import SwiftUI

enum DailyGoalBreakdownSection {
    case calories
    case protein
    case steps
    case carbs
    case fat

    var title: String {
        switch self {
        case .calories:
            return "Calories"
        case .protein:
            return "Protein"
        case .steps:
            return "Steps"
        case .carbs:
            return "Carbs"
        case .fat:
            return "Fat"
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
    var baseCarbs: Double
    var targetCarbs: Double
    var consumedCarbs: Double
    var targetFat: Double
    var consumedFat: Double
    var actualSteps: Double
    var uploadedSteps: Double
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
                        case .carbs:
                            carbsSection
                        case .fat:
                            fatSection
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

            if dayMode != .chill {
                VStack(alignment: .leading, spacing: 6) {
                    if trainingCalories > 0 {
                        Text("Workout burned \(Int(trainingCalories)) kcal. FitMaks first credits 70% of that burn, then trims the day bonus if your profile is already set to a higher weekly activity level, so the same training is not counted twice.")
                    } else {
                        switch dayMode {
                        case .cardio:
                            Text("Cardio starts from a 500 kcal estimate, but that bonus is scaled down when your profile already says you train a lot.")
                        case .gym:
                            Text("Strength starts from a 300 kcal estimate, but that bonus is scaled down when your profile already says you train a lot.")
                        case .cardioGym:
                            Text("Mixed training uses one blended estimate instead of stacking cardio and strength in full, then scales it down if your weekly activity level is already high.")
                        case .chill:
                            EmptyView()
                        }
                    }
                }
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

    var carbsSection: some View {
        let fuelBonus = max(targetCarbs - baseCarbs, 0)
        let burnZone = max(min(baseCarbs * 0.7, targetCarbs), 0)
        let isOver = consumedCarbs > targetCarbs
        let statusColor: Color = isOver ? .red : (consumedCarbs <= burnZone ? .neonGreen : (consumedCarbs <= baseCarbs ? .yellow : .neonCyan))
        let statusText: String = isOver ? "\(Int(consumedCarbs - targetCarbs)) g over cap" : "\(Int(max(targetCarbs - consumedCarbs, 0))) g room left"

        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CARBS")
                        .font(.caption.bold())
                        .foregroundColor(statusColor)

                    Spacer()

                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                }

                VStack(spacing: 10) {
                    goalRow("Rest-day base", value: baseCarbs, unit: "g", color: .appText)
                    goalRow("Low-burn zone", value: burnZone, unit: "g", color: .neonGreen)
                    goalRow("\(dayMode.rawValue) fuel room", value: fuelBonus, unit: "g", color: fuelBonus > 0 ? .neonCyan : .appMuted, prefix: fuelBonus > 0 ? "+" : "")
                    Divider().background(Color.appBorder)
                    goalRow("Today cap", value: targetCarbs, unit: "g", color: .fitOrange)
                    goalRow("Logged", value: consumedCarbs, unit: "g", color: statusColor)
                    goalRow(isOver ? "Over cap" : "Room left", value: abs(targetCarbs - consumedCarbs), unit: "g", color: statusColor)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Carbs work as a fuel ceiling, not a target you must finish.")
                    Text("On chill days, staying closer to the base keeps the day lighter. On cardio days, the cap expands so training can use more carbs without making the whole day feel wrong.")

                    VStack(alignment: .leading, spacing: 8) {
                        legendRow(title: "Low", detail: "lighter day", description: "Good for a rest day when you want to keep carbs very low.", color: .neonGreen)
                        legendRow(title: "Base", detail: "inside base", description: "You are inside your normal carb range for a regular day.", color: .yellow, darkText: true)
                        if fuelBonus > 0 {
                            legendRow(title: "Fuel", detail: "using bonus", description: "You are using extra carbs unlocked by training.", color: .neonCyan)
                        }
                        legendRow(title: "Over", detail: "past cap", description: "You went above today's carb limit.", color: .red)
                    }
                }
                .font(.caption)
                .foregroundColor(.appMuted)
                .lineSpacing(3)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.gray.opacity(0.15)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(statusColor.opacity(0.35), lineWidth: 1)
            )

            foodEntriesSection(title: "Carb sources")
        }
    }

