import SwiftUI
import SwiftData
import PhotosUI
import HealthKit

// MARK: - ВСПОМОГАТЕЛЬНЫЕ МОДЕЛИ

struct ProcessingItem: Identifiable {
    let id = UUID()
    let images: [UIImage]
    var textPrompt: String? = nil
    var isTraining: Bool = false
}

enum EntryMode {
    case food
    case training
}

enum TimelineItem: Identifiable {
    case food(FoodEntry)
    case training(TrainingEntry)
    
    var id: UUID {
        switch self {
        case .food(let f): return f.id
        case .training(let t): return t.id
        }
    }
    var date: Date {
        switch self {
        case .food(let f): return f.date
        case .training(let t): return t.date
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var ingredients: String? = nil
    var calories: Double? = nil
    var protein: Double? = nil
    var attachedImage: UIImage? = nil
}

@Model
class FavoriteFood {
    var id: UUID = UUID()
    var name: String
    var calories: Double
    var protein: Double
    var ingredients: String
    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        if let data = imageData { return UIImage(data: data) }
        return nil
    }
    init(image: UIImage?, name: String, calories: Double, protein: Double, ingredients: String) {
        self.name = name; self.calories = calories; self.protein = protein; self.ingredients = ingredients
        self.imageData = image?.jpegData(compressionQuality: 0.8)
    }
}

@Model
class TrainingEntry {
    var id: UUID = UUID()
    var name: String
    var caloriesBurned: Double
    var duration: String
    var date: Date
    @Attribute(.externalStorage) var imageData: Data?

    var uiImage: UIImage? {
        if let data = imageData { return UIImage(data: data) }
        return nil
    }

