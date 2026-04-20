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

// 🔥 НОВАЯ МОДЕЛЬ ДЛЯ ИТОГОВ ДНЯ
struct DailySummaryResult: Codable {
    let ai_summary: String
}

// MARK: - СЕРВИС GEMINI
class GeminiService {
    static let shared = GeminiService()
    private let apiKey = Config.apiKey
    
    // Чистая ссылка без маркдауна и скобок
    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    // 1. Анализ фото еды
    func analyzeImages(images: [UIImage], completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        Analyze food. Return ONLY a single JSON object. 
        CRITICAL RULE: You MUST use exactly this structure:
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "ingredients_breakdown": "Item1;100g;100;10\\nItem2;50g;50;5", "ai_response_text": ""}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines. Protein calculation is MANDATORY.
        """
        sendToGemini(images: images, prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    // 2. Анализ текста (что я съел)
    func analyzeText(text: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        Nutrition expert. User ate: '\(text)'. Return ONLY a single JSON object. 
        CRITICAL RULE: You MUST use exactly this structure:
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "ingredients_breakdown": "Item1;100g;100;10\\nItem2;50g;50;5", "ai_response_text": ""}
        Format 'ingredients_breakdown' rows with semicolons, separated by newlines.
        """
        sendToGemini(images: [], prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    // 3. Уточнение в чате
    func refineAnalysis(image: UIImage?, currentData: FoodResult, userComment: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        ACT AS NUTRITIONIST. 
        CURRENT DATA: \(currentData.food_name), \(currentData.calories)kcal, \(currentData.protein)g prot. 
        BREAKDOWN: \(currentData.ingredients_breakdown).
        USER COMMAND: "\(userComment)".
        CRITICAL RULE: Re-calculate totals based on user command.
        Even if the user asks a question, YOU MUST return a valid JSON. Answer the question or explain changes ONLY in 'ai_response_text'.
        DO NOT ADD ANY EXPLANATION OUTSIDE THE JSON. NO MARKDOWN. ONLY RAW JSON.
        Return ONLY JSON structure: {"food_name": "...", "emoji": "...", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;Weight;Kcal;Prot", "ai_response_text": "your answer"}
        """
        let imgs = image != nil ? [image!] : []
        sendToGemini(images: imgs, prompt: prompt, responseType: FoodResult.self, completion: completion)
    }

    // 4. Анализ тренировок
    func analyzeTrainingImages(images: [UIImage], completion: @escaping (TrainingResult?, String?) -> Void) {
        let prompt = """
        Extract workout stats from fitness tracker screenshot. Return ONLY a single JSON object.
        CRITICAL RULE: You MUST use exactly this structure:
        {"activity_name": "...", "calories_burned": 0, "duration": "...", "ai_summary": "..."}
        """
        sendToGemini(images: images, prompt: prompt, responseType: TrainingResult.self, completion: completion)
    }

    // 5. Генератор рецептов
    func generateRecipes(from ingredients: [String], completion: @escaping ([RecipeResult]?, String?) -> Void) {
        let list = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star fitness chef. I have these ingredients: \(list).
        Suggest 3 DISTINCT, healthy and high-protein recipes combining SOME or ALL of them. 
        Use MARKDOWN formatting for instructions (bolding, bullets, emojis).
        Return ONLY valid JSON:
        {"recipes": [ {"recipe_name": "...", "cooking_instructions": "...", "estimated_calories": 450, "estimated_protein": 35} ]}
        """
        sendToGemini(images: [], prompt: prompt, responseType: RecipeListResult.self) { result, error in
            completion(result?.recipes, error)
        }
    }
    
    // 6. Скан чека или продуктов
    func scanGroceries(images: [UIImage], completion: @escaping ([FoodResult]?, String?) -> Void) {
        let prompt = """
        Extract all individual food items from this grocery receipt or image. 
        For each item, estimate calories and protein per 100g. 
        Return ONLY JSON: 
        {"items": [{"food_name": "...", "emoji": "🍎", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;100g;0;0", "ai_response_text": ""}]}
        """
        sendToGemini(images: images, prompt: prompt, responseType: GroceryListResult.self) { result, err in
            completion(result?.items, err)
        }
    }
    
    // 🔥 7. ГЕНЕРАЦИЯ ИТОГОВ ДНЯ 🔥
    func generateDailySummary(timeOfDay: String, consumedCalories: Double, consumedProtein: Double, targetCalories: Double, targetProtein: Double, meals: [String], workouts: [String], completion: @escaping (String?) -> Void) {
        let prompt = """
        You are a top-tier fitness and nutrition coach.
        Current time: \(timeOfDay).
        User's daily goal: \(Int(targetCalories)) kcal, \(Int(targetProtein))g protein.
        Today's progress: \(Int(consumedCalories)) kcal consumed, \(Int(consumedProtein))g protein consumed.
        Meals eaten today: \(meals.isEmpty ? "None yet" : meals.joined(separator: ", ")).
        Workouts done today: \(workouts.isEmpty ? "None yet" : workouts.joined(separator: ", ")).

        Analyze the day based on the current time and progress. Give practical advice for the rest of the day, or a brief wrap-up if it's late evening/night. Keep it under 4 sentences, be direct, honest, and motivating. Use emojis.
        Return ONLY a single JSON object:
        {"ai_summary": "your text here"}
        """
        sendToGemini(images: [], prompt: prompt, responseType: DailySummaryResult.self) { result, _ in
            completion(result?.ai_summary)
        }
    }

    // MARK: - ОСНОВНОЙ МЕТОД ЗАПРОСА
    private func sendToGemini<T: Decodable>(images: [UIImage], prompt: String, responseType: T.Type, completion: @escaping (T?, String?) -> Void) {
        var parts: [[String: Any]] = [["text": prompt]]
        
        for image in images {
            if let data = image.resized(toMaxDimension: 768).jpegData(compressionQuality: 0.5)?.base64EncodedString() {
                parts.append(["inline_data": ["mime_type": "image/jpeg", "data": data]])
            }
        }
        
        guard let url = URL(string: "\(baseUrl)?key=\(apiKey)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 🔥 JSON MODE: жесткая валидация на уровне API 🔥
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "response_mime_type": "application/json"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🚨 Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil, error.localizedDescription) }
                return
            }
            
            guard let data = data else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown"
                print("🚨 API Error (\(httpResponse.statusCode)): \(errorString)")
                DispatchQueue.main.async { completion(nil, "API Error: \(httpResponse.statusCode)") }
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let resultParts = content["parts"] as? [[String: Any]],
                  let rawText = resultParts.first?["text"] as? String else {
                
                print("🚨 JSON Structure Error. Raw Response: \(String(data: data, encoding: .utf8) ?? "None")")
                DispatchQueue.main.async { completion(nil, "Invalid API Response") }
                return
            }
            
            var cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let mdQuotes = "`" + "`" + "`"
            if cleanText.contains(mdQuotes) {
                cleanText = cleanText.replacingOccurrences(of: mdQuotes + "json", with: "")
                cleanText = cleanText.replacingOccurrences(of: mdQuotes, with: "")
            }
            
            guard let start = cleanText.firstIndex(of: "{"),
                  let end = cleanText.lastIndex(of: "}"),
                  let finalData = String(cleanText[start...end]).data(using: .utf8) else {
                
                print("🚨 Parse Error. I couldn't find JSON bounds. Raw Text: \(rawText)")
                DispatchQueue.main.async { completion(nil, "Parse Error") }
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: finalData)
                DispatchQueue.main.async { completion(decoded, nil) }
            } catch {
                print("🚨 Decode Error: \(error)")
                print("🚨 RAW AI TEXT THAT FAILED: \n\(String(data: finalData, encoding: .utf8) ?? "unreadable")")
                DispatchQueue.main.async { completion(nil, "Decode Error") }
            }
        }.resume()
    }
}

// MARK: - РАСШИРЕНИЕ ДЛЯ КАРТИНОК
extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        let newSize = aspectRatio > 1
            ? CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            : CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
