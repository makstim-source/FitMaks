import SwiftUI
import SwiftData

// MARK: - Build Meal & CRUD Operations
extension MyFoodView {

    // MARK: - Build Meal Selection

    func buildMealSelectableRow(_ fav: FavoriteFood) -> some View {
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

    func buildMealSelectableMealRow(_ recipe: SavedRecipe) -> some View {
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

    var selectedBuildComponents: [MealBuilderComponent] {
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

    var mealBuildBar: some View {
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

    func saveBuildMeal(name: String, components: [MealBuilderComponent]) {
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

        let safeName = name.hasPrefix("👨‍🍳") ? name : "👨‍🍳 " + name
        modelContext.insert(FoodEntry(
            image: firstImage ?? UIImage(systemName: "fork.knife") ?? UIImage(),
            name: safeName,
            calories: totalCal,
            protein: totalProt,
            carbs: totalCarbs,
            fat: totalFat,
            ingredients: combinedIngredients,
            date: selectedDate,
            location: "recipe"
        ))

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring()) {
            selectedForMeal.removeAll()
            isBuildingMeal = false
        }
        dismiss()
    }

    // MARK: - CRUD Operations

    func clearShoppingList() {
        for item in shoppingItems {
            modelContext.delete(item)
        }
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
                date: selectedDate,
                location: "favorite"
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
                date: selectedDate,
                location: "recipe"
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

    func deleteFavorite(_ favorite: FavoriteFood) {
        GeminiService.shared.invalidateFoodImageCache(for: favorite.uiImage)
        modelContext.delete(favorite)
    }

    func deleteMeal(_ recipe: SavedRecipe) {
        GeminiService.shared.invalidateFoodImageCache(for: recipe.uiImage)
        modelContext.delete(recipe)
    }
}