    init(image: UIImage?, name: String, caloriesBurned: Double, duration: String, date: Date) {
        self.name = name
        self.caloriesBurned = caloriesBurned
        self.duration = duration
        self.date = date
        self.imageData = image?.jpegData(compressionQuality: 0.8)
    }
}

@Model
class DailySetup {
    @Attribute(.unique) var dateID: String
    var mode: String
    init(date: Date, mode: DayMode) {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        self.dateID = f.string(from: date)
        self.mode = mode.rawValue
    }
}

enum DayMode: String, CaseIterable {
    case chill = "Chill 🛋️"
    case padel = "Padel 🎾"
    case gym = "Gym 🏋️‍♂️"
}

struct TypingIndicatorView: View {
    var color: Color
    @State private var isAnimating = false
    var body: some View {
        HStack(spacing: 6) {
            Circle().frame(width: 8, height: 8).offset(y: isAnimating ? -3 : 3).animation(.easeInOut(duration: 0.4).repeatForever().delay(0.0), value: isAnimating)
            Circle().frame(width: 8, height: 8).offset(y: isAnimating ? -3 : 3).animation(.easeInOut(duration: 0.4).repeatForever().delay(0.2), value: isAnimating)
            Circle().frame(width: 8, height: 8).offset(y: isAnimating ? -3 : 3).animation(.easeInOut(duration: 0.4).repeatForever().delay(0.4), value: isAnimating)
        }.foregroundColor(color).frame(height: 20).onAppear { isAnimating = true }
    }
}


// MARK: - 🔥 ГЛАВНЫЙ ЭКРАН (CONTENT VIEW) 🔥

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .forward) var allFoodEntries: [FoodEntry]
    @Query(sort: \TrainingEntry.date, order: .forward) var allTrainingEntries: [TrainingEntry]
    @Query var favorites: [FavoriteFood]
    @Query var allDailySetups: [DailySetup]
    
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
    
    var currentDayMode: DayMode {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let id = f.string(from: selectedDate)
        if let setup = allDailySetups.first(where: { $0.dateID == id }), let mode = DayMode(rawValue: setup.mode) { return mode }
        return .chill
    }

    func setDayMode(_ mode: DayMode) {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let id = f.string(from: selectedDate)
        if let existing = allDailySetups.first(where: { $0.dateID == id }) {
            existing.mode = mode.rawValue
        } else {
            modelContext.insert(DailySetup(date: selectedDate, mode: mode))
        }
    }
    
    var calculatedProtein: Double {
        let multiplier = goal == "Build Muscle" ? 2.2 : 2.0
        return max(weight * multiplier, 180.0)
    }
    
    var calculatedCalories: Double {
        let bmr = (10.0 * weight) + (6.25 * height) - (5.0 * Double(age)) + (gender == "Male" ? 5.0 : -161.0)
        let multipliers: [String: Double] = ["Sedentary": 1.2, "Light": 1.375, "Moderate": 1.55, "Active": 1.725]
        let tdee = bmr * (multipliers[activityLevel] ?? 1.2)
        if goal == "Lose Weight" { return tdee - 500 }
        if goal == "Build Muscle" { return tdee + 500 }
        return tdee
    }
    
    var targetProtein: Double {
        let base = useCustomGoals ? customProtein : calculatedProtein
        switch currentDayMode {
        case .chill: return base
        case .padel: return base + 15
        case .gym: return base + 25
        }
    }
    
    var maxCalories: Double {
        let base = useCustomGoals ? customCalories : calculatedCalories
        switch currentDayMode {
        case .chill: return base
        case .padel: return base + 500
        case .gym: return base + 300
        }
    }
    
    let targetSteps: Double = 10000.0
    
    @State private var selectedDate = Date()
    @State private var isShowingSourceDialog = false
    @State private var isShowingCamera = false
    @State private var selectedCameraImage: UIImage?
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingTextEntry = false
    @State private var manualText = ""
    @State private var processingItems: [ProcessingItem] = []
    @State private var fridgeProcessingItems: [ProcessingItem] = []
    @State private var selectedEntryForEdit: FoodEntry?
    @State private var isShowingCalendar = false
    @State private var dailySteps: Double = 0
    @State private var isShowingFridge = false
    @State private var isSelectionModeForFridge = false
    @State private var isShowingProfile = false

    var dailyFoodEntries: [FoodEntry] { allFoodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    var dailyTrainingEntries: [TrainingEntry] { allTrainingEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    
    var dailyFeed: [TimelineItem] {
        let foods = dailyFoodEntries.map { TimelineItem.food($0) }
        let trainings = dailyTrainingEntries.map { TimelineItem.training($0) }
        return (foods + trainings).sorted { $0.date < $1.date }
    }
    
    var dailyProtein: Double { dailyFoodEntries.reduce(0) { $0 + $1.protein } }
    var dailyCaloriesConsumed: Double { dailyFoodEntries.reduce(0) { $0 + $1.calories } }
    var dailyCaloriesRemaining: Double { maxCalories - dailyCaloriesConsumed }

    var body: some View {
        ZStack {
            Color.darkGrey.edgesIgnoringSafeArea(.all)
            VStack(spacing: 15) {
                ZStack(alignment: .top) {
                    HStack {
                        Button(action: { isShowingCalendar = true }) { Image(systemName: "calendar").font(.title3).foregroundColor(.neonGreen).padding(12).background(Circle().fill(Color.gray.opacity(0.15))).overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)) }
                        Spacer()
                    }
                    VStack(spacing: 5) {
                        Text("FitMaks").font(.headline).fontWeight(.bold).foregroundColor(.white)
                        HStack(spacing: 20) {
                            Button(action: { changeDate(by: -1) }) { Image(systemName: "chevron.left").foregroundColor(.neonGreen).font(.title3.bold()) }
                            Text(formatDate(selectedDate)).font(.headline).foregroundColor(.white).frame(width: 160)
                            Button(action: { changeDate(by: 1) }) { Image(systemName: "chevron.right").foregroundColor(.neonGreen).font(.title3.bold()) }.disabled(Calendar.current.isDateInToday(selectedDate))
                        }
                    }
                }.padding(.top, 20).padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        let isOverCal = dailyCaloriesConsumed > maxCalories
                        let calColor = isOverCal ? Color.red : Color.neonGreen
                        let calValue = isOverCal ? (dailyCaloriesConsumed - maxCalories) : dailyCaloriesRemaining
                        let calFill = isOverCal ? maxCalories : dailyCaloriesRemaining
                        statCircle(title: "CALORIES", displayValue: calValue, fillValue: calFill, total: maxCalories, color: calColor, label: isOverCal ? "OVER" : "left")
                        statCircle(title: "PROTEIN", displayValue: dailyProtein, fillValue: dailyProtein, total: targetProtein, color: .neonCyan, label: "of \(Int(targetProtein))g")
                        statCircle(title: "STEPS", displayValue: dailySteps, fillValue: dailySteps, total: targetSteps, color: getStepsColor(steps: dailySteps, target: targetSteps), label: "of \(Int(targetSteps/1000))k")
                    }
                    .padding(.vertical, 12).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.15))).padding(.horizontal, 15)
                    
                    HStack(spacing: 10) {
                        ForEach(DayMode.allCases, id: \.self) { mode in
                            Button(action: { withAnimation(.spring()) { setDayMode(mode) } }) {
                                Text(mode.rawValue).font(.caption).bold().frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(currentDayMode == mode ? Color.neonCyan.opacity(0.2) : Color.black.opacity(0.3))
                                    .foregroundColor(currentDayMode == mode ? .neonCyan : .gray)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(currentDayMode == mode ? Color.neonCyan.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }.padding(.horizontal, 15)
                }
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(processingItems) { item in loadingRow(item: item) }
                        
                        if dailyFeed.isEmpty && processingItems.isEmpty {
                            Text("No records").foregroundColor(.gray).padding(.top, 40)
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
                    }.padding(15)
                }.background(Color.black.opacity(0.2)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.neonGreen.opacity(0.8), lineWidth: 1.5).shadow(color: .neonGreen.opacity(0.7), radius: 12)).padding(.horizontal, 15).padding(.bottom, 5)

                ZStack {
                    HStack {
                        Button(action: { isSelectionModeForFridge = false; isShowingFridge = true }) { Image(systemName: "refrigerator").font(.system(size: 22)).foregroundColor(.neonCyan).frame(width: 55, height: 55).background(Circle().fill(Color.black)).shadow(color: .neonCyan.opacity(0.5), radius: 8, x: 0, y: 0) }.padding(.leading, 30)
                        Spacer()
                        Button(action: { isShowingProfile = true }) { Image(systemName: "person.crop.circle").font(.system(size: 24)).foregroundColor(Color(red: 0.8, green: 0.2, blue: 1.0)).frame(width: 55, height: 55).background(Circle().fill(Color.black)).shadow(color: Color(red: 0.8, green: 0.2, blue: 1.0).opacity(0.5), radius: 8, x: 0, y: 0) }.padding(.trailing, 30)
                    }
                    Button(action: { isShowingSourceDialog = true }) { Image(systemName: "plus.circle.fill").font(.system(size: 70)).foregroundColor(.neonGreen).background(Circle().fill(Color.black)).shadow(color: .neonGreen.opacity(0.5), radius: 10, x: 0, y: 0) }
                }.padding(.bottom, 20)
            }.blur(radius: selectedEntryForEdit != nil ? 15 : 0)
            
            if let entry = selectedEntryForEdit { Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedEntryForEdit = nil } }; AIChatEditView(entry: entry, onDelete: { modelContext.delete(entry); withAnimation { selectedEntryForEdit = nil } }, onDone: { withAnimation { selectedEntryForEdit = nil } }).transition(.scale(scale: 0.9).combined(with: .opacity)) }
        }
        .onAppear { HealthKitManager.shared.fetchSteps(for: selectedDate) { steps in DispatchQueue.main.async { self.dailySteps = steps } } }
        .onChange(of: selectedDate) { _, newDate in
            HealthKitManager.shared.fetchSteps(for: newDate) { steps in DispatchQueue.main.async { self.dailySteps = steps } }
        }
        .confirmationDialog("Add Entry", isPresented: $isShowingSourceDialog) {
            Button("Food from Fridge ❄️") { self.isSelectionModeForFridge = true; self.isShowingFridge = true }
            Button("Food from Camera 📷") { pickingMode = .food; self.isShowingCamera = true }
            Button("Food from Library 🖼️") { pickingMode = .food; self.isShowingPhotoPicker = true }
            Button("Type Food Text ✍️") { self.isShowingTextEntry = true }
            Button("Add Training (Whoop) 🏋️‍♂️") { pickingMode = .training; self.isShowingPhotoPicker = true }
        }
        .alert("What did you eat?", isPresented: $isShowingTextEntry) {
            TextField("E.g. 200g chicken and rice", text: $manualText)
            Button("Analyze") { guard !manualText.isEmpty else { return }; let textImg = generatePlaceholderIcon(systemName: "brain", color: .neonGreen); let item = ProcessingItem(images: [textImg], textPrompt: manualText, isTraining: false); withAnimation { processingItems.append(item) }; processQueue(items: [item]); manualText = "" }
            Button("Cancel", role: .cancel) { manualText = "" }
        }
        .fullScreenCover(isPresented: $isShowingCamera) { ImagePicker(selectedImage: $selectedCameraImage, sourceType: .camera) }
        .onChange(of: selectedCameraImage) { _, newValue in
            if let img = newValue {
                let item = ProcessingItem(images: [img], isTraining: pickingMode == .training)
                processingItems.append(item)
                if pickingMode == .training { processTrainingQueue(items: [item]) } else { processQueue(items: [item]) }
                selectedCameraImage = nil
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var loadedImages: [UIImage] = []
                for item in newItems { if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { loadedImages.append(img) } }
                await MainActor.run {
                    selectedPhotoItems.removeAll()
                    if !loadedImages.isEmpty {
                        let newItem = ProcessingItem(images: loadedImages, isTraining: pickingMode == .training)
                        withAnimation { processingItems.append(newItem) }
                        if pickingMode == .training { processTrainingQueue(items: [newItem]) } else { processQueue(items: [newItem]) }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCalendar) { CustomCalendarView(selectedDate: $selectedDate, allEntries: allFoodEntries, maxCalories: maxCalories, targetProtein: targetProtein).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $isShowingFridge) { FridgeView(isSelectionMode: isSelectionModeForFridge, selectedDate: selectedDate, processingItems: $fridgeProcessingItems, onProcessQueue: processFridgeQueue) }
        .sheet(isPresented: $isShowingProfile) { ProfileView(gender: $gender, age: $age, weight: $weight, height: $height, goal: $goal, activityLevel: $activityLevel, useCustomGoals: $useCustomGoals, customCalories: $customCalories, customProtein: $customProtein, calculatedCalories: calculatedCalories, calculatedProtein: calculatedProtein) }
    }

    // MARK: - Рендер и логика Дневника
    
    func generatePlaceholderIcon(systemName: String, color: Color) -> UIImage { let size = CGSize(width: 150, height: 150); let renderer = UIGraphicsImageRenderer(size: size); return renderer.image { _ in UIColor(white: 0.15, alpha: 1.0).setFill(); UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill(); if let icon = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 60, weight: .bold))?.withTintColor(UIColor(color), renderingMode: .alwaysOriginal) { icon.draw(at: CGPoint(x: (size.width - icon.size.width) / 2, y: (size.height - icon.size.height) / 2)) } } }
    func generateEmojiIcon(emoji: String) -> UIImage { let size = CGSize(width: 150, height: 150); let renderer = UIGraphicsImageRenderer(size: size); return renderer.image { _ in UIColor(white: 0.15, alpha: 1.0).setFill(); UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 25).fill(); let safeEmoji = emoji.isEmpty ? "🍽️" : emoji; let nsString = safeEmoji as NSString; let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 75)]; let stringSize = nsString.size(withAttributes: attributes); nsString.draw(at: CGPoint(x: (size.width - stringSize.width) / 2, y: (size.height - stringSize.height) / 2), withAttributes: attributes) } }

    func foodRow(entry: FoodEntry) -> some View {
        let isFromFridge = favorites.contains(where: { $0.name == entry.name })
        return HStack(spacing: 15) {
            if let img = entry.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }
            VStack(alignment: .leading) {
                HStack(spacing: 6) { Text(entry.name).font(.subheadline).bold().foregroundColor(.white); if isFromFridge { Image(systemName: "snowflake").font(.system(size: 10, weight: .bold)).foregroundColor(.neonCyan) } }
                Text("-\(Int(entry.calories)) kcal • +\(Int(entry.protein))g protein").font(.caption).foregroundColor(.gray)
            }
            Spacer(); Image(systemName: "info.circle").foregroundColor(.gray).font(.subheadline)
        }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.3), lineWidth: 1)))
    }
    
    func trainingRow(entry: TrainingEntry) -> some View {
        HStack(spacing: 15) {
            if let img = entry.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }
            VStack(alignment: .leading) {
                Text(entry.name).font(.subheadline).bold().foregroundColor(.white)
                Text("\(Int(entry.caloriesBurned)) kcal burned • \(entry.duration)").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "flame.fill").foregroundColor(.blue).font(.subheadline)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.blue.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.blue.opacity(0.5), lineWidth: 1))
    }
    
    func loadingRow(item: ProcessingItem) -> some View { HStack(spacing: 15) { if let firstImg = item.images.first { Image(uiImage: firstImg).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(Color.black.opacity(0.2).cornerRadius(10)) }; VStack(alignment: .leading, spacing: 6) { Text(item.textPrompt != nil ? "Reading text..." : "AI is analyzing...").font(.subheadline).bold().foregroundColor(.white); RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 120, height: 10) }; Spacer(); ProgressView().tint(item.isTraining ? .blue : .neonGreen) }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(item.isTraining ? Color.blue.opacity(0.5) : Color.neonGreen.opacity(0.5), lineWidth: 1)).shadow(color: item.isTraining ? .blue.opacity(0.2) : .neonGreen.opacity(0.2), radius: 5)) }

    func processQueue(items: [ProcessingItem]) { Task { await withTaskGroup(of: (UUID, FoodResult?).self) { group in for item in items { group.addTask { if let text = item.textPrompt { return (item.id, await analyzeTextAsync(text: text)) } else { return (item.id, await analyzeImagesAsync(images: item.images)) } } }; for await (id, result) in group { await MainActor.run { if let index = processingItems.firstIndex(where: { $0.id == id }) { let item = processingItems[index]; let originalImage = item.images.first ?? UIImage(); withAnimation(.easeInOut) { processingItems.remove(at: index) }; if let res = result { let finalImage = item.textPrompt != nil ? generateEmojiIcon(emoji: res.emoji ?? "🍽️") : originalImage; let entry = FoodEntry(image: finalImage, name: res.food_name, calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown, date: selectedDate); withAnimation(.spring()) { modelContext.insert(entry) } } } } } } } }
    
    func processTrainingQueue(items: [ProcessingItem]) {
        Task {
            await withTaskGroup(of: (UUID, TrainingResult?).self) { group in
                for item in items {
                    group.addTask { return (item.id, await analyzeTrainingImagesAsync(images: item.images)) }
                }
                for await (id, result) in group {
                    await MainActor.run {
                        if let index = processingItems.firstIndex(where: { $0.id == id }) {
                            let processedImage = processingItems[index].images.first ?? UIImage()
                            withAnimation(.easeInOut) { processingItems.remove(at: index) }
                            if let res = result {
                                let entry = TrainingEntry(image: processedImage, name: res.activity_name, caloriesBurned: res.calories_burned, duration: res.duration, date: selectedDate)
                                withAnimation(.spring()) { modelContext.insert(entry) }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func processFridgeQueue(items: [ProcessingItem]) { Task { await withTaskGroup(of: (UUID, FoodResult?).self) { group in for item in items { group.addTask { if let text = item.textPrompt { return (item.id, await analyzeTextAsync(text: text)) } else { return (item.id, await analyzeImagesAsync(images: item.images)) } } }; for await (id, result) in group { await MainActor.run { if let index = fridgeProcessingItems.firstIndex(where: { $0.id == id }) { let item = fridgeProcessingItems[index]; let originalImage = item.images.first ?? UIImage(); withAnimation(.easeInOut) { fridgeProcessingItems.remove(at: index) }; if let res = result { let finalImage = item.textPrompt != nil ? generateEmojiIcon(emoji: res.emoji ?? "🍽️") : originalImage; let newFav = FavoriteFood(image: finalImage, name: res.food_name, calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown); withAnimation(.spring()) { modelContext.insert(newFav) } } } } } } } }
    
    func analyzeImagesAsync(images: [UIImage]) async -> FoodResult? { await withCheckedContinuation { continuation in GeminiService.shared.analyzeImages(images: images) { result, _ in continuation.resume(returning: result) } } }
    func analyzeTextAsync(text: String) async -> FoodResult? { await withCheckedContinuation { continuation in GeminiService.shared.analyzeText(text: text) { result, _ in continuation.resume(returning: result) } } }
    func analyzeTrainingImagesAsync(images: [UIImage]) async -> TrainingResult? { await withCheckedContinuation { continuation in GeminiService.shared.analyzeTrainingImages(images: images) { result, _ in continuation.resume(returning: result) } } }
    
    func statCircle(title: String, displayValue: Double, fillValue: Double, total: Double, color: Color, label: String) -> some View { VStack(spacing: 12) { Text(title).font(.caption2).bold().foregroundColor(.gray); ZStack { Circle().stroke(lineWidth: 7).foregroundColor(Color.black.opacity(0.3)); let isCompleted = fillValue >= total; let glowRadius: CGFloat = isCompleted ? 15 : 4; let glowOpacity: Double = isCompleted ? 0.9 : 0.4; Circle().trim(from: 0, to: CGFloat(min(fillValue/total, 1.0))).stroke(style: StrokeStyle(lineWidth: 7, lineCap: .round)).foregroundColor(color).rotationEffect(.degrees(-90)).shadow(color: color.opacity(glowOpacity), radius: glowRadius, x: 0, y: 0); VStack(spacing: 0) { Text("\(Int(displayValue))").font(.headline).bold().foregroundColor(.white); Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.gray) } }.frame(width: 75, height: 75) }.frame(maxWidth: .infinity) }
    func getStepsColor(steps: Double, target: Double) -> Color { let percent = min(max(steps / target, 0.0), 1.0); return Color(red: 1.0 - (0.5 * percent), green: 0.1, blue: percent) }
    func changeDate(by days: Int) { if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate), newDate <= Date() { selectedDate = newDate } }
    func formatDate(_ date: Date) -> String { Calendar.current.isDateInToday(date) ? "Today" : { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: date) }() }
}

// MARK: - 🔥 ЭКРАН ПРОФИЛЯ С ТЕКСТОВЫМ ВВОДОМ 🔥
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var gender: String; @Binding var age: Int; @Binding var weight: Double; @Binding var height: Double; @Binding var goal: String; @Binding var activityLevel: String
    @Binding var useCustomGoals: Bool; @Binding var customCalories: Double; @Binding var customProtein: Double
    var calculatedCalories: Double; var calculatedProtein: Double
    let neonPurple = Color(red: 0.8, green: 0.2, blue: 1.0)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack(spacing: 25) {
                        Toggle("Set Custom Goals", isOn: $useCustomGoals).tint(neonPurple).foregroundColor(.white).font(.headline).bold().padding(.horizontal, 20).onChange(of: useCustomGoals) { _, newValue in if newValue { if customCalories == 0 { customCalories = calculatedCalories }; if customProtein == 0 { customProtein = calculatedProtein } } }
                        HStack(spacing: 20) {
                            VStack(spacing: 5) { Text("DAILY CALORIES").font(.caption).bold().foregroundColor(.gray); if useCustomGoals { TextField("Kcal", value: $customCalories, format: .number).keyboardType(.numberPad).font(.title).bold().foregroundColor(.white).multilineTextAlignment(.center).padding(5).background(Color.gray.opacity(0.3)).cornerRadius(8) } else { Text("\(Int(calculatedCalories))").font(.title).bold().foregroundColor(.white).shadow(color: .white.opacity(0.5), radius: 5) } }.frame(maxWidth: .infinity)
                            Divider().background(Color.gray).frame(height: 40)
                            VStack(spacing: 5) { Text("DAILY PROTEIN").font(.caption).bold().foregroundColor(.gray); if useCustomGoals { HStack(spacing: 0) { TextField("Prot", value: $customProtein, format: .number).keyboardType(.numberPad).font(.title).bold().foregroundColor(neonPurple).multilineTextAlignment(.trailing).padding(5).background(Color.gray.opacity(0.3)).cornerRadius(8); Text("g").font(.title).bold().foregroundColor(neonPurple).padding(.leading, 2) } } else { Text("\(Int(calculatedProtein))g").font(.title).bold().foregroundColor(neonPurple).shadow(color: neonPurple.opacity(0.6), radius: 5) } }.frame(maxWidth: .infinity)
                        }.padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.4))).overlay(RoundedRectangle(cornerRadius: 20).stroke(neonPurple.opacity(0.5), lineWidth: 1)).padding(.horizontal)
                        
                        VStack(spacing: 20) {
                            Picker("Goal", selection: $goal) { Text("Lose Weight").tag("Lose Weight"); Text("Maintain").tag("Maintain"); Text("Build Muscle").tag("Build Muscle") }.pickerStyle(SegmentedPickerStyle())
                            Picker("Gender", selection: $gender) { Text("Male").tag("Male"); Text("Female").tag("Female") }.pickerStyle(SegmentedPickerStyle())
                            Picker("Activity", selection: $activityLevel) { Text("Sedentary").tag("Sedentary"); Text("Light").tag("Light"); Text("Moderate").tag("Moderate"); Text("Active").tag("Active") }.pickerStyle(SegmentedPickerStyle())
                            Divider().background(Color.gray.opacity(0.3))
                            VStack(alignment: .leading) { HStack { Text("Age (years):").foregroundColor(.white).bold(); Spacer(); TextField("Age", value: $age, format: .number).keyboardType(.numberPad).foregroundColor(neonPurple).bold().multilineTextAlignment(.trailing).frame(width: 50).padding(5).background(Color.black.opacity(0.3)).cornerRadius(5) }; Slider(value: Binding(get: { Double(age) }, set: { age = Int($0) }), in: 10...100, step: 1).tint(neonPurple) }
                            VStack(alignment: .leading) { HStack { Text("Weight (kg):").foregroundColor(.white).bold(); Spacer(); TextField("Weight", value: $weight, format: .number).keyboardType(.decimalPad).foregroundColor(neonPurple).bold().multilineTextAlignment(.trailing).frame(width: 60).padding(5).background(Color.black.opacity(0.3)).cornerRadius(5) }; Slider(value: $weight, in: 40...150, step: 0.5).tint(neonPurple) }
                            VStack(alignment: .leading) { HStack { Text("Height (cm):").foregroundColor(.white).bold(); Spacer(); TextField("Height", value: $height, format: .number).keyboardType(.decimalPad).foregroundColor(neonPurple).bold().multilineTextAlignment(.trailing).frame(width: 60).padding(5).background(Color.black.opacity(0.3)).cornerRadius(5) }; Slider(value: $height, in: 140...220, step: 1).tint(neonPurple) }
                        }.padding(20).background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.15))).padding(.horizontal).opacity(useCustomGoals ? 0.6 : 1.0).animation(.easeInOut, value: useCustomGoals)
                    }.padding(.top, 20)
                }
            }.navigationTitle("Profile & Goals").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { dismiss() }.foregroundColor(neonPurple).bold() } }
        }.preferredColorScheme(.dark)
    }
}


