import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Goal Snapshots & Daily Reminders
extension HomeViewModel {

    func syncDailyReminders(todayProgressForNotifications: DayProgress, todayFoodEntries: [FoodEntry]) {
        DailyReminderManager.shared.syncDailyReminders(
            progressToday: todayProgressForNotifications,
            hasFoodToday: !todayFoodEntries.isEmpty
        )
    }
}

