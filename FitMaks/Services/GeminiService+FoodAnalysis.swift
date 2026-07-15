import Foundation
import UIKit

// MARK: - Food Analysis

extension GeminiService {
    func analyzeImages(images: [UIImage], ignoreCache: Bool = false, completion: @escaping (FoodResult?, String?) -> Void) {
        let cacheKey = foodImageCacheKey(images: images)

        if !ignoreCache, let cacheKey, let cached = cachedFoodImageEstimate(for: cacheKey) {
            completion(cached, nil)
            return
        }

        let prompt = """
        Analyze food as a deterministic nutrition estimator. Consistency is more important than creativity.

        NAMING RULES:
        - food_name MUST be a short, appetizing dish description (2-4 words), NOT a brand or product name.
        - Good: "Herb Chicken & Rice", "Grilled Salmon Bowl", "Томатная паста с пенне". Bad: "Kanan Ohut Fileeleike Yrtti-Valkosipuli", "Risella Boil-in-Bag Basmati Rice".
        - Use the generic food name, not the packaging brand. "Basmati Rice" not "Risella Basmati Rice".
        - Ingredient names in the breakdown should also be generic (e.g. "Chicken breast" not "Kanan Sisäfilee").

        ESTIMATION RULES:
        - Estimate the visible edible portion only.
        - Break the dish into real ingredients only. Do NOT include both the whole dish and its ingredients.
        - Estimate every ingredient weight in grams using the visible plate size.
        - Use normal cooked-food nutrition values. Example anchors: cooked salmon is usually about 200-230 kcal and 20-25g protein per 100g; cooked white rice is usually about 130 kcal and 2-3g protein per 100g; creamy/oily sauces are separate small portions unless clearly large.
        - If uncertain, choose the most likely midpoint, not an extreme.
        - Avoid very large restaurant-size assumptions unless the image clearly shows a large portion.
        - The top-level calories, protein, carbs, and fat MUST equal the sum of the ingredient rows.
        - Any numbers you mention in ai_response_text (calories, protein, carbs, fat) MUST match the top-level totals exactly. Do not quote different numbers in the text.
        - If the same image is analyzed again, return the same ingredient weights and totals.
        - If you can identify the product brand/name but cannot read nutrition values from the label, search for its official nutrition data online.
        \(categoryPromptBlock)

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        \(singleFoodJSONShape)
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines as Item;Weight;Kcal;Protein;Carbs;Fat. Every row MUST have exactly 6 fields. Macro calculation is MANDATORY.
        CONSISTENCY CHECK: Before returning, verify that every number in ai_response_text matches the JSON fields. If they don't match, fix ai_response_text.
        """
        sendToGemini(images: images, prompt: prompt, responseType: FoodResult.self, temperature: 0.0, topP: 0.1, topK: 1, useSearchGrounding: true) { [weak self] result, error in
            let stabilized = result.map { self?.stabilizedFoodResult($0) ?? $0 }

            if let cacheKey, let stabilized {
                self?.cacheFoodImageEstimate(stabilized, for: cacheKey)
            }

            completion(stabilized, error)
        }
    }

    func analyzeText(text: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let cacheKey = normalizedFoodTextCacheKey(text)

        if let cached = cachedFoodTextEstimate(for: cacheKey) {
            completion(cached, nil)
            return
        }

        let prompt = """
        Nutrition expert. User ate: '\(text)'.
        Estimate deterministically. If the user gives no portion size, use a realistic standard serving and do not choose an extreme.
        Break the dish into real ingredients only. Do NOT include both the whole dish and its ingredients.
        The top-level calories, protein, carbs, and fat MUST equal the sum of the ingredient rows.
        Any numbers you mention in ai_response_text MUST match the top-level totals exactly.
        If the user names a specific brand or product, search for its real nutrition data online but use a generic dish name, not the brand name.
        NAMING RULE: food_name must be a short appetizing description (2-4 words), not a brand or product label. Use generic names like "Herb Chicken & Rice" not "Kanan Ohut Fileeleike".
        LANGUAGE RULE: Detect the language the user wrote in. Write food_name, ingredient names, and ai_response_text in that same language.
        \(categoryPromptBlock)

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        \(singleFoodJSONShape)
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines as Item;Weight;Kcal;Protein;Carbs;Fat. Every row MUST have exactly 6 fields. Macro calculation is MANDATORY.
        """
        sendToGemini(images: [], prompt: prompt, responseType: FoodResult.self, temperature: 0.0, topP: 0.1, topK: 1, useSearchGrounding: true) { [weak self] result, error in
            let stabilized = result.map { self?.stabilizedFoodResult($0) ?? $0 }

            if let stabilized {
                self?.cacheFoodTextEstimate(stabilized, for: cacheKey)
            }

            completion(stabilized, error)
        }
    }