// MARK: - 🔥 ЭКРАН ХОЛОДИЛЬНИКА 🔥

struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext; @Query var favorites: [FavoriteFood]; @Environment(\.dismiss) var dismiss
    var isSelectionMode: Bool; var selectedDate: Date; @Binding var processingItems: [ProcessingItem]; var onProcessQueue: ([ProcessingItem]) -> Void
    @State private var isShowingSourceDialog = false; @State private var isShowingCamera = false; @State private var selectedCameraImage: UIImage?; @State private var isShowingPhotoPicker = false; @State private var selectedPhotoItems: [PhotosPickerItem] = []; @State private var isShowingTextEntry = false; @State private var manualText = ""; @State private var selectedFavoriteForEdit: FavoriteFood?

    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.edgesIgnoringSafeArea(.all)
                if favorites.isEmpty && processingItems.isEmpty { VStack(spacing: 15) { Image(systemName: "snowflake").font(.system(size: 60)).foregroundColor(.neonCyan.opacity(0.4)); Text("Fridge is empty").font(.headline).foregroundColor(.white); Text(isSelectionMode ? "Add your frequent foods first." : "Tap + to stock your fridge.").font(.subheadline).foregroundColor(.gray) } }
                else { ScrollView { VStack(spacing: 12) { ForEach(processingItems) { item in loadingRow(item: item) }; ForEach(favorites.reversed()) { fav in favoriteRow(fav).onTapGesture { if isSelectionMode { let entry = FoodEntry(image: fav.uiImage ?? UIImage(), name: fav.name, calories: fav.calories, protein: fav.protein, ingredients: fav.ingredients, date: selectedDate); modelContext.insert(entry); dismiss() } else { withAnimation(.spring()) { selectedFavoriteForEdit = fav } } }.swipeToDelete { withAnimation(.spring()) { modelContext.delete(fav) } } } }.padding() }.blur(radius: selectedFavoriteForEdit != nil ? 15 : 0) }
                if let fav = selectedFavoriteForEdit { Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedFavoriteForEdit = nil } }; FavoriteChatEditView(favorite: fav, onDelete: { modelContext.delete(fav); withAnimation { selectedFavoriteForEdit = nil } }, onDone: { withAnimation { selectedFavoriteForEdit = nil } }).transition(.scale(scale: 0.9).combined(with: .opacity)) }
            }.navigationTitle(isSelectionMode ? "Pick from Fridge" : "My Fridge ❄️").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.neonCyan) }; if !isSelectionMode { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { isShowingSourceDialog = true }) { Image(systemName: "plus").foregroundColor(.neonCyan).font(.title3.bold()) } } } }
            .confirmationDialog("Add to Fridge", isPresented: $isShowingSourceDialog) { Button("Camera") { self.isShowingCamera = true }; Button("Library") { self.isShowingPhotoPicker = true }; Button("Type Text") { self.isShowingTextEntry = true } }
            .alert("Add Favorite Food", isPresented: $isShowingTextEntry) { TextField("E.g. 150g Greek Yogurt", text: $manualText); Button("Analyze") { guard !manualText.isEmpty else { return }; let textImg = ContentView().generatePlaceholderIcon(systemName: "brain", color: .neonCyan); let item = ProcessingItem(images: [textImg], textPrompt: manualText); withAnimation { processingItems.append(item) }; onProcessQueue([item]); manualText = "" }; Button("Cancel", role: .cancel) { manualText = "" } }
            .fullScreenCover(isPresented: $isShowingCamera) { ImagePicker(selectedImage: $selectedCameraImage, sourceType: .camera) }
            .onChange(of: selectedCameraImage) { _, newValue in if let img = newValue { let item = ProcessingItem(images: [img]); processingItems.append(item); onProcessQueue([item]); selectedCameraImage = nil } }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
            .onChange(of: selectedPhotoItems) { _, newItems in guard !newItems.isEmpty else { return }; Task { var loadedImages: [UIImage] = []; for item in newItems { if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { loadedImages.append(img) } }; await MainActor.run { selectedPhotoItems.removeAll(); if !loadedImages.isEmpty { let newItem = ProcessingItem(images: loadedImages); withAnimation { processingItems.append(newItem) }; onProcessQueue([newItem]) } } } }
        }.preferredColorScheme(.dark)
    }

    func favoriteRow(_ fav: FavoriteFood) -> some View { HStack(spacing: 15) { if let img = fav.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }; VStack(alignment: .leading) { Text(fav.name).font(.subheadline).bold().foregroundColor(.white); Text("\(Int(fav.calories)) kcal • \(Int(fav.protein))g protein").font(.caption).foregroundColor(.neonCyan) }; Spacer(); if isSelectionMode { Image(systemName: "plus.circle.fill").foregroundColor(.neonCyan).font(.title3) } else { Image(systemName: "pencil").foregroundColor(.gray).font(.subheadline) } }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.neonCyan.opacity(0.3), lineWidth: 1))) }
    func loadingRow(item: ProcessingItem) -> some View { HStack(spacing: 15) { if let firstImg = item.images.first { Image(uiImage: firstImg).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(Color.black.opacity(0.2).cornerRadius(10)) }; VStack(alignment: .leading, spacing: 6) { Text("Analyzing...").font(.subheadline).bold().foregroundColor(.white); RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 120, height: 10) }; Spacer(); ProgressView().tint(.neonCyan) }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.neonCyan.opacity(0.5), lineWidth: 1)).shadow(color: .neonCyan.opacity(0.2), radius: 5)) }
}

