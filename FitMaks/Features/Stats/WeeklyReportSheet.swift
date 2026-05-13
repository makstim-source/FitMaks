import SwiftUI

// MARK: - Data

struct WeeklyReportData: Identifiable {
    let id = UUID()
    let weekStart: Date
    let weekEnd: Date
    let days: [DayProgress]
    let totalCarbs: Double
    let totalFat: Double
    let totalMeals: Int

    var perfectDays: Int { days.filter(\.isPerfect).count }
    var calorieWins: Int { days.filter(\.calorieWin).count }
    var proteinWins: Int { days.filter(\.proteinWin).count }
    var stepWins: Int { days.filter(\.stepWin).count }
    var completedChecks: Int { calorieWins + proteinWins + stepWins }
    var totalChecks: Int { days.count * 3 }

    var weeklyScore: Int {
        guard totalChecks > 0 else { return 0 }
        return Int((Double(completedChecks) / Double(totalChecks) * 100).rounded())
    }

    var avgCalories: Double {
        guard !days.isEmpty else { return 0 }
        return days.map(\.consumed).reduce(0, +) / Double(days.count)
    }

    var avgCalorieTarget: Double {
        guard !days.isEmpty else { return 0 }
        return days.map(\.target).reduce(0, +) / Double(days.count)
    }

    var avgProtein: Double {
        guard !days.isEmpty else { return 0 }
        return days.map(\.protein).reduce(0, +) / Double(days.count)
    }

    var avgProteinTarget: Double {
        guard !days.isEmpty else { return 0 }
        return days.map(\.proteinTarget).reduce(0, +) / Double(days.count)
    }

    var totalSteps: Double {
        days.map(\.effectiveSteps).reduce(0, +)
    }

    var avgCarbs: Double {
        guard !days.isEmpty else { return 0 }
        return totalCarbs / Double(days.count)
    }

    var avgFat: Double {
        guard !days.isEmpty else { return 0 }
        return totalFat / Double(days.count)
    }

    var modeBreakdown: [(mode: DayMode, count: Int)] {
        var counts: [DayMode: Int] = [:]
        for day in days { counts[day.mode, default: 0] += 1 }
        return DayMode.allCases.compactMap { mode in
            guard let count = counts[mode], count > 0 else { return nil }
            return (mode, count)
        }
    }

    var dateRangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: weekStart)) — \(f.string(from: weekEnd))"
    }

    var weekID: String {
        DateFormatter.yyyyMMdd.string(from: weekStart)
    }

    var scoreColor: Color {
        switch weeklyScore {
        case 80...100: return .neonGreen
        case 60..<80: return .neonCyan
        case 40..<60: return .fitOrange
        default: return .red
        }
    }

    var scoreEmoji: String {
        switch weeklyScore {
        case 90...100: return "🏆"
        case 75..<90: return "💪"
        case 50..<75: return "👍"
        case 25..<50: return "🔄"
        default: return "🌱"
        }
    }

    var scoreLabel: String {
        switch weeklyScore {
        case 90...100: return "Outstanding"
        case 75..<90: return "Great week"
        case 50..<75: return "Solid effort"
        case 25..<50: return "Room to grow"
        default: return "Fresh start"
        }
    }

    static func previousWeek(from stats: [DayProgress], allFoodEntries: [FoodEntry]) -> WeeklyReportData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let prevMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
        let prevSunday = calendar.date(byAdding: .day, value: 6, to: prevMonday)!

        let weekDays = stats.filter { day in
            let d = calendar.startOfDay(for: day.date)
            return d >= prevMonday && d <= prevSunday
        }.sorted { $0.date < $1.date }

        guard !weekDays.isEmpty else { return nil }

        let weekFood = allFoodEntries.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= prevMonday && d <= prevSunday
        }

        return WeeklyReportData(
            weekStart: prevMonday,
            weekEnd: prevSunday,
            days: weekDays,
            totalCarbs: weekFood.reduce(0) { $0 + $1.carbs },
            totalFat: weekFood.reduce(0) { $0 + $1.fat },
            totalMeals: weekFood.count
        )
    }

    static func forWeekContaining(
        date: Date,
        allFoodEntries: [FoodEntry],
        allTrainingEntries: [TrainingEntry],
        setupIndex: [String: DailySetup],
        baseCaloriesGoal: Double,
        baseProteinGoal: Double,
        stepsIndex: [String: Double],
        activityLevel: String
    ) -> WeeklyReportData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: date)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: date)) else { return nil }
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!

        guard sunday < today else { return nil }

        let stepTarget = DayProgressEngine.defaultStepTarget
        var days: [DayProgress] = []

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let dateID = DateFormatter.yyyyMMdd.string(from: day)
            let setup = setupIndex[dateID]
            let mode = DayMode.fromStoredValue(setup?.mode)
            let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let dayTrainingCalories = allTrainingEntries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.caloriesBurned }
            let dayUploadedSteps = allTrainingEntries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + max($1.steps ?? 0, 0) }

            days.append(DayProgressEngine.progress(
                date: day,
                foodEntries: dayFood,
                trainingCalories: dayTrainingCalories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: day, fallback: baseCaloriesGoal) ?? baseCaloriesGoal,
                baseProtein: setup?.resolvedBaseProtein(for: day, fallback: baseProteinGoal) ?? baseProteinGoal,
                steps: stepsIndex[dateID] ?? 0,
                uploadedSteps: dayUploadedSteps,
                activityLevel: activityLevel,
                stepTarget: stepTarget
            ))
        }

        guard days.contains(where: { $0.consumed > 0 || $0.effectiveSteps > 0 }) else { return nil }

        let weekFood = allFoodEntries.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= monday && d <= sunday
        }

        return WeeklyReportData(
            weekStart: monday,
            weekEnd: sunday,
            days: days,
            totalCarbs: weekFood.reduce(0) { $0 + $1.carbs },
            totalFat: weekFood.reduce(0) { $0 + $1.fat },
            totalMeals: weekFood.count
        )
    }
}

