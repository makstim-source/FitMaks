import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 🔥 ГЛАВНЫЙ ЭКРАН MY FOOD 🔥
struct MyFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var favorites: [FavoriteFood]
    @Query var savedRecipes: [SavedRecipe]
    @Query var shoppingItems: [ShoppingItem]
    @Environment(\.dismiss) var dismiss
    
    var isSelectionMode: Bool
    var initialTab: Int
    var selectedDate: Date
    @Binding var processingItems: [ProcessingItem]
    var onProcessQueue: ([ProcessingItem]) -> Void
    
    @State private var isShowingSourceDialog = false
    @State private var isShowingReceiptSourceDialog = false // 🔥 Для скана чеков
    @State private var isShowingCamera = false
    @State private var selectedCameraImage: UIImage?
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingTextEntry = false
    @State private var manualText = ""
    @State private var selectedFavoriteForEdit: FavoriteFood?
    
    @State private var currentTab = 0
    @State private var newShopItem = ""
    
    // AI Chef & Scanner
    @State private var isGeneratingRecipe = false
    @State private var suggestedRecipes: [RecipeResult] = []
    @State private var showRecipeSuggestions = false
    @State private var selectedRecipeToShow: RecipeResult?
    @State private var isScanningReceipt = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    if !isSelectionMode {
                        Picker("", selection: $currentTab) {
                            Text("Fridge ❄️").tag(0)
                            Text("Meals 🍲").tag(1)
                            Text("Shopping 🛒").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        .background(Color.black.opacity(0.2))
                    }
                    
                    if currentTab == 0 {
                        fridgeTab
                    } else if currentTab == 1 {
                        mealsTab
                    } else {
                        shoppingTab
                    }
                }
                
                editOverlay
            }
            .navigationTitle(isSelectionMode ? (initialTab == 0 ? "Pick from Fridge" : "Pick from Meals") : "My Food 🍱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.neonCyan) }
                if !isSelectionMode && (currentTab == 0 || currentTab == 1) {
                    // 🔥 Теперь плюс есть и в холодильнике, и в Meals 🔥
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isShowingSourceDialog = true }) {
                            Image(systemName: "plus").foregroundColor(currentTab == 0 ? .neonCyan : .orange).font(.title3.bold())
                        }
                    }
                }
            }
            .confirmationDialog("Add to \(currentTab == 0 ? "Fridge" : "Meals")", isPresented: $isShowingSourceDialog) {
                Button("Camera") { self.isScanningReceipt = false; self.isShowingCamera = true }
                Button("Library") { self.isScanningReceipt = false; self.isShowingPhotoPicker = true }
                Button("Type Text") { self.isShowingTextEntry = true }
            }
            // 🔥 ДИАЛОГ ДЛЯ ЧЕКОВ 🔥
            .confirmationDialog("Scan Receipt", isPresented: $isShowingReceiptSourceDialog) {
                Button("Camera") { self.isScanningReceipt = true; self.isShowingCamera = true }
                Button("Photo Library") { self.isScanningReceipt = true; self.isShowingPhotoPicker = true }
            }
            .alert("Add Item", isPresented: $isShowingTextEntry) {
                TextField("E.g. 150g Greek Yogurt", text: $manualText)
                Button("Analyze") {
                    guard !manualText.isEmpty else { return }
                    // Передаем currentTab (0 или 1), чтобы ContentView знал, куда сохранять
                    let item = ProcessingItem(images: [UIImage(systemName: "brain")!], textPrompt: manualText, targetTab: currentTab)
                    withAnimation { processingItems.append(item) }
                    onProcessQueue([item])
                    manualText = ""
                }
                Button("Cancel", role: .cancel) { manualText = "" }
            }
            .fullScreenCover(isPresented: $isShowingCamera) { ImagePicker(selectedImage: $selectedCameraImage, sourceType: .camera) }
            .onChange(of: selectedCameraImage) { _, newValue in
                if let img = newValue {
                    if isScanningReceipt { processReceipt(img) } else { let item = ProcessingItem(images: [img], targetTab: currentTab); processingItems.append(item); onProcessQueue([item]) }
                    selectedCameraImage = nil; isScanningReceipt = false
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
                            if isScanningReceipt { processReceipt(loadedImages.first!) } else { let newItem = ProcessingItem(images: loadedImages, targetTab: currentTab); withAnimation { processingItems.append(newItem) }; onProcessQueue([newItem]) }
                        }
                    }
                }
            }
            .sheet(isPresented: $showRecipeSuggestions) { RecipeSuggestionsView(recipes: suggestedRecipes, selectedDate: selectedDate) }
            .sheet(item: $selectedRecipeToShow) { rec in RecipeSheet(recipe: rec, isPreSaved: true, selectedDate: selectedDate) }
            .onAppear { if isSelectionMode { currentTab = initialTab } }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - ПОДВЬЮХИ ДЛЯ ВКЛАДОК
    @ViewBuilder
    private var fridgeTab: some View {
        if favorites.isEmpty && processingItems.isEmpty {
            VStack(spacing: 15) { Spacer(); Image(systemName: "snowflake").font(.system(size: 60)).foregroundColor(.neonCyan.opacity(0.4)); Text("Fridge is empty").font(.headline).foregroundColor(.white); Spacer() }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(processingItems) { item in loadingRow(item: item) }
                    ForEach(favorites.reversed()) { fav in
                        favoriteRow(fav)
                            .onTapGesture {
                                if isSelectionMode {
                                    modelContext.insert(FoodEntry(image: fav.uiImage ?? UIImage(), name: fav.name, calories: fav.calories, protein: fav.protein, ingredients: fav.ingredients, date: selectedDate))
                                    dismiss()
                                } else {
                                    withAnimation(.spring()) { selectedFavoriteForEdit = fav }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { modelContext.delete(fav) } label: { Label("Delete", systemImage: "trash") }
                                Button { moveFavToMeals(fav) } label: { Label("To Meals", systemImage: "fork.knife") }.tint(.orange)
                            }
                    }
                }.padding()
            }.blur(radius: selectedFavoriteForEdit != nil ? 15 : 0)
        }
        
        if !isSelectionMode {
            HStack {
                Button(action: cookSomething) {
                    HStack { if isGeneratingRecipe { ProgressView().tint(.white).padding(.trailing, 5) } else { Image(systemName: "sparkles") }; Text(isGeneratingRecipe ? "Thinking..." : "Suggest a dish").bold() }
                        .frame(maxWidth: .infinity).padding().background(Color.neonCyan).foregroundColor(.black).cornerRadius(15)
                }.disabled(isGeneratingRecipe)
                
                Button(action: { isShowingReceiptSourceDialog = true }) {
                    HStack { Image(systemName: "receipt"); Text("Scan Receipt").bold() }
                        .frame(maxWidth: .infinity).padding().background(Color.black).foregroundColor(.white).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                }
            }.padding(.horizontal).padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var mealsTab: some View {
        if savedRecipes.isEmpty && processingItems.isEmpty {
            VStack(spacing: 15) { Spacer(); Image(systemName: "fork.knife").font(.system(size: 60)).foregroundColor(.orange.opacity(0.4)); Text("No saved meals").font(.headline).foregroundColor(.white); Spacer() }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(processingItems) { item in loadingRow(item: item) }
                    ForEach(savedRecipes.reversed()) { r in
                        Button(action: {
                            if isSelectionMode {
                                // 🔥 Теперь используем картинку из SavedRecipe 🔥
                                modelContext.insert(FoodEntry(image: r.uiImage ?? UIImage(systemName: "fork.knife")!, name: "👨‍🍳 " + r.name, calories: r.calories, protein: r.protein, ingredients: "Meal;1 portion;\(r.calories);\(r.protein)", date: selectedDate))
                                dismiss()
                            } else {
                                if !r.instructions.isEmpty { selectedRecipeToShow = r.asResult }
                            }
                        }) {
                            HStack(spacing: 15) {
                                if let img = r.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(r.name).font(.headline).foregroundColor(.white).multilineTextAlignment(.leading)
                                    Text("\(Int(r.calories)) kcal • \(Int(r.protein))g P").font(.caption).foregroundColor(.orange)
                                }
                            }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.3)))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { modelContext.delete(r) } label: { Label("Delete", systemImage: "trash") }
                            Button { moveMealToFav(r) } label: { Label("To Fridge", systemImage: "snowflake") }.tint(.neonCyan)
                        }
                    }
                }.padding()
            }
        }
    }

    @ViewBuilder
    private var shoppingTab: some View {
        VStack {
            HStack {
                TextField("Add item...", text: $newShopItem).padding(12).background(Color.black.opacity(0.4)).cornerRadius(10).foregroundColor(.white)
                Button(action: { guard !newShopItem.isEmpty else { return }; modelContext.insert(ShoppingItem(name: newShopItem)); newShopItem = "" }) { Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.neonCyan) }
            }.padding()
            
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(shoppingItems.sorted(by: { !$0.isCompleted && $1.isCompleted })) { item in
                        HStack {
                            Button(action: { withAnimation { item.isCompleted.toggle() } }) { Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(item.isCompleted ? .gray : .neonCyan).font(.title2) }
                            Text(item.name).foregroundColor(item.isCompleted ? .gray : .white).strikethrough(item.isCompleted)
                            Spacer()
                        }.padding().background(Color.black.opacity(0.2))
                        .swipeActions { Button(role: .destructive) { modelContext.delete(item) } label: { Label("Delete", systemImage: "trash") } }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var editOverlay: some View {
        if let fav = selectedFavoriteForEdit {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedFavoriteForEdit = nil } }
            FavoriteChatEditView(favorite: fav, onDelete: { modelContext.delete(fav); withAnimation { selectedFavoriteForEdit = nil } }, onDone: { withAnimation { selectedFavoriteForEdit = nil } })
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // MARK: - HELPER METHODS
    func favoriteRow(_ fav: FavoriteFood) -> some View { HStack(spacing: 15) { if let img = fav.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }; VStack(alignment: .leading) { Text(fav.name).font(.subheadline).bold().foregroundColor(.white); Text("\(Int(fav.calories)) kcal • \(Int(fav.protein))g protein").font(.caption).foregroundColor(.neonCyan) }; Spacer(); if isSelectionMode { Image(systemName: "plus.circle.fill").foregroundColor(.neonCyan).font(.title3) } else { Image(systemName: "pencil").foregroundColor(.gray).font(.subheadline) } }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.neonCyan.opacity(0.3), lineWidth: 1))) }
    func loadingRow(item: ProcessingItem) -> some View { HStack(spacing: 15) { if let firstImg = item.images.first { Image(uiImage: firstImg).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(Color.black.opacity(0.2).cornerRadius(10)) }; VStack(alignment: .leading, spacing: 6) { Text("Analyzing...").font(.subheadline).bold().foregroundColor(.white); RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 120, height: 10) }; Spacer(); ProgressView().tint(.neonCyan) }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.neonCyan.opacity(0.5), lineWidth: 1)).shadow(color: .neonCyan.opacity(0.2), radius: 5)) }
    
    // ЛОГИКА ПЕРЕНОСА С ФОТКАМИ
    func moveFavToMeals(_ fav: FavoriteFood) {
        let newMeal = SavedRecipe(image: fav.uiImage, name: fav.name, instructions: "", calories: fav.calories, protein: fav.protein)
        modelContext.insert(newMeal); modelContext.delete(fav)
    }
    
    func moveMealToFav(_ r: SavedRecipe) {
        let newFav = FavoriteFood(image: r.uiImage, name: r.name, calories: r.calories, protein: r.protein, ingredients: "Meal;1 portion;\(r.calories);\(r.protein)")
        modelContext.insert(newFav); modelContext.delete(r)
    }
    
    func processReceipt(_ img: UIImage) {
        let item = ProcessingItem(images: [img])
        withAnimation { processingItems.append(item) }
        GeminiService.shared.scanGroceries(images: [img]) { results, _ in
            DispatchQueue.main.async {
                if let index = processingItems.firstIndex(where: { $0.id == item.id }) { processingItems.remove(at: index) }
                if let items = results {
                    for res in items { modelContext.insert(FavoriteFood(image: UIImage(systemName: "cart"), name: res.food_name, calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown)) }
                }
            }
        }
    }

    func cookSomething() {
        isGeneratingRecipe = true
        let items = favorites.map { "\($0.name)" }
        GeminiService.shared.generateRecipes(from: items) { res, _ in
            isGeneratingRecipe = false
            if let res = res, !res.isEmpty { suggestedRecipes = res; showRecipeSuggestions = true }
        }
    }
}

