import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var isShowingReceiptSourceDialog = false
    @State private var isShowingCamera = false
    @State private var selectedCameraImage: UIImage?
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingTextEntry = false
    @State private var manualText = ""
    @State private var isShowingClearAlert = false // 🔥 Для подтверждения очистки
    
    @State private var selectedFavoriteForEdit: FavoriteFood?
    @State private var selectedMealForEdit: SavedRecipe?
    
    @State private var currentTab = 0
    @State private var newShopItem = ""
    
    @State private var isGeneratingRecipe = false
    @State private var suggestedRecipes: [RecipeResult] = []
    @State private var showRecipeSuggestions = false
    @State private var selectedRecipeToShow: RecipeResult?
    @State private var isScanningReceipt = false
    @State private var aiErrorMessage: String?

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
                    
                    if currentTab == 0 { fridgeTab }
                    else if currentTab == 1 { mealsTab }
                    else { shoppingTab }
                }
                
                editOverlay
            }
            .navigationTitle(isSelectionMode ? (initialTab == 0 ? "Pick from Fridge" : "Pick from Meals") : "My Food 🍱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.neonCyan) }
            }
            .confirmationDialog("Add to \(currentTab == 0 ? "Fridge" : "Meals")", isPresented: $isShowingSourceDialog) {
                Button("Camera") { self.isScanningReceipt = false; self.isShowingCamera = true }
                Button("Library") { self.isScanningReceipt = false; self.isShowingPhotoPicker = true }
                Button("Type Text") { self.isShowingTextEntry = true }
            }
            .confirmationDialog("Scan Receipt", isPresented: $isShowingReceiptSourceDialog) {
                Button("Camera") { self.isScanningReceipt = true; self.isShowingCamera = true }
                Button("Photo Library") { self.isScanningReceipt = true; self.isShowingPhotoPicker = true }
            }
            // 🔥 АЛЕРТ ОЧИСТКИ 🔥
            .alert("Очистить список?", isPresented: $isShowingClearAlert) {
                Button("Удалить всё", role: .destructive) { clearShoppingList() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Вы уверены, что хотите полностью очистить список покупок?")
            }
            .alert("Add Item", isPresented: $isShowingTextEntry) {
                TextField("E.g. 150g Greek Yogurt", text: $manualText)
                Button("Analyze") {
                    guard !manualText.isEmpty else { return }
                    let item = ProcessingItem(images: [UIImage(systemName: "brain")!], textPrompt: manualText, targetTab: currentTab)
                    withAnimation { processingItems.append(item) }
                    onProcessQueue([item])
                    manualText = ""
                }
                Button("Cancel", role: .cancel) { manualText = "" }
            }
            .alert("AI Error", isPresented: Binding(
                get: { aiErrorMessage != nil },
                set: { if !$0 { aiErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(aiErrorMessage ?? "The AI request failed.")
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
                                    let safeName = fav.name.hasPrefix("❄️") ? fav.name : "❄️ " + fav.name
                                    modelContext.insert(FoodEntry(image: fav.uiImage ?? UIImage(), name: safeName, calories: fav.calories, protein: fav.protein, ingredients: fav.ingredients, date: selectedDate)); dismiss()
                                }
                                else { withAnimation(.spring()) { selectedFavoriteForEdit = fav } }
                            }
                            .contextMenu {
                                Button { moveFavToMeals(fav) } label: { Label("Move to Meals", systemImage: "fork.knife") }
                                Button(role: .destructive) { modelContext.delete(fav) } label: { Label("Delete", systemImage: "trash") }
                            }
                            .swipeToDelete { withAnimation { modelContext.delete(fav) } }
                    }
                }.padding()
            }.blur(radius: selectedFavoriteForEdit != nil ? 15 : 0)
        }
        
        if !isSelectionMode {
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    Button(action: cookSomething) {
                        if isGeneratingRecipe { ProgressView().tint(.neonCyan).frame(width: 55, height: 55) }
                        else { Image(systemName: "sparkles").font(.title2).foregroundColor(.neonCyan).frame(width: 55, height: 55).background(Circle().fill(Color.black)).overlay(Circle().stroke(Color.neonCyan.opacity(0.5), lineWidth: 1)).shadow(color: .neonCyan.opacity(0.5), radius: 8) }
                    }.disabled(isGeneratingRecipe)
                    Text("Suggest").font(.caption2).foregroundColor(.gray)
                }.frame(width: 70)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: { isShowingSourceDialog = true }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 65)).foregroundColor(.neonCyan).background(Circle().fill(Color.black)).shadow(color: .neonCyan.opacity(0.5), radius: 10)
                    }
                    Text("Add Item").font(.caption2).foregroundColor(.gray)
                }.offset(y: -5)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: { isShowingReceiptSourceDialog = true }) {
                        Image(systemName: "doc.text.viewfinder").font(.title2).foregroundColor(.white).frame(width: 55, height: 55).background(Circle().fill(Color.black)).overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1)).shadow(color: .gray.opacity(0.5), radius: 8)
                    }
                    Text("Scan Receipt").font(.caption2).foregroundColor(.gray)
                }.frame(width: 70)
            }.padding(.horizontal, 30).padding(.bottom, 15).padding(.top, 5)
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
                        HStack(spacing: 15) {
                            if let img = r.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(r.name).font(.subheadline).bold().foregroundColor(.white).multilineTextAlignment(.leading)
                                Text("\(Int(r.calories)) kcal • \(Int(r.protein))g P").font(.caption).foregroundColor(.orange)
                            }
                            Spacer()
                            Image(systemName: r.instructions.isEmpty ? "pencil" : "doc.text").foregroundColor(.gray).font(.subheadline)
                        }
                        .padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15))).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        .onTapGesture {
                            if isSelectionMode {
                                let safeName = r.name.hasPrefix("👨‍🍳") ? r.name : "👨‍🍳 " + r.name
                                let ing = r.ingredients.isEmpty ? "Meal;1 portion;\(r.calories);\(r.protein)" : r.ingredients
                                modelContext.insert(FoodEntry(image: r.uiImage ?? UIImage(systemName: "fork.knife")!, name: safeName, calories: r.calories, protein: r.protein, ingredients: ing, date: selectedDate)); dismiss()
                            } else {
                                if !r.instructions.isEmpty { selectedRecipeToShow = r.asResult }
                                else { withAnimation(.spring()) { selectedMealForEdit = r } }
                            }
                        }
                        .contextMenu {
                            Button { moveMealToFav(r) } label: { Label("Move to Fridge", systemImage: "snowflake") }
                            if !r.instructions.isEmpty { Button { selectedRecipeToShow = r.asResult } label: { Label("View Recipe", systemImage: "doc.text") } }
                            Button { withAnimation(.spring()) { selectedMealForEdit = r } } label: { Label("Edit in Chat", systemImage: "pencil") }
                            Button(role: .destructive) { modelContext.delete(r) } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeToDelete { withAnimation { modelContext.delete(r) } }
                    }
                }.padding()
            }.blur(radius: selectedMealForEdit != nil ? 15 : 0)
        }
        
        if !isSelectionMode {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Button(action: { isShowingSourceDialog = true }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 65)).foregroundColor(.orange).background(Circle().fill(Color.black)).shadow(color: .orange.opacity(0.5), radius: 10)
                    }
                    Text("Add Meal").font(.caption2).foregroundColor(.gray)
                }
                Spacer()
            }.padding(.bottom, 15).padding(.top, 5)
        }
    }

    @ViewBuilder
    private var shoppingTab: some View {
        VStack {
            // 🔥 КНОПКА ОЧИСТИТЬ 🔥
            HStack {
                Text("Список покупок").font(.headline).foregroundColor(.white)
                Spacer()
                if !shoppingItems.isEmpty {
                    Button(action: { isShowingClearAlert = true }) {
                        Text("Очистить")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

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
                        .swipeToDelete { withAnimation { modelContext.delete(item) } }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var editOverlay: some View {
        if let fav = selectedFavoriteForEdit {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedFavoriteForEdit = nil } }
            FavoriteChatEditView(
                favorite: fav,
                onDelete: { modelContext.delete(fav); withAnimation { selectedFavoriteForEdit = nil } },
                onDone: { withAnimation { selectedFavoriteForEdit = nil } },
                onMove: { moveFavToMeals(fav); withAnimation { selectedFavoriteForEdit = nil } }
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        if let meal = selectedMealForEdit {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedMealForEdit = nil } }
            MealChatEditView(
                recipe: meal,
                onDelete: { modelContext.delete(meal); withAnimation { selectedMealForEdit = nil } },
                onDone: { withAnimation { selectedMealForEdit = nil } },
                onMove: { moveMealToFav(meal); withAnimation { selectedMealForEdit = nil } }
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // 🔥 ЛОГИКА ОЧИСТКИ 🔥
    func clearShoppingList() {
        for item in shoppingItems {
            modelContext.delete(item)
        }
    }

    // ОСТАЛЬНЫЕ МЕТОДЫ (Rows, Helpers)...
    func favoriteRow(_ fav: FavoriteFood) -> some View { HStack(spacing: 15) { if let img = fav.uiImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)) }; VStack(alignment: .leading) { Text(fav.name).font(.subheadline).bold().foregroundColor(.white); Text("\(Int(fav.calories)) kcal • \(Int(fav.protein))g protein").font(.caption).foregroundColor(.neonCyan) }; Spacer(); if isSelectionMode { Image(systemName: "plus.circle.fill").foregroundColor(.neonCyan).font(.title3) } else { Image(systemName: "pencil").foregroundColor(.gray).font(.subheadline) } }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.neonCyan.opacity(0.3), lineWidth: 1))) }
    func loadingRow(item: ProcessingItem) -> some View { let color: Color = item.targetTab == 1 ? .orange : .neonCyan; return HStack(spacing: 15) { if let firstImg = item.images.first { Image(uiImage: firstImg).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(Color.black.opacity(0.2).cornerRadius(10)) }; VStack(alignment: .leading, spacing: 6) { Text(item.textPrompt != nil ? "Reading text..." : "Analyzing...").font(.subheadline).bold().foregroundColor(.white); RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 120, height: 10) }; Spacer(); ProgressView().tint(color) }.padding().background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(color.opacity(0.5), lineWidth: 1)).shadow(color: color.opacity(0.2), radius: 5)) }
    func moveFavToMeals(_ fav: FavoriteFood) { let newMeal = SavedRecipe(image: fav.uiImage, name: fav.name, instructions: "", calories: fav.calories, protein: fav.protein, ingredients: fav.ingredients); modelContext.insert(newMeal); modelContext.delete(fav) }
    func moveMealToFav(_ r: SavedRecipe) { let newFav = FavoriteFood(image: r.uiImage, name: r.name, calories: r.calories, protein: r.protein, ingredients: r.ingredients.isEmpty ? "Meal;1 portion;\(r.calories);\(r.protein)" : r.ingredients); modelContext.insert(newFav); modelContext.delete(r) }
    func processReceipt(_ img: UIImage) { let item = ProcessingItem(images: [img]); withAnimation { processingItems.append(item) }; GeminiService.shared.scanGroceries(images: [img]) { results, error in DispatchQueue.main.async { if let index = processingItems.firstIndex(where: { $0.id == item.id }) { processingItems.remove(at: index) }; if let items = results { for res in items { modelContext.insert(FavoriteFood(image: UIImage(systemName: "cart"), name: res.food_name, calories: res.calories, protein: res.protein, ingredients: res.ingredients_breakdown)) } } else { aiErrorMessage = error ?? "Receipt scan failed. Please try again." } } } }
    func cookSomething() { isGeneratingRecipe = true; let items = favorites.map { "\($0.name)" }; GeminiService.shared.generateRecipes(from: items) { res, error in isGeneratingRecipe = false; if let res = res, !res.isEmpty { suggestedRecipes = res; showRecipeSuggestions = true } else { aiErrorMessage = error ?? "Recipe generation failed. Please try again." } } }
}
// MARK: - 🔥 ВЫБОР ИЗ СГЕНЕРИРОВАННЫХ РЕЦЕПТОВ 🔥
struct RecipeSuggestionsView: View {
    var recipes: [RecipeResult]; var selectedDate: Date; @Environment(\.dismiss) var dismiss; @State private var selectedRecipe: RecipeResult?
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
                                    HStack { Text("\(Int(r.estimated_calories)) kcal").foregroundColor(.neonGreen); Text("•").foregroundColor(.gray); Text("\(Int(r.estimated_protein))g protein").foregroundColor(.neonCyan) }.font(.subheadline).bold()
                                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.4))).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.foregroundColor(.gray) } }
            .sheet(item: $selectedRecipe) { rec in RecipeSheet(recipe: rec, isPreSaved: false, selectedDate: selectedDate) }
        }.preferredColorScheme(.dark)
    }
}

