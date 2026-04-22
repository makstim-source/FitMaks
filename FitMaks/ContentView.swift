import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 🔥 ГЛАВНЫЙ ЭКРАН 🔥
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .forward) var allFoodEntries: [FoodEntry]
    @Query(sort: \TrainingEntry.date, order: .forward) var allTrainingEntries: [TrainingEntry]
    @Query var allDailySetups: [DailySetup]
    @Query var favorites: [FavoriteFood] // 🔥 Достаем холодильник
    
    @AppStorage("userGender") private var gender: String = "Male"
    @AppStorage("userAge") private var age: Int = 30
    @AppStorage("userWeight") private var weight: Double = 80.0
    @AppStorage("userHeight") private var height: Double = 180.0
    @AppStorage("userGoal") private var goal: String = "Lose Weight"
    @AppStorage("userActivity") private var activityLevel: String = "Moderate"
    @AppStorage("useCustomGoals") private var useCustomGoals: Bool = false
    @AppStorage("customCalories") private var customCalories: Double = 0.0
    @AppStorage("customProtein") private var customProtein: Double = 0.0
    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID
    
    @State private var pickingMode: EntryMode = .food
    @State private var selectedDate = Date()
    @State private var isShowingSourceDialog = false; @State private var isShowingCamera = false; @State private var selectedCameraImage: UIImage?; @State private var isShowingPhotoPicker = false; @State private var selectedPhotoItems: [PhotosPickerItem] = []; @State private var isShowingTextEntry = false; @State private var manualText = ""
    @State private var processingItems: [ProcessingItem] = []; @State private var fridgeProcessingItems: [ProcessingItem] = []; @State private var selectedEntryForEdit: FoodEntry?
    
    @State private var isShowingCalendar = false; @State private var dailySteps: Double = 0; @State private var homeWeeklySteps: [String: Double] = [:]; @State private var isShowingMyFood = false; @State private var isSelectionModeForFridge = false; @State private var initialMyFoodTab = 0; @State private var isShowingProfile = false; @State private var isShowingStats = false
    @State private var isShowingAIAssistant = false
    @State private var isShowingGoalBreakdown = false
    @State private var aiErrorMessage: String?
    @State private var pendingAIReview: AIResultReview?

    var currentDayMode: DayMode { let id = DateFormatter.yyyyMMdd.string(from: selectedDate); let storedMode = allDailySetups.first(where: { $0.dateID == id })?.mode; return DayMode.fromStoredValue(storedMode) }
    func setDayMode(_ mode: DayMode) { let id = DateFormatter.yyyyMMdd.string(from: selectedDate); if let existing = allDailySetups.first(where: { $0.dateID == id }) { existing.mode = mode.rawValue } else { modelContext.insert(DailySetup(date: selectedDate, mode: mode)) } }
    
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
    var dailyTargets: DayTargets {
        DayProgressEngine.targets(
            baseCalories: baseCaloriesGoal,
            baseProtein: baseProteinGoal,
            mode: currentDayMode
        )
    }
    var calorieGoalBonus: Double { dailyTargets.calorieBonus }
    var proteinGoalBonus: Double { dailyTargets.proteinBonus }
    var targetProtein: Double { dailyTargets.protein }
    var maxCalories: Double { dailyTargets.calories }
    let targetSteps: Double = DayProgressEngine.defaultStepTarget
    
    var dailyFoodEntries: [FoodEntry] { allFoodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyTrainingEntries: [TrainingEntry] { allTrainingEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyFeed: [TimelineItem] { let foods = dailyFoodEntries.map { TimelineItem.food($0) }; let trainings = dailyTrainingEntries.map { TimelineItem.training($0) }; return (foods + trainings).sorted { $0.createdAt > $1.createdAt } }
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
            baseCalories: baseCaloriesGoal,
            baseProtein: baseProteinGoal,
            steps: dailySteps,
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
            let mode = DayMode.fromStoredValue(allDailySetups.first(where: { $0.dateID == dateID })?.mode)
            let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }

            return DayProgressEngine.progress(
                date: date,
                foodEntries: dayFood,
                mode: mode,
                baseCalories: baseCaloriesGoal,
                baseProtein: baseProteinGoal,
                steps: homeWeeklySteps[dateID] ?? 0,
                stepTarget: targetSteps
            )
        }

        return AchievementEngine.homePerfectStreak(in: recentDays)
    }

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
            .blur(radius: selectedEntryForEdit != nil ? 15 : 0)
            
            if let entry = selectedEntryForEdit { Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedEntryForEdit = nil } }; AIChatEditView(entry: entry, onDelete: { deleteFoodEntry(entry); withAnimation { selectedEntryForEdit = nil } }, onDone: { withAnimation { selectedEntryForEdit = nil } }).transition(.scale(scale: 0.9).combined(with: .opacity)) }
        }
        .onAppear {
            HealthKitManager.shared.fetchSteps(for: selectedDate) { steps in DispatchQueue.main.async { self.dailySteps = steps } }
            HealthKitManager.shared.fetchWeeklySteps { steps in DispatchQueue.main.async { self.homeWeeklySteps = steps } }
        }
        .onChange(of: selectedDate) { _, newDate in HealthKitManager.shared.fetchSteps(for: newDate) { steps in DispatchQueue.main.async { self.dailySteps = steps } } }
        .confirmationDialog("Add Entry", isPresented: $isShowingSourceDialog) {
            Button("From Fridge ❄️") { self.isSelectionModeForFridge = true; self.initialMyFoodTab = 0; self.isShowingMyFood = true }
            Button("From Meals 🍲") { self.isSelectionModeForFridge = true; self.initialMyFoodTab = 1; self.isShowingMyFood = true }
            Button("Camera 📷") { pickingMode = .food; self.isShowingCamera = true }
            Button("Library 🖼️") { pickingMode = .food; self.isShowingPhotoPicker = true }
            Button("Type Text ✍️") { self.isShowingTextEntry = true }
            Button("Training (Whoop) 🏋️‍♂️") { pickingMode = .training; self.isShowingPhotoPicker = true }
        }
        .alert("What did you eat?", isPresented: $isShowingTextEntry) { TextField("E.g. 200g chicken and rice", text: $manualText); Button("Analyze") { guard !manualText.isEmpty else { return }; let textImg = generatePlaceholderIcon(systemName: "brain", color: .neonGreen); let item = ProcessingItem(images: [textImg], textPrompt: manualText, isTraining: false, targetDate: selectedDate); withAnimation { processingItems.append(item) }; processQueue(items: [item]); manualText = "" }; Button("Cancel", role: .cancel) { manualText = "" } }
        .fullScreenCover(isPresented: $isShowingCamera) { ImagePicker(selectedImage: $selectedCameraImage, sourceType: .camera) }
        .onChange(of: selectedCameraImage) { _, newValue in if let img = newValue { let preparedImage = img.preparedForAIIntake(); let item = ProcessingItem(images: [preparedImage], isTraining: pickingMode == .training, targetDate: selectedDate); processingItems.append(item); if pickingMode == .training { processTrainingQueue(items: [item]) } else { processQueue(items: [item]) }; selectedCameraImage = nil } }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in guard !newItems.isEmpty else { return }; Task { var loadedImages: [UIImage] = []; for item in newItems { if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { loadedImages.append(img.preparedForAIIntake()) } }; await MainActor.run { selectedPhotoItems.removeAll(); if !loadedImages.isEmpty { let newItem = ProcessingItem(images: loadedImages, isTraining: pickingMode == .training, targetDate: selectedDate); withAnimation { processingItems.append(newItem) }; if pickingMode == .training { processTrainingQueue(items: [newItem]) } else { processQueue(items: [newItem]) } } } } }
        .sheet(isPresented: $isShowingCalendar) { CustomCalendarView(selectedDate: $selectedDate, allEntries: allFoodEntries, baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal, targetSteps: targetSteps, allSetups: allDailySetups).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $isShowingMyFood) { MyFoodView(isSelectionMode: isSelectionModeForFridge, initialTab: initialMyFoodTab, selectedDate: selectedDate, processingItems: $fridgeProcessingItems, onProcessQueue: processFridgeQueue, onScanReceiptQueue: processReceiptQueue) }
        .sheet(isPresented: $isShowingProfile) { ProfileView(gender: $gender, age: $age, weight: $weight, height: $height, goal: $goal, activityLevel: $activityLevel, useCustomGoals: $useCustomGoals, customCalories: $customCalories, customProtein: $customProtein, calculatedCalories: calculatedCalories, calculatedProtein: calculatedProtein) }
        .sheet(isPresented: $isShowingStats) { StatsView(allFoodEntries: allFoodEntries, allSetups: allDailySetups, baseCalories: useCustomGoals ? customCalories : calculatedCalories, baseProtein: baseProteinGoal) }
        // 🔥 ПЕРЕДАЕМ ДАТУ И ХОЛОДИЛЬНИК В ИИ-ТРЕНЕР 🔥
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
                dayMode: currentDayMode,
                baseCalories: baseCaloriesGoal,
                calorieBonus: calorieGoalBonus,
                targetCalories: maxCalories,
                consumedCalories: dailyCaloriesConsumed,
                baseProtein: baseProteinGoal,
                proteinBonus: proteinGoalBonus,
                targetProtein: targetProtein,
                consumedProtein: dailyProtein,
                actualSteps: dailySteps,
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
        .sheet(item: $pendingAIReview) { review in
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

    func generatePlaceholderIcon(systemName: String, color: Color) -> UIImage { let size = CGSize(width: 150, height: 150); let renderer = UIGraphicsImageRenderer(size: size); return renderer.image { _ in UIColor(white: 0.15, alpha: 1.0).setFill(); UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill(); if let icon = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 60, weight: .bold))?.withTintColor(UIColor(color), renderingMode: .alwaysOriginal) { icon.draw(at: CGPoint(x: (size.width - icon.size.width) / 2, y: (size.height - icon.size.height) / 2)) } } }
    func generateEmojiIcon(emoji: String) -> UIImage { let size = CGSize(width: 150, height: 150); let renderer = UIGraphicsImageRenderer(size: size); return renderer.image { _ in UIColor(white: 0.15, alpha: 1.0).setFill(); UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill(); let safeEmoji = emoji.isEmpty ? "🍽️" : emoji; let nsString = safeEmoji as NSString; let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 75)]; let stringSize = nsString.size(withAttributes: attributes); nsString.draw(at: CGPoint(x: (size.width - stringSize.width) / 2, y: (size.height - stringSize.height) / 2), withAttributes: attributes) } }

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

            HomeIconButton(systemName: "sparkles", color: .neonCyan) {
                isShowingAIAssistant = true
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
                            Color.yellow,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(4)

                    Image(systemName: homePerfectStreak >= 7 ? "trophy.fill" : "trophy")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.fitOrange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.yellow.opacity(0.35), radius: homePerfectStreak > 0 ? 8 : 0)
                }
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Color.yellow.opacity(0.22), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.20), radius: 10)

                Text("\(homePerfectStreak)/7")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(homePerfectStreak >= 7 ? .black : .yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(homePerfectStreak >= 7 ? Color.yellow : Color.black))
                    .overlay(Capsule().stroke(Color.yellow.opacity(0.55), lineWidth: 1))
                    .offset(x: 7, y: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Progress Arena. Current streak \(homePerfectStreak) of 7 days.")
    }

    private var dailyCommandCard: some View {
        VStack(spacing: 11) {
            HStack(spacing: 6) {
                let caloriesAboveTarget = dailyCaloriesConsumed > maxCalories
                let caloriesOutsideGrace = dailyCaloriesConsumed > dailyProgress.calorieGraceLimit
                HomeMetricTile(
                    title: "Calories",
                    value: caloriesAboveTarget ? "\(Int(dailyCaloriesConsumed - maxCalories))" : "\(Int(max(dailyCaloriesRemaining, 0)))",
                    subtitle: caloriesAboveTarget ? (caloriesOutsideGrace ? "over" : "grace") : "left",
                    progress: dailyCaloriesConsumed / max(maxCalories, 1),
                    color: caloriesOutsideGrace ? .red : .neonGreen,
                    systemName: caloriesOutsideGrace ? "exclamationmark.triangle.fill" : "leaf.fill"
                )
                .onTapGesture { isShowingGoalBreakdown = true }

                HomeMetricTile(
                    title: "Protein",
                    value: "\(Int(dailyProtein))g",
                    subtitle: "of \(Int(targetProtein))g",
                    progress: dailyProtein / max(targetProtein, 1),
                    color: .neonCyan,
                    systemName: "drop.fill"
                )
                .onTapGesture { isShowingGoalBreakdown = true }

                HomeMetricTile(
                    title: "Steps",
                    value: "\(Int(dailyProgress.effectiveSteps))",
                    subtitle: dailyProgress.stepBonus > 0 ? "+\(Int(dailyProgress.stepBonus / 1000))k gym" : "of 10k",
                    progress: dailySteps / max(targetSteps, 1),
                    bonusProgress: dailyProgress.stepBonus / max(targetSteps, 1),
                    bonusColor: .fitOrange,
                    color: getStepsColor(steps: dailyProgress.effectiveSteps, target: targetSteps),
                    systemName: "shoeprints.fill"
                )
                .onTapGesture { isShowingGoalBreakdown = true }
            }

            modeSelector
        }
        .padding(12)
        .background(HomeStatsPanelBackground(isPerfectPastDay: isPerfectPastDay))
        .overlay(HomeStatsPanelCelebrationOverlay(isPerfectPastDay: isPerfectPastDay))
        .shadow(color: isPerfectPastDay ? Color.neonGreen.opacity(0.36) : Color.black.opacity(0.14), radius: isPerfectPastDay ? 18 : 10, x: 0, y: 8)
        .padding(.horizontal, 15)
    }

    private var modeSelector: some View {
        HStack(spacing: 7) {
            ForEach(DayMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        setDayMode(mode)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(mode.emoji)
                            .font(.system(size: 14))
                        Text(modeLabel(mode))
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundColor(currentDayMode == mode ? .appAccentText : .appMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(currentDayMode == mode ? Color.neonCyan : Color.appSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(currentDayMode == mode ? Color.appText.opacity(0.25) : Color.appBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
        HStack {
            HomeDockButton(title: "Food", systemName: "takeoutbag.and.cup.and.straw.fill", color: .neonCyan) {
                isSelectionModeForFridge = false
                initialMyFoodTab = 0
                isShowingMyFood = true
            }

            Spacer()

            Button(action: { isShowingSourceDialog = true }) {
                ZStack {
                    Circle()
                    .fill(Color.neonGreen)
                        .frame(width: 66, height: 66)
                        .shadow(color: Color.neonGreen.opacity(0.45), radius: 18, x: 0, y: 8)

                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.appAccentText)
                }
            }
            .buttonStyle(.plain)
            .offset(y: -8)

            Spacer()

            HomeDockButton(title: "Profile", systemName: "person.crop.circle.fill", color: .fitPurple) {
                isShowingProfile = true
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(Color.appElevated)
                .ignoresSafeArea(edges: .bottom)
                .blur(radius: 0.5)
        )
    }

    private func modeLabel(_ mode: DayMode) -> String {
        switch mode {
        case .chill:
            return "Chill"
        case .padel:
            return "Padel"
        case .gym:
            return "Gym"
        }
    }

    func processQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, [FoodResult]?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await analyzeFoodResults(for: item)
                        return (item.id, results, error)
                    }
                }

                for await (id, results, error) in group {
                    await MainActor.run {
                        guard let index = processingItems.firstIndex(where: { $0.id == id }) else {
                            return
                        }

                        let item = processingItems[index]
                        let originalImage = item.images.first ?? UIImage()
                        let entryDate = item.targetDate ?? selectedDate

                        withAnimation(.easeInOut) {
                            _ = processingItems.remove(at: index)
                        }

                        guard let results, !results.isEmpty else {
                            aiErrorMessage = friendlyAIError(error, fallback: "Food analysis failed. Please try again.")
                            return
                        }

                        stageFoodResultsIfNeeded(
                            results,
                            originalItem: item,
                            originalImage: originalImage,
                            targetDate: entryDate
                        )
                    }
                }
            }
        }
    }

    func processTrainingQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, TrainingResult?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (result, error) = await GeminiService.shared.analyzeTrainingImagesAsync(images: item.images)
                        return (item.id, result, error)
                    }
                }

                for await (id, result, error) in group {
                    await MainActor.run {
                        guard let index = processingItems.firstIndex(where: { $0.id == id }) else {
                            return
                        }

                        let item = processingItems[index]
                        let processedImage = item.images.first ?? UIImage()
                        let entryDate = item.targetDate ?? selectedDate

                        withAnimation(.easeInOut) {
                            _ = processingItems.remove(at: index)
                        }

                        guard let result else {
                            aiErrorMessage = friendlyAIError(error, fallback: "Workout analysis failed. Please try again.")
                            return
                        }

                        let entry = TrainingEntry(
                            image: processedImage,
                            name: result.activity_name,
                            caloriesBurned: result.calories_burned,
                            duration: result.duration,
                            date: entryDate
                        )

                        withAnimation(.spring()) {
                            modelContext.insert(entry)
                        }
                    }
                }
            }
        }
    }

    func processFridgeQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, [FoodResult]?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await analyzeFoodResults(for: item)
                        return (item.id, results, error)
                    }
                }

                for await (id, results, error) in group {
                    await MainActor.run {
                        guard let index = fridgeProcessingItems.firstIndex(where: { $0.id == id }) else {
                            return
                        }

                        let item = fridgeProcessingItems[index]
                        let originalImage = item.images.first ?? UIImage()

                        withAnimation(.easeInOut) {
                            _ = fridgeProcessingItems.remove(at: index)
                        }

                        guard let results, !results.isEmpty else {
                            aiErrorMessage = friendlyAIError(error, fallback: "My Food analysis failed. Please try again.")
                            return
                        }

                        stageLibraryResultsIfNeeded(
                            results,
                            originalItem: item,
                            originalImage: originalImage
                        )
                    }
                }
            }
        }
    }

    func processReceiptQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, [FoodResult]?, String?).self) { group in
                for item in items {
                    group.addTask {
                        let (results, error) = await GeminiService.shared.scanGroceriesAsync(images: item.images)
                        return (item.id, results, error)
                    }
                }

                for await (id, results, error) in group {
                    await MainActor.run {
                        guard let index = fridgeProcessingItems.firstIndex(where: { $0.id == id }) else {
                            return
                        }

                        let item = fridgeProcessingItems[index]

                        withAnimation(.easeInOut) {
                            _ = fridgeProcessingItems.remove(at: index)
                        }

                        guard let results, !results.isEmpty else {
                            aiErrorMessage = friendlyAIError(error, fallback: "Receipt scan failed. Please try again.")
                            return
                        }

                        stageReceiptResultsIfNeeded(results, originalItem: item)
                    }
                }
            }
        }
    }

    private func deleteFoodEntry(_ entry: FoodEntry) {
        GeminiService.shared.invalidateFoodImageCache(for: entry.uiImage)
        modelContext.delete(entry)
    }

    private func imageForAnalyzedResult(
        item: ProcessingItem,
        result: FoodResult,
        resultIndex: Int,
        fallbackImage: UIImage
    ) -> UIImage {
        if item.textPrompt != nil {
            return generateEmojiIcon(emoji: result.emoji ?? "🍽️")
        }

        if let sourcePhotoNumber = result.source_photo_number {
            let imageIndex = sourcePhotoNumber - 1
            if item.images.indices.contains(imageIndex) {
                return item.images[imageIndex]
            }
        }

        return item.images.indices.contains(resultIndex)
            ? item.images[resultIndex]
            : fallbackImage
    }

    private func analyzeFoodResults(for item: ProcessingItem, ignoreCache: Bool = false) async -> ([FoodResult]?, String?) {
        if let text = item.textPrompt {
            let (result, error) = await GeminiService.shared.analyzeTextAsync(text: text)
            return (result.map { [$0] }, error)
        }

        if item.images.count > 1 {
            return await GeminiService.shared.analyzeFoodItemsAsync(images: item.images, ignoreCache: ignoreCache)
        }

        let (result, error) = await GeminiService.shared.analyzeImagesAsync(images: item.images, ignoreCache: ignoreCache)
        return (result.map { [$0] }, error)
    }

    private func stageFoodResultsIfNeeded(
        _ results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        targetDate: Date
    ) {
        if results.count > 1 {
            presentAIReview(
                results: results,
                originalItem: originalItem,
                originalImage: originalImage,
                destination: .diary(targetDate)
            )
            return
        }

        addFoodResults(results, originalItem: originalItem, originalImage: originalImage, targetDate: targetDate)
    }

    private func stageLibraryResultsIfNeeded(
        _ results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage
    ) {
        if results.count > 1 {
            presentAIReview(
                results: results,
                originalItem: originalItem,
                originalImage: originalImage,
                destination: originalItem.targetTab == 1 ? .meals : .fridge
            )
            return
        }

        addLibraryResults(results, originalItem: originalItem, originalImage: originalImage)
    }

    private func stageReceiptResultsIfNeeded(_ results: [FoodResult], originalItem: ProcessingItem) {
        if results.count > 1 {
            presentAIReview(
                results: results,
                originalItem: originalItem,
                originalImage: originalItem.images.first ?? UIImage(),
                destination: .receipt
            )
            return
        }

        addReceiptResults(results)
    }

    private func presentAIReview(
        results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        destination: AIResultDestination
    ) {
        let items = results.enumerated().map { pair -> AIReviewFoodItem in
            let (index, result) = pair
            let reviewImage = imageForAnalyzedResult(
                item: originalItem,
                result: result,
                resultIndex: index,
                fallbackImage: originalImage
            ).preparedForAppStorage()

            return AIReviewFoodItem(
                image: reviewImage,
                name: result.food_name,
                calories: result.calories,
                protein: result.protein,
                ingredients: result.ingredients_breakdown
            )
        }

        let review = AIResultReview(
            title: "Review \(items.count) items",
            subtitle: "\(destination.reviewSubtitle). Uncheck anything wrong before adding.",
            actionTitle: destination.actionTitle(count: items.count),
            addingStatus: destination.addingStatus,
            destination: destination,
            originalItem: originalItem,
            originalImage: originalImage,
            items: items
        )

        let status = ProcessingItem(
            images: [originalImage],
            targetTab: originalItem.targetTab,
            targetDate: originalItem.targetDate,
            statusTitle: "Found \(items.count) items"
        )

        withAnimation(.spring()) {
            if destination.usesFridgeQueue {
                fridgeProcessingItems.append(status)
            } else {
                processingItems.append(status)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)

            await MainActor.run {
                if destination.usesFridgeQueue {
                    removeProcessingItems(ids: [status.id], from: &fridgeProcessingItems)
                } else {
                    removeProcessingItems(ids: [status.id], from: &processingItems)
                }

                pendingAIReview = review
            }
        }
    }

    private func retryReviewIgnoringCache(_ review: AIResultReview) {
        pendingAIReview = nil

        let status = ProcessingItem(
            images: [review.originalImage],
            targetTab: review.originalItem.targetTab,
            targetDate: review.originalItem.targetDate,
            statusTitle: "Recalculating fresh..."
        )

        withAnimation(.spring()) {
            if review.destination.usesFridgeQueue {
                fridgeProcessingItems.append(status)
            } else {
                processingItems.append(status)
            }
        }

        Task {
            let (results, error) = review.destination == .receipt
                ? await GeminiService.shared.scanGroceriesAsync(images: review.originalItem.images)
                : await analyzeFoodResults(for: review.originalItem, ignoreCache: true)

            await MainActor.run {
                if review.destination.usesFridgeQueue {
                    removeProcessingItems(ids: [status.id], from: &fridgeProcessingItems)
                } else {
                    removeProcessingItems(ids: [status.id], from: &processingItems)
                }

                guard let results, !results.isEmpty else {
                    aiErrorMessage = friendlyAIError(error, fallback: "Fresh AI analysis failed. Please try again.")
                    return
                }

                if results.count > 1 {
                    presentAIReview(
                        results: results,
                        originalItem: review.originalItem,
                        originalImage: review.originalImage,
                        destination: review.destination
                    )
                } else {
                    switch review.destination {
                    case .diary(let targetDate):
                        addFoodResults(results, originalItem: review.originalItem, originalImage: review.originalImage, targetDate: targetDate)
                    case .fridge, .meals:
                        addLibraryResults(results, originalItem: review.originalItem, originalImage: review.originalImage)
                    case .receipt:
                        addReceiptResults(results)
                    }
                }
            }
        }
    }

    private func confirmAIReview(_ review: AIResultReview, selectedItems: [AIReviewFoodItem]) {
        guard !selectedItems.isEmpty else { return }

        showAddingStatus(review.addingStatus, image: review.originalImage, usesFridgeQueue: review.destination.usesFridgeQueue)

        withAnimation(.spring()) {
            for item in selectedItems {
                switch review.destination {
                case .diary(let targetDate):
                    modelContext.insert(FoodEntry(
                        image: item.image,
                        name: item.name,
                        calories: item.calories,
                        protein: item.protein,
                        ingredients: item.ingredients,
                        date: targetDate
                    ))
                case .fridge, .receipt:
                    modelContext.insert(FavoriteFood(
                        image: item.image,
                        name: item.name,
                        calories: item.calories,
                        protein: item.protein,
                        ingredients: item.ingredients
                    ))
                case .meals:
                    modelContext.insert(SavedRecipe(
                        image: item.image,
                        name: item.name,
                        instructions: "",
                        calories: item.calories,
                        protein: item.protein,
                        ingredients: item.ingredients
                    ))
                }
            }
        }
    }

    private func addFoodResults(
        _ results: [FoodResult],
        originalItem: ProcessingItem,
        originalImage: UIImage,
        targetDate: Date
    ) {
        showAddingStatus("Adding to \(shortDayLabel(targetDate))", image: originalImage, usesFridgeQueue: false)

        withAnimation(.spring()) {
            for (resultIndex, result) in results.enumerated() {
                let image = imageForAnalyzedResult(
                    item: originalItem,
                    result: result,
                    resultIndex: resultIndex,
                    fallbackImage: originalImage
                )
                modelContext.insert(FoodEntry(
                    image: image,
                    name: result.food_name,
                    calories: result.calories,
                    protein: result.protein,
                    ingredients: result.ingredients_breakdown,
                    date: targetDate
                ))
            }
        }
    }

    private func addLibraryResults(_ results: [FoodResult], originalItem: ProcessingItem, originalImage: UIImage) {
        showAddingStatus(originalItem.targetTab == 1 ? "Saving to Meals" : "Saving to Fridge", image: originalImage, usesFridgeQueue: true)

        withAnimation(.spring()) {
            for (resultIndex, result) in results.enumerated() {
                let image = imageForAnalyzedResult(
                    item: originalItem,
                    result: result,
                    resultIndex: resultIndex,
                    fallbackImage: originalImage
                )

                if originalItem.targetTab == 1 {
                    modelContext.insert(SavedRecipe(
                        image: image,
                        name: result.food_name,
                        instructions: "",
                        calories: result.calories,
                        protein: result.protein,
                        ingredients: result.ingredients_breakdown
                    ))
                } else {
                    modelContext.insert(FavoriteFood(
                        image: image,
                        name: result.food_name,
                        calories: result.calories,
                        protein: result.protein,
                        ingredients: result.ingredients_breakdown
                    ))
                }
            }
        }
    }

    private func addReceiptResults(_ results: [FoodResult]) {
        showAddingStatus("Saving to Fridge", image: generateEmojiIcon(emoji: "🛒"), usesFridgeQueue: true)

        withAnimation(.spring()) {
            for result in results {
                modelContext.insert(FavoriteFood(
                    image: generateEmojiIcon(emoji: result.emoji ?? "🛒"),
                    name: result.food_name,
                    calories: result.calories,
                    protein: result.protein,
                    ingredients: result.ingredients_breakdown
                ))
            }
        }
    }

    private func showAddingStatus(_ title: String, image: UIImage, usesFridgeQueue: Bool) {
        let item = ProcessingItem(images: [image.preparedForAppStorage()], statusTitle: title)

        withAnimation(.spring()) {
            if usesFridgeQueue {
                fridgeProcessingItems.append(item)
            } else {
                processingItems.append(item)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run {
                if usesFridgeQueue {
                    removeProcessingItems(ids: [item.id], from: &fridgeProcessingItems)
                } else {
                    removeProcessingItems(ids: [item.id], from: &processingItems)
                }
            }
        }
    }

    private func shortDayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func friendlyAIError(_ error: String?, fallback: String) -> String {
        guard let error, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        if error.lowercased().contains("cancelled") {
            return "The AI request was interrupted. Please try again."
        }

        return error
    }

    private func removeProcessingItems(ids: [UUID], from items: inout [ProcessingItem]) {
        let idSet = Set(ids)
        withAnimation(.easeInOut) {
            items.removeAll { idSet.contains($0.id) }
        }
    }

    func getStepsColor(steps: Double, target: Double) -> Color { let percent = min(max(steps / target, 0.0), 1.0); return Color(red: 1.0 - (0.5 * percent), green: 0.1, blue: percent) }
    func changeDate(by days: Int) { if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate), newDate <= Date() { selectedDate = newDate } }
    func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

