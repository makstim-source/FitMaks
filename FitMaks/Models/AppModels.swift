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
    var carbs: Double? = nil
    var fat: Double? = nil
    var attachedImage: UIImage? = nil
    var shouldTypewrite: Bool = false
}

struct ParsedIng: Identifiable {
    let id = UUID()
    let name: String
    let weight: String
    let kcal: String
    let prot: String
    let carbs: String
    let fat: String
}

enum FavoritePortionBasis: String, CaseIterable {
    case per100g
    case perServing
    case perPack
    case perPiece

    var title: String {
        switch self {
        case .per100g:
            return "100 g"
        case .perServing:
            return "1 serving"
        case .perPack:
            return "1 pack"
        case .perPiece:
            return "1 piece"
        }
    }

    var sheetTitle: String {
        switch self {
        case .per100g:
            return "100 g basis"
        case .perServing:
            return "Serving basis"
        case .perPack:
            return "Pack basis"
        case .perPiece:
            return "Piece basis"
        }
    }
}

struct FavoritePortionPreset: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
}

// MARK: - Food Categories

enum FridgeCategory: String, CaseIterable {
    case proteins = "Proteins"
    case healthyCarbs = "Healthy Carbs"
    case fruitVeg = "Fruit & Veg"
    case dairy = "Dairy"
    case drinks = "Drinks"
    case snacks = "Snacks"
    case sauces = "Sauces & Extras"
    case other = "Other"

    var emoji: String {
        switch self {
        case .proteins: return "🥩"
        case .healthyCarbs: return "🍚"
        case .fruitVeg: return "🥬"
        case .dairy: return "🧀"
        case .drinks: return "🥤"
        case .snacks: return "🍫"
        case .sauces: return "🫙"
        case .other: return "📦"
        }
    }

    static func infer(name: String, ingredients: String) -> FridgeCategory {
        let text = (name + " " + ingredients).lowercased()

        let proteinKeys = ["chicken", "курин", "курица", "beef", "говя", "turkey", "индей",
                           "tuna", "тунец", "salmon", "лосось", "shrimp", "креветк", "fish", "рыб",
                           "egg", "яйц", "mince", "фарш", "steak", "pork", "свинин", "duck", "утк",
                           "lamb", "баранин", "tofu", "тофу", "protein", "протеин",
                           "kana", "kanan", "filee", "pihvi", "liha", "lohi", "katkarapu",
                           "kalkkuna", "nauta", "sika", "ankka", "karitsa",
                           "sisäfilee", "ulkofilee", "grilli"]
        let dairyKeys = ["milk", "молок", "yogurt", "йогурт", "skyr", "cheese", "сыр",
                         "творог", "cottage", "кефир", "kefir", "cream", "сливк", "butter", "масло",
                         "сметан", "alpro", "valio", "quark", "rahka", "maitorahka",
                         "maito", "juusto", "kerma", "jogurtti", "piimä",
                         "milbona", "ehrmann"]
        let carbKeys = ["rice", "рис", "pasta", "макарон", "bread", "хлеб", "oat", "овся",
                        "potato", "картош", "noodle", "лапш", "cereal", "мюсли", "granola",
                        "buckwheat", "гречк", "couscous", "кускус", "quinoa", "киноа", "булк",
                        "tortilla", "тортилья", "flatbread", "лаваш", "wrap",
                        "kaura", "peruna", "riisi", "leipä", "penne", "spagetti", "nuudeli"]
        let fruitVegKeys = ["apple", "яблок", "banana", "банан", "berr", "ягод", "orange", "апельсин",
                            "grape", "виноград", "tomato", "помидор", "cucumber", "огурец", "pepper", "перец",
                            "carrot", "морков", "onion", "лук", "avocado", "авокадо", "lettuce", "салат",
                            "spinach", "шпинат", "broccoli", "брокколи", "mango", "манго", "kiwi", "киви",
                            "lemon", "лимон", "peach", "персик", "pear", "груш", "cabbage", "капуст",
                            "zucchini", "кабачок", "eggplant", "баклажан", "mushroom", "гриб",
                            "omena", "banaani", "tomaatti", "kurkku", "porkkana", "sipuli",
                            "sieni", "parsakaali", "paprika", "passata"]
        let snackKeys = ["bar", "батончик", "chocolate", "шоколад", "chips", "чипс", "nuts", "орех",
                         "cookie", "печень", "candy", "конфет", "waffle", "вафл", "cracker",
                         "dried", "сухофрукт", "popcorn", "попкорн", "халва", "мармелад",
                         "suklaa", "keksi", "pähkinä"]
        let sauceKeys = ["sauce", "соус", "ketchup", "кетчуп", "mayo", "майонез", "mustard", "горчиц",
                         "dressing", "заправк", "vinegar", "уксус", "oil", "олив", "honey", "мёд", "мед",
                         "syrup", "сироп", "jam", "джем", "варень", "pesto", "песто", "soy sauce",
                         "sriracha", "hummus", "хумус", "salsa", "сальса", "spice", "специ",
                         "sinappi", "kastike", "hunaja", "öljy"]
        let drinkKeys = ["juice", "сок", "cola", "cola zero", "soda", "water", "вода",
                         "drink", "напиток", "shake", "smoothie", "coffee", "кофе", "tea", "чай",
                         "monster", "red bull", "компот", "морс",
                         "mehu", "kahvi", "tee", "limonadi"]

        if proteinKeys.contains(where: { text.contains($0) }) { return .proteins }
        if dairyKeys.contains(where: { text.contains($0) }) { return .dairy }
        if carbKeys.contains(where: { text.contains($0) }) { return .healthyCarbs }
        if fruitVegKeys.contains(where: { text.contains($0) }) { return .fruitVeg }
        if snackKeys.contains(where: { text.contains($0) }) { return .snacks }
        if sauceKeys.contains(where: { text.contains($0) }) { return .sauces }
        if drinkKeys.contains(where: { text.contains($0) }) { return .drinks }
        return .other
    }
}