// MARK: - 🔥 ВЫБОР ИЗ СГЕНЕРИРОВАННЫХ РЕЦЕПТОВ 🔥
struct RecipeSuggestionsView: View {
    var recipes: [RecipeResult]
    var selectedDate: Date
    @Environment(\.dismiss) var dismiss
    @State private var selectedRecipe: RecipeResult?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 15) {
                        Text("Chef's Suggestions").font(.title2).bold().foregroundColor(.white).padding(.top)
                        ForEach(recipes) { r in
                            Button(action: { selectedRecipe = r }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(r.recipe_name).font(.headline).foregroundColor(.white).multilineTextAlignment(.leading)
                                    HStack {
                                        Text("\(Int(r.estimated_calories)) kcal").foregroundColor(.neonGreen)
                                        Text("•").foregroundColor(.gray)
                                        Text("\(Int(r.estimated_protein))g protein").foregroundColor(.neonCyan)
                                    }.font(.subheadline).bold()
                                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.4))).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.foregroundColor(.gray) } }
            .sheet(item: $selectedRecipe) { rec in RecipeSheet(recipe: rec, isPreSaved: false, selectedDate: selectedDate) }
        }.preferredColorScheme(.dark)
    }
}

// MARK: - 🔥 ЭКРАН ПОКАЗА РЕЦЕПТА 🔥
struct RecipeSheet: View {
    var recipe: RecipeResult
    var isPreSaved: Bool
    var selectedDate: Date
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isSaved = false
    @State private var isAddedToDiary = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(recipe.recipe_name).font(.largeTitle).bold().foregroundColor(.white).lineLimit(nil).fixedSize(horizontal: false, vertical: true).padding(.top)
                        HStack {
                            VStack(spacing: 5) { Text("CALORIES").font(.caption).foregroundColor(.gray); Text("\(Int(recipe.estimated_calories))").font(.title2).bold().foregroundColor(.neonGreen) }.frame(maxWidth: .infinity)
                            Divider().background(Color.gray).frame(height: 30)
                            VStack(spacing: 5) { Text("PROTEIN").font(.caption).foregroundColor(.gray); Text("\(Int(recipe.estimated_protein))g").font(.title2).bold().foregroundColor(.neonCyan) }.frame(maxWidth: .infinity)
                        }.padding().background(Color.black.opacity(0.3)).cornerRadius(15)
                        
