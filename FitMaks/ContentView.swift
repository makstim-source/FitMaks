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

    @AppStorage("userGender") fileprivate var gender: String = "Male"
    @AppStorage("userAge") fileprivate var age: Int = 30
    @AppStorage("userWeight") var weight: Double = 80.0
    @AppStorage("userHeight") fileprivate var height: Double = 180.0
    @AppStorage("userGoal") fileprivate var goal: String = "Lose Weight"
    @AppStorage("userActivity") fileprivate var activityLevel: String = "Moderate"
    @AppStorage("useCustomGoals") fileprivate var useCustomGoals: Bool = false
    @AppStorage("customCalories") fileprivate var customCalories: Double = 0.0
    @AppStorage("customProtein") fileprivate var customProtein: Double = 0.0
    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID

    @AppStorage("lastKnownBaseCaloriesGoal") var lastKnownBaseCaloriesGoal: Double = 0
    @AppStorage("lastKnownBaseProteinGoal") var lastKnownBaseProteinGoal: Double = 0
    @AppStorage("hasMigratedCarbsFat") private var hasMigratedCarbsFat = false
    @AppStorage("lastViewedWeeklyReportID") private var lastViewedWeeklyReportID = ""

    @State var viewModel = HomeViewModel()
    @State private var syncWorkItem: DispatchWorkItem?
    @State private var isShowingCopyDayDialog = false

    // MARK: - Day Mode

    var currentDayMode: DayMode { viewModel.dayMode(for: viewModel.selectedDate) }

    func setup(for date: Date) -> DailySetup? {
        let id = DateFormatter.yyyyMMdd.string(from: date)
        return viewModel.setupIndex[id]
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
        setup(for: viewModel.selectedDate)?.resolvedBaseCalories(for: viewModel.selectedDate, fallback: baseCaloriesGoal) ?? baseCaloriesGoal
    }
    var selectedBaseProteinGoal: Double {
        setup(for: viewModel.selectedDate)?.resolvedBaseProtein(for: viewModel.selectedDate, fallback: baseProteinGoal) ?? baseProteinGoal
    }
    var dailyTargets: DayTargets {
        DayProgressEngine.targets(
            baseCalories: selectedBaseCaloriesGoal,
            baseProtein: selectedBaseProteinGoal,
            mode: currentDayMode,
            trainingCalories: dailyTrainingCalories,
            activityLevel: activityLevel
        )
    }
    var calorieGoalBonus: Double { dailyTargets.calorieBonus }
    var proteinGoalBonus: Double { dailyTargets.proteinBonus }
    var targetProtein: Double { dailyTargets.protein }
    var maxCalories: Double { dailyTargets.calories }
    let targetSteps: Double = DayProgressEngine.defaultStepTarget
    var goalSnapshotSignature: String { "\(Int(baseCaloriesGoal.rounded()))#\(Int(baseProteinGoal.rounded()))" }
    var loggedPastDaysSignature: String { viewModel.cachedLoggedPastDaysSignature }

    // MARK: - Daily Data

    var dailyFoodEntries: [FoodEntry] { viewModel.cachedDailyFood }
    var dailyTrainingEntries: [TrainingEntry] { viewModel.cachedDailyTraining }
    var dailyTrainingCalories: Double { viewModel.cachedDailyTrainingCalories }
    var dailyUploadedTrainingSteps: Double { viewModel.cachedDailyUploadedSteps }
    var todayFoodEntries: [FoodEntry] { viewModel.cachedTodayFood }
    var todayTrainingEntries: [TrainingEntry] { viewModel.cachedTodayTraining }
    var todayTrainingCalories: Double { todayTrainingEntries.reduce(0) { $0 + $1.caloriesBurned } }
    var todayUploadedTrainingSteps: Double { todayTrainingEntries.reduce(0) { $0 + max($1.steps ?? 0, 0) } }
    var todayMode: DayMode {
        let dateID = DateFormatter.yyyyMMdd.string(from: Date())
        return DayMode.fromStoredValue(viewModel.setupIndex[dateID]?.mode)
    }
    var todayStepsForNotifications: Double {
        let dateID = DateFormatter.yyyyMMdd.string(from: Date())
        if let steps = viewModel.homeWeeklySteps[dateID] {
            return steps
        }
        return Calendar.current.isDateInToday(viewModel.selectedDate) ? viewModel.dailySteps : 0
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
            activityLevel: activityLevel,
            stepTarget: targetSteps
        )
    }
    var dailyReminderSignature: String {
        let foodSignature = todayFoodEntries.map { "\($0.id.uuidString):\(Int($0.calories)):\(Int($0.protein))" }.joined(separator: "|")
        let trainingSignature = todayTrainingEntries.map { "\($0.id.uuidString):\(Int($0.caloriesBurned)):\(Int($0.steps ?? 0))" }.joined(separator: "|")
        return "\(DateFormatter.yyyyMMdd.string(from: Date()))#\(foodSignature)#\(trainingSignature)#\(Int(todayStepsForNotifications))#\(todayMode.rawValue)#\(Int(baseProteinGoal))"
    }
    var dailyFeed: [TimelineItem] { viewModel.cachedDailyFeed }
    var visibleProcessingItems: [ProcessingItem] { viewModel.processingItems.sorted { $0.createdAt > $1.createdAt } }
    var dailyProtein: Double { viewModel.cachedDailyProtein }
    var dailyCarbs: Double { viewModel.cachedDailyCarbs }
    var dailyFat: Double { viewModel.cachedDailyFat }
    var baseTargetCarbs: Double { max(selectedBaseCaloriesGoal - selectedBaseProteinGoal * 4, 0) * 0.55 / 4 }
    var baseTargetFat: Double { max(selectedBaseCaloriesGoal - selectedBaseProteinGoal * 4, 0) * 0.45 / 9 }
    var targetCarbs: Double { max(maxCalories - targetProtein * 4, 0) * 0.55 / 4 }
    var targetFat: Double { max(maxCalories - targetProtein * 4, 0) * 0.45 / 9 }
    var dailyCaloriesConsumed: Double { viewModel.cachedDailyCalories }
    var dailyCaloriesRemaining: Double { maxCalories - dailyCaloriesConsumed }
    var dailyProgress: DayProgress {
        DayProgressEngine.progress(
            date: viewModel.selectedDate,
            consumedCalories: dailyCaloriesConsumed,
            consumedProtein: dailyProtein,
            hasFood: !dailyFoodEntries.isEmpty,
            mode: currentDayMode,
            trainingCalories: dailyTrainingCalories,
            baseCalories: selectedBaseCaloriesGoal,
            baseProtein: selectedBaseProteinGoal,
            steps: viewModel.dailySteps,
            uploadedSteps: dailyUploadedTrainingSteps,
            activityLevel: activityLevel,
            stepTarget: targetSteps
        )
    }

    var isPerfectPastDay: Bool {
        dailyProgress.isPerfectPastDay()
    }

    var homePerfectStreak: Int { viewModel.cachedPerfectStreak }
    var homeLast30Stats: [DayProgress] { viewModel.cachedLast30Stats }
    var homeRecentSevenDayStats: [DayProgress] { Array(homeLast30Stats.suffix(7)) }
    var homeAchievementCollection: StatsAchievementCollection { viewModel.cachedAchievementCollection }
    var previousWeekReport: WeeklyReportData? { WeeklyReportData.previousWeek(from: homeLast30Stats, allFoodEntries: allFoodEntries) }
    var shouldShowWeeklyBanner: Bool {
        guard let report = previousWeekReport else { return false }
        return lastViewedWeeklyReportID != report.weekID
    }
    func weekReport(for date: Date) -> WeeklyReportData? {
        WeeklyReportData.forWeekContaining(
            date: date,
            allFoodEntries: allFoodEntries,
            allTrainingEntries: allTrainingEntries,
            setupIndex: viewModel.setupIndex,
            baseCaloriesGoal: baseCaloriesGoal,
            baseProteinGoal: baseProteinGoal,
            stepsIndex: viewModel.homeWeeklySteps,
            activityLevel: activityLevel
        )
    }
    var activeWeeklyReport: WeeklyReportData? {
        if let calDate = viewModel.calendarReportDate {
            return weekReport(for: calDate)
        }
        return previousWeekReport
    }

    var unlockedAchievementSignature: String {
        homeAchievementCollection.all
            .filter(\.isUnlocked)
            .map(\.id)
            .sorted()
            .joined(separator: "|")
    }

    var copyablePlanDates: [Date] {
        let calendar = Calendar.current
        let selected = calendar.startOfDay(for: viewModel.selectedDate)

        let foodDates = allFoodEntries.map { calendar.startOfDay(for: $0.date) }
        let setupDates = allDailySetups.compactMap { DateFormatter.yyyyMMdd.date(from: $0.dateID) }

        return Array(Set(foodDates + setupDates))
            .filter { $0 != selected }
            .sorted(by: >)
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Body

    
    fileprivate func syncViewModel() {
        viewModel.sync(
            weight: weight,
            baseCaloriesGoal: baseCaloriesGoal,
            baseProteinGoal: baseProteinGoal,
            allDailySetups: allDailySetups,
            allFoodEntries: allFoodEntries,
            allTrainingEntries: allTrainingEntries,
            activityLevel: activityLevel,
            modelContext: modelContext
        )
    }

    fileprivate func debouncedSync() {
        syncWorkItem?.cancel()
        let item = DispatchWorkItem { [self] in syncViewModel() }
        syncWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }

    var body: some View {
        ZStack {
            homeBackground

            VStack(spacing: 10) {
                homeHeader
                dailyCommandCard
                if shouldShowWeeklyBanner, let report = previousWeekReport {
                    WeeklyReportBanner(report: report) {
                        viewModel.calendarReportDate = nil
                        viewModel.isShowingWeeklyReport = true
                    }
                    .padding(.horizontal, 15)
                }
                timelinePanel
                bottomDock
            }
            .padding(.top, 8)
            .blur(radius: (viewModel.selectedEntryForEdit != nil || viewModel.selectedTrainingDetail != nil) ? 15 : 0)

            if let banner = viewModel.achievementBanner {
                Color.appScrim
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(12)

                StatsAchievementUnlockPopup(
                    achievement: banner,
                    onPost: {
                        postAchievementBanner()
                    },
                    onDismiss: {
                        dismissAchievementBanner()
                    }
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(13)
            }

            if let entry = viewModel.selectedEntryForEdit {
                Color.appScrim
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation { viewModel.selectedEntryForEdit = nil } }
                AIChatEditView(
                    entry: entry,
                    onShare: {
                        viewModel.livePayload = foodSharePayload(for: entry)
                    },
                    onDelete: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); viewModel.deleteFoodEntry(entry); withAnimation { viewModel.selectedEntryForEdit = nil } },
                    onDone: { syncViewModel(); withAnimation { viewModel.selectedEntryForEdit = nil } }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if let training = viewModel.selectedTrainingDetail {
                Color.appScrim
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation { viewModel.selectedTrainingDetail = nil } }
                TrainingDetailOverlay(
                    entry: training,
                    onShare: {
                        viewModel.livePayload = workoutSharePayload(for: training)
                    },
                    onDone: { withAnimation { viewModel.selectedTrainingDetail = nil } }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        
        .fullScreenCover(isPresented: $viewModel.isShowingMyFood, onDismiss: { viewModel.isBuildMealMode = false }) {
            MyFoodView(
                isSelectionMode: viewModel.isSelectionModeForFridge,
                initialTab: viewModel.initialMyFoodTab,
                initialBuildMode: viewModel.isBuildMealMode,
                selectedDate: viewModel.selectedDate,
                processingItems: $viewModel.fridgeProcessingItems,
                pendingAIReview: $viewModel.pendingAIReview,
                onProcessQueue: viewModel.processFridgeQueue,
                onScanReceiptQueue: viewModel.processReceiptQueue,
                onConfirmReview: { review, items in viewModel.confirmAIReview(review, selectedItems: items) },
                onRecalculateReview: { review in viewModel.retryReviewIgnoringCache(review) }
            )
        }
        .fullScreenCover(isPresented: $viewModel.isShowingProfile, onDismiss: { ICloudSettingsSync.pushToICloud() }) {
            ProfileView(
                gender: $gender, age: $age, weight: $weight, height: $height,
                goal: $goal, activityLevel: $activityLevel,
                useCustomGoals: $useCustomGoals,
                customCalories: $customCalories, customProtein: $customProtein,
                calculatedCalories: calculatedCalories, calculatedProtein: calculatedProtein,
                postOptions: universalPostOptions()
            )
        }
        .sheet(isPresented: $viewModel.isShowingWeeklyReport, onDismiss: {
            viewModel.calendarReportDate = nil
        }) {
            if let report = activeWeeklyReport {
                WeeklyReportSheet(report: report) {
                    viewModel.isShowingWeeklyReport = false
                    let snapshot = FitMaksShareWeeklySnapshot(
                        dateRange: report.dateRangeLabel,
                        score: report.weeklyScore,
                        scoreLabel: "\(report.scoreEmoji) \(report.scoreLabel)",
                        perfectDays: report.perfectDays,
                        avgCalories: "\(Int(report.avgCalories)) kcal",
                        avgProtein: "\(Int(report.avgProtein))g",
                        avgCarbs: "\(Int(report.avgCarbs))g",
                        avgFat: "\(Int(report.avgFat))g",
                        totalSteps: Int(report.totalSteps).formatted(),
                        dayResults: report.days.map {
                            FitMaksShareWeeklyDay(
                                label: ShareFormatters.shortWeekdayName(for: $0.date).uppercased(),
                                dayNumber: "\($0.date.formatted(.dateTime.day()))",
                                modeEmoji: $0.mode.emoji,
                                modeLabel: viewModel.modeLabel($0.mode),
                                isPerfect: $0.isPerfect,
                                calorieWin: $0.calorieWin,
                                proteinWin: $0.proteinWin,
                                stepWin: $0.stepWin
                            )
                        },
                        scoreColor: report.scoreColor
                    )
                    viewModel.livePayload = .weeklyReport(snapshot)
                }
                .onAppear {
                    if let prev = previousWeekReport, report.weekID == prev.weekID {
                        lastViewedWeeklyReportID = report.weekID
                    }
                }
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $viewModel.isShowingStats) {
            StatsView(
                allFoodEntries: allFoodEntries,
                allTrainingEntries: allTrainingEntries,
                allSetups: allDailySetups,
                baseCalories: useCustomGoals ? customCalories : calculatedCalories,
                baseProtein: baseProteinGoal,
                postOptions: universalPostOptions()
            )
        }
        .fullScreenCover(isPresented: $viewModel.isShowingAchievements) {
            AchievementsView(
                allFoodEntries: allFoodEntries,
                allTrainingEntries: allTrainingEntries,
                allSetups: allDailySetups,
                baseCalories: useCustomGoals ? customCalories : calculatedCalories,
                baseProtein: baseProteinGoal,
                postOptions: universalPostOptions()
            )
        }
        .fullScreenCover(item: $viewModel.livePayload) { payload in
            FitMaksLiveView(payload: payload, options: universalPostOptions())
        }
        .sheet(isPresented: $viewModel.isShowingAIAssistant) {
            AIAssistantView(
                selectedDate: viewModel.selectedDate,
                consumedCalories: dailyCaloriesConsumed,
                consumedProtein: dailyProtein,
                consumedCarbs: dailyCarbs,
                consumedFat: dailyFat,
                targetCalories: maxCalories,
                targetProtein: targetProtein,
                targetCarbs: targetCarbs,
                targetFat: targetFat,
                foods: dailyFoodEntries,
                trainings: dailyTrainingEntries,
                favorites: favorites
            ).presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.isShowingGoalBreakdown) {
            DailyCalorieBreakdownSheet(
                entries: dailyFoodEntries,
                selectedDate: viewModel.selectedDate,
                section: viewModel.selectedGoalBreakdownSection,
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
                baseCarbs: baseTargetCarbs,
                targetCarbs: targetCarbs,
                consumedCarbs: dailyCarbs,
                targetFat: targetFat,
                consumedFat: dailyFat,
                actualSteps: viewModel.dailySteps,
                uploadedSteps: dailyUploadedTrainingSteps,
                stepBonus: dailyProgress.stepBonus,
                targetSteps: targetSteps
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Copy from another day",
            isPresented: $isShowingCopyDayDialog,
            titleVisibility: .visible
        ) {
            ForEach(copyablePlanDates, id: \.self) { sourceDate in
                Button(copySourceTitle(for: sourceDate)) {
                    copyDayEntries(from: sourceDate)
                }
            }
        } message: {
            Text("Copy meals and mode into the selected day.")
        }
        .alert("AI Error", isPresented: Binding(
            get: { viewModel.aiErrorMessage != nil },
            set: { if !$0 { viewModel.aiErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.aiErrorMessage ?? "The AI request failed.")
        }
        .sheet(item: Binding<AIResultReview?>(
            get: { viewModel.isShowingMyFood ? nil : viewModel.pendingAIReview },
            set: { viewModel.pendingAIReview = $0 }
        )) { review in
            AIResultReviewSheet(
                review: review,
                onCancel: { viewModel.pendingAIReview = nil },
                onRecalculate: { viewModel.retryReviewIgnoringCache(review) },
                onConfirm: { items in
                    viewModel.confirmAIReview(review, selectedItems: items)
                    viewModel.pendingAIReview = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .applyStateObservers(self)
        .overlay {
            if viewModel.isShowingSourceDialog {
                Color.appScrim
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.8)) { viewModel.isShowingSourceDialog = false } }
                    .transition(.opacity)

                VStack {
                    Spacer()
                    NewEntrySheet(
                        onFromFridge: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.isSelectionModeForFridge = true; viewModel.initialMyFoodTab = 0; viewModel.isShowingMyFood = true },
                        onFromMeals: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.isSelectionModeForFridge = true; viewModel.initialMyFoodTab = 1; viewModel.isShowingMyFood = true },
                        onBuildMeal: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.isBuildMealMode = true; viewModel.isShowingMyFood = true },
                        onCamera: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.pickingMode = .food; viewModel.isShowingCamera = true },
                        onLibrary: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.pickingMode = .food; viewModel.isShowingPhotoPicker = true },
                        onTypeText: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.isShowingTextEntry = true },
                        onTraining: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.pickingMode = .training; viewModel.isShowingPhotoPicker = true },
                        onTypeTraining: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.isShowingTrainingTextEntry = true },
                        onFAQ: { withAnimation { viewModel.isShowingSourceDialog = false }; viewModel.isShowingFAQ = true },
                        onCancel: { withAnimation(.easeOut(duration: 0.2)) { viewModel.isShowingSourceDialog = false } }
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: viewModel.isShowingSourceDialog)
        .sheet(isPresented: $viewModel.isShowingFAQ) {
            FAQSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.isShowingPaywall) {
            PaywallView()
        }
        .alert("What did you eat?", isPresented: $viewModel.isShowingTextEntry) {
            TextField("E.g. 200g chicken and rice", text: $viewModel.manualText)
            Button("Analyze") { viewModel.submitManualFoodText() }
            Button("Cancel", role: .cancel) { viewModel.manualText = "" }
        }
        .alert("Describe your workout", isPresented: $viewModel.isShowingTrainingTextEntry) {
            TextField("E.g. 40 min run 5km", text: $viewModel.manualText)
            Button("Analyze") { viewModel.submitManualTrainingText() }
            Button("Cancel", role: .cancel) { viewModel.manualText = "" }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            ImagePicker(selectedImage: $viewModel.selectedCameraImage, sourceType: .camera)
        }
        .onChange(of: viewModel.selectedCameraImage) { _, newValue in
            viewModel.handleCameraImage(newValue)
        }
        .photosPicker(isPresented: $viewModel.isShowingPhotoPicker, selection: $viewModel.selectedPhotoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: viewModel.selectedPhotoItems) { _, newItems in
            viewModel.handleSelectedPhotoItems(newItems)
        }
        .sheet(isPresented: $viewModel.isShowingCalendar) {
            CustomCalendarView(
                selectedDate: $viewModel.selectedDate,
                allEntries: allFoodEntries,
                allTrainingEntries: allTrainingEntries,
                baseCalories: baseCaloriesGoal,
                baseProtein: baseProteinGoal,
                targetSteps: targetSteps,
                allSetups: allDailySetups,
                onWeeklyReport: { monday in
                    viewModel.isShowingCalendar = false
                    viewModel.calendarReportDate = monday
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        viewModel.isShowingWeeklyReport = true
                    }
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
        let pastel = isPastelDayTheme()
        let headerAccent = pastel ? Color.fitPurple : Color.neonGreen
        let assistantAccent = pastel ? Color.neonCyan : Color.neonCyan

        return HStack(spacing: 10) {
            statsShortcutButton

            Spacer()

            HStack(spacing: 8) {
                Button(action: { viewModel.changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(headerAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(themeChromeGradient()))
                        .overlay(Circle().stroke(headerAccent.opacity(pastel ? 0.24 : 0.14), lineWidth: 1))
                }

                Button(action: { viewModel.isShowingCalendar = true }) {
                    Text(viewModel.formatDate(viewModel.selectedDate))
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(headerAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 82)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(themeCardGradient()))
                        .overlay(Capsule().stroke(headerAccent.opacity(pastel ? 0.22 : 0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(headerAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(themeChromeGradient()))
                        .overlay(Circle().stroke(headerAccent.opacity(pastel ? 0.24 : 0.14), lineWidth: 1))
                }
                .opacity(Calendar.current.isDateInTomorrow(viewModel.selectedDate) ? 0 : 1)
                .disabled(Calendar.current.isDateInTomorrow(viewModel.selectedDate))
            }

            Spacer()

            HStack(spacing: 10) {
                HomeIconButton(systemName: "sparkles", color: assistantAccent) {
                    if SubscriptionManager.shared.isPro {
                        viewModel.isShowingAIAssistant = true
                    } else {
                        viewModel.isShowingPaywall = true
                    }
                }
                .accessibilityIdentifier("aiAssistantButton")
            }
        }
        .padding(.horizontal, 16)
    }

    private var statsShortcutButton: some View {
        Button {
            viewModel.isShowingStats = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(themeChromeGradient())

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
                .shadow(color: themeShadowColor().opacity(0.85), radius: 12)

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
        let pastel = isPastelDayTheme()

        return VStack(spacing: 11) {
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
                    color: viewModel.getStepsColor(steps: dailyProgress.effectiveSteps, target: targetSteps),
                    systemName: "shoeprints.fill"
                )
                .onTapGesture { viewModel.openGoalBreakdown(.steps) }

                let caloriesAboveTarget = dailyCaloriesConsumed > maxCalories
                let caloriesOutsideGrace = dailyCaloriesConsumed > dailyProgress.calorieGraceLimit
                HomeMetricTile(
                    title: "Calories",
                    value: caloriesAboveTarget ? "\(Int(dailyCaloriesConsumed - maxCalories))" : "\(Int(max(dailyCaloriesRemaining, 0)))",
                    subtitle: caloriesAboveTarget ? (caloriesOutsideGrace ? "over" : "grace") : "deficit",
                    progress: dailyCaloriesConsumed / max(maxCalories, 1),
                    color: caloriesOutsideGrace ? .red : .neonGreen,
                    systemName: caloriesOutsideGrace ? "exclamationmark.triangle.fill" : "flame.fill"
                )
                .onTapGesture { viewModel.openGoalBreakdown(.calories) }

                HomeMetricTile(
                    title: "Protein",
                    value: "\(Int(dailyProtein))g",
                    subtitle: "of \(Int(targetProtein))g",
                    progress: dailyProtein / max(targetProtein, 1),
                    color: .neonCyan,
                    systemName: "drop.fill"
                )
                .onTapGesture { viewModel.openGoalBreakdown(.protein) }
            }

            HStack(spacing: 8) {
                HomeCarbControlCard(
                    consumed: dailyCarbs,
                    baseTarget: baseTargetCarbs,
                    activeTarget: targetCarbs
                )
                .onTapGesture { viewModel.openGoalBreakdown(.carbs) }

                HomeFatControlCard(
                    consumed: dailyFat,
                    target: targetFat
                )
                .onTapGesture { viewModel.openGoalBreakdown(.fat) }
            }

            modeSelectorSection
        }
        .padding(12)
        .background(HomeStatsPanelBackground(isPerfectPastDay: isPerfectPastDay))
        .overlay(HomeStatsPanelCelebrationOverlay(isPerfectPastDay: isPerfectPastDay))
        .shadow(color: isPerfectPastDay ? Color.yellow.opacity(pastel ? 0.05 : 0.08) : themeShadowColor().opacity(pastel ? 0.20 : 0.55), radius: isPerfectPastDay ? (pastel ? 8 : 12) : (pastel ? 7 : 10), x: 0, y: pastel ? 4 : 8)
        .padding(.horizontal, 15)
    }

    private var modeSelectorSection: some View {
        let pastel = isPastelDayTheme()
        let iphoneGlass = isIPhoneGlassTheme()

        return VStack(alignment: .leading, spacing: 7) {
            if shouldShowPlanPrompt {
                Text(Calendar.current.isDateInTomorrow(viewModel.selectedDate)
                     ? "Plan tomorrow's mode"
                     : "What's your plan for today?")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .padding(.horizontal, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 7) {
                ForEach(DayMode.allCases, id: \.self) { mode in
                    let accentColor = modeAccentColor(mode, iphoneGlass: iphoneGlass)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            viewModel.setDayMode(currentDayMode.toggled(mode), for: viewModel.selectedDate)
                        }
                    } label: {
                        let isSelected = currentDayMode.includes(mode)
                        HStack(spacing: 5) {
                            Text(mode.emoji)
                                .font(.system(size: 14))
                            Text(viewModel.modeLabel(mode))
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(isSelected ? .appText : .appMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, pastel ? 6 : 5)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(
                                    isSelected
                                        ? LinearGradient(
                                            colors: [accentColor.opacity(0.22), accentColor.opacity(0.08), Color.appSurface],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : (pastel
                                            ? LinearGradient(colors: [Color.appElevated, Color.appSurface], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [Color.appSurface, Color.appElevated], startPoint: .topLeading, endPoint: .bottomTrailing))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(isSelected ? accentColor.opacity(0.35) : Color.appBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(pastel ? 4 : 0)
            .background(
                Group {
                    if iphoneGlass {
                        RoundedRectangle(cornerRadius: 17)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.appSurface,
                                        Color.appElevated,
                                        Color.appSurface
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 17)
                                    .stroke(Color.appBorder, lineWidth: 1)
                            )
                    } else if pastel {
                        RoundedRectangle(cornerRadius: 17)
                            .fill(Color.appSurface.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17)
                                    .stroke(Color.appBorder.opacity(0.8), lineWidth: 1)
                            )
                    }
                }
            )
        }
    }

    private var shouldShowPlanPrompt: Bool {
        let cal = Calendar.current
        let date = viewModel.selectedDate
        return (cal.isDateInToday(date) || cal.isDateInTomorrow(date)) && setup(for: date) == nil
    }

    private func modeAccentColor(_ mode: DayMode, iphoneGlass: Bool) -> Color {
        switch mode {
        case .chill:
            return .neonCyan
        case .cardio:
            return .fitOrange
        case .gym, .cardioGym:
            return .fitPurple
        }
    }

    private var timelinePanel: some View {
        let pastel = isPastelDayTheme()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DIARY")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .tracking(0.5)

                Spacer()

                Text("\(dailyFeed.count) entries")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.appMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.appSurface))
            }
            .padding(.horizontal, 3)

            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 10) {
                    ForEach(visibleProcessingItems) { item in HomeProcessingRow(item: item) }

                    if dailyFeed.isEmpty && viewModel.processingItems.isEmpty {
                        emptyDiaryCard
                    } else {
                        ForEach(dailyFeed) { item in
                            switch item {
                            case .food(let entry):
                                HomeFoodRow(entry: entry)
                                    .onTapGesture { withAnimation(.spring()) { viewModel.selectedEntryForEdit = entry } }
                                    .swipeToDelete {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.spring()) { viewModel.deleteFoodEntry(entry) }
                                    }
                            case .training(let entry):
                                HomeTrainingRow(entry: entry)
                                    .onTapGesture { withAnimation(.spring()) { viewModel.selectedTrainingDetail = entry } }
                                    .swipeToDelete {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        withAnimation(.spring()) { modelContext.delete(entry) }
                                    }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.visible)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(themeCardGradient())
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
        )
        .shadow(color: themeShadowColor().opacity(pastel ? 0.14 : 0.5), radius: pastel ? 8 : 12, x: 0, y: pastel ? 3 : 8)
        .padding(.horizontal, 15)
    }

    private var emptyDiaryCard: some View {
        let pastel = isPastelDayTheme()
        let glass = isIPhoneGlassTheme()
        let accent = glass ? Color.neonGreen : (pastel ? Color.neonCyan : Color.neonGreen)
        let isTomorrow = Calendar.current.isDateInTomorrow(viewModel.selectedDate)

        return VStack(spacing: 14) {
            Button(action: { viewModel.isShowingSourceDialog = true }) {
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 78, height: 78)

                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(accent.opacity(0.85))
                    }

                    VStack(spacing: 5) {
                        Text(isTomorrow ? "Plan tomorrow" : "Start this day")
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(.appText)

                        Text(isTomorrow
                             ? "Pre-log meals and set your training mode."
                             : "Add food, scan a label, or drop a workout screenshot.")
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
                                colors: glass
                                    ? [Color.neonGreen.opacity(0.08), Color.appSurface, Color.appElevated]
                                    : (pastel
                                        ? [Color.appElevated, Color.appSurface, Color.appElevated]
                                        : [Color.neonGreen.opacity(0.10), Color.appSurface.opacity(0.84), Color.appElevated]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(accent.opacity(glass ? 0.18 : (pastel ? 0.16 : 0.18)), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if !copyablePlanDates.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isShowingCopyDayDialog = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .black))

                        Text("Copy from another day")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundColor(.appText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.appSurface))
                    .overlay(
                        Capsule()
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomDock: some View {
        let pastel = isPastelDayTheme()
        let iphoneGlass = isIPhoneGlassTheme()

        return HStack(spacing: 0) {
            HStack(spacing: 12) {
                HomeDockButton(title: "Food", systemName: "takeoutbag.and.cup.and.straw.fill", color: .neonCyan) {
                    viewModel.isSelectionModeForFridge = false
                    viewModel.initialMyFoodTab = 0
                    viewModel.isShowingMyFood = true
                }

                HomeDockButton(title: "Post", systemName: "camera.fill", color: .fitOrange) {
                    viewModel.livePayload = todaySharePayload()
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.isShowingSourceDialog = true
            }) {
                ZStack {
                    Circle()
                        .fill(themePrimaryButtonGradient())
                        .frame(width: 62, height: 62)
                        .shadow(color: themeShadowColor().opacity(0.95), radius: 20, x: 0, y: 8)

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
                HomeDockButton(title: "Badges", systemName: "medal.fill", color: .yellow) {
                    viewModel.isShowingAchievements = true
                }

                HomeDockButton(title: "Profile", systemName: "person.crop.circle.badge.checkmark", color: .fitPurple) {
                    viewModel.isShowingProfile = true
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(
                    AnyShapeStyle(
                        iphoneGlass
                            ? LinearGradient(
                                colors: [
                                    Color.appSurface.opacity(0.6),
                                    Color.appElevated
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : themeCardGradient()
                    )
                )
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(height: 0.5)
                }
                .blur(radius: pastel ? 0 : 0.5)
        )
    }

    fileprivate func refreshAchievementBannerQueue() {
        let seenIDs = Set(
            seenAchievementUnlockIDs
                .split(separator: "|")
                .map(String.init)
        )
        let unlocked = homeAchievementCollection.all.filter(\.isUnlocked)
        let unseen = unlocked.filter { !seenIDs.contains($0.id) }

        guard !unseen.isEmpty else { return }

        viewModel.pendingAchievementBanners = unseen.sorted { lhs, rhs in
            if lhs.family != rhs.family {
                return lhs.family == .core
            }

            if lhs.rarity.rawValue != rhs.rarity.rawValue {
                return lhs.rarity.rawValue > rhs.rarity.rawValue
            }

            return lhs.title < rhs.title
        }

        if viewModel.achievementBanner == nil {
            showNextAchievementBanner()
        }
    }

    private func showNextAchievementBanner() {
        guard !viewModel.pendingAchievementBanners.isEmpty else { return }

        let next = viewModel.pendingAchievementBanners.removeFirst()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            viewModel.achievementBanner = next
        }
    }

    private func dismissAchievementBanner() {
        guard let current = viewModel.achievementBanner else { return }

        var seenIDs = Set(
            seenAchievementUnlockIDs
                .split(separator: "|")
                .map(String.init)
        )
        seenIDs.insert(current.id)
        seenAchievementUnlockIDs = seenIDs.sorted().joined(separator: "|")

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            viewModel.achievementBanner = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [self] in
            showNextAchievementBanner()
        }
    }

    private func postAchievementBanner() {
        guard let current = viewModel.achievementBanner else { return }
        let payload = achievementSharePayload(from: current)
        dismissAchievementBanner()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            viewModel.livePayload = payload
        }
    }


    fileprivate func migrateCarbsFatIfNeeded() {
        guard !hasMigratedCarbsFat else { return }
        hasMigratedCarbsFat = true

        func estimate(_ calories: Double, _ protein: Double) -> (carbs: Double, fat: Double) {
            let remaining = max(calories - protein * 4, 0)
            return (remaining * 0.55 / 4, remaining * 0.45 / 9)
        }

        let foodEntries = (try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? []
        for entry in foodEntries where entry.carbs == 0 && entry.fat == 0 && entry.calories > 0 {
            let (c, f) = estimate(entry.calories, entry.protein)
            entry.carbs = c
            entry.fat = f
        }

        let favorites = (try? modelContext.fetch(FetchDescriptor<FavoriteFood>())) ?? []
        for fav in favorites where fav.carbs == 0 && fav.fat == 0 && fav.calories > 0 {
            let (c, f) = estimate(fav.calories, fav.protein)
            fav.carbs = c
            fav.fat = f
        }

        let recipes = (try? modelContext.fetch(FetchDescriptor<SavedRecipe>())) ?? []
        for recipe in recipes where recipe.carbs == 0 && recipe.fat == 0 && recipe.calories > 0 {
            let (c, f) = estimate(recipe.calories, recipe.protein)
            recipe.carbs = c
            recipe.fat = f
        }

        try? modelContext.save()
    }

    fileprivate func handleOnAppear() {
        migrateCarbsFatIfNeeded()
        syncViewModel()
        var tempCalories = lastKnownBaseCaloriesGoal
        var tempProtein = lastKnownBaseProteinGoal
        viewModel.initializeGoalSnapshotTracking(lastKnownCalories: &tempCalories, lastKnownProtein: &tempProtein)
        lastKnownBaseCaloriesGoal = tempCalories
        lastKnownBaseProteinGoal = tempProtein
        
        viewModel.syncWeightFromHealthKit(allBodyMetrics: allBodyMetrics) { newWeight in weight = newWeight }
        
        HealthKitManager.shared.fetchSteps(for: viewModel.selectedDate) { steps in
            DispatchQueue.main.async {
                self.viewModel.dailySteps = steps
                self.viewModel.syncDailyReminders(todayProgressForNotifications: self.todayProgressForNotifications, todayFoodEntries: self.todayFoodEntries)
            }
        }
        HealthKitManager.shared.fetchWeeklySteps { steps in
            DispatchQueue.main.async {
                self.viewModel.homeWeeklySteps = steps
                self.refreshAchievementBannerQueue()
                self.viewModel.syncDailyReminders(todayProgressForNotifications: self.todayProgressForNotifications, todayFoodEntries: self.todayFoodEntries)
            }
        }
        viewModel.syncDailyReminders(todayProgressForNotifications: todayProgressForNotifications, todayFoodEntries: todayFoodEntries)
    }

    fileprivate func handleDateChange(_ newDate: Date) {
        viewModel.rebuildDailyCache()
        HealthKitManager.shared.fetchSteps(for: newDate) { steps in
            DispatchQueue.main.async {
                self.viewModel.dailySteps = steps
                self.viewModel.syncDailyReminders(todayProgressForNotifications: self.todayProgressForNotifications, todayFoodEntries: self.todayFoodEntries)
            }
        }
    }

    fileprivate func handleGoalSnapshotChange() {
        let oldCalories = lastKnownBaseCaloriesGoal
        let oldProtein = lastKnownBaseProteinGoal
        viewModel.preserveMissingPastGoalSnapshots(baseCalories: oldCalories, baseProtein: oldProtein)
        viewModel.snapshotTodayGoals(baseCalories: oldCalories, baseProtein: oldProtein)
        lastKnownBaseCaloriesGoal = baseCaloriesGoal
        lastKnownBaseProteinGoal = baseProteinGoal
        ICloudSettingsSync.pushToICloud()
    }

    fileprivate func handleLoggedPastDaysChange() {
        viewModel.preserveMissingPastGoalSnapshots(baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal)
    }

    private func copySourceTitle(for date: Date) -> String {
        "\(ShareFormatters.weekdayName(for: date)) · \(DateFormatter.shortDate.string(from: date))"
    }

    private func copyDayEntries(from sourceDate: Date) {
        let calendar = Calendar.current
        let destinationDate = calendar.startOfDay(for: viewModel.selectedDate)
        let sourceFoods = allFoodEntries
            .filter { calendar.isDate($0.date, inSameDayAs: sourceDate) }
            .sorted { ($0.createdAt ?? $0.date) < ($1.createdAt ?? $1.date) }

        for (index, entry) in sourceFoods.enumerated() {
            let fallbackImage = viewModel.generatePlaceholderIcon(systemName: "fork.knife.circle.fill", color: .neonGreen)
            let copied = FoodEntry(
                image: entry.uiImage ?? fallbackImage,
                name: entry.name,
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat,
                ingredients: entry.ingredients,
                date: destinationDate,
                location: entry.location
            )
            copied.createdAt = Date().addingTimeInterval(Double(index))
            modelContext.insert(copied)
        }

        viewModel.setDayMode(viewModel.dayMode(for: sourceDate), for: destinationDate)
        try? modelContext.save()
        syncViewModel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
extension View {
    func applyStateObservers(_ view: ContentView) -> some View {
        self
            .applyDataObservers(view)
            .applyEventObservers(view)
    }

    private func applyDataObservers(_ view: ContentView) -> some View {
        self
            .onChange(of: view.weight) { _, _ in view.syncViewModel() }
            .onChange(of: view.baseCaloriesGoal) { _, _ in view.syncViewModel() }
            .onChange(of: view.baseProteinGoal) { _, _ in view.syncViewModel() }
            .applyQueryObservers(view)
    }

    private func applyQueryObservers(_ view: ContentView) -> some View {
        self
            .onChange(of: view.allDailySetups) { _, _ in view.debouncedSync() }
            .onChange(of: view.allFoodEntries) { _, _ in view.debouncedSync() }
            .onChange(of: view.allTrainingEntries) { _, _ in view.debouncedSync() }
    }

    private func applyEventObservers(_ view: ContentView) -> some View {
        self
            .onAppear { view.handleOnAppear() }
            .onChange(of: view.viewModel.selectedDate) { _, newDate in view.handleDateChange(newDate) }
            .onChange(of: view.goalSnapshotSignature) { _, _ in view.handleGoalSnapshotChange() }
            .onChange(of: view.loggedPastDaysSignature) { _, _ in view.handleLoggedPastDaysChange() }
            .onChange(of: view.dailyReminderSignature) { _, _ in
                view.viewModel.syncDailyReminders(todayProgressForNotifications: view.todayProgressForNotifications, todayFoodEntries: view.todayFoodEntries)
            }
    }

}