enum MealCategory: String, CaseIterable {
    case mainDish = "Main Dish"
    case sides = "Sides"
    case salads = "Salads & Starters"
    case breakfast = "Breakfast"
    case snacks = "Snacks"
    case other = "Other"

    var emoji: String {
        switch self {
        case .mainDish: return "🍖"
        case .sides: return "🥘"
        case .salads: return "🥗"
        case .breakfast: return "🌅"
        case .snacks: return "🍿"
        case .other: return "🍽️"
        }
    }

    static func infer(name: String, ingredients: String, dateSaved: Date) -> MealCategory {
        let text = (name + " " + ingredients).lowercased()

        let breakfastKeys = ["breakfast", "завтрак", "oatmeal", "каша", "porridge", "pancake", "блин",
                             "waffle", "вафл", "cereal", "мюсли", "granola", "гранола", "toast", "тост",
                             "омлет", "omelette", "scrambled", "яичниц", "aamiainen", "puuro"]
        let saladKeys = ["salad", "салат", "soup", "суп", "борщ", "borscht", "starter", "закуск",
                         "appetizer", "bruschetta", "брускетт", "gazpacho", "keitto", "salaatti",
                         "hummus", "хумус", "bowl", "боул"]
        let snackKeys = ["snack", "перекус", "shake", "шейк", "smoothie", "смузи", "bar", "батончик",
                         "yogurt", "йогурт", "fruit cup", "фрукт", "protein ball",
                         "välipala"]

        let mainDishProtein = ["chicken", "курин", "курица", "beef", "говя", "turkey", "индей",
                               "salmon", "лосось", "fish", "рыб", "pork", "свинин", "steak", "стейк",
                               "lamb", "баранин", "duck", "утк", "tuna", "тунец", "shrimp", "креветк",
                               "kana", "lohi", "nauta", "filee", "pihvi", "liha"]
        let mainDishCarb = ["rice", "рис", "pasta", "паста", "макарон", "potato", "картош",
                            "noodle", "лапш", "riisi", "peruna"]
        let sideKeys = ["rice", "рис", "bread", "хлеб", "couscous", "кускус", "quinoa", "киноа",
                        "mashed", "пюре", "fries", "фри", "buckwheat", "гречк",
                        "oat", "овся", "flatbread", "лаваш", "tortilla", "тортилья",
                        "riisi", "leipä", "kaura"]

        if breakfastKeys.contains(where: { text.contains($0) }) { return .breakfast }
        if saladKeys.contains(where: { text.contains($0) }) { return .salads }
        if snackKeys.contains(where: { text.contains($0) }) { return .snacks }

        let hasProtein = mainDishProtein.contains(where: { text.contains($0) })
        let hasCarb = mainDishCarb.contains(where: { text.contains($0) })
        if hasProtein && hasCarb { return .mainDish }
        if hasProtein { return .mainDish }

        if sideKeys.contains(where: { text.contains($0) }) { return .sides }

        return .other
    }
}

