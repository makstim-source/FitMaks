import Foundation
import UIKit

// MARK: - Training & Workout Analysis

extension GeminiService {
    func analyzeTrainingImages(images: [UIImage], completion: @escaping (TrainingResult?, String?) -> Void) {
        let prompt = """
        Extract workout stats from a fitness app screenshot (any app: Whoop, Apple Fitness, Strava, Garmin, Samsung Health, Fitbit, Nike Run Club, MyFitnessPal, or any other).
        Read EVERY visible metric: calories, duration, distance, heart rate, steps, strain, etc.
        Return ONLY a single JSON object.

        RULES:
        - "activity_name": a clear, descriptive name for the workout. Prefer the exact sport or session type if visible (e.g. "Padel", "Outdoor Run", "Cycling", "Leg Day", "Upper Body", "Treadmill Walk") instead of generic labels like "Workout".
        - "calories_burned": total active calories from the session. Use 0 if not visible.
        - "steps": step count if visible, otherwise null.
        - "tonnage_kg": for strength workouts only, estimate total lifted tonnage in kilograms if sets/reps/weights are visible. Otherwise null.
        - "duration": workout duration as shown (e.g. "45 min", "1h 12m"). Use "" if not visible.
        - "day_mode": classify as "cardio" (running, cycling, sports, walking), "gym" (strength, weights, resistance), "mixed" (both), or null.
        - "ai_summary": a short 1-2 sentence summary including ALL key metrics you found (avg HR, max HR, distance, strain, zones, pace, reps, sets — anything useful). Be specific with numbers.

        LANGUAGE RULE: Detect the language visible in the screenshot. Write activity_name and ai_summary in that same language.

        CRITICAL RULE: You MUST use exactly this structure:
        {"activity_name": "...", "calories_burned": 0, "steps": null, "tonnage_kg": null, "day_mode": null, "duration": "...", "ai_summary": "..."}
        """
        sendToGemini(images: images, prompt: prompt, responseType: TrainingResult.self, temperature: 0.1, topP: 0.3, topK: 1, completion: completion)
    }

    func analyzeTrainingText(text: String, completion: @escaping (TrainingResult?, String?) -> Void) {
        let prompt = """
        You are a fitness coach AI. The user described their workout in text: "\(text)"

        Parse the workout and return stats. The user may write in ANY language (Russian, English, Spanish, etc.).
        Common examples:
        - "Падел 2 часа" → Padel, 2h
        - "Бег 5км 30 мин" → Running, 5km, 30 min
        - "Legs and glutes: Hinge 12kg x4x10, Romanian deadlift 11.5kg x3x10, Hyperextension 8kg x3x10" → Leg Day, estimate tonnage
        - "Swimming 45 min" → Swimming, 45 min

        RULES:
        - "activity_name": the exact sport or session type. Use the user's language. Recognize: padel/падел, бег/run, плавание/swimming, велосипед/cycling, зал/gym, ходьба/walk, теннис/tennis, йога/yoga, бокс/boxing, футбол/football, баскетбол/basketball, etc.
        - "calories_burned": estimate realistic calories based on the activity, duration, and moderate intensity. Use 0 only if you truly cannot estimate.
        - "steps": estimate steps if it's a walking/running activity, otherwise null.
        - "tonnage_kg": for strength workouts, calculate total tonnage from sets × reps × weight. Otherwise null.
        - "duration": as described by user (e.g. "2h", "45 min"). Use "" if not mentioned.
        - "day_mode": "cardio" (running, cycling, sports, swimming, walking), "gym" (strength, weights), "mixed" (both), or null.
        - "ai_summary": 1-2 sentence summary with key metrics. Write in the user's language.

        CRITICAL RULE: Return ONLY a single JSON object:
        {"activity_name": "...", "calories_burned": 0, "steps": null, "tonnage_kg": null, "day_mode": null, "duration": "...", "ai_summary": "..."}
        """
        sendToGemini(images: [], prompt: prompt, responseType: TrainingResult.self, temperature: 0.1, topP: 0.3, topK: 1, useSearchGrounding: true, completion: completion)
    }
}

// MARK: - Body Metrics

extension GeminiService {
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