// MARK: - 🔥 ЭКРАН ПОКАЗА РЕЦЕПТА 🔥
struct RecipeSheet: View {
    var recipe: RecipeResult; var isPreSaved: Bool; var selectedDate: Date
    @Environment(\.dismiss) var dismiss; @Environment(\.modelContext) private var modelContext; @State private var isSaved = false; @State private var isAddedToDiary = false
    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(recipe.recipe_name).font(.largeTitle).bold().foregroundColor(.white).lineLimit(nil).fixedSize(horizontal: false, vertical: true).padding(.top)
                        HStack { VStack(spacing: 5) { Text("CALORIES").font(.caption).foregroundColor(.gray); Text("\(Int(recipe.estimated_calories))").font(.title2).bold().foregroundColor(.neonGreen) }.frame(maxWidth: .infinity); Divider().background(Color.gray).frame(height: 30); VStack(spacing: 5) { Text("PROTEIN").font(.caption).foregroundColor(.gray); Text("\(Int(recipe.estimated_protein))g").font(.title2).bold().foregroundColor(.neonCyan) }.frame(maxWidth: .infinity) }.padding().background(Color.black.opacity(0.3)).cornerRadius(15)
                        Text(LocalizedStringKey(recipe.cooking_instructions)).foregroundColor(.gray).lineSpacing(5)
                        Button(action: addToDiary) { HStack { Image(systemName: isAddedToDiary ? "checkmark" : "plus.circle.fill"); Text(isAddedToDiary ? "Added to Diary" : "Add to Today's Diary 🍽️").bold() }.frame(maxWidth: .infinity).padding().background(isAddedToDiary ? Color.neonGreen.opacity(0.8) : Color.orange).foregroundColor(.white).cornerRadius(15).padding(.top, 20) }.disabled(isAddedToDiary)
                        Spacer()
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.gray) }
                if !isPreSaved { ToolbarItem(placement: .navigationBarTrailing) { Button(isSaved ? "Saved ✅" : "Save Meal") { if !isSaved { modelContext.insert(SavedRecipe(name: recipe.recipe_name, instructions: recipe.cooking_instructions, calories: recipe.estimated_calories, protein: recipe.estimated_protein, ingredients: "")); withAnimation { isSaved = true } } }.foregroundColor(isSaved ? .neonGreen : .orange).bold() } }
            }
        }.preferredColorScheme(.dark)
    }
    func addToDiary() {
        let safeName = recipe.recipe_name.hasPrefix("👨‍🍳") ? recipe.recipe_name : "👨‍🍳 " + recipe.recipe_name
        modelContext.insert(FoodEntry(image: UIImage(systemName: "fork.knife")!, name: safeName, calories: recipe.estimated_calories, protein: recipe.estimated_protein, ingredients: "Recipe;1 portion;\(recipe.estimated_calories);\(recipe.estimated_protein)", date: selectedDate))
        withAnimation { isAddedToDiary = true }
    }
}