    func analyzeFoodItems(images: [UIImage], ignoreCache: Bool = false, completion: @escaping ([FoodResult]?, String?) -> Void) {
        let cacheKey = foodImageCacheKey(images: images)

        if !ignoreCache, let cacheKey, let cached = cachedFoodImageItems(for: cacheKey) {
            completion(cached, nil)
            return
        }

        let prompt = """
        Analyze uploaded food photos as a deterministic nutrition estimator.

        The upload may contain:
        - One dish/product photographed from multiple angles.
        - Several different dishes/products.
        - A product photo plus a nutrition label photo for the same product.

        NAMING RULES:
        - food_name MUST be a short, appetizing dish description (2-4 words), NOT a brand or product name.
        - Good: "Herb Chicken & Rice", "Grilled Salmon Bowl", "Томатная паста с пенне". Bad: "Kanan Ohut Fileeleike Yrtti-Valkosipuli", "Risella Boil-in-Bag Basmati Rice".
        - Use the generic food name, not the packaging brand. "Basmati Rice" not "Risella Basmati Rice".
        - Ingredient names in the breakdown should also be generic (e.g. "Chicken breast" not "Kanan Sisäfilee").

        GROUPING RULES:
        - Return one JSON item per distinct edible dish/product.
        - If two or more photos show the same physical item, merge them into ONE item.
        - If one photo is a nutrition label for another visible product, use the label data for that same item.
        - Do NOT split a single dish into separate top-level items. Put its ingredients in ingredients_breakdown.
        - If there are clearly multiple separate dishes/products, return multiple items.
        - For every returned item, set source_photo_number to the 1-based photo number that best visually represents that item: 1 for the first uploaded photo, 2 for the second, etc.
        - If an item uses a front photo and a label photo, choose the front/visible product photo as source_photo_number. Use the label only for nutrition data.

        ESTIMATION RULES:
        - Estimate the visible edible portion only unless the image clearly shows packaged nutrition for a known serving.
        - Break each dish into real ingredients only. Do NOT include both the whole dish and its ingredients.
        - Estimate every ingredient weight in grams using the visible plate size.
        - Use normal cooked-food nutrition values.
        - If uncertain, choose the most likely midpoint, not an extreme.
        - The top-level calories, protein, carbs, and fat for each item MUST equal the sum of its ingredient rows.
        - Any numbers mentioned in ai_response_text MUST match the top-level totals exactly.
        - If the same images are analyzed again, return the same items, ingredient weights, and totals.
        - If a nutrition label is partially unreadable, or the product weight/nutrition info is missing, search the internet for the exact product name to find accurate nutrition data.
        \(categoryPromptBlock)

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        \(multiFoodJSONShape)
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines as Item;Weight;Kcal;Protein;Carbs;Fat. Every row MUST have exactly 6 fields. Macro calculation is MANDATORY.
        """

        sendToGemini(images: images, prompt: prompt, responseType: FoodItemsResult.self, temperature: 0.0, topP: 0.1, topK: 1, useSearchGrounding: true) { [weak self] result, error in
            let stabilized = result?.items.map { self?.stabilizedFoodResult($0) ?? $0 }

            if let cacheKey, let stabilized {
                self?.cacheFoodImageItems(stabilized, for: cacheKey)
            }

            completion(stabilized, error)
        }
    }

    func refineAnalysis(image: UIImage?, currentData: FoodResult, userComment: String, userName: String? = nil, completion: @escaping (FoodResult?, String?) -> Void) {
        refineAnalysis(images: image.map { [$0] } ?? [], currentData: currentData, userComment: userComment, userName: userName, completion: completion)
    }

