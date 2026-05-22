import Foundation
import UIKit

// MARK: - Gemini API Error

private struct GeminiAPIErrorResponse: Decodable {
    struct APIError: Decodable {
        let code: Int?
        let message: String?
    }

    let error: APIError
}

// MARK: - Gemini Service

class GeminiService {
    static let shared = GeminiService()
    private let apiKey = Config.apiKey

    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    let foodCacheQueue = DispatchQueue(label: "FitMaks.foodEstimateCache")
    let maxCacheSize = 50
    var foodImageEstimateCache: [String: FoodResult] = [:]
    var foodImageEstimateKeys: [String] = []
    var foodImageItemsCache: [String: [FoodResult]] = [:]
    var foodImageItemsKeys: [String] = []
    var foodTextEstimateCache: [String: FoodResult] = [:]
    var foodTextEstimateKeys: [String] = []

    let fridgeCategoryKeys = "proteins, healthy_carbs, fruit_veg, dairy, drinks, snacks, sauces_extras, other"
    let mealCategoryKeys = "main_dish, sides, salads_starters, breakfast, desserts, snacks, other"

    var categoryPromptBlock: String {
        """
        CATEGORY RULES:
        - fridge_category is the best reusable PRODUCT / FRIDGE bucket for this item.
        - meal_category is the best reusable MEAL bucket for this item.
        - fridge_category MUST be exactly one of: \(fridgeCategoryKeys).
        - meal_category MUST be exactly one of: \(mealCategoryKeys).
        - Never invent new category values. If unsure, use "other".
        - Choose fridge_category by the PHYSICAL PRODUCT TYPE, not by flavor words in the name.
        - Yogurt / quark / skyr / pudding / cottage cheese belong to "dairy".
        - Ready-to-drink shakes, cartons, bottled protein drinks, juices, sodas, and coffees belong to "drinks".
        - Whey / isolate powders and raw meat / fish / eggs belong to "proteins".
        - Chips, crisps, corn cakes, rice cakes, crackers, bars, cookies, candy, nachos, pretzels, and similar packaged grab-and-go items belong to "snacks" — even if the flavor name contains a vegetable or dairy word (e.g. "Paprika Chips" → snacks, "Sour Cream Corn Cakes" → snacks, "Tomato Basil Chips" → snacks).
        - Fresh or frozen whole fruits, berries, and vegetables belong to "fruit_veg" — even when sold in plastic containers or packages (e.g. blueberries in a punnet, kumquats in a bag).
        - For meal_category: noodle dishes and pasta dishes with protein (chicken noodle, beef pasta, etc.) are "main_dish", not "salads_starters". Desserts like cake, ice cream, brownies, cookies, pie, cheesecake, muffins belong to "desserts".
        """
    }

    var singleFoodJSONShape: String {
        """
        {"food_name": "Dish Name", "emoji": "🍽️", "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "ingredients_breakdown": "Item1;100g;100;10;0;0\\nItem2;50g;50;5;0;0", "fridge_category": "proteins", "meal_category": "main_dish", "ai_response_text": ""}
        """
    }

    var multiFoodJSONShape: String {
        """
        {"items":[{"food_name":"Dish Name","emoji":"🍽️","source_photo_number":1,"calories":0,"protein":0,"carbs":0,"fat":0,"ingredients_breakdown":"Item1;100g;100;10;0;0\\nItem2;50g;50;5;0;0","fridge_category":"proteins","meal_category":"main_dish","ai_response_text":""}]}
        """
    }

    // MARK: - Core API

    func sendToGemini<T: Decodable>(
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
            "temperature": temperature
        ]

        if !useSearchGrounding {
            generationConfig["response_mime_type"] = "application/json"
        }

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

    // MARK: - Request Execution

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

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if let apiError = try? JSONDecoder().decode(GeminiAPIErrorResponse.self, from: data) {
                    completion(nil, apiError.error.message ?? "Invalid Gemini response.")
                } else {
                    completion(nil, "Invalid Gemini response.")
                }
                return
            }

            if let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let reason = first["finishReason"] as? String,
               first["content"] == nil {
                if retriesRemaining > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.performRequest(request, responseType: responseType, retriesRemaining: retriesRemaining - 1, completion: completion)
                    }
                    return
                }
                completion(nil, "AI blocked the response (\(reason)). Try rephrasing.")
                return
            }

            guard
                let candidates = json["candidates"] as? [[String: Any]],
                let content = candidates.first?["content"] as? [String: Any],
                let resultParts = content["parts"] as? [[String: Any]],
                let rawText = resultParts.first?["text"] as? String
            else {
                if retriesRemaining > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.performRequest(request, responseType: responseType, retriesRemaining: retriesRemaining - 1, completion: completion)
                    }
                    return
                }
                let feedback = (json["promptFeedback"] as? [String: Any])?["blockReason"] as? String
                completion(nil, feedback.map { "AI blocked: \($0). Try rephrasing." } ?? "Invalid Gemini response. Please try again.")
                return
            }

            var cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let mdQuotes = "`" + "`" + "`"
            if cleanText.contains(mdQuotes) {
                cleanText = cleanText.replacingOccurrences(of: mdQuotes + "json", with: "")
                cleanText = cleanText.replacingOccurrences(of: mdQuotes, with: "")
            }

            let jsonCandidates = self.extractJSONBlocks(from: cleanText)

            for candidate in jsonCandidates {
                if let data = candidate.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(T.self, from: data) {
                    completion(decoded, nil)
                    return
                }
            }

            let finalData: Data?
            if let start = cleanText.firstIndex(of: "{"),
               let end = cleanText.lastIndex(of: "}") {
                finalData = String(cleanText[start...end]).data(using: .utf8)
            } else {
                finalData = nil
            }

            if let finalData, let decoded = try? JSONDecoder().decode(T.self, from: finalData) {
                completion(decoded, nil)
                return
            }

            let fallbackText: String
            if let finalData,
               let json = try? JSONSerialization.jsonObject(with: finalData) as? [String: Any] {
                fallbackText = (json["ai_response_text"] as? String)
                    ?? (json["ai_summary"] as? String)
                    ?? cleanText
            } else if !cleanText.isEmpty {
                fallbackText = cleanText
            } else {
                completion(nil, "Gemini returned invalid JSON.")
                return
            }
            completion(nil, "AI_TEXT:\(fallbackText)")
        }.resume()
    }

    // MARK: - JSON Extraction

    private func extractJSONBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            if chars[i] == "{" {
                var depth = 0
                var inString = false
                var escaped = false
                let start = i
                for j in i..<chars.count {
                    if escaped { escaped = false; continue }
                    if chars[j] == "\\" && inString { escaped = true; continue }
                    if chars[j] == "\"" { inString.toggle(); continue }
                    if inString { continue }
                    if chars[j] == "{" { depth += 1 }
                    if chars[j] == "}" {
                        depth -= 1
                        if depth == 0 {
                            blocks.append(String(chars[start...j]))
                            i = j + 1
                            break
                        }
                    }
                }
                if depth != 0 { i += 1 }
            } else {
                i += 1
            }
        }
        return blocks.sorted { $0.count > $1.count }
    }

    private func wrapPlainTextAsJSON(_ text: String) -> Data? {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "{\"ai_summary\":\"\(escaped)\"}".data(using: .utf8)
    }

    // MARK: - Error Handling

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
}
