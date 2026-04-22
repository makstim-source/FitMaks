import Foundation
import UIKit

enum AIResultDestination: Equatable {
    case diary(Date)
    case fridge
    case receipt
    case meals

    var usesFridgeQueue: Bool {
        switch self {
        case .diary:
            return false
        case .fridge, .receipt, .meals:
            return true
        }
    }

    var reviewSubtitle: String {
        switch self {
        case .diary(let date):
            return "AI found multiple foods for \(shortLabel(for: date))"
        case .fridge:
            return "AI found multiple items for My Food"
        case .receipt:
            return "AI found multiple items on the receipt"
        case .meals:
            return "AI found multiple meals"
        }
    }

    var addingStatus: String {
        switch self {
        case .diary(let date):
            return "Adding to \(shortLabel(for: date))"
        case .fridge, .receipt:
            return "Saving to Fridge"
        case .meals:
            return "Saving to Meals"
        }
    }

    func actionTitle(count: Int) -> String {
        switch self {
        case .diary:
            return "Add \(count) to Diary"
        case .fridge, .receipt:
            return "Save \(count) to Fridge"
        case .meals:
            return "Save \(count) to Meals"
        }
    }

    private func shortLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct AIReviewFoodItem: Identifiable {
    let id = UUID()
    var image: UIImage
    var name: String
    var calories: Double
    var protein: Double
    var ingredients: String
    var isSelected = true
}

struct AIResultReview: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var actionTitle: String
    var addingStatus: String
    var destination: AIResultDestination
    var originalItem: ProcessingItem
    var originalImage: UIImage
    var items: [AIReviewFoodItem]

    static func make(
        results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        destination: AIResultDestination,
        imageForResult: (ProcessingItem, FoodResult, Int, UIImage) -> UIImage
    ) -> AIResultReview {
        let items = results.enumerated().map { pair -> AIReviewFoodItem in
            let (index, result) = pair
            let reviewImage = imageForResult(originalItem, result, index, originalImage)
                .preparedForAppStorage()

            return AIReviewFoodItem(
                image: reviewImage,
                name: result.food_name,
                calories: result.calories,
                protein: result.protein,
                ingredients: result.ingredients_breakdown
            )
        }

        return AIResultReview(
            title: "Review \(items.count) items",
            subtitle: "\(destination.reviewSubtitle). Uncheck anything wrong before adding.",
            actionTitle: destination.actionTitle(count: items.count),
            addingStatus: destination.addingStatus,
            destination: destination,
            originalItem: originalItem,
            originalImage: originalImage,
            items: items
        )
    }
}

enum AIResultImageResolver {
    static func image(
        for item: ProcessingItem,
        result: FoodResult,
        resultIndex: Int,
        fallbackImage: UIImage,
        emojiImage: (String) -> UIImage
    ) -> UIImage {
        if item.textPrompt != nil {
            return emojiImage(result.emoji ?? "🍽️")
        }

        if let sourcePhotoNumber = result.source_photo_number {
            let imageIndex = sourcePhotoNumber - 1
            if item.images.indices.contains(imageIndex) {
                return item.images[imageIndex]
            }
        }

        return item.images.indices.contains(resultIndex)
            ? item.images[resultIndex]
            : fallbackImage
    }
}