// MARK: - ЧАТЫ (Дневник и Холодильник)

struct AIChatEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: FoodEntry
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0
    @State private var attachedImage: UIImage? = nil; @State private var isShowingAttachmentDialog = false; @State private var isShowingAttachmentPicker = false; @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    @State private var savedToFridge = false

    var onDelete: () -> Void; var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.neonGreen) }
                Spacer()
                Text("Analysis").font(.headline).foregroundColor(.white)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: saveToFridge) { Image(systemName: savedToFridge ? "checkmark.circle.fill" : "snowflake").foregroundColor(savedToFridge ? .neonCyan : .neonCyan.opacity(0.8)).font(.title3) }
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)).font(.title3) }
                }
            }.padding().background(Color.darkGrey)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        buildTable(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, color: .gray)
                        ForEach(messages) { msg in
                            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 10) {
                                HStack { if msg.isUser { Spacer() }; VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 8) { if let img = msg.attachedImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 10)) }; if !msg.text.isEmpty { Text(msg.text) } }.font(.subheadline).padding(12).background(msg.isUser ? Color.neonGreen.opacity(0.2) : Color.gray.opacity(0.2)).foregroundColor(.white).cornerRadius(15); if !msg.isUser { Spacer() } }
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { buildTable(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, color: .neonCyan).padding(.trailing, 20) }
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
        .onAppear {
            originalIngredients = entry.ingredients; originalCalories = entry.calories; originalProtein = entry.protein
            if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false)) }
            let descriptor = FetchDescriptor<FavoriteFood>()
            if let existing = try? modelContext.fetch(descriptor), existing.contains(where: { $0.name == entry.name }) { savedToFridge = true }
        }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
    }
    
    // 🔥 ОЧИЩЕННАЯ ТАБЛИЦА С 4 КОЛОНКАМИ 🔥
    @ViewBuilder
    func buildTable(title: String, ingredients: String, calories: Double, protein: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.caption2).bold().foregroundColor(color); Spacer(); Text("\(Int(calories)) kcal • \(Int(protein))g prot").font(.caption2).bold().foregroundColor(.white) }
            VStack(spacing: 0) {
                HStack { Text("Item").frame(maxWidth: .infinity, alignment: .leading); Text("Weight").frame(width: 60, alignment: .center); Text("Kcal").frame(width: 40, alignment: .trailing); Text("Prot").frame(width: 40, alignment: .trailing) }.font(.caption.bold()).foregroundColor(.white).padding(.bottom, 8)
                Divider().background(Color.white.opacity(0.3))
                ForEach(parseIngredients(ingredients), id: \.0) { item, weight, kcal, prot in
                    HStack { Text(item).frame(maxWidth: .infinity, alignment: .leading); Text(weight).frame(width: 60, alignment: .center); Text(kcal).frame(width: 40, alignment: .trailing); Text(prot).frame(width: 40, alignment: .trailing) }.font(.system(size: 11, design: .monospaced)).foregroundColor(.white).padding(.vertical, 8)
                    Divider().background(Color.gray.opacity(0.1))
                }
            }.padding().background(Color.black.opacity(0.4)).cornerRadius(12)
        }
    }
    
    // 🔥 УМНЫЙ ПАРСЕР: ВЫРЕЗАЕТ ЛИШНИЙ ТЕКСТ И НЕ ТЕРЯЕТ ПРОТЕИН 🔥
    func parseIngredients(_ input: String) -> [(String, String, String, String)] {
        return input.components(separatedBy: "\n").compactMap { line in
            let p = line.components(separatedBy: ";")
            if p.count >= 3 {
                let name = p[0].trimmingCharacters(in: .whitespaces)
                let weight = p[1].trimmingCharacters(in: .whitespaces)
                // Вырезаем "kcal" и пробелы
                let kcal = p[2].replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                // Проверяем 4-ю колонку, вырезаем "g"
                let rawProt = p.count > 3 ? p[3] : "0"
                let prot = rawProt.replacingOccurrences(of: "g", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                
                return (name, weight, kcal.isEmpty ? "0" : kcal, prot.isEmpty ? "0" : prot)
            }
            return nil
        }
    }
    
    func saveToFridge() {
        guard !savedToFridge else { return }
        let descriptor = FetchDescriptor<FavoriteFood>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if !existing.contains(where: { $0.name == entry.name }) {
            let newFav = FavoriteFood(image: entry.uiImage, name: entry.name, calories: entry.calories, protein: entry.protein, ingredients: entry.ingredients)
            modelContext.insert(newFav)
        }
        withAnimation { savedToFridge = true }
    }
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: entry.name, emoji: nil, calories: entry.calories, protein: entry.protein, ingredients_breakdown: entry.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: entry.uiImage ?? UIImage(), additionalImage: imageToSend, currentData: current, userComment: text) { result, _ in isWaiting = false; if let res = result { entry.name = res.food_name; entry.calories = res.calories; entry.protein = res.protein; entry.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein)); savedToFridge = false } } }
}

