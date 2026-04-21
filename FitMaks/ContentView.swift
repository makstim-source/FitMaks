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
    
    @State private var isShowingCalendar = false; @State private var dailySteps: Double = 0; @State private var isShowingMyFood = false; @State private var isSelectionModeForFridge = false; @State private var initialMyFoodTab = 0; @State private var isShowingProfile = false; @State private var isShowingStats = false
    @State private var isShowingAIAssistant = false
    @State private var isShowingGoalBreakdown = false
    @State private var aiErrorMessage: String?

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
    var dailyFeed: [TimelineItem] { let foods = dailyFoodEntries.map { TimelineItem.food($0) }; let trainings = dailyTrainingEntries.map { TimelineItem.training($0) }; return (foods + trainings).sorted { $0.date < $1.date } }
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
            
            if let entry = selectedEntryForEdit { Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedEntryForEdit = nil } }; AIChatEditView(entry: entry, onDelete: { modelContext.delete(entry); withAnimation { selectedEntryForEdit = nil } }, onDone: { withAnimation { selectedEntryForEdit = nil } }).transition(.scale(scale: 0.9).combined(with: .opacity)) }
        }
        .onAppear { HealthKitManager.shared.fetchSteps(for: selectedDate) { steps in DispatchQueue.main.async { self.dailySteps = steps } } }
        .onChange(of: selectedDate) { _, newDate in HealthKitManager.shared.fetchSteps(for: newDate) { steps in DispatchQueue.main.async { self.dailySteps = steps } } }
        .confirmationDialog("Add Entry", isPresented: $isShowingSourceDialog) {
            Button("From Fridge ❄️") { self.isSelectionModeForFridge = true; self.initialMyFoodTab = 0; self.isShowingMyFood = true }
            Button("From Meals 🍲") { self.isSelectionModeForFridge = true; self.initialMyFoodTab = 1; self.isShowingMyFood = true }
            Button("Camera 📷") { pickingMode = .food; self.isShowingCamera = true }
            Button("Library 🖼️") { pickingMode = .food; self.isShowingPhotoPicker = true }
            Button("Type Text ✍️") { self.isShowingTextEntry = true }
            Button("Training (Whoop) 🏋️‍♂️") { pickingMode = .training; self.isShowingPhotoPicker = true }
        }
        .alert("What did you eat?", isPresented: $isShowingTextEntry) { TextField("E.g. 200g chicken and rice", text: $manualText); Button("Analyze") { guard !manualText.isEmpty else { return }; let textImg = generatePlaceholderIcon(systemName: "brain", color: .neonGreen); let item = ProcessingItem(images: [textImg], textPrompt: manualText, isTraining: false); withAnimation { processingItems.append(item) }; processQueue(items: [item]); manualText = "" }; Button("Cancel", role: .cancel) { manualText = "" } }
        .fullScreenCover(isPresented: $isShowingCamera) { ImagePicker(selectedImage: $selectedCameraImage, sourceType: .camera) }
        .onChange(of: selectedCameraImage) { _, newValue in if let img = newValue { let item = ProcessingItem(images: [img], isTraining: pickingMode == .training); processingItems.append(item); if pickingMode == .training { processTrainingQueue(items: [item]) } else { processQueue(items: [item]) }; selectedCameraImage = nil } }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in guard !newItems.isEmpty else { return }; Task { var loadedImages: [UIImage] = []; for item in newItems { if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { loadedImages.append(img) } }; await MainActor.run { selectedPhotoItems.removeAll(); if !loadedImages.isEmpty { let newItem = ProcessingItem(images: loadedImages, isTraining: pickingMode == .training); withAnimation { processingItems.append(newItem) }; if pickingMode == .training { processTrainingQueue(items: [newItem]) } else { processQueue(items: [newItem]) } } } } }
        .sheet(isPresented: $isShowingCalendar) { CustomCalendarView(selectedDate: $selectedDate, allEntries: allFoodEntries, baseCalories: baseCaloriesGoal, baseProtein: baseProteinGoal, targetSteps: targetSteps, allSetups: allDailySetups).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $isShowingMyFood) { MyFoodView(isSelectionMode: isSelectionModeForFridge, initialTab: initialMyFoodTab, selectedDate: selectedDate, processingItems: $fridgeProcessingItems, onProcessQueue: processFridgeQueue) }
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
                consumedProtein: dailyProtein
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
    }

    func generatePlaceholderIcon(systemName: String, color: Color) -> UIImage { let size = CGSize(width: 150, height: 150); let renderer = UIGraphicsImageRenderer(size: size); return renderer.image { _ in UIColor(white: 0.15, alpha: 1.0).setFill(); UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill(); if let icon = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 60, weight: .bold))?.withTintColor(UIColor(color), renderingMode: .alwaysOriginal) { icon.draw(at: CGPoint(x: (size.width - icon.size.width) / 2, y: (size.height - icon.size.height) / 2)) } } }
    func generateEmojiIcon(emoji: String) -> UIImage { let size = CGSize(width: 150, height: 150); let renderer = UIGraphicsImageRenderer(size: size); return renderer.image { _ in UIColor(white: 0.15, alpha: 1.0).setFill(); UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill(); let safeEmoji = emoji.isEmpty ? "🍽️" : emoji; let nsString = safeEmoji as NSString; let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 75)]; let stringSize = nsString.size(withAttributes: attributes); nsString.draw(at: CGPoint(x: (size.width - stringSize.width) / 2, y: (size.height - stringSize.height) / 2), withAttributes: attributes) } }

    private var homeBackground: some View {
        LinearGradient(
            colors: [
                Color.appBackgroundStart,
                Color.appBackgroundMid,
                Color.appBackgroundEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.neonCyan.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 45)
                .offset(x: 80, y: -95)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.neonGreen.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: -120, y: 80)
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 10) {
            homeIconButton(systemName: "chart.bar.xaxis", color: .neonGreen) {
                isShowingStats = true
            }

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

            homeIconButton(systemName: "sparkles", color: .neonCyan) {
                isShowingAIAssistant = true
            }
        }
        .padding(.horizontal, 16)
    }

    private var dailyCommandCard: some View {
        VStack(spacing: 11) {
            HStack(spacing: 6) {
                let caloriesAboveTarget = dailyCaloriesConsumed > maxCalories
                let caloriesOutsideGrace = dailyCaloriesConsumed > dailyProgress.calorieGraceLimit
                metricTile(
                    title: "Calories",
                    value: caloriesAboveTarget ? "\(Int(dailyCaloriesConsumed - maxCalories))" : "\(Int(max(dailyCaloriesRemaining, 0)))",
                    subtitle: caloriesAboveTarget ? (caloriesOutsideGrace ? "over" : "grace") : "left",
                    progress: dailyCaloriesConsumed / max(maxCalories, 1),
                    color: caloriesOutsideGrace ? .red : .neonGreen,
                    systemName: caloriesOutsideGrace ? "exclamationmark.triangle.fill" : "leaf.fill"
                )
                .onTapGesture { isShowingGoalBreakdown = true }

                metricTile(
                    title: "Protein",
                    value: "\(Int(dailyProtein))g",
                    subtitle: "of \(Int(targetProtein))g",
                    progress: dailyProtein / max(targetProtein, 1),
                    color: .neonCyan,
                    systemName: "drop.fill"
                )
                .onTapGesture { isShowingGoalBreakdown = true }

                metricTile(
                    title: "Steps",
                    value: "\(Int(dailySteps))",
                    subtitle: "of 10k",
                    progress: dailySteps / max(targetSteps, 1),
                    color: getStepsColor(steps: dailySteps, target: targetSteps),
                    systemName: "shoeprints.fill"
                )
            }

            modeSelector
        }
        .padding(12)
        .background(statsPanelBackground)
        .overlay(statsPanelCelebrationOverlay)
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
                    ForEach(processingItems) { item in loadingRow(item: item) }

                    if dailyFeed.isEmpty && processingItems.isEmpty {
                        emptyDiaryCard
                    } else {
                        ForEach(dailyFeed.reversed()) { item in
                            switch item {
                            case .food(let entry):
                                foodRow(entry: entry)
                                    .onTapGesture { withAnimation(.spring()) { selectedEntryForEdit = entry } }
                                    .swipeToDelete { withAnimation(.spring()) { modelContext.delete(entry) } }
                            case .training(let entry):
                                trainingRow(entry: entry)
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
            dockButton(title: "Food", systemName: "takeoutbag.and.cup.and.straw.fill", color: .neonCyan) {
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

            dockButton(title: "Profile", systemName: "person.crop.circle.fill", color: .fitPurple) {
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

    private var dayStatusTitle: String {
        if isPerfectPastDay {
            return "Collected clean."
        }

        if dailyFeed.isEmpty {
            return "Ready when you are."
        }

        if dailyCaloriesConsumed > maxCalories {
            return "Watch the finish."
        }

        if dailyProgress.proteinWin {
            return "Protein locked."
        }

        return "Build the win."
    }

    private func homeIconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color.appSurface)
                        .overlay(Circle().stroke(color.opacity(0.16), lineWidth: 1))
                )
                .shadow(color: color.opacity(0.18), radius: 10)
        }
        .buttonStyle(.plain)
    }

    private func metricTile(title: String, value: String, subtitle: String, progress: Double, color: Color, systemName: String) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)
                .lineLimit(1)

            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.34), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.55), radius: progress >= 1 ? 13 : 6)

                VStack(spacing: 0) {
                    Image(systemName: systemName)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(color)
                        .padding(.bottom, 1)

                    Text(value)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.appText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(subtitle)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 5)
            }
            .frame(width: 74, height: 74)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.09), lineWidth: 1))
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

    private func dockButton(title: String, systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.appSurface))
                    .overlay(Circle().stroke(color.opacity(0.18), lineWidth: 1))

                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
    }

    func foodRow(entry: FoodEntry) -> some View {
        HStack(spacing: 13) {
            if let image = entry.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.neonGreen.opacity(0.12))
                    Image(systemName: "fork.knife")
                        .foregroundColor(.neonGreen)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(Int(entry.calories)) kcal", systemImage: "flame.fill")
                        .foregroundColor(.neonGreen)
                    Label("\(Int(entry.protein))g", systemImage: "drop.fill")
                        .foregroundColor(.neonCyan)
                }
                .font(.caption.bold())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.appMuted)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
        )
    }
    
    func trainingRow(entry: TrainingEntry) -> some View {
        HStack(spacing: 13) {
            if let image = entry.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.25), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.14))
                    Image(systemName: "figure.run")
                        .foregroundColor(.blue)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)

                Label("\(Int(entry.caloriesBurned)) kcal burned · \(entry.duration)", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.blue.opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.blue.opacity(0.20), lineWidth: 1))
        )
    }

    func loadingRow(item: ProcessingItem) -> some View {
        let color: Color = item.isTraining ? .blue : .neonGreen

        return HStack(spacing: 13) {
            if let firstImage = item.images.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(Color.black.opacity(0.18).clipShape(RoundedRectangle(cornerRadius: 15)))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.textPrompt != nil ? "Reading text..." : "AI is analyzing...")
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(color.opacity(0.55))
                            .frame(width: 32, height: 5)
                    }
                }
            }

            Spacer()
            ProgressView().tint(color)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.24), lineWidth: 1))
        )
    }

    func processQueue(items: [ProcessingItem]) { Task { await withTaskGroup(of: (UUID, FoodResult?, String?).self) { group in for item in items { group.addTask { if let text = item.textPrompt { let (result, error) = await analyzeTextAsync(text: text); return (item.id, result, error) } else { let (result, error) = await analyzeImagesAsync(images: item.images); return (item.id, result, error) } } }; for await (id, result, error) in group { await MainActor.run { if let index = processingItems.firstIndex(where: { $0.id == id }) { let item = processingItems[index]; let originalImage = item.images.first ?? UIImage(); withAnimation(.easeInOut) { _ = processingItems.remove(at: index) }; if let res = result {
        let finalImage = item.textPrompt != nil ? generateEmojiIcon(emoji: res.emoji ?? "🍽️") : originalImage
        let entry = FoodEntry(image: finalImage, name: res.food_name, calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown, date: selectedDate); withAnimation(.spring()) { modelContext.insert(entry) }
    } else { aiErrorMessage = error ?? "Food analysis failed. Please try again." } } } } } } }
    
    func processTrainingQueue(items: [ProcessingItem]) { Task { await withTaskGroup(of: (UUID, TrainingResult?, String?).self) { group in for item in items { group.addTask { let (result, error) = await analyzeTrainingImagesAsync(images: item.images); return (item.id, result, error) } }; for await (id, result, error) in group { await MainActor.run { if let index = processingItems.firstIndex(where: { $0.id == id }) { let processedImage = processingItems[index].images.first ?? UIImage(); withAnimation(.easeInOut) { _ = processingItems.remove(at: index) }; if let res = result { let entry = TrainingEntry(image: processedImage, name: res.activity_name, caloriesBurned: res.calories_burned, duration: res.duration, date: selectedDate); withAnimation(.spring()) { modelContext.insert(entry) } } else { aiErrorMessage = error ?? "Workout analysis failed. Please try again." } } } } } } }
    func processFridgeQueue(items: [ProcessingItem]) { Task { await withTaskGroup(of: (UUID, FoodResult?, String?).self) { group in for item in items { group.addTask { if let text = item.textPrompt { let (result, error) = await analyzeTextAsync(text: text); return (item.id, result, error) } else { let (result, error) = await analyzeImagesAsync(images: item.images); return (item.id, result, error) } } }; for await (id, result, error) in group { await MainActor.run { if let index = fridgeProcessingItems.firstIndex(where: { $0.id == id }) { let item = fridgeProcessingItems[index]; let originalImage = item.images.first ?? UIImage(); withAnimation(.easeInOut) { _ = fridgeProcessingItems.remove(at: index) }; if let res = result { let finalImage = item.textPrompt != nil ? generateEmojiIcon(emoji: res.emoji ?? "🍽️") : originalImage; if item.targetTab == 1 { modelContext.insert(SavedRecipe(image: finalImage, name: res.food_name, instructions: "", calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown)) } else { modelContext.insert(FavoriteFood(image: finalImage, name: res.food_name, calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown)) } } else { aiErrorMessage = error ?? "My Food analysis failed. Please try again." } } } } } } }
    
    func analyzeImagesAsync(images: [UIImage]) async -> (FoodResult?, String?) { await withCheckedContinuation { continuation in GeminiService.shared.analyzeImages(images: images) { result, error in continuation.resume(returning: (result, error)) } } }
    func analyzeTextAsync(text: String) async -> (FoodResult?, String?) { await withCheckedContinuation { continuation in GeminiService.shared.analyzeText(text: text) { result, error in continuation.resume(returning: (result, error)) } } }
    func analyzeTrainingImagesAsync(images: [UIImage]) async -> (TrainingResult?, String?) { await withCheckedContinuation { continuation in GeminiService.shared.analyzeTrainingImages(images: images) { result, error in continuation.resume(returning: (result, error)) } } }

    @ViewBuilder
    var statsPanelBackground: some View {
        if isPerfectPastDay {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.neonGreen.opacity(0.24),
                            Color.neonCyan.opacity(0.18),
                            Color.appElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSurface)
        }
    }

    @ViewBuilder
    var statsPanelCelebrationOverlay: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isPerfectPastDay
                    ? LinearGradient(colors: [.neonGreen, .neonCyan, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isPerfectPastDay ? 2 : 0
                )

            if isPerfectPastDay {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))

                    Text("PERFECT DAY")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                }
                .foregroundColor(.appAccentText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.neonGreen))
                .shadow(color: .neonGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                .offset(x: -12, y: -10)
            }
        }
    }
    
    func statCircle(title: String, displayValue: Double, fillValue: Double, total: Double, color: Color, label: String) -> some View { VStack(spacing: 12) { Text(title).font(.caption2).bold().foregroundColor(.appMuted); ZStack { Circle().stroke(lineWidth: 7).foregroundColor(Color.appText.opacity(0.18)); let isCompleted = fillValue >= total; let glowRadius: CGFloat = isCompleted ? 15 : 4; let glowOpacity: Double = isCompleted ? 0.9 : 0.4; Circle().trim(from: 0, to: CGFloat(min(fillValue/total, 1.0))).stroke(style: StrokeStyle(lineWidth: 7, lineCap: .round)).foregroundColor(color).rotationEffect(.degrees(-90)).shadow(color: color.opacity(glowOpacity), radius: glowRadius, x: 0, y: 0); VStack(spacing: 0) { Text("\(Int(displayValue))").font(.headline).bold().foregroundColor(.appText); Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.appMuted) } }.frame(width: 75, height: 75) }.frame(maxWidth: .infinity) }
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