enum AIResultDestination: Equatable {
    case diary(Date)
    case fridge
    case receipt
    case meals

    var usesFridgeQueue: Bool {
        switch self {
        case .diary:
            return false
        case .fridge, .receipt, .meals:
            return true
        }
    }

    var reviewSubtitle: String {
        switch self {
        case .diary(let date):
            return "AI found multiple foods for \(shortLabel(for: date))"
        case .fridge:
            return "AI found multiple items for My Food"
        case .receipt:
            return "AI found multiple items on the receipt"
        case .meals:
            return "AI found multiple meals"
        }
    }

    var addingStatus: String {
        switch self {
        case .diary(let date):
            return "Adding to \(shortLabel(for: date))"
        case .fridge, .receipt:
            return "Saving to Fridge"
        case .meals:
            return "Saving to Meals"
        }
    }

    func actionTitle(count: Int) -> String {
        switch self {
        case .diary:
            return "Add \(count) to Diary"
        case .fridge, .receipt:
            return "Save \(count) to Fridge"
        case .meals:
            return "Save \(count) to Meals"
        }
    }

    private func shortLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct AIReviewFoodItem: Identifiable {
    let id = UUID()
    var image: UIImage
    var name: String
    var calories: Double
    var protein: Double
    var ingredients: String
    var isSelected = true
}

struct AIResultReview: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var actionTitle: String
    var addingStatus: String
    var destination: AIResultDestination
    var originalItem: ProcessingItem
    var originalImage: UIImage
    var items: [AIReviewFoodItem]
}

