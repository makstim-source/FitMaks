import Foundation

enum CategoryResolver {

    // MARK: - Fridge Category Resolution

    static func resolveFridgeCategory(name: String, ingredients: String, aiRawValue: String?) -> FridgeCategory {
        let text = (name + " " + ingredients).lowercased()
        let tokens = normalizedTokens(from: text)

        if containsAny(snackProductKeys, in: text, tokens: tokens) {
            return .other
        }

        if let aiCategory = FridgeCategory.fromAI(aiRawValue) {
            if aiCategory == .proteins && containsAny(proteinMarketingOnlyKeys, in: text, tokens: tokens) {
                if containsAny(explicitDrinkKeys, in: text, tokens: tokens) { return .drinks }
                if containsAny(explicitDairyKeys, in: text, tokens: tokens) { return .dairy }
            }
            return aiCategory
        }

        return inferFridgeCategory(name: name, ingredients: ingredients)
    }

    static func inferFridgeCategory(name: String, ingredients: String) -> FridgeCategory {
        let text = (name + " " + ingredients).lowercased()
        let tokens = normalizedTokens(from: text)

        if containsAny(snackProductKeys, in: text, tokens: tokens) { return .other }

        let isPowderProtein = containsAny(powderProteinKeys, in: text, tokens: tokens)
        if containsAny(explicitDrinkKeys, in: text, tokens: tokens) && !isPowderProtein { return .drinks }
        if containsAny(explicitDairyKeys, in: text, tokens: tokens) { return .dairy }
        if containsAny(explicitProteinKeys, in: text, tokens: tokens) { return .proteins }
        if containsAny(carbKeys, in: text, tokens: tokens) { return .healthyCarbs }
        if containsAny(sauceKeys, in: text, tokens: tokens) { return .sauces }
        if containsAny(fruitVegKeys, in: text, tokens: tokens) { return .fruitVeg }
        if containsAny(snackKeys, in: text, tokens: tokens) { return .other }
        return .other
    }

    // MARK: - Meal Category Inference

    static func inferMealCategory(name: String, ingredients: String, dateSaved: Date) -> MealCategory {
        let text = (name + " " + ingredients).lowercased()

        if breakfastKeys.contains(where: { text.contains($0) }) { return .breakfast }
        if dessertKeys.contains(where: { text.contains($0) }) { return .desserts }
        if saladKeys.contains(where: { text.contains($0) }) { return .salads }
        if mealSnackKeys.contains(where: { text.contains($0) }) { return .snacks }

        let hasProtein = mainDishProtein.contains(where: { text.contains($0) })
        let hasCarb = mainDishCarb.contains(where: { text.contains($0) })
        if hasProtein && hasCarb { return .mainDish }
        if hasProtein { return .mainDish }

        if sideKeys.contains(where: { text.contains($0) }) { return .sides }

        return .other
    }

    // MARK: - AI Key Normalization

