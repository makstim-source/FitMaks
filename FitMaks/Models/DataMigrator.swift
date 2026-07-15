import Foundation
import SwiftData

enum DataMigrator {
    private static func yieldIfNeeded(_ index: Int, every batchSize: Int = 40) async {
        if index > 0 && index.isMultiple(of: batchSize) { await Task.yield() }
    }

    static func migrateCarbsFatIfNeeded(modelContext: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: "hasMigratedCarbsFat") else { return }

        func estimate(_ calories: Double, _ protein: Double) -> (carbs: Double, fat: Double) {
            let remaining = max(calories - protein * 4, 0)
            return (remaining * 0.55 / 4, remaining * 0.45 / 9)
        }

        var didChange = false
        let foodEntries = (try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? []
        for (index, entry) in foodEntries.enumerated() where entry.carbs == 0 && entry.fat == 0 && entry.calories > 0 {
            let (c, f) = estimate(entry.calories, entry.protein)
            entry.carbs = c; entry.fat = f; didChange = true
            await yieldIfNeeded(index)
        }

        let favorites = (try? modelContext.fetch(FetchDescriptor<FavoriteFood>())) ?? []
        for (index, fav) in favorites.enumerated() where fav.carbs == 0 && fav.fat == 0 && fav.calories > 0 {
            let (c, f) = estimate(fav.calories, fav.protein)
            fav.carbs = c; fav.fat = f; didChange = true
            await yieldIfNeeded(index)
        }

        let recipes = (try? modelContext.fetch(FetchDescriptor<SavedRecipe>())) ?? []
        for (index, recipe) in recipes.enumerated() where recipe.carbs == 0 && recipe.fat == 0 && recipe.calories > 0 {
            let (c, f) = estimate(recipe.calories, recipe.protein)
            recipe.carbs = c; recipe.fat = f; didChange = true
            await yieldIfNeeded(index)
        }

        if didChange { try? modelContext.save() }
        UserDefaults.standard.set(true, forKey: "hasMigratedCarbsFat")
    }

    static func migrateCategoriesIfNeeded(modelContext: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: "hasMigratedCategoriesV3") else { return }

        var didChange = false
        let favorites = (try? modelContext.fetch(FetchDescriptor<FavoriteFood>())) ?? []
        for (index, fav) in favorites.enumerated() {
            fav.categoryRaw = FridgeCategory.infer(name: fav.name, ingredients: fav.ingredients).rawValue
            didChange = true
            await yieldIfNeeded(index)
        }

        let recipes = (try? modelContext.fetch(FetchDescriptor<SavedRecipe>())) ?? []
        for (index, recipe) in recipes.enumerated() {
            recipe.categoryRaw = MealCategory.infer(name: recipe.name, ingredients: recipe.ingredients, dateSaved: recipe.dateSaved).rawValue
            didChange = true
            await yieldIfNeeded(index)
        }

        if didChange { try? modelContext.save() }
        UserDefaults.standard.set(true, forKey: "hasMigratedCategoriesV3")
    }

    static func refineFridgeCategoriesIfNeeded(modelContext: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: "hasRefinedFridgeCategoriesV7") else { return }

        var didChange = false
        let favorites = (try? modelContext.fetch(FetchDescriptor<FavoriteFood>())) ?? []
        for (index, fav) in favorites.enumerated() {
            fav.categoryRaw = FridgeCategory.resolve(name: fav.name, ingredients: fav.ingredients, aiRawValue: nil).rawValue
            didChange = true
            await yieldIfNeeded(index)
        }

        if didChange { try? modelContext.save() }
        UserDefaults.standard.set(true, forKey: "hasRefinedFridgeCategoriesV7")
    }

    static func runAll(modelContext: ModelContext) async {
        await migrateCarbsFatIfNeeded(modelContext: modelContext)
        await migrateCategoriesIfNeeded(modelContext: modelContext)
        await refineFridgeCategoriesIfNeeded(modelContext: modelContext)
    }
}
