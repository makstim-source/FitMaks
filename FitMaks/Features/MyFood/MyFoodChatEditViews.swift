import SwiftUI
import SwiftData

struct FavoriteChatEditView: View {
    @Bindable var favorite: FavoriteFood
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0
    @State private var attachedImage: UIImage? = nil; @State private var isShowingAttachmentDialog = false; @State private var isShowingAttachmentPicker = false; @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    var onDelete: () -> Void; var onDone: () -> Void; var onMove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.neonCyan) }
                Spacer()
                Text("Edit Item").font(.headline).foregroundColor(.white)
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
                    colors: [Color.neonCyan.opacity(0.11), Color.black.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, accentColor: .neonCyan)
                        ForEach(messages) { msg in
                            VStack(spacing: 10) {
                                CoachMessageBubble(message: msg, accentColor: .neonCyan, assistantName: "FitMaks AI")
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, accentColor: .neonCyan).padding(.trailing, 20) }
                            }
                            .id(msg.id)
                        }
                        if isWaiting {
                            CoachTypingBubble(accentColor: .neonCyan)
                                .id("TypingIndicator")
                        }
                    }.padding()
                }.onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                if let img = attachedImage { HStack { ZStack(alignment: .topTrailing) { Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.neonCyan, lineWidth: 2)); Button(action: { withAnimation { attachedImage = nil } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Circle().fill(Color.black)) }.offset(x: 8, y: -8) }; Spacer() }.padding(.horizontal).padding(.top, 10) }
                HStack(spacing: 10) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.system(size: 17, weight: .black)).foregroundColor(.neonCyan).frame(width: 42, height: 42).background(Circle().fill(Color.white.opacity(0.07))) }; TextField("Ask AI or attach label...", text: $userMessage).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 14).frame(height: 42).background(Capsule().fill(Color.black.opacity(0.38))).overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)).foregroundColor(.white); Button(action: sendMessage) { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .black)).foregroundColor(.black).frame(width: 42, height: 42).background(Circle().fill((userMessage.isEmpty && attachedImage == nil) || isWaiting ? Color.gray.opacity(0.45) : Color.neonCyan)) }.disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting) }.padding(14).background(Color.black.opacity(0.24))
            }
        }.background(LinearGradient(colors: [Color(red: 18/255, green: 21/255, blue: 28/255), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(28).overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.neonCyan.opacity(0.18), lineWidth: 1)).padding(.horizontal, 15).frame(maxHeight: 680)
        .onAppear { originalIngredients = favorite.ingredients; originalCalories = favorite.calories; originalProtein = favorite.protein; if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false, shouldTypewrite: true)) } }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img.preparedForAIIntake() } } }), sourceType: attachmentSource) }
    }

    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: favorite.name, emoji: nil, calories: favorite.calories, protein: favorite.protein, ingredients_breakdown: favorite.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text, userName: AuthService.shared.displayName) { result, error in isWaiting = false; if let res = result { favorite.name = res.food_name; favorite.calories = res.calories; favorite.protein = res.protein; favorite.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true)) } else { messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true)) } } }

    func recalculateFresh() { guard let image = favorite.uiImage else { messages.append(ChatMessage(text: "I need the original photo to recalculate this one.", isUser: false, shouldTypewrite: true)); return }; isWaiting = true; messages.append(ChatMessage(text: "Recalculating fresh, ignoring previous memory...", isUser: true, attachedImage: image)); GeminiService.shared.analyzeImages(images: [image], ignoreCache: true) { result, error in isWaiting = false; if let res = result { favorite.name = res.food_name; favorite.calories = res.calories; favorite.protein = res.protein; favorite.ingredients = res.ingredients_breakdown; originalIngredients = res.ingredients_breakdown; originalCalories = res.calories; originalProtein = res.protein; messages.append(ChatMessage(text: "Fresh calculation applied.", isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true)) } else { messages.append(ChatMessage(text: error ?? "Fresh recalculation failed. Please try again.", isUser: false, shouldTypewrite: true)) } } }
}

