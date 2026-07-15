import SwiftUI

struct StatsHeroScoreCard: View {
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
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("STREAK MODE", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(light ? .appAccentText.opacity(0.82) : .black.opacity(0.78))
                        .tracking(0.8)

                    Text(scoreMessage)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(.appAccentText)
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
                        .foregroundColor(.appAccentText)
                        .shadow(color: light ? .white.opacity(0.18) : .white.opacity(0.34), radius: 2, x: 0, y: 1)
                    }
                    .frame(width: 104, height: 70, alignment: .trailing)

                    Text("current streak")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(light ? .appMuted : .black.opacity(0.62))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(light ? Color.appSurface.opacity(0.95) : Color.appElevated)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: light
                                    ? [Color.fitOrange.opacity(0.72), Color.neonGreen.opacity(0.82)]
                                    : [Color.appScrim, Color.neonGreen.opacity(0.86)],
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
                    .foregroundColor(light ? .appMuted : .black.opacity(0.62))

                Spacer()

                Text(AppRules.calorieGraceLabel)
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(light ? .appMuted : .black.opacity(0.56))
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
                        colors: light
                            ? [
                                Color(red: 214/255, green: 226/255, blue: 186/255),
                                Color(red: 244/255, green: 225/255, blue: 136/255),
                                Color(red: 213/255, green: 222/255, blue: 242/255)
                            ]
                            : [
                                Color.neonGreen,
                                Color.yellow.opacity(0.92),
                                Color.neonCyan.opacity(0.78)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(light ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)
        )
        .shadow(color: light ? Color.black.opacity(0.06) : Color.neonGreen.opacity(0.26), radius: 24, x: 0, y: 12)
    }
}

struct StatsWeeklyArena: View {
    let stats: [DayProgress]

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Day Streak Board")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)

                Spacer()

                Text("C / P / S")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(light ? .appMuted : .gray)
            }

            ForEach(stats, id: \.date) { stat in
                StatsDayBadgeRow(stat: stat)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
    }
}

struct StatsFuelChart: View {
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

struct StatsDayBadgeRow: View {
    let stat: DayProgress

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(StatsFormatters.dayName(stat.date))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(light ? .appMuted : .gray)

                    Text(StatsFormatters.dayNumber(stat.date))
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.appText)
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
                .fill(
                    stat.isPerfect
                        ? (light ? Color.neonGreen.opacity(0.08) : Color.neonGreen.opacity(0.13))
                        : Color.appSurface
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    stat.isPerfect
                        ? (light ? Color.yellow.opacity(0.24) : Color.yellow.opacity(0.38))
                        : (light ? Color.appBorder.opacity(0.65) : Color.appSurface),
                    lineWidth: 1
                )
        )
    }
}

struct StatsDayMetricPill: View {
    let title: String
    let value: String
    let isOn: Bool
    let color: Color
    var disablesValueAnimation = false
    var forceHighlight = false

    private var highlighted: Bool { isOn || forceHighlight }

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7, weight: .heavy))
                .foregroundColor(highlighted ? color : (light ? .appMuted : .gray))
                .tracking(0.5)

            Text(value)
                .font(.system(size: disablesValueAnimation ? 10 : 11, weight: .heavy))
                .foregroundColor(light ? .appText.opacity(highlighted ? 0.92 : 0.62) : .white.opacity(highlighted ? 0.92 : 0.58))
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
                .fill(highlighted ? color.opacity(light ? 0.09 : 0.12) : Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(highlighted ? color.opacity(light ? 0.16 : 0.20) : (light ? Color.appBorder.opacity(0.65) : Color.appSurface), lineWidth: 1)
        )
    }
}

struct StatsCalorieBalanceRow: View {
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
                        .fill(Color.appBorder)

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
