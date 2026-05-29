import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications

struct UserSettings {
    var gender: String = "Male"
    var age: Int = 30
    var weight: Double = 80.0
    var height: Double = 180.0
    var goal: String = "Lose Weight"
    var activityLevel: String = "Moderate"
    var useCustomGoals: Bool = false
    var customCalories: Double = 0.0
    var customProtein: Double = 0.0
    var customFat: Double = 0.0
    var customCarbs: Double = 0.0
}

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
    var isShowingTrainingTextEntry = false
    var isShowingFAQ = false
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
    var isShowingWeeklyReport = false
    var calendarReportDate: Date?
    var isShowingPaywall = false
    var selectedGoalBreakdownSection: DailyGoalBreakdownSection = .calories
    var aiErrorMessage: String?
    var pendingAIReview: AIResultReview?

    var modelContext: ModelContext?
    var settings = UserSettings()
    var allDailySetups: [DailySetup] = []
    var setupIndex: [String: DailySetup] = [:]
    var allFoodEntries: [FoodEntry] = []
    var allTrainingEntries: [TrainingEntry] = []
    var allBodyMetrics: [BodyMetricEntry] = []

    var hasCompletedStartupHydration = false
    var isPerformingStartupHydration = false
    var onWeightChanged: ((Double) -> Void)?

    var cachedLast30Stats: [DayProgress] = []
    var cachedPerfectStreak: Int = 0
    var cachedRecentSevenDayStats: [DayProgress] = []
    var cachedAchievementCollection: StatsAchievementCollection = .empty

    var cachedDailyFood: [FoodEntry] = []
    var cachedDailyTraining: [TrainingEntry] = []
    var cachedTodayFood: [FoodEntry] = []
    var cachedTodayTraining: [TrainingEntry] = []

    var cachedDailyCalories: Double = 0
    var cachedDailyProtein: Double = 0
    var cachedDailyCarbs: Double = 0
    var cachedDailyFat: Double = 0
    var cachedDailyTrainingCalories: Double = 0
    var cachedDailyUploadedSteps: Double = 0
    var cachedDailyFeed: [TimelineItem] = []
    var cachedLoggedPastDaysSignature: String = ""
    var cachedCopyablePlanDates: [Date] = []
    var cachedPreviousWeekReport: WeeklyReportData?

    private var foodByDate: [String: [FoodEntry]] = [:]
    private var trainingByDate: [String: [TrainingEntry]] = [:]

    // MARK: - Goal Computations

    var calculatedProtein: Double {
        NutritionCalculator.recommendedProtein(weight: settings.weight, goal: settings.goal)
    }

    var calculatedCalories: Double {
        NutritionCalculator.recommendedCalories(
            gender: settings.gender, age: settings.age, weight: settings.weight,
            height: settings.height, activityLevel: settings.activityLevel, goal: settings.goal
        )
    }

    var baseCaloriesGoal: Double { settings.useCustomGoals ? settings.customCalories : calculatedCalories }
    var baseProteinGoal: Double { settings.useCustomGoals ? settings.customProtein : calculatedProtein }

    var currentDayMode: DayMode { dayMode(for: selectedDate) }

    func selectedBaseCaloriesGoal(for date: Date) -> Double {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        return setupIndex[id]?.resolvedBaseCalories(for: date, fallback: baseCaloriesGoal) ?? baseCaloriesGoal
    }

    func selectedBaseProteinGoal(for date: Date) -> Double {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        return setupIndex[id]?.resolvedBaseProtein(for: date, fallback: baseProteinGoal) ?? baseProteinGoal
    }

    var dailyTargets: DayTargets {
        DayProgressEngine.targets(
            baseCalories: selectedBaseCaloriesGoal(for: selectedDate),
            baseProtein: selectedBaseProteinGoal(for: selectedDate),
            mode: currentDayMode,
            trainingCalories: cachedDailyTrainingCalories,
            activityLevel: settings.activityLevel
        )
    }

    var calorieGoalBonus: Double { dailyTargets.calorieBonus }
    var proteinGoalBonus: Double { dailyTargets.proteinBonus }
    var targetProtein: Double { dailyTargets.protein }
    var maxCalories: Double { dailyTargets.calories }
    let targetSteps: Double = DayProgressEngine.defaultStepTarget

    var baseTargetCarbs: Double {
        max(selectedBaseCaloriesGoal(for: selectedDate) - selectedBaseProteinGoal(for: selectedDate) * 4, 0) * 0.55 / 4
    }
    var baseTargetFat: Double {
        max(selectedBaseCaloriesGoal(for: selectedDate) - selectedBaseProteinGoal(for: selectedDate) * 4, 0) * 0.45 / 9
    }
    var targetCarbs: Double { max(maxCalories - targetProtein * 4, 0) * 0.55 / 4 }
    var targetFat: Double { max(maxCalories - targetProtein * 4, 0) * 0.45 / 9 }
    var dailyCaloriesRemaining: Double { maxCalories - cachedDailyCalories }

    var dailyProgress: DayProgress {
        DayProgressEngine.progress(
            date: selectedDate,
            consumedCalories: cachedDailyCalories,
            consumedProtein: cachedDailyProtein,
            hasFood: !cachedDailyFood.isEmpty,
            mode: currentDayMode,
            trainingCalories: cachedDailyTrainingCalories,
            baseCalories: selectedBaseCaloriesGoal(for: selectedDate),
            baseProtein: selectedBaseProteinGoal(for: selectedDate),
            steps: dailySteps,
            uploadedSteps: cachedDailyUploadedSteps,
            activityLevel: settings.activityLevel,
            stepTarget: targetSteps
        )
    }

    var isPerfectPastDay: Bool { dailyProgress.isPerfectPastDay() }

    var todayMode: DayMode {
        let dateID = DateFormatter.yyyyMMdd.string(from: Date())
        return DayMode.fromStoredValue(setupIndex[dateID]?.mode)
    }

    var todayStepsForNotifications: Double {
        let dateID = DateFormatter.yyyyMMdd.string(from: Date())
        if let steps = homeWeeklySteps[dateID] { return steps }
        return Calendar.current.isDateInToday(selectedDate) ? dailySteps : 0
    }

    var todayTrainingCalories: Double {
        cachedTodayTraining.reduce(0) { $0 + $1.caloriesBurned }
    }

    var todayUploadedTrainingSteps: Double {
        cachedTodayTraining.reduce(0) { $0 + max($1.steps ?? 0, 0) }
    }

    var todayProgressForNotifications: DayProgress {
        DayProgressEngine.progress(
            date: Date(),
            foodEntries: cachedTodayFood,
            trainingCalories: todayTrainingCalories,
            mode: todayMode,
            baseCalories: baseCaloriesGoal,
            baseProtein: baseProteinGoal,
            steps: todayStepsForNotifications,
            uploadedSteps: todayUploadedTrainingSteps,
            activityLevel: settings.activityLevel,
            stepTarget: targetSteps
        )
    }

    var goalSnapshotSignature: String {
        "\(Int(baseCaloriesGoal.rounded()))#\(Int(baseProteinGoal.rounded()))"
    }

    var dailyReminderSignature: String {
        let foodSig = cachedTodayFood.map { "\($0.id.uuidString):\(Int($0.calories)):\(Int($0.protein))" }.joined(separator: "|")
        let trainSig = cachedTodayTraining.map { "\($0.id.uuidString):\(Int($0.caloriesBurned)):\(Int($0.steps ?? 0))" }.joined(separator: "|")
        return "\(DateFormatter.yyyyMMdd.string(from: Date()))#\(foodSig)#\(trainSig)#\(Int(todayStepsForNotifications))#\(todayMode.rawValue)#\(Int(baseProteinGoal))"
    }

    var canClearSelectedDay: Bool {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        guard selectedDay > today else { return false }
        return !cachedDailyFeed.isEmpty || setupIndex[DateFormatter.yyyyMMdd.string(from: selectedDate)] != nil
    }

    var shouldShowWeeklyBanner: Bool {
        let calendar = Calendar.current
        guard calendar.isDateInToday(selectedDate) else { return false }
        guard calendar.component(.weekday, from: Date()) == 2 else { return false }
        guard let report = cachedPreviousWeekReport else { return false }
        let lastViewed = UserDefaults.standard.string(forKey: "lastViewedWeeklyReportID") ?? ""
        return lastViewed != report.weekID
    }

    var unlockedAchievementSignature: String {
        cachedAchievementCollection.all.filter(\.isUnlocked).map(\.id).sorted().joined(separator: "|")
    }

    // MARK: - Date Indices

    private func rebuildDateIndices() {
        foodByDate = Dictionary(grouping: allFoodEntries) {
            DateFormatter.yyyyMMdd.string(from: $0.date)
        }
        trainingByDate = Dictionary(grouping: allTrainingEntries) {
            DateFormatter.yyyyMMdd.string(from: $0.date)
        }
    }

    func sync(
        settings: UserSettings,
        allDailySetups: [DailySetup],
        allFoodEntries: [FoodEntry],
        allTrainingEntries: [TrainingEntry],
        allBodyMetrics: [BodyMetricEntry],
        modelContext: ModelContext,
        includeStats: Bool = true
    ) {
        self.settings = settings
        self.allDailySetups = allDailySetups
        self.setupIndex = Dictionary(allDailySetups.map { ($0.dateID, $0) }, uniquingKeysWith: { _, new in new })
        self.allFoodEntries = allFoodEntries
        self.allTrainingEntries = allTrainingEntries
        self.allBodyMetrics = allBodyMetrics
        if self.modelContext == nil {
            self.modelContext = modelContext
        }
        rebuildDateIndices()
        rebuildDailyCache()
        rebuildCopyablePlanDates()
        rebuildLoggedPastDaysSignature()
        if includeStats {
            rebuildCachedStats(activityLevel: settings.activityLevel)
        }
    }

    func rebuildDailyCache() {
        let selectedKey = DateFormatter.yyyyMMdd.string(from: selectedDate)
        let todayKey = DateFormatter.yyyyMMdd.string(from: Date())

        cachedDailyFood = foodByDate[selectedKey] ?? []
        cachedDailyTraining = trainingByDate[selectedKey] ?? []
        cachedTodayFood = foodByDate[todayKey] ?? []
        cachedTodayTraining = trainingByDate[todayKey] ?? []

        cachedDailyCalories = cachedDailyFood.reduce(0) { $0 + $1.calories }
        cachedDailyProtein = cachedDailyFood.reduce(0) { $0 + $1.protein }
        cachedDailyCarbs = cachedDailyFood.reduce(0) { $0 + $1.carbs }
        cachedDailyFat = cachedDailyFood.reduce(0) { $0 + $1.fat }
        cachedDailyTrainingCalories = cachedDailyTraining.reduce(0) { $0 + $1.caloriesBurned }
        cachedDailyUploadedSteps = cachedDailyTraining.reduce(0) { $0 + max($1.steps ?? 0, 0) }

        let foods = cachedDailyFood.map { TimelineItem.food($0) }
        let trainings = cachedDailyTraining.map { TimelineItem.training($0) }
        cachedDailyFeed = (foods + trainings).sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.training, .food): return true
            case (.food, .training): return false
            default: return lhs.createdAt > rhs.createdAt
            }
        }
    }

    func rebuildCopyablePlanDates() {
        let selectedKey = DateFormatter.yyyyMMdd.string(from: selectedDate)
        cachedCopyablePlanDates = foodByDate.keys
            .filter { $0 != selectedKey }
            .sorted(by: >)
            .prefix(8)
            .compactMap { DateFormatter.yyyyMMdd.date(from: $0) }
    }

    func rebuildLoggedPastDaysSignature() {
        let todayKey = DateFormatter.yyyyMMdd.string(from: Date())
        let allKeys = Set(foodByDate.keys).union(trainingByDate.keys)
        let pastKeys = allKeys.filter { $0 < todayKey }
        cachedLoggedPastDaysSignature = pastKeys.sorted().joined(separator: "|")
    }

    private func rebuildCachedStats(activityLevel: String) {
        let calendar = Calendar.current
        let today = Date()
        let stepTarget = DayProgressEngine.defaultStepTarget

        cachedLast30Stats = (0..<30).compactMap { index in
            let daysBack = 29 - index
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: today) else { return nil }
            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let setup = setupIndex[dateID]
            let mode = DayMode.fromStoredValue(setup?.mode)
            let dayFood = foodByDate[dateID] ?? []
            let dayTraining = trainingByDate[dateID] ?? []
            let dayTrainingCalories = dayTraining.reduce(0) { $0 + $1.caloriesBurned }
            let dayUploadedSteps = dayTraining.reduce(0) { $0 + max($1.steps ?? 0, 0) }
            return DayProgressEngine.progress(
                date: date,
                foodEntries: dayFood,
                trainingCalories: dayTrainingCalories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCaloriesGoal) ?? baseCaloriesGoal,
                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProteinGoal) ?? baseProteinGoal,
                steps: homeWeeklySteps[dateID] ?? 0,
                uploadedSteps: dayUploadedSteps,
                activityLevel: activityLevel,
                stepTarget: stepTarget
            )
        }

        let recent7 = Array(cachedLast30Stats.suffix(7))
        cachedRecentSevenDayStats = recent7
        cachedPerfectStreak = AchievementEngine.homePerfectStreak(in: recent7)
        cachedAchievementCollection = AchievementEngine.achievementCollection(
            last30Stats: cachedLast30Stats,
            recentSevenDayStats: recent7,
            foodEntries: allFoodEntries
        )
        cachedPreviousWeekReport = WeeklyReportData.previousWeek(from: cachedLast30Stats, allFoodEntries: allFoodEntries)
    }

    func rebuildStats(activityLevel: String) {
        rebuildCachedStats(activityLevel: activityLevel)
    }

    func dayMode(for date: Date) -> DayMode {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        let storedMode = setupIndex[id]?.mode
        return DayMode.fromStoredValue(storedMode)
    }

    func setDayMode(_ mode: DayMode, for date: Date) {
        guard let modelContext else { return }
        let id = DateFormatter.yyyyMMdd.string(from: date)

        if let existing = setupIndex[id] {
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

    func initializeGoalSnapshotTracking() {
        var lastKnownCalories = UserDefaults.standard.double(forKey: "lastKnownBaseCaloriesGoal")
        var lastKnownProtein = UserDefaults.standard.double(forKey: "lastKnownBaseProteinGoal")
        guard lastKnownCalories == 0 || lastKnownProtein == 0 else { return }
        lastKnownCalories = baseCaloriesGoal
        lastKnownProtein = baseProteinGoal
        UserDefaults.standard.set(lastKnownCalories, forKey: "lastKnownBaseCaloriesGoal")
        UserDefaults.standard.set(lastKnownProtein, forKey: "lastKnownBaseProteinGoal")
        preserveMissingPastGoalSnapshots(baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal)
    }

    func shouldSnapshotGoals(for date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    func snapshotPastGoalsIfNeeded(for date: Date) {
        guard let modelContext else { return }
        guard shouldSnapshotGoals(for: date) else { return }
        let id = DateFormatter.yyyyMMdd.string(from: date)

        if let existing = setupIndex[id] {
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

        if let existing = setupIndex[id] {
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
            if let existing = setupIndex[id] {
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
    // MARK: - Lifecycle & Events

    func onAppear() {
        if hasCompletedStartupHydration {
            // data refreshed by onChange sync
        } else {
            hasCompletedStartupHydration = true
            isPerformingStartupHydration = true

            Task { @MainActor in
                await Task.yield()
                await migrateCarbsFatIfNeeded()
                await migrateCategoriesIfNeeded()
                await refineFridgeCategoriesIfNeeded()

                rebuildDateIndices()
                rebuildDailyCache()
                rebuildCopyablePlanDates()
                rebuildLoggedPastDaysSignature()

                initializeGoalSnapshotTracking()

                await Task.yield()
                rebuildStats(activityLevel: settings.activityLevel)
                isPerformingStartupHydration = false
            }
        }

        syncWeightFromHealthKit()
        fetchDailySteps()
        fetchWeeklySteps()
        syncDailyReminders()
    }

    func handleDateChange(_ newDate: Date) {
        rebuildDailyCache()
        rebuildCopyablePlanDates()
        fetchDailySteps()
    }

    func handleGoalSnapshotChange() {
        let oldCalories = UserDefaults.standard.double(forKey: "lastKnownBaseCaloriesGoal")
        let oldProtein = UserDefaults.standard.double(forKey: "lastKnownBaseProteinGoal")
        preserveMissingPastGoalSnapshots(baseCalories: oldCalories, baseProtein: oldProtein)
        snapshotTodayGoals(baseCalories: oldCalories, baseProtein: oldProtein)
        UserDefaults.standard.set(baseCaloriesGoal, forKey: "lastKnownBaseCaloriesGoal")
        UserDefaults.standard.set(baseProteinGoal, forKey: "lastKnownBaseProteinGoal")
        ICloudSettingsSync.pushToICloud()
    }

    func handleLoggedPastDaysChange() {
        preserveMissingPastGoalSnapshots(baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal)
    }

    func fetchDailySteps() {
        HealthKitManager.shared.fetchSteps(for: selectedDate) { [weak self] steps in
            DispatchQueue.main.async {
                self?.dailySteps = steps
                self?.syncDailyReminders()
            }
        }
    }

    func fetchWeeklySteps() {
        HealthKitManager.shared.fetchWeeklySteps { [weak self] steps in
            DispatchQueue.main.async {
                self?.homeWeeklySteps = steps
                self?.refreshAchievementBannerQueue()
                self?.syncDailyReminders()
            }
        }
    }

    func syncDailyReminders() {
        DailyReminderManager.shared.syncDailyReminders(
            progressToday: todayProgressForNotifications,
            hasFoodToday: !cachedTodayFood.isEmpty
        )
    }

    // MARK: - Achievement Banners

    func refreshAchievementBannerQueue() {
        let seenRaw = UserDefaults.standard.string(forKey: "seenAchievementUnlockIDs") ?? ""
        let seenIDs = Set(seenRaw.split(separator: "|").map(String.init))
        let unlocked = cachedAchievementCollection.all.filter(\.isUnlocked)
        let unseen = unlocked.filter { !seenIDs.contains($0.id) }
        guard !unseen.isEmpty else { return }

        pendingAchievementBanners = unseen.sorted { lhs, rhs in
            if lhs.family != rhs.family { return lhs.family == .core }
            if lhs.rarity.rawValue != rhs.rarity.rawValue { return lhs.rarity.rawValue > rhs.rarity.rawValue }
            return lhs.title < rhs.title
        }

        if achievementBanner == nil { showNextAchievementBanner() }
    }

    private func showNextAchievementBanner() {
        guard !pendingAchievementBanners.isEmpty else { return }
        let next = pendingAchievementBanners.removeFirst()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            achievementBanner = next
        }
    }

    func dismissAchievementBanner() {
        guard let current = achievementBanner else { return }
        let seenRaw = UserDefaults.standard.string(forKey: "seenAchievementUnlockIDs") ?? ""
        var seenIDs = Set(seenRaw.split(separator: "|").map(String.init))
        seenIDs.insert(current.id)
        UserDefaults.standard.set(seenIDs.sorted().joined(separator: "|"), forKey: "seenAchievementUnlockIDs")

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            achievementBanner = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.showNextAchievementBanner()
        }
    }

    func postAchievementBanner() {
        guard let current = achievementBanner else { return }
        let payload = achievementSharePayload(from: current)
        dismissAchievementBanner()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.livePayload = payload
        }
    }

    func achievementSharePayload(from achievement: StatsAchievement) -> FitMaksSharePayload {
        .achievement(
            FitMaksShareAchievementSnapshot(
                title: achievement.title,
                familyLabel: achievement.family == .core ? "Core trophy" : "Side quest",
                subtitle: achievement.subtitle,
                detail: achievement.detail,
                goalText: achievement.goalText,
                progressText: achievement.progressText,
                icon: achievement.icon,
                color: achievement.color,
                isUnlocked: achievement.isUnlocked,
                progress: achievement.progress,
                hasStarted: achievement.current > 0
            )
        )
    }

    // MARK: - Day Management

    func copyDayEntries(from sourceDate: Date) {
        guard let modelContext else { return }
        let calendar = Calendar.current
        let destinationDate = calendar.startOfDay(for: selectedDate)
        let sourceFoods = allFoodEntries
            .filter { calendar.isDate($0.date, inSameDayAs: sourceDate) }
            .sorted { ($0.createdAt ?? $0.date) < ($1.createdAt ?? $1.date) }

        for (index, entry) in sourceFoods.enumerated() {
            let fallbackImage = generatePlaceholderIcon(systemName: "fork.knife.circle.fill", color: .neonGreen)
            let copied = FoodEntry(
                image: entry.uiImage ?? fallbackImage,
                name: entry.name, calories: entry.calories, protein: entry.protein,
                carbs: entry.carbs, fat: entry.fat,
                ingredients: entry.ingredients, date: destinationDate, location: entry.location
            )
            copied.createdAt = Date().addingTimeInterval(Double(index))
            modelContext.insert(copied)
        }

        setDayMode(dayMode(for: sourceDate), for: destinationDate)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func clearSelectedDay() {
        guard let modelContext else { return }
        let calendar = Calendar.current
        let date = selectedDate

        for entry in allFoodEntries where calendar.isDate(entry.date, inSameDayAs: date) {
            deleteFoodEntry(entry)
        }
        for entry in allTrainingEntries where calendar.isDate(entry.date, inSameDayAs: date) {
            modelContext.delete(entry)
        }
        for setup in allDailySetups where setup.dateID == DateFormatter.yyyyMMdd.string(from: date) {
            modelContext.delete(setup)
        }

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Migrations

    private func yieldIfNeeded(_ index: Int, every batchSize: Int = 40) async {
        if index > 0 && index.isMultiple(of: batchSize) { await Task.yield() }
    }

    func migrateCarbsFatIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: "hasMigratedCarbsFat") else { return }
        guard let modelContext else { return }

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

    func migrateCategoriesIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: "hasMigratedCategoriesV3") else { return }
        guard let modelContext else { return }

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

    func refineFridgeCategoriesIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: "hasRefinedFridgeCategoriesV7") else { return }
        guard let modelContext else { return }

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

    // MARK: - Weekly Reports

    var trailingSevenDayReport: WeeklyReportData? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) else { return nil }
        return WeeklyReportData.trailingDays(
            endingOn: yesterday, count: 7,
            allFoodEntries: allFoodEntries, allTrainingEntries: allTrainingEntries,
            setupIndex: setupIndex, baseCaloriesGoal: baseCaloriesGoal, baseProteinGoal: baseProteinGoal,
            stepsIndex: homeWeeklySteps, activityLevel: settings.activityLevel
        )
    }

    func weekReport(for date: Date) -> WeeklyReportData? {
        WeeklyReportData.forWeekContaining(
            date: date,
            allFoodEntries: allFoodEntries, allTrainingEntries: allTrainingEntries,
            setupIndex: setupIndex, baseCaloriesGoal: baseCaloriesGoal, baseProteinGoal: baseProteinGoal,
            stepsIndex: homeWeeklySteps, activityLevel: settings.activityLevel
        )
    }

    var activeWeeklyReport: WeeklyReportData? {
        if let calDate = calendarReportDate {
            return Calendar.current.isDateInToday(calDate) ? trailingSevenDayReport : weekReport(for: calDate)
        }
        return trailingSevenDayReport
    }

    func weightEntriesForReport(_ report: WeeklyReportData) -> [(date: String, weight: Double)] {
        let calendar = Calendar.current
        return allBodyMetrics
            .filter { calendar.startOfDay(for: $0.date) >= report.weekStart && calendar.startOfDay(for: $0.date) <= report.weekEnd }
            .sorted { $0.date < $1.date }
            .map { (DateFormatter.yyyyMMdd.string(from: $0.date), $0.weightKg) }
    }

    func avgTrainingCaloriesForReport(_ report: WeeklyReportData) -> Double {
        let calendar = Calendar.current
        let reportTraining = allTrainingEntries.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= report.weekStart && d <= report.weekEnd
        }
        return reportTraining.reduce(0.0) { $0 + $1.caloriesBurned } / Double(max(report.days.count, 1))
    }

    func markWeeklyReportViewed(_ weekID: String) {
        UserDefaults.standard.set(weekID, forKey: "lastViewedWeeklyReportID")
    }
}

