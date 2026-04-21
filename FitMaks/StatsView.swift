import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) var dismiss

    var allFoodEntries: [FoodEntry]
    var allSetups: [DailySetup]
    var baseCalories: Double
    var baseProtein: Double

    @State private var weeklySteps: [String: Double] = [:]
    @State private var showBars = false
    @State private var animateStreakFlame = false
    @State private var weekOffset = 0

    private let stepTarget: Double = DayProgressEngine.defaultStepTarget

    typealias WeekStat = DayProgress

    var dateRangeText: String {
        if weekOffset == 0 { return "Last 7 Days" }
        if weekOffset == 1 { return "Previous 7 Days" }
        return "\(weekOffset + 1) Blocks Ago"
    }

    var stats: [WeekStat] {
        let calendar = Calendar.current
        let startDaysAgo = weekOffset * 7

        let result = (0..<7).map { index in
            let date = calendar.date(byAdding: .day, value: -(index + startDaysAgo), to: Date()) ?? Date()
            return stat(for: date)
        }

        return result.reversed()
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
        DayProgressEngine.currentPerfectStreak(in: last30Stats)
    }

    var bestPerfectStreak30: Int {
        DayProgressEngine.bestPerfectStreak(in: last30Stats, skipIncompleteToday: true)
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
                        StatsWeekSwitcher(
                            dateRangeText: dateRangeText,
                            weekDateRange: weekDateRange,
                            weekOffset: $weekOffset
                        )
                        StatsHeroScoreCard(
                            currentPerfectStreak: currentPerfectStreak,
                            bestPerfectStreak30: bestPerfectStreak30,
                            perfectDays30: perfectDays30,
                            animateStreakFlame: animateStreakFlame
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
                        StatsFuelChart(stats: stats, showBars: showBars)
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
                animateBars()
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    animateStreakFlame = true
                }
            }
            .onChange(of: weekOffset) { _, _ in
                animateBars()
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }

    private var weekDateRange: String {
        guard let first = stats.first?.date, let last = stats.last?.date else {
            return ""
        }

        return "\(StatsFormatters.shortDay(first)) - \(StatsFormatters.shortDay(last))"
    }

    private func stat(for date: Date) -> WeekStat {
        let calendar = Calendar.current
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let mode = DayMode.fromStoredValue(allSetups.first(where: { $0.dateID == dateID })?.mode)
        let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }

        return DayProgressEngine.progress(
            date: date,
            foodEntries: dayFood,
            mode: mode,
            baseCalories: baseCalories,
            baseProtein: baseProtein,
            steps: weeklySteps[dateID] ?? 0,
            stepTarget: stepTarget
        )
    }

    private func animateBars() {
        showBars = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                showBars = true
            }
        }
    }
}

private struct StatsWeekSwitcher: View {
    let dateRangeText: String
    let weekDateRange: String
    @Binding var weekOffset: Int

    var body: some View {
        HStack {
            Button(action: { withAnimation(.spring()) { weekOffset += 1 } }) {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .foregroundColor(.neonGreen)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }

            Spacer()

            VStack(spacing: 3) {
                Text(dateRangeText)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)

                Text(weekDateRange)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
            }

            Spacer()

            Button(action: { withAnimation(.spring()) { weekOffset -= 1 } }) {
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
                    .foregroundColor(weekOffset > 0 ? .neonGreen : .appMuted)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .disabled(weekOffset == 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
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

private struct StatsMetricGrid: View {
    let calorieWins: Int
    let proteinWins: Int
    let stepWins: Int
    let weeklyScore: Int
    let avgCalories: Double
    let totalSteps: Double

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            StatsMetricCard(icon: "leaf.fill", title: "Calorie wins", value: "\(calorieWins)/7", subtitle: AppRules.calorieGraceLabel, color: .neonGreen)
            StatsMetricCard(icon: "drop.fill", title: "Protein closes", value: "\(proteinWins)/7", subtitle: AppRules.completionGraceLabel, color: .neonCyan)
            StatsMetricCard(icon: "shoeprints.fill", title: "10k days", value: "\(stepWins)/7", subtitle: "\(StatsFormatters.compactSteps(totalSteps)) total", color: .yellow)
            StatsMetricCard(icon: "chart.line.uptrend.xyaxis", title: "Window score", value: "\(weeklyScore)%", subtitle: "\(Int(avgCalories)) kcal avg", color: .orange)
        }
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
    let showBars: Bool

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
                    StatsCalorieBalanceRow(stat: stat, showBars: showBars)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
    }
}

private struct StatsChallengeCard: View {
    let currentPerfectStreak: Int
    let remainingChecks: Int

    private var title: String {
        currentPerfectStreak == 0 ? "Start the next streak." : "Keep the chain alive."
    }

    private var text: String {
        if currentPerfectStreak == 0 {
            return "A missed day does not kill the week. Close calories, protein, and 10k once to light the chain again."
        }

        return "Today is not a test of the whole week. It is just the next link: calories, protein, 10k."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.neonCyan.opacity(0.14))
                Image(systemName: remainingChecks == 0 ? "crown.fill" : "scope")
                    .font(.title2)
                    .foregroundColor(remainingChecks == 0 ? .yellow : .neonCyan)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.neonCyan.opacity(0.13), Color.black.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.neonCyan.opacity(0.18), lineWidth: 1))
    }
}

private struct StatsScorePill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.black.opacity(0.55))
                Text(value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.12)))
    }
}

private struct StatsMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.13)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(value)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.16), lineWidth: 1))
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
                    value: "\(StatsFormatters.compactWholeSteps(stat.effectiveSteps))/10k",
                    isOn: stat.stepWin,
                    color: stat.stepBonus > 0 ? .fitOrange : .yellow
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7, weight: .heavy))
                .foregroundColor(isOn ? color : .gray)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white.opacity(isOn ? 0.92 : 0.58))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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
    let showBars: Bool

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
                        .frame(width: hasFood ? max(CGFloat(8), proxy.size.width * CGFloat(showBars ? fillRatio : 0.04)) : 8)
                }
            }
            .frame(height: 8)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 17).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(statusColor.opacity(hasFood ? 0.22 : 0.10), lineWidth: 1))
    }
}

private struct StatsBadgeChip: View {
    let text: String
    let isOn: Bool
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundColor(isOn ? .black : .gray)
            .frame(width: 26, height: 22)
            .background(Capsule().fill(isOn ? color : Color.white.opacity(0.07)))
            .shadow(color: isOn ? color.opacity(0.45) : .clear, radius: 7)
    }
}

private enum StatsFormatters {
    static func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    static func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    static func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func compactSteps(_ value: Double) -> String {
        guard value >= 1000 else { return "\(Int(value.rounded()))" }

        let thousands = value / 1000
        if thousands >= 10 || thousands.rounded() == thousands {
            return "\(Int(thousands.rounded()))k"
        }

        return String(format: "%.1fk", thousands)
    }

    static func compactWholeSteps(_ value: Double) -> String {
        guard value >= 1000 else { return "\(Int(value.rounded()))" }
        return "\(Int((value / 1000).rounded()))k"
    }
}
