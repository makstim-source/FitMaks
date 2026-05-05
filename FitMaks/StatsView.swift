import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("seenAchievementUnlockIDs") private var seenAchievementUnlockIDs = ""

    var allFoodEntries: [FoodEntry]
    var allTrainingEntries: [TrainingEntry]
    var allSetups: [DailySetup]
    var baseCalories: Double
    var baseProtein: Double
    var postOptions: [FitMaksPostOption] = []

    @State private var weeklySteps: [String: Double] = [:]
    @State private var achievementBanner: StatsAchievement?
    @State private var pendingAchievementBanners: [StatsAchievement] = []
    @State private var livePayload: FitMaksSharePayload?

    private let stepTarget: Double = DayProgressEngine.defaultStepTarget

    typealias WeekStat = DayProgress

    var stats: [WeekStat] {
        let calendar = Calendar.current

        return (0..<7).map { index in
            let date = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            return stat(for: date)
        }
    }

    var last30Stats: [WeekStat] {
        let calendar = Calendar.current

        return (0..<30).compactMap { index in
            let daysBack = 29 - index
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
                return nil
            }

            return stat(for: date)
        }
    }

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

    private var currentSevenDayStats: [WeekStat] {
        let calendar = Calendar.current

        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()) else {
                return nil
            }

            return stat(for: date)
        }
    }

    private var achievementCollection: StatsAchievementCollection {
        AchievementEngine.achievementCollection(
            last30Stats: last30Stats,
            recentSevenDayStats: currentSevenDayStats,
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
                        StatsMetricGrid(
                            calorieWins: calorieWins,
                            proteinWins: proteinWins,
                            stepWins: stepWins,
                            weeklyScore: weeklyScore,
                            avgCalories: avgCalories,
                            totalSteps: totalSteps
                        )
                        StatsWeeklyArena(stats: stats)
                        StatsFuelChart(stats: stats)
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
                        Label("Post", systemImage: "camera.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.fitOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black))
                            .shadow(color: .fitOrange.opacity(0.35), radius: 8)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.neonGreen)
                        .bold()
                }
            }
            .onAppear {
                HealthKitManager.shared.fetchWeeklySteps { steps in
                    DispatchQueue.main.async {
                        self.weeklySteps = steps
                    }
                }
                refreshAchievementBannerQueue()
            }
            .onChange(of: unlockedAchievementSignature) { _, _ in
                refreshAchievementBannerQueue()
            }
        }
        .fullScreenCover(item: $livePayload) { payload in
            FitMaksLiveView(payload: payload, options: postOptions.isEmpty ? sharedPostOptions() : postOptions)
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private func stat(for date: Date) -> WeekStat {
        let calendar = Calendar.current
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let setup = allSetups.first(where: { $0.dateID == dateID })
        let mode = DayMode.fromStoredValue(setup?.mode)
        let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let dayTrainingCalories = allTrainingEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.caloriesBurned }
        let dayUploadedTrainingSteps = allTrainingEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + max($1.steps ?? 0, 0) }

        return DayProgressEngine.progress(
            date: date,
            foodEntries: dayFood,
            trainingCalories: dayTrainingCalories,
            mode: mode,
            baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCalories) ?? baseCalories,
            baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProtein) ?? baseProtein,
            steps: weeklySteps[dateID] ?? 0,
            uploadedSteps: dayUploadedTrainingSteps,
            stepTarget: stepTarget
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

    var allFoodEntries: [FoodEntry]
    var allTrainingEntries: [TrainingEntry]
    var allSetups: [DailySetup]
    var baseCalories: Double
    var baseProtein: Double
    var postOptions: [FitMaksPostOption] = []

    @State private var weeklySteps: [String: Double] = [:]
    @State private var selectedAchievement: StatsAchievement?
    @State private var livePayload: FitMaksSharePayload?

    private let stepTarget: Double = DayProgressEngine.defaultStepTarget

    private var last30Stats: [DayProgress] {
        let calendar = Calendar.current

        return (0..<30).compactMap { index in
            let daysBack = 29 - index
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
                return nil
            }

            return stat(for: date)
        }
    }

    private var currentSevenDayStats: [DayProgress] {
        let calendar = Calendar.current

        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()) else {
                return nil
            }

            return stat(for: date)
        }
    }

    private var achievementCollection: StatsAchievementCollection {
        AchievementEngine.achievementCollection(
            last30Stats: last30Stats,
            recentSevenDayStats: currentSevenDayStats,
            foodEntries: allFoodEntries
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                HomeBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        StatsAchievementsCard(
                            collection: achievementCollection,
                            selectedAchievement: $selectedAchievement
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 42)
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
                HealthKitManager.shared.fetchWeeklySteps { steps in
                    DispatchQueue.main.async {
                        self.weeklySteps = steps
                    }
                }
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

    private func stat(for date: Date) -> DayProgress {
        let calendar = Calendar.current
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let setup = allSetups.first(where: { $0.dateID == dateID })
        let mode = DayMode.fromStoredValue(setup?.mode)
        let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let dayTrainingCalories = allTrainingEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.caloriesBurned }
        let dayUploadedTrainingSteps = allTrainingEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + max($1.steps ?? 0, 0) }

        return DayProgressEngine.progress(
            date: date,
            foodEntries: dayFood,
            trainingCalories: dayTrainingCalories,
            mode: mode,
            baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCalories) ?? baseCalories,
            baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProtein) ?? baseProtein,
            steps: weeklySteps[dateID] ?? 0,
            uploadedSteps: dayUploadedTrainingSteps,
            stepTarget: stepTarget
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