    func refineAnalysis(images: [UIImage], currentData: FoodResult, userComment: String, userName: String? = nil, completion: @escaping (FoodResult?, String?) -> Void) {
        let comment = userComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveCommand = comment.isEmpty && !images.isEmpty
            ? "Read the attached nutrition label / package and update the data with exact values from it."
            : comment

        let nameInstruction = userName.map { "The user's name is \($0). Address them by first name in ai_response_text." } ?? ""

        let prompt = """
        ACT AS NUTRITIONIST. \(nameInstruction)
        CURRENT DATA: \(currentData.food_name), \(currentData.calories)kcal, \(currentData.protein)g protein, \(currentData.carbs)g carbs, \(currentData.fat)g fat.
        BREAKDOWN: \(currentData.ingredients_breakdown).
        USER COMMAND: "\(effectiveCommand)".
        CRITICAL RULE: Re-calculate totals based on user command.
        Even if the user asks a question, YOU MUST return a valid JSON. Answer the question or explain changes ONLY in 'ai_response_text'.
        CONSISTENCY: Any nutrition numbers in ai_response_text MUST match the JSON totals. Compute ingredient rows first, then write ai_response_text using those exact totals.
        If you need accurate nutrition data for a product, search the internet.
        LANGUAGE RULE: Detect the language of USER COMMAND. Write food_name, ingredients_breakdown names, and ai_response_text in that same language.
        \(categoryPromptBlock)
        Return ONLY JSON structure: {"food_name": "...", "emoji": "...", "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "ingredients_breakdown": "Item1;100g;100;10;12;3\\nItem2;50g;50;5;8;2", "fridge_category": "proteins", "meal_category": "main_dish", "ai_response_text": "your answer"}
        Every ingredients_breakdown row MUST have exactly 6 semicolon-separated fields: Item;Weight;Kcal;Protein;Carbs;Fat.
        """
        sendToGemini(images: images, prompt: prompt, responseType: FoodResult.self, temperature: 0.0, topP: 0.1, topK: 1, useSearchGrounding: true) { [weak self] result, error in
            if let result {
                completion(self?.stabilizedFoodResult(result) ?? result, nil)
            } else {
                let responseText: String
                if let error, error.hasPrefix("AI_TEXT:") {
                    let text = String(error.dropFirst("AI_TEXT:".count))
                    responseText = text.isEmpty ? "I couldn't process that. Try rephrasing." : text
                } else {
                    responseText = "I couldn't process that request. Try rephrasing or send a different photo."
                }
                let fallback = FoodResult(
                    food_name: currentData.food_name,
                    emoji: currentData.emoji,
                    calories: currentData.calories,
                    protein: currentData.protein,
                    carbs: currentData.carbs,
                    fat: currentData.fat,
                    ingredients_breakdown: currentData.ingredients_breakdown,
                    fridge_category: currentData.fridge_category,
                    meal_category: currentData.meal_category,
                    ai_response_text: responseText
                )
                completion(fallback, nil)
            }
        }
    }

    func invalidateFoodImageCache(for image: UIImage?) {
        guard let image, let key = foodImageCacheKey(images: [image]) else {
            return
        }

        foodCacheQueue.async {
            self.foodImageEstimateCache.removeValue(forKey: key)
            self.foodImageEstimateKeys.removeAll { $0 == key }
            self.foodImageItemsCache.removeValue(forKey: key)
            self.foodImageItemsKeys.removeAll { $0 == key }
        }
    }
}

// MARK: - Food Result Stabilization

extension GeminiService {
    func stabilizedFoodResult(_ result: FoodResult) -> FoodResult {
        let paddedBreakdown = padIngredientRows(result.ingredients_breakdown)
        let rowTotals = nutritionTotals(from: paddedBreakdown)

        guard let rowTotals else {
            return roundedFoodResult(FoodResult(
                food_name: result.food_name,
                emoji: result.emoji,
                source_photo_number: result.source_photo_number,
                calories: result.calories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                ingredients_breakdown: paddedBreakdown,
                fridge_category: result.fridge_category,
                meal_category: result.meal_category,
                ai_response_text: result.ai_response_text
            ))
        }

        let breakdownIncomplete = result.calories > 0 && rowTotals.calories < result.calories * 0.55

        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double

        if breakdownIncomplete {
            calories = result.calories
            protein = result.protein
            carbs = result.carbs
            fat = result.fat
        } else {
            let calorieDifference = abs(rowTotals.calories - result.calories)
            let proteinDifference = abs(rowTotals.protein - result.protein)
            let carbsDifference = abs(rowTotals.carbs - result.carbs)
            let fatDifference = abs(rowTotals.fat - result.fat)
            calories = calorieDifference > max(50, result.calories * 0.12) ? rowTotals.calories : result.calories
            protein = proteinDifference > max(5, result.protein * 0.15) ? rowTotals.protein : result.protein
            carbs = carbsDifference > max(8, max(result.carbs, 20) * 0.18) ? rowTotals.carbs : result.carbs
            fat = fatDifference > max(4, max(result.fat, 10) * 0.18) ? rowTotals.fat : result.fat
        }

        let rounded = roundedFoodResult(
            FoodResult(
                food_name: result.food_name,
                emoji: result.emoji,
                source_photo_number: result.source_photo_number,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                ingredients_breakdown: paddedBreakdown,
                fridge_category: result.fridge_category,
                meal_category: result.meal_category,
                ai_response_text: result.ai_response_text
            )
        )

        let correctedText = correctResponseTextNutrition(
            result.ai_response_text,
            original: (result.calories, result.protein, result.carbs, result.fat),
            corrected: (rounded.calories, rounded.protein, rounded.carbs, rounded.fat)
        )

        return FoodResult(
            food_name: rounded.food_name,
            emoji: rounded.emoji,
            source_photo_number: rounded.source_photo_number,
            calories: rounded.calories,
            protein: rounded.protein,
            carbs: rounded.carbs,
            fat: rounded.fat,
            ingredients_breakdown: rounded.ingredients_breakdown,
            fridge_category: rounded.fridge_category,
            meal_category: rounded.meal_category,
            ai_response_text: correctedText
        )
    }

