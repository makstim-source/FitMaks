import SwiftUI
import SwiftData
import PhotosUI

struct MyFoodView: View {
    @Environment(\.modelContext) var modelContext
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

    @State var isShowingSourceDialog = false
    @State var isShowingReceiptSourceDialog = false
    @State var isShowingCamera = false
    @State var selectedCameraImage: UIImage?
    @State var isShowingPhotoPicker = false
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var isShowingTextEntry = false
    @State var manualText = ""
    @State var isShowingClearAlert = false

    @State var selectedFavoriteForEdit: FavoriteFood?
    @State var selectedMealForEdit: SavedRecipe?
    @State var selectedFavoriteForAmount: FavoriteFood?

    @State var currentTab = 0
    @State var newShopItem = ""

    @State var isGeneratingRecipe = false
    @State var suggestedRecipes: [RecipeResult] = []
    @State var showRecipeSuggestions = false
    @State var selectedRecipeToShow: RecipeResult?
    @State var isScanningReceipt = false
    @State var aiErrorMessage: String?
    @State var isBuildingMeal = false
    @State var selectedForMeal: Set<UUID> = []
    @State var isShowingMealBuilder = false
    @State var searchText = ""
    @State var selectedFridgeCategory: FridgeCategory? = nil
    @State var selectedMealCategory: MealCategory? = nil

    var newestFavorites: [FavoriteFood] {
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

    var newestSavedRecipes: [SavedRecipe] {
        savedRecipes.sorted { $0.dateSaved > $1.dateSaved }
    }

    var filteredFavorites: [FavoriteFood] {
        var result = newestFavorites
        if let cat = selectedFridgeCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.ingredients.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var filteredRecipes: [SavedRecipe] {
        var result = newestSavedRecipes
        if let cat = selectedMealCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.ingredients.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var activeFridgeCategories: [FridgeCategory] {
        FridgeCategory.allCases
    }

    var activeMealCategories: [MealCategory] {
        MealCategory.allCases
    }

    @ViewBuilder
    var selectedTabContent: some View {
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
            .fullScreenCover(item: $selectedFavoriteForEdit) { fav in
                FavoriteChatEditScreen(
                    favorite: fav,
                    onDelete: { deleteFavorite(fav); selectedFavoriteForEdit = nil },
                    onDone: { selectedFavoriteForEdit = nil },
                    onMove: { moveFavToMeals(fav); selectedFavoriteForEdit = nil }
                )
            }
            .fullScreenCover(item: $selectedMealForEdit) { meal in
                MealChatEditScreen(
                    recipe: meal,
                    onDelete: { deleteMeal(meal); selectedMealForEdit = nil },
                    onDone: { selectedMealForEdit = nil },
                    onMove: { moveMealToFav(meal); selectedMealForEdit = nil }
                )
            }
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
}