private struct StatsAchievementsCard: View {
    let collection: StatsAchievementCollection
    @Binding var selectedAchievement: StatsAchievement?

    private let coreColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    private var unlockedChaosCount: Int { collection.chaos.filter(\.isUnlocked).count }
    private var wideChaosIDs: Set<String> {
        Set(
            collection.orderedChaos
                .filter(isWideCandidate)
                .prefix(3)
                .map(\.id)
        )
    }
    private var chaosRows: [ChaosBadgeRow] {
        var rows: [ChaosBadgeRow] = []
        let badges = collection.orderedChaos
        var index = 0

        while index < badges.count {
            let current = badges[index]

            if shouldUseWideTile(for: current) {
                rows.append(.single(current))
                index += 1
                continue
            }

            if index + 1 < badges.count {
                let next = badges[index + 1]
                if !shouldUseWideTile(for: next) {
                    rows.append(.pair(current, next))
                    index += 2
                    continue
                }
            }

            rows.append(.single(current))
            index += 1
        }

        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trophy Case")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)

                Spacer()

                Text("core + chaos")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
            }

            Text("Core trophies show the serious streaks. Chaos badges catch the funny, honest, and oddly shareable parts of real progress.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Label("Core Trophies", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.appText)

                LazyVGrid(columns: coreColumns, spacing: 10) {
                    ForEach(collection.core) { achievement in
                        Button {
                            selectedAchievement = achievement
                        } label: {
                            StatsAchievementTile(achievement: achievement, layout: .core)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Chaos Badges", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.appText)

                    Spacer()

                    Text("\(unlockedChaosCount)/\(collection.chaos.count) unlocked")
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(.neonGreen)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.neonGreen.opacity(0.12)))
                }

                Text("Side quests with more personality: chicken era, bounce-back days, gym brain, honest cheat-meal logs, and other crimes against average behavior.")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)

