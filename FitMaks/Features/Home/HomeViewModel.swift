import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications

@Observable
@MainActor
final class HomeViewModel {
    var pickingMode: EntryMode = .food
    var selectedDate = Date()
    var isShowingSourceDialog = false
    var isShowingCamera = false
    var selectedCameraImage: UIImage?
    var isShowingPhotoPicker = false
    var selectedPhotoItems: [PhotosPickerItem] = []
    var isShowingTextEntry = false
    var manualText = ""
    var processingItems: [ProcessingItem] = []
    var fridgeProcessingItems: [ProcessingItem] = []
    var selectedEntryForEdit: FoodEntry?
    var selectedTrainingDetail: TrainingEntry?
    var isShowingCalendar = false
    var dailySteps: Double = 0
    var homeWeeklySteps: [String: Double] = [:]
    var isShowingMyFood = false
    var isSelectionModeForFridge = false
    var isBuildMealMode = false
    var initialMyFoodTab = 0
    var isShowingProfile = false
    var isShowingStats = false
    var isShowingAchievements = false
    var livePayload: FitMaksSharePayload?
    var achievementBanner: StatsAchievement?
    var pendingAchievementBanners: [StatsAchievement] = []
    var isShowingAIAssistant = false
    var isShowingGoalBreakdown = false
    var selectedGoalBreakdownSection: DailyGoalBreakdownSection = .calories
    var aiErrorMessage: String?
    var pendingAIReview: AIResultReview?

    var modelContext: ModelContext?
    var currentWeight: Double = 80.0
    var baseCaloriesGoal: Double = 0
    var baseProteinGoal: Double = 0
    var allDailySetups: [DailySetup] = []
    var allFoodEntries: [FoodEntry] = []
    var allTrainingEntries: [TrainingEntry] = []

    func sync(
        weight: Double,
        baseCaloriesGoal: Double,
        baseProteinGoal: Double,
        allDailySetups: [DailySetup],
        allFoodEntries: [FoodEntry],
        allTrainingEntries: [TrainingEntry],
        modelContext: ModelContext
    ) {
        self.currentWeight = weight
        self.baseCaloriesGoal = baseCaloriesGoal
        self.baseProteinGoal = baseProteinGoal
        self.allDailySetups = allDailySetups
        self.allFoodEntries = allFoodEntries
        self.allTrainingEntries = allTrainingEntries
        if self.modelContext == nil {
            self.modelContext = modelContext
        }
    }

    func dayMode(for date: Date) -> DayMode {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        let storedMode = allDailySetups.first(where: { $0.dateID == id })?.mode
        return DayMode.fromStoredValue(storedMode)
    }

    func setDayMode(_ mode: DayMode, for date: Date) {
        guard let modelContext else { return }
        let id = DateFormatter.yyyyMMdd.string(from: date)

        if let existing = allDailySetups.first(where: { $0.dateID == id }) {
            existing.mode = mode.rawValue
            snapshotPastGoalsIfNeeded(for: date)
        } else {
            modelContext.insert(DailySetup(
                date: date,
                mode: mode,
                baseCalories: shouldSnapshotGoals(for: date) ? baseCaloriesGoal : nil,
                baseProtein: shouldSnapshotGoals(for: date) ? baseProteinGoal : nil
            ))
        }
    }

    func initializeGoalSnapshotTracking(lastKnownCalories: inout Double, lastKnownProtein: inout Double) {
        guard lastKnownCalories == 0 || lastKnownProtein == 0 else { return }
        lastKnownCalories = baseCaloriesGoal
        lastKnownProtein = baseProteinGoal
        preserveMissingPastGoalSnapshots(baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal)
    }

