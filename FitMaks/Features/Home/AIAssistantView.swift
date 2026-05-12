import SwiftUI

struct AIAssistantView: View {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    @Environment(\.dismiss) var dismiss

    var selectedDate: Date
    var consumedCalories: Double
    var consumedProtein: Double
    var consumedCarbs: Double
    var consumedFat: Double
    var targetCalories: Double
    var targetProtein: Double
    var targetCarbs: Double
    var targetFat: Double
    var foods: [FoodEntry]
    var trainings: [TrainingEntry]
    var favorites: [FavoriteFood]

    @State private var messages: [ChatMessage] = []
    @State private var userMessage = ""
    @State private var attachedImage: UIImage? = nil
    @State private var isShowingAttachmentDialog = false
    @State private var isShowingAttachmentPicker = false
    @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    @State private var isWaiting = false
    @FocusState private var isInputFocused: Bool

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
                        .onTapGesture { isInputFocused = false }
                    }

                    chatComposer
                }
            }
            .navigationTitle(aiNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appMuted)
                }
            }
            .onAppear {
                if messages.isEmpty {
                    fetchSummary(isInitial: true, message: "", image: nil)
                }
            }
            .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) {
                Button("Camera") {
                    self.attachmentSource = .camera
                    self.isShowingAttachmentPicker = true
                }
                Button("Library") {
                    self.attachmentSource = .photoLibrary
                    self.isShowingAttachmentPicker = true
                }
            }
            .fullScreenCover(isPresented: $isShowingAttachmentPicker) {
                ImagePicker(
                    selectedImage: Binding(
                        get: { self.attachedImage },
                        set: { if let img = $0 { withAnimation { self.attachedImage = img.preparedForAIIntake() } } }
                    ),
                    sourceType: attachmentSource
                )
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private var coachPulseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(aiPulseLabel, systemImage: "sparkles")
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
                        : "\(Int(max(targetCalories - consumedCalories, 0))) deficit"
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

            HStack(spacing: 10) {
                compactMacroCard(
                    title: "Carbs",
                    valueText: "\(Int(consumedCarbs))g",
                    detailText: "cap \(Int(targetCarbs))g",
                    statusText: carbStatusLabel,
                    statusColor: carbStatusColor,
                    tintColor: .fitOrange
                )

                compactMacroCard(
                    title: "Fat",
                    valueText: "\(Int(consumedFat))g",
                    detailText: "zone \(Int(fatLowerBound))-\(Int(fatUpperBound))g",
                    statusText: fatCompactStatusLabel,
                    statusColor: fatStatusColor,
                    tintColor: .yellow
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

    private var aiNavTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "AI Coach ✨" }
        if cal.isDateInTomorrow(selectedDate) { return "Plan Tomorrow 📋" }
        return "Past Day Review 📅"
    }

    private var aiPulseLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "TODAY'S PULSE" }
        if cal.isDateInTomorrow(selectedDate) { return "TOMORROW'S PLAN" }
        return "DAY REVIEW"
    }

    private var coachHeadline: String {
        let cal = Calendar.current
        if cal.isDateInTomorrow(selectedDate) {
            if consumedCalories > 0 {
                return "Meals pre-logged. Fine-tune the plan."
            }
            return "Plan ahead, win before it starts."
        }

        if cal.isDateInToday(selectedDate) {
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

    private func compactMacroCard(title: String, valueText: String, detailText: String, statusText: String, statusColor: Color, tintColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(tintColor)
                    .tracking(0.7)

                Spacer(minLength: 6)

                Text(statusText)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(statusText == "Base" || statusText == "In range" ? .black : .appAccentText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(statusColor))
            }

            Text(valueText)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.appText)

            Text(detailText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.appMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appElevated.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(tintColor.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var carbBurnThreshold: Double {
        max(min(targetCarbs * 0.7, targetCarbs), 0)
    }

    private var carbStatusColor: Color {
        if consumedCarbs > targetCarbs { return .red }
        if consumedCarbs <= carbBurnThreshold { return .neonGreen }
        if consumedCarbs <= targetCarbs { return .fitOrange }
        return .red
    }

    private var carbStatusLabel: String {
        if consumedCarbs > targetCarbs { return "Over" }
        if consumedCarbs <= carbBurnThreshold { return "Low" }
        return "Base"
    }

    private var fatLowerBound: Double {
        max(targetFat * 0.85, targetFat - 8)
    }

    private var fatUpperBound: Double {
        max(targetFat * 1.15, fatLowerBound + 6)
    }

    private var fatStatusColor: Color {
        if consumedFat < fatLowerBound { return .fitOrange }
        if consumedFat > fatUpperBound { return .fitPurple }
        return .yellow
    }

    private var fatStatusDetail: String {
        if consumedFat < fatLowerBound {
            return "\(Int(fatLowerBound - consumedFat))g below zone"
        }
        if consumedFat > fatUpperBound {
            return "\(Int(consumedFat - fatUpperBound))g above zone"
        }
        return "in support zone"
    }

    private var fatCompactStatusLabel: String {
        if consumedFat < fatLowerBound { return "Low" }
        if consumedFat > fatUpperBound { return "High" }
        return "In range"
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
                                .foregroundColor(.appText)
                                .background(Circle().fill(Color.appElevated))
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
                    .focused($isInputFocused)
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
        isInputFocused = false
        let text = userMessage
        let imageToSend = attachedImage
        messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend))
        userMessage = ""
        withAnimation { attachedImage = nil }
        fetchSummary(isInitial: false, message: text, image: imageToSend)
    }

    func fetchSummary(isInitial: Bool, message: String, image: UIImage?) {
        isWaiting = true

        let timeString = Self.timeFormatter.string(from: Date())

        let calendar = Calendar.current
        let isTomorrow = calendar.isDateInTomorrow(selectedDate)
        let isPastDay = !calendar.isDateInToday(selectedDate) && !isTomorrow
        let selectedDateDescription = Self.dateOnlyFormatter.string(from: selectedDate)

        let selectedDateRelation: String
        if calendar.isDateInToday(selectedDate) {
            selectedDateRelation = "today"
        } else if isTomorrow {
            selectedDateRelation = "tomorrow (planning ahead — the user is pre-logging meals and choosing a training mode for the next day)"
        } else if calendar.isDateInYesterday(selectedDate) {
            selectedDateRelation = "yesterday"
        } else {
            selectedDateRelation = "older past date, not yesterday"
        }

        let mealNames = foods.map { "\($0.name) (\(Int($0.calories)) kcal, \(Int($0.protein))g P)" }
        let workoutNames = trainings.map { training in
            let stepsText = (training.steps ?? 0) > 0 ? ", \(Int(training.steps ?? 0)) steps" : ""
            return "\(training.name) (\(Int(training.caloriesBurned)) kcal burned\(stepsText))"
        }
        let fridgeNames = favorites.map { "\($0.name) (\(Int($0.calories))kcal, \(Int($0.protein))g protein)" }
        let recentMessages = messages.suffix(4).map { msg in
            "\(msg.isUser ? "User" : "Coach"): \(msg.text)"
        }

        GeminiService.shared.sendCoachMessage(image: image, message: message, isInitial: isInitial, isPastDay: isPastDay, selectedDateDescription: selectedDateDescription, selectedDateRelation: selectedDateRelation, timeOfDay: timeString, consumedCalories: consumedCalories, consumedProtein: consumedProtein, consumedCarbs: consumedCarbs, consumedFat: consumedFat, targetCalories: targetCalories, targetProtein: targetProtein, targetCarbs: targetCarbs, targetFat: targetFat, meals: mealNames, workouts: workoutNames, fridgeItems: fridgeNames, recentMessages: recentMessages, userName: AuthService.shared.displayName) { result, error in
            DispatchQueue.main.async {
                self.isWaiting = false
                let aiText = result ?? error ?? "Oops, something went wrong connecting to the AI. Try again!"
                self.messages.append(ChatMessage(text: aiText, isUser: false, shouldTypewrite: true))
            }
        }
    }
}