                VStack(spacing: 10) {
                    ForEach(Array(chaosRows.enumerated()), id: \.offset) { _, row in
                        switch row {
                        case .single(let achievement):
                            Button {
                                selectedAchievement = achievement
                            } label: {
                                StatsAchievementTile(achievement: achievement, layout: .chaosWide)
                            }
                            .buttonStyle(.plain)

                        case .pair(let leading, let trailing):
                            HStack(spacing: 10) {
                                Button {
                                    selectedAchievement = leading
                                } label: {
                                    StatsAchievementTile(achievement: leading, layout: .chaosCompact)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    selectedAchievement = trailing
                                } label: {
                                    StatsAchievementTile(achievement: trailing, layout: .chaosCompact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
    }

    private func shouldUseWideTile(for achievement: StatsAchievement) -> Bool {
        wideChaosIDs.contains(achievement.id)
    }

    private func isWideCandidate(_ achievement: StatsAchievement) -> Bool {
        achievement.title.count >= 20
            || achievement.subtitle.count >= 30
            || achievement.rarity == .hard
            || achievement.rarity == .legendary
    }
}

private enum ChaosBadgeRow {
    case single(StatsAchievement)
    case pair(StatsAchievement, StatsAchievement)
}

private enum StatsAchievementTileLayout {
    case core
    case chaosCompact
    case chaosWide
}

struct StatsAchievementUnlockBanner: View {
    let achievement: StatsAchievement
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                achievement.color.opacity(0.96),
                                Color.white.opacity(0.74),
                                achievement.color.opacity(0.68)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: achievement.icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.appAccentText)
            }
            .frame(width: 50, height: 50)
            .shadow(color: achievement.color.opacity(0.55), radius: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Achievement unlocked")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(achievement.color)
                    .tracking(0.8)

                Text(achievement.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(achievement.subtitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.appMuted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.appText.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appElevated.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(achievement.color.opacity(0.38), lineWidth: 1.2)
                )
        )
        .shadow(color: achievement.color.opacity(0.22), radius: 22, x: 0, y: 10)
    }
}

private struct StatsAchievementTile: View {
    let achievement: StatsAchievement
    var layout: StatsAchievementTileLayout = .core

    private var tileOpacity: Double {
        achievement.isUnlocked ? 1 : 0.62
    }

    private var isWide: Bool {
        layout == .chaosWide
    }

    private var minHeight: CGFloat? {
        switch layout {
        case .core:
            return nil
        case .chaosCompact:
            return 154
        case .chaosWide:
            return 138
        }
    }

    private var titleFontSize: CGFloat {
        switch layout {
        case .core:
            return 13
        case .chaosCompact:
            return 13
        case .chaosWide:
            return 16
        }
    }

    private var subtitleFont: Font {
        switch layout {
        case .core, .chaosCompact:
            return .caption2
        case .chaosWide:
            return .caption
        }
    }

    private var titleLineLimit: Int {
        switch layout {
        case .core:
            return 2
        case .chaosCompact:
            return 3
        case .chaosWide:
            return 2
        }
    }

    private var subtitleLineLimit: Int {
        switch layout {
        case .core:
            return 2
        case .chaosCompact:
            return 3
        case .chaosWide:
            return 2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(
                            achievement.isUnlocked
                                ? LinearGradient(
                                    colors: [
                                        achievement.color.opacity(0.95),
                                        Color.white.opacity(0.72),
                                        achievement.color.opacity(0.70)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        achievement.color.opacity(0.08),
                                        achievement.color.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )

                    Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(achievement.isUnlocked ? .appAccentText : .appMuted)

                    if achievement.isUnlocked {
                        Image(systemName: "sparkles")
                            .font(.system(size: isWide ? 13 : 12, weight: .black))
                            .foregroundColor(.white)
                            .offset(x: 18, y: -17)
                            .opacity(0.92)
                            .shadow(color: .white.opacity(0.75), radius: 7)
                    }
                }
                .frame(width: 42, height: 42)
                .shadow(color: achievement.isUnlocked ? achievement.color.opacity(0.54) : .clear, radius: 15)

                Spacer()

                Text(achievement.progressText)
                    .font(.system(size: isWide ? 11 : 10, weight: .heavy))
                    .foregroundColor(achievement.isUnlocked ? .appAccentText : .appMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(achievement.isUnlocked ? achievement.color : achievement.color.opacity(0.07)))
                    .shadow(color: achievement.isUnlocked ? achievement.color.opacity(0.30) : .clear, radius: 8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: titleFontSize, weight: .black))
                    .foregroundColor(.appText.opacity(tileOpacity))
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(isWide ? 0.84 : 0.76)

                Text(achievement.subtitle)
                    .font(subtitleFont)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineLimit(subtitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appText.opacity(0.08))

                    Capsule()
                        .fill(achievement.color.opacity(achievement.isUnlocked ? 0.95 : 0.58))
                        .frame(width: max(achievement.progress > 0 ? 8 : 0, proxy.size.width * CGFloat(achievement.progress)))
                }
            }
            .frame(height: 7)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    achievement.isUnlocked
                        ? LinearGradient(
                            colors: [
                                achievement.color.opacity(0.22),
                                Color.appSurface,
                                achievement.color.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.appSurface, Color.appSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(achievement.color.opacity(achievement.isUnlocked ? 0.55 : 0.12), lineWidth: achievement.isUnlocked ? 1.5 : 1)
        )
        .shadow(color: achievement.isUnlocked ? achievement.color.opacity(0.18) : .clear, radius: 12, x: 0, y: 7)
    }
}

private struct StatsDetailLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(color)
            .tracking(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

private struct StatsAchievementDetailSheet: View {
    let achievement: StatsAchievement
    var onShare: (() -> Void)? = nil

    var body: some View {
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

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(achievement.color.opacity(0.18))

                        Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(achievement.color)
                    }
                    .frame(width: 66, height: 66)
                    .shadow(color: achievement.color.opacity(0.35), radius: 16)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(achievement.title)
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.appText)

                            Spacer(minLength: 0)

                            if let onShare {
                                Button(action: onShare) {
                                    Label("Post", systemImage: "camera.fill")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.fitOrange)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.black))
                                        .shadow(color: .fitOrange.opacity(0.35), radius: 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(achievement.subtitle)
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundColor(achievement.color)

                        HStack(spacing: 8) {
                            StatsDetailLabel(text: achievement.family.label, color: achievement.color)
                            StatsDetailLabel(text: achievement.rarity.label, color: achievement.color.opacity(0.82))
                        }
                    }
                }

                Text(achievement.detail)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(achievement.isUnlocked ? "Unlocked" : "Progress")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundColor(.appMuted)

                        Spacer()

                        Text(achievement.currentText)
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(achievement.color)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.appText.opacity(0.08))