    static func normalizeAIKey(_ rawValue: String?) -> String {
        (rawValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    // MARK: - Token Matching Helpers

    private static func normalizedTokens(from text: String) -> Set<String> {
        Set(text.split { !$0.isLetter && !$0.isNumber }.map { String($0).lowercased() })
    }

    private static func containsAny(_ keywords: [String], in text: String, tokens: Set<String>) -> Bool {
        keywords.contains { containsKeyword($0, in: text, tokens: tokens) }
    }

    private static func containsKeyword(_ keyword: String, in text: String, tokens: Set<String>) -> Bool {
        let needle = keyword.lowercased()

        if needle.contains(" ") || needle.contains("-") {
            return text.contains(needle)
        }

        let isShortASCIIWord = needle.count <= 6 && needle.unicodeScalars.allSatisfy { $0.isASCII && $0.properties.isAlphabetic }
        if isShortASCIIWord {
            return tokens.contains(needle)
        }

        return text.contains(needle)
    }

    // MARK: - Fridge Category Keywords

    private static let explicitProteinKeys = [
        "chicken", "курин", "курица", "beef", "говя", "turkey", "индей",
        "tuna", "тунец", "salmon", "лосось", "shrimp", "креветк", "fish", "рыб",
        "egg", "яйц", "mince", "фарш", "steak", "pork", "свинин", "duck", "утк",
        "lamb", "баранин", "tofu", "тофу", "kana", "kanan", "filee", "pihvi", "liha",
        "lohi", "katkarapu", "kalkkuna", "nauta", "sika", "ankka", "karitsa",
        "tonfisk", "tonnikala", "skipjack", "filet", "fillet",
        "sisäfilee", "ulkofilee", "grilli", "whey", "isolate", "isolaatti", "casein",
        "hera", "whey isolate", "protein powder", "mass gainer", "gainer", "amino",
        "bcaa", "eaa", "creatine", "kreatiini"
    ]

    private static let powderProteinKeys = [
        "whey", "isolate", "isolaatti", "casein", "hera", "protein powder",
        "powder", "jauhe", "mass gainer", "gainer", "bcaa", "eaa", "creatine", "kreatiini"
    ]

    private static let proteinMarketingOnlyKeys = [
        "protein", "high protein", "protein+", "profeel", "protein drink", "protein yogurt",
        "high protein drink", "high protein yogurt", "proteiin", "proteiini"
    ]

    private static let explicitDairyKeys = [
        "yogurt", "yoghurt", "йогурт", "skyr", "cheese", "сыр", "творог", "cottage cheese",
        "cottage", "кефир", "kefir", "cream", "сливк", "butter", "масло", "сметан",
        "quark", "rahka", "maitorahka", "maito", "juusto", "kerma", "jogurtti", "piimä",
        "milbona", "ehrmann", "protein quark", "protein yogurt", "pudding", "protein pudding",
        "kvarg", "kvark", "curd", "raejuusto"
    ]

    private static let carbKeys = [
        "rice", "рис", "pasta", "макарон", "bread", "хлеб", "oat", "овся",
        "potato", "картош", "noodle", "лапш", "cereal", "мюсли", "granola",
        "buckwheat", "гречк", "couscous", "кускус", "quinoa", "киноа", "булк",
        "tortilla", "тортилья", "flatbread", "лаваш", "wrap",
        "kaura", "peruna", "riisi", "leipä", "penne", "spagetti", "nuudeli"
    ]

    private static let fruitVegKeys = [
        "apple", "яблок", "banana", "банан", "berr", "ягод", "orange", "апельсин",
        "grape", "виноград", "tomato", "помидор", "cucumber", "огурец", "pepper", "перец",
        "carrot", "морков", "onion", "лук", "avocado", "авокадо", "lettuce", "салат",
        "spinach", "шпинат", "broccoli", "брокколи", "mango", "манго", "kiwi", "киви",
        "lemon", "лимон", "peach", "персик", "pear", "груш", "cabbage", "капуст",
        "zucchini", "кабачок", "eggplant", "баклажан", "mushroom", "гриб",
        "omena", "banaani", "tomaatti", "kurkku", "porkkana", "sipuli",
        "sieni", "parsakaali", "paprika", "kumquat", "кумкват",
        "celery", "сельдерей", "selleri", "plum", "слив", "fig", "инжир",
        "cherry", "вишн", "черешн", "melon", "дын", "арбуз", "watermelon"
    ]

    private static let snackKeys = [
        "bar", "батончик", "chocolate", "шоколад", "chips", "чипс", "nuts", "орех",
        "cookie", "печень", "candy", "конфет", "waffle", "вафл", "cracker",
        "dried", "сухофрукт", "popcorn", "попкорн", "халва", "мармелад",
        "suklaa", "keksi", "pähkinä", "corn cake", "rice cake", "sipsit"
    ]

    private static let snackProductKeys = [
        "chips", "чипс", "cracker", "corn cake", "rice cake", "popcorn", "попкорн",
        "crisps", "nachos", "pretzel", "sipsit"
    ]

    private static let sauceKeys = [
        "sauce", "соус", "ketchup", "кетчуп", "mayo", "майонез", "mustard", "горчиц",
        "dressing", "заправк", "vinegar", "уксус", "oil", "олив", "honey", "мёд", "мед",
        "syrup", "сироп", "jam", "джем", "варень", "pesto", "песто", "soy sauce",
        "sriracha", "hummus", "хумус", "salsa", "сальса", "spice", "специ",
        "sinappi", "kastike", "hunaja", "öljy", "passata"
    ]

    private static let explicitDrinkKeys = [
        "drink", "напиток", "juoma", "shake", "smoothie", "juice", "сок", "mehu",
        "cola", "cola zero", "soda", "sparkling water", "mineral water", "kivennäisvesi", "coffee", "кофе", "kahvi",
        "tea", "чай", "tee", "monster", "red bull", "beverage", "beverages",
        "limonadi", "energy drink", "iced coffee", "iced latte"
    ]

    // MARK: - Meal Category Keywords

    private static let breakfastKeys = [
        "breakfast", "завтрак", "oatmeal", "каша", "porridge", "pancake", "блин",
        "waffle", "вафл", "cereal", "мюсли", "granola", "гранола", "toast", "тост",
        "омлет", "omelette", "scrambled", "яичниц", "aamiainen", "puuro"
    ]

    private static let dessertKeys = [
        "dessert", "десерт", "cake", "торт", "пирог", "pie", "ice cream", "мороженое",
        "brownie", "брауни", "cheesecake", "чизкейк", "cookie", "печень",
        "muffin", "маффин", "donut", "пончик", "tiramisu", "тирамису",
        "pudding", "пудинг", "mousse", "мусс", "waffle", "вафл",
        "crumble", "tart", "cupcake", "капкейк", "pastry", "выпечк",
        "kakku", "piirakka", "leivos", "jäätelö"
    ]

    private static let saladKeys = [
        "salad", "салат", "starter", "закуск",
        "appetizer", "bruschetta", "брускетт", "salaatti",
        "hummus", "хумус", "bowl", "боул"
    ]

    private static let mealSnackKeys = [
        "snack", "перекус", "shake", "шейк", "smoothie", "смузи", "bar", "батончик",
        "yogurt", "йогурт", "fruit cup", "фрукт", "protein ball",
        "välipala"
    ]

    private static let mainDishProtein = [
        "chicken", "курин", "курица", "beef", "говя", "turkey", "индей",
        "salmon", "лосось", "fish", "рыб", "pork", "свинин", "steak", "стейк",
        "lamb", "баранин", "duck", "утк", "tuna", "тунец", "shrimp", "креветк",
        "kana", "lohi", "nauta", "filee", "pihvi", "liha"
    ]

    private static let mainDishCarb = [
        "rice", "рис", "pasta", "паста", "макарон", "potato", "картош",
        "noodle", "лапш", "riisi", "peruna"
    ]

    private static let sideKeys = [
        "rice", "рис", "bread", "хлеб", "couscous", "кускус", "quinoa", "киноа",
        "mashed", "пюре", "fries", "фри", "buckwheat", "гречк",
        "oat", "овся", "flatbread", "лаваш", "tortilla", "тортилья",
        "riisi", "leipä", "kaura"
    ]
}