// MARK: - 🔥 ЭКРАН ИИ-ТРЕНЕРА 🔥
struct AIAssistantView: View {
    @Environment(\.dismiss) var dismiss
    
    var selectedDate: Date
    var consumedCalories: Double
    var consumedProtein: Double
    var targetCalories: Double
    var targetProtein: Double
    var foods: [FoodEntry]
    var trainings: [TrainingEntry]
    var favorites: [FavoriteFood] // 🔥 Список холодильника

    @State private var messages: [ChatMessage] = []
    @State private var userMessage = ""
    @State private var attachedImage: UIImage? = nil
    @State private var isShowingAttachmentDialog = false
    @State private var isShowingAttachmentPicker = false
    @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    @State private var isWaiting = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.appBackgroundStart,
                        Color.appBackgroundMid,
                        Color.appBackgroundEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                coachPulseCard

                                ForEach(messages) { msg in
                                    CoachMessageBubble(message: msg, accentColor: .neonCyan)
                                        .id(msg.id)
                                }

                                if isWaiting {
                                    CoachTypingBubble(accentColor: .neonCyan)
                                        .id("TypingIndicator")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 20)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastID = messages.last?.id {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isWaiting) { _, waiting in
                            if waiting {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    proxy.scrollTo("TypingIndicator", anchor: .bottom)
                                }
                            }
                        }
                    }

                    chatComposer
                }
            }
            .navigationTitle(Calendar.current.isDateInToday(selectedDate) ? "AI Coach ✨" : "Past Day Review 📅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.foregroundColor(.appMuted) } }
            .onAppear { if messages.isEmpty { fetchSummary(isInitial: true, message: "", image: nil) } }
            .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
            .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
        }.preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private var coachPulseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(Calendar.current.isDateInToday(selectedDate) ? "TODAY'S PULSE" : "DAY REVIEW", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.neonCyan)
                    .tracking(0.9)

                Spacer()

                Text(DateFormatter.shortDate.string(from: selectedDate))
                    .font(.caption)
                    .foregroundColor(.appMuted)
            }

            Text(coachHeadline)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.appText)
                .lineLimit(2)

            VStack(spacing: 10) {
                miniGoal(
                    title: "Calories",
                    value: consumedCalories,
                    target: targetCalories,
                    color: consumedCalories > AppRules.caloriePerfectLimit(for: targetCalories) ? .red : .neonGreen,
                    detail: consumedCalories > targetCalories
                        ? (consumedCalories > AppRules.caloriePerfectLimit(for: targetCalories) ? "\(Int(consumedCalories - targetCalories)) over" : "\(Int(consumedCalories - targetCalories)) over · grace")
                        : "\(Int(max(targetCalories - consumedCalories, 0))) left"
                )

                miniGoal(
                    title: "Protein",
                    value: consumedProtein,
                    target: targetProtein,
                    color: .neonCyan,
                    detail: consumedProtein >= targetProtein
                        ? "closed"
                        : (consumedProtein >= AppRules.completionMinimum(for: targetProtein) ? "within 3% grace" : "\(Int(max(targetProtein - consumedProtein, 0)))g missing")
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.neonCyan.opacity(0.16),
                            Color.neonGreen.opacity(0.08),
                            Color.appElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: Color.neonCyan.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var coachHeadline: String {
        if Calendar.current.isDateInToday(selectedDate) {
            if consumedProtein >= AppRules.completionMinimum(for: targetProtein)
                && consumedCalories <= AppRules.caloriePerfectLimit(for: targetCalories)
                && consumedCalories > 0 {
                return "Strong day. Protect the win."
            }

            return "Ask for the next smart move."
        }

        return "Review the day, keep the lesson."
    }

    private func miniGoal(title: String, value: Double, target: Double, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.appMuted)

                Spacer()

                Text(detail)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appText.opacity(0.08))

                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(min(max(value / max(target, 1), 0), 1)))
                        .shadow(color: color.opacity(0.45), radius: 8)
                }
            }
            .frame(height: 7)
        }
    }

    private var chatComposer: some View {
        VStack(spacing: 10) {
            if let image = attachedImage {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 62, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.neonCyan, lineWidth: 2)
                            )

                        Button(action: { withAnimation { attachedImage = nil } }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black))
                        }
                        .offset(x: 8, y: -8)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            HStack(spacing: 12) {
                Button(action: { isShowingAttachmentDialog = true }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.neonCyan)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.appSurface))
                }

                TextField("Ask for a meal move, plan, or review...", text: $userMessage)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Capsule().fill(Color.appElevated))
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    .foregroundColor(.appText)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.appAccentText)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill((userMessage.isEmpty && attachedImage == nil) || isWaiting ? Color.gray : Color.neonCyan)
                        )
                        .shadow(color: Color.neonCyan.opacity((userMessage.isEmpty && attachedImage == nil) || isWaiting ? 0 : 0.45), radius: 10)
                }
                .disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            Rectangle()
                .fill(Color.appElevated)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    func sendMessage() {
        let text = userMessage
        let imageToSend = attachedImage
        messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend))
        userMessage = ""
        withAnimation { attachedImage = nil }
        fetchSummary(isInitial: false, message: text, image: imageToSend)
    }

    func fetchSummary(isInitial: Bool, message: String, image: UIImage?) {
        isWaiting = true
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: Date())

        let isPastDay = !Calendar.current.isDateInToday(selectedDate)
        
        let mealNames = foods.map { "\($0.name) (\(Int($0.calories)) kcal, \(Int($0.protein))g P)" }
        let workoutNames = trainings.map { "\($0.name) (\(Int($0.caloriesBurned)) kcal burned)" }
        
        // 🔥 Собираем холодильник для ИИ 🔥
        let fridgeNames = favorites.map { "\($0.name) (\(Int($0.calories))kcal, \(Int($0.protein))g protein)" }

        GeminiService.shared.sendCoachMessage(image: image, message: message, isInitial: isInitial, isPastDay: isPastDay, timeOfDay: timeString, consumedCalories: consumedCalories, consumedProtein: consumedProtein, targetCalories: targetCalories, targetProtein: targetProtein, meals: mealNames, workouts: workoutNames, fridgeItems: fridgeNames) { result, error in
            DispatchQueue.main.async {
                self.isWaiting = false
                let aiText = result ?? error ?? "Oops, something went wrong connecting to the AI. Try again!"
                self.messages.append(ChatMessage(text: aiText, isUser: false, shouldTypewrite: true))
            }
        }
    }
}

