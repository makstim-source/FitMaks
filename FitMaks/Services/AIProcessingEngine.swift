import Foundation

enum AIProcessingEngine {
    static func analyzeFood(
        for item: ProcessingItem,
        ignoreCache: Bool = false
    ) async -> ([FoodResult]?, String?) {
        if let text = item.textPrompt {
            let (result, error) = await GeminiService.shared.analyzeTextAsync(text: text)
            return (result.map { [$0] }, error)
        }

        if item.images.count > 1 {
            return await GeminiService.shared.analyzeFoodItemsAsync(images: item.images, ignoreCache: ignoreCache)
        }

        let (result, error) = await GeminiService.shared.analyzeImagesAsync(images: item.images, ignoreCache: ignoreCache)
        return (result.map { [$0] }, error)
    }

    static func analyzeTraining(for item: ProcessingItem) async -> (TrainingResult?, String?) {
        await GeminiService.shared.analyzeTrainingImagesAsync(images: item.images)
    }

    static func scanReceipt(for item: ProcessingItem) async -> ([FoodResult]?, String?) {
        await GeminiService.shared.scanGroceriesAsync(images: item.images)
    }

    static func friendlyError(_ error: String?, fallback: String) -> String {
        guard let error, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        if error.lowercased().contains("cancelled") {
            return "The AI request was interrupted. Please try again."
        }

        return error
    }
}
