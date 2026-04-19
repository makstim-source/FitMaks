import Foundation
import UIKit

struct FoodResult: Codable { let food_name: String; let emoji: String?; let calories: Double; let protein: Double; let ingredients_breakdown: String; let ai_response_text: String }
struct TrainingResult: Codable { let activity_name: String; let calories_burned: Double; let duration: String; let ai_summary: String }

// Модели для рецептов
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

class GeminiService {
    static let shared = GeminiService()
    private let apiKey = Config.apiKey
    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    func analyzeImages(images: [UIImage], completion: @escaping (FoodResult?, String?) -> Void) {
        sendToGemini(images: images, prompt: "Analyze food. Return ONLY JSON. Format: Item;Weight;Kcal;Protein. Protein is MANDATORY.", responseType: FoodResult.self, completion: completion)
    }
    
    func analyzeText(text: String, completion: @escaping (FoodResult?, String?) -> Void) {
        sendToGemini(images: [], prompt: "Nutrition expert. User ate: '\(text)'. Return ONLY JSON. Format: Item;Weight;Kcal;Protein.", responseType: FoodResult.self, completion: completion)
    }
    
    func refineAnalysis(image: UIImage?, currentData: FoodResult, userComment: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = "ACT AS NUTRITIONIST. CURRENT: \(currentData.food_name), \(currentData.calories)kcal, \(currentData.protein)g prot. BREAKDOWN: \(currentData.ingredients_breakdown). USER COMMAND: \"\(userComment)\". Update calculations. Return ONLY JSON structure with 4 columns in breakdown: Item;Weight;Kcal;Protein. STRIP 'kcal' and 'g' from values."
        sendToGemini(images: image != nil ? [image!] : [], prompt: prompt, responseType: FoodResult.self, completion: completion)
    }

    func analyzeTrainingImages(images: [UIImage], completion: @escaping (TrainingResult?, String?) -> Void) {
        sendToGemini(images: images, prompt: "Extract workout stats from Whoop/Watch screenshot. Return ONLY JSON.", responseType: TrainingResult.self, completion: completion)
    }

    // 🔥 ПРОМПТ ДЛЯ НЕСКОЛЬКИХ РЕЦЕПТОВ 🔥
    func generateRecipes(from ingredients: [String], completion: @escaping ([RecipeResult]?, String?) -> Void) {
        let list = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star chef. I have these ingredients: \(list).
        Suggest 2 to 4 DISTINCT, delicious, and healthy recipes I can make combining SOME or ALL of them. 
        Use MARKDOWN formatting for instructions (bolding, bullets, emojis).
        Return ONLY valid JSON using exactly this structure:
        {"recipes": [ {"recipe_name": "...", "cooking_instructions": "...", "estimated_calories": 450, "estimated_protein": 35} ]}
        """
        sendToGemini(images: [], prompt: prompt, responseType: RecipeListResult.self) { result, error in
            completion(result?.recipes, error)
        }
    }

    private func sendToGemini<T: Decodable>(images: [UIImage], prompt: String, responseType: T.Type, completion: @escaping (T?, String?) -> Void) {
        var parts: [[String: Any]] = [["text": prompt]]
        for image in images { if let data = image.resized(toMaxDimension: 768).jpegData(compressionQuality: 0.5)?.base64EncodedString() { parts.append(["inline_data": ["mime_type": "image/jpeg", "data": data]]) } }
        guard let url = URL(string: "\(baseUrl)?key=\(apiKey)") else { return }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["contents": [["parts": parts]]])

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let candidates = json["candidates"] as? [[String: Any]], let text = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]], let rawText = text.first?["text"] as? String, let start = rawText.firstIndex(of: "{"), let end = rawText.lastIndex(of: "}"), let finalData = String(rawText[start...end]).data(using: .utf8), let result = try? JSONDecoder().decode(T.self, from: finalData) else {
                DispatchQueue.main.async { completion(nil, "Error") }; return
            }
            DispatchQueue.main.async { completion(result, nil) }
        }.resume()
    }
}

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let aspect = size.width / size.height
        let newSize = aspect > 1 ? CGSize(width: maxDimension, height: maxDimension/aspect) : CGSize(width: maxDimension*aspect, height: maxDimension)
        return UIGraphicsImageRenderer(size: newSize).image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
