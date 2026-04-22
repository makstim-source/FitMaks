import SwiftUI

enum DailyGoalBreakdownSection {
    case calories
    case protein
    case steps

    var title: String {
        switch self {
        case .calories:
            return "Calories"
        case .protein:
            return "Protein"
        case .steps:
            return "Steps"
        }
    }
}

struct DailyCalorieBreakdownSheet: View {
    var entries: [FoodEntry]
    var selectedDate: Date
    var section: DailyGoalBreakdownSection
    var dayMode: DayMode
    var trainingCalories: Double
    var baseCalories: Double
    var calorieBonus: Double
    var targetCalories: Double
    var consumedCalories: Double
    var baseProtein: Double
    var proteinBonus: Double
    var targetProtein: Double
    var consumedProtein: Double
    var actualSteps: Double
    var stepBonus: Double
    var targetSteps: Double

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

                        switch section {
                        case .calories:
                            caloriesSection
                        case .protein:
                            proteinSection
                        case .steps:
                            stepsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(section.title)
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

    var caloriesSection: some View {
        VStack(spacing: 16) {
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

            if dayMode == .cardio {
                Text(trainingCalories > 0 ? "Cardio bonus is using your uploaded workout calories instead of the 500 kcal estimate." : "Cardio starts with a 500 kcal estimate. Upload a workout screenshot and FitMaks will replace it with the calories from that workout.")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            foodEntriesSection(title: "Food calories")
        }
    }

    var proteinSection: some View {
        VStack(spacing: 16) {
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

            foodEntriesSection(title: "Protein sources")
        }
    }

    var stepsSection: some View {
        VStack(spacing: 16) {
            stepsGoalCard
        }
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

    var stepsGoalCard: some View {
        let effectiveSteps = actualSteps + stepBonus
        let minimumSteps = AppRules.completionMinimum(for: targetSteps)
        let missingSteps = max(minimumSteps - effectiveSteps, 0)
        let isClosed = missingSteps <= 0
        let statusColor = isClosed ? Color.yellow : Color.fitOrange
        let statusText = isClosed ? "steps closed" : "\(Int(missingSteps)) steps short"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STEPS")
                    .font(.caption.bold())
                    .foregroundColor(statusColor)

                Spacer()

                Text(statusText)
                    .font(.caption.bold())
                    .foregroundColor(statusColor)
            }

            VStack(spacing: 10) {
                goalRow("Health steps", value: actualSteps, unit: "steps", color: .appText)
                goalRow("\(dayMode.rawValue) credit", value: stepBonus, unit: "steps", color: stepBonus > 0 ? .fitOrange : .appMuted, prefix: stepBonus > 0 ? "+" : "")
                Divider().background(Color.appBorder)
                goalRow("Counted steps", value: effectiveSteps, unit: "steps", color: statusColor)
                goalRow("Daily target", value: targetSteps, unit: "steps", color: .yellow)
                goalRow("3% grace minimum", value: minimumSteps, unit: "steps", color: .appMuted)
                goalRow("Still needed", value: missingSteps, unit: "steps", color: missingSteps > 0 ? .fitOrange : .yellow)
            }

            if stepBonus > 0 {
                Text("Gym adds a 5k step credit, so a strength day can still close the 10k movement goal without pretending you walked more.")
                    .font(.caption)
                    .foregroundColor(.appMuted)
                    .lineSpacing(3)
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

    func foodEntriesSection(title: String) -> some View {
        Group {
            if entries.isEmpty {
                emptyFoodState
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundColor(.appMuted)

                    ForEach(entries.sorted { ($0.createdAt ?? $0.date) > ($1.createdAt ?? $1.date) }) { entry in
                        foodEntryCard(entry)
                    }
                }
            }
        }
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