enum FavoritePortionRules {
    private static let packagedKeywords = [
        "yogurt", "йогурт", "skyr", "bar", "батон", "drink", "shake", "milk", "кефир",
        "kefir", "pudding", "творог", "cottage cheese", "alpro", "valio", "protein drink",
        "juice", "cola", "soda", "monster", "red bull"
    ]

    private static let rawStapleKeywords = [
        "фарш", "mince", "ground beef", "ground turkey", "bread", "хлеб", "rice", "рис",
        "pasta", "макарон", "каша", "oat", "овся", "salmon", "лосось", "chicken breast",
        "курин", "beef", "говя", "turkey", "индей", "raw", "сыр"
    ]

    private static let pieceKeywords = [
        "egg", "яйц", "banana", "банан", "apple", "яблок", "slice", "ломтик", "piece", "pcs",
        "flatbread", "лаваш", "лепёшка", "wrap", "tortilla", "тортилья", "cracker", "waffle",
        "вафл", "pancake", "блин", "muffin", "маффин", "cookie", "печень"
    ]

    private static let productSuffixes = [
        "flatbread", "лаваш", "лепёшка", "cake", "торт", "cookie", "печень", "muffin", "маффин",
        "wrap", "tortilla", "тортилья", "cracker", "crisp", "waffle", "вафл", "pancake", "блин",
        "bar", "батончик", "ball", "milk", "молоко", "drink", "напиток", "shake", "smoothie",
        "yogurt", "йогурт", "soup", "суп"
    ]

    static func totalWeightGrams(from ingredients: String) -> Double? {
        let lines = ingredients.split(separator: "\n")
        var total: Double = 0
        var found = false

        for line in lines {
            let parts = line.split(separator: ";")
            guard parts.count >= 2 else { continue }
            let weight = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let range = weight.range(of: #"(\d+(?:\.\d+)?)\s*(?:g\b|gr\b|gram|grams|ml\b)"#, options: .regularExpression) {
                let number = String(weight[range]).filter { $0.isNumber || $0 == "." }
                if let value = Double(number) {
                    total += value
                    found = true
                }
            }
        }

        return found ? total : nil
    }

    static func inferBasis(name: String, ingredients: String) -> (basis: FavoritePortionBasis, weight: Double?) {
        let lowerName = name.lowercased()
        let lowerIngredients = ingredients.lowercased()
        let totalWeight = totalWeightGrams(from: ingredients)

        if lowerIngredients.contains("serving") || lowerIngredients.contains("portion") || lowerIngredients.contains("bowl") {
            return (.perServing, totalWeight)
        }

        if lowerIngredients.contains("pack") || lowerIngredients.contains("bottle") || lowerIngredients.contains("can") {
            return (.perPack, totalWeight)
        }

        if pieceKeywords.contains(where: { lowerName.contains($0) || lowerIngredients.contains($0) }) {
            return (.perPiece, totalWeight)
        }

        if rawStapleKeywords.contains(where: { lowerName.contains($0) }) {
            let isFinishedProduct = productSuffixes.contains(where: { lowerName.contains($0) })
            if !isFinishedProduct {
                if totalWeight != nil {
                    return (.per100g, totalWeight)
                }
                return (.perPack, totalWeight)
            }
        }

        if packagedKeywords.contains(where: { lowerName.contains($0) }) {
            return (.perPack, totalWeight)
        }

        return (.perServing, totalWeight)
    }

