import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AI Processing & Queue Management
extension HomeViewModel {

    func submitManualFoodText() {
        guard !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard canUseFreeAIScan else { isShowingPaywall = true; return }

        let textImage = generatePlaceholderIcon(systemName: "brain", color: .neonGreen)
        let item = ProcessingItem(
            images: [textImage],
            textPrompt: manualText,
            isTraining: false,
            targetDate: selectedDate
        )

        enqueueHomeProcessingItem(item)
        processQueue(items: [item])
        manualText = ""
    }

    func submitManualTrainingText() {
        guard !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let textImage = generatePlaceholderIcon(systemName: "figure.run", color: .orange)
        let item = ProcessingItem(
            images: [textImage],
            textPrompt: manualText,
            isTraining: true,
            targetDate: selectedDate
        )

        enqueueHomeProcessingItem(item)
        processTrainingQueue(items: [item])
        manualText = ""
    }

    func handleCameraImage(_ image: UIImage?) {
        guard let image else {
            return
        }
        let isTraining = pickingMode == .training
        if !isTraining {
            guard canUseFreeAIScan else { isShowingPaywall = true; selectedCameraImage = nil; return }
        }

        let item = ProcessingItem(
            images: [image.preparedForAIIntake()],
            isTraining: isTraining,
            targetDate: selectedDate
        )

        enqueueHomeProcessingItem(item)
        processHomeProcessingItem(item)
        selectedCameraImage = nil
    }

    func handleSelectedPhotoItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else {
            return
        }

        let targetDate = selectedDate
        let isTraining = pickingMode == .training
        if !isTraining {
            guard canUseFreeAIScan else { isShowingPaywall = true; selectedPhotoItems.removeAll(); return }
        }

