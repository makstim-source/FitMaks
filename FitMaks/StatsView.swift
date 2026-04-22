import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) var dismiss

    var allFoodEntries: [FoodEntry]
    var allTrainingEntries: [TrainingEntry]
    var allSetups: [DailySetup]
    var baseCalories: Double
    var baseProtein: Double

    @State private var weeklySteps: [String: Double] = [:]
    @State private var animateStreakFlame = false
    @State private var selectedAchievement: StatsAchievement?

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

    private var achievements: [StatsAchievement] {
        AchievementEngine.achievements(
            last30Stats: last30Stats,
            recentSevenDayStats: currentSevenDayStats
        )
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
                            animateStreakFlame: animateStreakFlame
                        )
                        StatsAchievementsCard(
                            achievements: achievements,
                            selectedAchievement: $selectedAchievement
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
            }
            .navigationTitle("Progress Arena")
            .navigationBarTitleDisplayMode(.large)
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
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    animateStreakFlame = true
                }
            }
            .sheet(item: $selectedAchievement) { achievement in
                StatsAchievementDetailSheet(achievement: achievement)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private func stat(for date: Date) -> WeekStat {
        let calendar = Calendar.current
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let mode = DayMode.fromStoredValue(allSetups.first(where: { $0.dateID == dateID })?.mode)
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
            baseCalories: baseCalories,
            baseProtein: baseProtein,
            steps: weeklySteps[dateID] ?? 0,
            uploadedSteps: dayUploadedTrainingSteps,
            stepTarget: stepTarget
        )
    }

}

private struct StatsAchievementsCard: View {
    let achievements: [StatsAchievement]
    @Binding var selectedAchievement: StatsAchievement?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trophy Case")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)

                Spacer()

                Text("unlock next")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
            }

            Text("Visible goals make streaks feel collectible: perfect-day trophies, plus a separate protein statue for closing protein every day.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(achievements) { achievement in
                    Button {
                        selectedAchievement = achievement
                    } label: {
                        StatsAchievementTile(achievement: achievement)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
    }
}

private struct StatsAchievementTile: View {
    let achievement: StatsAchievement

    @State private var unlockedGlow = false

    private var tileOpacity: Double {
        achievement.isUnlocked ? 1 : 0.62
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
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .offset(x: 18, y: -17)
                            .opacity(unlockedGlow ? 1 : 0.52)
                            .shadow(color: .white.opacity(unlockedGlow ? 1 : 0.45), radius: unlockedGlow ? 10 : 4)
                    }
                }
                .frame(width: 42, height: 42)
                .shadow(color: achievement.isUnlocked ? achievement.color.opacity(unlockedGlow ? 0.86 : 0.34) : .clear, radius: unlockedGlow ? 20 : 10)

                Spacer()

                Text(achievement.progressText)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(achievement.isUnlocked ? .appAccentText : .appMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(achievement.isUnlocked ? achievement.color : achievement.color.opacity(0.07)))
                    .shadow(color: achievement.isUnlocked ? achievement.color.opacity(unlockedGlow ? 0.48 : 0.20) : .clear, radius: unlockedGlow ? 12 : 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.appText.opacity(tileOpacity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(achievement.subtitle)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineLimit(2)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .shadow(color: achievement.isUnlocked ? achievement.color.opacity(unlockedGlow ? 0.30 : 0.12) : .clear, radius: unlockedGlow ? 18 : 9, x: 0, y: 7)
        .onAppear {
            guard achievement.isUnlocked else { return }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                unlockedGlow = true
            }
        }
    }
}

private struct StatsAchievementDetailSheet: View {
    let achievement: StatsAchievement

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
                        Text(achievement.title)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.appText)

                        Text(achievement.subtitle)
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundColor(achievement.color)
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
    let animateStreakFlame: Bool

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
                            .font(.system(size: animateStreakFlame ? 68 : 60, weight: .black))
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
                            .scaleEffect(animateStreakFlame ? 1.06 : 0.95)
                            .rotationEffect(.degrees(animateStreakFlame ? 2.5 : -2))
                            .shadow(color: Color.red.opacity(animateStreakFlame ? 0.82 : 0.38), radius: animateStreakFlame ? 20 : 10)

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
                    title: "kcal",
                    value: "\(Int(stat.consumed))/\(Int(stat.target))",
                    isOn: stat.calorieWin,
                    color: .neonGreen
                )
                StatsDayMetricPill(
                    title: "prot",
                    value: "\(Int(stat.protein))/\(Int(stat.proteinTarget))g",
                    isOn: stat.proteinWin,
                    color: .neonCyan
                )
                StatsDayMetricPill(
                    title: "steps",
                    value: "\(StatsFormatters.compactWholeSteps(stat.effectiveSteps)) / 10k",
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7, weight: .heavy))
                .foregroundColor(isOn ? color : .gray)
                .tracking(0.5)

            Text(value)
                .font(.system(size: disablesValueAnimation ? 10 : 11, weight: .heavy))
                .foregroundColor(.white.opacity(isOn ? 0.92 : 0.58))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .contentTransition(.identity)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .animation(nil, value: value)
                .id(disablesValueAnimation ? value : "stable-value")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isOn ? color.opacity(0.12) : Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOn ? color.opacity(0.20) : Color.white.opacity(0.055), lineWidth: 1)
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

                Text("\(Int(stat.consumed)) / \(Int(stat.target)) kcal")
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