    static func quickPresets(for favorite: FavoriteFood) -> [FavoritePortionPreset] {
        switch favorite.portionBasis {
        case .per100g:
            return [
                FavoritePortionPreset(label: "50 g", amount: 50),
                FavoritePortionPreset(label: "100 g", amount: 100),
                FavoritePortionPreset(label: "150 g", amount: 150)
            ]
        case .perServing:
            return [
                FavoritePortionPreset(label: "1/2", amount: 0.5),
                FavoritePortionPreset(label: "1", amount: 1),
                FavoritePortionPreset(label: "2", amount: 2)
            ]
        case .perPack:
            return [
                FavoritePortionPreset(label: "1/2 pack", amount: 0.5),
                FavoritePortionPreset(label: "1 pack", amount: 1),
                FavoritePortionPreset(label: "2 packs", amount: 2)
            ]
        case .perPiece:
            return [
                FavoritePortionPreset(label: "1 piece", amount: 1),
                FavoritePortionPreset(label: "2 pieces", amount: 2),
                FavoritePortionPreset(label: "3 pieces", amount: 3)
            ]
        }
    }

    static func amountLabel(for favorite: FavoriteFood, amount: Double) -> String {
        switch favorite.portionBasis {
        case .per100g:
            return "\(Int(amount.rounded())) g"
        case .perServing:
            return amount == amount.rounded() ? "\(Int(amount)) serving" : String(format: "%.1f servings", amount)
        case .perPack:
            return amount == amount.rounded() ? "\(Int(amount)) pack" : String(format: "%.1f pack", amount)
        case .perPiece:
            return amount == amount.rounded() ? "\(Int(amount)) piece" : String(format: "%.1f piece", amount)
        }
    }
}

@Model
final class FavoriteFood {
    var id: UUID = UUID()
    var createdAt: Date?
    var name: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var ingredients: String = ""
    var portionBasisRaw: String = FavoritePortionBasis.perServing.rawValue
    var portionGramsReference: Double?
    var categoryRaw: String = FridgeCategory.other.rawValue

    @Attribute(.externalStorage) var imageData: Data?

