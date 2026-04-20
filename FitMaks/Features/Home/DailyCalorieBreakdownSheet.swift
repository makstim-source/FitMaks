import SwiftUI

struct DailyCalorieBreakdownSheet: View {
    var entries: [FoodEntry]
    var selectedDate: Date
    var dayMode: DayMode
    var baseCalories: Double
    var calorieBonus: Double
    var targetCalories: Double
    var consumedCalories: Double
    var baseProtein: Double
    var proteinBonus: Double
    var targetProtein: Double
    var consumedProtein: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text(DateFormatter.shortDate.string(from: selectedDate))
                                .font(.headline)
                                .foregroundColor(.appText)

                            Text(dayMode.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(.appMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))

                        goalCard(
                            title: "CALORIES",
                            unit: "kcal",
                            base: baseCalories,
                            bonus: calorieBonus,
                            target: targetCalories,
                            consumed: consumedCalories,
                            accentColor: .neonGreen,
                            isMinimumGoal: false
                        )

                        goalCard(
                            title: "PROTEIN",
                            unit: "g",
                            base: baseProtein,
                            bonus: proteinBonus,
                            target: targetProtein,
                            consumed: consumedProtein,
                            accentColor: .neonCyan,
                            isMinimumGoal: true
                        )

                        if entries.isEmpty {
                            emptyFoodState
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Food entries")
                                    .font(.caption.bold())
                                    .foregroundColor(.appMuted)

                                ForEach(entries.reversed()) { entry in
                                    foodEntryCard(entry)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.neonGreen)
                    .bold()
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    func goalCard(title: String, unit: String, base: Double, bonus: Double, target: Double, consumed: Double, accentColor: Color, isMinimumGoal: Bool) -> some View {
        let remaining = target - consumed
        let isOver = remaining < 0
        let statusColor = !isMinimumGoal && isOver ? Color.red : accentColor
        let statusText = statusText(remaining: remaining, unit: unit, isMinimumGoal: isMinimumGoal)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(statusColor)

                Spacer()

                Text(statusText)
                    .font(.caption.bold())
                    .foregroundColor(statusColor)
            }

            VStack(spacing: 10) {
                goalRow("Base goal", value: base, unit: unit, color: .appText)
                goalRow("\(dayMode.rawValue) bonus", value: bonus, unit: unit, color: bonus > 0 ? accentColor : .appMuted, prefix: bonus > 0 ? "+" : "")
                Divider().background(Color.appBorder)
                goalRow("Today target", value: target, unit: unit, color: accentColor)
                goalRow("Logged", value: consumed, unit: unit, color: statusColor)
                goalRow(statusRowTitle(remaining: remaining, isMinimumGoal: isMinimumGoal), value: abs(remaining), unit: unit, color: statusColor)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.gray.opacity(0.15)))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(statusColor.opacity(0.35), lineWidth: 1)
        )
    }

    func statusText(remaining: Double, unit: String, isMinimumGoal: Bool) -> String {
        if isMinimumGoal {
            return remaining > 0 ? "\(Int(remaining)) \(unit) short" : "\(Int(abs(remaining))) \(unit) over target"
        }

        return remaining < 0 ? "\(Int(abs(remaining))) \(unit) over" : "\(Int(remaining)) \(unit) left"
    }

    func statusRowTitle(remaining: Double, isMinimumGoal: Bool) -> String {
        if isMinimumGoal {
            return remaining > 0 ? "Missing" : "Above target"
        }

        return remaining < 0 ? "Over" : "Left"
    }

    func goalRow(_ title: String, value: Double, unit: String, color: Color, prefix: String = "") -> some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)

            Spacer()

            Text("\(prefix)\(Int(value)) \(unit)")
                .bold()
                .foregroundColor(color)
        }
        .font(.subheadline)
    }

    var emptyFoodState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 42))
                .foregroundColor(.gray.opacity(0.5))

            Text("No food entries for this day")
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.gray.opacity(0.12)))
    }

    func foodEntryCard(_ entry: FoodEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let image = entry.uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)

                    Text("\(Int(entry.calories)) kcal • \(Int(entry.protein))g protein")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }

            let ingredients = parseIngredientBreakdown(entry.ingredients)
            if !ingredients.isEmpty {
                VStack(spacing: 6) {
                    ForEach(ingredients.prefix(4)) { ingredient in
                        HStack {
                            Text(ingredient.name)
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text("\(ingredient.kcal) kcal • \(ingredient.prot)g")
                                .foregroundColor(.gray)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.gray.opacity(0.15)))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }
}
