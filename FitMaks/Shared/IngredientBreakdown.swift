import SwiftUI

func scaleIngredientBreakdown(_ input: String, by factor: Double) -> String {
    guard factor > 0, factor.isFinite else {
        return input
    }

    return input
        .components(separatedBy: "\n")
        .map { line in
            let parts = line.components(separatedBy: ";")
            guard parts.count >= 3 else {
                return line
            }

            var updated = parts
            updated[1] = scaledWeightLabel(parts[1], factor: factor)
            updated[2] = scaledNumberString(parts[2], factor: factor)

            if parts.count > 3 {
                updated[3] = scaledNumberString(parts[3], factor: factor)
            }
            if parts.count > 4 {
                updated[4] = scaledNumberString(parts[4], factor: factor)
            }
            if parts.count > 5 {
                updated[5] = scaledNumberString(parts[5], factor: factor)
            }

            return updated.joined(separator: ";")
        }
        .joined(separator: "\n")
}

private func scaledWeightLabel(_ label: String, factor: Double) -> String {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    if let range = lower.range(of: #"(\d+(?:\.\d+)?)\s*(g\b|gr\b|gram|grams|ml\b|pcs\b|piece\b|pieces\b|serving\b|servings\b|pack\b|packs\b)"#, options: .regularExpression) {
        let original = String(trimmed[range])
        let number = original.filter { $0.isNumber || $0 == "." }
        let unit = original.drop { $0.isNumber || $0 == "." || $0 == " " }

        if let value = Double(number) {
            let scaled = value * factor
            let formatted = scaled.rounded() == scaled ? "\(Int(scaled))" : String(format: "%.1f", scaled)
            return trimmed.replacingOccurrences(of: original, with: "\(formatted)\(unit)")
        }
    }

    return trimmed
}

private func scaledNumberString(_ value: String, factor: Double) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let suffix = trimmed.contains("g") ? "g" : (trimmed.lowercased().contains("kcal") ? " kcal" : "")
    let number = trimmed.filter { $0.isNumber || $0 == "." }

    guard let parsed = Double(number) else {
        return trimmed
    }

    let scaled = parsed * factor
    let formatted = scaled.rounded() == scaled ? "\(Int(scaled))" : String(format: "%.1f", scaled)
    return suffix.isEmpty ? formatted : "\(formatted)\(suffix)"
}

func parseIngredientBreakdown(_ input: String) -> [ParsedIng] {
    input.components(separatedBy: "\n").compactMap { line in
        let parts = line.components(separatedBy: ";")
        guard parts.count >= 3 else {
            return nil
        }

        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let weight = parts[1].trimmingCharacters(in: .whitespaces)
        let kcal = parts[2]
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        let rawProtein = parts.count > 3 ? parts[3] : "0"
        let protein = rawProtein
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        let rawCarbs = parts.count > 4 ? parts[4] : "0"
        let carbs = rawCarbs
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        let rawFat = parts.count > 5 ? parts[5] : "0"
        let fat = rawFat
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        return ParsedIng(
            name: name,
            weight: weight,
            kcal: kcal.isEmpty ? "0" : kcal,
            prot: protein.isEmpty ? "0" : protein,
            carbs: carbs.isEmpty ? "0" : carbs,
            fat: fat.isEmpty ? "0" : fat
        )
    }
}

func fillMissingMacros(_ items: [ParsedIng], totalCarbs: Double, totalFat: Double) -> [ParsedIng] {
    let hasPerIngredient = items.contains { (Double($0.carbs) ?? 0) > 0 || (Double($0.fat) ?? 0) > 0 }
    guard !hasPerIngredient, (totalCarbs > 0 || totalFat > 0) else { return items }

    let totalCal = items.reduce(0.0) { $0 + (Double($1.kcal) ?? 0) }
    guard totalCal > 0 else { return items }

    return items.map { item in
        let cal = Double(item.kcal) ?? 0
        let share = cal / totalCal
        let c = (totalCarbs * share).rounded()
        let f = (totalFat * share).rounded()
        return ParsedIng(
            name: item.name,
            weight: item.weight,
            kcal: item.kcal,
            prot: item.prot,
            carbs: c > 0 ? String(Int(c)) : "0",
            fat: f > 0 ? String(Int(f)) : "0"
        )
    }
}

struct IngredientBreakdownCard: View {
    var title: String
    var ingredients: String
    var calories: Double
    var protein: Double
    var carbs: Double = 0
    var fat: Double = 0
    var accentColor: Color

    private var parsedItems: [ParsedIng] {
        fillMissingMacros(parseIngredientBreakdown(ingredients), totalCarbs: carbs, totalFat: fat)
    }

    private static func roundedDisplay(_ value: String) -> String {
        guard let v = Double(value.filter { $0.isNumber || $0 == "." }) else { return value }
        return v.rounded() == v ? "\(Int(v))" : String(format: "%.1f", v)
    }

    var body: some View {
        let items = parsedItems
        let showCF = items.contains { (Double($0.carbs) ?? 0) > 0 || (Double($0.fat) ?? 0) > 0 }
        let showWeight = items.contains { !$0.weight.isEmpty && $0.weight != "0" && $0.weight != "0g" }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Spacer()
                macroChip(text: "\(Int(calories)) kcal", color: .neonGreen)
                macroChip(text: "\(Int(protein))g P", color: .neonCyan)
                if carbs > 0 { macroChip(text: "\(Int(carbs))g C", color: .fitOrange) }
                if fat > 0 { macroChip(text: "\(Int(fat))g F", color: .yellow) }
            }

            HStack {
                Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                if showWeight {
                    Text("Wt").frame(width: 48, alignment: .trailing)
                }
                Text("Kcal").frame(width: 36, alignment: .trailing)
                Text("P").frame(width: 32, alignment: .trailing)
                if showCF {
                    Text("C").frame(width: 28, alignment: .trailing)
                    Text("F").frame(width: 32, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.gray)
            .padding(.horizontal, 10)

            ForEach(items) { item in
                HStack {
                    Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                    if showWeight {
                        Text(item.weight).frame(width: 48, alignment: .trailing)
                            .foregroundColor(.appMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(Self.roundedDisplay(item.kcal)).frame(width: 36, alignment: .trailing)
                        .foregroundColor(.neonGreen)
                    Text(Self.roundedDisplay(item.prot)).frame(width: 32, alignment: .trailing)
                        .foregroundColor(.neonCyan)
                    if showCF {
                        Text(Self.roundedDisplay(item.carbs)).frame(width: 28, alignment: .trailing)
                            .foregroundColor(.fitOrange)
                        Text(Self.roundedDisplay(item.fat)).frame(width: 32, alignment: .trailing)
                            .foregroundColor(.yellow)
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.appText)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.appSurface)
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appElevated)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(accentColor.opacity(0.15), lineWidth: 1))
        )
        .drawingGroup()
    }

    private func macroChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}