// MARK: - 🔥 ЧАТ ДЛЯ ХОЛОДИЛЬНИКА 🔥
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
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }
                }
            }.padding().background(Color.darkGrey)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, accentColor: .gray)
                        ForEach(messages) { msg in VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 10) { HStack { if msg.isUser { Spacer() }; VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 8) { if let img = msg.attachedImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 10)) }; if !msg.text.isEmpty { Text(msg.text) } }.font(.subheadline).padding(12).background(msg.isUser ? Color.neonCyan.opacity(0.3) : Color.gray.opacity(0.2)).foregroundColor(.white).cornerRadius(15); if !msg.isUser { Spacer() } }; if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, accentColor: .neonCyan).padding(.trailing, 20) } }.id(msg.id) }
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
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: favorite.name, emoji: nil, calories: favorite.calories, protein: favorite.protein, ingredients_breakdown: favorite.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text) { result, error in isWaiting = false; if let res = result { favorite.name = res.food_name; favorite.calories = res.calories; favorite.protein = res.protein; favorite.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein)) } else { messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false)) } } }
}

// MARK: - 🔥 ЧАТ ДЛЯ MEALS 🔥
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
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }
                }
            }.padding().background(Color.darkGrey)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        IngredientBreakdownCard(title: "INITIAL CALCULATION", ingredients: originalIngredients, calories: originalCalories, protein: originalProtein, accentColor: .gray)
                        ForEach(messages) { msg in VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 10) { HStack { if msg.isUser { Spacer() }; VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 8) { if let img = msg.attachedImage { Image(uiImage: img).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 10)) }; if !msg.text.isEmpty { Text(msg.text) } }.font(.subheadline).padding(12).background(msg.isUser ? Color.orange.opacity(0.3) : Color.gray.opacity(0.2)).foregroundColor(.white).cornerRadius(15); if !msg.isUser { Spacer() } }; if let ing = msg.ingredients, let cal = msg.calories, let prot = msg.protein { IngredientBreakdownCard(title: "UPDATED CALCULATION", ingredients: ing, calories: cal, protein: prot, accentColor: .orange).padding(.trailing, 20) } }.id(msg.id) }
                        if isWaiting { HStack { TypingIndicatorView(color: .orange).padding(14).background(Color.gray.opacity(0.2)).cornerRadius(15); Spacer() }.id("TypingIndicator") }
                    }.padding()
                }.onChange(of: messages.count) { withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }.onChange(of: isWaiting) { _, waiting in if waiting { withAnimation { proxy.scrollTo("TypingIndicator", anchor: .bottom) } } }
            }
            VStack(spacing: 0) {
                if let img = attachedImage { HStack { ZStack(alignment: .topTrailing) { Image(uiImage: img).resizable().scaledToFill().frame(width: 60, height: 60).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange, lineWidth: 2)); Button(action: { withAnimation { attachedImage = nil } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Circle().fill(Color.black)) }.offset(x: 8, y: -8) }; Spacer() }.padding(.horizontal).padding(.top, 10) }
                HStack(spacing: 12) { Button(action: { isShowingAttachmentDialog = true }) { Image(systemName: "paperclip").font(.title3).foregroundColor(.orange) }; TextField("Ask AI or attach label...", text: $userMessage).padding(10).background(Color.black.opacity(0.4)).cornerRadius(20).foregroundColor(.white); Button(action: sendMessage) { Image(systemName: "paperplane.fill").foregroundColor((userMessage.isEmpty && attachedImage == nil) || isWaiting ? .gray : .orange) }.disabled((userMessage.isEmpty && attachedImage == nil) || isWaiting) }.padding().background(Color(red: 20/255, green: 20/255, blue: 25/255))
            }
        }.background(Color.darkGrey).cornerRadius(25).overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.2), lineWidth: 1)).padding(.horizontal, 15).frame(maxHeight: 680)
        .onAppear { originalIngredients = recipe.ingredients; originalCalories = recipe.calories; originalProtein = recipe.protein; if messages.isEmpty { messages.append(ChatMessage(text: "Review the initial table above. Need any adjustments?", isUser: false)) } }
        .confirmationDialog("Attach photo", isPresented: $isShowingAttachmentDialog) { Button("Camera") { self.attachmentSource = .camera; self.isShowingAttachmentPicker = true }; Button("Library") { self.attachmentSource = .photoLibrary; self.isShowingAttachmentPicker = true } }
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
    }
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: recipe.name, emoji: nil, calories: recipe.calories, protein: recipe.protein, ingredients_breakdown: recipe.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text) { result, error in isWaiting = false; if let res = result { recipe.name = res.food_name; recipe.calories = res.calories; recipe.protein = res.protein; recipe.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein)) } else { messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false)) } } }
}