    var fatSection: some View {
        let lowerBound = max(targetFat * 0.85, targetFat - 8)
        let upperBound = max(targetFat * 1.15, lowerBound + 6)
        let statusColor: Color = consumedFat < lowerBound ? .fitOrange : (consumedFat > upperBound ? .fitPurple : .yellow)
        let statusText: String
        if consumedFat < lowerBound {
            statusText = "\(Int(lowerBound - consumedFat)) g below zone"
        } else if consumedFat > upperBound {
            statusText = "\(Int(consumedFat - upperBound)) g above zone"
        } else {
            statusText = "inside support zone"
        }

        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("FAT")
                        .font(.caption.bold())
                        .foregroundColor(statusColor)

                    Spacer()

                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                }

                VStack(spacing: 10) {
                    goalRow("Support floor", value: lowerBound, unit: "g", color: .fitOrange)
                    goalRow("Comfort ceiling", value: upperBound, unit: "g", color: .fitPurple)
                    Divider().background(Color.appBorder)
                    goalRow("Center target", value: targetFat, unit: "g", color: .yellow)
                    goalRow("Logged", value: consumedFat, unit: "g", color: statusColor)
                    goalRow(consumedFat < lowerBound ? "Still needed" : (consumedFat > upperBound ? "Above zone" : "Buffer left"), value: consumedFat < lowerBound ? (lowerBound - consumedFat) : (consumedFat > upperBound ? (consumedFat - upperBound) : (upperBound - consumedFat)), unit: "g", color: statusColor)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Fat is shown as a comfort zone, not a race to max out.")
                    Text("Too low means the day may be under-fueled. Too high usually means calories are getting dense fast. The sweet spot is the yellow support corridor.")

                    VStack(alignment: .leading, spacing: 8) {
                        legendRow(title: "Low", detail: "below floor", description: "Fat is a bit too low for a well-supported day.", color: .fitOrange)
                        legendRow(title: "In range", detail: "support zone", description: "This is the sweet spot for a balanced day.", color: .yellow, darkText: true)
                        legendRow(title: "High", detail: "above zone", description: "Fat is getting dense and can push calories up fast.", color: .fitPurple)
                    }
                }
                .font(.caption)
                .foregroundColor(.appMuted)
                .lineSpacing(3)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.gray.opacity(0.15)))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(statusColor.opacity(0.35), lineWidth: 1)
            )

            foodEntriesSection(title: "Fat sources")
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
        let countedBaseSteps = max(actualSteps, uploadedSteps)
        let effectiveSteps = countedBaseSteps + stepBonus
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
                goalRow("Uploaded workout steps", value: uploadedSteps, unit: "steps", color: uploadedSteps > 0 ? .yellow : .appMuted)
                goalRow("Best available base", value: countedBaseSteps, unit: "steps", color: countedBaseSteps >= actualSteps && uploadedSteps > actualSteps ? .yellow : .appText)
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

            if uploadedSteps > actualSteps {
                Text("Workout screenshots act as provisional steps while Apple Health catches up. When Health later shows a higher number, FitMaks uses that instead so the day is not double-counted.")
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

    func legendRow(title: String, detail: String, description: String, color: Color, darkText: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption2)
                .fontWeight(.black)
                .foregroundColor(darkText ? .black : .appAccentText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(color))

            VStack(alignment: .leading, spacing: 3) {
                Text(detail)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appText)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
        )
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

                    Text("\(Int(entry.calories)) kcal • \(Int(entry.protein))g protein • \(Int(entry.carbs))g carbs • \(Int(entry.fat))g fat")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }

            let ingredients = parseIngredientBreakdown(entry.ingredients)
            let showCF = entry.carbs > 0 || entry.fat > 0 || ingredients.contains { (Double($0.carbs) ?? 0) > 0 || (Double($0.fat) ?? 0) > 0 }
            if !ingredients.isEmpty {
                VStack(spacing: 6) {
                    ForEach(ingredients.prefix(4)) { ingredient in
                        HStack(spacing: 6) {
                            Text(ingredient.name)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .layoutPriority(1)

                            Spacer(minLength: 4)

                            ingredientMacroLabel(ingredient, showCF: showCF)
                                .layoutPriority(2)
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

    private func ingredientMacroLabel(_ ing: ParsedIng, showCF: Bool) -> some View {
        return HStack(spacing: 4) {
            Text("\(ing.kcal) kcal")
                .foregroundColor(.neonGreen)
            Text("P \(ing.prot)g")
                .foregroundColor(.neonCyan)
            if showCF {
                Text("C \(ing.carbs)g")
                    .foregroundColor(.fitOrange)
                Text("F \(ing.fat)g")
                    .foregroundColor(.yellow)
            }
        }
        .font(.system(size: 10, weight: .heavy))
        .lineLimit(1)
        .fixedSize()
    }
}
