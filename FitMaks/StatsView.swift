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
    @State private var weekOffset = 0

    private let stepTarget: Double = 10000

    typealias WeekStat = (
        date: Date,
        consumed: Double,
        target: Double,
        mode: DayMode,
        protein: Double,
        proteinTarget: Double,
        steps: Double
    )

    var dateRangeText: String {
        if weekOffset == 0 { return "This Week" }
        if weekOffset == 1 { return "Last Week" }
        return "\(weekOffset) Weeks Ago"
    }

    var stats: [WeekStat] {
        var result: [WeekStat] = []
        let calendar = Calendar.current
        let startDaysAgo = weekOffset * 7

        for index in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(index + startDaysAgo), to: Date()) ?? Date()
            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let mode = DayMode.fromStoredValue(allSetups.first(where: { $0.dateID == dateID })?.mode)
            let dayFood = allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let consumed = dayFood.reduce(0) { $0 + $1.calories }
            let protein = dayFood.reduce(0) { $0 + $1.protein }

            let targetCalories: Double
            let targetProtein: Double

            switch mode {
            case .chill:
                targetCalories = baseCalories
                targetProtein = baseProtein
            case .padel:
                targetCalories = baseCalories + 500
                targetProtein = baseProtein + 15
            case .gym:
                targetCalories = baseCalories + 300
                targetProtein = baseProtein + 25
            }

            result.append((
                date: date,
                consumed: consumed,
                target: targetCalories,
                mode: mode,
                protein: protein,
                proteinTarget: targetProtein,
                steps: weeklySteps[dateID] ?? 0
            ))
        }

        return result.reversed()
    }

    var calorieWins: Int { stats.filter(calorieWin).count }
    var proteinWins: Int { stats.filter(proteinWin).count }
    var stepWins: Int { stats.filter(stepWin).count }
    var perfectDays: Int { stats.filter(isPerfectDay).count }
    var completedChecks: Int { calorieWins + proteinWins + stepWins }
    var totalChecks: Int { stats.count * 3 }
    var weeklyScore: Int { Int((Double(completedChecks) / Double(max(totalChecks, 1)) * 100).rounded()) }
    var avgCalories: Double { stats.map { $0.consumed }.reduce(0, +) / Double(max(stats.count, 1)) }
    var totalSteps: Double { stats.map { $0.steps }.reduce(0, +) }
    var remainingChecks: Int { max(totalChecks - completedChecks, 0) }

    var bestPerfectRun: Int {
        var best = 0
        var current = 0

        for stat in stats {
            if isPerfectDay(stat) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }

        return best
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 8/255, green: 12/255, blue: 16/255),
                        Color.darkGrey,
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        weekSwitcher
                        heroScoreCard
                        metricGrid
                        weeklyArena
                        fuelChart
                        challengeCard
                    }
                    .padding()
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
            }
            .onChange(of: weekOffset) { _, _ in
                animateBars()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var weekSwitcher: some View {
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
                    .foregroundColor(.white)

                Text(weekDateRange)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: { withAnimation(.spring()) { weekOffset -= 1 } }) {
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
                    .foregroundColor(weekOffset > 0 ? .neonGreen : .gray)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .disabled(weekOffset == 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var heroScoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("WEEK SCORE", systemImage: "bolt.fill")
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
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(weeklyScore)")
                            .font(.system(size: 52, weight: .black))
                        Text("%")
                            .font(.system(size: 20, weight: .black))
                    }
                    .foregroundColor(.black)

                    Text("\(completedChecks)/\(totalChecks) badges")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.62))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.13))

                    Capsule()
                        .fill(Color.black.opacity(0.82))
                        .frame(width: proxy.size.width * CGFloat(Double(weeklyScore) / 100.0))
                }
            }
            .frame(height: 9)

            HStack(spacing: 10) {
                scorePill(title: "Perfect", value: "\(perfectDays)/7", icon: "sparkles")
                scorePill(title: "Best run", value: "\(bestPerfectRun)d", icon: "flame.fill")
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

    private var metricGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            metricCard(icon: "leaf.fill", title: "Calorie wins", value: "\(calorieWins)/7", subtitle: "under daily target", color: .neonGreen)
            metricCard(icon: "drop.fill", title: "Protein closes", value: "\(proteinWins)/7", subtitle: "goal reached", color: .neonCyan)
            metricCard(icon: "shoeprints.fill", title: "10k days", value: "\(stepWins)/7", subtitle: "\(Int(totalSteps)) total steps", color: .yellow)
            metricCard(icon: "chart.line.uptrend.xyaxis", title: "Avg intake", value: "\(Int(avgCalories))", subtitle: "kcal per day", color: .orange)
        }
    }

    private var weeklyArena: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Badges")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)

                Spacer()

                Text("C / P / S")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            }

            ForEach(stats, id: \.date) { stat in
                dayBadgeRow(stat)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var fuelChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fuel Chart")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 10) {
                    chartLegend(color: .neonGreen, text: "kcal")
                    chartLegend(color: .neonCyan, text: "protein")
                    chartLegend(color: .yellow, text: "steps")
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats, id: \.date) { stat in
                    VStack(spacing: 7) {
                        HStack(alignment: .bottom, spacing: 4) {
                            chartBar(
                                value: stat.consumed,
                                target: stat.target,
                                color: stat.consumed > stat.target && stat.consumed > 0 ? .red : .neonGreen
                            )
                            chartBar(value: stat.protein, target: stat.proteinTarget, color: .neonCyan)
                            chartBar(value: stat.steps, target: stepTarget, color: .yellow)
                        }
                        .frame(height: 118, alignment: .bottom)

                        Text(dayName(stat.date))
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var challengeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.neonCyan.opacity(0.14))
                Image(systemName: remainingChecks == 0 ? "crown.fill" : "scope")
                    .font(.title2)
                    .foregroundColor(remainingChecks == 0 ? .yellow : .neonCyan)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(remainingChecks == 0 ? "Perfect sweep." : "Next objective")
                    .font(.headline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

                Text(remainingChecks == 0 ? "This week is clean. Go admire the calendar." : "Collect \(remainingChecks) more badges to beat this week.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
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

    private var scoreMessage: String {
        switch weeklyScore {
        case 85...100:
            return "That is a dangerous week."
        case 60..<85:
            return "Momentum is building."
        case 30..<60:
            return "A few badges unlock the week."
        default:
            return "Start collecting small wins."
        }
    }

    private var weekDateRange: String {
        guard let first = stats.first?.date, let last = stats.last?.date else {
            return ""
        }

        return "\(shortDay(first)) - \(shortDay(last))"
    }

    private func scorePill(title: String, value: String, icon: String) -> some View {
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

    private func metricCard(icon: String, title: String, value: String, subtitle: String, color: Color) -> some View {
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

    private func dayBadgeRow(_ stat: WeekStat) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(dayName(stat.date))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.gray)

                Text(dayNumber(stat.date))
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: 42)

            Text(stat.mode.emoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    badgeChip(text: "C", isOn: calorieWin(stat), color: .neonGreen)
                    badgeChip(text: "P", isOn: proteinWin(stat), color: .neonCyan)
                    badgeChip(text: "S", isOn: stepWin(stat), color: .yellow)
                }

                Text(daySubtitle(stat))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            if isPerfectDay(stat) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.headline)
                    .shadow(color: .yellow.opacity(0.8), radius: 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isPerfectDay(stat) ? Color.neonGreen.opacity(0.13) : Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isPerfectDay(stat) ? Color.yellow.opacity(0.38) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func badgeChip(text: String, isOn: Bool, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundColor(isOn ? .black : .gray)
            .frame(width: 26, height: 22)
            .background(Capsule().fill(isOn ? color : Color.white.opacity(0.07)))
            .shadow(color: isOn ? color.opacity(0.45) : .clear, radius: 7)
    }

    private func chartLegend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private func chartBar(value: Double, target: Double, color: Color) -> some View {
        let ratio = min(max(value / max(target, 1), 0), 1.35)
        let height = showBars && value > 0 ? CGFloat(ratio * 86) : 5

        return RoundedRectangle(cornerRadius: 5)
            .fill(color.opacity(value > 0 ? 0.95 : 0.2))
            .frame(width: 8, height: height)
            .shadow(color: color.opacity(value > 0 ? 0.35 : 0), radius: 7)
    }

    private func calorieWin(_ stat: WeekStat) -> Bool {
        stat.consumed > 0 && stat.consumed <= stat.target
    }

    private func proteinWin(_ stat: WeekStat) -> Bool {
        stat.protein >= stat.proteinTarget
    }

    private func stepWin(_ stat: WeekStat) -> Bool {
        stat.steps >= stepTarget
    }

    private func isPerfectDay(_ stat: WeekStat) -> Bool {
        calorieWin(stat) && proteinWin(stat) && stepWin(stat)
    }

    private func daySubtitle(_ stat: WeekStat) -> String {
        "\(Int(stat.consumed))/\(Int(stat.target)) kcal · \(Int(stat.protein))/\(Int(stat.proteinTarget))g · \(Int(stat.steps)) steps"
    }

    private func animateBars() {
        showBars = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                showBars = true
            }
        }
    }

    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
