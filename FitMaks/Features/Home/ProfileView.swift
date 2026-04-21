import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var gender: String
    @Binding var age: Int
    @Binding var weight: Double
    @Binding var height: Double
    @Binding var goal: String
    @Binding var activityLevel: String
    @Binding var useCustomGoals: Bool
    @Binding var customCalories: Double
    @Binding var customProtein: Double

    var calculatedCalories: Double
    var calculatedProtein: Double

    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID
    @State private var isShowingThemePicker = false

    private var neonPurple: Color { .fitPurple }
    private let activityOptions: [ActivityOption] = [
        ActivityOption(key: "Sedentary", title: "Mostly sitting", subtitle: "Desk job, little walking", multiplier: 1.2),
        ActivityOption(key: "Light", title: "Light movement", subtitle: "Walks, 1-2 workouts/week", multiplier: 1.375),
        ActivityOption(key: "Moderate", title: "Regular training", subtitle: "3-4 workouts/week", multiplier: 1.55),
        ActivityOption(key: "Active", title: "Very active", subtitle: "Hard training or physical job", multiplier: 1.725)
    ]

    private var bmr: Double {
        (10.0 * weight) + (6.25 * height) - (5.0 * Double(age)) + (gender == "Male" ? 5.0 : -161.0)
    }

    private var selectedActivity: ActivityOption {
        activityOptions.first(where: { $0.key == activityLevel }) ?? activityOptions[2]
    }

    private var maintenanceCalories: Double {
        bmr * selectedActivity.multiplier
    }

    private var goalAdjustment: Double {
        switch goal {
        case "Lose Weight":
            return -500
        case "Build Muscle":
            return 500
        default:
            return 0
        }
    }

    private var recommendedCalories: Double {
        maintenanceCalories + goalAdjustment
    }

    private var weeklyWeightChangeKg: Double {
        abs(goalAdjustment) * 7 / 7700
    }

    private var selectedCalories: Double {
        useCustomGoals ? customCalories : calculatedCalories
    }

    private var selectedProtein: Double {
        useCustomGoals ? customProtein : calculatedProtein
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.appBackgroundStart,
                        Color.appBackgroundMid,
                        Color.appBackgroundEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        goalsHeader
                        recommendationCard
                        goalAndGenderCard
                        activityCard
                        bodyMetricsCard
                        customGoalsCard
                        themeCard
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profile & Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .foregroundColor(neonPurple)
                    .bold()
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .sheet(isPresented: $isShowingThemePicker) {
            ThemeSelectionView(isFirstRun: false) {
                isShowingThemePicker = false
            }
            .presentationDetents([.large])
        }
    }

    private var goalsHeader: some View {
        HStack(spacing: 14) {
            goalStat(title: "DAILY CALORIES", value: "\(Int(selectedCalories))", unit: "kcal", color: .appText)
            goalStat(title: "DAILY PROTEIN", value: "\(Int(selectedProtein))", unit: "g", color: neonPurple)
        }
    }

    private var themeCard: some View {
        let theme = AppTheme(rawValue: selectedThemeID) ?? .neonPulse
        let palette = theme.palette

        return Button {
            isShowingThemePicker = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(palette.primary.opacity(0.18))

                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(palette.primary)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    sectionTitle("Appearance")

                    Text("Theme: \(palette.name)")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(.appText)

                    Text("Change colors without touching your body goals.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appMuted)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: -5) {
                    Circle().fill(palette.primary).frame(width: 18, height: 18)
                    Circle().fill(palette.secondary).frame(width: 18, height: 18)
                    Circle().fill(palette.action).frame(width: 18, height: 18)
                }
                .overlay(Capsule().stroke(Color.appText.opacity(0.12), lineWidth: 1))

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.appMuted)
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("WHY THIS TARGET", systemImage: "function")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(neonPurple)
                        .tracking(0.8)

                    Text("\(Int(recommendedCalories)) kcal/day")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.appText)
                }

                Spacer()

                Text(goalBadgeText)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(goalBadgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(goalBadgeColor.opacity(0.14)))
            }

            VStack(spacing: 10) {
                explanationRow(title: "BMR", value: "\(Int(bmr)) kcal", detail: "Your base burn at rest")
                explanationRow(title: "Maintenance", value: "\(Int(maintenanceCalories)) kcal", detail: "\(selectedActivity.title) x\(String(format: "%.3g", selectedActivity.multiplier))")
                explanationRow(title: "Adjustment", value: adjustmentText, detail: adjustmentDetail)
                explanationRow(title: "Protein", value: "\(Int(calculatedProtein))g", detail: proteinDetail)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(neonPurple.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: neonPurple.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    private var goalAndGenderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Goal")

            HStack(spacing: 9) {
                goalButton(title: "Cut", subtitle: "Fat loss", key: "Lose Weight", color: .neonGreen)
                goalButton(title: "Maintain", subtitle: "Stable", key: "Maintain", color: .neonCyan)
                goalButton(title: "Build", subtitle: "Muscle", key: "Build Muscle", color: .orange)
            }

            Divider()
                .background(Color.appBorder)

            sectionTitle("Body formula")

            HStack(spacing: 10) {
                genderButton("Male")
                genderButton("Female")
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Activity")

                Spacer()

                Text("Choose what sounds like your real life")
                    .font(.caption2)
                    .foregroundColor(.appMuted)
            }

            VStack(spacing: 10) {
                ForEach(activityOptions) { option in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            activityLevel = option.key
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(activityLevel == option.key ? neonPurple : Color.appSurface)

                                Image(systemName: activityIcon(for: option.key))
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(activityLevel == option.key ? .appAccentText : neonPurple)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(.subheadline)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.appText)

                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.appMuted)
                            }

                            Spacer()

                            Text("x\(String(format: "%.3g", option.multiplier))")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(activityLevel == option.key ? neonPurple : .appMuted)
                        }
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(activityLevel == option.key ? neonPurple.opacity(0.16) : Color.appSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(activityLevel == option.key ? neonPurple.opacity(0.5) : Color.appBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var bodyMetricsCard: some View {
        VStack(spacing: 14) {
            HStack {
                sectionTitle("Your numbers")
                Spacer()
                Text("Hold +/- for faster changes")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            MetricStepperCard(
                title: "Age",
                value: Binding(
                    get: { Double(age) },
                    set: { age = Int($0.rounded()) }
                ),
                unit: "years",
                range: 10...100,
                step: 1,
                decimals: 0,
                accentColor: neonPurple
            )

            MetricStepperCard(
                title: "Weight",
                value: $weight,
                unit: "kg",
                range: 40...150,
                step: 0.5,
                decimals: 1,
                accentColor: neonPurple
            )

            MetricStepperCard(
                title: "Height",
                value: $height,
                unit: "cm",
                range: 140...220,
                step: 1,
                decimals: 0,
                accentColor: neonPurple
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    private var customGoalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $useCustomGoals) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Set custom goals")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(.appText)

                    Text("Override the recommendation if you already know your targets.")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                }
            }
            .tint(neonPurple)
            .onChange(of: useCustomGoals) { _, newValue in
                if newValue {
                    if customCalories == 0 {
                        customCalories = calculatedCalories
                    }
                    if customProtein == 0 {
                        customProtein = calculatedProtein
                    }
                }
            }

            if useCustomGoals {
                HStack(spacing: 12) {
                    editableGoalField(title: "Calories", value: $customCalories, unit: "kcal")
                    editableGoalField(title: "Protein", value: $customProtein, unit: "g")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var goalBadgeText: String {
        switch goal {
        case "Lose Weight":
            return "DEFICIT"
        case "Build Muscle":
            return "SURPLUS"
        default:
            return "MAINTAIN"
        }
    }

    private var goalBadgeColor: Color {
        switch goal {
        case "Lose Weight":
            return .neonGreen
        case "Build Muscle":
            return .orange
        default:
            return .neonCyan
        }
    }

    private var adjustmentText: String {
        switch goal {
        case "Lose Weight":
            return "-500 kcal/day"
        case "Build Muscle":
            return "+500 kcal/day"
        default:
            return "0 kcal/day"
        }
    }

    private var adjustmentDetail: String {
        switch goal {
        case "Lose Weight":
            return "Estimated fat loss: about \(String(format: "%.1f", weeklyWeightChangeKg)) kg/week"
        case "Build Muscle":
            return "Estimated gain pace: about \(String(format: "%.1f", weeklyWeightChangeKg)) kg/week"
        default:
            return "Designed to keep weight stable"
        }
    }

    private var proteinDetail: String {
        let gramsPerKg: Double

        switch goal {
        case "Build Muscle":
            gramsPerKg = 2.2
        case "Lose Weight":
            gramsPerKg = 2.0
        default:
            gramsPerKg = 1.8
        }

        return "\(String(format: "%.1f", gramsPerKg))g/kg based on body weight"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(.appMuted)
            .tracking(0.8)
    }

    private func goalStat(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .fontWeight(.heavy)
                .foregroundColor(.appMuted)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color.opacity(0.72))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }

    private func explanationRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)

                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
            }

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.heavy)
                .foregroundColor(.appText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }

    private func goalButton(title: String, subtitle: String, key: String, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                goal = key
            }
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                Text(subtitle)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .opacity(0.7)
            }
            .foregroundColor(goal == key ? .appAccentText : .appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(goal == key ? color : Color.appSurface)
            )
        }
        .buttonStyle(.plain)
    }

    private func genderButton(_ value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                gender = value
            }
        } label: {
            Text(value)
                .font(.headline)
                .fontWeight(.heavy)
                .foregroundColor(gender == value ? .appAccentText : .appText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gender == value ? neonPurple : Color.appSurface)
                )
        }
        .buttonStyle(.plain)
    }

    private func editableGoalField(title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.appMuted)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.leading)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.appMuted)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
    }

    private func activityIcon(for key: String) -> String {
        switch key {
        case "Sedentary":
            return "chair"
        case "Light":
            return "figure.walk"
        case "Moderate":
            return "figure.run"
        default:
            return "flame.fill"
        }
    }
}

private struct ActivityOption: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let subtitle: String
    let multiplier: Double
}

private struct MetricStepperCard: View {
    var title: String
    @Binding var value: Double
    var unit: String
    var range: ClosedRange<Double>
    var step: Double
    var decimals: Int
    var accentColor: Color

    private var formattedValue: String {
        decimals == 0
            ? "\(Int(value.rounded()))"
            : String(format: "%.\(decimals)f", value)
    }

    private var progress: Double {
        min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.appMuted)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(formattedValue)
                            .font(.system(size: 31, weight: .black))
                            .foregroundColor(.appText)

                        Text(unit)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appMuted)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    stepButton(systemName: "minus") {
                        value = max(range.lowerBound, value - step)
                    }

                    stepButton(systemName: "plus") {
                        value = min(range.upperBound, value + step)
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appText.opacity(0.08))

                    Capsule()
                        .fill(accentColor)
                        .frame(width: proxy.size.width * CGFloat(progress))
                        .shadow(color: accentColor.opacity(0.45), radius: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.appAccentText)
                .frame(width: 42, height: 42)
                .background(Circle().fill(accentColor))
                .shadow(color: accentColor.opacity(0.35), radius: 8)
        }
        .buttonRepeatBehavior(.enabled)
    }
}
