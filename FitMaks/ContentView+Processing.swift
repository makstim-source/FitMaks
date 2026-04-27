import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AI Processing & Queue Management
extension ContentView {

    func submitManualFoodText() {
        guard !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

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

    func handleCameraImage(_ image: UIImage?) {
        guard let image else {
            return
        }

        let item = ProcessingItem(
            images: [image.preparedForAIIntake()],
            isTraining: pickingMode == .training,
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
        withAnimation {
            processingItems.append(item)
        }
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
            await withTaskGroup(of: (UUID, [FoodResult]?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await AIProcessingEngine.analyzeFood(for: item)
                        return (item.id, results, error)
                    }
                }

                for await (id, results, error) in group {
                    await MainActor.run {
                        guard let item = finishProcessingItem(id: id, from: &processingItems) else {
                            return
                        }

                        let originalImage = item.images.first ?? UIImage()
                        let entryDate = item.targetDate ?? selectedDate

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

                        let entry = TrainingEntry(
                            image: processedImage,
                            name: result.activity_name,
                            caloriesBurned: result.calories_burned,
                            steps: result.steps,
                            duration: result.duration,
                            date: entryDate,
                            aiSummary: result.ai_summary
                        )

                        withAnimation(.spring()) {
                            snapshotPastGoalsIfNeeded(for: entryDate)
                            modelContext.insert(entry)
                            applyTrainingModeSuggestion(from: result, for: entryDate)
                        }
                    }
                }
            }
        }
    }

    func processFridgeQueue(items: [ProcessingItem]) {
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
        modelContext.delete(entry)
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
                    modelContext.insert(FoodEntry(
                        image: item.image,
                        name: item.name,
                        calories: item.calories,
                        protein: item.protein,
                        ingredients: item.ingredients,
                        date: targetDate
                    ))
                case .fridge, .receipt:
                    modelContext.insert(FavoriteFood(
                        image: item.image,
                        name: item.name,
                        calories: item.calories,
                        protein: item.protein,
                        ingredients: item.ingredients
                    ))
                case .meals:
                    modelContext.insert(SavedRecipe(
                        image: item.image,
                        name: item.name,
                        instructions: "",
                        calories: item.calories,
                        protein: item.protein,
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
                modelContext.insert(FoodEntry(
                    image: image,
                    name: result.food_name,
                    calories: result.calories,
                    protein: result.protein,
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
                    modelContext.insert(SavedRecipe(
                        image: image,
                        name: result.food_name,
                        instructions: "",
                        calories: result.calories,
                        protein: result.protein,
                        ingredients: result.ingredients_breakdown
                    ))
                } else {
                    modelContext.insert(FavoriteFood(
                        image: image,
                        name: result.food_name,
                        calories: result.calories,
                        protein: result.protein,
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
                modelContext.insert(FavoriteFood(
                    image: generateEmojiIcon(emoji: result.emoji ?? "🛒"),
                    name: result.food_name,
                    calories: result.calories,
                    protein: result.protein,
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
