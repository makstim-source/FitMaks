import SwiftUI
import SwiftData
import PhotosUI

enum MyFoodEditPresentationStyle {
    case card
    case screen
}

struct FavoriteChatEditView: View {
    @Bindable var favorite: FavoriteFood
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0; @State private var originalCarbs: Double = 0; @State private var originalFat: Double = 0
    @State private var attachedImages: [UIImage] = []; @State private var isShowingAttachmentDialog = false; @State private var isShowingCameraPicker = false; @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingDirectPhotoDialog = false; @State private var isShowingDirectPhotoPicker = false; @State private var directPhotoSource: UIImagePickerController.SourceType = .camera
    @State private var isEditingBasis = false
    @State private var selectedBasis: FavoritePortionBasis
    @FocusState private var isInputFocused: Bool
    let presentationStyle: MyFoodEditPresentationStyle
    var onDelete: () -> Void; var onDone: () -> Void; var onMove: () -> Void

    private var lightTheme: Bool { isLightAppTheme() }
    private var isFullScreen: Bool { presentationStyle == .screen }

    init(
        favorite: FavoriteFood,
        presentationStyle: MyFoodEditPresentationStyle = .card,
        onDelete: @escaping () -> Void,
        onDone: @escaping () -> Void,
        onMove: @escaping () -> Void
    ) {
        self.favorite = favorite
        self.presentationStyle = presentationStyle
        self.onDelete = onDelete
        self.onDone = onDone
        self.onMove = onMove
        _selectedBasis = State(initialValue: favorite.portionBasis)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.neonCyan) }
                Spacer()
                Text("Edit Item").font(.headline).foregroundColor(.appText)
                Spacer()
                HStack(spacing: 15) {
                    Button(action: onMove) { Text("Move to Meals").font(.caption).bold().padding(.horizontal, 10).padding(.vertical, 6).background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(8) }
                    Button(action: recalculateFresh) { Image(systemName: "arrow.clockwise").foregroundColor(.neonCyan) }.disabled(isWaiting)
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.neonCyan.opacity(0.11), Color.appElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            HStack(spacing: 14) {
                Button(action: { isShowingDirectPhotoDialog = true }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let img = favorite.uiImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.neonCyan.opacity(0.15))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.neonCyan.opacity(0.6))
                                )
                        }
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.neonCyan))
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        TextField("Item name", text: $favorite.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.appText)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.neonCyan.opacity(0.45))
                    }
                    Rectangle()
                        .fill(Color.neonCyan.opacity(0.18))
                        .frame(height: 1)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            fridgeCategoryPicker
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        IngredientBreakdownCard(title: "BREAKDOWN", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, carbs: originalCarbs, fat: originalFat, accentColor: .neonCyan)
                        favoriteBasisCard
                            ForEach(messages) { msg in
                            VStack(spacing: 10) {
                                CoachMessageBubble(message: msg, accentColor: .neonCyan, assistantName: "ShapeForge AI")
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED", ingredients: ing, calories: cal, protein: prot, carbs: msg.carbs ?? 0, fat: msg.fat ?? 0, accentColor: .neonCyan).padding(.trailing, 20) }
                            }
                            .id(msg.id)
                        }
                        if isWaiting {
                            CoachTypingBubble(accentColor: .neonCyan)
                                .id("TypingIndicator")
                        }
                    }.padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                favoriteAttachedImagesPreview
                HStack(spacing: 10) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.system(size: 17, weight: .black)).foregroundColor(.neonCyan).frame(width: 42, height: 42).background(Circle().fill(lightTheme ? Color.appSurface : Color.appBorder)).overlay(Circle().stroke(lightTheme ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)) }; TextField("Ask AI to change...", text: $userMessage).focused($isInputFocused).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 14).frame(height: 42).background(Capsule().fill(lightTheme ? Color.appSurface.opacity(0.96) : Color.appSurface)).overlay(Capsule().stroke(Color.appBorder, lineWidth: 1)).foregroundColor(.appText); Button(action: sendMessage) { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .black)).foregroundColor(.appAccentText).frame(width: 42, height: 42).background(Circle().fill((userMessage.isEmpty && attachedImages.isEmpty) || isWaiting ? Color.gray.opacity(0.45) : Color.neonCyan)) }.disabled((userMessage.isEmpty && attachedImages.isEmpty) || isWaiting) }.padding(14).background(lightTheme ? Color.appElevated.opacity(0.98) : Color.appElevated)
            }
        }
        .background(
            Group {
                if isFullScreen {
                    LinearGradient(
                        colors: lightTheme
                            ? [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd]
                            : [Color(red: 7/255, green: 13/255, blue: 18/255), Color(red: 10/255, green: 16/255, blue: 22/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(lightTheme ? Color.appElevated : Color(red: 10/255, green: 14/255, blue: 20/255))
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: lightTheme
                                        ? [Color.appElevated, Color.appSurface]
                                        : [Color(red: 16/255, green: 22/255, blue: 30/255), Color(red: 11/255, green: 16/255, blue: 22/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 0 : 28, style: .continuous))
        .overlay(
            Group {
                if !isFullScreen {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.neonCyan.opacity(lightTheme ? 0.12 : 0.18), lineWidth: 1)
                }
            }
        )
        .padding(.horizontal, isFullScreen ? 0 : 15)
        .frame(maxWidth: .infinity, maxHeight: isFullScreen ? .infinity : 680, alignment: .top)
        .onAppear { originalIngredients = favorite.ingredients; originalCalories = favorite.calories; originalProtein = favorite.protein; originalCarbs = favorite.carbs; originalFat = favorite.fat }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { isShowingCameraPicker = true }; PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) { Text("Library") } }
        .fullScreenCover(isPresented: $isShowingCameraPicker) { ImagePicker(selectedImage: Binding(get: { nil }, set: { if let img = $0 { withAnimation { self.attachedImages.append(img.preparedForAIIntake()) } } }), sourceType: .camera) }
        .onChange(of: selectedPhotoItems) { _, items in Task { for item in items { if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) { await MainActor.run { withAnimation { attachedImages.append(uiImage.preparedForAIIntake()) } } } }; await MainActor.run { selectedPhotoItems = [] } } }
        .confirmationDialog("Change photo", isPresented: $isShowingDirectPhotoDialog) { Button("Camera") { self.directPhotoSource = .camera; self.isShowingDirectPhotoPicker = true }; Button("Library") { self.directPhotoSource = .photoLibrary; self.isShowingDirectPhotoPicker = true } }
        .fullScreenCover(isPresented: $isShowingDirectPhotoPicker) { ImagePicker(selectedImage: Binding(get: { nil }, set: { if let img = $0 { self.setAsDishPhoto(img) } }), sourceType: directPhotoSource) }
    }

    private var fridgeCategoryPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(FridgeCategory.allCases, id: \.rawValue) { cat in
                Button {
                    favorite.category = cat
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text("\(cat.emoji) \(cat.compactDisplayTitle)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(favorite.category == cat ? .appAccentText : .appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(favorite.category == cat ? Color.neonCyan : Color.appSurface))
                        .overlay(Capsule().stroke(favorite.category == cat ? Color.clear : Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var favoriteBasisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("COUNTING BASIS", systemImage: "ruler")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.neonCyan)
                    .tracking(0.6)

                Spacer()

                Button("Change") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        selectedBasis = favorite.portionBasis
                        isEditingBasis.toggle()
                    }
                }
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.neonCyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.neonCyan.opacity(0.12)))
            }

            Text(favorite.basisDisplayText)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.appText)

            if isEditingBasis {
                VStack(spacing: 10) {
                    ForEach(FavoritePortionBasis.allCases, id: \.rawValue) { basis in
                        Button {
                            selectedBasis = basis
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(basis.title)
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundColor(.appText)
                                    Text(basisDescription(for: basis))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.appMuted)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: selectedBasis == basis ? "checkmark.circle.fill" : "circle")
                                    .font(.title3.bold())
                                    .foregroundColor(selectedBasis == basis ? .neonGreen : .white.opacity(0.35))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.appSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedBasis == basis ? Color.neonGreen.opacity(0.22) : Color.appBorder, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                selectedBasis = favorite.portionBasis
                                isEditingBasis = false
                            }
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.appBorder))
                        }
                        .buttonStyle(.plain)

                        Button {
                            favorite.updatePortionBasis(selectedBasis)
                            originalIngredients = favorite.ingredients
                            originalCalories = favorite.calories
                            originalProtein = favorite.protein
                            originalCarbs = favorite.carbs
                            originalFat = favorite.fat
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                isEditingBasis = false
                            }
                        } label: {
                            Text("Apply")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(selectedBasis == favorite.portionBasis ? .appMuted : .appAccentText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(selectedBasis == favorite.portionBasis ? Color.gray.opacity(0.3) : Color.neonGreen))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedBasis == favorite.portionBasis)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.neonCyan.opacity(0.10), Color.appSurface, Color.appElevated],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.neonCyan.opacity(0.15), lineWidth: 1))
        )
    }

    @ViewBuilder
    private var favoriteAttachedImagesPreview: some View {
        if !attachedImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(attachedImages.enumerated()), id: \.offset) { (index: Int, img: UIImage) in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 56, height: 56).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonCyan.opacity(0.5), lineWidth: 1.5))
                            Button {
                                let i = index
                                withAnimation { attachedImages.remove(at: i) }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                                    .foregroundColor(.appText).background(Circle().fill(Color.appElevated))
                            }.offset(x: 6, y: -6)
                        }
                    }
                }.padding(.horizontal, 16)
            }.padding(.top, 10)
        }
    }

    private func basisDescription(for basis: FavoritePortionBasis) -> String {
        switch basis {
        case .per100g:
            return "Best for mince, bread, rice, oats, pasta, raw staples."
        case .perServing:
            return "Best for cooked dishes or foods you eat by portion."
        case .perPack:
            return "Best for yogurt cups, bars, drinks, and packaged products."
        case .perPiece:
            return "Best for eggs, bananas, slices, or single units."
        }
    }

    private func setAsDishPhoto(_ image: UIImage) {
        let prepared = image.preparedForAppStorage()
        if let data = prepared.jpegData(compressionQuality: 0.72) {
            ImageCache.shared.invalidate(for: favorite.id.uuidString)
            favorite.imageData = data
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            messages.append(ChatMessage(text: "📸 Dish photo updated!", isUser: false, shouldTypewrite: true))
        }
    }

    func sendMessage() {
        isInputFocused = false
        let text = userMessage
        let imagesToSend = attachedImages
        messages.append(ChatMessage(text: text, isUser: true, attachedImage: imagesToSend.first))
        userMessage = ""
        withAnimation { attachedImages.removeAll() }
        isWaiting = true

        let current = FoodResult(
            food_name: favorite.name,
            emoji: nil,
            calories: favorite.calories,
            protein: favorite.protein,
            carbs: favorite.carbs,
            fat: favorite.fat,
            ingredients_breakdown: favorite.ingredients,
            fridge_category: favorite.category.aiKey,
            meal_category: nil,
            ai_response_text: ""
        )

        GeminiService.shared.refineAnalysis(
            images: imagesToSend,
            currentData: current,
            userComment: text,
            userName: AuthService.shared.displayName
        ) { result, error in
            isWaiting = false
            if let res = result {
                favorite.name = res.food_name
                favorite.calories = res.calories
                favorite.protein = res.protein
                favorite.carbs = res.carbs
                favorite.fat = res.fat
                favorite.ingredients = res.ingredients_breakdown
                favorite.category = FridgeCategory.resolve(
                    name: res.food_name,
                    ingredients: res.ingredients_breakdown,
                    aiRawValue: res.fridge_category
                )
                if let newWeight = FavoritePortionRules.totalWeightGrams(from: res.ingredients_breakdown), newWeight > 0 {
                    favorite.portionGramsReference = newWeight
                }
                favorite.updatePortionBasis(favorite.portionBasis)
                messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: favorite.ingredients, calories: favorite.calories, protein: favorite.protein, carbs: favorite.carbs, fat: favorite.fat, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }

    func recalculateFresh() {
        guard let image = favorite.uiImage else {
            messages.append(ChatMessage(text: "I need the original photo to recalculate this one.", isUser: false, shouldTypewrite: true))
            return
        }

        isWaiting = true
        messages.append(ChatMessage(text: "Recalculating fresh, ignoring previous memory...", isUser: true, attachedImage: image))
        GeminiService.shared.analyzeImages(images: [image], ignoreCache: true) { result, error in
            isWaiting = false
            if let res = result {
                favorite.name = res.food_name
                favorite.calories = res.calories
                favorite.protein = res.protein
                favorite.carbs = res.carbs
                favorite.fat = res.fat
                favorite.ingredients = res.ingredients_breakdown
                favorite.category = FridgeCategory.resolve(
                    name: res.food_name,
                    ingredients: res.ingredients_breakdown,
                    aiRawValue: res.fridge_category
                )
                if let newWeight = FavoritePortionRules.totalWeightGrams(from: res.ingredients_breakdown), newWeight > 0 {
                    favorite.portionGramsReference = newWeight
                }
                favorite.updatePortionBasis(favorite.portionBasis)
                originalIngredients = favorite.ingredients
                originalCalories = favorite.calories
                originalProtein = favorite.protein
                originalCarbs = favorite.carbs
                originalFat = favorite.fat
                messages.append(ChatMessage(text: "Fresh calculation applied.", isUser: false, ingredients: favorite.ingredients, calories: favorite.calories, protein: favorite.protein, carbs: favorite.carbs, fat: favorite.fat, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "Fresh recalculation failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }
}

struct MealChatEditView: View {
    @Bindable var recipe: SavedRecipe
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0; @State private var originalCarbs: Double = 0; @State private var originalFat: Double = 0
    @State private var attachedImages: [UIImage] = []; @State private var isShowingAttachmentDialog = false; @State private var isShowingCameraPicker = false; @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingDirectPhotoDialog = false; @State private var isShowingDirectPhotoPicker = false; @State private var directPhotoSource: UIImagePickerController.SourceType = .camera
    @FocusState private var isInputFocused: Bool
    let presentationStyle: MyFoodEditPresentationStyle
    var onDelete: () -> Void; var onDone: () -> Void; var onMove: () -> Void
    private var lightTheme: Bool { isLightAppTheme() }
    private var isFullScreen: Bool { presentationStyle == .screen }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.orange) }
                Spacer()
                Text("Edit Meal").font(.headline).foregroundColor(.appText)
                Spacer()
                HStack(spacing: 15) {
                    Button(action: onMove) { Text("Move to Fridge").font(.caption).bold().padding(.horizontal, 10).padding(.vertical, 6).background(Color.neonCyan.opacity(0.2)).foregroundColor(.neonCyan).cornerRadius(8) }
                    Button(action: recalculateFresh) { Image(systemName: "arrow.clockwise").foregroundColor(.orange) }.disabled(isWaiting)
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.11), Color.appElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            HStack(spacing: 14) {
                Button(action: { isShowingDirectPhotoDialog = true }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let img = recipe.uiImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.orange.opacity(0.6))
                                )
                        }
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.orange))
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        TextField("Meal name", text: $recipe.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.appText)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange.opacity(0.45))
                    }
                    Rectangle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(height: 1)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            mealCategoryPicker
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        IngredientBreakdownCard(title: "BREAKDOWN", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, carbs: originalCarbs, fat: originalFat, accentColor: .orange)
                            ForEach(messages) { msg in
                            VStack(spacing: 10) {
                                CoachMessageBubble(message: msg, accentColor: .orange, assistantName: "ShapeForge AI")
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED", ingredients: ing, calories: cal, protein: prot, carbs: msg.carbs ?? 0, fat: msg.fat ?? 0, accentColor: .orange).padding(.trailing, 20) }
                            }
                            .id(msg.id)
                        }
                        if isWaiting {
                            CoachTypingBubble(accentColor: .orange)
                                .id("TypingIndicator")
                        }
                    }.padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                mealAttachedImagesPreview
                HStack(spacing: 10) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.system(size: 17, weight: .black)).foregroundColor(.orange).frame(width: 42, height: 42).background(Circle().fill(lightTheme ? Color.appSurface : Color.appBorder)).overlay(Circle().stroke(lightTheme ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)) }; TextField("Ask AI to change...", text: $userMessage).focused($isInputFocused).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 14).frame(height: 42).background(Capsule().fill(lightTheme ? Color.appSurface.opacity(0.96) : Color.appSurface)).overlay(Capsule().stroke(Color.appBorder, lineWidth: 1)).foregroundColor(.appText); Button(action: sendMessage) { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .black)).foregroundColor(.appAccentText).frame(width: 42, height: 42).background(Circle().fill((userMessage.isEmpty && attachedImages.isEmpty) || isWaiting ? Color.gray.opacity(0.45) : Color.orange)) }.disabled((userMessage.isEmpty && attachedImages.isEmpty) || isWaiting) }.padding(14).background(lightTheme ? Color.appElevated.opacity(0.98) : Color.appElevated)
            }
        }
        .background(
            Group {
                if isFullScreen {
                    LinearGradient(
                        colors: lightTheme
                            ? [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd]
                            : [Color(red: 7/255, green: 13/255, blue: 18/255), Color(red: 10/255, green: 16/255, blue: 22/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(lightTheme ? Color.appElevated : Color(red: 10/255, green: 14/255, blue: 20/255))
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: lightTheme
                                        ? [Color.appElevated, Color.appSurface]
                                        : [Color(red: 17/255, green: 23/255, blue: 30/255), Color(red: 12/255, green: 16/255, blue: 22/255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 0 : 28, style: .continuous))
        .overlay(
            Group {
                if !isFullScreen {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.orange.opacity(lightTheme ? 0.12 : 0.18), lineWidth: 1)
                }
            }
        )
        .padding(.horizontal, isFullScreen ? 0 : 15)
        .frame(maxWidth: .infinity, maxHeight: isFullScreen ? .infinity : 680, alignment: .top)
        .onAppear { originalIngredients = recipe.ingredients; originalCalories = recipe.calories; originalProtein = recipe.protein; originalCarbs = recipe.carbs; originalFat = recipe.fat }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { isShowingCameraPicker = true }; PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) { Text("Library") } }
        .fullScreenCover(isPresented: $isShowingCameraPicker) { ImagePicker(selectedImage: Binding(get: { nil }, set: { if let img = $0 { withAnimation { self.attachedImages.append(img.preparedForAIIntake()) } } }), sourceType: .camera) }
        .onChange(of: selectedPhotoItems) { _, items in Task { for item in items { if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) { await MainActor.run { withAnimation { attachedImages.append(uiImage.preparedForAIIntake()) } } } }; await MainActor.run { selectedPhotoItems = [] } } }
        .confirmationDialog("Change photo", isPresented: $isShowingDirectPhotoDialog) { Button("Camera") { self.directPhotoSource = .camera; self.isShowingDirectPhotoPicker = true }; Button("Library") { self.directPhotoSource = .photoLibrary; self.isShowingDirectPhotoPicker = true } }
        .fullScreenCover(isPresented: $isShowingDirectPhotoPicker) { ImagePicker(selectedImage: Binding(get: { nil }, set: { if let img = $0 { self.setAsDishPhoto(img) } }), sourceType: directPhotoSource) }
    }

    private var mealCategoryPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(MealCategory.allCases, id: \.rawValue) { cat in
                Button {
                    recipe.category = cat
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text("\(cat.emoji) \(cat.compactDisplayTitle)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(recipe.category == cat ? .appAccentText : .appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(recipe.category == cat ? Color.orange : Color.appSurface))
                        .overlay(Capsule().stroke(recipe.category == cat ? Color.clear : Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var mealAttachedImagesPreview: some View {
        if !attachedImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(attachedImages.enumerated()), id: \.offset) { (index: Int, img: UIImage) in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 56, height: 56).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.5), lineWidth: 1.5))
                            Button {
                                let i = index
                                withAnimation { attachedImages.remove(at: i) }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                                    .foregroundColor(.appText).background(Circle().fill(Color.appElevated))
                            }.offset(x: 6, y: -6)
                        }
                    }
                }.padding(.horizontal, 16)
            }.padding(.top, 10)
        }
    }

    private func setAsDishPhoto(_ image: UIImage) {
        let prepared = image.preparedForAppStorage()
        if let data = prepared.jpegData(compressionQuality: 0.72) {
            ImageCache.shared.invalidate(for: recipe.id.uuidString)
            recipe.imageData = data
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            messages.append(ChatMessage(text: "📸 Dish photo updated!", isUser: false, shouldTypewrite: true))
        }
    }

    func sendMessage() {
        isInputFocused = false
        let text = userMessage
        let imagesToSend = attachedImages
        messages.append(ChatMessage(text: text, isUser: true, attachedImage: imagesToSend.first))
        userMessage = ""
        withAnimation { attachedImages.removeAll() }
        isWaiting = true

        let current = FoodResult(
            food_name: recipe.name,
            emoji: nil,
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fat: recipe.fat,
            ingredients_breakdown: recipe.ingredients,
            fridge_category: nil,
            meal_category: recipe.category.aiKey,
            ai_response_text: ""
        )

        GeminiService.shared.refineAnalysis(
            images: imagesToSend,
            currentData: current,
            userComment: text,
            userName: AuthService.shared.displayName
        ) { result, error in
            isWaiting = false
            if let res = result {
                recipe.name = res.food_name
                recipe.calories = res.calories
                recipe.protein = res.protein
                recipe.carbs = res.carbs
                recipe.fat = res.fat
                recipe.ingredients = res.ingredients_breakdown
                recipe.category = MealCategory.fromAI(res.meal_category)
                    ?? MealCategory.infer(name: res.food_name, ingredients: res.ingredients_breakdown, dateSaved: recipe.dateSaved)
                messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, carbs: res.carbs, fat: res.fat, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }

    func recalculateFresh() {
        guard let image = recipe.uiImage else {
            messages.append(ChatMessage(text: "I need the original photo to recalculate this meal.", isUser: false, shouldTypewrite: true))
            return
        }

        isWaiting = true
        messages.append(ChatMessage(text: "Recalculating fresh, ignoring previous memory...", isUser: true, attachedImage: image))
        GeminiService.shared.analyzeImages(images: [image], ignoreCache: true) { result, error in
            isWaiting = false
            if let res = result {
                recipe.name = res.food_name
                recipe.calories = res.calories
                recipe.protein = res.protein
                recipe.carbs = res.carbs
                recipe.fat = res.fat
                recipe.ingredients = res.ingredients_breakdown
                recipe.category = MealCategory.fromAI(res.meal_category)
                    ?? MealCategory.infer(name: res.food_name, ingredients: res.ingredients_breakdown, dateSaved: recipe.dateSaved)
                originalIngredients = res.ingredients_breakdown
                originalCalories = res.calories
                originalProtein = res.protein
                originalCarbs = res.carbs
                originalFat = res.fat
                messages.append(ChatMessage(text: "Fresh calculation applied.", isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, carbs: res.carbs, fat: res.fat, shouldTypewrite: true))
            } else {
                messages.append(ChatMessage(text: error ?? "Fresh recalculation failed. Please try again.", isUser: false, shouldTypewrite: true))
            }
        }
    }
}

struct FavoriteChatEditScreen: View {
    @Bindable var favorite: FavoriteFood
    var onDelete: () -> Void
    var onDone: () -> Void
    var onMove: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            FavoriteChatEditView(
                favorite: favorite,
                presentationStyle: .screen,
                onDelete: onDelete,
                onDone: onDone,
                onMove: onMove
            )
        }
    }
}

struct MealChatEditScreen: View {
    @Bindable var recipe: SavedRecipe
    var onDelete: () -> Void
    var onDone: () -> Void
    var onMove: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            MealChatEditView(
                recipe: recipe,
                presentationStyle: .screen,
                onDelete: onDelete,
                onDone: onDone,
                onMove: onMove
            )
        }
    }
}
