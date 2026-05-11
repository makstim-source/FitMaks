import SwiftUI

// MARK: - Meal Builder

struct MealBuilderComponent: Identifiable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
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

    private var totalCarbs: Double {
        components.reduce(0) { $0 + $1.carbs * $1.effectiveMultiplier }
    }

    private var totalFat: Double {
        components.reduce(0) { $0 + $1.fat * $1.effectiveMultiplier }
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
                .foregroundColor(.appText)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appSurface)
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
        let carbs = Int((item.carbs * mult).rounded())
        let fat = Int((item.fat * mult).rounded())

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
                        .foregroundColor(.appText)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(cal) kcal").foregroundColor(.neonGreen)
                        Text("\(prot)g P").foregroundColor(.neonCyan)
                    }.font(.system(size: 11, weight: .bold))
                    HStack(spacing: 6) {
                        Text("C \(carbs)g").foregroundColor(.fitOrange)
                        Text("F \(fat)g").foregroundColor(.yellow)
                    }.font(.system(size: 10, weight: .heavy))
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
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.15), lineWidth: 1))
        )
    }

    private func smartStep(for grams: Double) -> Double {
        switch grams {
        case ..<30: return 5
        case ..<100: return 10
        case ..<300: return 25
        default: return 50
        }
    }

    private func gramControls(comp: Binding<MealBuilderComponent>) -> some View {
        let item = comp.wrappedValue
        let total = item.totalWeightGrams ?? 0
        let currentGrams = item.useAll ? total : item.customGrams
        let step = smartStep(for: currentGrams)

        return HStack(spacing: 6) {
            stepperButton(systemName: "minus", dimmed: item.useAll) {
                let s = smartStep(for: comp.wrappedValue.useAll ? (comp.wrappedValue.totalWeightGrams ?? 0) : comp.wrappedValue.customGrams)
                if comp.wrappedValue.useAll {
                    comp.wrappedValue.useAll = false
                    comp.wrappedValue.customGrams = max(s, total - s)
                } else {
                    comp.wrappedValue.customGrams = max(s, comp.wrappedValue.customGrams - s)
                }
            }

            Text(item.useAll ? "\(Int(total))g" : "\(Int(item.customGrams))g")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.appText)
                .frame(width: 56)

            stepperButton(systemName: "plus", dimmed: item.useAll) {
                let s = smartStep(for: comp.wrappedValue.useAll ? (comp.wrappedValue.totalWeightGrams ?? 0) : comp.wrappedValue.customGrams)
                if comp.wrappedValue.useAll {
                    comp.wrappedValue.useAll = false
                    comp.wrappedValue.customGrams = total + s
                } else {
                    let next = comp.wrappedValue.customGrams + s
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
                .foregroundColor(.appText)
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
                Text("C \(Int(totalCarbs))g")
                    .foregroundColor(.fitOrange)
                Text("F \(Int(totalFat))g")
                    .foregroundColor(.yellow)
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
                .foregroundColor(.appAccentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.orange))
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var defaultMealName: String {
        let shorts = components.prefix(3).map { shortIngredientName($0.name) }
        return shorts.joined(separator: " & ")
    }

    private func shortIngredientName(_ name: String) -> String {
        let stripped = name
            .replacingOccurrences(of: "👨‍🍳 ", with: "")
            .replacingOccurrences(of: "❄️ ", with: "")
        let words = stripped.split(separator: " ").map(String.init)
        let meaningful = words.filter { w in
            let low = w.lowercased()
            let noise = ["boil-in-bag", "boil", "bag", "finest", "ohut", "with", "and", "in", "the", "+", "&", "от", "с", "и", "в"]
            return !noise.contains(low) && w.count > 1
        }
        let result = meaningful.prefix(2).joined(separator: " ")
        return result.isEmpty ? stripped : result
    }
}
