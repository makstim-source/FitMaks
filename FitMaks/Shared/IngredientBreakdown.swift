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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(accentColor)

                Spacer()

                Text("\(Int(calories)) kcal • \(Int(protein))g prot")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Weight").frame(width: 60, alignment: .center)
                    Text("Kcal").frame(width: 40, alignment: .trailing)
                    Text("Prot").frame(width: 40, alignment: .trailing)
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.bottom, 8)

                Divider()
                    .background(Color.white.opacity(0.3))

                ForEach(parseIngredientBreakdown(ingredients)) { item in
                    HStack {
                        Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.weight).frame(width: 60, alignment: .center)
                        Text(item.kcal).frame(width: 40, alignment: .trailing)
                        Text(item.prot).frame(width: 40, alignment: .trailing)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)

                    Divider()
                        .background(Color.gray.opacity(0.1))
                }
            }
            .padding()
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
        }
    }
}