                        Text(LocalizedStringKey(recipe.cooking_instructions)).foregroundColor(.gray).lineSpacing(5)
                        
                        Button(action: addToDiary) {
                            HStack { Image(systemName: isAddedToDiary ? "checkmark" : "plus.circle.fill"); Text(isAddedToDiary ? "Added to Diary" : "Add to Today's Diary 🍽️").bold() }
                                .frame(maxWidth: .infinity).padding().background(isAddedToDiary ? Color.neonGreen.opacity(0.8) : Color.orange).foregroundColor(.white).cornerRadius(15).padding(.top, 20)
                        }.disabled(isAddedToDiary)
                        Spacer()
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.gray) }
                if !isPreSaved {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isSaved ? "Saved ✅" : "Save Meal") {
                            if !isSaved {
                                modelContext.insert(SavedRecipe(name: recipe.recipe_name, instructions: recipe.cooking_instructions, calories: recipe.estimated_calories, protein: recipe.estimated_protein))
                                withAnimation { isSaved = true }
                            }
                        }.foregroundColor(isSaved ? .neonGreen : .orange).bold()
                    }
                }
            }
        }.preferredColorScheme(.dark)
    }
    
    func addToDiary() {
        modelContext.insert(FoodEntry(image: UIImage(systemName: "fork.knife")!, name: "👨‍🍳 " + recipe.recipe_name, calories: recipe.estimated_calories, protein: recipe.estimated_protein, ingredients: "Recipe;1 portion;\(recipe.estimated_calories);\(recipe.estimated_protein)", date: selectedDate))
        withAnimation { isAddedToDiary = true }
    }
}