    var category: FridgeCategory {
        get { FridgeCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var portionBasis: FavoritePortionBasis {
        get { FavoritePortionBasis(rawValue: portionBasisRaw) ?? .perServing }
        set { portionBasisRaw = newValue.rawValue }
    }

    var resolvedPortionGramsReference: Double? {
        if let portionGramsReference, portionGramsReference > 0 {
            return portionGramsReference
        }

        return FavoritePortionRules.totalWeightGrams(from: ingredients)
    }

    var basisDisplayText: String {
        switch portionBasis {
        case .per100g:
            if let resolvedPortionGramsReference, resolvedPortionGramsReference > 0 {
                return "Stored as 100 g · pack \(Int(resolvedPortionGramsReference.rounded())) g"
            }
            return "Stored as 100 g"
        case .perServing:
            if let resolvedPortionGramsReference, resolvedPortionGramsReference > 0 {
                return "Stored as 1 serving · \(Int(resolvedPortionGramsReference.rounded())) g"
            }
            return "Stored as 1 serving · grams not set"
        case .perPack:
            if let resolvedPortionGramsReference, resolvedPortionGramsReference > 0 {
                return "Stored as 1 pack · \(Int(resolvedPortionGramsReference.rounded())) g"
            }
            return "Stored as 1 pack"
        case .perPiece:
            return "Stored as 1 piece"
        }
    }

    var quickAddPresets: [FavoritePortionPreset] {
        FavoritePortionRules.quickPresets(for: self)
    }

    var uiImage: UIImage? {
        guard let imageData else { return nil }
        return ImageCache.shared.image(for: id.uuidString, data: imageData)
    }

    init(
        image: UIImage?,
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double = 0,
        fat: Double = 0,
        ingredients: String,
        portionBasis: FavoritePortionBasis? = nil,
        portionGramsReference: Double? = nil
    ) {
        let inferred = FavoritePortionRules.inferBasis(name: name, ingredients: ingredients)
        let resolvedBasis = portionBasis ?? inferred.basis
        let resolvedReference = portionGramsReference ?? inferred.weight
        let normalizedNutrition = FavoriteFood.normalizedNutrition(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            ingredients: ingredients,
            basis: resolvedBasis,
            referenceWeight: resolvedReference
        )

        self.createdAt = Date()
        self.name = name.isEmpty ? "Food" : name
        self.calories = max(0, normalizedNutrition.calories)
        self.protein = max(0, normalizedNutrition.protein)
        self.carbs = max(0, normalizedNutrition.carbs)
        self.fat = max(0, normalizedNutrition.fat)
        self.ingredients = normalizedNutrition.ingredients
        self.portionBasisRaw = resolvedBasis.rawValue
        self.portionGramsReference = resolvedReference
        self.categoryRaw = FridgeCategory.infer(name: name, ingredients: ingredients).rawValue
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }

    func updatePortionBasis(_ basis: FavoritePortionBasis) {
        let previousBasis = portionBasis
        let originalReference = portionGramsReference ?? FavoritePortionRules.totalWeightGrams(from: ingredients)

        let sourceCalories: Double
        let sourceProtein: Double
        let sourceCarbs: Double
        let sourceFat: Double
        let sourceIngredients: String

        if previousBasis == .per100g, let reference = originalReference, reference > 0 {
            let multiplier = reference / 100
            sourceCalories = calories * multiplier
            sourceProtein = protein * multiplier
            sourceCarbs = carbs * multiplier
            sourceFat = fat * multiplier
            sourceIngredients = scaleIngredientBreakdown(ingredients, by: multiplier)
        } else {
            sourceCalories = calories
            sourceProtein = protein
            sourceCarbs = carbs
            sourceFat = fat
            sourceIngredients = ingredients
        }

        let normalized = FavoriteFood.normalizedNutrition(
            calories: sourceCalories,
            protein: sourceProtein,
            carbs: sourceCarbs,
            fat: sourceFat,
            ingredients: sourceIngredients,
            basis: basis,
            referenceWeight: originalReference
        )

        calories = normalized.calories
        protein = normalized.protein
        carbs = normalized.carbs
        fat = normalized.fat
        ingredients = normalized.ingredients
        portionBasis = basis
        portionGramsReference = originalReference
    }

    private static func normalizedNutrition(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        ingredients: String,
        basis: FavoritePortionBasis,
        referenceWeight: Double?
    ) -> (calories: Double, protein: Double, carbs: Double, fat: Double, ingredients: String) {
        guard basis == .per100g, let referenceWeight, referenceWeight > 0 else {
            return (calories, protein, carbs, fat, ingredients)
        }

        let factor = 100 / referenceWeight
        return (
            calories * factor,
            protein * factor,
            carbs * factor,
            fat * factor,
            scaleIngredientBreakdown(ingredients, by: factor)
        )
    }
}

@Model
final class TrainingEntry {
    var id: UUID = UUID()
    var createdAt: Date?
    var name: String = ""
    var caloriesBurned: Double = 0
    var steps: Double?
    var tonnageKg: Double?
    var duration: String = ""
    var date: Date = Date()
    var aiSummary: String?

    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        guard let imageData else { return nil }
        return ImageCache.shared.image(for: id.uuidString, data: imageData)
    }

    init(image: UIImage?, name: String, caloriesBurned: Double, steps: Double? = nil, tonnageKg: Double? = nil, duration: String, date: Date, aiSummary: String? = nil) {
        self.createdAt = Date()
        self.name = name.isEmpty ? "Workout" : name
        self.caloriesBurned = max(0, caloriesBurned)
        self.steps = steps.map { max(0, $0) }
        self.tonnageKg = tonnageKg.map { max(0, $0) }
        self.duration = duration
        self.date = date
        self.aiSummary = aiSummary
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }
}

@Model
final class DailySetup {
    var dateID: String = ""
    var mode: String = "Chill 💤"
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
    var date: Date = Date()
    var weightKg: Double = 0
    var bodyFatPercent: Double?
    var musclePercent: Double?
    var waterPercent: Double?
    var visceralFat: Double?
    var metabolicAge: Double?
    var note: String = ""
    var source: String = "Manual"

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

enum BodyMetricDailyBest {
    static let weightTieTolerance: Double = 0.05

