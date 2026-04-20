import Foundation
import UIKit

// MARK: - МОДЕЛИ ОТВЕТОВ ИИ
struct FoodResult: Codable {
    let food_name: String
    let emoji: String?
    let calories: Double
    let protein: Double
    let ingredients_breakdown: String
    let ai_response_text: String
}

struct TrainingResult: Codable {
    let activity_name: String
    let calories_burned: Double
    let duration: String
    let ai_summary: String
}

struct RecipeResult: Codable, Identifiable {
    var id: String { recipe_name }
    let recipe_name: String
    let cooking_instructions: String
    let estimated_calories: Double
    let estimated_protein: Double
}

struct RecipeListResult: Codable {
    let recipes: [RecipeResult]
}

struct GroceryListResult: Codable {
    let items: [FoodResult]
}

struct DailySummaryResult: Codable {
    let ai_summary: String
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
    
    func analyzeImages(images: [UIImage], completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        Analyze food. Return ONLY a single JSON object. 
        CRITICAL RULE: You MUST use exactly this structure:
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "ingredients_breakdown": "Item1;100g;100;10\\nItem2;50g;50;5", "ai_response_text": ""}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines. Protein calculation is MANDATORY.
        """
        sendToGemini(images: images, prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    func analyzeText(text: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        Nutrition expert. User ate: '\(text)'. Return ONLY a single JSON object. 
        CRITICAL RULE: You MUST use exactly this structure:
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "ingredients_breakdown": "Item1;100g;100;10\\nItem2;50g;50;5", "ai_response_text": ""}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines.
        """
        sendToGemini(images: [], prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    func refineAnalysis(image: UIImage?, currentData: FoodResult, userComment: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        ACT AS NUTRITIONIST. 
        CURRENT DATA: \(currentData.food_name), \(currentData.calories)kcal, \(currentData.protein)g prot. 
        BREAKDOWN: \(currentData.ingredients_breakdown).
        USER COMMAND: "\(userComment)".
        CRITICAL RULE: Re-calculate totals based on user command.
        Even if the user asks a question, YOU MUST return a valid JSON. Answer the question or explain changes ONLY in 'ai_response_text'.
        Return ONLY JSON structure: {"food_name": "...", "emoji": "...", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;Weight;Kcal;Prot", "ai_response_text": "your answer"}
        """
        let imgs = image != nil ? [image!] : []
        sendToGemini(images: imgs, prompt: prompt, responseType: FoodResult.self, completion: completion)
    }

    func analyzeTrainingImages(images: [UIImage], completion: @escaping (TrainingResult?, String?) -> Void) {
        let prompt = """
        Extract workout stats from fitness tracker screenshot. Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        {"activity_name": "...", "calories_burned": 0, "duration": "...", "ai_summary": "..."}
        """
        sendToGemini(images: images, prompt: prompt, responseType: TrainingResult.self, completion: completion)
    }

    func generateRecipes(from ingredients: [String], completion: @escaping ([RecipeResult]?, String?) -> Void) {
        let list = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star fitness chef. I have these ingredients: \(list).
        Suggest 3 DISTINCT, healthy and high-protein recipes combining SOME or ALL of them. 
        Use MARKDOWN formatting for instructions (bolding, bullets, emojis).
        Return ONLY valid JSON:
        {"recipes": [ {"recipe_name": "...", "cooking_instructions": "...", "estimated_calories": 450, "estimated_protein": 35} ]}
        """
        sendToGemini(images: [], prompt: prompt, responseType: RecipeListResult.self) { result, error in completion(result?.recipes, error) }
    }
    
    func scanGroceries(images: [UIImage], completion: @escaping ([FoodResult]?, String?) -> Void) {
        let prompt = """
        Extract all individual food items from this grocery receipt or image. 
        For each item, estimate calories and protein per 100g. 
        Return ONLY JSON: 
        {"items": [{"food_name": "...", "emoji": "🍎", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;100g;0;0", "ai_response_text": ""}]}
        """
        sendToGemini(images: images, prompt: prompt, responseType: GroceryListResult.self) { result, err in completion(result?.items, err) }
    }
    
    // 🔥 ОБНОВЛЕННЫЙ ЧАТ С ИИ-ТРЕНЕРОМ (УМЕЕТ В ПРОШЛОЕ И ВИДИТ ХОЛОДИЛЬНИК) 🔥
    func sendCoachMessage(image: UIImage?, message: String, isInitial: Bool, isPastDay: Bool, timeOfDay: String, consumedCalories: Double, consumedProtein: Double, targetCalories: Double, targetProtein: Double, meals: [String], workouts: [String], fridgeItems: [String], completion: @escaping (String?, String?) -> Void) {
        
        let dayContext = isPastDay
            ? "You are evaluating a PAST DAY that is already over. Evaluate their overall performance for that entire day. DO NOT suggest what to eat or do 'later today'."
            : "Current time: \(timeOfDay). The day is still ongoing."
            
        let fridgeContext = (!isPastDay && !fridgeItems.isEmpty)
            ? "Available food in their Fridge: \(fridgeItems.joined(separator: ", ")). Recommend SPECIFIC items from this list if they need to hit their protein or calorie goals today."
            : ""
            
        let prompt = """
        You are a strict, honest, and highly motivating fitness and nutrition coach.
        \(dayContext)
        User's daily goal: \(Int(targetCalories)) kcal, \(Int(targetProtein))g protein.
        Progress: \(Int(consumedCalories)) kcal consumed, \(Int(consumedProtein))g protein consumed.
        Meals eaten: \(meals.isEmpty ? "None" : meals.joined(separator: ", ")).
        Workouts done: \(workouts.isEmpty ? "None" : workouts.joined(separator: ", ")).
        \(fridgeContext)

        \(isInitial ? (isPastDay ? "Give a quick summary of their performance for this past day." : "The user just opened the app. Give them a quick daily summary and motivation based on current time.") : "The user says/shows: '\(message)'. Reply to them directly.")

        CRITICAL RULES:
        1. Evaluate food quality. If they ate junk food, sugar, or excess fat, scold them slightly but constructively. Praise good protein intake.
        2. If it's a PAST DAY, summarize their success or failure. If it's the CURRENT DAY, motivate them and suggest exact foods from their Fridge to hit remaining goals.
        3. Be direct, use quick humor, and don't sugar-coat.
        4. Keep it concise (under 5 sentences). Use emojis.

        Return ONLY a single JSON object:
        {"ai_summary": "your response here"}
        """
        let imgs = image != nil ? [image!] : []
        sendToGemini(images: imgs, prompt: prompt, responseType: DailySummaryResult.self) { result, error in
            completion(result?.ai_summary, error)
        }
    }

    private func sendToGemini<T: Decodable>(images: [UIImage], prompt: String, responseType: T.Type, completion: @escaping (T?, String?) -> Void) {
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
        let body: [String: Any] = ["contents": [["parts": parts]], "generationConfig": ["response_mime_type": "application/json"]]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            finish(nil, "Failed to encode Gemini request.")
            return
        }

        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                finish(nil, error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                finish(nil, "No response from Gemini.")
                return
            }

            guard let data = data else {
                finish(nil, "Gemini returned an empty response.")
                return
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? JSONDecoder().decode(GeminiAPIErrorResponse.self, from: data) {
                    finish(nil, apiError.error.message ?? "Gemini request failed with code \(httpResponse.statusCode).")
                    return
                }

                let responseText = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                finish(nil, responseText?.isEmpty == false ? responseText : "Gemini request failed with code \(httpResponse.statusCode).")
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
                    finish(nil, apiError.error.message ?? "Invalid Gemini response.")
                } else {
                    finish(nil, "Invalid Gemini response.")
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
                finish(nil, "Gemini returned invalid JSON.")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: finalData)
                finish(decoded, nil)
            } catch {
                finish(nil, "Failed to decode Gemini response.")
            }
        }.resume()
    }
}

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        let newSize = aspectRatio > 1 ? CGSize(width: maxDimension, height: maxDimension / aspectRatio) : CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        return UIGraphicsImageRenderer(size: newSize).image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