    func analyzeWeightTrend(
        weightEntries: [(date: String, weight: Double)],
        targetCalories: Int,
        targetProtein: Int,
        userName: String? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        guard !weightEntries.isEmpty else {
            completion(nil, "No weight data to analyze.")
            return
        }

        let nameContext = userName.map { "The user's name is \($0). Address them by first name." } ?? ""
        let weightLines = weightEntries.map { "\($0.date): \($0.weight) kg" }.joined(separator: "\n")
        let firstDate = weightEntries.first!.date
        let lastDate = weightEntries.last!.date
        let entryCount = weightEntries.count

        let prompt = """
        You are a sharp, data-driven body composition analyst.
        \(nameContext)

        Analyze the user's weight trend from \(entryCount) measurements between \(firstDate) and \(lastDate).

        WEIGHT LOG:
        \(weightLines)

        CONTEXT:
        - User's daily calorie target: \(targetCalories) kcal
        - User's daily protein target: \(targetProtein)g

        RULES:
        1. Identify the trend: gaining, losing, stable, or fluctuating. Quantify the change (first vs last, and rate per week if enough data).
        2. Comment on consistency of measurements — are they regular or sporadic?
        3. If weight is dropping, estimate if the rate is healthy (0.3-0.7 kg/week is typical for a moderate deficit).
        4. If weight is rising or flat, suggest possible explanations (water retention, muscle gain, surplus, measurement timing).
        5. Note any unusual spikes or dips and possible causes (sodium, hydration, post-workout).
        6. Give 1-2 specific, actionable recommendations.
        7. Be honest, concise, and practical. No motivational fluff.
        8. Use 2-4 short paragraphs. Use emoji sparingly (1-2 max).
        9. Do NOT comment on carbs, fat, or other nutrition data — you only have weight measurements and targets.
        10. Detect the user's language from their name or default to English.

        Return ONLY a single JSON object:
        {"ai_summary": "your analysis here"}
        """

        sendToGemini(images: [], prompt: prompt, responseType: DailySummaryResult.self, temperature: 0.4) { result, error in
            completion(result?.ai_summary, error)
        }
    }
}

// MARK: - Recipes & Groceries