struct MealChatEditView: View {
    @Bindable var recipe: SavedRecipe
    @State private var userMessage = ""; @State private var isWaiting = false; @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""; @State private var originalCalories: Double = 0; @State private var originalProtein: Double = 0
    @State private var attachedImage: UIImage? = nil; @State private var isShowingAttachmentDialog = false; @State private var isShowingAttachmentPicker = false; @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    var onDelete: () -> Void; var onDone: () -> Void; var onMove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.orange) }
                Spacer()
                Text("Edit Meal").font(.headline).foregroundColor(.white)
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
                    colors: [Color.orange.opacity(0.11), Color.black.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, accentColor: .orange)
                        ForEach(messages) { msg in
                            VStack(spacing: 10) {
                                CoachMessageBubble(message: msg, accentColor: .orange, assistantName: "FitMaks AI")
                                if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, accentColor: .orange).padding(.trailing, 20) }
                            }
                            .id(msg.id)
                        }
                        if isWaiting {
                            CoachTypingBubble(accentColor: .orange)
                                .id("TypingIndicator")
                        }
                    }.padding()
                }.onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                if let img = attachedImage { HStack { ZStack(alignment: .topTrailing) { Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange, lineWidth: 2)); Button(action: { withAnimation { attachedImage = nil } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Circle().fill(Color.black)) }.offset(x: 8, y: -8) }; Spacer() }.padding(.horizontal).padding(.top, 10) }
                HStack(spacing: 10) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.system(size: 17, weight: .black)).foregroundColor(.orange).frame(width: 42, height: 42).background(Circle().fill(Color.white.opacity(0.07))) }; TextField("Ask AI or attach label...", text: $userMessage).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 14).frame(height: 42).background(Capsule().fill(Color.black.opacity(0.38))).overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)).foregroundColor(.white); Button(action: sendMessage) { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .black)).foregroundColor(.black).frame(width: 42, height: 42).background(Circle().fill((userMessage.isEmpty && attachedImage == nil) || isWaiting ? Color.gray.opacity(0.45) : Color.orange)) }.disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting) }.padding(14).background(Color.black.opacity(0.24))
            }
        }.background(LinearGradient(colors: [Color(red: 18/255, green: 21/255, blue: 28/255), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(28).overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.orange.opacity(0.18), lineWidth: 1)).padding(.horizontal, 15).frame(maxHeight: 680)
        .onAppear { originalIngredients = recipe.ingredients; originalCalories = recipe.calories; originalProtein = recipe.protein; if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false, shouldTypewrite: true)) } }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img.preparedForAIIntake() } } }), sourceType: attachmentSource) }
    }

    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: recipe.name, emoji: nil, calories: recipe.calories, protein: recipe.protein, ingredients_breakdown: recipe.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text, userName: AuthService.shared.displayName) { result, error in isWaiting = false; if let res = result { recipe.name = res.food_name; recipe.calories = res.calories; recipe.protein = res.protein; recipe.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true)) } else { messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true)) } } }

    func recalculateFresh() { guard let image = recipe.uiImage else { messages.append(ChatMessage(text: "I need the original photo to recalculate this meal.", isUser: false, shouldTypewrite: true)); return }; isWaiting = true; messages.append(ChatMessage(text: "Recalculating fresh, ignoring previous memory...", isUser: true, attachedImage: image)); GeminiService.shared.analyzeImages(images: [image], ignoreCache: true) { result, error in isWaiting = false; if let res = result { recipe.name = res.food_name; recipe.calories = res.calories; recipe.protein = res.protein; recipe.ingredients = res.ingredients_breakdown; originalIngredients = res.ingredients_breakdown; originalCalories = res.calories; originalProtein = res.protein; messages.append(ChatMessage(text: "Fresh calculation applied.", isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true)) } else { messages.append(ChatMessage(text: error ?? "Fresh recalculation failed. Please try again.", isUser: false, shouldTypewrite: true)) } } }
}
