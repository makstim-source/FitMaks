import SwiftUI

struct AIAssistantView: View {
    @Environment(\.dismiss) var dismiss

    var selectedDate: Date
    var consumedCalories: Double
    var consumedProtein: Double
    var targetCalories: Double
    var targetProtein: Double
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

        let calendar = Calendar.current
        let isPastDay = !calendar.isDateInToday(selectedDate)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let selectedDateDescription = dateFormatter.string(from: selectedDate)

        let selectedDateRelation: String
        if calendar.isDateInToday(selectedDate) {
            selectedDateRelation = "today"
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

        GeminiService.shared.sendCoachMessage(image: image, message: message, isInitial: isInitial, isPastDay: isPastDay, selectedDateDescription: selectedDateDescription, selectedDateRelation: selectedDateRelation, timeOfDay: timeString, consumedCalories: consumedCalories, consumedProtein: consumedProtein, targetCalories: targetCalories, targetProtein: targetProtein, meals: mealNames, workouts: workoutNames, fridgeItems: fridgeNames, userName: AuthService.shared.displayName) { result, error in
            DispatchQueue.main.async {
                self.isWaiting = false
                let aiText = result ?? error ?? "Oops, something went wrong connecting to the AI. Try again!"
                self.messages.append(ChatMessage(text: aiText, isUser: false, shouldTypewrite: true))
            }
        }
    }
}
