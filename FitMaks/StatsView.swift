import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("seenAchievementUnlockIDs") private var seenAchievementUnlockIDs = ""
    @AppStorage("userActivity") private var activityLevel: String = "Moderate"

    var allFoodEntries: [FoodEntry]
    var allTrainingEntries: [TrainingEntry]
    var allSetups: [DailySetup]
    var bodyMetrics: [BodyMetricEntry] = []
    var baseCalories: Double
    var baseProtein: Double
    var postOptions: [FitMaksPostOption] = []
    var onLast7DaysReport: (() -> Void)?

    @State private var weeklySteps: [String: Double] = [:]
    @State private var achievementBanner: StatsAchievement?
    @State private var pendingAchievementBanners: [StatsAchievement] = []
    @State private var livePayload: FitMaksSharePayload?
    @State private var cachedStats: [WeekStat] = []
    @State private var cachedLast30Stats: [WeekStat] = []
    @State private var cachedAchievements: StatsAchievementCollection?
    @State private var aiInsight: String?
    @State private var aiInsightLoading = false
    @State private var aiInsightError: String?
    @State private var isShowingPaywall = false

    private let stepTarget: Double = DayProgressEngine.defaultStepTarget

    typealias WeekStat = DayProgress

    var stats: [WeekStat] { cachedStats }
    var last30Stats: [WeekStat] { cachedLast30Stats }

    var calorieWins: Int { stats.filter { $0.calorieWin }.count }
    var proteinWins: Int { stats.filter { $0.proteinWin }.count }
    var stepWins: Int { stats.filter { $0.stepWin }.count }
    var completedChecks: Int { calorieWins + proteinWins + stepWins }
    var totalChecks: Int { stats.count * 3 }
    var weeklyScore: Int { Int((Double(completedChecks) / Double(max(totalChecks, 1)) * 100).rounded()) }
    var avgCalories: Double { stats.map { $0.consumed }.reduce(0, +) / Double(max(stats.count, 1)) }
    var totalSteps: Double { stats.map { $0.steps }.reduce(0, +) }
    var remainingChecks: Int { max(totalChecks - completedChecks, 0) }
    var perfectDays30: Int { last30Stats.filter { $0.isPerfect }.count }

    var currentPerfectStreak: Int {
        AchievementEngine.currentPerfectStreak(in: last30Stats)
    }

    var bestPerfectStreak30: Int {
        AchievementEngine.bestPerfectStreak(in: last30Stats, skipIncompleteToday: true)
    }

    private var achievementCollection: StatsAchievementCollection {
        cachedAchievements ?? AchievementEngine.achievementCollection(
            last30Stats: last30Stats,
            recentSevenDayStats: stats,
            foodEntries: allFoodEntries
        )
    }

    private var unlockedAchievementSignature: String {
        achievementCollection.all
            .filter(\.isUnlocked)
            .map(\.id)
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        let light = isLightAppTheme()

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
                        StatsHeroScoreCard(
                            currentPerfectStreak: currentPerfectStreak,
                            bestPerfectStreak30: bestPerfectStreak30,
                            perfectDays30: perfectDays30,
                            onShare: {
                                livePayload = .streak(
                                    FitMaksShareStreakSnapshot(
                                        current: currentPerfectStreak,
                                        target: Int(AppRules.weeklyStreakTarget),
                                        best30: bestPerfectStreak30,
                                        perfect30: perfectDays30
                                    )
                                )
                            }
                        )
                        StatsLast7DaysReportButton(
                            dateRange: statsDateRangeLabel,
                            weeklyScore: weeklyScore,
                            perfectDays: stats.filter { $0.isPerfect }.count,
                            calorieWins: calorieWins,
                            proteinWins: proteinWins,
                            stepWins: stepWins,
                            scoreColor: scoreColor(for: weeklyScore)
                        ) {
                            onLast7DaysReport?()
                        }
                        StatsWeeklyArena(stats: stats)
                        StatsFuelChart(stats: stats)
                        statsAIInsightCard
                        StatsChallengeCard(
                            currentPerfectStreak: currentPerfectStreak,
                            remainingChecks: remainingChecks
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 42)
                }

                if let achievementBanner {
                    VStack {
                        StatsAchievementUnlockBanner(achievement: achievementBanner) {
                            dismissAchievementBanner()
                        }
                        .padding(.top, 8)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }
            }
            .navigationTitle("Streak Mode")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        livePayload = streakPayload
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                            Text("Post")
                        }
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.fitOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(light ? Color.appSurface : Color.appElevated))
                        .overlay(
                            Capsule()
                                .stroke(light ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                        .shadow(color: light ? Color.black.opacity(0.05) : .fitOrange.opacity(0.35), radius: 8)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(light ? .appAccentText : .neonGreen)
                        .bold()
                }
            }
            .onAppear {
                rebuildStats()
                HealthKitManager.shared.fetchWeeklySteps { steps in
                    DispatchQueue.main.async {
                        self.weeklySteps = steps
                    }
                }
                refreshAchievementBannerQueue()
            }
            .onChange(of: weeklySteps) { _, _ in
                rebuildStats()
            }
            .task {
                if SubscriptionManager.shared.isPro { await loadAIInsight() }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
        }
        .fullScreenCover(item: $livePayload) { payload in
            FitMaksLiveView(payload: payload, options: postOptions.isEmpty ? sharedPostOptions() : postOptions)
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    // MARK: - AI Insight

    private var statsDateRangeLabel: String {
        guard let first = stats.first?.date, let last = stats.last?.date else {
            return "Last 7 days"
        }

        return "\(StatsFormatters.shortDay(first)) — \(StatsFormatters.shortDay(last))"
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return .neonGreen
        case 60..<80: return .fitOrange
        default: return .red
        }
    }

    private var statsAIInsightCard: some View {
        let isPro = SubscriptionManager.shared.isPro
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fitPurple)
                Text("AI WEEKLY INSIGHT")
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
                if aiInsightLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(.fitPurple)
                        Text("Analyzing your week...")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                } else if let aiInsight {
                    Text(aiInsight)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let aiInsightError {
                    Text(aiInsightError)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red.opacity(0.8))
                }
            } else {
                ZStack {
                    Text("Your caloric intake averaged 2,100 kcal this week, sitting right at your deficit target. Protein was on point 5 out of 7 days. Weight dropped 0.2 kg — steady progress.")
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
                            Text("Unlock AI Insights")
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

    private func loadAIInsight() async {
        guard !aiInsightLoading, aiInsight == nil else { return }
        aiInsightLoading = true

        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weightData = bodyMetrics
            .filter { $0.date >= sevenDaysAgo }
            .sorted { $0.date < $1.date }
            .map { (DateFormatter.yyyyMMdd.string(from: $0.date), $0.weightKg) }

        let trackedDays = stats.filter(\.hasFood)
        let trackedCount = Double(max(trackedDays.count, 1))
        let avgCalTracked = trackedDays.map(\.consumed).reduce(0, +) / trackedCount
        let avgProtTracked = trackedDays.map(\.protein).reduce(0, +) / trackedCount

        let recentFood = allFoodEntries.filter { $0.date >= sevenDaysAgo }
        let totalCarbs = recentFood.reduce(0.0) { $0 + $1.carbs }
        let totalFat = recentFood.reduce(0.0) { $0 + $1.fat }
        let avgCarbsVal = totalCarbs / trackedCount
        let avgFatVal = totalFat / trackedCount

        let recentTraining = allTrainingEntries.filter { $0.date >= sevenDaysAgo }
        let totalTrainingCal = recentTraining.reduce(0.0) { $0 + $1.caloriesBurned }
        let avgTrainingCal = totalTrainingCal / Double(max(stats.count, 1))

        let (result, error) = await GeminiService.shared.generateNutritionWeightReportAsync(
            dateRange: "Last 7 days (\(trackedDays.count) days with food logged)",
            avgCalories: Int(avgCalTracked),
            targetCalories: Int(baseCalories),
            avgProtein: Int(avgProtTracked),
            targetProtein: Int(baseProtein),
            avgCarbs: Int(avgCarbsVal),
            avgFat: Int(avgFatVal),
            avgTrainingCalories: Int(avgTrainingCal),
            weightEntries: weightData,
            weeklyScore: weeklyScore,
            perfectDays: stats.filter(\.isPerfect).count,
            totalDays: trackedDays.count,
            userName: AuthService.shared.displayName
        )
        aiInsightLoading = false
        if let result {
            aiInsight = result
        } else {
            aiInsightError = error ?? "Failed to generate insight."
        }
    }

    // MARK: - Rebuild

    private func rebuildStats() {
        let calendar = Calendar.current
        let index = Dictionary(allSetups.map { ($0.dateID, $0) }, uniquingKeysWith: { _, new in new })

        var foodByDay: [String: [FoodEntry]] = [:]
        for entry in allFoodEntries {
            let key = DateFormatter.yyyyMMdd.string(from: entry.date)
            foodByDay[key, default: []].append(entry)
        }

        var trainingByDay: [String: (calories: Double, steps: Double)] = [:]
        for entry in allTrainingEntries {
            let key = DateFormatter.yyyyMMdd.string(from: entry.date)
            var existing = trainingByDay[key] ?? (0, 0)
            existing.calories += entry.caloriesBurned
            existing.steps += max(entry.steps ?? 0, 0)
            trainingByDay[key] = existing
        }

        func buildStat(for date: Date) -> WeekStat {
            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let setup = index[dateID]
            let mode = DayMode.fromStoredValue(setup?.mode)
            let training = trainingByDay[dateID] ?? (0, 0)
            return DayProgressEngine.progress(
                date: date,
                foodEntries: foodByDay[dateID] ?? [],
                trainingCalories: training.calories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCalories) ?? baseCalories,
                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProtein) ?? baseProtein,
                steps: weeklySteps[dateID] ?? 0,
                uploadedSteps: training.steps,
                activityLevel: activityLevel,
                stepTarget: stepTarget
            )
        }

        let newStats = (0..<7).map { i in
            buildStat(for: calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date())
        }

        let newLast30 = (0..<30).compactMap { i -> WeekStat? in
            guard let date = calendar.date(byAdding: .day, value: -(29 - i), to: Date()) else { return nil }
            return buildStat(for: date)
        }

        cachedStats = newStats
        cachedLast30Stats = newLast30
        cachedAchievements = AchievementEngine.achievementCollection(
            last30Stats: newLast30,
            recentSevenDayStats: newStats,
            foodEntries: allFoodEntries
        )
    }

    private func refreshAchievementBannerQueue() {
        let seenIDs = Set(
            seenAchievementUnlockIDs
                .split(separator: "|")
                .map(String.init)
        )
        let unlocked = achievementCollection.all.filter(\.isUnlocked)
        let unseen = unlocked.filter { !seenIDs.contains($0.id) }

        guard !unseen.isEmpty else { return }

        let ordered = unseen.sorted { lhs, rhs in
            if lhs.family != rhs.family {
                return lhs.family == .core
            }

            if lhs.rarity.rawValue != rhs.rarity.rawValue {
                return lhs.rarity.rawValue > rhs.rarity.rawValue
            }

            return lhs.title < rhs.title
        }

        pendingAchievementBanners = ordered

        if achievementBanner == nil {
            showNextAchievementBanner()
        }
    }

    private func showNextAchievementBanner() {
        guard !pendingAchievementBanners.isEmpty else { return }

        let next = pendingAchievementBanners.removeFirst()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            achievementBanner = next
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if achievementBanner?.id == next.id {
                dismissAchievementBanner()
            }
        }
    }

    private func dismissAchievementBanner() {
        guard let current = achievementBanner else { return }

        var seenIDs = Set(
            seenAchievementUnlockIDs
                .split(separator: "|")
                .map(String.init)
        )
        seenIDs.insert(current.id)
        seenAchievementUnlockIDs = seenIDs.sorted().joined(separator: "|")

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            achievementBanner = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showNextAchievementBanner()
        }
    }

    private var streakPayload: FitMaksSharePayload {
        .streak(
            FitMaksShareStreakSnapshot(
                current: currentPerfectStreak,
                target: Int(AppRules.weeklyStreakTarget),
                best30: bestPerfectStreak30,
                perfect30: perfectDays30
            )
        )
    }

    private var streakBoardPayload: FitMaksSharePayload {
        .streakBoard(
            FitMaksShareStreakBoardSnapshot(
                rows: stats.map { stat in
                    let isOver = stat.hasFood && stat.consumed > stat.calorieGraceLimit
                    return FitMaksShareStreakBoardRow(
                        dayName: StatsFormatters.dayName(stat.date),
                        dayNumber: StatsFormatters.dayNumber(stat.date),
                        modeEmoji: stat.mode.emoji,
                        calorieWin: stat.calorieWin,
                        proteinWin: stat.proteinWin,
                        stepWin: stat.stepWin,
                        isPerfect: stat.isPerfect,
                        calorieTitle: isOver ? "kcal over" : "kcal deficit",
                        calorieValue: stat.hasFood ? "\(abs(Int(stat.target - stat.consumed)))" : "—",
                        calorieColor: isOver ? .red : .neonGreen,
                        proteinValue: "\(Int(stat.protein))/\(Int(stat.proteinTarget))g",
                        stepsValue: "\(StatsFormatters.compactWholeSteps(stat.effectiveSteps))/10k",
                        stepsColor: stat.stepBonus > 0 ? .fitOrange : .yellow
                    )
                }
            )
        )
    }

    private func sharedPostOptions() -> [FitMaksPostOption] {
        [
            FitMaksPostOption(id: streakPayload.id, title: "Summary", payload: streakPayload),
            FitMaksPostOption(id: streakBoardPayload.id, title: "Board", payload: streakBoardPayload)
        ] + achievementCollection.all.filter { $0.isUnlocked || $0.current > 0 }.map {
            FitMaksPostOption(
                id: UUID(),
                title: $0.title,
                payload: .achievement(
                    FitMaksShareAchievementSnapshot(
                        title: $0.title,
                        familyLabel: $0.family == .core ? "Core trophy" : "Side quest",
                        subtitle: $0.subtitle,
                        detail: $0.detail,
                        goalText: $0.goalText,
                        progressText: $0.progressText,
                        icon: $0.icon,
                        color: $0.color,
                        isUnlocked: $0.isUnlocked,
                        progress: $0.progress,
                        hasStarted: $0.current > 0
                    )
                )
            )
        }
    }

}

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userActivity") private var activityLevel: String = "Moderate"

    var allFoodEntries: [FoodEntry]
    var allTrainingEntries: [TrainingEntry]
    var allSetups: [DailySetup]
    var baseCalories: Double
    var baseProtein: Double
    var postOptions: [FitMaksPostOption] = []

    @State private var weeklySteps: [String: Double] = [:]
    @State private var selectedAchievement: StatsAchievement?
    @State private var livePayload: FitMaksSharePayload?
    @State private var cachedLast30Stats: [DayProgress] = []
    @State private var cachedSevenDayStats: [DayProgress] = []
    @State private var cachedAchievements: StatsAchievementCollection?

    private let stepTarget: Double = DayProgressEngine.defaultStepTarget

    private var last30Stats: [DayProgress] { cachedLast30Stats }
    private var currentSevenDayStats: [DayProgress] { cachedSevenDayStats }

    private var achievementCollection: StatsAchievementCollection {
        cachedAchievements ?? AchievementEngine.achievementCollection(
            last30Stats: last30Stats,
            recentSevenDayStats: currentSevenDayStats,
            foodEntries: allFoodEntries
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HomeBackground()

                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 18) {
                            StatsAchievementsCard(
                                collection: achievementCollection,
                                selectedAchievement: $selectedAchievement
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 42)
                        .frame(width: geo.size.width)
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.neonGreen)
                        .bold()
                }
            }
            .onAppear {
                rebuildStats()
                HealthKitManager.shared.fetchWeeklySteps { steps in
                    DispatchQueue.main.async {
                        self.weeklySteps = steps
                    }
                }
            }
            .onChange(of: weeklySteps) { _, _ in
                rebuildStats()
            }
            .sheet(item: $selectedAchievement) { achievement in
                StatsAchievementDetailSheet(
                    achievement: achievement,
                    onShare: {
                        livePayload = .achievement(
                            FitMaksShareAchievementSnapshot(
                                title: achievement.title,
                                familyLabel: achievement.family == .core ? "Core trophy" : "Side quest",
                                subtitle: achievement.subtitle,
                                detail: achievement.detail,
                                goalText: achievement.goalText,
                                progressText: achievement.progressText,
                                icon: achievement.icon,
                                color: achievement.color,
                                isUnlocked: achievement.isUnlocked,
                                progress: achievement.progress,
                                hasStarted: achievement.current > 0
                            )
                        )
                    }
                )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(item: $livePayload) { payload in
            FitMaksLiveView(payload: payload, options: postOptions.isEmpty ? sharedPostOptions() : postOptions)
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private func rebuildStats() {
        let calendar = Calendar.current
        let index = Dictionary(allSetups.map { ($0.dateID, $0) }, uniquingKeysWith: { _, new in new })

        var foodByDay: [String: [FoodEntry]] = [:]
        for entry in allFoodEntries {
            let key = DateFormatter.yyyyMMdd.string(from: entry.date)
            foodByDay[key, default: []].append(entry)
        }

        var trainingByDay: [String: (calories: Double, steps: Double)] = [:]
        for entry in allTrainingEntries {
            let key = DateFormatter.yyyyMMdd.string(from: entry.date)
            var existing = trainingByDay[key] ?? (0, 0)
            existing.calories += entry.caloriesBurned
            existing.steps += max(entry.steps ?? 0, 0)
            trainingByDay[key] = existing
        }

        func buildStat(for date: Date) -> DayProgress {
            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let setup = index[dateID]
            let mode = DayMode.fromStoredValue(setup?.mode)
            let training = trainingByDay[dateID] ?? (0, 0)
            return DayProgressEngine.progress(
                date: date,
                foodEntries: foodByDay[dateID] ?? [],
                trainingCalories: training.calories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCalories) ?? baseCalories,
                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProtein) ?? baseProtein,
                steps: weeklySteps[dateID] ?? 0,
                uploadedSteps: training.steps,
                activityLevel: activityLevel,
                stepTarget: stepTarget
            )
        }

        let newSevenDay = (0..<7).compactMap { i -> DayProgress? in
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            return buildStat(for: date)
        }

        let newLast30 = (0..<30).compactMap { i -> DayProgress? in
            guard let date = calendar.date(byAdding: .day, value: -(29 - i), to: Date()) else { return nil }
            return buildStat(for: date)
        }

        cachedSevenDayStats = newSevenDay
        cachedLast30Stats = newLast30
        cachedAchievements = AchievementEngine.achievementCollection(
            last30Stats: newLast30,
            recentSevenDayStats: newSevenDay,
            foodEntries: allFoodEntries
        )
    }

    private var streakPayload: FitMaksSharePayload {
        .streak(
            FitMaksShareStreakSnapshot(
                current: AchievementEngine.currentPerfectStreak(in: last30Stats),
                target: Int(AppRules.weeklyStreakTarget),
                best30: AchievementEngine.bestPerfectStreak(in: last30Stats, skipIncompleteToday: true),
                perfect30: last30Stats.filter { $0.isPerfect }.count
            )
        )
    }

    private var streakBoardPayload: FitMaksSharePayload {
        .streakBoard(
            FitMaksShareStreakBoardSnapshot(
                rows: currentSevenDayStats.map { stat in
                    let isOver = stat.hasFood && stat.consumed > stat.calorieGraceLimit
                    return FitMaksShareStreakBoardRow(
                        dayName: StatsFormatters.dayName(stat.date),
                        dayNumber: StatsFormatters.dayNumber(stat.date),
                        modeEmoji: stat.mode.emoji,
                        calorieWin: stat.calorieWin,
                        proteinWin: stat.proteinWin,
                        stepWin: stat.stepWin,
                        isPerfect: stat.isPerfect,
                        calorieTitle: isOver ? "kcal over" : "kcal deficit",
                        calorieValue: stat.hasFood ? "\(abs(Int(stat.target - stat.consumed)))" : "—",
                        calorieColor: isOver ? .red : .neonGreen,
                        proteinValue: "\(Int(stat.protein))/\(Int(stat.proteinTarget))g",
                        stepsValue: "\(StatsFormatters.compactWholeSteps(stat.effectiveSteps))/10k",
                        stepsColor: stat.stepBonus > 0 ? .fitOrange : .yellow
                    )
                }
            )
        )
    }

    private func sharedPostOptions() -> [FitMaksPostOption] {
        [
            FitMaksPostOption(id: streakPayload.id, title: "Summary", payload: streakPayload),
            FitMaksPostOption(id: streakBoardPayload.id, title: "Board", payload: streakBoardPayload)
        ] + achievementCollection.all.filter { $0.isUnlocked || $0.current > 0 }.map {
            FitMaksPostOption(
                id: UUID(),
                title: $0.title,
                payload: .achievement(
                    FitMaksShareAchievementSnapshot(
                        title: $0.title,
                        familyLabel: $0.family == .core ? "Core trophy" : "Side quest",
                        subtitle: $0.subtitle,
                        detail: $0.detail,
                        goalText: $0.goalText,
                        progressText: $0.progressText,
                        icon: $0.icon,
                        color: $0.color,
                        isUnlocked: $0.isUnlocked,
                        progress: $0.progress,
                        hasStarted: $0.current > 0
                    )
                )
            )
        }
    }
}