    private func roundedFoodResult(_ result: FoodResult) -> FoodResult {
        FoodResult(
            food_name: result.food_name,
            emoji: result.emoji,
            source_photo_number: result.source_photo_number,
            calories: max(0, (result.calories / 5).rounded() * 5),
            protein: max(0, result.protein.rounded()),
            carbs: max(0, result.carbs.rounded()),
            fat: max(0, result.fat.rounded()),
            ingredients_breakdown: result.ingredients_breakdown,
            fridge_category: result.fridge_category,
            meal_category: result.meal_category,
            ai_response_text: result.ai_response_text
        )
    }

    private func padIngredientRows(_ breakdown: String) -> String {
        breakdown.components(separatedBy: .newlines).map { line in
            let parts = line.components(separatedBy: ";")
            guard parts.count >= 4, parts.count < 6 else { return line }
            var padded = parts
            while padded.count < 6 { padded.append("0") }
            return padded.joined(separator: ";")
        }.joined(separator: "\n")
    }

    private func nutritionTotals(from breakdown: String) -> (calories: Double, protein: Double, carbs: Double, fat: Double)? {
        var calories = 0.0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var rowCount = 0

        for line in breakdown.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ";")

            guard parts.count >= 4 else {
                continue
            }

            calories += numericValue(from: parts[2])
            protein += numericValue(from: parts[3])
            if parts.count > 4 {
                carbs += numericValue(from: parts[4])
            }
            if parts.count > 5 {
                fat += numericValue(from: parts[5])
            }
            rowCount += 1
        }

        return rowCount > 0 ? (calories, protein, carbs, fat) : nil
    }

    private static let numericAllowedChars = CharacterSet(charactersIn: "0123456789.,-")

    private func numericValue(from string: String) -> Double {
        let cleaned = string
            .unicodeScalars
            .filter { Self.numericAllowedChars.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: ",", with: ".")

        return Double(cleaned) ?? 0
    }

    private func correctResponseTextNutrition(
        _ text: String,
        original: (cal: Double, pro: Double, carbs: Double, fat: Double),
        corrected: (cal: Double, pro: Double, carbs: Double, fat: Double)
    ) -> String {
        guard abs(original.cal - corrected.cal) > 10
                || abs(original.pro - corrected.pro) > 3 else {
            return text
        }

        var result = text

        let replacements: [(Double, Double, String)] = [
            (original.cal, corrected.cal, "kcal"),
            (original.pro, corrected.pro, "g protein"),
            (original.carbs, corrected.carbs, "g carbs"),
            (original.fat, corrected.fat, "g fat"),
        ]

        for (oldVal, newVal, suffix) in replacements where abs(oldVal - newVal) > 1 {
            let oldInts = [String(Int(oldVal.rounded())), String(format: "%.1f", oldVal)]
            for oldStr in oldInts {
                let pattern = oldStr + " " + suffix
                if result.contains(pattern) {
                    result = result.replacingOccurrences(of: pattern, with: "\(Int(newVal.rounded())) \(suffix)")
                }
                let patternNoSpace = oldStr + suffix
                if result.contains(patternNoSpace) {
                    result = result.replacingOccurrences(of: patternNoSpace, with: "\(Int(newVal.rounded()))\(suffix)")
                }
            }
        }

        return result
    }
}