struct AIResultReviewSheet: View {
    let review: AIResultReview
    var onCancel: () -> Void
    var onRecalculate: () -> Void
    var onConfirm: ([AIReviewFoodItem]) -> Void

    @State private var items: [AIReviewFoodItem]

    init(
        review: AIResultReview,
        onCancel: @escaping () -> Void,
        onRecalculate: @escaping () -> Void,
        onConfirm: @escaping ([AIReviewFoodItem]) -> Void
    ) {
        self.review = review
        self.onCancel = onCancel
        self.onRecalculate = onRecalculate
        self.onConfirm = onConfirm
        _items = State(initialValue: review.items)
    }

    private var selectedItems: [AIReviewFoodItem] {
        items.filter { $0.isSelected }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach($items) { $item in
                            reviewRow(item: $item)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }

                footer
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI CHECKPOINT")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(1.4)

                    Text(review.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.appText)
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appMuted)
            }

            Text(review.subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private func reviewRow(item: Binding<AIReviewFoodItem>) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    item.wrappedValue.isSelected.toggle()
                }
            } label: {
                Image(systemName: item.wrappedValue.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .black))
                    .foregroundColor(item.wrappedValue.isSelected ? .neonGreen : .appMuted)
            }

            Image(uiImage: item.wrappedValue.image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 10) {
                TextField("Food name", text: item.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    metricField(title: "kcal", value: item.calories, color: .neonGreen)
                    metricField(title: "protein", value: item.protein, color: .neonCyan)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(item.wrappedValue.isSelected ? Color.appElevated : Color.appSurface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(item.wrappedValue.isSelected ? Color.neonGreen.opacity(0.24) : Color.appBorder, lineWidth: 1)
        )
    }

    private func metricField(title: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(color)
                .frame(width: 58)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.appMuted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.appSurface))
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: onRecalculate) {
                Label("Recalculate fresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.neonCyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.neonCyan.opacity(0.12)))
            }

            Button {
                onConfirm(selectedItems)
            } label: {
                Text(selectedItems.isEmpty ? "Select at least one item" : review.actionTitle)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.appAccentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(selectedItems.isEmpty ? Color.gray.opacity(0.35) : Color.neonGreen))
                    .shadow(color: Color.neonGreen.opacity(selectedItems.isEmpty ? 0 : 0.35), radius: 18, x: 0, y: 8)
            }
            .disabled(selectedItems.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(Color.appElevated.opacity(0.86).ignoresSafeArea(edges: .bottom))
    }
}
