import Foundation

// MARK: - Flexible JSON Decoding Helpers

extension KeyedDecodingContainer {
    func flexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let str = try? decode(String.self, forKey: key), let value = Double(str) { return value }
        return try decode(Double.self, forKey: key)
    }

    func flexibleOptionalDouble(forKey key: Key) throws -> Double? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let str = try? decode(String.self, forKey: key) { return Double(str) }
        return nil
    }
}

// MARK: - AI Response Models

struct FoodResult: Codable {
    let food_name: String
    let emoji: String?
    var source_photo_number: Int? = nil
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let ingredients_breakdown: String
    let fridge_category: String?
    let meal_category: String?
    let ai_response_text: String

    private enum CodingKeys: String, CodingKey {
        case food_name, emoji, source_photo_number, calories, protein, carbs, fat, ingredients_breakdown, fridge_category, meal_category, ai_response_text
    }

    init(
        food_name: String,
        emoji: String?,
        source_photo_number: Int? = nil,
        calories: Double,
        protein: Double,
        carbs: Double = 0,
        fat: Double = 0,
        ingredients_breakdown: String,
        fridge_category: String? = nil,
        meal_category: String? = nil,
        ai_response_text: String
    ) {
        self.food_name = food_name
        self.emoji = emoji
        self.source_photo_number = source_photo_number
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.ingredients_breakdown = ingredients_breakdown
        self.fridge_category = fridge_category
        self.meal_category = meal_category
        self.ai_response_text = ai_response_text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        food_name = try c.decode(String.self, forKey: .food_name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        source_photo_number = try c.decodeIfPresent(Int.self, forKey: .source_photo_number)
        calories = try c.flexibleDouble(forKey: .calories)
        protein = try c.flexibleDouble(forKey: .protein)
        carbs = (try? c.flexibleDouble(forKey: .carbs)) ?? 0
        fat = (try? c.flexibleDouble(forKey: .fat)) ?? 0
        ingredients_breakdown = (try c.decodeIfPresent(String.self, forKey: .ingredients_breakdown)) ?? ""
        fridge_category = try c.decodeIfPresent(String.self, forKey: .fridge_category)
        meal_category = try c.decodeIfPresent(String.self, forKey: .meal_category)
        ai_response_text = (try c.decodeIfPresent(String.self, forKey: .ai_response_text)) ?? ""
    }
}

struct TrainingResult: Codable {
    let activity_name: String
    let calories_burned: Double
    let steps: Double?
    let tonnage_kg: Double?
    let day_mode: String?
    let duration: String
    let ai_summary: String

    private enum CodingKeys: String, CodingKey {
        case activity_name, calories_burned, steps, tonnage_kg, day_mode, duration, ai_summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activity_name = try c.decode(String.self, forKey: .activity_name)
        calories_burned = try c.flexibleDouble(forKey: .calories_burned)
        steps = try c.flexibleOptionalDouble(forKey: .steps)
        tonnage_kg = try c.flexibleOptionalDouble(forKey: .tonnage_kg)
        day_mode = try c.decodeIfPresent(String.self, forKey: .day_mode)
        duration = (try c.decodeIfPresent(String.self, forKey: .duration)) ?? ""
        ai_summary = (try c.decodeIfPresent(String.self, forKey: .ai_summary)) ?? ""
    }
}

struct RecipeResult: Codable, Identifiable {
    var id: String { recipe_name }
    let recipe_name: String
    let cooking_instructions: String
    let estimated_calories: Double
    let estimated_protein: Double
    let estimated_carbs: Double
    let estimated_fat: Double

    private enum CodingKeys: String, CodingKey {
        case recipe_name, cooking_instructions, estimated_calories, estimated_protein, estimated_carbs, estimated_fat
    }

    init(
        recipe_name: String,
        cooking_instructions: String,
        estimated_calories: Double,
        estimated_protein: Double,
        estimated_carbs: Double = 0,
        estimated_fat: Double = 0
    ) {
        self.recipe_name = recipe_name
        self.cooking_instructions = cooking_instructions
        self.estimated_calories = estimated_calories
        self.estimated_protein = estimated_protein
        self.estimated_carbs = estimated_carbs
        self.estimated_fat = estimated_fat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recipe_name = try c.decode(String.self, forKey: .recipe_name)
        cooking_instructions = (try c.decodeIfPresent(String.self, forKey: .cooking_instructions)) ?? ""
        estimated_calories = try c.flexibleDouble(forKey: .estimated_calories)
        estimated_protein = try c.flexibleDouble(forKey: .estimated_protein)
        estimated_carbs = (try? c.flexibleDouble(forKey: .estimated_carbs)) ?? 0
        estimated_fat = (try? c.flexibleDouble(forKey: .estimated_fat)) ?? 0
    }
}

struct RecipeListResult: Codable {
    let recipes: [RecipeResult]
}

struct GroceryListResult: Codable {
    let items: [FoodResult]
}

struct FoodItemsResult: Codable {
    let items: [FoodResult]
}

struct DailySummaryResult: Codable {
    let ai_summary: String
}

struct BodyMetricScanResult: Codable {
    let measured_date: String?
    let weight_kg: Double?
    let body_fat_percent: Double?
    let muscle_percent: Double?
    let water_percent: Double?
    let visceral_fat: Double?
    let metabolic_age: Double?
    let ai_summary: String

    private enum CodingKeys: String, CodingKey {
        case measured_date, weight_kg, body_fat_percent, muscle_percent, water_percent, visceral_fat, metabolic_age, ai_summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        measured_date = try c.decodeIfPresent(String.self, forKey: .measured_date)
        weight_kg = try c.flexibleOptionalDouble(forKey: .weight_kg)
        body_fat_percent = try c.flexibleOptionalDouble(forKey: .body_fat_percent)
        muscle_percent = try c.flexibleOptionalDouble(forKey: .muscle_percent)
        water_percent = try c.flexibleOptionalDouble(forKey: .water_percent)
        visceral_fat = try c.flexibleOptionalDouble(forKey: .visceral_fat)
        metabolic_age = try c.flexibleOptionalDouble(forKey: .metabolic_age)
        ai_summary = (try c.decodeIfPresent(String.self, forKey: .ai_summary)) ?? ""
    }
}
