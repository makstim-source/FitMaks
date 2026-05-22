import Foundation
import UIKit

// MARK: - Async Wrappers

extension GeminiService {
    func analyzeImagesAsync(images: [UIImage], ignoreCache: Bool = false) async -> (FoodResult?, String?) {
        await withCheckedContinuation { continuation in
            analyzeImages(images: images, ignoreCache: ignoreCache) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func analyzeFoodItemsAsync(images: [UIImage], ignoreCache: Bool = false) async -> ([FoodResult]?, String?) {
        await withCheckedContinuation { continuation in
            analyzeFoodItems(images: images, ignoreCache: ignoreCache) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func analyzeTextAsync(text: String) async -> (FoodResult?, String?) {
        await withCheckedContinuation { continuation in
            analyzeText(text: text) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func analyzeTrainingImagesAsync(images: [UIImage]) async -> (TrainingResult?, String?) {
        await withCheckedContinuation { continuation in
            analyzeTrainingImages(images: images) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func analyzeTrainingTextAsync(text: String) async -> (TrainingResult?, String?) {
        await withCheckedContinuation { continuation in
            analyzeTrainingText(text: text) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func scanGroceriesAsync(images: [UIImage]) async -> ([FoodResult]?, String?) {
        await withCheckedContinuation { continuation in
            scanGroceries(images: images) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func generateNutritionWeightReportAsync(
        dateRange: String,
        avgCalories: Int, targetCalories: Int,
        avgProtein: Int, targetProtein: Int,
        avgCarbs: Int, avgFat: Int,
        avgTrainingCalories: Int = 0,
        weightEntries: [(date: String, weight: Double)],
        weeklyScore: Int,
        perfectDays: Int,
        totalDays: Int,
        userName: String? = nil
    ) async -> (String?, String?) {
        await withCheckedContinuation { continuation in
            generateNutritionWeightReport(
                dateRange: dateRange,
                avgCalories: avgCalories, targetCalories: targetCalories,
                avgProtein: avgProtein, targetProtein: targetProtein,
                avgCarbs: avgCarbs, avgFat: avgFat,
                avgTrainingCalories: avgTrainingCalories,
                weightEntries: weightEntries,
                weeklyScore: weeklyScore,
                perfectDays: perfectDays,
                totalDays: totalDays,
                userName: userName
            ) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }

    func analyzeWeightTrendAsync(
        weightEntries: [(date: String, weight: Double)],
        targetCalories: Int,
        targetProtein: Int,
        userName: String? = nil
    ) async -> (String?, String?) {
        await withCheckedContinuation { continuation in
            analyzeWeightTrend(
                weightEntries: weightEntries,
                targetCalories: targetCalories,
                targetProtein: targetProtein,
                userName: userName
            ) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }
}