// MARK: - 🔥 ЧАТ ДЛЯ РЕДАКТИРОВАНИЯ ИЗБРАННОГО (ХОЛОДИЛЬНИК) 🔥
struct FavoriteChatEditView: View {
    @Bindable var favorite: FavoriteFood
    @State private var userMessage = ""
    @State private var isWaiting = false
    @State private var messages: [ChatMessage] = []
    @State private var originalIngredients = ""
    @State private var originalCalories: Double = 0
    @State private var originalProtein: Double = 0
    @State private var attachedImage: UIImage? = nil
    @State private var isShowingAttachmentDialog = false
    @State private var isShowingAttachmentPicker = false
    @State private var attachmentSource: UIImagePickerController.SourceType = .camera
    var onDelete: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack { Button(action: onDone) { Text("Done").fontWeight(.bold).foregroundColor(.neonCyan) }; Spacer(); Text("Edit Item").font(.headline).foregroundColor(.white); Spacer(); Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) } }.padding().background(Color.darkGrey)
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
                ForEach(parseIngredients(ingredients)) { item in
                    HStack { Text(item.name).frame(maxWidth: .infinity, alignment: .leading); Text(item.weight).frame(width: 60, alignment: .center); Text(item.kcal).frame(width: 40, alignment: .trailing); Text(item.prot).frame(width: 40, alignment: .trailing) }.font(.system(size: 11, design: .monospaced)).foregroundColor(.white).padding(.vertical, 8)
                    Divider().background(Color.gray.opacity(0.1))
                }
            }.padding().background(Color.black.opacity(0.4)).cornerRadius(12)
        }
    }
    
    func parseIngredients(_ input: String) -> [ParsedIng] {
        return input.components(separatedBy: "\n").compactMap { line in
            let p = line.components(separatedBy: ";")
            if p.count >= 3 {
                let name = p[0].trimmingCharacters(in: .whitespaces)
                let weight = p[1].trimmingCharacters(in: .whitespaces)
                let kcal = p[2].replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                let rawProt = p.count > 3 ? p[3] : "0"
                let prot = rawProt.replacingOccurrences(of: "g", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                return ParsedIng(name: name, weight: weight, kcal: kcal.isEmpty ? "0" : kcal, prot: prot.isEmpty ? "0" : prot)
            }
            return nil
        }
    }
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: favorite.name, emoji: nil, calories: favorite.calories, protein: favorite.protein, ingredients_breakdown: favorite.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text) { result, _ in isWaiting = false; if let res = result { favorite.name = res.food_name; favorite.calories = res.calories; favorite.protein = res.protein; favorite.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein)) } } }
}
