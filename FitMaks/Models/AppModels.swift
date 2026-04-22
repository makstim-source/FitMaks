import Foundation
import SwiftData
import UIKit

struct ProcessingItem: Identifiable {
    let id = UUID()
    let createdAt = Date()
    let images: [UIImage]
    var textPrompt: String? = nil
    var isTraining: Bool = false
    var targetTab: Int = 0
    var targetDate: Date? = nil
    var statusTitle: String? = nil
}

enum EntryMode {
    case food
    case training
}

enum TimelineItem: Identifiable {
    case food(FoodEntry)
    case training(TrainingEntry)

    var id: UUID {
        switch self {
        case .food(let food):
            return food.id
        case .training(let training):
            return training.id
        }
    }

    var date: Date {
        switch self {
        case .food(let food):
            return food.date
        case .training(let training):
            return training.date
        }
    }

    var createdAt: Date {
        switch self {
        case .food(let food):
            return food.createdAt ?? food.date
        case .training(let training):
            return training.createdAt ?? training.date
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var ingredients: String? = nil
    var calories: Double? = nil
    var protein: Double? = nil
    var attachedImage: UIImage? = nil
    var shouldTypewrite: Bool = false
}

struct ParsedIng: Identifiable {
    let id = UUID()
    let name: String
    let weight: String
    let kcal: String
    let prot: String
}

@Model
final class FavoriteFood {
    var id: UUID = UUID()
    var createdAt: Date?
    var name: String
    var calories: Double
    var protein: Double
    var ingredients: String

    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        guard let imageData else {
            return nil
        }
        return UIImage(data: imageData)
    }

    init(image: UIImage?, name: String, calories: Double, protein: Double, ingredients: String) {
        self.createdAt = Date()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.ingredients = ingredients
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }
}

@Model
final class TrainingEntry {
    var id: UUID = UUID()
    var createdAt: Date?
    var name: String
    var caloriesBurned: Double
    var duration: String
    var date: Date

    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        guard let imageData else {
            return nil
        }
        return UIImage(data: imageData)
    }

    init(image: UIImage?, name: String, caloriesBurned: Double, duration: String, date: Date) {
        self.createdAt = Date()
        self.name = name
        self.caloriesBurned = caloriesBurned
        self.duration = duration
        self.date = date
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }
}

@Model
final class DailySetup {
    @Attribute(.unique) var dateID: String
    var mode: String

    init(date: Date, mode: DayMode) {
        self.dateID = DateFormatter.yyyyMMdd.string(from: date)
        self.mode = mode.rawValue
    }
}

@Model
final class ShoppingItem {
    var id: UUID = UUID()
    var name: String
    var isCompleted: Bool

    init(name: String) {
        self.name = name
        self.isCompleted = false
    }
}

@Model
final class SavedRecipe {
    var id: UUID = UUID()
    var name: String
    var instructions: String
    var calories: Double
    var protein: Double
    var dateSaved: Date
    var ingredients: String

    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        guard let imageData else {
            return nil
        }
        return UIImage(data: imageData)
    }

    init(
        image: UIImage? = nil,
        name: String,
        instructions: String,
        calories: Double,
        protein: Double,
        ingredients: String = ""
    ) {
        self.name = name
        self.instructions = instructions
        self.calories = calories
        self.protein = protein
        self.ingredients = ingredients
        self.dateSaved = Date()
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }

    var asResult: RecipeResult {
        RecipeResult(
            recipe_name: name,
            cooking_instructions: instructions,
            estimated_calories: calories,
            estimated_protein: protein
        )
    }
}

enum DayMode: String, CaseIterable {
    case chill = "Chill 💤"
    case padel = "Padel 🎾"
    case gym = "Gym 🏋️‍♂️"

    static func fromStoredValue(_ value: String?) -> DayMode {
        if value == "Chill 🛋️" {
            return .chill
        }

        return DayMode(rawValue: value ?? "") ?? .chill
    }

    var emoji: String {
        switch self {
        case .chill:
            return "💤"
        case .padel:
            return "🎾"
        case .gym:
            return "🏋️‍♂️"
        }
    }
}
