import Foundation
import UIKit
import CryptoKit

// MARK: - Flexible JSON Decoding Helpers

private extension KeyedDecodingContainer {
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

// MARK: - МОДЕЛИ ОТВЕТОВ ИИ
struct FoodResult: Codable {
    let food_name: String
    let emoji: String?
    var source_photo_number: Int? = nil
    let calories: Double
    let protein: Double
    let ingredients_breakdown: String
    let ai_response_text: String

    private enum CodingKeys: String, CodingKey {
        case food_name, emoji, source_photo_number, calories, protein, ingredients_breakdown, ai_response_text
    }

    init(food_name: String, emoji: String?, source_photo_number: Int? = nil, calories: Double, protein: Double, ingredients_breakdown: String, ai_response_text: String) {
        self.food_name = food_name
        self.emoji = emoji
        self.source_photo_number = source_photo_number
        self.calories = calories
        self.protein = protein
        self.ingredients_breakdown = ingredients_breakdown
        self.ai_response_text = ai_response_text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        food_name = try c.decode(String.self, forKey: .food_name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        source_photo_number = try c.decodeIfPresent(Int.self, forKey: .source_photo_number)
        calories = try c.flexibleDouble(forKey: .calories)
        protein = try c.flexibleDouble(forKey: .protein)
        ingredients_breakdown = (try c.decodeIfPresent(String.self, forKey: .ingredients_breakdown)) ?? ""
        ai_response_text = (try c.decodeIfPresent(String.self, forKey: .ai_response_text)) ?? ""
    }
}

struct TrainingResult: Codable {
    let activity_name: String
    let calories_burned: Double
    let steps: Double?
    let day_mode: String?
    let duration: String
    let ai_summary: String

    private enum CodingKeys: String, CodingKey {
        case activity_name, calories_burned, steps, day_mode, duration, ai_summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activity_name = try c.decode(String.self, forKey: .activity_name)
        calories_burned = try c.flexibleDouble(forKey: .calories_burned)
        steps = try c.flexibleOptionalDouble(forKey: .steps)
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

    private enum CodingKeys: String, CodingKey {
        case recipe_name, cooking_instructions, estimated_calories, estimated_protein
    }