        Task {
            var loadedImages: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image.preparedForAIIntake())
                }
            }

            await MainActor.run {
                selectedPhotoItems.removeAll()
                guard !loadedImages.isEmpty else {
                    return
                }

                let item = ProcessingItem(
                    images: loadedImages,
                    isTraining: isTraining,
                    targetDate: targetDate
                )

                enqueueHomeProcessingItem(item)
                processHomeProcessingItem(item)
            }
        }
    }

    func enqueueHomeProcessingItem(_ item: ProcessingItem) {
        if !item.isTraining {
            AIUsageLimiter.recordScan()
        }
        withAnimation {
            processingItems.append(item)
        }
    }

    var canUseFreeAIScan: Bool {
        AIUsageLimiter.canScan
    }

    func processHomeProcessingItem(_ item: ProcessingItem) {
        if item.isTraining {
            processTrainingQueue(items: [item])
        } else {
            processQueue(items: [item])
        }
    }

    func processQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, [FoodResult]?, TrainingResult?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await AIProcessingEngine.analyzeFood(for: item)
                        guard item.textPrompt == nil else {
                            return (item.id, results, nil, error)
                        }

                        if AIFallbackLogic.shouldRunTrainingFallback(foodResults: results, error: error) {
                            let (trainingResult, trainingError) = await AIProcessingEngine.analyzeTraining(for: item)
                            if let trainingResult {
                                return (item.id, nil, trainingResult, nil)
                            }
                            return (item.id, results, nil, error ?? trainingError)
                        }

                        return (item.id, results, nil, error)
                    }
                }

                for await (id, results, trainingResult, error) in group {
                    await MainActor.run {
                        guard let item = finishProcessingItem(id: id, from: &processingItems) else {
                            return
                        }

                        let originalImage = item.images.first ?? UIImage()
                        let entryDate = item.targetDate ?? selectedDate

                        if let trainingResult {
                            addTrainingResult(trainingResult, image: originalImage, date: entryDate)
                            showAddingStatus("Workout added to \(shortDayLabel(entryDate))", image: originalImage, usesFridgeQueue: false)
                            return
                        }

                        guard let results, !results.isEmpty else {
                            aiErrorMessage = AIProcessingEngine.friendlyError(error, fallback: "Food analysis failed. Please try again.")
                            return
                        }

                        stageFoodResultsIfNeeded(
                            results,
                            originalItem: item,
                            originalImage: originalImage,
                            targetDate: entryDate
                        )
                    }
                }
            }
        }
    }

    func processTrainingQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, TrainingResult?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (result, error) = await AIProcessingEngine.analyzeTraining(for: item)
                        return (item.id, result, error)
                    }
                }

                for await (id, result, error) in group {
                    await MainActor.run {
                        guard let item = finishProcessingItem(id: id, from: &processingItems) else {
                            return
                        }

                        let processedImage = item.images.first ?? UIImage()
                        let entryDate = item.targetDate ?? selectedDate

                        guard let result else {
                            aiErrorMessage = AIProcessingEngine.friendlyError(error, fallback: "Workout analysis failed. Please try again.")
                            return
                        }

                        let resolvedCalories = resolvedTrainingCalories(from: result)
                        let entry = TrainingEntry(
                            image: processedImage,
                            name: result.activity_name,
                            caloriesBurned: resolvedCalories,
                            steps: result.steps,
                            tonnageKg: result.tonnage_kg,
                            duration: result.duration,
                            date: entryDate,
                            aiSummary: result.ai_summary
                        )

                        withAnimation(.spring()) {
                            snapshotPastGoalsIfNeeded(for: entryDate)
                            modelContext?.insert(entry)
                            applyTrainingModeSuggestion(from: result, for: entryDate)
                        }
                    }
                }
            }
        }
    }

    func processFridgeQueue(items: [ProcessingItem]) {
        guard AIUsageLimiter.canConsume(items.count) else { isShowingPaywall = true; return }
        AIUsageLimiter.recordScans(items.count)
        Task {
            await withTaskGroup(of: (UUID, [FoodResult]?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await AIProcessingEngine.analyzeFood(for: item)
                        return (item.id, results, error)
                    }
                }

                for await (id, results, error) in group {
                    await MainActor.run {
                        guard let item = finishProcessingItem(id: id, from: &fridgeProcessingItems) else {
                            return
                        }

                        let originalImage = item.images.first ?? UIImage()

                        guard let results, !results.isEmpty else {
                            aiErrorMessage = AIProcessingEngine.friendlyError(error, fallback: "My Food analysis failed. Please try again.")
                            return
                        }

                        stageLibraryResultsIfNeeded(
                            results,
                            originalItem: item,
                            originalImage: originalImage
                        )
                    }
                }
            }
        }
    }

    func processReceiptQueue(items: [ProcessingItem]) {
        guard AIUsageLimiter.canConsume(items.count) else { isShowingPaywall = true; return }
        AIUsageLimiter.recordScans(items.count)
        Task {
            await withTaskGroup(of: (UUID, [FoodResult]?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await AIProcessingEngine.scanReceipt(for: item)
                        return (item.id, results, error)
                    }
                }

                for await (id, results, error) in group {
                    await MainActor.run {
                        guard let item = finishProcessingItem(id: id, from: &fridgeProcessingItems) else {
                            return
                        }

                        guard let results, !results.isEmpty else {
                            aiErrorMessage = AIProcessingEngine.friendlyError(error, fallback: "Receipt scan failed. Please try again.")
                            return
                        }

                        stageReceiptResultsIfNeeded(results, originalItem: item)
                    }
                }
            }
        }
    }

    func deleteFoodEntry(_ entry: FoodEntry) {
        GeminiService.shared.invalidateFoodImageCache(for: entry.uiImage)
        modelContext?.delete(entry)
    }

    func resolvedTrainingCalories(from result: TrainingResult) -> Double {
        if result.calories_burned > 0 {
            return result.calories_burned
        }

        let durationMinutes = durationMinutes(from: result.duration) ?? fallbackTrainingDurationMinutes(for: result)
        let met = estimatedMET(for: result)
        let estimatedCalories = met * 3.5 * max(currentWeight, 45) / 200 * durationMinutes
        return max(estimatedCalories.rounded(), 120)
    }

    func addTrainingResult(_ result: TrainingResult, image: UIImage, date: Date) {
        let entry = TrainingEntry(
            image: image,
            name: result.activity_name,
            caloriesBurned: resolvedTrainingCalories(from: result),
            steps: result.steps,
            tonnageKg: result.tonnage_kg,
            duration: result.duration,
            date: date,
            aiSummary: result.ai_summary
        )

        withAnimation(.spring()) {
            snapshotPastGoalsIfNeeded(for: date)
            modelContext?.insert(entry)
            applyTrainingModeSuggestion(from: result, for: date)
        }
    }

}

