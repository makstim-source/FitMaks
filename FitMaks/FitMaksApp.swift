import SwiftUI
import SwiftData

@main
struct FitMaksApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            FoodEntry.self,
            FavoriteFood.self,
            TrainingEntry.self,
            DailySetup.self,
            SavedRecipe.self,
            ShoppingItem.self // 🔥 Новая база для списка покупок
        ])
    }
}
