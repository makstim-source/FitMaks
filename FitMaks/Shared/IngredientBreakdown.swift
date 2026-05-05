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

struct IngredientBreakdownCard: View {
    var title: String
    var ingredients: String
    var calories: Double
    var protein: Double
    var carbs: Double = 0
    var fat: Double = 0
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "wand.and.stars")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(accentColor)
                    .tracking(0.6)

                HStack(spacing: 6) {
                    macroChip(text: "\(Int(calories)) kcal", color: .neonGreen)
                    macroChip(text: "\(Int(protein))g P", color: .neonCyan)
                    if carbs > 0 { macroChip(text: "\(Int(carbs))g C", color: .fitOrange) }
                    if fat > 0 { macroChip(text: "\(Int(fat))g F", color: .yellow) }
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Weight").frame(width: 58, alignment: .center)
                    Text("Kcal").frame(width: 42, alignment: .trailing)
                    Text("Prot").frame(width: 38, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.gray)

                ForEach(parseIngredientBreakdown(ingredients)) { item in
                    HStack {
                        Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                        Text(item.weight).frame(width: 58, alignment: .center)
                        Text(item.kcal).frame(width: 42, alignment: .trailing)
                        Text(item.prot).frame(width: 38, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.045))
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.34))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 1))
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.10), Color.white.opacity(0.045), Color.black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(accentColor.opacity(0.15), lineWidth: 1))
        )
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