enum AIFallbackLogic {
    static func shouldRunTrainingFallback(foodResults: [FoodResult]?, error: String?) -> Bool {
        if let foodResults, !foodResults.isEmpty {
            return foodResults.count == 1 && looksLikeWorkoutMisclassified(foodResults[0])
        }

        return error != nil
    }

    static func looksLikeWorkoutMisclassified(_ result: FoodResult) -> Bool {
        let text = "\(result.food_name.lowercased()) \(result.ingredients_breakdown.lowercased()) \(result.ai_response_text.lowercased())"
        let workoutHints = [
            "workout", "training", "session", "run", "running", "cardio",
            "gym", "strength", "padel", "tennis", "bpm", "strain", "burned",
            "kcal burned", "steps", "whoop"
        ]

        if workoutHints.contains(where: { text.contains($0) }) {
            return true
        }

        let noIngredients = result.ingredients_breakdown
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        return noIngredients && result.protein <= 1 && result.calories <= 1
    }
}

extension HomeViewModel {

    func durationMinutes(from duration: String) -> Double? {
        let lower = duration.lowercased()
        let numbers = lower
            .replacingOccurrences(of: "[^0-9hms ]", with: " ", options: .regularExpression)
            .split(separator: " ")

        if lower.contains("h"), let hours = numbers.first.flatMap({ Double($0) }) {
            let minutes = numbers.dropFirst().first.flatMap { Double($0) } ?? 0
            return hours * 60 + minutes
        }

        if let first = numbers.first, let value = Double(first) {
            return value
        }

        return nil
    }

    func fallbackTrainingDurationMinutes(for result: TrainingResult) -> Double {
        let combined = "\(result.activity_name.lowercased()) \(result.ai_summary.lowercased()) \(result.day_mode?.lowercased() ?? "")"

        if combined.contains("run") || combined.contains("cycling") || combined.contains("padel") || combined.contains("tennis") {
            return 60
        }

        if combined.contains("walk") {
            return 45
        }

        return 50
    }

    func estimatedMET(for result: TrainingResult) -> Double {
        let combined = "\(result.activity_name.lowercased()) \(result.ai_summary.lowercased()) \(result.day_mode?.lowercased() ?? "")"

        if combined.contains("run") || combined.contains("running") {
            return 9.5
        }
        if combined.contains("padel") || combined.contains("tennis") || combined.contains("pickleball") {
            return 7.3
        }
        if combined.contains("cycle") || combined.contains("bike") || combined.contains("cycling") {
            return 8.2
        }
        if combined.contains("walk") || combined.contains("hike") {
            return 4.4
        }
        if combined.contains("gym") || combined.contains("strength") || combined.contains("weight") || combined.contains("leg day") || combined.contains("upper body") || combined.contains("lower body") {
            return 5.8
        }

        return 6.0
    }

    func stageFoodResultsIfNeeded(
        _ results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        targetDate: Date
    ) {
        if results.count > 1 {
            presentAIReview(
                results: results,
                originalItem: originalItem,
                originalImage: originalImage,
                destination: .diary(targetDate)
            )
            return
        }

        addFoodResults(results, originalItem: originalItem, originalImage: originalImage, targetDate: targetDate)
    }

    func stageLibraryResultsIfNeeded(
        _ results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage
    ) {
        if results.count > 1 {
            presentAIReview(
                results: results,
                originalItem: originalItem,
                originalImage: originalImage,
                destination: originalItem.targetTab == 1 ? .meals : .fridge
            )
            return
        }

        addLibraryResults(results, originalItem: originalItem, originalImage: originalImage)
    }

    func stageReceiptResultsIfNeeded(_ results: [FoodResult], originalItem: ProcessingItem) {
        if results.count > 1 {
            presentAIReview(
                results: results,
                originalItem: originalItem,
                originalImage: originalItem.images.first ?? UIImage(),
                destination: .receipt
            )
            return
        }

        addReceiptResults(results)
    }

