import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Main Home Screen
struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage("seenAchievementUnlockIDs") private var seenAchievementUnlockIDs = ""
    @Query(sort: \FoodEntry.date, order: .forward) var allFoodEntries: [FoodEntry]
    @Query(sort: \TrainingEntry.date, order: .forward) var allTrainingEntries: [TrainingEntry]
    @Query var allDailySetups: [DailySetup]
    @Query var favorites: [FavoriteFood]
    @Query(sort: \BodyMetricEntry.date, order: .reverse) var allBodyMetrics: [BodyMetricEntry]

    @AppStorage("userGender") private var gender: String = "Male"
    @AppStorage("userAge") private var age: Int = 30
    @AppStorage("userWeight") var weight: Double = 80.0
    @AppStorage("userHeight") private var height: Double = 180.0
    @AppStorage("userGoal") private var goal: String = "Lose Weight"
    @AppStorage("userActivity") private var activityLevel: String = "Moderate"
    @AppStorage("useCustomGoals") private var useCustomGoals: Bool = false
    @AppStorage("customCalories") private var customCalories: Double = 0.0
    @AppStorage("customProtein") private var customProtein: Double = 0.0
    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID

    @State var pickingMode: EntryMode = .food
    @State var selectedDate = Date()
    @State private var isShowingSourceDialog = false
    @State private var isShowingCamera = false
    @State var selectedCameraImage: UIImage?
    @State private var isShowingPhotoPicker = false
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingTextEntry = false
    @State var manualText = ""
    @State var processingItems: [ProcessingItem] = []
    @State var fridgeProcessingItems: [ProcessingItem] = []
    @State private var selectedEntryForEdit: FoodEntry?
    @State private var selectedTrainingDetail: TrainingEntry?
    @State private var isShowingCalendar = false
    @State private var dailySteps: Double = 0
    @State private var homeWeeklySteps: [String: Double] = [:]
    @State private var isShowingMyFood = false
    @State private var isSelectionModeForFridge = false
    @State private var initialMyFoodTab = 0
    @State private var isShowingProfile = false
    @State private var isShowingStats = false
    @State private var isShowingAchievements = false
    @State private var livePayload: FitMaksSharePayload?
    @State private var achievementBanner: StatsAchievement?
    @State private var pendingAchievementBanners: [StatsAchievement] = []
    @State private var isShowingAIAssistant = false
    @State var isShowingGoalBreakdown = false
    @State var selectedGoalBreakdownSection: DailyGoalBreakdownSection = .calories
    @State var aiErrorMessage: String?
    @State var pendingAIReview: AIResultReview?
    @AppStorage("lastKnownBaseCaloriesGoal") var lastKnownBaseCaloriesGoal: Double = 0
    @AppStorage("lastKnownBaseProteinGoal") var lastKnownBaseProteinGoal: Double = 0

    // MARK: - Day Mode

    var currentDayMode: DayMode { dayMode(for: selectedDate) }

    func setDayMode(_ mode: DayMode) {
        setDayMode(mode, for: selectedDate)
    }

    func setDayMode(_ mode: DayMode, for date: Date) {
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

    func dayMode(for date: Date) -> DayMode {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        let storedMode = allDailySetups.first(where: { $0.dateID == id })?.mode
        return DayMode.fromStoredValue(storedMode)
    }

    func setup(for date: Date) -> DailySetup? {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        return allDailySetups.first(where: { $0.dateID == id })
    }

    // MARK: - Goals & Targets

    var calculatedProtein: Double {
        NutritionCalculator.recommendedProtein(weight: weight, goal: goal)
    }
    var calculatedCalories: Double {
        NutritionCalculator.recommendedCalories(
            gender: gender,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityLevel,
            goal: goal
        )
    }
    var baseCaloriesGoal: Double { useCustomGoals ? customCalories : calculatedCalories }
    var baseProteinGoal: Double { useCustomGoals ? customProtein : calculatedProtein }
    var selectedBaseCaloriesGoal: Double {
        setup(for: selectedDate)?.resolvedBaseCalories(for: selectedDate, fallback: baseCaloriesGoal) ?? baseCaloriesGoal
    }
    var selectedBaseProteinGoal: Double {
        setup(for: selectedDate)?.resolvedBaseProtein(for: selectedDate, fallback: baseProteinGoal) ?? baseProteinGoal
    }
    var dailyTargets: DayTargets {
        DayProgressEngine.targets(
            baseCalories: selectedBaseCaloriesGoal,
            baseProtein: selectedBaseProteinGoal,
            mode: currentDayMode,
            trainingCalories: dailyTrainingCalories
        )
    }
    var calorieGoalBonus: Double { dailyTargets.calorieBonus }
    var proteinGoalBonus: Double { dailyTargets.proteinBonus }
    var targetProtein: Double { dailyTargets.protein }
    var maxCalories: Double { dailyTargets.calories }
    let targetSteps: Double = DayProgressEngine.defaultStepTarget
    var goalSnapshotSignature: String { "\(Int(baseCaloriesGoal.rounded()))#\(Int(baseProteinGoal.rounded()))" }
    var loggedPastDaysSignature: String {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let ids = Set(
            (allFoodEntries.map(\.date) + allTrainingEntries.map(\.date))
                .filter { $0 < todayStart }
                .map { DateFormatter.yyyyMMdd.string(from: $0) }
        )

        return ids.sorted().joined(separator: "|")
    }

    // MARK: - Daily Data

    var dailyFoodEntries: [FoodEntry] { allFoodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyTrainingEntries: [TrainingEntry] { allTrainingEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyTrainingCalories: Double { dailyTrainingEntries.reduce(0) { $0 + $1.caloriesBurned } }
    var dailyUploadedTrainingSteps: Double { dailyTrainingEntries.reduce(0) { $0 + max($1.steps ?? 0, 0) } }
    var todayFoodEntries: [FoodEntry] { allFoodEntries.filter { Calendar.current.isDateInToday($0.date) } }
    var todayTrainingEntries: [TrainingEntry] { allTrainingEntries.filter { Calendar.current.isDateInToday($0.date) } }
    var todayTrainingCalories: Double { todayTrainingEntries.reduce(0) { $0 + $1.caloriesBurned } }
    var todayUploadedTrainingSteps: Double { todayTrainingEntries.reduce(0) { $0 + max($1.steps ?? 0, 0) } }
    var todayMode: DayMode {
        let dateID = DateFormatter.yyyyMMdd.string(from: Date())
        return DayMode.fromStoredValue(allDailySetups.first(where: { $0.dateID == dateID })?.mode)
    }
    var todayStepsForNotifications: Double {
        let dateID = DateFormatter.yyyyMMdd.string(from: Date())
        if let steps = homeWeeklySteps[dateID] {
            return steps
        }
        return Calendar.current.isDateInToday(selectedDate) ? dailySteps : 0
    }
    var todayProgressForNotifications: DayProgress {
        DayProgressEngine.progress(
            date: Date(),
            foodEntries: todayFoodEntries,
            trainingCalories: todayTrainingCalories,
            mode: todayMode,
            baseCalories: baseCaloriesGoal,
            baseProtein: baseProteinGoal,
            steps: todayStepsForNotifications,
            uploadedSteps: todayUploadedTrainingSteps,
            stepTarget: targetSteps
        )
    }
    var dailyReminderSignature: String {
        let foodSignature = todayFoodEntries.map { "\($0.id.uuidString):\(Int($0.calories)):\(Int($0.protein))" }.joined(separator: "|")
        let trainingSignature = todayTrainingEntries.map { "\($0.id.uuidString):\(Int($0.caloriesBurned)):\(Int($0.steps ?? 0))" }.joined(separator: "|")
        return "\(DateFormatter.yyyyMMdd.string(from: Date()))#\(foodSignature)#\(trainingSignature)#\(Int(todayStepsForNotifications))#\(todayMode.rawValue)#\(Int(baseProteinGoal))"
    }
    var dailyFeed: [TimelineItem] {
        let foods = dailyFoodEntries.map { TimelineItem.food($0) }
        let trainings = dailyTrainingEntries.map { TimelineItem.training($0) }
        return (foods + trainings).sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.training, .food):
                return true
            case (.food, .training):
                return false
            default:
                return lhs.createdAt > rhs.createdAt
            }
        }
    }
    var visibleProcessingItems: [ProcessingItem] { processingItems.sorted { $0.createdAt > $1.createdAt } }
    var dailyProtein: Double { dailyFoodEntries.reduce(0) { $0 + $1.protein } }
    var dailyCaloriesConsumed: Double { dailyFoodEntries.reduce(0) { $0 + $1.calories } }
    var dailyCaloriesRemaining: Double { maxCalories - dailyCaloriesConsumed }
    var dailyProgress: DayProgress {
        DayProgressEngine.progress(
            date: selectedDate,
            consumedCalories: dailyCaloriesConsumed,
            consumedProtein: dailyProtein,
            hasFood: !dailyFoodEntries.isEmpty,
            mode: currentDayMode,
            trainingCalories: dailyTrainingCalories,
            baseCalories: selectedBaseCaloriesGoal,
            baseProtein: selectedBaseProteinGoal,
            steps: dailySteps,
            uploadedSteps: dailyUploadedTrainingSteps,
            stepTarget: targetSteps
        )
    }

    var isPerfectPastDay: Bool {
        dailyProgress.isPerfectPastDay()
    }

    var homePerfectStreak: Int {
        let calendar = Calendar.current
        let recentDays: [DayProgress] = (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()) else {
                return nil
            }

            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let setup = allDailySetups.first(where: { $0.dateID == dateID })
            let mode = DayMode.fromStoredValue(setup?.mode)
            let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let dayTrainingCalories = allTrainingEntries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.caloriesBurned }
            let dayUploadedTrainingSteps = allTrainingEntries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + max($1.steps ?? 0, 0) }

            return DayProgressEngine.progress(
                date: date,
                foodEntries: dayFood,
                trainingCalories: dayTrainingCalories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCaloriesGoal) ?? baseCaloriesGoal,
                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProteinGoal) ?? baseProteinGoal,
                steps: homeWeeklySteps[dateID] ?? 0,
                uploadedSteps: dayUploadedTrainingSteps,
                stepTarget: targetSteps
            )
        }

        return AchievementEngine.homePerfectStreak(in: recentDays)
    }

    var homeLast30Stats: [DayProgress] {
        let calendar = Calendar.current

        return (0..<30).compactMap { index in
            let daysBack = 29 - index
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
                return nil
            }

            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let setup = allDailySetups.first(where: { $0.dateID == dateID })
            let mode = DayMode.fromStoredValue(setup?.mode)
            let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let dayTrainingCalories = allTrainingEntries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.caloriesBurned }
            let dayUploadedTrainingSteps = allTrainingEntries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + max($1.steps ?? 0, 0) }

            return DayProgressEngine.progress(
                date: date,
                foodEntries: dayFood,
                trainingCalories: dayTrainingCalories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCaloriesGoal) ?? baseCaloriesGoal,
                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProteinGoal) ?? baseProteinGoal,
                steps: homeWeeklySteps[dateID] ?? 0,
                uploadedSteps: dayUploadedTrainingSteps,
                stepTarget: targetSteps
            )
        }
    }

    var homeRecentSevenDayStats: [DayProgress] {
        Array(homeLast30Stats.suffix(7))
    }

    var homeAchievementCollection: StatsAchievementCollection {
        AchievementEngine.achievementCollection(
            last30Stats: homeLast30Stats,
            recentSevenDayStats: homeRecentSevenDayStats,
            foodEntries: allFoodEntries
        )
    }

    var unlockedAchievementSignature: String {
        homeAchievementCollection.all
            .filter(\.isUnlocked)
            .map(\.id)
            .sorted()
            .joined(separator: "|")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            homeBackground

            VStack(spacing: 10) {
                homeHeader
                dailyCommandCard
                timelinePanel
                bottomDock
            }
            .padding(.top, 8)
            .blur(radius: (selectedEntryForEdit != nil || selectedTrainingDetail != nil) ? 15 : 0)

            if let achievementBanner {
                VStack {
                    StatsAchievementUnlockBanner(achievement: achievementBanner) {
                        dismissAchievementBanner()
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(12)
            }

            if let entry = selectedEntryForEdit {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation { selectedEntryForEdit = nil } }
                AIChatEditView(
                    entry: entry,
                    onShare: {
                        livePayload = foodSharePayload(for: entry)
                    },
                    onDelete: { deleteFoodEntry(entry); withAnimation { selectedEntryForEdit = nil } },
                    onDone: { withAnimation { selectedEntryForEdit = nil } }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if let training = selectedTrainingDetail {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation { selectedTrainingDetail = nil } }
                TrainingDetailOverlay(
                    entry: training,
                    onShare: {
                        livePayload = workoutSharePayload(for: training)
                    },
                    onDone: { withAnimation { selectedTrainingDetail = nil } }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .onAppear {
            initializeGoalSnapshotTracking()
            syncWeightFromHealthKit()
            HealthKitManager.shared.fetchSteps(for: selectedDate) { steps in
                DispatchQueue.main.async {
                    self.dailySteps = steps
                    self.syncDailyReminders()
                }
            }
            HealthKitManager.shared.fetchWeeklySteps { steps in
                DispatchQueue.main.async {
                    self.homeWeeklySteps = steps
                    refreshAchievementBannerQueue()
                    self.syncDailyReminders()
                }
            }
            syncDailyReminders()
        }
        .onChange(of: unlockedAchievementSignature) { _, _ in
            refreshAchievementBannerQueue()
        }
        .onChange(of: selectedDate) { _, newDate in
            HealthKitManager.shared.fetchSteps(for: newDate) { steps in
                DispatchQueue.main.async {
                    self.dailySteps = steps
                    self.syncDailyReminders()
                }
            }
        }
        .onChange(of: goalSnapshotSignature) { _, _ in
            let oldCalories = lastKnownBaseCaloriesGoal
            let oldProtein = lastKnownBaseProteinGoal
            preserveMissingPastGoalSnapshots(
                baseCalories: oldCalories,
                baseProtein: oldProtein
            )
            snapshotTodayGoals(
                baseCalories: oldCalories,
                baseProtein: oldProtein
            )
            lastKnownBaseCaloriesGoal = baseCaloriesGoal
            lastKnownBaseProteinGoal = baseProteinGoal
            ICloudSettingsSync.pushToICloud()
        }
        .onChange(of: loggedPastDaysSignature) { _, _ in
            preserveMissingPastGoalSnapshots(
                baseCalories: baseCaloriesGoal,
                baseProtein: baseProteinGoal
            )
        }
        .onChange(of: dailyReminderSignature) { _, _ in
            syncDailyReminders()
        }
        .confirmationDialog("Add Entry", isPresented: $isShowingSourceDialog) {
            Button("From Fridge ❄️") { self.isSelectionModeForFridge = true; self.initialMyFoodTab = 0; self.isShowingMyFood = true }
            Button("From Meals 🍲") { self.isSelectionModeForFridge = true; self.initialMyFoodTab = 1; self.isShowingMyFood = true }
            Button("Camera 📷") { pickingMode = .food; self.isShowingCamera = true }
            Button("Library 🖼️") { pickingMode = .food; self.isShowingPhotoPicker = true }
            Button("Type Text ✍️") { self.isShowingTextEntry = true }
            Button("Training 🏋️‍♂️") { pickingMode = .training; self.isShowingPhotoPicker = true }
        }
        .alert("What did you eat?", isPresented: $isShowingTextEntry) {
            TextField("E.g. 200g chicken and rice", text: $manualText)
            Button("Analyze") { submitManualFoodText() }
            Button("Cancel", role: .cancel) { manualText = "" }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            ImagePicker(selectedImage: $selectedCameraImage, sourceType: .camera)
        }
        .onChange(of: selectedCameraImage) { _, newValue in
            handleCameraImage(newValue)
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in
            handleSelectedPhotoItems(newItems)
        }
        .sheet(isPresented: $isShowingCalendar) {
            CustomCalendarView(
                selectedDate: $selectedDate,
                allEntries: allFoodEntries,
                allTrainingEntries: allTrainingEntries,
                baseCalories: baseCaloriesGoal,
                baseProtein: baseProteinGoal,
                targetSteps: targetSteps,
                allSetups: allDailySetups
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingMyFood) {
            MyFoodView(
                isSelectionMode: isSelectionModeForFridge,
                initialTab: initialMyFoodTab,
                selectedDate: selectedDate,
                processingItems: $fridgeProcessingItems,
                pendingAIReview: $pendingAIReview,
                onProcessQueue: processFridgeQueue,
                onScanReceiptQueue: processReceiptQueue,
                onConfirmReview: { review, items in confirmAIReview(review, selectedItems: items) },
                onRecalculateReview: { review in retryReviewIgnoringCache(review) }
            )
        }
        .fullScreenCover(isPresented: $isShowingProfile, onDismiss: { ICloudSettingsSync.pushToICloud() }) {
            ProfileView(
                gender: $gender, age: $age, weight: $weight, height: $height,
                goal: $goal, activityLevel: $activityLevel,
                useCustomGoals: $useCustomGoals,
                customCalories: $customCalories, customProtein: $customProtein,
                calculatedCalories: calculatedCalories, calculatedProtein: calculatedProtein,
                postOptions: universalPostOptions()
            )
        }
        .sheet(isPresented: $isShowingStats) {
            StatsView(
                allFoodEntries: allFoodEntries,
                allTrainingEntries: allTrainingEntries,
                allSetups: allDailySetups,
                baseCalories: useCustomGoals ? customCalories : calculatedCalories,
                baseProtein: baseProteinGoal,
                postOptions: universalPostOptions()
            )
        }
        .fullScreenCover(isPresented: $isShowingAchievements) {
            AchievementsView(
                allFoodEntries: allFoodEntries,
                allTrainingEntries: allTrainingEntries,
                allSetups: allDailySetups,
                baseCalories: useCustomGoals ? customCalories : calculatedCalories,
                baseProtein: baseProteinGoal,
                postOptions: universalPostOptions()
            )
        }
        .fullScreenCover(item: $livePayload) { payload in
            FitMaksLiveView(payload: payload, options: universalPostOptions())
        }
        .sheet(isPresented: $isShowingAIAssistant) {
            AIAssistantView(
                selectedDate: selectedDate,
                consumedCalories: dailyCaloriesConsumed,
                consumedProtein: dailyProtein,
                targetCalories: maxCalories,
                targetProtein: targetProtein,
                foods: dailyFoodEntries,
                trainings: dailyTrainingEntries,
                favorites: favorites
            ).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingGoalBreakdown) {
            DailyCalorieBreakdownSheet(
                entries: dailyFoodEntries,
                selectedDate: selectedDate,
                section: selectedGoalBreakdownSection,
                dayMode: currentDayMode,
                trainingCalories: dailyTrainingCalories,
                baseCalories: selectedBaseCaloriesGoal,
                calorieBonus: calorieGoalBonus,
                targetCalories: maxCalories,
                consumedCalories: dailyCaloriesConsumed,
                baseProtein: selectedBaseProteinGoal,
                proteinBonus: proteinGoalBonus,
                targetProtein: targetProtein,
                consumedProtein: dailyProtein,
                actualSteps: dailySteps,
                uploadedSteps: dailyUploadedTrainingSteps,
                stepBonus: dailyProgress.stepBonus,
                targetSteps: targetSteps
            )
            .presentationDetents([.medium, .large])
        }
        .alert("AI Error", isPresented: Binding(
            get: { aiErrorMessage != nil },
            set: { if !$0 { aiErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiErrorMessage ?? "The AI request failed.")
        }
        .sheet(item: Binding<AIResultReview?>(
            get: { isShowingMyFood ? nil : pendingAIReview },
            set: { pendingAIReview = $0 }
        )) { review in
            AIResultReviewSheet(
                review: review,
                onCancel: { pendingAIReview = nil },
                onRecalculate: { retryReviewIgnoringCache(review) },
                onConfirm: { items in
                    confirmAIReview(review, selectedItems: items)
                    pendingAIReview = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - UI Components

    private var homeBackground: some View {
        HomeBackground()
    }

    private var homeHeader: some View {
        HStack(spacing: 10) {
            statsShortcutButton

            Spacer()

            HStack(spacing: 8) {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.neonGreen)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }

                Button(action: { isShowingCalendar = true }) {
                    Text(formatDate(selectedDate))
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.neonGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 82)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.appElevated))
                        .overlay(Capsule().stroke(Color.neonGreen.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.neonGreen)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .opacity(Calendar.current.isDateInToday(selectedDate) ? 0 : 1)
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }

            Spacer()

            HStack(spacing: 10) {
                HomeIconButton(systemName: "sparkles", color: .neonCyan) {
                    isShowingAIAssistant = true
                }
                .accessibilityIdentifier("aiAssistantButton")
            }
        }
        .padding(.horizontal, 16)
    }

    private var statsShortcutButton: some View {
        Button {
            isShowingStats = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.appSurface,
                                    Color.appElevated
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .trim(from: 0, to: CGFloat(min(Double(homePerfectStreak) / 7, 1)))
                        .stroke(
                            Color.fitOrange,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(4)

                    Image(systemName: homePerfectStreak >= 7 ? "flame.fill" : "flame")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.fitOrange, Color.red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.fitOrange.opacity(0.35), radius: homePerfectStreak > 0 ? 8 : 0)
                }
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Color.fitOrange.opacity(0.22), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.20), radius: 10)

                Text("\(homePerfectStreak)/7")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(homePerfectStreak >= 7 ? .black : .fitOrange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(homePerfectStreak >= 7 ? Color.fitOrange : Color.black))
                    .overlay(Capsule().stroke(Color.fitOrange.opacity(0.55), lineWidth: 1))
                    .offset(x: 7, y: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statsButton")
        .accessibilityLabel("Open Streak Mode. Current streak \(homePerfectStreak) of 7 days.")
    }

    private var dailyCommandCard: some View {
        VStack(spacing: 11) {
            HStack(spacing: 6) {
                HomeMetricTile(
                    title: "Steps",
                    value: "\(Int(dailyProgress.effectiveSteps))",
                    subtitle: "of 10k",
                    progress: dailyProgress.stepWin
                        ? dailyProgress.effectiveSteps / max(targetSteps, 1)
                        : dailyProgress.countedSteps / max(targetSteps, 1),
                    bonusProgress: dailyProgress.stepWin ? 0 : dailyProgress.stepBonus / max(targetSteps, 1),
                    bonusColor: .fitOrange,
                    color: getStepsColor(steps: dailyProgress.effectiveSteps, target: targetSteps),
                    systemName: "shoeprints.fill"
                )
                .onTapGesture { openGoalBreakdown(.steps) }

                let caloriesAboveTarget = dailyCaloriesConsumed > maxCalories
                let caloriesOutsideGrace = dailyCaloriesConsumed > dailyProgress.calorieGraceLimit
                HomeMetricTile(
                    title: "Calories",
                    value: caloriesAboveTarget ? "\(Int(dailyCaloriesConsumed - maxCalories))" : "\(Int(max(dailyCaloriesRemaining, 0)))",
                    subtitle: caloriesAboveTarget ? (caloriesOutsideGrace ? "over" : "grace") : "deficit",
                    progress: dailyCaloriesConsumed / max(maxCalories, 1),
                    color: caloriesOutsideGrace ? .red : .neonGreen,
                    systemName: caloriesOutsideGrace ? "exclamationmark.triangle.fill" : "leaf.fill"
                )
                .onTapGesture { openGoalBreakdown(.calories) }

                HomeMetricTile(
                    title: "Protein",
                    value: "\(Int(dailyProtein))g",
                    subtitle: "of \(Int(targetProtein))g",
                    progress: dailyProtein / max(targetProtein, 1),
                    color: .neonCyan,
                    systemName: "drop.fill"
                )
                .onTapGesture { openGoalBreakdown(.protein) }
            }

            modeSelectorSection
        }
        .padding(12)
        .background(HomeStatsPanelBackground(isPerfectPastDay: isPerfectPastDay))
        .overlay(HomeStatsPanelCelebrationOverlay(isPerfectPastDay: isPerfectPastDay))
        .shadow(color: isPerfectPastDay ? Color.yellow.opacity(0.05) : Color.black.opacity(0.05), radius: isPerfectPastDay ? 12 : 10, x: 0, y: 8)
        .padding(.horizontal, 15)
    }

    private var modeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            if shouldShowPlanPrompt {
                Text("What's your plan for today?")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .padding(.horizontal, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 7) {
                ForEach(DayMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            setDayMode(currentDayMode.toggled(mode))
                        }
                    } label: {
                        let isSelected = currentDayMode.includes(mode)
                        HStack(spacing: 5) {
                            Text(mode.emoji)
                                .font(.system(size: 14))
                            Text(modeLabel(mode))
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(isSelected ? .appAccentText : .appMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(isSelected ? Color.neonCyan : Color.appSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(isSelected ? Color.appText.opacity(0.25) : Color.appBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shouldShowPlanPrompt: Bool {
        Calendar.current.isDateInToday(selectedDate) && setup(for: selectedDate) == nil
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Diary")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.appText)

                Spacer()

                Text("\(dailyFeed.count) entries")
                    .font(.caption2.bold())
                    .foregroundColor(.appMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.appSurface))
            }
            .padding(.horizontal, 3)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(visibleProcessingItems) { item in HomeProcessingRow(item: item) }

                    if dailyFeed.isEmpty && processingItems.isEmpty {
                        emptyDiaryCard
                    } else {
                        ForEach(dailyFeed) { item in
                            switch item {
                            case .food(let entry):
                                HomeFoodRow(entry: entry)
                                    .onTapGesture { withAnimation(.spring()) { selectedEntryForEdit = entry } }
                                    .swipeToDelete { withAnimation(.spring()) { deleteFoodEntry(entry) } }
                            case .training(let entry):
                                HomeTrainingRow(entry: entry)
                                    .onTapGesture { withAnimation(.spring()) { selectedTrainingDetail = entry } }
                                    .swipeToDelete { withAnimation(.spring()) { modelContext.delete(entry) } }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 15)
    }

    private var emptyDiaryCard: some View {
        Button(action: { isShowingSourceDialog = true }) {
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.12))
                        .frame(width: 78, height: 78)

                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.neonGreen.opacity(0.85))
                }

                VStack(spacing: 5) {
                    Text("Start this day")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.appText)

                    Text("Add food, scan a label, or drop a workout screenshot.")
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 46)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.neonGreen.opacity(0.08), Color.white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.neonGreen.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var bottomDock: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                HomeDockButton(title: "Food", systemName: "takeoutbag.and.cup.and.straw.fill", color: .neonCyan) {
                    isSelectionModeForFridge = false
                    initialMyFoodTab = 0
                    isShowingMyFood = true
                }

                HomeDockButton(title: "Post", systemName: "camera", color: .fitOrange) {
                    livePayload = todaySharePayload()
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Button(action: { isShowingSourceDialog = true }) {
                ZStack {
                    Circle()
                        .fill(Color.neonGreen)
                        .frame(width: 62, height: 62)
                        .shadow(color: Color.neonGreen.opacity(0.45), radius: 18, x: 0, y: 8)

                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.appAccentText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Entry")
            .accessibilityIdentifier("addEntryButton")
            .offset(y: -8)
            .padding(.horizontal, 10)

            HStack(spacing: 12) {
                HomeDockButton(title: "Badges", systemName: "trophy.fill", color: .yellow) {
                    isShowingAchievements = true
                }

                HomeDockButton(title: "Profile", systemName: "person.crop.circle.badge.checkmark", color: .fitPurple) {
                    isShowingProfile = true
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(Color.appElevated)
                .ignoresSafeArea(edges: .bottom)
                .blur(radius: 0.5)
        )
    }

    private func refreshAchievementBannerQueue() {
        let seenIDs = Set(
            seenAchievementUnlockIDs
                .split(separator: "|")
                .map(String.init)
        )
        let unlocked = homeAchievementCollection.all.filter(\.isUnlocked)
        let unseen = unlocked.filter { !seenIDs.contains($0.id) }

        guard !unseen.isEmpty else { return }

        pendingAchievementBanners = unseen.sorted { lhs, rhs in
            if lhs.family != rhs.family {
                return lhs.family == .core
            }

            if lhs.rarity.rawValue != rhs.rarity.rawValue {
                return lhs.rarity.rawValue > rhs.rarity.rawValue
            }

            return lhs.title < rhs.title
        }

        if achievementBanner == nil {
            showNextAchievementBanner()
        }
    }

    private func showNextAchievementBanner() {
        guard !pendingAchievementBanners.isEmpty else { return }

        let next = pendingAchievementBanners.removeFirst()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            achievementBanner = next
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if achievementBanner?.id == next.id {
                dismissAchievementBanner()
            }
        }
    }

    private func dismissAchievementBanner() {
        guard let current = achievementBanner else { return }

        var seenIDs = Set(
            seenAchievementUnlockIDs
                .split(separator: "|")
                .map(String.init)
        )
        seenIDs.insert(current.id)
        seenAchievementUnlockIDs = seenIDs.sorted().joined(separator: "|")

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            achievementBanner = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showNextAchievementBanner()
        }
    }
}
