import SwiftUI

// MARK: - Goal Settings Sheet & Components
extension ProfileView {

    var goalSettingsSheet: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        goalsPreviewCard
                        goalAndGenderCard
                        activityCard
                        bodyMetricsCard
                        customGoalsCard
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Goals & Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if let snap = goalSnapshot {
                            gender = snap.gender
                            age = snap.age
                            weight = snap.weight
                            height = snap.height
                            goal = snap.goal
                            activityLevel = snap.activityLevel
                            useCustomGoals = snap.useCustomGoals
                            customCalories = snap.customCalories
                            customProtein = snap.customProtein
                            macroRestriction = snap.macroRestriction
                            customFat = snap.customFat
                            customCarbs = snap.customCarbs
                        }
                        isShowingGoalSettings = false
                    }
                    .foregroundColor(.appMuted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        isShowingGoalSettings = false
                    }
                    .foregroundColor(neonPurple)
                    .bold()
                }
            }
            .onAppear {
                goalSnapshot = GoalSnapshot(
                    gender: gender, age: age, weight: weight, height: height,
                    goal: goal, activityLevel: activityLevel,
                    useCustomGoals: useCustomGoals,
                    customCalories: customCalories, customProtein: customProtein,
                    macroRestriction: macroRestriction,
                    customFat: customFat, customCarbs: customCarbs
                )
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .presentationDetents([.large])
    }

    // MARK: - Preview Card

    var goalsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LIVE TARGET")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(1)

                    Text("\(Int(selectedCalories)) kcal")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(.appText)

                    Text("\(Int(selectedProtein))g protein")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(neonPurple)
                }

                Spacer()

                Text(useCustomGoals ? "CUSTOM" : goalBadgeText)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(useCustomGoals ? neonPurple : goalBadgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill((useCustomGoals ? neonPurple : goalBadgeColor).opacity(0.14)))
            }

            HStack(spacing: 10) {
                goalsPreviewMiniStat(title: "BMR", value: "\(Int(bmr))")
                goalsPreviewMiniStat(title: "Maintain", value: "\(Int(maintenanceCalories))")
                goalsPreviewMiniStat(title: "Week", value: "x\(String(format: "%.3g", selectedActivity.multiplier))")
            }

            Text(useCustomGoals ? "Custom goals are on, so ShapeForge will use your manual calorie and protein targets." : "\(selectedActivity.title) · \(adjustmentText) · \(proteinDetail)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .lineSpacing(3)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.neonGreen.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Goal & Gender

    var goalAndGenderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle("Goal")
                Spacer()
                liveTargetBadge
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                goalButton(title: "Cut", subtitle: "Lose fat", key: "Lose Weight", color: .neonGreen)
                goalButton(title: "Recomp", subtitle: "Lean + muscle", key: "Recomp", color: .neonCyan)
                goalButton(title: "Maintain", subtitle: "Hold shape", key: "Maintain", color: .fitPurple)
                goalButton(title: "Build", subtitle: "Gain muscle", key: "Build Muscle", color: .orange)
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

    // MARK: - Activity

    var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Normal week")

                Spacer()

                liveTargetBadge
            }

            Text("Pick your normal week, not your best week. Calories update instantly.")
                .font(.caption2)
                .foregroundColor(.appMuted)

            VStack(spacing: 10) {
                ForEach(activityOptions) { option in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            calculatorDidChange()
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

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("x\(String(format: "%.3g", option.multiplier))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(activityLevel == option.key ? neonPurple : .appMuted)

                                Text("\(Int(caloriesForActivity(option.key))) kcal")
                                    .font(.caption2)
                                    .fontWeight(.heavy)
                                    .foregroundColor(activityLevel == option.key ? .appText : .appMuted)
                            }
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

    // MARK: - Body Metrics (in Goal Settings)

    var bodyMetricsCard: some View {
        VStack(spacing: 14) {
            HStack {
                sectionTitle("Your numbers")
                Spacer()
                liveTargetBadge
            }

            HStack {
                Text("Hold +/- for faster changes")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
            }

            MetricStepperCard(
                title: "Age",
                value: Binding(
                    get: { Double(age) },
                    set: {
                        calculatorDidChange()
                        age = Int($0.rounded())
                    }
                ),
                unit: "years",
                range: 10...100,
                step: 1,
                decimals: 0,
                accentColor: neonPurple
            )

            MetricStepperCard(
                title: "Weight",
                value: Binding(
                    get: { weight },
                    set: {
                        calculatorDidChange()
                        weight = $0
                    }
                ),
                unit: "kg",
                range: 40...150,
                step: 0.5,
                decimals: 1,
                accentColor: neonPurple
            )

            MetricStepperCard(
                title: "Height",
                value: Binding(
                    get: { height },
                    set: {
                        calculatorDidChange()
                        height = $0
                    }
                ),
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

    // MARK: - Custom Goals

    var customGoalsCard: some View {
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
                        customCalories = recommendedCalories
                    }
                    if customProtein == 0 {
                        customProtein = recommendedProtein
                    }
                }
            }

            if useCustomGoals {
                HStack(spacing: 12) {
                    editableGoalField(title: "Calories", value: $customCalories, unit: "kcal")
                    editableGoalField(title: "Protein", value: $customProtein, unit: "g")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                macroRestrictionSection
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var macroRestrictionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MACRO SPLIT")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)

            HStack(spacing: 6) {
                restrictionButton(title: "Auto", value: "none")
                restrictionButton(title: "Set Fat", value: "fat")
                restrictionButton(title: "Set Carbs", value: "carbs")
            }

            if macroRestriction != "none" {
                let proteinCal = customProtein * 4
                let remainingCal = max(0, customCalories - proteinCal)

                if macroRestriction == "fat" {
                    HStack(spacing: 12) {
                        editableGoalField(title: "Fat", value: $customFat, unit: "g")
                        computedGoalField(title: "Carbs", value: autoCarbs, unit: "g")
                    }

                    macroCalorieSummary(
                        proteinCal: proteinCal,
                        fatCal: customFat * 9,
                        carbsCal: autoCarbs * 4,
                        remaining: remainingCal
                    )
                } else {
                    HStack(spacing: 12) {
                        computedGoalField(title: "Fat", value: autoFat, unit: "g")
                        editableGoalField(title: "Carbs", value: $customCarbs, unit: "g")
                    }

                    macroCalorieSummary(
                        proteinCal: proteinCal,
                        fatCal: autoFat * 9,
                        carbsCal: customCarbs * 4,
                        remaining: remainingCal
                    )
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    var autoCarbs: Double {
        let remaining = customCalories - (customProtein * 4) - (customFat * 9)
        return max(0, remaining / 4)
    }

    var autoFat: Double {
        let remaining = customCalories - (customProtein * 4) - (customCarbs * 4)
        return max(0, remaining / 9)
    }

    // MARK: - Goal Settings Components

    func restrictionButton(title: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                macroRestriction = value
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(macroRestriction == value ? .appAccentText : .appMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(macroRestriction == value ? neonPurple : Color.appElevated)
                )
                .overlay(Capsule().stroke(macroRestriction == value ? Color.clear : Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    func computedGoalField(title: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.appMuted)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(value.rounded()))")
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(neonPurple)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.appMuted)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(neonPurple.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(neonPurple.opacity(0.2), lineWidth: 1))
    }

    func macroCalorieSummary(proteinCal: Double, fatCal: Double, carbsCal: Double, remaining: Double) -> some View {
        let total = proteinCal + fatCal + carbsCal
        let overflow = total > customCalories + 1

        return HStack(spacing: 0) {
            macroBar(label: "P", cal: proteinCal, total: customCalories, color: .neonCyan)
            macroBar(label: "F", cal: fatCal, total: customCalories, color: .yellow)
            macroBar(label: "C", cal: carbsCal, total: customCalories, color: .fitOrange)
        }
        .frame(height: 22)
        .clipShape(Capsule())
        .overlay(
            HStack {
                Spacer()
                Text(overflow ? "over budget" : "\(Int(customCalories)) kcal")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(overflow ? .red : .appText.opacity(0.7))
                    .padding(.trailing, 8)
            }
        )
    }

    func macroBar(label: String, cal: Double, total: Double, color: Color) -> some View {
        let fraction = total > 0 ? max(0.05, cal / total) : 0.33
        return Rectangle()
            .fill(color.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(width: nil)
            .overlay(
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
            )
            .layoutPriority(fraction)
    }

    var liveTargetBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .black))

            Text("\(Int(selectedCalories)) kcal · \(Int(selectedProtein))g")
                .font(.caption2)
                .fontWeight(.heavy)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(.neonGreen)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.neonGreen.opacity(0.13)))
    }

    func goalsPreviewMiniStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.appText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
    }

    func caloriesForActivity(_ activityKey: String) -> Double {
        NutritionCalculator.recommendedCalories(
            gender: gender,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityKey,
            goal: goal
        )
    }

    func calculatorDidChange() {
        if useCustomGoals {
            useCustomGoals = false
        }
    }

    func goalButton(title: String, subtitle: String, key: String, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                calculatorDidChange()
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

    func genderButton(_ value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                calculatorDidChange()
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

    func editableGoalField(title: String, value: Binding<Double>, unit: String) -> some View {
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

    func activityIcon(for key: String) -> String {
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