    func presentAIReview(
        results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        destination: AIResultDestination
    ) {
        let review = AIResultReview.make(
            results: results,
            originalItem: originalItem,
            originalImage: originalImage,
            destination: destination,
            imageForResult: { item, result, index, fallback in
                resolvedImage(item: item, result: result, resultIndex: index, fallbackImage: fallback)
            }
        )

        let status = ProcessingItem(
            images: [originalImage],
            targetTab: originalItem.targetTab,
            targetDate: originalItem.targetDate,
            statusTitle: "Found \(review.items.count) items"
        )

        withAnimation(.spring()) {
            if destination.usesFridgeQueue {
                fridgeProcessingItems.append(status)
            } else {
                processingItems.append(status)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)

            await MainActor.run {
                if destination.usesFridgeQueue {
                    removeProcessingItems(ids: [status.id], from: &fridgeProcessingItems)
                } else {
                    removeProcessingItems(ids: [status.id], from: &processingItems)
                }

                pendingAIReview = review
            }
        }
    }

    func retryReviewIgnoringCache(_ review: AIResultReview) {
        pendingAIReview = nil

        let status = ProcessingItem(
            images: [review.originalImage],
            targetTab: review.originalItem.targetTab,
            targetDate: review.originalItem.targetDate,
            statusTitle: "Recalculating fresh..."
        )

        withAnimation(.spring()) {
            if review.destination.usesFridgeQueue {
                fridgeProcessingItems.append(status)
            } else {
                processingItems.append(status)
            }
        }

        Task {
            let (results, error) = review.destination == .receipt
                ? await AIProcessingEngine.scanReceipt(for: review.originalItem)
                : await AIProcessingEngine.analyzeFood(for: review.originalItem, ignoreCache: true)

            await MainActor.run {
                if review.destination.usesFridgeQueue {
                    removeProcessingItems(ids: [status.id], from: &fridgeProcessingItems)
                } else {
                    removeProcessingItems(ids: [status.id], from: &processingItems)
                }

                guard let results, !results.isEmpty else {
                    aiErrorMessage = AIProcessingEngine.friendlyError(error, fallback: "Fresh AI analysis failed. Please try again.")
                    return
                }

                if results.count > 1 {
                    presentAIReview(
                        results: results,
                        originalItem: review.originalItem,
                        originalImage: review.originalImage,
                        destination: review.destination
                    )
                } else {
                    switch review.destination {
                    case .diary(let targetDate):
                        addFoodResults(results, originalItem: review.originalItem, originalImage: review.originalImage, targetDate: targetDate)
                    case .fridge, .meals:
                        addLibraryResults(results, originalItem: review.originalItem, originalImage: review.originalImage)
                    case .receipt:
                        addReceiptResults(results)
                    }
                }
            }
        }
    }

    func confirmAIReview(_ review: AIResultReview, selectedItems: [AIReviewFoodItem]) {
        guard !selectedItems.isEmpty else { return }

        showAddingStatus(review.addingStatus, image: review.originalImage, usesFridgeQueue: review.destination.usesFridgeQueue)

        withAnimation(.spring()) {
            for item in selectedItems {
                switch review.destination {
                case .diary(let targetDate):
                    snapshotPastGoalsIfNeeded(for: targetDate)
                    modelContext?.insert(FoodEntry(
                        image: item.image,
                        name: item.name,
                        calories: item.calories,
                        protein: item.protein,
                        carbs: item.carbs,
                        fat: item.fat,
                        ingredients: item.ingredients,
                        date: targetDate
                    ))
                case .fridge, .receipt:
                    modelContext?.insert(FavoriteFood(
                        image: item.image,
                        name: item.name,
                        calories: item.calories,
                        protein: item.protein,
                        carbs: item.carbs,
                        fat: item.fat,
                        ingredients: item.ingredients
                    ))
                case .meals:
                    modelContext?.insert(SavedRecipe(
                        image: item.image,
                        name: item.name,
                        instructions: "",
                        calories: item.calories,
                        protein: item.protein,
                        carbs: item.carbs,
                        fat: item.fat,
                        ingredients: item.ingredients
                    ))
                }
            }
        }
    }