struct FavoriteChatEditView: View {
    @Bindable var favorite: FavoriteFood
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0
    @State private var attachedImage: UIImage? = nil; @State private var isShowingAttachmentDialog = false; @State private var isShowingAttachmentPicker = false; @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    var onDelete: () -> Void; var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack { Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.neonCyan) }; Spacer(); Text("Edit Fridge Item").font(.headline).foregroundColor(.white); Spacer(); Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) } }.padding().background(Color.darkGrey)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        buildTable(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, color: .gray)
                        ForEach(messages) { msg in
                            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 10) {
                                HStack { if msg.isUser { Spacer() }; VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 8) { if let img = msg.attachedImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 10)) }; if !msg.text.isEmpty { Text(msg.text) } }.font(.subheadline).padding(12).background(msg.isUser ? Color.neonCyan.opacity(0.3) : Color.gray.opacity(0.2)).foregroundColor(.white).cornerRadius(15); if !msg.isUser { Spacer() } }
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { buildTable(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, color: .neonCyan).padding(.trailing, 20) }
                            }.id(msg.id)
                        }
                        if isWaiting { HStack { TypingIndicatorView(color: .neonCyan).padding(14).background(Color.gray.opacity(0.2)).cornerRadius(15); Spacer() }.id("TypingIndicator") }
                    }.padding()
                }.onChange(of: messages.count) { withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                if let img = attachedImage { HStack { ZStack(alignment: .topTrailing) { Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonCyan, lineWidth: 2)); Button(action: { withAnimation { attachedImage = nil } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Circle().fill(Color.black)) }.offset(x: 8, y: -8) }; Spacer() }.padding(.horizontal).padding(.top, 10) }
                HStack(spacing: 12) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.title3).foregroundColor(.neonCyan) }; TextField("Ask AI or attach label...", text: $userMessage).padding(10).background(Color.black.opacity(0.4)).cornerRadius(20).foregroundColor(.white); Button(action: sendMessage) { Image(systemName: "paperplane.fill").foregroundColor((userMessage.isEmpty && attachedImage == nil) || isWaiting ? .gray : .neonCyan) }.disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting) }.padding().background(Color(red: 20/255, green: 20/255, blue: 25/255))
            }
        }.background(Color.darkGrey).cornerRadius(25).overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.2), lineWidth: 1)).padding(.horizontal, 15).frame(maxHeight: 680)
        .onAppear { originalIngredients = favorite.ingredients; originalCalories = favorite.calories; originalProtein = favorite.protein; if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false)) } }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
    }
    
    @ViewBuilder
    func buildTable(title: String, ingredients: String, calories: Double, protein: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.caption2).bold().foregroundColor(color); Spacer(); Text("\(Int(calories)) kcal • \(Int(protein))g prot").font(.caption2).bold().foregroundColor(.white) }
            VStack(spacing: 0) {
                HStack { Text("Item").frame(maxWidth: .infinity, alignment: .leading); Text("Weight").frame(width: 60, alignment: .center); Text("Kcal").frame(width: 40, alignment: .trailing); Text("Prot").frame(width: 40, alignment: .trailing) }.font(.caption.bold()).foregroundColor(.white).padding(.bottom, 8)
                Divider().background(Color.white.opacity(0.3))
                ForEach(parseIngredients(ingredients), id: \.0) { item, weight, kcal, prot in
                    HStack { Text(item).frame(maxWidth: .infinity, alignment: .leading); Text(weight).frame(width: 60, alignment: .center); Text(kcal).frame(width: 40, alignment: .trailing); Text(prot).frame(width: 40, alignment: .trailing) }.font(.system(size: 11, design: .monospaced)).foregroundColor(.white).padding(.vertical, 8)
                    Divider().background(Color.gray.opacity(0.1))
                }
            }.padding().background(Color.black.opacity(0.4)).cornerRadius(12)
        }
    }
    
    func parseIngredients(_ input: String) -> [(String, String, String, String)] {
        return input.components(separatedBy: "\n").compactMap { line in
            let p = line.components(separatedBy: ";")
            if p.count >= 3 {
                let name = p[0].trimmingCharacters(in: .whitespaces)
                let weight = p[1].trimmingCharacters(in: .whitespaces)
                let kcal = p[2].replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                let rawProt = p.count > 3 ? p[3] : "0"
                let prot = rawProt.replacingOccurrences(of: "g", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                return (name, weight, kcal.isEmpty ? "0" : kcal, prot.isEmpty ? "0" : prot)
            }
            return nil
        }
    }
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: favorite.name, emoji: nil, calories: favorite.calories, protein: favorite.protein, ingredients_breakdown: favorite.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: favorite.uiImage ?? UIImage(), additionalImage: imageToSend, currentData: current, userComment: text) { result, _ in isWaiting = false; if let res = result { favorite.name = res.food_name; favorite.calories = res.calories; favorite.protein = res.protein; favorite.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein)) } } }
}