// MARK: - Banner

struct WeeklyReportBanner: View {
    let report: WeeklyReportData
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(report.scoreColor.opacity(0.18))
                    Text(report.scoreEmoji)
                        .font(.system(size: 20))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly Report")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.appText)

                    Text("\(report.dateRangeLabel) · \(report.weeklyScore)% score")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(report.scoreColor)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [report.scoreColor.opacity(0.10), Color.appSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(report.scoreColor.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet

struct WeeklyReportSheet: View {
    let report: WeeklyReportData
    var weightEntries: [(date: String, weight: Double)] = []
    var baseCalories: Double = 0
    var baseProtein: Double = 0
    var userName: String? = nil
    var onShare: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    private var isPro: Bool { SubscriptionManager.shared.isPro }
    @State private var aiAnalysis: String?
    @State private var aiLoading = false
    @State private var aiError: String?
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        scoreCard
                        weekGrid
                        statsCards
                        aiInsightSection
                        if let onShare {
                            shareButton(action: onShare)
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.neonGreen)
                        .bold()
                }
            }
            .task {
                if isPro { await loadAIAnalysis() }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    // MARK: - Score

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text("WEEKLY REPORT")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(report.scoreColor)
                .tracking(1.2)

            Text(report.dateRangeLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appMuted)

            Text("\(report.weeklyScore)%")
                .font(.system(size: 56, weight: .black))
                .foregroundColor(report.scoreColor)

            Text("\(report.scoreEmoji) \(report.scoreLabel)")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.appText)

            Text("\(report.perfectDays)/7 perfect days")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.appMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.appElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(report.scoreColor.opacity(0.22), lineWidth: 1)
                )
        )
        .shadow(color: report.scoreColor.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    // MARK: - Week Grid

    private var weekGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAY BY DAY")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)

            HStack(spacing: 6) {
                ForEach(report.days, id: \.date) { day in
                    dayColumn(day)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.appBorder, lineWidth: 1))
        )
    }

    private func dayColumn(_ day: DayProgress) -> some View {
        let dayName = day.date.formatted(.dateTime.weekday(.abbreviated))

        return VStack(spacing: 6) {
            Text(dayName)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)

            ZStack {
                Circle()
                    .fill(day.isPerfect ? Color.neonGreen.opacity(0.18) : Color.appElevated)
                    .overlay(
                        Circle()
                            .stroke(day.isPerfect ? Color.neonGreen.opacity(0.5) : Color.appBorder, lineWidth: 1)
                    )

                if day.isPerfect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.neonGreen)
                } else {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Circle().fill(day.calorieWin ? Color.neonGreen : Color.appBorder).frame(width: 5, height: 5)
                            Circle().fill(day.proteinWin ? Color.neonCyan : Color.appBorder).frame(width: 5, height: 5)
                        }
                        Circle().fill(day.stepWin ? Color.fitOrange : Color.appBorder).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(width: 38, height: 38)

            Text(day.mode.emoji)
                .font(.system(size: 14))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricCard(
                    title: "AVG CALORIES",
                    value: "\(Int(report.avgCalories))",
                    target: "/ \(Int(report.avgCalorieTarget)) kcal",
                    detail: "\(report.calorieWins)/7 on target",
                    color: .neonGreen
                )

                metricCard(
                    title: "AVG PROTEIN",
                    value: "\(Int(report.avgProtein))g",
                    target: "/ \(Int(report.avgProteinTarget))g",
                    detail: "\(report.proteinWins)/7 on target",
                    color: .neonCyan
                )
            }

            HStack(spacing: 10) {
                metricCard(
                    title: "AVG CARBS",
                    value: "\(Int(report.avgCarbs))g",
                    target: "",
                    detail: "\(report.totalMeals) meals logged",
                    color: .fitOrange
                )

                metricCard(
                    title: "AVG FAT",
                    value: "\(Int(report.avgFat))g",
                    target: "",
                    detail: "per day avg",
                    color: .fitPurple
                )
            }

            HStack(spacing: 10) {
                metricCard(
                    title: "TOTAL STEPS",
                    value: Int(report.totalSteps).formatted(),
                    target: "",
                    detail: "\(report.stepWins)/7 hit target",
                    color: .fitOrange
                )

                modeCard
            }
        }
    }

    private func metricCard(title: String, value: String, target: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !target.isEmpty {
                    Text(target)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Text(detail)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.appMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appElevated)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
        )
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRAINING MIX")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)

            if report.modeBreakdown.isEmpty {
                Text("No data")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appMuted)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(report.modeBreakdown, id: \.mode) { item in
                        HStack(spacing: 5) {
                            Text(item.mode.emoji)
                                .font(.system(size: 13))
                            Text("\(item.count)x")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.appText)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appElevated)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
        )
    }

    // MARK: - AI Insight

    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fitPurple)
                Text("AI ANALYSIS")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .tracking(0.8)
                Spacer()
                if !isPro {
                    Text("PRO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.neonGreen))
                }
            }

            if isPro {
                if aiLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(.fitPurple)
                        Text("Analyzing your week...")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                } else if let aiAnalysis {
                    Text(aiAnalysis)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let aiError {
                    Text(aiError)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red.opacity(0.8))
                }
            } else {
                ZStack {
                    Text("Your nutrition was consistent this week with an average of 2,100 kcal. Protein intake fell short on 3 days. Weight trend shows a gradual decrease of 0.3 kg which aligns with your caloric deficit. Consider adding a protein-rich snack on training days.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appText)
                        .lineSpacing(4)
                        .blur(radius: 6)

                    Button {
                        isShowingPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Unlock AI Analysis")
                                .font(.system(size: 13, weight: .black))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.neonGreen))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isPro ? Color.fitPurple.opacity(0.22) : Color.appBorder, lineWidth: 1)
                )
        )
    }

    private func loadAIAnalysis() async {
        aiLoading = true

        let tracked = report.days.filter(\.hasFood)
        let trackedCount = Double(max(tracked.count, 1))
        let avgCal = tracked.map(\.consumed).reduce(0, +) / trackedCount
        let avgProt = tracked.map(\.protein).reduce(0, +) / trackedCount
        let avgCarbs = report.totalCarbs / trackedCount
        let avgFat = report.totalFat / trackedCount

        let (result, error) = await GeminiService.shared.generateNutritionWeightReportAsync(
            dateRange: "\(report.dateRangeLabel) (\(tracked.count)/\(report.days.count) days tracked)",
            avgCalories: Int(avgCal),
            targetCalories: Int(baseCalories),
            avgProtein: Int(avgProt),
            targetProtein: Int(baseProtein),
            avgCarbs: Int(avgCarbs),
            avgFat: Int(avgFat),
            weightEntries: weightEntries,
            weeklyScore: report.weeklyScore,
            perfectDays: report.perfectDays,
            totalDays: tracked.count,
            userName: userName
        )
        aiLoading = false
        if let result {
            aiAnalysis = result
        } else {
            aiError = error ?? "Failed to generate analysis."
        }
    }

    private func shareButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                Text("Share Weekly Report")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(report.scoreColor)
            )
        }
        .buttonStyle(.plain)
    }
}
