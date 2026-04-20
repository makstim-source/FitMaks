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
                myFoodBackground
                
                VStack(spacing: 0) {
                    if !isSelectionMode {
                        libraryHeader
                        foodTabSwitcher
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
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    // MARK: - ПОДВЬЮХИ ДЛЯ ВКЛАДОК
    private var myFoodBackground: some View {
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
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.neonCyan.opacity(0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 52)
                .offset(x: -110, y: -80)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.orange.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 58)
                .offset(x: 100, y: 90)
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOOD LIBRARY")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.appMuted)
                        .tracking(1)

                    Text("Build meals faster.")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.appText)
                }

                Spacer()

                HStack(spacing: 7) {
                    libraryCount(title: "Fridge", value: favorites.count, color: .neonCyan)
                    libraryCount(title: "Meals", value: savedRecipes.count, color: .orange)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var foodTabSwitcher: some View {
        HStack(spacing: 8) {
            tabButton(title: "Fridge", emoji: "❄️", index: 0, color: .neonCyan)
            tabButton(title: "Meals", emoji: "🍲", index: 1, color: .orange)
            tabButton(title: "Shopping", emoji: "🛒", index: 2, color: .neonGreen)
        }
        .padding(6)
        .background(Capsule().fill(Color.appElevated))
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private func tabButton(title: String, emoji: String, index: Int, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                currentTab = index
            }
        } label: {
            HStack(spacing: 5) {
                Text(emoji)
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundColor(currentTab == index ? .appAccentText : .appMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(currentTab == index ? color : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private func libraryCount(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 17, weight: .black))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.gray)
        }
        .frame(width: 54, height: 48)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.14), lineWidth: 1))
    }

    @ViewBuilder
    private var fridgeTab: some View {
        if favorites.isEmpty && processingItems.isEmpty {
            libraryEmptyState(
                systemName: "snowflake",
                title: "Fridge is empty",
                subtitle: "Scan groceries, labels, or type ingredients to build your food base.",
                color: .neonCyan
            )
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
            HStack(spacing: 8) {
                foodActionButton(title: "Ideas", systemName: "sparkles", color: .neonCyan, isLoading: isGeneratingRecipe, action: cookSomething)
                    .disabled(isGeneratingRecipe)
                foodActionButton(title: "Add", systemName: "plus", color: .neonCyan) { isShowingSourceDialog = true }
                foodActionButton(title: "Scan", systemName: "doc.text.viewfinder", color: .white) { isShowingReceiptSourceDialog = true }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var mealsTab: some View {
        if savedRecipes.isEmpty && processingItems.isEmpty {
            libraryEmptyState(
                systemName: "fork.knife",
                title: "No saved meals",
                subtitle: "Save dishes you repeat often and add them to diary in one tap.",
                color: .orange
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(processingItems) { item in loadingRow(item: item) }
                    ForEach(savedRecipes.reversed()) { r in
                        mealRow(r)
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
                foodActionButton(title: "Add Meal", systemName: "plus", color: .orange) { isShowingSourceDialog = true }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
            .padding(.top, 4)
        }
    }

    private func libraryEmptyState(systemName: String, title: String, subtitle: String, color: Color) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.13))
                        .frame(width: 92, height: 92)

                    Image(systemName: systemName)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(color.opacity(0.85))
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.045))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(color.opacity(0.14), lineWidth: 1))
            )
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    private func foodActionButton(title: String, systemName: String, color: Color, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)

                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: systemName)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.black)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.leading, 5)
            .padding(.trailing, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.34))
                    .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func mealRow(_ recipe: SavedRecipe) -> some View {
        HStack(spacing: 13) {
            if let image = recipe.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.orange.opacity(0.20), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(Color.orange.opacity(0.13))
                    Image(systemName: "fork.knife")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                }
                .frame(width: 58, height: 58)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label("\(Int(recipe.calories)) kcal", systemImage: "flame.fill")
                    Label("\(Int(recipe.protein))g", systemImage: "drop.fill")
                }
                .font(.caption.bold())
                .foregroundColor(.orange)
            }

            Spacer()

            Image(systemName: recipe.instructions.isEmpty ? "pencil" : "doc.text.fill")
                .font(.caption.bold())
                .foregroundColor(.gray)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.orange.opacity(0.14), lineWidth: 1))
        )
    }

    @ViewBuilder
    private var shoppingTab: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHOPPING LIST")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.gray)
                        .tracking(1)

                    Text("\(shoppingItems.filter { !$0.isCompleted }.count) open items")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                }

                Spacer()

                if !shoppingItems.isEmpty {
                    Button(action: { isShowingClearAlert = true }) {
                        Text("Clear")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            HStack(spacing: 10) {
                TextField("Add item...", text: $newShopItem)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.black.opacity(0.34)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .foregroundColor(.white)

                Button(action: {
                    guard !newShopItem.isEmpty else { return }
                    modelContext.insert(ShoppingItem(name: newShopItem))
                    newShopItem = ""
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.black)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.neonGreen))
                        .shadow(color: Color.neonGreen.opacity(0.35), radius: 10)
                }
            }
            .padding(.horizontal, 18)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(shoppingItems.sorted(by: { !$0.isCompleted && $1.isCompleted })) { item in
                        HStack {
                            Button(action: { withAnimation { item.isCompleted.toggle() } }) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .gray : .neonCyan)
                                    .font(.title2)
                            }

                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(item.isCompleted ? .gray : .white)
                                .strikethrough(item.isCompleted)

                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(item.isCompleted ? Color.white.opacity(0.035) : Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 1))
                        )
                        .swipeToDelete { withAnimation { modelContext.delete(item) } }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
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
    func favoriteRow(_ fav: FavoriteFood) -> some View {
        HStack(spacing: 13) {
            if let image = fav.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.neonCyan.opacity(0.20), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(Color.neonCyan.opacity(0.13))
                    Image(systemName: "snowflake")
                        .font(.title3.bold())
                        .foregroundColor(.neonCyan)
                }
                .frame(width: 58, height: 58)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(fav.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(Int(fav.calories)) kcal", systemImage: "flame.fill")
                    Label("\(Int(fav.protein))g", systemImage: "drop.fill")
                }
                .font(.caption.bold())
                .foregroundColor(.neonCyan)
            }

            Spacer()

            Image(systemName: isSelectionMode ? "plus.circle.fill" : "pencil")
                .font(.caption.bold())
                .foregroundColor(isSelectionMode ? .neonCyan : .gray)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.neonCyan.opacity(0.14), lineWidth: 1))
        )
    }

    func loadingRow(item: ProcessingItem) -> some View {
        let color: Color = item.targetTab == 1 ? .orange : .neonCyan

        return HStack(spacing: 13) {
            if let firstImage = item.images.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(Color.black.opacity(0.18).clipShape(RoundedRectangle(cornerRadius: 16)))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.textPrompt != nil ? "Reading text..." : "Analyzing...")
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

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
                LinearGradient(colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 15) {
                        Text("Chef's Suggestions").font(.title2).bold().foregroundColor(.appText).padding(.top)
                        ForEach(recipes) { r in
                            Button(action: { selectedRecipe = r }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(r.recipe_name).font(.headline).foregroundColor(.appText).multilineTextAlignment(.leading)
                                    HStack { Text("\(Int(r.estimated_calories)) kcal").foregroundColor(.neonGreen); Text("•").foregroundColor(.appMuted); Text("\(Int(r.estimated_protein))g protein").foregroundColor(.neonCyan) }.font(.subheadline).bold()
                                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.4))).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                            }
                        }
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.foregroundColor(.appMuted) } }
            .sheet(item: $selectedRecipe) { rec in RecipeSheet(recipe: rec, isPreSaved: false, selectedDate: selectedDate) }
        }.preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }
}