                            Capsule()
                                .fill(achievement.color)
                                .frame(width: max(achievement.progress > 0 ? 12 : 0, proxy.size.width * CGFloat(achievement.progress)))
                                .shadow(color: achievement.color.opacity(0.42), radius: 12)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(achievement.color.opacity(0.18), lineWidth: 1))

                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }
}

private struct StatsHeroScoreCard: View {
    let currentPerfectStreak: Int
    let bestPerfectStreak30: Int
    let perfectDays30: Int
    var onShare: (() -> Void)? = nil

    private var cappedStreak: Double {
        min(Double(currentPerfectStreak), AppRules.weeklyStreakTarget)
    }

    private var weeklyProgress: Double {
        cappedStreak / AppRules.weeklyStreakTarget
    }

    private var scoreMessage: String {
        switch currentPerfectStreak {
        case 7...:
            return "You are on a serious run."
        case 3..<7:
            return "Momentum is real now."
        case 1..<3:
            return "Protect the streak."
        default:
            return "One perfect day starts it."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("STREAK MODE", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.black.opacity(0.78))
                        .tracking(0.8)

                    Text(scoreMessage)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(.black)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 64, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.02, blue: 0.0).opacity(0.95),
                                        Color.red.opacity(0.82),
                                        Color.fitOrange.opacity(0.30)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .scaleEffect(0.98)
                            .shadow(color: Color.red.opacity(0.45), radius: 14)

                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(currentPerfectStreak)")
                                .font(.system(size: 52, weight: .black))
                            Text("d")
                                .font(.system(size: 20, weight: .black))
                        }
                        .foregroundColor(.black)
                        .shadow(color: .white.opacity(0.34), radius: 2, x: 0, y: 1)
                    }
                    .frame(width: 104, height: 70, alignment: .trailing)

                    Text("current streak")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.62))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.12))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.86), Color.neonGreen.opacity(0.86)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: currentPerfectStreak > 0 ? max(CGFloat(12), proxy.size.width * CGFloat(weeklyProgress)) : 0)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(Int(cappedStreak))/\(Int(AppRules.weeklyStreakTarget)) weekly flame")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.black.opacity(0.62))

                Spacer()

                Text(AppRules.calorieGraceLabel)
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.black.opacity(0.56))
            }

            HStack(spacing: 10) {
                StatsScorePill(title: "Best 30d", value: "\(bestPerfectStreak30)d", icon: "flame.fill")
                StatsScorePill(title: "Perfect days", value: "\(perfectDays30)/30", icon: "sparkles")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.neonGreen,
                            Color.yellow.opacity(0.92),
                            Color.neonCyan.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.neonGreen.opacity(0.26), radius: 24, x: 0, y: 12)
    }
}

private struct StatsWeeklyArena: View {
    let stats: [DayProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Day Streak Board")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)

                Spacer()

                Text("C / P / S")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }

            ForEach(stats, id: \.date) { stat in
                StatsDayBadgeRow(stat: stat)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct StatsFuelChart: View {
    let stats: [DayProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Calorie Balance")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)

                Spacer()

                Text(AppRules.calorieGraceLabel)
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.neonGreen)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.neonGreen.opacity(0.12)))
            }

            Text("One clean read per day: under target is green, up to 3% over stays in grace, bigger overages turn red.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 11) {
                ForEach(stats, id: \.date) { stat in
                    StatsCalorieBalanceRow(stat: stat)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
    }
}

