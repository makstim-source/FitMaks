import SwiftUI

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

        return ParsedIng(
            name: name,
            weight: weight,
            kcal: kcal.isEmpty ? "0" : kcal,
            prot: protein.isEmpty ? "0" : protein
        )
    }
}

struct IngredientBreakdownCard: View {
    var title: String
    var ingredients: String
    var calories: Double
    var protein: Double
    var accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "wand.and.stars")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(accentColor)
                    .tracking(0.6)

                Spacer()

                HStack(spacing: 6) {
                    macroChip(text: "\(Int(calories)) kcal", color: .neonGreen)
                    macroChip(text: "\(Int(protein))g P", color: .neonCyan)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Weight").frame(width: 58, alignment: .center)
                    Text("Kcal").frame(width: 42, alignment: .trailing)
                    Text("Prot").frame(width: 42, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.gray)

                ForEach(parseIngredientBreakdown(ingredients)) { item in
                    HStack {
                        Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                        Text(item.weight).frame(width: 58, alignment: .center)
                        Text(item.kcal).frame(width: 42, alignment: .trailing)
                        Text(item.prot).frame(width: 42, alignment: .trailing)
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