    init(recipe_name: String, cooking_instructions: String, estimated_calories: Double, estimated_protein: Double) {
        self.recipe_name = recipe_name
        self.cooking_instructions = cooking_instructions
        self.estimated_calories = estimated_calories
        self.estimated_protein = estimated_protein
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recipe_name = try c.decode(String.self, forKey: .recipe_name)
        cooking_instructions = (try c.decodeIfPresent(String.self, forKey: .cooking_instructions)) ?? ""
        estimated_calories = try c.flexibleDouble(forKey: .estimated_calories)
        estimated_protein = try c.flexibleDouble(forKey: .estimated_protein)
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

private struct GeminiAPIErrorResponse: Decodable {
    struct APIError: Decodable {
        let code: Int?
        let message: String?
    }

    let error: APIError
}

// MARK: - СЕРВИС GEMINI
class GeminiService {
    static let shared = GeminiService()
    private let apiKey = Config.apiKey
    
    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    private let foodCacheQueue = DispatchQueue(label: "FitMaks.foodEstimateCache")
    private var foodImageEstimateCache: [String: FoodResult] = [:]
    private var foodImageItemsCache: [String: [FoodResult]] = [:]
    private var foodTextEstimateCache: [String: FoodResult] = [:]
    
    func analyzeImages(images: [UIImage], ignoreCache: Bool = false, completion: @escaping (FoodResult?, String?) -> Void) {
        let cacheKey = foodImageCacheKey(images: images)

        if !ignoreCache, let cacheKey, let cached = cachedFoodImageEstimate(for: cacheKey) {
            completion(cached, nil)
            return
        }

        let prompt = """
        Analyze food as a deterministic nutrition estimator. Consistency is more important than creativity.

        ESTIMATION RULES:
        - Estimate the visible edible portion only.
        - Break the dish into real ingredients only. Do NOT include both the whole dish and its ingredients.
        - Estimate every ingredient weight in grams using the visible plate size.
        - Use normal cooked-food nutrition values. Example anchors: cooked salmon is usually about 200-230 kcal and 20-25g protein per 100g; cooked white rice is usually about 130 kcal and 2-3g protein per 100g; creamy/oily sauces are separate small portions unless clearly large.
        - If uncertain, choose the most likely midpoint, not an extreme.
        - Avoid very large restaurant-size assumptions unless the image clearly shows a large portion.
        - The top-level calories and protein MUST equal the sum of the ingredient rows.
        - If the same image is analyzed again, return the same ingredient weights and totals.
        - If you can identify the product brand/name but cannot read nutrition values from the label, search for its official nutrition data online.

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "ingredients_breakdown": "Item1;100g;100;10\\nItem2;50g;50;5", "ai_response_text": ""}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines. Protein calculation is MANDATORY.
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
        The top-level calories and protein MUST equal the sum of the ingredient rows.
        If the user names a specific brand or product, search for its real nutrition data online.
        LANGUAGE RULE: Detect the language the user wrote in. Write food_name, ingredient names, and ai_response_text in that same language.

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "ingredients_breakdown": "Item1;100g;100;10\\nItem2;50g;50;5", "ai_response_text": ""}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines.
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
        - The top-level calories and protein for each item MUST equal the sum of its ingredient rows.
        - If the same images are analyzed again, return the same items, ingredient weights, and totals.
        - If a nutrition label is partially unreadable, or the product weight/nutrition info is missing, search the internet for the exact product name to find accurate nutrition data.

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        {"items":[{"food_name":"Dish Name","emoji":"🍽️","source_photo_number":1,"calories":0,"protein":0,"ingredients_breakdown":"Item1;100g;100;10\\nItem2;50g;50;5","ai_response_text":""}]}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines. Protein calculation is MANDATORY.
        """

        sendToGemini(images: images, prompt: prompt, responseType: FoodItemsResult.self, temperature: 0.0, topP: 0.1, topK: 1, useSearchGrounding: true) { [weak self] result, error in
            let stabilized = result?.items.map { self?.stabilizedFoodResult($0) ?? $0 }

            if let cacheKey, let stabilized {
                self?.cacheFoodImageItems(stabilized, for: cacheKey)
            }

            completion(stabilized, error)
        }
    }
    
    func refineAnalysis(image: UIImage?, currentData: FoodResult, userComment: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let comment = userComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveCommand = comment.isEmpty && image != nil
            ? "Read the attached nutrition label / package and update the data with exact values from it."
            : comment

        let prompt = """
        ACT AS NUTRITIONIST.
        CURRENT DATA: \(currentData.food_name), \(currentData.calories)kcal, \(currentData.protein)g prot.
        BREAKDOWN: \(currentData.ingredients_breakdown).
        USER COMMAND: "\(effectiveCommand)".
        CRITICAL RULE: Re-calculate totals based on user command.
        Even if the user asks a question, YOU MUST return a valid JSON. Answer the question or explain changes ONLY in 'ai_response_text'.
        If you need accurate nutrition data for a product, search the internet.
        LANGUAGE RULE: Detect the language of USER COMMAND. Write food_name, ingredients_breakdown names, and ai_response_text in that same language.
        Return ONLY JSON structure: {"food_name": "...", "emoji": "...", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;Weight;Kcal;Prot", "ai_response_text": "your answer"}
        """
        let imgs = image != nil ? [image!] : []
        sendToGemini(images: imgs, prompt: prompt, responseType: FoodResult.self, temperature: 0.0, topP: 0.1, topK: 1, useSearchGrounding: true) { [weak self] result, error in
            completion(result.map { self?.stabilizedFoodResult($0) ?? $0 }, error)
        }
    }

    func analyzeTrainingImages(images: [UIImage], completion: @escaping (TrainingResult?, String?) -> Void) {
        let prompt = """
        Extract workout stats from a fitness app screenshot (any app: Whoop, Apple Fitness, Strava, Garmin, Samsung Health, Fitbit, Nike Run Club, MyFitnessPal, or any other).
        Read EVERY visible metric: calories, duration, distance, heart rate, steps, strain, etc.
        Return ONLY a single JSON object.

        RULES:
        - "activity_name": a clear, descriptive name for the workout.
        - "calories_burned": total active calories from the session. Use 0 if not visible.
        - "steps": step count if visible, otherwise null.
        - "duration": workout duration as shown (e.g. "45 min", "1h 12m"). Use "" if not visible.
        - "day_mode": classify as "cardio" (running, cycling, sports, walking), "gym" (strength, weights, resistance), "mixed" (both), or null.
        - "ai_summary": a short 1-2 sentence summary including ALL key metrics you found (avg HR, max HR, distance, strain, zones, pace, reps, sets — anything useful). Be specific with numbers.

        LANGUAGE RULE: Detect the language visible in the screenshot. Write activity_name and ai_summary in that same language.

        CRITICAL RULE: You MUST use exactly this structure:
        {"activity_name": "...", "calories_burned": 0, "steps": null, "day_mode": null, "duration": "...", "ai_summary": "..."}
        """
        sendToGemini(images: images, prompt: prompt, responseType: TrainingResult.self, temperature: 0.1, topP: 0.3, topK: 1, completion: completion)
    }

    func analyzeBodyMetrics(images: [UIImage], note: String, completion: @escaping (BodyMetricScanResult?, String?) -> Void) {
        let prompt = """
        Extract body scale metrics from the user's input. The input may be:
        - Text typed by the user.
        - A screenshot from a smart scale app.
        - A camera photo of a scale display.

        Read only values that are visible or explicitly typed. Do not invent missing metrics.
        Normalize values:
        - weight_kg must be kilograms.
        - body_fat_percent, muscle_percent, and water_percent must be percentages without the % sign.
        - visceral_fat is a scale/index number if visible.
        - metabolic_age is years if visible.
        - measured_date must be YYYY-MM-DD if a date is visible or explicitly typed.

        User typed note: "\(note)"

        Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        {"measured_date": null, "weight_kg": 0, "body_fat_percent": null, "muscle_percent": null, "water_percent": null, "visceral_fat": null, "metabolic_age": null, "ai_summary": "short useful insight"}
        If weight is not visible or not typed, set weight_kg to null.
        If no date is visible or typed, set measured_date to null.
        Keep ai_summary under 2 short sentences.
        LANGUAGE RULE: If the user typed a note, detect its language and write ai_summary in that same language. Otherwise use English.
        """

        sendToGemini(images: images, prompt: prompt, responseType: BodyMetricScanResult.self, temperature: 0.0, topP: 0.1, topK: 1, completion: completion)
    }

    func generateRecipes(from ingredients: [String], completion: @escaping ([RecipeResult]?, String?) -> Void) {
        let list = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star fitness chef. I have these ingredients: \(list).
        Suggest 3 DISTINCT, healthy and high-protein recipes combining SOME or ALL of them.
        Use MARKDOWN formatting for instructions (bolding, bullets, emojis).
        LANGUAGE RULE: Detect the language of the ingredient names. Write recipe_name and cooking_instructions in that same language.
        Return ONLY valid JSON:
        {"recipes": [ {"recipe_name": "...", "cooking_instructions": "...", "estimated_calories": 450, "estimated_protein": 35} ]}
        """
        sendToGemini(images: [], prompt: prompt, responseType: RecipeListResult.self, temperature: 0.7) { result, error in completion(result?.recipes, error) }
    }
    
    func scanGroceries(images: [UIImage], completion: @escaping ([FoodResult]?, String?) -> Void) {
        let prompt = """
        Extract all individual food items from this grocery receipt or image. 
        For each item, estimate calories and protein per 100g. 
        Return ONLY JSON: 
        {"items": [{"food_name": "...", "emoji": "🍎", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;100g;0;0", "ai_response_text": ""}]}
        """
        sendToGemini(images: images, prompt: prompt, responseType: GroceryListResult.self, temperature: 0.1, topP: 0.3, topK: 1) { result, err in completion(result?.items, err) }
    }

    func invalidateFoodImageCache(for image: UIImage?) {
        guard let image, let key = foodImageCacheKey(images: [image]) else {
            return
        }

        foodCacheQueue.async {
            self.foodImageEstimateCache.removeValue(forKey: key)
            self.foodImageItemsCache.removeValue(forKey: key)
        }
    }
    
    // 🔥 ОБНОВЛЕННЫЙ ЧАТ С ИИ-ТРЕНЕРОМ (УМЕЕТ В ПРОШЛОЕ И ВИДИТ ХОЛОДИЛЬНИК) 🔥
    func sendCoachMessage(image: UIImage?, message: String, isInitial: Bool, isPastDay: Bool, selectedDateDescription: String, selectedDateRelation: String, timeOfDay: String, consumedCalories: Double, consumedProtein: Double, targetCalories: Double, targetProtein: Double, meals: [String], workouts: [String], fridgeItems: [String], completion: @escaping (String?, String?) -> Void) {
        
        let dayContext = isPastDay
            ? "Selected date: \(selectedDateDescription). Date relation: \(selectedDateRelation). You are evaluating a PAST DAY that is already over. Evaluate their overall performance for that entire selected date. DO NOT suggest what to eat or do 'later today'."
            : "Selected date: \(selectedDateDescription). Date relation: \(selectedDateRelation). Current time: \(timeOfDay). The day is still ongoing."
            
        let fridgeContext = (!isPastDay && !fridgeItems.isEmpty)
            ? "Available food in their Fridge: \(fridgeItems.joined(separator: ", ")). Recommend SPECIFIC items from this list if they need to hit their protein or calorie goals today."
            : ""
            
        let prompt = """
        You are a strict, honest, and highly motivating fitness and nutrition coach.
        \(dayContext)
        User's daily calorie ceiling: \(Int(targetCalories)) kcal. User's protein minimum: \(Int(targetProtein))g protein.
        Progress: \(Int(consumedCalories)) kcal consumed, \(Int(consumedProtein))g protein consumed.
        Meals eaten: \(meals.isEmpty ? "None" : meals.joined(separator: ", ")).
        Workouts done: \(workouts.isEmpty ? "None" : workouts.joined(separator: ", ")).
        \(fridgeContext)

        \(isInitial ? (isPastDay ? "Give a quick summary of their performance for this selected past date." : "The user just opened the app. Give them a quick daily summary and motivation based on current time.") : "The user says/shows: '\(message)'. Reply to them directly in the context of the selected date.")

        CRITICAL RULES:
        1. Evaluate food quality. If they ate junk food, sugar, or excess fat, scold them slightly but constructively. Praise good protein intake.
        2. If it's a PAST DAY, summarize their success or failure. If it's the CURRENT DAY, motivate them and suggest exact foods from their Fridge to hit remaining goals.
        3. Be direct, use quick humor, and don't sugar-coat.
        4. Keep it concise (under 5 sentences). Use emojis.
        5. Never call the selected date "yesterday" unless Date relation is exactly "yesterday". For older dates, use the exact selected date or say "that day".
        6. Treat calories as an upper limit / deficit target, not a minimum. Being under the calorie ceiling is GOOD unless calories are extremely low and clearly unhealthy. Do NOT say they failed because they did not eat all calories.
        7. Protein is a minimum target. Being under protein is bad; being over protein is good.
        8. Detect the language of the user's message. Reply in that same language. If this is an initial summary with no user message, reply in English.

        Return ONLY a single JSON object:
        {"ai_summary": "your response here"}
        """
        let imgs = image != nil ? [image!] : []
        sendToGemini(images: imgs, prompt: prompt, responseType: DailySummaryResult.self, temperature: 0.6) { result, error in
            completion(result?.ai_summary, error)
        }
    }

    private func sendToGemini<T: Decodable>(
        images: [UIImage],
        prompt: String,
        responseType: T.Type,
        temperature: Double = 0.2,
        topP: Double? = nil,
        topK: Int? = nil,
        useSearchGrounding: Bool = false,
        completion: @escaping (T?, String?) -> Void
    ) {
        func finish(_ result: T?, _ error: String?) {
            DispatchQueue.main.async {
                completion(result, error)
            }
        }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty else {
            finish(nil, "Gemini API key is missing.")
            return
        }

        var parts: [[String: Any]] = [["text": prompt]]
        for image in images { if let data = image.resized(toMaxDimension: 768).jpegData(compressionQuality: 0.5)?.base64EncodedString() { parts.append(["inline_data": ["mime_type": "image/jpeg", "data": data]]) } }

        guard
            var components = URLComponents(string: baseUrl)
        else {
            finish(nil, "Gemini URL is invalid.")
            return
        }

        components.queryItems = [URLQueryItem(name: "key", value: trimmedAPIKey)]

        guard let url = components.url else {
            finish(nil, "Gemini URL is invalid.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var generationConfig: [String: Any] = [
            "response_mime_type": "application/json",
            "temperature": temperature
        ]

        if let topP {
            generationConfig["topP"] = topP
        }

        if let topK {
            generationConfig["topK"] = topK
        }

        var body: [String: Any] = ["contents": [["parts": parts]], "generationConfig": generationConfig]
        if useSearchGrounding {
            body["tools"] = [["google_search": [String: Any]()]]
        }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            finish(nil, "Failed to encode Gemini request.")
            return
        }

        request.httpBody = bodyData

        performRequest(request, responseType: responseType, retriesRemaining: 2, completion: finish)
    }

    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        retriesRemaining: Int,
        completion: @escaping (T?, String?) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                if retriesRemaining > 0, self.isRetryableError(error) {
                    let delay = Double(3 - retriesRemaining)
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequest(request, responseType: responseType, retriesRemaining: retriesRemaining - 1, completion: completion)
                    }
                    return
                }
                completion(nil, self.userFacingErrorMessage(error.localizedDescription))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, "No response from Gemini.")
                return
            }

            guard let data else {
                completion(nil, "Gemini returned an empty response.")
                return
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if retriesRemaining > 0, self.isRetryableStatusCode(httpResponse.statusCode) {
                    let delay = Double(3 - retriesRemaining)
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequest(request, responseType: responseType, retriesRemaining: retriesRemaining - 1, completion: completion)
                    }
                    return
                }

                if let apiError = try? JSONDecoder().decode(GeminiAPIErrorResponse.self, from: data) {
                    completion(nil, apiError.error.message ?? "Gemini request failed with code \(httpResponse.statusCode).")
                    return
                }

                let responseText = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                completion(nil, responseText?.isEmpty == false ? responseText : "Gemini request failed with code \(httpResponse.statusCode).")
                return
            }

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = json["candidates"] as? [[String: Any]],
                let content = candidates.first?["content"] as? [String: Any],
                let resultParts = content["parts"] as? [[String: Any]],
                let rawText = resultParts.first?["text"] as? String
            else {
                if let apiError = try? JSONDecoder().decode(GeminiAPIErrorResponse.self, from: data) {
                    completion(nil, apiError.error.message ?? "Invalid Gemini response.")
                } else {
                    completion(nil, "Invalid Gemini response.")
                }
                return
            }

            var cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let mdQuotes = "`" + "`" + "`"
            if cleanText.contains(mdQuotes) {
                cleanText = cleanText.replacingOccurrences(of: mdQuotes + "json", with: "")
                cleanText = cleanText.replacingOccurrences(of: mdQuotes, with: "")
            }

            guard
                let start = cleanText.firstIndex(of: "{"),
                let end = cleanText.lastIndex(of: "}"),
                let finalData = String(cleanText[start...end]).data(using: .utf8)
            else {
                completion(nil, "Gemini returned invalid JSON.")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: finalData)
                completion(decoded, nil)
            } catch {
                completion(nil, "Failed to decode Gemini response.")
            }
        }.resume()
    }

    private func isRetryableError(_ error: Error) -> Bool {
        let code = (error as NSError).code
        return [
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDNSLookupFailed
        ].contains(code)
    }

    private func isRetryableStatusCode(_ code: Int) -> Bool {
        [429, 500, 502, 503, 504].contains(code)
    }

    private func userFacingErrorMessage(_ message: String) -> String {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.lowercased().contains("cancelled") {
            return "The AI request was interrupted. Please try again."
        }

        return normalized.isEmpty ? "The AI request failed. Please try again." : normalized
    }

    private func stabilizedFoodResult(_ result: FoodResult) -> FoodResult {
        let rowTotals = nutritionTotals(from: result.ingredients_breakdown)

        guard let rowTotals else {
            return roundedFoodResult(result)
        }

        let calorieDifference = abs(rowTotals.calories - result.calories)
        let proteinDifference = abs(rowTotals.protein - result.protein)
        let calories = calorieDifference > max(50, result.calories * 0.12) ? rowTotals.calories : result.calories
        let protein = proteinDifference > max(5, result.protein * 0.15) ? rowTotals.protein : result.protein

        return roundedFoodResult(
            FoodResult(
                food_name: result.food_name,
                emoji: result.emoji,
                source_photo_number: result.source_photo_number,
                calories: calories,
                protein: protein,
                ingredients_breakdown: result.ingredients_breakdown,
                ai_response_text: result.ai_response_text
            )
        )
    }

    private func roundedFoodResult(_ result: FoodResult) -> FoodResult {
        FoodResult(
            food_name: result.food_name,
            emoji: result.emoji,
            source_photo_number: result.source_photo_number,
            calories: max(0, (result.calories / 5).rounded() * 5),
            protein: max(0, result.protein.rounded()),
            ingredients_breakdown: result.ingredients_breakdown,
            ai_response_text: result.ai_response_text
        )
    }

    private func nutritionTotals(from breakdown: String) -> (calories: Double, protein: Double)? {
        var calories = 0.0
        var protein = 0.0
        var rowCount = 0

        for line in breakdown.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ";")

            guard parts.count >= 4 else {
                continue
            }

            calories += numericValue(from: parts[2])
            protein += numericValue(from: parts[3])
            rowCount += 1
        }

        return rowCount > 0 ? (calories, protein) : nil
    }

    private func numericValue(from string: String) -> Double {
        let allowed = CharacterSet(charactersIn: "0123456789.,-")
        let cleaned = string
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: ",", with: ".")

        return Double(cleaned) ?? 0
    }

    private func foodImageCacheKey(images: [UIImage]) -> String? {
        let fingerprints = images.compactMap { perceptualFingerprint(for: $0) }

        guard !fingerprints.isEmpty else {
            return nil
        }

        let combined = fingerprints.joined(separator: "|")

        return SHA256.hash(data: Data(combined.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func perceptualFingerprint(for image: UIImage) -> String? {
        let size = CGSize(width: 16, height: 16)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let cgImage = resized.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var brightness: [Double] = []
        brightness.reserveCapacity(width * height)

        for pixel in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[pixel])
            let green = Double(pixels[pixel + 1])
            let blue = Double(pixels[pixel + 2])
            brightness.append((red * 0.299) + (green * 0.587) + (blue * 0.114))
        }

        guard !brightness.isEmpty else {
            return nil
        }

        let average = brightness.reduce(0, +) / Double(brightness.count)
        return brightness.map { $0 >= average ? "1" : "0" }.joined()
    }

    private func normalizedFoodTextCacheKey(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func cachedFoodImageEstimate(for key: String) -> FoodResult? {
        foodCacheQueue.sync {
            foodImageEstimateCache[key]
        }
    }

    private func cacheFoodImageEstimate(_ result: FoodResult, for key: String) {
        foodCacheQueue.async {
            self.foodImageEstimateCache[key] = result
        }
    }

    private func cachedFoodImageItems(for key: String) -> [FoodResult]? {
        foodCacheQueue.sync {
            foodImageItemsCache[key]
        }
    }

    private func cacheFoodImageItems(_ result: [FoodResult], for key: String) {
        foodCacheQueue.async {
            self.foodImageItemsCache[key] = result
        }
    }

    private func cachedFoodTextEstimate(for key: String) -> FoodResult? {
        foodCacheQueue.sync {
            foodTextEstimateCache[key]
        }
    }

    private func cacheFoodTextEstimate(_ result: FoodResult, for key: String) {
        foodCacheQueue.async {
            self.foodTextEstimateCache[key] = result
        }
    }
}

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

    func scanGroceriesAsync(images: [UIImage]) async -> ([FoodResult]?, String?) {
        await withCheckedContinuation { continuation in
            scanGroceries(images: images) { result, error in
                continuation.resume(returning: (result, error))
            }
        }
    }
}

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        guard size.width > 0, size.height > 0 else {
            return self
        }

        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return self
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func preparedForAIIntake(maxDimension: CGFloat = 1280) -> UIImage {
        resized(toMaxDimension: maxDimension)
    }

    func preparedForAppStorage(maxDimension: CGFloat = 900) -> UIImage {
        resized(toMaxDimension: maxDimension)
    }
}
