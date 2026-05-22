import Foundation

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
