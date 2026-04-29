import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Goal Snapshots & Daily Reminders
extension ContentView {

    func initializeGoalSnapshotTracking() {
        guard lastKnownBaseCaloriesGoal == 0 || lastKnownBaseProteinGoal == 0 else {
            return
        }

        lastKnownBaseCaloriesGoal = baseCaloriesGoal
        lastKnownBaseProteinGoal = baseProteinGoal
        preserveMissingPastGoalSnapshots(
            baseCalories: baseCaloriesGoal,
            baseProtein: baseProteinGoal
        )
    }

    func shouldSnapshotGoals(for date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    func snapshotPastGoalsIfNeeded(for date: Date) {
        guard shouldSnapshotGoals(for: date) else {
            return
        }

        let id = DateFormatter.yyyyMMdd.string(from: date)

        if let existing = allDailySetups.first(where: { $0.dateID == id }) {
            existing.applyGoalSnapshotIfNeeded(
                baseCalories: baseCaloriesGoal,
                baseProtein: baseProteinGoal
            )
        } else {
            modelContext.insert(DailySetup(
                date: date,
                mode: dayMode(for: date),
                baseCalories: baseCaloriesGoal,
                baseProtein: baseProteinGoal
            ))
        }
    }

    func snapshotTodayGoals(baseCalories: Double, baseProtein: Double) {
        guard baseCalories > 0, baseProtein > 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let id = DateFormatter.yyyyMMdd.string(from: today)
        let hasActivity = allFoodEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
            || allTrainingEntries.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }

        guard hasActivity else { return }

        if let existing = allDailySetups.first(where: { $0.dateID == id }) {
            existing.applyGoalSnapshotIfNeeded(baseCalories: baseCalories, baseProtein: baseProtein)
        } else {
            modelContext.insert(DailySetup(
                date: today,
                mode: dayMode(for: today),
                baseCalories: baseCalories,
                baseProtein: baseProtein
            ))
        }
    }

    func preserveMissingPastGoalSnapshots(baseCalories: Double, baseProtein: Double) {
        guard baseCalories > 0, baseProtein > 0 else {
            return
        }

        for date in loggedPastDatesWithActivity() {
            let id = DateFormatter.yyyyMMdd.string(from: date)

            if let existing = allDailySetups.first(where: { $0.dateID == id }) {
                existing.applyGoalSnapshotIfNeeded(
                    baseCalories: baseCalories,
                    baseProtein: baseProtein
                )
            } else {
                modelContext.insert(DailySetup(
                    date: date,
                    mode: .chill,
                    baseCalories: baseCalories,
                    baseProtein: baseProtein
                ))
            }
        }
    }

    func loggedPastDatesWithActivity() -> [Date] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dates = allFoodEntries.map(\.date) + allTrainingEntries.map(\.date)
        var uniqueByDay: [String: Date] = [:]

        for date in dates where date < todayStart {
            let day = calendar.startOfDay(for: date)
            uniqueByDay[DateFormatter.yyyyMMdd.string(from: day)] = day
        }

        return uniqueByDay.values.sorted()
    }

    func syncDailyReminders() {
        DailyReminderManager.shared.syncDailyReminders(
            progressToday: todayProgressForNotifications,
            hasFoodToday: !todayFoodEntries.isEmpty
        )
    }

    func applyTrainingModeSuggestion(from result: TrainingResult, for date: Date) {
        guard let suggestedMode = suggestedDayMode(from: result) else {
            return
        }

        let mergedMode = dayMode(for: date).merged(with: suggestedMode)
        setDayMode(mergedMode, for: date)
    }

    func suggestedDayMode(from result: TrainingResult) -> DayMode? {
        let modeText = (result.day_mode ?? "").lowercased()
        let combinedText = "\(result.activity_name.lowercased()) \(result.ai_summary.lowercased()) \(modeText)"

        if modeText.contains("mixed") || modeText.contains("both") {
            return .cardioGym
        }

        if modeText.contains("gym") || modeText.contains("strength") {
            return .gym
        }

        if modeText.contains("cardio") || modeText.contains("sport") || modeText.contains("padel") {
            return .cardio
        }

        let gymKeywords = [
            "gym", "strength", "weight", "weights", "lifting", "bodybuilding", "resistance",
            "upper body", "lower body", "push", "pull", "leg day", "legs", "hypertrophy",
            "crossfit", "functional fitness", "workout"
        ]
        let cardioKeywords = [
            "padel", "tennis", "run", "running", "walk", "walking", "cycling", "bike", "biking",
            "cardio", "football", "soccer", "sport", "elliptical", "stairmaster", "rowing",
            "hike", "hiking", "pickleball"
        ]

        let hasGym = gymKeywords.contains { combinedText.contains($0) }
        let hasCardio = cardioKeywords.contains { combinedText.contains($0) }

        if hasGym && hasCardio {
            return .cardioGym
        }

        if hasGym {
            return .gym
        }

        if hasCardio {
            return .cardio
        }

        return nil
    }

    // MARK: - Auto Weight Sync from HealthKit

    func syncWeightFromHealthKit() {
        let now = Date()
        let lastSync = UserDefaults.standard.object(forKey: "lastHealthWeightSyncDate") as? Date ?? .distantPast
        let cooldown: TimeInterval = 6 * 3600

        guard now.timeIntervalSince(lastSync) > cooldown else { return }

        HealthKitManager.shared.fetchLatestBodyMetrics { [self] snapshot in
            guard let snapshot else { return }

            let calendar = Calendar.current
            let alreadyHasToday = allBodyMetrics.contains {
                calendar.isDate($0.date, inSameDayAs: snapshot.date)
            }

            guard !alreadyHasToday else {
                UserDefaults.standard.set(now, forKey: "lastHealthWeightSyncDate")
                return
            }

            guard snapshot.date > lastSync else {
                UserDefaults.standard.set(now, forKey: "lastHealthWeightSyncDate")
                return
            }

            let entry = BodyMetricEntry(
                date: snapshot.date,
                weightKg: snapshot.weightKg,
                bodyFatPercent: snapshot.bodyFatPercent,
                musclePercent: snapshot.musclePercent,
                source: "Apple Health"
            )
            modelContext.insert(entry)

            if BodyMetricProfileSync.shouldPromoteProfileWeight(
                candidateDate: snapshot.date,
                currentLatestDate: allBodyMetrics.first?.date
            ) {
                weight = snapshot.weightKg
            }

            UserDefaults.standard.set(now, forKey: "lastHealthWeightSyncDate")

            sendWeightSyncNotification(snapshot: snapshot)
        }
    }

    private func sendWeightSyncNotification(snapshot: HealthBodyMetricSnapshot) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            var details = ["\(String(format: "%.1f", snapshot.weightKg)) kg"]
            if let fat = snapshot.bodyFatPercent {
                details.append("\(String(format: "%.1f", fat))% fat")
            }
            if let muscle = snapshot.musclePercent {
                details.append("\(String(format: "%.1f", muscle))% muscle")
            }

            let content = UNMutableNotificationContent()
            content.title = "FitMaks"
            content.body = "Synced from Apple Health: \(details.joined(separator: " · "))"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "fitmaks.weight.sync.\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
