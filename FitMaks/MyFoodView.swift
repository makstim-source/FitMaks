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
            .navigationTitle(isBuildingMeal ? "Build Meal" : isSelectionMode ? (initialTab == 0 ? "Pick from Fridge" : "Pick from Meals") : "My Food 🍱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.neonCyan) }
                if !isSelectionMode && !isBuildingMeal {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation(.spring()) { isBuildingMeal = true }
                        } label: {
                            Label("Build Meal", systemImage: "square.stack.3d.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                }
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
            .onAppear { if isSelectionMode { currentTab = initialTab } }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    // MARK: - Tab Subviews
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
                        if isBuildingMeal {
                            buildMealSelectableRow(fav)
                        } else {
                            favoriteRow(fav)
                                .contextMenu {
                                    Button { addFavoriteToDiary(fav); dismiss() } label: { Label("Add to Diary", systemImage: "plus.circle") }
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

        if isBuildingMeal {
            mealBuildBar
        } else if !isSelectionMode {
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

        if isBuildingMeal {
            mealBuildBar
        } else if !isSelectionMode {
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
                            .foregroundColor(.black)
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
                        .foregroundColor(.white).lineLimit(1)
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
                    .fill(isSelected ? Color.orange.opacity(0.10) : Color.white.opacity(0.055))
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
                            .foregroundColor(.black)
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
                        .foregroundColor(.white).lineLimit(1)
                    HStack(spacing: 8) {
                        Label("\(Int(recipe.calories)) kcal", systemImage: "flame.fill")
                        Label("\(Int(recipe.protein))g", systemImage: "drop.fill")
                    }.font(.caption.bold()).foregroundColor(.orange)
                }
                Spacer()
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.orange.opacity(0.10) : Color.white.opacity(0.055))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.orange.opacity(0.3) : Color.orange.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedBuildComponents: [MealBuilderComponent] {
        var result: [MealBuilderComponent] = []
        for fav in newestFavorites where selectedForMeal.contains(fav.id) {
            result.append(MealBuilderComponent(
                id: fav.id, name: fav.name, calories: fav.calories, protein: fav.protein,
                ingredients: fav.ingredients, image: fav.uiImage,
                totalWeightGrams: MealBuilderComponent.parseWeight(from: fav.ingredients)
            ))
        }
        for recipe in newestSavedRecipes where selectedForMeal.contains(recipe.id) {
            result.append(MealBuilderComponent(
                id: recipe.id, name: recipe.name, calories: recipe.calories, protein: recipe.protein,
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
                    HStack(spacing: 6) {
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        Text("·").foregroundColor(.appMuted)
                        Text("\(Int(totalCal)) cal")
                        Text("·").foregroundColor(.appMuted)
                        Text("\(Int(totalProt))g")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
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
                        .foregroundColor(.black)
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
        let combinedIngredients = components.map { comp in
            let mult = comp.effectiveMultiplier
            let cal = Int((comp.calories * mult).rounded())
            let prot = Int((comp.protein * mult).rounded())
            let weightLabel: String
            if comp.hasGramMode {
                weightLabel = "\(Int(comp.effectiveGrams))g"
            } else if comp.useAll {
                weightLabel = "1 portion"
            } else {
                let pc = comp.portionCount
                weightLabel = pc == pc.rounded() ? "\(Int(pc)) pcs" : String(format: "%.1f pcs", pc)
            }
            return "\(comp.name);\(weightLabel);\(cal);\(prot)"
        }.joined(separator: "\n")

        let firstImage = components.compactMap(\.image).first
        let recipe = SavedRecipe(
            image: firstImage,
            name: name,
            instructions: "",
            calories: totalCal,
            protein: totalProt,
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
                Text(item.statusTitle ?? (item.textPrompt != nil ? "Reading text..." : "FitMaks AI analyzing food..."))
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

// MARK: - Meal Builder

struct MealBuilderComponent: Identifiable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let ingredients: String
    let image: UIImage?
    var totalWeightGrams: Double?
    var useAll: Bool = true
    var customGrams: Double = 100
    var portionCount: Double = 1

    var hasGramMode: Bool { totalWeightGrams != nil && totalWeightGrams! > 0 }

    var effectiveMultiplier: Double {
        if useAll { return 1.0 }
        if let total = totalWeightGrams, total > 0 {
            return min(customGrams / total, 10)
        }
        return portionCount
    }

    var effectiveGrams: Double {
        if let total = totalWeightGrams {
            return useAll ? total : customGrams
        }
        return 0
    }

    static func parseWeight(from ingredients: String) -> Double? {
        let lines = ingredients.split(separator: "\n")
        var total: Double = 0
        var found = false
        for line in lines {
            let parts = line.split(separator: ";")
            guard parts.count >= 2 else { continue }
            let w = String(parts[1]).trimmingCharacters(in: .whitespaces).lowercased()
            if let range = w.range(of: #"(\d+(?:\.\d+)?)\s*(?:g\b|gr|ml)"#, options: .regularExpression) {
                let numStr = String(w[range]).filter { $0.isNumber || $0 == "." }
                if let val = Double(numStr) { total += val; found = true }
            }
        }
        return found ? total : nil
    }
}

struct MealBuilderSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var components: [MealBuilderComponent]
    @State private var mealName = ""
    var onSave: (String, [MealBuilderComponent]) -> Void

    private var totalCalories: Double {
        components.reduce(0) { $0 + $1.calories * $1.effectiveMultiplier }
    }

    private var totalProtein: Double {
        components.reduce(0) { $0 + $1.protein * $1.effectiveMultiplier }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackgroundStart.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        mealNameField
                        componentsList
                        totalBar
                    }
                    .padding()
                    .padding(.bottom, 80)
                }

                VStack {
                    Spacer()
                    saveButton
                }
            }
            .navigationTitle("Build Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.orange)
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private var mealNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEAL NAME")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)

            TextField("e.g. Chicken Rice Bowl", text: $mealName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                )
        }
    }

    private var componentsList: some View {
        VStack(spacing: 10) {
            Text("INGREDIENTS")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach($components) { $comp in
                componentRow(comp: $comp)
            }
        }
    }

    private func componentRow(comp: Binding<MealBuilderComponent>) -> some View {
        let item = comp.wrappedValue
        let mult = item.effectiveMultiplier
        let cal = Int((item.calories * mult).rounded())
        let prot = Int((item.protein * mult).rounded())

        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.neonCyan.opacity(0.13))
                        Image(systemName: "snowflake").font(.caption.bold()).foregroundColor(.neonCyan)
                    }.frame(width: 42, height: 42)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(cal) kcal").foregroundColor(.neonGreen)
                        Text("\(prot)g P").foregroundColor(.neonCyan)
                    }.font(.system(size: 11, weight: .bold))
                }

                Spacer()
            }

            if item.hasGramMode {
                gramControls(comp: comp)
            } else {
                portionControls(comp: comp)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.15), lineWidth: 1))
        )
    }

    private func gramControls(comp: Binding<MealBuilderComponent>) -> some View {
        let item = comp.wrappedValue
        let total = item.totalWeightGrams ?? 0
        let step: Double = total <= 150 ? 25 : 50

        return HStack(spacing: 6) {
            stepperButton(systemName: "minus", dimmed: item.useAll) {
                if comp.wrappedValue.useAll {
                    comp.wrappedValue.useAll = false
                    comp.wrappedValue.customGrams = max(step, total - step)
                } else {
                    comp.wrappedValue.customGrams = max(step, comp.wrappedValue.customGrams - step)
                }
            }

            Text(item.useAll ? "\(Int(total))g" : "\(Int(item.customGrams))g")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 56)

            stepperButton(systemName: "plus", dimmed: item.useAll) {
                if comp.wrappedValue.useAll {
                    comp.wrappedValue.useAll = false
                    comp.wrappedValue.customGrams = total + step
                } else {
                    let next = comp.wrappedValue.customGrams + step
                    if next >= total && next <= total + 1 {
                        comp.wrappedValue.useAll = true
                    } else {
                        comp.wrappedValue.customGrams = next
                    }
                }
            }

            Spacer()

            allButton(isActive: item.useAll, label: "All (\(Int(total))g)") {
                comp.wrappedValue.useAll = true
            }
        }
    }

    private func portionControls(comp: Binding<MealBuilderComponent>) -> some View {
        let item = comp.wrappedValue

        return HStack(spacing: 6) {
            stepperButton(systemName: "minus", dimmed: item.useAll) {
                comp.wrappedValue.useAll = false
                comp.wrappedValue.portionCount = max(0.5, comp.wrappedValue.portionCount - 0.5)
            }

            Text(item.useAll ? "1 pcs" : portionLabel(item.portionCount))
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 56)

            stepperButton(systemName: "plus", dimmed: false) {
                comp.wrappedValue.useAll = false
                comp.wrappedValue.portionCount += 0.5
            }

            Spacer()

            allButton(isActive: item.useAll, label: "All") {
                comp.wrappedValue.useAll = true
                comp.wrappedValue.portionCount = 1
            }
        }
    }

    private func stepperButton(systemName: String, dimmed: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.2)) { action() }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.orange)
                .frame(width: 34, height: 30)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func allButton(isActive: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.2)) { action() }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(isActive ? .black : .orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(isActive ? Color.orange : Color.orange.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func portionLabel(_ value: Double) -> String {
        if value == value.rounded() { return "\(Int(value)) pcs" }
        if value == 0.5 { return "½ pcs" }
        let whole = Int(value)
        let frac = value - Double(whole)
        if abs(frac - 0.5) < 0.01 { return "\(whole)½ pcs" }
        return String(format: "%.1f pcs", value)
    }

    private var totalBar: some View {
        HStack {
            Text("TOTAL")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)
            Spacer()
            HStack(spacing: 10) {
                Label("\(Int(totalCalories)) kcal", systemImage: "flame.fill")
                    .foregroundColor(.neonGreen)
                Label("\(Int(totalProtein))g", systemImage: "drop.fill")
                    .foregroundColor(.neonCyan)
            }
            .font(.system(size: 14, weight: .black))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        )
    }

    private var saveButton: some View {
        Button {
            let name = mealName.trimmingCharacters(in: .whitespaces)
            let finalName = name.isEmpty ? defaultMealName : name
            onSave(finalName, components)
            dismiss()
        } label: {
            Text("Save to Meals")
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.orange))
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var defaultMealName: String {
        let names = components.prefix(3).map(\.name)
        return names.joined(separator: " + ")
    }
}
