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
    var steps: Double?
    var duration: String
    var date: Date

    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        guard let imageData else {
            return nil
        }
        return UIImage(data: imageData)
    }

    init(image: UIImage?, name: String, caloriesBurned: Double, steps: Double? = nil, duration: String, date: Date) {
        self.createdAt = Date()
        self.name = name
        self.caloriesBurned = caloriesBurned
        self.steps = steps
        self.duration = duration
        self.date = date
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }
}

@Model
final class DailySetup {
    @Attribute(.unique) var dateID: String
    var mode: String
    var baseCalories: Double?
    var baseProtein: Double?

    init(date: Date, mode: DayMode, baseCalories: Double? = nil, baseProtein: Double? = nil) {
        self.dateID = DateFormatter.yyyyMMdd.string(from: date)
        self.mode = mode.rawValue
        self.baseCalories = baseCalories
        self.baseProtein = baseProtein
    }

    func applyGoalSnapshotIfNeeded(baseCalories: Double, baseProtein: Double) {
        if self.baseCalories == nil {
            self.baseCalories = baseCalories
        }

        if self.baseProtein == nil {
            self.baseProtein = baseProtein
        }
    }

    func resolvedBaseCalories(for date: Date, fallback: Double, now: Date = Date(), calendar: Calendar = .current) -> Double {
        guard date < calendar.startOfDay(for: now) else {
            return fallback
        }

        return baseCalories ?? fallback
    }

    func resolvedBaseProtein(for date: Date, fallback: Double, now: Date = Date(), calendar: Calendar = .current) -> Double {
        guard date < calendar.startOfDay(for: now) else {
            return fallback
        }

        return baseProtein ?? fallback
    }
}

@Model
final class BodyMetricEntry {
    var id: UUID = UUID()
    var date: Date
    var weightKg: Double
    var bodyFatPercent: Double?
    var musclePercent: Double?
    var waterPercent: Double?
    var visceralFat: Double?
    var metabolicAge: Double?
    var note: String
    var source: String

    init(
        date: Date = Date(),
        weightKg: Double,
        bodyFatPercent: Double? = nil,
        musclePercent: Double? = nil,
        waterPercent: Double? = nil,
        visceralFat: Double? = nil,
        metabolicAge: Double? = nil,
        note: String = "",
        source: String = "Manual"
    ) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.musclePercent = musclePercent
        self.waterPercent = waterPercent
        self.visceralFat = visceralFat
        self.metabolicAge = metabolicAge
        self.note = note
        self.source = source
    }
}

enum BodyMetricProfileSync {
    static func shouldPromoteProfileWeight(candidateDate: Date, currentLatestDate: Date?, calendar: Calendar = .current) -> Bool {
        guard let currentLatestDate else {
            return true
        }

        return candidateDate > currentLatestDate || calendar.isDate(candidateDate, inSameDayAs: currentLatestDate)
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
    case cardio = "Cardio 🏃"
    case gym = "Gym 🏋️‍♂️"
    case cardioGym = "Cardio + Gym 🏃🏋️‍♂️"

    static var allCases: [DayMode] {
        [.chill, .cardio, .gym]
    }

    static func fromStoredValue(_ value: String?) -> DayMode {
        if value == "Chill 🛋️" {
            return .chill
        }

        if value == "Padel 🎾" {
            return .cardio
        }

        return DayMode(rawValue: value ?? "") ?? .chill
    }

    var emoji: String {
        switch self {
        case .chill:
            return "💤"
        case .cardio:
            return "🏃"
        case .gym:
            return "🏋️‍♂️"
        case .cardioGym:
            return "🏃🏋️‍♂️"
        }
    }

    var hasCardio: Bool {
        self == .cardio || self == .cardioGym
    }

    var hasGym: Bool {
        self == .gym || self == .cardioGym
    }

    func includes(_ mode: DayMode) -> Bool {
        switch mode {
        case .chill:
            return self == .chill
        case .cardio:
            return hasCardio
        case .gym:
            return hasGym
        case .cardioGym:
            return self == .cardioGym
        }
    }

    func toggled(_ mode: DayMode) -> DayMode {
        switch mode {
        case .chill:
            return .chill
        case .cardio:
            return DayMode.combined(hasCardio: !hasCardio, hasGym: hasGym)
        case .gym:
            return DayMode.combined(hasCardio: hasCardio, hasGym: !hasGym)
        case .cardioGym:
            return .cardioGym
        }
    }

    func merged(with mode: DayMode) -> DayMode {
        DayMode.combined(
            hasCardio: hasCardio || mode.hasCardio,
            hasGym: hasGym || mode.hasGym
        )
    }

    private static func combined(hasCardio: Bool, hasGym: Bool) -> DayMode {
        switch (hasCardio, hasGym) {
        case (true, true):
            return .cardioGym
        case (true, false):
            return .cardio
        case (false, true):
            return .gym
        case (false, false):
            return .chill
        }
    }
}