// MARK: - HEALTHKIT МЕНЕДЖЕР & СВАЙПЫ
class HealthKitManager { static let shared = HealthKitManager(); let healthStore = HKHealthStore(); func fetchSteps(for date: Date, completion: @escaping (Double) -> Void) { guard HKHealthStore.isHealthDataAvailable(), let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { completion(0); return }; healthStore.requestAuthorization(toShare: nil, read: [stepType]) { success, _ in guard success else { completion(0); return }; let start = Calendar.current.startOfDay(for: date); let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!; let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate), options: .cumulativeSum) { _, result, _ in completion(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0) }; self.healthStore.execute(query) } } }
struct SwipeToDeleteModifier: ViewModifier { var action: () -> Void; @State private var offset: CGFloat = 0; func body(content: Content) -> some View { ZStack(alignment: .trailing) { ZStack(alignment: .trailing) { RoundedRectangle(cornerRadius: 15).fill(Color.red); Image(systemName: "trash").font(.title3).foregroundColor(.white).padding(.trailing, 20) }.onTapGesture { withAnimation(.spring()) { offset = 0 }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { action() } }; content.background(Color.darkGrey).cornerRadius(15).offset(x: offset).gesture(DragGesture(minimumDistance: 30).onChanged { value in guard abs(value.translation.width) > abs(value.translation.height) else { return }; if value.translation.width < 0 { offset = max(value.translation.width, -80) } else if offset < 0 && value.translation.width > 0 { offset = min(value.translation.width - 80, 0) } }.onEnded { value in withAnimation(.spring()) { offset = value.translation.width < -40 ? -80 : 0 } }) } } }
extension View { func swipeToDelete(action: @escaping () -> Void) -> some View { self.modifier(SwipeToDeleteModifier(action: action)) } }