// MARK: - HealthKit & Weight
extension HomeViewModel {
    func syncWeightFromHealthKit() {
        guard let modelContext else { return }
        let metrics = self.allBodyMetrics
        let now = Date()
        let lastSync = UserDefaults.standard.object(forKey: "lastHealthWeightSyncDate") as? Date ?? .distantPast
        guard now.timeIntervalSince(lastSync) > 6 * 3600 else { return }

        HealthKitManager.shared.fetchLatestBodyMetrics { [weak self] snapshot in
            guard let self, let snapshot else { return }
            let calendar = Calendar.current
            guard !metrics.contains(where: { calendar.isDate($0.date, inSameDayAs: snapshot.date) }),
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
                candidateDate: snapshot.date, currentLatestDate: metrics.first?.date
            ) { self.onWeightChanged?(snapshot.weightKg) }

            UserDefaults.standard.set(now, forKey: "lastHealthWeightSyncDate")
            self.sendWeightSyncNotification(snapshot: snapshot)
        }
    }

    private func sendWeightSyncNotification(snapshot: HealthBodyMetricSnapshot) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "ShapeForge"
            content.body = "Synced from Apple Health: \(String(format: "%.1f", snapshot.weightKg)) kg"
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "fitmaks.weight.sync.\(Date().timeIntervalSince1970)", content: content, trigger: nil))
        }
    }
}
