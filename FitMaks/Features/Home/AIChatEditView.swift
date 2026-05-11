import SwiftUI
import SwiftData

struct AIChatEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: FoodEntry
    @State private var userMessage = ""
    @State private var isWaiting = false
    @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""
    @State private var originalCalories: Double = 0
    @State private var originalProtein: Double = 0
    @State private var originalCarbs: Double = 0
    @State private var originalFat: Double = 0
    @State private var attachedImage: UIImage? = nil
    @State private var isShowingAttachmentDialog = false
    @State private var isShowingAttachmentPicker = false
    @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    @State private var isShowingSaveDialog = false
    @State private var saveConfirmationText: String?
    @FocusState private var isInputFocused: Bool

    var onShare: (() -> Void)? = nil
    var onDelete: () -> Void
    var onDone: () -> Void

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
                    Text(entry.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.appText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 180)
                }

                Spacer()

                HStack(spacing: 14) {
                    if let onShare {
                        Button(action: onShare) {
                            Text("Post")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.fitOrange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.appElevated))
                                .shadow(color: .fitOrange.opacity(0.35), radius: 8)
                        }
                        .buttonStyle(.plain)
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
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, carbs: originalCarbs, fat: originalFat, accentColor: .neonGreen.opacity(0.8))
                        ForEach(messages) { msg in
                            VStack(spacing: 10) {
                                CoachMessageBubble(message: msg, accentColor: .neonGreen, assistantName: "FitMaks AI")
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein {
                                    IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, carbs: msg.carbs ?? 0, fat: msg.fat ?? 0, accentColor: .neonCyan)
                                        .padding(.trailing, 20)
                                }
                            }
                            .id(msg.id)
                        }
                        if isWaiting {
                            CoachTypingBubble(accentColor: .neonGreen)
                                .id("TypingIndicator")
                        }
                    }
                    .padding()
                }
                .onTapGesture { isInputFocused = false }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: isWaiting) { _, waiting in
                    if waiting {
                        withAnimation {
                            proxy.scrollTo("TypingIndicator", anchor: .bottom)
                        }
                    }
                }
            }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button(action: recalculateFresh) {
                        Text("Recalculate")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.appAccentText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(Color.neonGreen.opacity(isWaiting ? 0.45 : 1)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isWaiting)

                    Button(action: { isShowingSaveDialog = true }) {
                        Text("Save to My Food")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.appAccentText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(Color.neonCyan))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

                if let img = attachedImage {
                    HStack(spacing: 12) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonGreen, lineWidth: 2))
                            Button(action: { withAnimation { attachedImage = nil } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.appText)
                                    .background(Circle().fill(Color.appElevated))
                            }
                            .offset(x: 8, y: -8)
                        }

                        Button {
                            setAsDishPhoto(img)
                        } label: {
                            Label("Set as photo", systemImage: "photo.badge.checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.appAccentText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.neonGreen))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                HStack(spacing: 10) {
                    Button(action: { isShowingAttachmentDialog = true }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 17, weight: .black))
                            .foregroundColor(.neonCyan)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.appSurface))
                    }

                    TextField("Ask AI or attach label...", text: $userMessage)
                        .focused($isInputFocused)
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
        .onAppear {
            originalIngredients = entry.ingredients
            originalCalories = entry.calories
            originalProtein = entry.protein
            originalCarbs = entry.carbs
            originalFat = entry.fat
            if messages.isEmpty {
                messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false, shouldTypewrite: true))
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
        .confirmationDialog("Save to My Food", isPresented: $isShowingSaveDialog) {
            Button("Fridge") { saveAs(isMeal: false) }
            Button("Meals") { saveAs(isMeal: true) }
        }
        .overlay(alignment: .top) {
            if let saveConfirmationText {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .black))

                    Text(saveConfirmationText)
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundColor(.appAccentText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.neonGreen))
                .shadow(color: Color.neonGreen.opacity(0.28), radius: 14, x: 0, y: 7)
                .padding(.top, 58)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    func saveAs(isMeal: Bool) {
        let destination = isMeal ? "Meals" : "Fridge"

        if isMeal {
            modelContext.insert(SavedRecipe(image: entry.uiImage, name: entry.name, instructions: "", calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat, ingredients: entry.ingredients))
        } else {
            modelContext.insert(FavoriteFood(image: entry.uiImage, name: entry.name, calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat, ingredients: entry.ingredients))
        }

        do {
            try modelContext.save()
            let confirmation = "Saved to \(destination)"
            messages.append(ChatMessage(text: confirmation, isUser: false, shouldTypewrite: true))
            showSaveConfirmation(confirmation)
        } catch {
            messages.append(ChatMessage(text: "Could not save to \(destination). Please try again.", isUser: false, shouldTypewrite: true))
        }
    }

    private func showSaveConfirmation(_ text: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            saveConfirmationText = text
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            await MainActor.run {
                guard saveConfirmationText == text else {
                    return
                }

                withAnimation(.easeOut(duration: 0.22)) {
                    saveConfirmationText = nil
                }
            }
        }
    }

    private func setAsDishPhoto(_ image: UIImage) {
        let prepared = image.preparedForAppStorage()
        if let data = prepared.jpegData(compressionQuality: 0.72) {
            ImageCache.shared.invalidate(for: entry.id.uuidString)
            entry.imageData = data
            withAnimation { attachedImage = nil }
            showSaveConfirmation("Photo updated")
        }
    }

    func sendMessage() {
        isInputFocused = false
        let text = userMessage
        let imageToSend = attachedImage
        messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend))
        userMessage = ""
        withAnimation { attachedImage = nil }
        isWaiting = true
        let current = FoodResult(food_name: entry.name, emoji: nil, calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat, ingredients_breakdown: entry.ingredients, ai_response_text: "")
        GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text, userName: AuthService.shared.displayName) { result, error in
            isWaiting = false
            if let res = result {
                let prefix = entry.name.hasPrefix("👨‍🍳") ? "👨‍🍳 " : (entry.name.hasPrefix("❄️") ? "❄️ " : "")
                let cleanName = res.food_name.replacingOccurrences(of: "👨‍🍳 ", with: "").replacingOccurrences(of: "❄️ ", with: "")
                entry.name = prefix + cleanName
                entry.calories = res.calories
                entry.protein = res.protein
                entry.carbs = res.carbs
                entry.fat = res.fat
                entry.ingredients = res.ingredients_breakdown
                messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, carbs: res.carbs, fat: res.fat, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }

    func recalculateFresh() {
        guard let image = entry.uiImage else {
            messages.append(ChatMessage(text: "I need the original photo to recalculate this one.", isUser: false, shouldTypewrite: true))
            return
        }

        isWaiting = true
        messages.append(ChatMessage(text: "Recalculating from the photo and ignoring previous memory...", isUser: true, attachedImage: image))

        GeminiService.shared.analyzeImages(images: [image], ignoreCache: true) { result, error in
            isWaiting = false

            if let result {
                entry.name = result.food_name
                entry.calories = result.calories
                entry.protein = result.protein
                entry.carbs = result.carbs
                entry.fat = result.fat
                entry.ingredients = result.ingredients_breakdown
                originalIngredients = result.ingredients_breakdown
                originalCalories = result.calories
                originalProtein = result.protein
                originalCarbs = result.carbs
                originalFat = result.fat
                messages.append(ChatMessage(text: "Fresh calculation applied. If it still looks off, tell me what the food really is.", isUser: false, ingredients: result.ingredients_breakdown, calories: result.calories, protein: result.protein, carbs: result.carbs, fat: result.fat, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "Fresh recalculation failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }
}