    func shouldSnapshotGoals(for date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    func snapshotPastGoalsIfNeeded(for date: Date) {
        guard let modelContext else { return }
        guard shouldSnapshotGoals(for: date) else { return }
        let id = DateFormatter.yyyyMMdd.string(from: date)

        if let existing = allDailySetups.first(where: { $0.dateID == id }) {
            existing.applyGoalSnapshotIfNeeded(baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal)
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
        guard let modelContext else { return }
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
        guard let modelContext else { return }
        guard baseCalories > 0, baseProtein > 0 else { return }
        for date in loggedPastDatesWithActivity() {
            let id = DateFormatter.yyyyMMdd.string(from: date)
            if let existing = allDailySetups.first(where: { $0.dateID == id }) {
                existing.applyGoalSnapshotIfNeeded(baseCalories: baseCalories, baseProtein: baseProtein)
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

    func applyTrainingModeSuggestion(from result: TrainingResult, for date: Date) {
        guard let suggestedMode = suggestedDayMode(from: result) else { return }
        let mergedMode = dayMode(for: date).merged(with: suggestedMode)
        setDayMode(mergedMode, for: date)
    }

    func suggestedDayMode(from result: TrainingResult) -> DayMode? {
        let modeText = (result.day_mode ?? "").lowercased()
        let combinedText = "\(result.activity_name.lowercased()) \(result.ai_summary.lowercased()) \(modeText)"
        if modeText.contains("mixed") || modeText.contains("both") { return .cardioGym }
        if modeText.contains("gym") || modeText.contains("strength") { return .gym }
        if modeText.contains("cardio") || modeText.contains("sport") || modeText.contains("padel") { return .cardio }

        let gymKeywords = ["gym", "strength", "weight", "lifting", "leg day", "upper body", "workout"]
        let cardioKeywords = ["run", "walking", "cycling", "cardio", "tennis", "padel"]
        let hasGym = gymKeywords.contains { combinedText.contains($0) }
        let hasCardio = cardioKeywords.contains { combinedText.contains($0) }
        if hasGym && hasCardio { return .cardioGym }
        if hasGym { return .gym }
        if hasCardio { return .cardio }
        return nil
    }
}

// MARK: - HealthKit & Weight
extension HomeViewModel {
    func syncWeightFromHealthKit(allBodyMetrics: [BodyMetricEntry], updateWeight: @escaping (Double) -> Void) {
        guard let modelContext else { return }
        let now = Date()
        let lastSync = UserDefaults.standard.object(forKey: "lastHealthWeightSyncDate") as? Date ?? .distantPast
        guard now.timeIntervalSince(lastSync) > 6 * 3600 else { return }

        HealthKitManager.shared.fetchLatestBodyMetrics { [weak self] snapshot in
            guard let self, let snapshot else { return }
            let calendar = Calendar.current
            guard !allBodyMetrics.contains(where: { calendar.isDate($0.date, inSameDayAs: snapshot.date) }),
                  snapshot.date > lastSync else {
                UserDefaults.standard.set(now, forKey: "lastHealthWeightSyncDate")
                return
            }

            modelContext.insert(BodyMetricEntry(
                date: snapshot.date, weightKg: snapshot.weightKg,
                bodyFatPercent: snapshot.bodyFatPercent, musclePercent: snapshot.musclePercent,
                source: "Apple Health"
            ))

            if BodyMetricProfileSync.shouldPromoteProfileWeight(
                candidateDate: snapshot.date, currentLatestDate: allBodyMetrics.first?.date
            ) { updateWeight(snapshot.weightKg) }

            UserDefaults.standard.set(now, forKey: "lastHealthWeightSyncDate")
            self.sendWeightSyncNotification(snapshot: snapshot)
        }
    }

    private func sendWeightSyncNotification(snapshot: HealthBodyMetricSnapshot) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "FitMaks"
            content.body = "Synced from Apple Health: \(String(format: "%.1f", snapshot.weightKg)) kg"
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "fitmaks.weight.sync.\(Date().timeIntervalSince1970)", content: content, trigger: nil))
        }
    }
}
