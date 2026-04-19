import Foundation
import UIKit

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

class GeminiService {
    static let shared = GeminiService()
    private let apiKey = Config.apiKey
    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    func analyzeImages(images: [UIImage], completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        Nutrition expert mode. Analyze these images of food.
        Provide a single, most relevant emoji.
        Return ONLY valid JSON using exactly this structure:
        {"food_name": "...", "emoji": "🍔", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;Weight;Kcal;Protein\\nItem;Weight;Kcal;Protein", "ai_response_text": "..."}
        """
        sendToGemini(images: images, prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    func analyzeText(text: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        Nutrition expert mode. The user ate: "\(text)".
        Estimate nutritional value. Provide a single emoji.
        Return ONLY valid JSON using exactly this structure:
        {"food_name": "...", "emoji": "🥗", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;Weight;Kcal;Protein\\nItem;Weight;Kcal;Protein", "ai_response_text": "..."}
        """
        sendToGemini(images: [], prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    func analyzeTrainingImages(images: [UIImage], completion: @escaping (TrainingResult?, String?) -> Void) {
        let prompt = """
        You are a sports data analyst. The user uploaded screenshots from a fitness tracker.
        Extract the workout details.
        Return ONLY valid JSON using exactly this structure:
        {"activity_name": "Padel", "calories_burned": 500, "duration": "1h 30m", "ai_summary": "Great intense session!"}
        """
        sendToGemini(images: images, prompt: prompt, responseType: TrainingResult.self, completion: completion)
    }
    
    func refineAnalysis(image: UIImage, additionalImage: UIImage?, currentData: FoodResult, userComment: String, completion: @escaping (FoodResult?, String?) -> Void) {
        let prompt = """
        CURRENT DATA: \(currentData.food_name), \(currentData.calories) kcal, \(currentData.protein)g protein. 
        Ingredients: \(currentData.ingredients_breakdown).
        USER REQUEST: "\(userComment)".
        Modify ONLY requested items. Recalculate totals.
        Return ONLY valid JSON using this EXACT structure:
        {"food_name": "...", "emoji": "🥩", "calories": 0, "protein": 0, "ingredients_breakdown": "Item;Weight;Kcal;Protein\\nItem;Weight;Kcal;Protein", "ai_response_text": "..."}
        """
        var imagesToSend = [image]
        if let extra = additionalImage { imagesToSend.append(extra) }
        sendToGemini(images: imagesToSend, prompt: prompt, responseType: FoodResult.self, completion: completion)
    }
    
    private func sendToGemini<T: Decodable>(images: [UIImage], prompt: String, responseType: T.Type, completion: @escaping (T?, String?) -> Void) {
        var parts: [[String: Any]] = [["text": prompt]]
        for image in images {
            let optimizedImage = image.resized(toMaxDimension: 1024)
            if let imageData = optimizedImage.jpegData(compressionQuality: 0.6)?.base64EncodedString() {
                parts.append(["inline_data": ["mime_type": "image/jpeg", "data": imageData]])
            }
        }
        
        guard let url = URL(string: "\(baseUrl)?key=\(apiKey)") else { completion(nil, "Bad URL"); return }
        
        let requestBody: [String: Any] = ["contents": [["parts": parts]]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do { request.httpBody = try JSONSerialization.data(withJSONObject: requestBody) } catch { completion(nil, "JSON encoding error"); return }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(nil, error.localizedDescription) }; return }
            guard let data = data, !data.isEmpty else { DispatchQueue.main.async { completion(nil, "Empty response") }; return }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let content = candidates.first?["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String else { throw NSError(domain: "Parsing", code: 0) }
                
                guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { throw NSError(domain: "Parsing", code: 0) }
                let jsonString = String(text[start...end])
                guard let jsonData = jsonString.data(using: .utf8) else { throw NSError(domain: "Parsing", code: 0) }
                
                let result = try JSONDecoder().decode(T.self, from: jsonData)
                DispatchQueue.main.async { completion(result, nil) }
            } catch { DispatchQueue.main.async { completion(nil, error.localizedDescription) } }
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
