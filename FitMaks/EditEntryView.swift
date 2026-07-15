import SwiftUI
import SwiftData

struct EditEntryView: View {
    @Bindable var entry: FoodEntry
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Edit Details")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                Button(action: onSave) {
                    Text("Done")
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FOOD NAME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)

                    TextField("Enter name", text: $entry.name, axis: .vertical)
                        .lineLimit(1...3)
                        .foregroundColor(.appText)
                        .padding(10)
                        .background(Color.appElevated)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("CALORIES (KCAL)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)

                    TextField("0", value: $entry.calories, format: .number)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.neonGreen)
                        .padding(10)
                        .background(Color.appElevated)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("PROTEIN (G)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)

                    TextField("0", value: $entry.protein, format: .number)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.neonCyan)
                        .padding(10)
                        .background(Color.appElevated)
                        .cornerRadius(8)
                }
            }
        }
        .padding(25)
        .background(Color(red: 30/255, green: 30/255, blue: 35/255))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 30)
    }
}