private struct StatsDayBadgeRow: View {
    let stat: DayProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(StatsFormatters.dayName(stat.date))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.gray)

                    Text(StatsFormatters.dayNumber(stat.date))
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(width: 42)

                Text(stat.mode.emoji)
                    .font(.title3)
                    .frame(width: 30)

                HStack(spacing: 6) {
                    StatsBadgeChip(text: "C", isOn: stat.calorieWin, color: .neonGreen)
                    StatsBadgeChip(text: "P", isOn: stat.proteinWin, color: .neonCyan)
                    StatsBadgeChip(text: "S", isOn: stat.stepWin, color: .yellow)
                }

                Spacer(minLength: 6)

                if stat.isPerfect {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                        .font(.headline)
                        .frame(width: 24)
                        .shadow(color: .yellow.opacity(0.8), radius: 8)
                }
            }

            HStack(spacing: 7) {
                StatsDayMetricPill(
                    title: stat.hasFood && stat.consumed > stat.calorieGraceLimit ? "kcal over" : "kcal deficit",
                    value: stat.hasFood ? "\(abs(Int(stat.target - stat.consumed)))" : "—",
                    isOn: stat.calorieWin,
                    color: stat.hasFood && stat.consumed > stat.calorieGraceLimit ? .red : .neonGreen,
                    forceHighlight: stat.hasFood && stat.consumed > stat.calorieGraceLimit
                )
                StatsDayMetricPill(
                    title: "protein",
                    value: "\(Int(stat.protein))/\(Int(stat.proteinTarget))g",
                    isOn: stat.proteinWin,
                    color: .neonCyan
                )
                StatsDayMetricPill(
                    title: "steps",
                    value: "\(StatsFormatters.compactWholeSteps(stat.effectiveSteps))/10k",
                    isOn: stat.stepWin,
                    color: stat.stepBonus > 0 ? .fitOrange : .yellow,
                    disablesValueAnimation: true
                )
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(stat.isPerfect ? Color.neonGreen.opacity(0.13) : Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(stat.isPerfect ? Color.yellow.opacity(0.38) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct StatsDayMetricPill: View {
    let title: String
    let value: String
    let isOn: Bool
    let color: Color
    var disablesValueAnimation = false
    var forceHighlight = false

    private var highlighted: Bool { isOn || forceHighlight }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7, weight: .heavy))
                .foregroundColor(highlighted ? color : .gray)
                .tracking(0.5)

            Text(value)
                .font(.system(size: disablesValueAnimation ? 10 : 11, weight: .heavy))
                .foregroundColor(.white.opacity(highlighted ? 0.92 : 0.58))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(.identity)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .animation(nil, value: value)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(highlighted ? color.opacity(0.12) : Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(highlighted ? color.opacity(0.20) : Color.white.opacity(0.055), lineWidth: 1)
        )
    }
}

private struct StatsCalorieBalanceRow: View {
    let stat: DayProgress

    private var hasFood: Bool {
        stat.hasFood
    }

    private var isGrace: Bool {
        hasFood && stat.consumed > stat.target && stat.consumed <= stat.calorieGraceLimit
    }

    private var isOver: Bool {
        hasFood && stat.consumed > stat.calorieGraceLimit
    }

    private var calorieLabel: String {
        guard hasFood else { return "— kcal" }
        let diff = Int(stat.target - stat.consumed)
        if diff > 0 {
            return "-\(diff) kcal"
        } else if diff == 0 {
            return "0 kcal"
        } else {
            return "+\(abs(diff)) kcal"
        }
    }

    private var statusColor: Color {
        !hasFood ? .appMuted : (isOver ? .red : (isGrace ? .yellow : .neonGreen))
    }

    private var statusText: String {
        if !hasFood {
            return "no food logged"
        } else if isOver {
            return "\(Int(stat.consumed - stat.target)) over"
        } else if isGrace {
            return "within 3% grace"
        } else {
            return "\(Int(stat.target - stat.consumed)) left"
        }
    }

    private var fillRatio: Double {
        min(max(stat.consumed / max(stat.target, 1), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(StatsFormatters.dayName(stat.date))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .frame(width: 34, alignment: .leading)

                Text(calorieLabel)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.appText)

                Spacer()

                Text(statusText)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))

                    Capsule()
                        .fill(statusColor.opacity(hasFood ? 0.95 : 0.22))
                        .frame(width: hasFood ? max(CGFloat(8), proxy.size.width * CGFloat(fillRatio)) : 8)
                }
            }
            .frame(height: 8)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 17).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(statusColor.opacity(hasFood ? 0.22 : 0.10), lineWidth: 1))
    }
}