// MARK: - КАЛЕНДАРЬ
struct CustomCalendarView: View { @Binding var selectedDate: Date; var allEntries: [FoodEntry]; var maxCalories: Double; var targetProtein: Double; @Environment(\.dismiss) var dismiss; @State private var currentMonthOffset: Int = 0; let columns = Array(repeating: GridItem(.flexible()), count: 7); var body: some View { VStack(spacing: 20) { HStack { Button(action: { currentMonthOffset -= 1 }) { Image(systemName: "chevron.left").foregroundColor(.neonGreen).font(.title2) }; Spacer(); Text(monthYearString(for: currentMonthOffset)).font(.title3).bold().foregroundColor(.white); Spacer(); Button(action: { currentMonthOffset += 1 }) { Image(systemName: "chevron.right").foregroundColor(currentMonthOffset < 0 ? .neonGreen : .gray).font(.title2) }.disabled(currentMonthOffset >= 0) }.padding(.horizontal).padding(.top, 25); HStack { ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in Text(day).font(.caption).bold().foregroundColor(.gray).frame(maxWidth: .infinity) } }; LazyVGrid(columns: columns, spacing: 15) { ForEach(extractDates(), id: \.self) { date in if let date = date { let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate); let dailyEntries = allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }; let totalCal = dailyEntries.reduce(0) { $0 + $1.calories }; let totalProt = dailyEntries.reduce(0) { $0 + $1.protein }; let bgColor: Color = dailyEntries.isEmpty ? Color.gray.opacity(0.15) : (totalCal > maxCalories ? Color.red.opacity(0.8) : Color.neonGreen.opacity(0.8)); let proteinGoalMet = totalProt >= targetProtein && !dailyEntries.isEmpty; ZStack { Circle().fill(bgColor).frame(width: 40, height: 40); if proteinGoalMet { Circle().stroke(Color.neonCyan, lineWidth: 2).frame(width: 44, height: 44).shadow(color: .neonCyan.opacity(0.5), radius: 4) }; Text("\(Calendar.current.component(.day, from: date))").foregroundColor(bgColor == Color.gray.opacity(0.15) ? .white : .black).fontWeight(isSelected ? .bold : .medium) }.overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0).frame(width: 48, height: 48)).onTapGesture { if date <= Date() { selectedDate = date; dismiss() } } } else { Color.clear.frame(width: 40, height: 40) } } }; Spacer() }.padding().background(Color.darkGrey.edgesIgnoringSafeArea(.all)) }; func monthYearString(for offset: Int) -> String { let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()) }; func extractDates() -> [Date?] { let cal = Calendar.current; let target = cal.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date(); let start = cal.date(from: cal.dateComponents([.year, .month], from: target))!; let range = cal.range(of: .day, in: .month, for: start)!; var firstWeekday = cal.component(.weekday, from: start) - cal.firstWeekday; if firstWeekday < 0 { firstWeekday += 7 }; var dates: [Date?] = Array(repeating: nil, count: firstWeekday); for d in 1...range.count { if let date = cal.date(byAdding: .day, value: d - 1, to: start) { dates.append(date) } }; return dates } }
