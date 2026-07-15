import SwiftUI
import SwiftData

struct RecipeSuggestionsView: View {
    var recipes: [RecipeResult]
    var selectedDate: Date

    @Environment(\.dismiss) var dismiss
    @State private var selectedRecipe: RecipeResult?

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
                                    HStack { Text("\(Int(r.estimated_calories)) kcal").foregroundColor(.neonGreen); Text("•").foregroundColor(.appMuted); Text("\(Int(r.estimated_protein))g protein").foregroundColor(.neonCyan); Text("•").foregroundColor(.appMuted); Text("C \(Int(r.estimated_carbs))g").foregroundColor(.fitOrange); Text("•").foregroundColor(.appMuted); Text("F \(Int(r.estimated_fat))g").foregroundColor(.yellow) }.font(.subheadline).bold()
                                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 15).fill(Color.appScrim)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.orange.opacity(0.5), lineWidth: 1))
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
                LinearGradient(colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(recipe.recipe_name).font(.largeTitle).bold().foregroundColor(.appText).lineLimit(nil).fixedSize(horizontal: false, vertical: true).padding(.top)
                        VStack(spacing: 12) {
                            HStack { VStack(spacing: 5) { Text("CALORIES").font(.caption).foregroundColor(.appMuted); Text("\(Int(recipe.estimated_calories))").font(.title2).bold().foregroundColor(.neonGreen) }.frame(maxWidth: .infinity); Divider().background(Color.appBorder).frame(height: 30); VStack(spacing: 5) { Text("PROTEIN").font(.caption).foregroundColor(.appMuted); Text("\(Int(recipe.estimated_protein))g").font(.title2).bold().foregroundColor(.neonCyan) }.frame(maxWidth: .infinity) }
                            HStack { VStack(spacing: 5) { Text("CARBS").font(.caption).foregroundColor(.appMuted); Text("\(Int(recipe.estimated_carbs))g").font(.title3).bold().foregroundColor(.fitOrange) }.frame(maxWidth: .infinity); Divider().background(Color.appBorder).frame(height: 26); VStack(spacing: 5) { Text("FAT").font(.caption).foregroundColor(.appMuted); Text("\(Int(recipe.estimated_fat))g").font(.title3).bold().foregroundColor(.yellow) }.frame(maxWidth: .infinity) }
                        }.padding().background(Color.appElevated).cornerRadius(15)
                        Text(LocalizedStringKey(recipe.cooking_instructions)).foregroundColor(.appMuted).lineSpacing(5)
                        Button(action: addToDiary) { HStack { Image(systemName: isAddedToDiary ? "checkmark" : "plus.circle.fill"); Text(isAddedToDiary ? "Added to Diary" : "Add to Today's Diary 🍽️").bold() }.frame(maxWidth: .infinity).padding().background(isAddedToDiary ? Color.neonGreen.opacity(0.8) : Color.fitOrange).foregroundColor(.appAccentText).cornerRadius(15).padding(.top, 20) }.disabled(isAddedToDiary)
                        Spacer()
                    }.padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() }.foregroundColor(.appMuted) }
                if !isPreSaved { ToolbarItem(placement: .navigationBarTrailing) { Button(isSaved ? "Saved ✅" : "Save Meal") { if !isSaved { modelContext.insert(SavedRecipe(name: recipe.recipe_name, instructions: recipe.cooking_instructions, calories: recipe.estimated_calories, protein: recipe.estimated_protein, carbs: recipe.estimated_carbs, fat: recipe.estimated_fat, ingredients: "")); withAnimation { isSaved = true } } }.foregroundColor(isSaved ? .neonGreen : .orange).bold() } }
            }
        }.preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    func addToDiary() {
        let safeName = recipe.recipe_name.hasPrefix("👨‍🍳") ? recipe.recipe_name : "👨‍🍳 " + recipe.recipe_name
        modelContext.insert(FoodEntry(image: UIImage(systemName: "fork.knife") ?? UIImage(), name: safeName, calories: recipe.estimated_calories, protein: recipe.estimated_protein, carbs: recipe.estimated_carbs, fat: recipe.estimated_fat, ingredients: "Recipe;1 portion;\(recipe.estimated_calories);\(recipe.estimated_protein);\(recipe.estimated_carbs);\(recipe.estimated_fat)", date: selectedDate))
        withAnimation { isAddedToDiary = true }
    }
}