// MARK: - 🔥 ЭКРАН ПОКАЗА РЕЦЕПТА 🔥
struct RecipeSheet: View {
    var recipe: RecipeResult; var isPreSaved: Bool; var selectedDate: Date
    @Environment(\.dismiss) var dismiss; @Environment(\.modelContext) private var modelContext; @State private var isSaved = false; @State private var isAddedToDiary = false
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(recipe.recipe_name).font(.largeTitle).bold().foregroundColor(.appText).lineLimit(nil).fixedSize(horizontal: false, vertical: true).padding(.top)
                        HStack { VStack(spacing: 5) { Text("CALORIES").font(.caption).foregroundColor(.appMuted); Text("\(Int(recipe.estimated_calories))").font(.title2).bold().foregroundColor(.neonGreen) }.frame(maxWidth: .infinity); Divider().background(Color.appBorder).frame(height: 30); VStack(spacing: 5) { Text("PROTEIN").font(.caption).foregroundColor(.appMuted); Text("\(Int(recipe.estimated_protein))g").font(.title2).bold().foregroundColor(.neonCyan) }.frame(maxWidth: .infinity) }.padding().background(Color.appElevated).cornerRadius(15)
                        Text(LocalizedStringKey(recipe.cooking_instructions)).foregroundColor(.appMuted).lineSpacing(5)
                        Button(action: addToDiary) { HStack { Image(systemName: isAddedToDiary ? "checkmark" : "plus.circle.fill"); Text(isAddedToDiary ? "Added to Diary" : "Add to Today's Diary 🍽️").bold() }.frame(maxWidth: .infinity).padding().background(isAddedToDiary ? Color.neonGreen.opacity(0.8) : Color.fitOrange).foregroundColor(.appAccentText).cornerRadius(15).padding(.top, 20) }.disabled(isAddedToDiary)
                        Spacer()
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.appMuted) }
                if !isPreSaved { ToolbarItem(placement: .navigationBarTrailing) { Button(isSaved ? "Saved ✅" : "Save Meal") { if !isSaved { modelContext.insert(SavedRecipe(name: recipe.recipe_name, instructions: recipe.cooking_instructions, calories: recipe.estimated_calories, protein: recipe.estimated_protein, ingredients: "")); withAnimation { isSaved = true } } }.foregroundColor(isSaved ? .neonGreen : .orange).bold() } }
            }
        }.preferredColorScheme(AppTheme.current.palette.preferredScheme)
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
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
    }
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: favorite.name, emoji: nil, calories: favorite.calories, protein: favorite.protein, ingredients_breakdown: favorite.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text) { result, error in isWaiting = false; if let res = result { favorite.name = res.food_name; favorite.calories = res.calories; favorite.protein = res.protein; favorite.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true)) } else { messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true)) } } }
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
        .fullScreenCover(isPresented: $isShowingAttachmentPicker) { ImagePicker(selectedImage: Binding(get: { self.attachedImage }, set: { if let img = $0 { withAnimation { self.attachedImage = img } } }), sourceType: attachmentSource) }
    }
    
    func sendMessage() { let text = userMessage; let imageToSend = attachedImage; messages.append(ChatMessage(text: text, isUser: true, attachedImage: imageToSend)); userMessage = ""; withAnimation { attachedImage = nil }; isWaiting = true; let current = FoodResult(food_name: recipe.name, emoji: nil, calories: recipe.calories, protein: recipe.protein, ingredients_breakdown: recipe.ingredients, ai_response_text: ""); GeminiService.shared.refineAnalysis(image: imageToSend, currentData: current, userComment: text) { result, error in isWaiting = false; if let res = result { recipe.name = res.food_name; recipe.calories = res.calories; recipe.protein = res.protein; recipe.ingredients = res.ingredients_breakdown; messages.append(ChatMessage(text: res.ai_response_text.isEmpty ? "Updated!" : res.ai_response_text, isUser: false, ingredients: res.ingredients_breakdown, calories: res.calories, protein: res.protein, shouldTypewrite: true)) } else { messages.append(ChatMessage(text: error ?? "AI request failed. Please try again.", isUser: false, shouldTypewrite: true)) } } }
}