// MARK: - ЧАТ И РЕДАКТОР ЕДЫ
struct AIChatEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: FoodEntry
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0
    @State private var attachedImage: UIImage? = nil; @State private var isShowingAttachmentDialog = false; @State private var isShowingAttachmentPicker = false; @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    @State private var isShowingSaveDialog = false

    var onDelete: () -> Void; var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.neonGreen)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Analysis")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.appText)

                    Text(entry.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                }

                Spacer()

                HStack(spacing: 14) {
                    Button(action: { isShowingSaveDialog = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.neonCyan)
                            .font(.system(size: 17, weight: .bold))
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.85))
                            .font(.system(size: 17, weight: .bold))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.appSurface, Color.appElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, accentColor: .neonGreen.opacity(0.8))
                        ForEach(messages) { msg in
                            VStack(spacing: 10) {
                                CoachMessageBubble(message: msg, accentColor: .neonGreen, assistantName: "FitMaks AI")
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, accentColor: .neonCyan).padding(.trailing, 20) }
                            }
                            .id(msg.id)
                        }
                        if isWaiting {
                            CoachTypingBubble(accentColor: .neonGreen)
                                .id("TypingIndicator")
                        }
                    }.padding()
                }
                .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }
                .onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                if let img = attachedImage { HStack { ZStack(alignment: .topTrailing) { Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonGreen, lineWidth: 2)); Button(action: { withAnimation { attachedImage = nil } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Circle().fill(Color.black)) }.offset(x: 8, y: -8) }; Spacer() }.padding(.horizontal).padding(.top, 10) }
                HStack(spacing: 10) {
                    Button(action: { isShowingAttachmentDialog = true }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 17, weight: .black))
                            .foregroundColor(.neonCyan)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.appSurface))
                    }

                    TextField("Ask AI or attach label...", text: $userMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(Capsule().fill(Color.appElevated))
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        .foregroundColor(.appText)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.appAccentText)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill((userMessage.isEmpty && attachedImage == nil) || isWaiting ? Color.gray.opacity(0.45) : Color.neonGreen))
                    }
                    .disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting)
                }
                .padding(14)
                .background(Color.appElevated)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.appBackgroundMid, Color.appBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(28)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.neonGreen.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.neonGreen.opacity(0.16), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 15)
        .frame(maxHeight: 680)
        .onAppear { originalIngredients = entry.ingredients; originalCalories = entry.calories; originalProtein = entry.protein; if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false, shouldTypewrite: true)) } }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
        .confirmationDialog("Save to My Food", isPresented: $isShowingSaveDialog) {
            Button("Fridge (Ingredient) ❄️") { saveAs(isMeal: false) }
            Button("Meals (Dish) 🍲") { saveAs(isMeal: true) }
        }
    }
    
    func saveAs(isMeal: Bool) {
        if isMeal { modelContext.insert(SavedRecipe(image: entry.uiImage, name: entry.name, instructions: "", calories: entry.calories, protein: entry.protein, ingredients: entry.ingredients)) }
        else { modelContext.insert(FavoriteFood(image: entry.uiImage, name: entry.name, calories: entry.calories, protein: entry.protein, ingredients: entry.ingredients)) }
    }
    
    func sendMessage() {
        let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: entry.name, emoji: nil, calories: entry.calories, protein: entry.protein, ingredients_breakdown: entry.ingredients, ai_response_text: "");
        GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text) { result, error in
            isWaiting = false;
            if let res = result {
                let prefix = entry.name.hasPrefix("👨‍🍳") ? "👨‍🍳 " : (entry.name.hasPrefix("❄️") ? "❄️ " : "")
                let cleanName = res.food_name.replacingOccurrences(of: "👨‍🍳 ", with: "").replacingOccurrences(of: "❄️ ", with: "")
                entry.name = prefix + cleanName; entry.calories = res.calories; entry.protein = res.protein; entry.ingredients = res.ingredients_breakdown;
                messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }
}