    func addFoodResults(
        _ results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        targetDate: Date
    ) {
        showAddingStatus("Adding to \(shortDayLabel(targetDate))", image: originalImage, usesFridgeQueue: false)

        withAnimation(.spring()) {
            snapshotPastGoalsIfNeeded(for: targetDate)

            for (resultIndex, result) in results.enumerated() {
                let image = resolvedImage(
                    item: originalItem,
                    result: result,
                    resultIndex: resultIndex,
                    fallbackImage: originalImage
                )
                modelContext?.insert(FoodEntry(
                    image: image,
                    name: result.food_name,
                    calories: result.calories,
                    protein: result.protein,
                    carbs: result.carbs,
                    fat: result.fat,
                    ingredients: result.ingredients_breakdown,
                    date: targetDate
                ))
            }
        }
    }

    func addLibraryResults(_ results: [FoodResult], originalItem: ProcessingItem, originalImage: UIImage) {
        showAddingStatus(originalItem.targetTab == 1 ? "Saving to Meals" : "Saving to Fridge", image: originalImage, usesFridgeQueue: true)

        withAnimation(.spring()) {
            for (resultIndex, result) in results.enumerated() {
                let image = resolvedImage(
                    item: originalItem,
                    result: result,
                    resultIndex: resultIndex,
                    fallbackImage: originalImage
                )

                if originalItem.targetTab == 1 {
                    modelContext?.insert(SavedRecipe(
                        image: image,
                        name: result.food_name,
                        instructions: "",
                        calories: result.calories,
                        protein: result.protein,
                        carbs: result.carbs,
                        fat: result.fat,
                        ingredients: result.ingredients_breakdown
                    ))
                } else {
                    modelContext?.insert(FavoriteFood(
                        image: image,
                        name: result.food_name,
                        calories: result.calories,
                        protein: result.protein,
                        carbs: result.carbs,
                        fat: result.fat,
                        ingredients: result.ingredients_breakdown
                    ))
                }
            }
        }
    }

    func resolvedImage(
        item: ProcessingItem,
        result: FoodResult,
        resultIndex: Int,
        fallbackImage: UIImage
    ) -> UIImage {
        AIResultImageResolver.image(
            for: item,
            result: result,
            resultIndex: resultIndex,
            fallbackImage: fallbackImage,
            emojiImage: { generateEmojiIcon(emoji: $0) }
        )
    }

    func addReceiptResults(_ results: [FoodResult]) {
        showAddingStatus("Saving to Fridge", image: generateEmojiIcon(emoji: "🛒"), usesFridgeQueue: true)

        withAnimation(.spring()) {
            for result in results {
                modelContext?.insert(FavoriteFood(
                    image: generateEmojiIcon(emoji: result.emoji ?? "🛒"),
                    name: result.food_name,
                    calories: result.calories,
                    protein: result.protein,
                    carbs: result.carbs,
                    fat: result.fat,
                    ingredients: result.ingredients_breakdown
                ))
            }
        }
    }

    func showAddingStatus(_ title: String, image: UIImage, usesFridgeQueue: Bool) {
        let item = ProcessingItem(images: [image.preparedForAppStorage()], statusTitle: title)

        withAnimation(.spring()) {
            if usesFridgeQueue {
                fridgeProcessingItems.append(item)
            } else {
                processingItems.append(item)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run {
                if usesFridgeQueue {
                    removeProcessingItems(ids: [item.id], from: &fridgeProcessingItems)
                } else {
                    removeProcessingItems(ids: [item.id], from: &processingItems)
                }
            }
        }
    }

    func shortDayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    func removeProcessingItems(ids: [UUID], from items: inout [ProcessingItem]) {
        let idSet = Set(ids)
        withAnimation(.easeInOut) {
            items.removeAll { idSet.contains($0.id) }
        }
    }

    func finishProcessingItem(id: UUID, from items: inout [ProcessingItem]) -> ProcessingItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let item = items[index]
        withAnimation(.easeInOut) {
            _ = items.remove(at: index)
        }
        return item
    }
}
