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
    var initialBuildMode: Bool = false
    var selectedDate: Date
    @Binding var processingItems: [ProcessingItem]
    @Binding var pendingAIReview: AIResultReview?
    var onProcessQueue: ([ProcessingItem]) -> Void
    var onScanReceiptQueue: ([ProcessingItem]) -> Void
    var onConfirmReview: (AIResultReview, [AIReviewFoodItem]) -> Void
    var onRecalculateReview: (AIResultReview) -> Void
    
    @State private var isShowingSourceDialog = false
    @State private var isShowingReceiptSourceDialog = false
    @State private var isShowingCamera = false
    @State private var selectedCameraImage: UIImage?
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingTextEntry = false
    @State private var manualText = ""
    @State private var isShowingClearAlert = false
    
    @State private var selectedFavoriteForEdit: FavoriteFood?
    @State private var selectedMealForEdit: SavedRecipe?
    @State private var selectedFavoriteForAmount: FavoriteFood?
    
    @State private var currentTab = 0
    @State private var newShopItem = ""
    
    @State private var isGeneratingRecipe = false
    @State private var suggestedRecipes: [RecipeResult] = []
    @State private var showRecipeSuggestions = false
    @State private var selectedRecipeToShow: RecipeResult?
    @State private var isScanningReceipt = false
    @State private var aiErrorMessage: String?
    @State private var isBuildingMeal = false
    @State private var selectedForMeal: Set<UUID> = []
    @State private var isShowingMealBuilder = false
    @State private var searchText = ""
    @State private var selectedFridgeCategory: FridgeCategory? = nil
    @State private var selectedMealCategory: MealCategory? = nil

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

    private var filteredFavorites: [FavoriteFood] {
        var result = newestFavorites
        if let cat = selectedFridgeCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) || $0.ingredients.lowercased().contains(query) }
        }
        return result
    }

    private var filteredRecipes: [SavedRecipe] {
        var result = newestSavedRecipes
        if let cat = selectedMealCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) || $0.ingredients.lowercased().contains(query) }
        }
        return result
    }

    private var activeFridgeCategories: [FridgeCategory] {
        let used = Set(favorites.map { $0.category })
        return FridgeCategory.allCases.filter { used.contains($0) }
    }

    private var activeMealCategories: [MealCategory] {
        let used = Set(savedRecipes.map { $0.category })
        return MealCategory.allCases.filter { used.contains($0) }
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
            .navigationTitle(isBuildingMeal ? "Build Meal" : isSelectionMode ? (initialTab == 0 ? "Pick from Fridge" : "Pick from Meals") : "My Food 🍱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.appText) }
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
            .alert("Clear list?", isPresented: $isShowingClearAlert) {
                Button("Delete all", role: .destructive) { clearShoppingList() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to clear the entire shopping list?")
            }
            .alert("Add Item", isPresented: $isShowingTextEntry) {
                TextField("E.g. 150g Greek Yogurt", text: $manualText)
                Button("Analyze") {
                    guard !manualText.isEmpty else { return }
                    let item = ProcessingItem(images: [UIImage(systemName: "brain") ?? UIImage()], textPrompt: manualText, targetTab: currentTab)
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
                    if isScanningReceipt {
                        queueReceiptScan(images: [preparedImage])
                    } else {
                        let item = ProcessingItem(images: [preparedImage], targetTab: currentTab)
                        withAnimation(.spring()) { processingItems.append(item) }
                        onProcessQueue([item])
                    }
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
            .sheet(item: $selectedFavoriteForAmount) { favorite in
                FavoriteAmountSheet(
                    favorite: favorite,
                    selectedDate: selectedDate,
                    onAdd: { amount in
                        addFavoriteToDiary(favorite, amount: amount)
                        selectedFavoriteForAmount = nil
                        dismiss()
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $pendingAIReview) { review in
                AIResultReviewSheet(
                    review: review,
                    onCancel: { pendingAIReview = nil },
                    onRecalculate: { onRecalculateReview(review) },
                    onConfirm: { items in
                        onConfirmReview(review, items)
                        pendingAIReview = nil
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingMealBuilder) {
                MealBuilderSheet(
                    components: selectedBuildComponents,
                    onSave: saveBuildMeal
                )
            }
            .onAppear {
                if isSelectionMode { currentTab = initialTab }
                if initialBuildMode { isBuildingMeal = true; currentTab = 0 }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    // MARK: - Tab Subviews
    private var myFoodBackground: some View {
        let theme = AppTheme.current
        let neonCore = theme == .originalV2
        let glass = isIPhoneGlassTheme(theme)

        return LinearGradient(
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
                .fill((neonCore ? theme.palette.secondary : Color.neonCyan).opacity(glass ? 0.14 : (neonCore ? 0.18 : 0.12)))
                .frame(width: neonCore ? 280 : 230, height: neonCore ? 280 : 230)
                .blur(radius: neonCore ? 64 : 52)
                .offset(x: -110, y: -80)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill((neonCore ? theme.palette.action : Color.orange).opacity(glass ? 0.12 : (neonCore ? 0.16 : 0.10)))
                .frame(width: neonCore ? 320 : 260, height: neonCore ? 320 : 260)
                .blur(radius: neonCore ? 72 : 58)
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
                    libraryCount(title: "Meals", value: savedRecipes.count, color: .fitOrange)
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
            tabButton(title: "Meals", emoji: "🍲", index: 1, color: .fitOrange)
            tabButton(title: "Shopping", emoji: "🛒", index: 2, color: .fitPurple)
        }
        .padding(6)
        .background(Capsule().fill(themeChromeGradient()))
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private func tabButton(title: String, emoji: String, index: Int, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                currentTab = index
                searchText = ""
                selectedFridgeCategory = nil
                selectedMealCategory = nil
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
            .background(
                Capsule().fill(
                    currentTab == index
                        ? AnyShapeStyle(selectedTabGradient(for: color))
                        : AnyShapeStyle(Color.clear)
                )
            )
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
                .foregroundColor(.appMuted)
        }
        .frame(width: 54, height: 48)
        .background(RoundedRectangle(cornerRadius: 16).fill(themeCardGradient()))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(AppTheme.current == .originalV2 ? 0.24 : 0.14), lineWidth: 1))
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
            if !isBuildingMeal {
                foodSearchBar(color: .neonCyan)
                fridgeCategoryChips
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(processingItems(for: 0)) { item in loadingRow(item: item) }
                    ForEach(filteredFavorites) { fav in
                        if isBuildingMeal {
                            buildMealSelectableRow(fav)
                        } else {
                            favoriteRow(fav)
                                .contextMenu {
                                    Button { presentFavoriteAmountPicker(for: fav) } label: { Label("Add to Diary", systemImage: "plus.circle") }
                                    Button { withAnimation(.spring()) { selectedFavoriteForEdit = fav } } label: { Label("Edit in Chat", systemImage: "pencil") }
                                    Button { moveFavToMeals(fav) } label: { Label("Move to Meals", systemImage: "fork.knife") }
                                    Button(role: .destructive) { deleteFavorite(fav) } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeToDelete { withAnimation { deleteFavorite(fav) } }
                        }
                    }
                }.padding()
                if isBuildingMeal { Spacer().frame(height: 80) }
            }.blur(radius: selectedFavoriteForEdit != nil ? 15 : 0)
        }

        processingBanner(for: 0, color: .neonCyan)

        if isBuildingMeal {
            mealBuildBar
        } else if !isSelectionMode {
            HStack(spacing: 8) {
                foodActionButton(title: "Ideas", systemName: "sparkles", color: .neonCyan, isLoading: isGeneratingRecipe, action: cookSomething)
                    .disabled(isGeneratingRecipe)
                foodActionButton(title: "Add", systemName: "plus", color: .neonCyan) { isShowingSourceDialog = true }
                foodActionButton(title: "Receipt", systemName: "doc.text.viewfinder", color: .fitPurple) { isShowingReceiptSourceDialog = true }
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
                color: .fitOrange
            )
        } else {
            if !isBuildingMeal {
                foodSearchBar(color: .fitOrange)
                mealCategoryChips
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(processingItems(for: 1)) { item in loadingRow(item: item) }
                    ForEach(filteredRecipes) { r in
                        if isBuildingMeal {
                            buildMealSelectableMealRow(r)
                        } else {
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
                    }
                }.padding()
                if isBuildingMeal { Spacer().frame(height: 80) }
            }.blur(radius: selectedMealForEdit != nil ? 15 : 0)
        }

        processingBanner(for: 1, color: .orange)

        if isBuildingMeal {
            mealBuildBar
        } else if !isSelectionMode {
            HStack(spacing: 8) {
                foodActionButton(title: "Add Meal", systemName: "plus", color: .fitOrange) { isShowingSourceDialog = true }
                foodActionButton(title: "Build from Fridge", systemName: "square.stack.3d.up", color: .fitOrange) {
                    withAnimation(.spring()) { isBuildingMeal = true; currentTab = 0 }
                }
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
                        .foregroundColor(.appText)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.appSurface)
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
                            .foregroundColor(.appAccentText)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.leading, 5)
            .padding(.trailing, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(themeChromeGradient())
                    .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func mealRow(_ recipe: SavedRecipe) -> some View {
        HStack(spacing: 11) {
            if let image = recipe.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.fitOrange.opacity(0.20), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.fitOrange.opacity(0.13))
                    Image(systemName: "fork.knife")
                        .font(.title3.bold())
                        .foregroundColor(.fitOrange)
                }
                .frame(width: 54, height: 54)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    Label("\(Int(recipe.calories))", systemImage: "flame.fill")
                        .foregroundColor(.neonGreen)
                    Label("\(Int(recipe.protein))g", systemImage: "drop.fill")
                        .foregroundColor(.neonCyan)
                    Label("\(Int(recipe.carbs))g", systemImage: "leaf.fill")
                        .foregroundColor(.fitOrange)
                    Label("\(Int(recipe.fat))g", systemImage: "circle.inset.filled")
                        .foregroundColor(.yellow)
                }
                .font(.system(size: 10, weight: .heavy))
                .lineLimit(1)
                .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                rowIconButton(systemName: "pencil", color: .appText) {
                    withAnimation(.spring()) { selectedMealForEdit = recipe }
                }

                rowIconButton(systemName: "plus", color: .fitOrange) {
                    addMealToDiary(recipe)
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            myFoodRowBackground(accent: .fitOrange)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) { selectedMealForEdit = recipe }
        }
    }

    @ViewBuilder
    private var shoppingTab: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHOPPING LIST")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.appMuted)
                        .tracking(1)

                    Text("\(shoppingItems.filter { !$0.isCompleted }.count) open items")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.appText)
                }

                Spacer()

                if !shoppingItems.isEmpty {
                    Button(action: { isShowingClearAlert = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 9, weight: .black))

                            Text("Clear")
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundColor(.fitOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.fitOrange.opacity(isLightAppTheme() ? 0.13 : 0.16)))
                        .overlay(
                            Capsule()
                                .stroke(Color.fitOrange.opacity(0.42), lineWidth: 1)
                        )
                        .shadow(color: Color.fitOrange.opacity(isLightAppTheme() ? 0.06 : 0.18), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)

            HStack(spacing: 10) {
                TextField("Add item...", text: $newShopItem)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Capsule().fill(themeChromeGradient()))
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    .foregroundColor(.appText)

                Button(action: {
                    guard !newShopItem.isEmpty else { return }
                    modelContext.insert(ShoppingItem(name: newShopItem))
                    newShopItem = ""
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.appAccentText)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(themePrimaryButtonGradient()))
                        .shadow(color: themeShadowColor().opacity(0.35), radius: 10)
                }
            }
            .padding(.horizontal, 18)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(shoppingItems.sorted(by: { !$0.isCompleted && $1.isCompleted })) { item in
                        HStack {
                            Button(action: { withAnimation { item.isCompleted.toggle() } }) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .appMuted : .neonCyan)
                                    .font(.title2)
                            }

                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(item.isCompleted ? .appMuted : .appText)
                                .strikethrough(item.isCompleted)

                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(item.isCompleted ? Color.appSurface.opacity(0.5) : Color.appSurface)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
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
            Color.appScrim.edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedFavoriteForEdit = nil } }
            FavoriteChatEditView(
                favorite: fav,
                onDelete: { deleteFavorite(fav); withAnimation { selectedFavoriteForEdit = nil } },
                onDone: { withAnimation { selectedFavoriteForEdit = nil } },
                onMove: { moveFavToMeals(fav); withAnimation { selectedFavoriteForEdit = nil } }
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        if let meal = selectedMealForEdit {
            Color.appScrim.edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { selectedMealForEdit = nil } }
            MealChatEditView(
                recipe: meal,
                onDelete: { deleteMeal(meal); withAnimation { selectedMealForEdit = nil } },
                onDone: { withAnimation { selectedMealForEdit = nil } },
                onMove: { moveMealToFav(meal); withAnimation { selectedMealForEdit = nil } }
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // MARK: - Build Meal

    private func buildMealSelectableRow(_ fav: FavoriteFood) -> some View {
        let isSelected = selectedForMeal.contains(fav.id)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if isSelected { selectedForMeal.remove(fav.id) } else { selectedForMeal.insert(fav.id) }
            }
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color.appMuted.opacity(0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle().fill(Color.orange).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.appAccentText)
                    }
                }

                if let image = fav.uiImage {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color.neonCyan.opacity(0.13))
                        Image(systemName: "snowflake").font(.caption.bold()).foregroundColor(.neonCyan)
                    }.frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(fav.name)
                        .font(.subheadline).fontWeight(.heavy)
                        .foregroundColor(.appText).lineLimit(1)
                    HStack(spacing: 8) {
                        Label("\(Int(fav.calories)) kcal", systemImage: "flame.fill")
                        Label("\(Int(fav.protein))g", systemImage: "drop.fill")
                    }.font(.caption.bold()).foregroundColor(.neonCyan)
                }
                Spacer()
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.orange.opacity(0.10) : Color.appSurface)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.orange.opacity(0.3) : Color.neonCyan.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func buildMealSelectableMealRow(_ recipe: SavedRecipe) -> some View {
        let isSelected = selectedForMeal.contains(recipe.id)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if isSelected { selectedForMeal.remove(recipe.id) } else { selectedForMeal.insert(recipe.id) }
            }
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color.appMuted.opacity(0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle().fill(Color.orange).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.appAccentText)
                    }
                }

                if let image = recipe.uiImage {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.13))
                        Image(systemName: "fork.knife").font(.caption.bold()).foregroundColor(.orange)
                    }.frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.subheadline).fontWeight(.heavy)
                        .foregroundColor(.appText).lineLimit(1)
                    HStack(spacing: 6) {
                        Label("\(Int(recipe.calories))", systemImage: "flame.fill")
                            .foregroundColor(.neonGreen)
                        Label("\(Int(recipe.protein))g", systemImage: "drop.fill")
                            .foregroundColor(.neonCyan)
                        Label("\(Int(recipe.carbs))g", systemImage: "leaf.fill")
                            .foregroundColor(.fitOrange)
                        Label("\(Int(recipe.fat))g", systemImage: "circle.inset.filled")
                            .foregroundColor(.yellow)
                    }.font(.system(size: 10, weight: .heavy))
                    .lineLimit(1)
                    .fixedSize()
                }
                Spacer()
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.orange.opacity(0.10) : Color.appSurface)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.orange.opacity(0.3) : Color.orange.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedBuildComponents: [MealBuilderComponent] {
        var result: [MealBuilderComponent] = []
        for fav in newestFavorites where selectedForMeal.contains(fav.id) {
            result.append(MealBuilderComponent(
                id: fav.id, name: fav.name, calories: fav.calories, protein: fav.protein, carbs: fav.carbs, fat: fav.fat,
                ingredients: fav.ingredients, image: fav.uiImage,
                totalWeightGrams: MealBuilderComponent.parseWeight(from: fav.ingredients)
            ))
        }
        for recipe in newestSavedRecipes where selectedForMeal.contains(recipe.id) {
            result.append(MealBuilderComponent(
                id: recipe.id, name: recipe.name, calories: recipe.calories, protein: recipe.protein, carbs: recipe.carbs, fat: recipe.fat,
                ingredients: recipe.ingredients, image: recipe.uiImage,
                totalWeightGrams: MealBuilderComponent.parseWeight(from: recipe.ingredients)
            ))
        }
        return result
    }

    private var mealBuildBar: some View {
        let items = selectedBuildComponents
        let totalCal = items.reduce(0.0) { $0 + $1.calories }
        let totalProt = items.reduce(0.0) { $0 + $1.protein }
        let totalCarbs = items.reduce(0.0) { $0 + $1.carbs }
        let totalFat = items.reduce(0.0) { $0 + $1.fat }

        return VStack(spacing: 0) {
            Divider().background(Color.orange.opacity(0.3))
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring()) { selectedForMeal.removeAll(); isBuildingMeal = false }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.appMuted)
                }

                Spacer()

                if !items.isEmpty {
                    Text("\(items.count) · \(Int(totalCal))cal · \(Int(totalProt))p · \(Int(totalCarbs))c · \(Int(totalFat))f")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Select items")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.appMuted)
                }

                Spacer()

                Button {
                    isShowingMealBuilder = true
                } label: {
                    Text("Next")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.appAccentText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.orange))
                }
                .disabled(items.isEmpty)
                .opacity(items.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.appElevated)
        }
    }

    private func saveBuildMeal(name: String, components: [MealBuilderComponent]) {
        let totalCal = components.reduce(0.0) { $0 + $1.calories * $1.effectiveMultiplier }
        let totalProt = components.reduce(0.0) { $0 + $1.protein * $1.effectiveMultiplier }
        let totalCarbs = components.reduce(0.0) { $0 + $1.carbs * $1.effectiveMultiplier }
        let totalFat = components.reduce(0.0) { $0 + $1.fat * $1.effectiveMultiplier }
        let combinedIngredients = components.map { comp in
            let mult = comp.effectiveMultiplier
            let cal = Int((comp.calories * mult).rounded())
            let prot = Int((comp.protein * mult).rounded())
            let carbs = Int((comp.carbs * mult).rounded())
            let fat = Int((comp.fat * mult).rounded())
            let weightLabel: String
            if comp.hasGramMode {
                weightLabel = "\(Int(comp.effectiveGrams))g"
            } else if comp.useAll {
                weightLabel = "1 portion"
            } else {
                let pc = comp.portionCount
                weightLabel = pc == pc.rounded() ? "\(Int(pc)) pcs" : String(format: "%.1f pcs", pc)
            }
            return "\(comp.name);\(weightLabel);\(cal);\(prot);\(carbs);\(fat)"
        }.joined(separator: "\n")

        let firstImage = components.compactMap(\.image).first
        let recipe = SavedRecipe(
            image: firstImage,
            name: name,
            instructions: "",
            calories: totalCal,
            protein: totalProt,
            carbs: totalCarbs,
            fat: totalFat,
            ingredients: combinedIngredients
        )
        modelContext.insert(recipe)

        withAnimation(.spring()) {
            selectedForMeal.removeAll()
            isBuildingMeal = false
            currentTab = 1
        }
    }

    func clearShoppingList() {
        for item in shoppingItems {
            modelContext.delete(item)
        }
    }
    func favoriteRow(_ fav: FavoriteFood) -> some View {
        HStack(spacing: 11) {
            if let image = fav.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.neonCyan.opacity(0.20), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.neonCyan.opacity(0.13))
                    Image(systemName: "snowflake")
                        .font(.title3.bold())
                        .foregroundColor(.neonCyan)
                }
                .frame(width: 54, height: 54)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(fav.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    Label("\(Int(fav.calories))", systemImage: "flame.fill")
                        .foregroundColor(.neonGreen)
                    Label("\(Int(fav.protein))g", systemImage: "drop.fill")
                        .foregroundColor(.neonCyan)
                    Label("\(Int(fav.carbs))g", systemImage: "leaf.fill")
                        .foregroundColor(.fitOrange)
                    Label("\(Int(fav.fat))g", systemImage: "circle.inset.filled")
                        .foregroundColor(.yellow)
                }
                .font(.system(size: 10, weight: .heavy))
                .lineLimit(1)
                .fixedSize()

                Text(fav.basisDisplayText)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                rowIconButton(systemName: "pencil", color: .white.opacity(0.82)) {
                    withAnimation(.spring()) { selectedFavoriteForEdit = fav }
                }

                rowIconButton(systemName: "plus", color: .neonCyan) {
                    presentFavoriteAmountPicker(for: fav)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            myFoodRowBackground(accent: .neonCyan)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) {
                selectedFavoriteForEdit = fav
            }
        }
    }

    private func rowIconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(AppTheme.current == .originalV2 ? Color.appElevated.opacity(0.95) : Color.appBorder)
                        .overlay(Circle().stroke(color.opacity(0.22), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func selectedTabGradient(for color: Color) -> LinearGradient {
        let theme = AppTheme.current
        if theme == .originalV2 {
            return LinearGradient(
                colors: [color.opacity(0.92), theme.palette.primary.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if isIPhoneGlassTheme(theme) {
            return LinearGradient(
                colors: [color.opacity(0.88), theme.palette.secondary.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(colors: [color, color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func foodSearchBar(color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appMuted)

            TextField("Search...", text: $searchText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appText)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.appMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Capsule().fill(themeChromeGradient()))
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }

    private var fridgeCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                categoryChip(title: "All", emoji: nil, isSelected: selectedFridgeCategory == nil, color: .neonCyan) {
                    withAnimation(.spring(response: 0.25)) { selectedFridgeCategory = nil }
                }
                ForEach(activeFridgeCategories, id: \.rawValue) { cat in
                    categoryChip(title: cat.rawValue, emoji: cat.emoji, isSelected: selectedFridgeCategory == cat, color: .neonCyan) {
                        withAnimation(.spring(response: 0.25)) {
                            selectedFridgeCategory = selectedFridgeCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 6)
    }

    private var mealCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                categoryChip(title: "All", emoji: nil, isSelected: selectedMealCategory == nil, color: .fitOrange) {
                    withAnimation(.spring(response: 0.25)) { selectedMealCategory = nil }
                }
                ForEach(activeMealCategories, id: \.rawValue) { cat in
                    categoryChip(title: cat.rawValue, emoji: cat.emoji, isSelected: selectedMealCategory == cat, color: .fitOrange) {
                        withAnimation(.spring(response: 0.25)) {
                            selectedMealCategory = selectedMealCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 6)
    }

    private func categoryChip(title: String, emoji: String?, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji { Text(emoji).font(.system(size: 12)) }
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundColor(isSelected ? .appAccentText : .appMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? color : Color.appSurface)
            )
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func myFoodRowBackground(accent: Color) -> some View {
        let theme = AppTheme.current

        return RoundedRectangle(cornerRadius: 20)
            .fill(
                theme == .originalV2
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                theme.palette.surface,
                                accent.opacity(0.12),
                                theme.palette.elevated
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(themeCardGradient())
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accent.opacity(theme == .originalV2 ? 0.22 : 0.14), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func processingBanner(for tab: Int, color: Color) -> some View {
        let active = processingItems(for: tab)
        if !active.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(color)
                Text(active.first?.statusTitle ?? "Analyzing with AI...")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)
                Spacer()
                Text("\(active.count)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(color.opacity(0.18)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(0.10))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
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
                    .overlay(Color.appElevated.clipShape(RoundedRectangle(cornerRadius: 16)))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.statusTitle ?? (item.textPrompt != nil ? "Reading text..." : "FitMaks AI analyzing food..."))
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
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
            carbs: fav.carbs,
            fat: fav.fat,
            ingredients: fav.ingredients
        )

        modelContext.insert(newMeal)
        modelContext.delete(fav)
    }

    func moveMealToFav(_ recipe: SavedRecipe) {
        let ingredients = recipe.ingredients.isEmpty
            ? "Meal;1 portion;\(recipe.calories);\(recipe.protein);\(recipe.carbs);\(recipe.fat)"
            : recipe.ingredients
        let newFavorite = FavoriteFood(
            image: recipe.uiImage,
            name: recipe.name,
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fat: recipe.fat,
            ingredients: ingredients
        )

        modelContext.insert(newFavorite)
        modelContext.delete(recipe)
    }

    func presentFavoriteAmountPicker(for favorite: FavoriteFood) {
        selectedFavoriteForAmount = favorite
    }

    func addFavoriteToDiary(_ fav: FavoriteFood, amount: Double = 1) {
        let safeName = fav.name.hasPrefix("❄️") ? fav.name : "❄️ " + fav.name
        let multiplier: Double

        switch fav.portionBasis {
        case .per100g:
            multiplier = amount / 100
        case .perServing, .perPack, .perPiece:
            multiplier = amount
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring()) {
            modelContext.insert(FoodEntry(
                image: fav.uiImage ?? UIImage(),
                name: safeName,
                calories: fav.calories * multiplier,
                protein: fav.protein * multiplier,
                carbs: fav.carbs * multiplier,
                fat: fav.fat * multiplier,
                ingredients: scaleIngredientBreakdown(fav.ingredients, by: multiplier),
                date: selectedDate
            ))
        }
    }

    func addMealToDiary(_ recipe: SavedRecipe) {
        let safeName = recipe.name.hasPrefix("👨‍🍳") ? recipe.name : "👨‍🍳 " + recipe.name
        let ingredients = recipe.ingredients.isEmpty
            ? "Meal;1 portion;\(recipe.calories);\(recipe.protein);\(recipe.carbs);\(recipe.fat)"
            : recipe.ingredients

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring()) {
            modelContext.insert(FoodEntry(
                image: recipe.uiImage ?? UIImage(systemName: "fork.knife") ?? UIImage(),
                name: safeName,
                calories: recipe.calories,
                protein: recipe.protein,
                carbs: recipe.carbs,
                fat: recipe.fat,
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
