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
    var onScanReceiptQueue: ([ProcessingItem]) -> Void
    
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

    private var newestFavorites: [FavoriteFood] {
        favorites.enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.createdAt, rhs.element.createdAt) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.offset > rhs.offset
                }
            }
            .map(\.element)
    }

    private var newestSavedRecipes: [SavedRecipe] {
        savedRecipes.sorted { $0.dateSaved > $1.dateSaved }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch currentTab {
        case 0:
            fridgeTab
        case 1:
            mealsTab
        default:
            shoppingTab
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                myFoodBackground
                
                VStack(spacing: 0) {
                    if !isSelectionMode {
                        libraryHeader
                        foodTabSwitcher
                    }

                    selectedTabContent
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
                    let preparedImage = img.preparedForAIIntake()
                    if isScanningReceipt { queueReceiptScan(images: [preparedImage]) } else { let item = ProcessingItem(images: [preparedImage], targetTab: currentTab); processingItems.append(item); onProcessQueue([item]) }
                    selectedCameraImage = nil; isScanningReceipt = false
                }
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var loadedImages: [UIImage] = []
                    for item in newItems { if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { loadedImages.append(img.preparedForAIIntake()) } }
                    await MainActor.run {
                        selectedPhotoItems.removeAll()
                        if !loadedImages.isEmpty {
                            if isScanningReceipt { queueReceiptScan(images: loadedImages) } else { let newItem = ProcessingItem(images: loadedImages, targetTab: currentTab); withAnimation { processingItems.append(newItem) }; onProcessQueue([newItem]) }
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
        if favorites.isEmpty && processingItems(for: 0).isEmpty {
            libraryEmptyState(
                systemName: "snowflake",
                title: "Fridge is empty",
                subtitle: "Scan groceries, labels, or type ingredients to build your food base.",
                color: .neonCyan
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(processingItems(for: 0)) { item in loadingRow(item: item) }
                    ForEach(newestFavorites) { fav in
                        favoriteRow(fav)
                            .contextMenu {
                                Button { addFavoriteToDiary(fav); dismiss() } label: { Label("Add to Diary", systemImage: "plus.circle") }
                                Button { withAnimation(.spring()) { selectedFavoriteForEdit = fav } } label: { Label("Edit in Chat", systemImage: "pencil") }
                                Button { moveFavToMeals(fav) } label: { Label("Move to Meals", systemImage: "fork.knife") }
                                Button(role: .destructive) { deleteFavorite(fav) } label: { Label("Delete", systemImage: "trash") }
                            }
                            .swipeToDelete { withAnimation { deleteFavorite(fav) } }
                    }
                }.padding()
            }.blur(radius: selectedFavoriteForEdit != nil ? 15 : 0)
        }
        
        if !isSelectionMode {
            HStack(spacing: 8) {
                foodActionButton(title: "Ideas", systemName: "sparkles", color: .neonCyan, isLoading: isGeneratingRecipe, action: cookSomething)
                    .disabled(isGeneratingRecipe)
                foodActionButton(title: "Add", systemName: "plus", color: .neonCyan) { isShowingSourceDialog = true }
                foodActionButton(title: "Receipt", systemName: "doc.text.viewfinder", color: .white) { isShowingReceiptSourceDialog = true }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var mealsTab: some View {
        if savedRecipes.isEmpty && processingItems(for: 1).isEmpty {
            libraryEmptyState(
                systemName: "fork.knife",
                title: "No saved meals",
                subtitle: "Save dishes you repeat often and add them to diary in one tap.",
                color: .orange
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(processingItems(for: 1)) { item in loadingRow(item: item) }
                    ForEach(newestSavedRecipes) { r in
                        mealRow(r)
                        .contextMenu {
                            Button { addMealToDiary(r); dismiss() } label: { Label("Add to Diary", systemImage: "plus.circle") }
                            Button { moveMealToFav(r) } label: { Label("Move to Fridge", systemImage: "snowflake") }
                            if !r.instructions.isEmpty { Button { selectedRecipeToShow = r.asResult } label: { Label("View Recipe", systemImage: "doc.text") } }
                            Button { withAnimation(.spring()) { selectedMealForEdit = r } } label: { Label("Edit in Chat", systemImage: "pencil") }
                            Button(role: .destructive) { deleteMeal(r) } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeToDelete { withAnimation { deleteMeal(r) } }
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

            HStack(spacing: 8) {
                rowIconButton(systemName: "pencil", color: .white.opacity(0.82)) {
                    withAnimation(.spring()) { selectedMealForEdit = recipe }
                }

                rowIconButton(systemName: "plus", color: .orange) {
                    addMealToDiary(recipe)
                    dismiss()
                }
            }
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
                onDelete: { deleteFavorite(fav); withAnimation { selectedFavoriteForEdit = nil } },
                onDone: { withAnimation { selectedFavoriteForEdit = nil } },
                onMove: { moveFavToMeals(fav); withAnimation { selectedFavoriteForEdit = nil } }
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        if let meal = selectedMealForEdit {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedMealForEdit = nil } }
            MealChatEditView(
                recipe: meal,
                onDelete: { deleteMeal(meal); withAnimation { selectedMealForEdit = nil } },
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

            HStack(spacing: 8) {
                rowIconButton(systemName: "pencil", color: .white.opacity(0.82)) {
                    withAnimation(.spring()) { selectedFavoriteForEdit = fav }
                }

                rowIconButton(systemName: "plus", color: .neonCyan) {
                    addFavoriteToDiary(fav)
                    dismiss()
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.neonCyan.opacity(0.14), lineWidth: 1))
        )
    }

    private func rowIconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Circle().stroke(color.opacity(0.22), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
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
                Text(item.statusTitle ?? (item.textPrompt != nil ? "Reading text..." : "Analyzing..."))
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

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

    private func processingItems(for tab: Int) -> [ProcessingItem] {
        processingItems
            .filter { $0.targetTab == tab }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func moveFavToMeals(_ fav: FavoriteFood) {
        let newMeal = SavedRecipe(
            image: fav.uiImage,
            name: fav.name,
            instructions: "",
            calories: fav.calories,
            protein: fav.protein,
            ingredients: fav.ingredients
        )

        modelContext.insert(newMeal)
        modelContext.delete(fav)
    }

    func moveMealToFav(_ recipe: SavedRecipe) {
        let ingredients = recipe.ingredients.isEmpty
            ? "Meal;1 portion;\(recipe.calories);\(recipe.protein)"
            : recipe.ingredients
        let newFavorite = FavoriteFood(
            image: recipe.uiImage,
            name: recipe.name,
            calories: recipe.calories,
            protein: recipe.protein,
            ingredients: ingredients
        )

        modelContext.insert(newFavorite)
        modelContext.delete(recipe)
    }

    func addFavoriteToDiary(_ fav: FavoriteFood) {
        let safeName = fav.name.hasPrefix("❄️") ? fav.name : "❄️ " + fav.name
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring()) {
            modelContext.insert(FoodEntry(
                image: fav.uiImage ?? UIImage(),
                name: safeName,
                calories: fav.calories,
                protein: fav.protein,
                ingredients: fav.ingredients,
                date: selectedDate
            ))
        }
    }

    func addMealToDiary(_ recipe: SavedRecipe) {
        let safeName = recipe.name.hasPrefix("👨‍🍳") ? recipe.name : "👨‍🍳 " + recipe.name
        let ingredients = recipe.ingredients.isEmpty
            ? "Meal;1 portion;\(recipe.calories);\(recipe.protein)"
            : recipe.ingredients

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring()) {
            modelContext.insert(FoodEntry(
                image: recipe.uiImage ?? UIImage(systemName: "fork.knife") ?? UIImage(),
                name: safeName,
                calories: recipe.calories,
                protein: recipe.protein,
                ingredients: ingredients,
                date: selectedDate
            ))
        }
    }

    func queueReceiptScan(images: [UIImage]) {
        let item = ProcessingItem(images: images, targetTab: 0)

        withAnimation {
            processingItems.append(item)
        }

        onScanReceiptQueue([item])
    }

    func cookSomething() {
        isGeneratingRecipe = true
        let items = favorites.map { $0.name }

        GeminiService.shared.generateRecipes(from: items) { result, error in
            isGeneratingRecipe = false

            guard let result, !result.isEmpty else {
                aiErrorMessage = error ?? "Recipe generation failed. Please try again."
                return
            }

            suggestedRecipes = result
            showRecipeSuggestions = true
        }
    }

    private func deleteFavorite(_ favorite: FavoriteFood) {
        GeminiService.shared.invalidateFoodImageCache(for: favorite.uiImage)
        modelContext.delete(favorite)
    }

    private func deleteMeal(_ recipe: SavedRecipe) {
        GeminiService.shared.invalidateFoodImageCache(for: recipe.uiImage)
        modelContext.delete(recipe)
    }
}