extension GeminiService {
    func generateRecipes(from ingredients: [String], completion: @escaping ([RecipeResult]?, String?) -> Void) {
        let list = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star fitness chef. I have these ingredients: \(list).
        Suggest 3 DISTINCT, healthy and high-protein recipes combining SOME or ALL of them.
        Use MARKDOWN formatting for instructions (bolding, bullets, emojis).
        LANGUAGE RULE: Detect the language of the ingredient names. Write recipe_name and cooking_instructions in that same language.
        Return ONLY valid JSON:
        {"recipes": [ {"recipe_name": "...", "cooking_instructions": "...", "estimated_calories": 450, "estimated_protein": 35, "estimated_carbs": 30, "estimated_fat": 15} ]}
        """
        sendToGemini(images: [], prompt: prompt, responseType: RecipeListResult.self, temperature: 0.7) { result, error in completion(result?.recipes, error) }
    }

    func scanGroceries(images: [UIImage], completion: @escaping ([FoodResult]?, String?) -> Void) {
        let prompt = """
        Extract all individual food items from this grocery receipt or image. 
        For each item, estimate calories, protein, carbs, and fat per 100g. 
        Return ONLY JSON: 
        \(categoryPromptBlock)
        {"items": [{"food_name": "...", "emoji": "🍎", "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "ingredients_breakdown": "Item;100g;0;0;0;0", "fridge_category": "fruit_veg", "meal_category": "other", "ai_response_text": ""}]}
        """
        sendToGemini(images: images, prompt: prompt, responseType: GroceryListResult.self, temperature: 0.1, topP: 0.3, topK: 1) { result, err in completion(result?.items, err) }
    }
}

// MARK: - Reports

extension GeminiService {
    func generateNutritionWeightReport(
        dateRange: String,
        avgCalories: Int, targetCalories: Int,
        avgProtein: Int, targetProtein: Int,
        avgCarbs: Int, avgFat: Int,
        avgTrainingCalories: Int = 0,
        weightEntries: [(date: String, weight: Double)],
        weeklyScore: Int,
        perfectDays: Int,
        totalDays: Int,
        userName: String? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        let nameContext = userName.map { "The user's name is \($0). Address them by first name." } ?? ""
        let weightLines = weightEntries.map { "\($0.date): \($0.weight) kg" }.joined(separator: "\n")
        let weightContext = weightEntries.isEmpty
            ? "No weight measurements available for this period."
            : "Weight log:\n\(weightLines)"
        let trainingContext = avgTrainingCalories > 0
            ? "- Avg daily training burn: \(avgTrainingCalories) kcal (the app adds this as a calorie bonus, so effective daily budget is ~\(targetCalories + avgTrainingCalories) kcal on training days)"
            : "- No significant training logged"

        let prompt = """
        You are a sharp, data-driven fitness and nutrition analyst.
        \(nameContext)

        Analyze the user's nutrition and weight data for the period: \(dateRange).

        NUTRITION SUMMARY:
        - Base daily calorie target: \(targetCalories) kcal (without training bonuses)
        - Avg daily calories consumed: \(avgCalories) kcal
        - Avg daily protein: \(avgProtein)g (target: \(targetProtein)g)
        - Avg daily carbs: \(avgCarbs)g
        - Avg daily fat: \(avgFat)g
        \(trainingContext)
        - Weekly score: \(weeklyScore)% (\(perfectDays)/\(totalDays) perfect days)

        \(weightContext)

        RULES:
        1. The calorie target shown is the BASE target. Training burns extra calories on top. Factor training into your energy balance analysis — if the user burns 800+ kcal training, eating above the base target is expected and healthy.
        2. If weight data exists, analyze the trend (gaining, losing, stable) and connect it to the TOTAL energy balance (intake minus base metabolism minus training burn).
        3. If weight is dropping but calories seem high, consider that high training volume explains it.
        4. If weight is stable or rising while in an apparent deficit, explain likely causes (water retention, muscle gain, inconsistent tracking, underestimated intake).
        5. Highlight protein adherence — is the user hitting their protein target?
        6. Comment on macro balance (carbs vs fat ratio) only if there's something notable.
        7. Give 1-2 specific, actionable recommendations for the next period.
        8. Be honest, concise, and practical. No motivational fluff.
        9. Use 3-5 short paragraphs. Use emoji sparingly (1-2 max).
        10. If no weight data: focus purely on nutrition patterns and recommendations.
        11. Detect the user's language from their name or default to English.

        Return ONLY a single JSON object:
        {"ai_summary": "your analysis here"}
        """

        sendToGemini(images: [], prompt: prompt, responseType: DailySummaryResult.self, temperature: 0.4) { result, error in
            completion(result?.ai_summary, error)
        }
    }
}

// MARK: - AI Coach Chat

extension GeminiService {
    func sendCoachMessage(image: UIImage?, message: String, isInitial: Bool, isPastDay: Bool, selectedDateDescription: String, selectedDateRelation: String, timeOfDay: String, consumedCalories: Double, consumedProtein: Double, consumedCarbs: Double, consumedFat: Double, targetCalories: Double, targetProtein: Double, targetCarbs: Double, targetFat: Double, meals: [String], workouts: [String], fridgeItems: [String], recentMessages: [String], userName: String? = nil, completion: @escaping (String?, String?) -> Void) {

        let dayContext = isPastDay
            ? "Selected date: \(selectedDateDescription). Date relation: \(selectedDateRelation). You are evaluating a PAST DAY that is already over. Evaluate their overall performance for that entire selected date. DO NOT suggest what to eat or do 'later today'."
            : "Selected date: \(selectedDateDescription). Date relation: \(selectedDateRelation). Current time: \(timeOfDay). The day is still ongoing."

        let fridgeContext = (!isPastDay && !fridgeItems.isEmpty)
            ? "Available food in their Fridge: \(fridgeItems.joined(separator: ", ")). Recommend SPECIFIC items from this list if they need to hit their protein or calorie goals today."
            : ""

        let nameContext = userName.map { "The user's name is \($0). Address them by first name." } ?? ""
        let recentContext = recentMessages.isEmpty ? "" : "Recent chat context:\n" + recentMessages.joined(separator: "\n")

        let lowercasedMessage = message.lowercased()
        let explanationKeywords = [
            "why", "how come", "what causes", "cause", "reason",
            "почему", "почему так", "из-за чего", "что происходит", "от чего", "как так",
            "hungry", "craving", "appetite", "headache", "dizzy", "nausea", "fatigue", "weak",
            "голод", "жор", "тяга", "хочется есть", "аппетит", "слабость", "усталость", "тошнит", "кружится"
        ]
        let isExplanationMode = !isInitial && explanationKeywords.contains { lowercasedMessage.contains($0) }

        let responseModeInstruction: String
        if isInitial {
            responseModeInstruction = isPastDay
                ? "Give a quick summary of their performance for this selected past date."
                : "The user just opened the app. Give them a quick daily summary based on current time."
        } else if isExplanationMode {
            responseModeInstruction = "The user is asking why something is happening, or describing symptoms / cravings / behavior. Explain the most likely reasons in plain language. Use the recent chat context to understand what 'this' refers to. Give 2-4 likely reasons, connect them to timing, training load, calories, protein, carbs, fat, sleep, hydration, and food choices when relevant. End with one practical next step. Do NOT open with praise."
        } else {
            responseModeInstruction = "The user says/shows: '\(message)'. Reply directly in the context of the selected date."
        }

        let prompt = """
        You are an honest, sharp, practical fitness and nutrition coach.
        \(nameContext)
        \(dayContext)
        User's daily calorie ceiling: \(Int(targetCalories)) kcal. User's protein minimum: \(Int(targetProtein))g protein.
        Secondary macro context: carbs currently \(Int(consumedCarbs))g / about \(Int(targetCarbs))g cap, fat currently \(Int(consumedFat))g / about \(Int(targetFat))g target.
        Progress: \(Int(consumedCalories)) kcal consumed, \(Int(consumedProtein))g protein consumed, \(Int(consumedCarbs))g carbs consumed, \(Int(consumedFat))g fat consumed.
        Meals eaten: \(meals.isEmpty ? "None" : meals.joined(separator: ", ")).
        Workouts done: \(workouts.isEmpty ? "None" : workouts.joined(separator: ", ")).
        \(fridgeContext)
        \(recentContext)

        \(responseModeInstruction)

        CRITICAL RULES:
        1. First decide the user's intent: summary, explanation, troubleshooting, or planning. Match that intent. Do NOT give motivational praise when the user is clearly asking for an explanation.
        2. If the user asks "why" or describes a symptom/craving/behavior, explain the likely mechanisms instead of cheering them on.
        3. Use carbs and fat in your reasoning when relevant. Example: post-workout hunger can relate to late training, depleted carbs, long gap since last meal, low-fat / low-fiber meals, or overall intake.
        4. If it's a PAST DAY, summarize or explain that finished day only. If it's the CURRENT DAY, you may suggest exact foods from the Fridge if the user wants a next step.
        5. Be direct, calm, and useful. Light humor is okay, but no cringe hype, no overpraise, no fake intensity.
        6. Keep it concise (usually 3-5 sentences). Emojis are optional, not required.
        7. If the user describes symptoms or body reactions, do NOT diagnose. Say "likely reasons" or "common reasons". If something sounds severe or persistent, briefly suggest professional medical advice.
        8. Never answer a vague follow-up like "Почему так?" as if it were a new topic. Use the recent chat context to infer what "that" means.
        9. Never call the selected date "yesterday" unless Date relation is exactly "yesterday". For older dates, use the exact selected date or say "that day".
        10. Treat calories as an upper limit / deficit target, not a minimum. Being under the calorie ceiling is GOOD unless calories are extremely low and clearly unhealthy. Do NOT say they failed because they did not eat all calories.
        11. Protein is a minimum target. Being under protein is bad; being over protein is usually fine.
        12. Detect the language of the user's message. Reply in that same language. If this is an initial summary with no user message, reply in English.

        Return ONLY a single JSON object:
        {"ai_summary": "your response here"}
        """
        let imgs = image != nil ? [image!] : []
        sendToGemini(images: imgs, prompt: prompt, responseType: DailySummaryResult.self, temperature: isExplanationMode ? 0.35 : 0.5) { result, error in
            completion(result?.ai_summary, error)
        }
    }
}