    static func measurementScore(
        bodyFatPercent: Double?,
        musclePercent: Double?,
        waterPercent: Double?,
        visceralFat: Double?,
        metabolicAge: Double?
    ) -> Int {
        [bodyFatPercent, musclePercent, waterPercent, visceralFat, metabolicAge]
            .filter { $0 != nil }
            .count
    }

    static func shouldReplace(
        existingWeight: Double,
        existingScore: Int,
        candidateWeight: Double,
        candidateScore: Int
    ) -> Bool {
        if candidateWeight < existingWeight - weightTieTolerance {
            return true
        }

        if abs(candidateWeight - existingWeight) <= weightTieTolerance {
            return candidateScore > existingScore
        }

        return false
    }

    static func shouldReplace(existing: BodyMetricEntry, candidate: BodyMetricEntry) -> Bool {
        shouldReplace(
            existingWeight: existing.weightKg,
            existingScore: measurementScore(
                bodyFatPercent: existing.bodyFatPercent,
                musclePercent: existing.musclePercent,
                waterPercent: existing.waterPercent,
                visceralFat: existing.visceralFat,
                metabolicAge: existing.metabolicAge
            ),
            candidateWeight: candidate.weightKg,
            candidateScore: measurementScore(
                bodyFatPercent: candidate.bodyFatPercent,
                musclePercent: candidate.musclePercent,
                waterPercent: candidate.waterPercent,
                visceralFat: candidate.visceralFat,
                metabolicAge: candidate.metabolicAge
            )
        )
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
    var name: String = ""
    var isCompleted: Bool = false

    init(name: String) {
        self.name = name
        self.isCompleted = false
    }
}

@Model
final class SavedRecipe {
    var id: UUID = UUID()
    var name: String = ""
    var instructions: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var dateSaved: Date = Date()
    var ingredients: String = ""
    var categoryRaw: String = MealCategory.other.rawValue

    @Attribute(.externalStorage) var imageData: Data?

    var category: MealCategory {
        get { MealCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var uiImage: UIImage? {
        guard let imageData else { return nil }
        return ImageCache.shared.image(for: id.uuidString, data: imageData)
    }

    init(
        image: UIImage? = nil,
        name: String,
        instructions: String,
        calories: Double,
        protein: Double,
        carbs: Double = 0,
        fat: Double = 0,
        ingredients: String = ""
    ) {
        self.name = name.isEmpty ? "Meal" : name
        self.instructions = instructions
        self.calories = max(0, calories)
        self.protein = max(0, protein)
        self.carbs = max(0, carbs)
        self.fat = max(0, fat)
        self.ingredients = ingredients
        self.dateSaved = Date()
        self.categoryRaw = MealCategory.infer(name: name, ingredients: ingredients, dateSaved: Date()).rawValue
        self.imageData = image?.preparedForAppStorage().jpegData(compressionQuality: 0.72)
    }

    var asResult: RecipeResult {
        RecipeResult(
            recipe_name: name,
            cooking_instructions: instructions,
            estimated_calories: calories,
            estimated_protein: protein,
            estimated_carbs: carbs,
            estimated_fat: fat
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
