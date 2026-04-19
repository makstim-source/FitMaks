import SwiftUI
import SwiftData

@main
struct FitMaksApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 🔥 Принудительно ставим темную тему для всего приложения,
                // чтобы системные алерты и клавиатура были черными
                .preferredColorScheme(.dark)
        }
        // 🔥 Регистрируем все наши модели в хранилище 🔥
        // Без DailySetup не будет сохраняться режим дня (Padel/Gym)
        // Без TrainingEntry не будут добавляться тренировки из Whoop
        .modelContainer(for: [
            FoodEntry.self,
            FavoriteFood.self,
            TrainingEntry.self,
            DailySetup.self
        ])
    }
}
