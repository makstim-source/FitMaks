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
    
    var calculatedProtein: Double { return max(weight * (goal == "Build Muscle" ? 2.2 : 2.0), 180.0) }
    var calculatedCalories: Double { let bmr = (10.0 * weight) + (6.25 * height) - (5.0 * Double(age)) + (gender == "Male" ? 5.0 : -161.0); let multipliers: [String: Double] = ["Sedentary": 1.2, "Light": 1.375, "Moderate": 1.55, "Active": 1.725]; let tdee = bmr * (multipliers[activityLevel] ?? 1.2); if goal == "Lose Weight" { return tdee - 500 }; if goal == "Build Muscle" { return tdee + 500 }; return tdee }
    var baseCaloriesGoal: Double { useCustomGoals ? customCalories : calculatedCalories }
    var baseProteinGoal: Double { useCustomGoals ? customProtein : calculatedProtein }
    var calorieGoalBonus: Double { switch currentDayMode { case .chill: return 0; case .padel: return 500; case .gym: return 300 } }
    var proteinGoalBonus: Double { switch currentDayMode { case .chill: return 0; case .padel: return 15; case .gym: return 25 } }
    var targetProtein: Double { baseProteinGoal + proteinGoalBonus }
    var maxCalories: Double { baseCaloriesGoal + calorieGoalBonus }
    let targetSteps: Double = 10000.0
    
    var dailyFoodEntries: [FoodEntry] { allFoodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyTrainingEntries: [TrainingEntry] { allTrainingEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyFeed: [TimelineItem] { let foods = dailyFoodEntries.map { TimelineItem.food($0) }; let trainings = dailyTrainingEntries.map { TimelineItem.training($0) }; return (foods + trainings).sorted { $0.date < $1.date } }
    var dailyProtein: Double { dailyFoodEntries.reduce(0) { $0 + $1.protein } }
    var dailyCaloriesConsumed: Double { dailyFoodEntries.reduce(0) { $0 + $1.calories } }
    var dailyCaloriesRemaining: Double { maxCalories - dailyCaloriesConsumed }
    var isPerfectPastDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
        && selectedDate < Date()
        && dailyProtein >= targetProtein
        && dailySteps >= targetSteps
        && dailyCaloriesConsumed <= maxCalories
    }

    var body: some View {
        ZStack {
            Color.darkGrey.edgesIgnoringSafeArea(.all)
            VStack(spacing: 15) {
                HStack {
                    Button(action: { isShowingStats = true }) { Image(systemName: "chart.bar.xaxis").font(.title3).foregroundColor(.neonGreen).padding(12).background(Circle().fill(Color.gray.opacity(0.15))) }
                    Spacer()
                    VStack(spacing: 5) {
                        Text("FitMaks").font(.footnote).fontWeight(.bold).foregroundColor(.gray)
                        HStack(spacing: 15) {
                            Button(action: { changeDate(by: -1) }) { Image(systemName: "chevron.left").foregroundColor(.neonGreen).font(.title3.bold()) }
                            Text(formatDate(selectedDate)).font(.headline).bold().foregroundColor(.neonGreen).padding(.horizontal, 12).padding(.vertical, 6).background(Color.gray.opacity(0.15)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)).onTapGesture { isShowingCalendar = true }
                            Button(action: { changeDate(by: 1) }) { Image(systemName: "chevron.right").foregroundColor(.neonGreen).font(.title3.bold()) }.opacity(Calendar.current.isDateInToday(selectedDate) ? 0 : 1).disabled(Calendar.current.isDateInToday(selectedDate))
                        }
                    }
                    Spacer()
                    Button(action: { isShowingAIAssistant = true }) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.neonCyan)
                            .padding(12)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                }.padding(.top, 10).padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        let isOverCal = dailyCaloriesConsumed > maxCalories; let calColor = isOverCal ? Color.red : Color.neonGreen; let calValue = isOverCal ? (dailyCaloriesConsumed - maxCalories) : dailyCaloriesRemaining; let calFill = isOverCal ? maxCalories : dailyCaloriesRemaining
                        let proteinColor = Color.neonCyan
                        statCircle(title: "CALORIES", displayValue: calValue, fillValue: calFill, total: maxCalories, color: calColor, label: isOverCal ? "OVER" : "left")
                            .contentShape(Rectangle())
                            .onTapGesture { isShowingGoalBreakdown = true }
                        statCircle(title: "PROTEIN", displayValue: dailyProtein, fillValue: dailyProtein, total: targetProtein, color: proteinColor, label: "of \(Int(targetProtein))g")
                            .contentShape(Rectangle())
                            .onTapGesture { isShowingGoalBreakdown = true }
                        statCircle(title: "STEPS", displayValue: dailySteps, fillValue: dailySteps, total: targetSteps, color: getStepsColor(steps: dailySteps, target: targetSteps), label: "of \(Int(targetSteps/1000))k")
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(statsPanelBackground)
                    .overlay(statsPanelCelebrationOverlay)
                    .shadow(color: isPerfectPastDay ? Color.neonGreen.opacity(0.45) : .clear, radius: 18, x: 0, y: 0)
                    .padding(.horizontal, 15)
                    HStack(spacing: 10) { ForEach(DayMode.allCases, id: \.self) { mode in Button(action: { withAnimation(.spring()) { setDayMode(mode) } }) { Text(mode.rawValue).font(.caption).bold().frame(maxWidth: .infinity).padding(.vertical, 10).background(currentDayMode == mode ? Color.neonCyan.opacity(0.2) : Color.black.opacity(0.3)).foregroundColor(currentDayMode == mode ? .neonCyan : .gray).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(currentDayMode == mode ? Color.neonCyan.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)) } } }.padding(.horizontal, 15)
                }
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(processingItems) { item in loadingRow(item: item) }
                        if dailyFeed.isEmpty && processingItems.isEmpty {
                            Button(action: { isShowingSourceDialog = true }) {
                                VStack(spacing: 15) {
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 45))
                                        .foregroundColor(.gray.opacity(0.3))
                                    Text("Add your food\nor a workout screenshot here")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.gray)
                                        .lineSpacing(4)
                                }
                                .padding(.top, 60)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            ForEach(dailyFeed.reversed()) { item in
                                switch item {
                                case .food(let entry): foodRow(entry: entry).onTapGesture { withAnimation(.spring()) { selectedEntryForEdit = entry } }.swipeToDelete { withAnimation(.spring()) { modelContext.delete(entry) } }
                                case .training(let entry): trainingRow(entry: entry).swipeToDelete { withAnimation(.spring()) { modelContext.delete(entry) } }
                                }
                            }
                        }
                    }.padding(15)
                }.background(Color.black.opacity(0.2)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.neonGreen.opacity(0.8), lineWidth: 1.5).shadow(color: .neonGreen.opacity(0.7), radius: 12)).padding(.horizontal, 15).padding(.bottom, 5)

                ZStack {
                    HStack {
                        Button(action: { isSelectionModeForFridge = false; initialMyFoodTab = 0; isShowingMyFood = true }) { Image(systemName: "takeoutbag.and.cup.and.straw").font(.system(size: 22)).foregroundColor(.neonCyan).frame(width: 55, height: 55).background(Circle().fill(Color.black)).shadow(color: .neonCyan.opacity(0.5), radius: 8, x: 0, y: 0) }.padding(.leading, 30)
                        Spacer()
                        Button(action: { isShowingProfile = true }) { Image(systemName: "person.crop.circle").font(.system(size: 24)).foregroundColor(Color(red: 0.8, green: 0.2, blue: 1.0)).frame(width: 55, height: 55).background(Circle().fill(Color.black)).shadow(color: Color(red: 0.8, green: 0.2, blue: 1.0).opacity(0.5), radius: 8, x: 0, y: 0) }.padding(.trailing, 30)
                    }
                    Button(action: { isShowingSourceDialog = true }) { Image(systemName: "plus.circle.fill").font(.system(size: 70)).foregroundColor(.neonGreen).background(Circle().fill(Color.black)).shadow(color: .neonGreen.opacity(0.5), radius: 10, x: 0, y: 0) }
                }.padding(.bottom, 20)
            }.blur(radius: selectedEntryForEdit != nil ? 15 : 0)
            
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
        .sheet(isPresented: $isShowingStats) { StatsView(allFoodEntries: allFoodEntries, allSetups: allDailySetups, baseCalories: useCustomGoals ? customCalories : calculatedCalories, baseProtein: targetProtein) }
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

    func foodRow(entry: FoodEntry) -> some View {
        return HStack(spacing: 15) {
            if let img = entry.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }
            VStack(alignment: .leading) {
                HStack(spacing: 6) { Text(entry.name).font(.subheadline).bold().foregroundColor(.white) }
                Text("-\(Int(entry.calories)) kcal • +\(Int(entry.protein))g protein").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "info.circle").foregroundColor(.gray).font(.subheadline)
        }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15))).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
    
    func trainingRow(entry: TrainingEntry) -> some View { HStack(spacing: 15) { if let img = entry.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }; VStack(alignment: .leading) { Text(entry.name).font(.subheadline).bold().foregroundColor(.white); Text("\(Int(entry.caloriesBurned)) kcal burned • \(entry.duration)").font(.caption).foregroundColor(.gray) }; Spacer(); Image(systemName: "flame.fill").foregroundColor(.blue).font(.subheadline) }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.blue.opacity(0.1))).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.blue.opacity(0.5), lineWidth: 1)) }
    func loadingRow(item: ProcessingItem) -> some View { HStack(spacing: 15) { if let firstImg = item.images.first { Image(uiImage: firstImg).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(Color.black.opacity(0.2).cornerRadius(10)) }; VStack(alignment: .leading, spacing: 6) { Text(item.textPrompt != nil ? "Reading text..." : "AI is analyzing...").font(.subheadline).bold().foregroundColor(.white); RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 120, height: 10) }; Spacer(); ProgressView().tint(item.isTraining ? .blue : .neonGreen) }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(item.isTraining ? Color.blue.opacity(0.5) : Color.neonGreen.opacity(0.5), lineWidth: 1)).shadow(color: item.isTraining ? .blue.opacity(0.2) : .neonGreen.opacity(0.2), radius: 5)) }

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
                            Color.black.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
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
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.neonGreen))
                .shadow(color: .neonGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                .offset(x: -12, y: -10)
            }
        }
    }
    
    func statCircle(title: String, displayValue: Double, fillValue: Double, total: Double, color: Color, label: String) -> some View { VStack(spacing: 12) { Text(title).font(.caption2).bold().foregroundColor(.gray); ZStack { Circle().stroke(lineWidth: 7).foregroundColor(Color.black.opacity(0.3)); let isCompleted = fillValue >= total; let glowRadius: CGFloat = isCompleted ? 15 : 4; let glowOpacity: Double = isCompleted ? 0.9 : 0.4; Circle().trim(from: 0, to: CGFloat(min(fillValue/total, 1.0))).stroke(style: StrokeStyle(lineWidth: 7, lineCap: .round)).foregroundColor(color).rotationEffect(.degrees(-90)).shadow(color: color.opacity(glowOpacity), radius: glowRadius, x: 0, y: 0); VStack(spacing: 0) { Text("\(Int(displayValue))").font(.headline).bold().foregroundColor(.white); Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.gray) } }.frame(width: 75, height: 75) }.frame(maxWidth: .infinity) }
    func getStepsColor(steps: Double, target: Double) -> Color { let percent = min(max(steps / target, 0.0), 1.0); return Color(red: 1.0 - (0.5 * percent), green: 0.1, blue: percent) }
    func changeDate(by days: Int) { if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate), newDate <= Date() { selectedDate = newDate } }
    func formatDate(_ date: Date) -> String { Calendar.current.isDateInToday(date) ? "Today" : { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: date) }() }
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
                        Color(red: 10/255, green: 15/255, blue: 19/255),
                        Color.darkGrey,
                        Color.black.opacity(0.92)
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
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.foregroundColor(.gray) } }
            .onAppear { if messages.isEmpty { fetchSummary(isInitial: true, message: "", image: nil) } }
            .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
            .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
        }.preferredColorScheme(.dark)
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
                    .foregroundColor(.gray)
            }

            Text(coachHeadline)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)

            VStack(spacing: 10) {
                miniGoal(
                    title: "Calories",
                    value: consumedCalories,
                    target: targetCalories,
                    color: consumedCalories > targetCalories ? .red : .neonGreen,
                    detail: consumedCalories > targetCalories ? "\(Int(consumedCalories - targetCalories)) over" : "\(Int(max(targetCalories - consumedCalories, 0))) left"
                )

                miniGoal(
                    title: "Protein",
                    value: consumedProtein,
                    target: targetProtein,
                    color: .neonCyan,
                    detail: consumedProtein >= targetProtein ? "closed" : "\(Int(max(targetProtein - consumedProtein, 0)))g missing"
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
                            Color.black.opacity(0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.neonCyan.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var coachHeadline: String {
        if Calendar.current.isDateInToday(selectedDate) {
            if consumedProtein >= targetProtein && consumedCalories <= targetCalories && consumedCalories > 0 {
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
                    .foregroundColor(.gray)

                Spacer()

                Text(detail)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

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
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }

                TextField("Ask for a meal move, plan, or review...", text: $userMessage)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Capsule().fill(Color.black.opacity(0.36)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .foregroundColor(.white)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.black)
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
                .fill(Color(red: 12/255, green: 14/255, blue: 18/255).opacity(0.96))
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
                Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.neonGreen) }
                Spacer(); Text("Analysis").font(.headline).foregroundColor(.white); Spacer()
                HStack(spacing: 20) {
                    Button(action: { isShowingSaveDialog = true }) { Image(systemName: "square.and.arrow.down").foregroundColor(.neonCyan).font(.title3) }
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)).font(.title3) }
                }
            }.padding().background(Color.darkGrey)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, accentColor: .gray)
                        ForEach(messages) { msg in
                            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 10) {
                                HStack { if msg.isUser { Spacer() }; VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 8) { if let img = msg.attachedImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 10)) }; if !msg.text.isEmpty { Text(msg.text) } }.font(.subheadline).padding(12).background(msg.isUser ? Color.neonGreen.opacity(0.2) : Color.gray.opacity(0.2)).foregroundColor(.white).cornerRadius(15); if !msg.isUser { Spacer() } }
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, accentColor: .neonCyan).padding(.trailing, 20) }
                            }.id(msg.id)
                        }
                        if isWaiting { HStack { TypingIndicatorView(color: .neonGreen).padding(14).background(Color.gray.opacity(0.2)).cornerRadius(15); Spacer() }.id("TypingIndicator") }
                    }.padding()
                }.onChange(of: messages.count) { withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                if let img = attachedImage { HStack { ZStack(alignment: .topTrailing) { Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonGreen, lineWidth: 2)); Button(action: { withAnimation { attachedImage = nil } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Circle().fill(Color.black)) }.offset(x: 8, y: -8) }; Spacer() }.padding(.horizontal).padding(.top, 10) }
                HStack(spacing: 12) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.title3).foregroundColor(.neonCyan) }; TextField("Ask AI or attach label...", text: $userMessage).padding(10).background(Color.black.opacity(0.4)).cornerRadius(20).foregroundColor(.white); Button(action: sendMessage) { Image(systemName: "paperplane.fill").foregroundColor((userMessage.isEmpty && attachedImage == nil) || isWaiting ? .gray : .neonGreen) }.disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting) }.padding().background(Color(red: 20/255, green: 20/255, blue: 25/255))
            }
        }.background(Color.darkGrey).cornerRadius(25).overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.2), lineWidth: 1)).padding(.horizontal, 15).frame(maxHeight: 680)
        .onAppear { originalIngredients = entry.ingredients; originalCalories = entry.calories; originalProtein = entry.protein; if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false)) } }
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
                messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein))
            } else {
                messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false))
            }
        }
    }
}
