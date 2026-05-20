import SwiftUI

struct StatsMetricGrid: View {
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

struct StatsLast7DaysReportButton: View {
    let dateRange: String
    let weeklyScore: Int
    let perfectDays: Int
    let calorieWins: Int
    let proteinWins: Int
    let stepWins: Int
    let scoreColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last 7 days report")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.appText)

                    Text(dateRange)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.appMuted)

                    Text("\(weeklyScore)% score · \(perfectDays)/7 perfect days")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(scoreColor)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(scoreColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                scoreColor.opacity(0.16),
                                Color.appSurface,
                                Color.appSurface.opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(scoreColor.opacity(0.24), lineWidth: 1)
                    )
            )
            .shadow(color: scoreColor.opacity(0.12), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct StatsChallengeCard: View {
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
        let light = isLightAppTheme()

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
                    .foregroundColor(.appText)

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(light ? .appMuted : .gray)
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
                        colors: [Color.neonCyan.opacity(0.13), Color.appElevated],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.neonCyan.opacity(0.18), lineWidth: 1))
    }
}

struct StatsScorePill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        let light = isLightAppTheme()
        let titleColor = light ? Color.appMuted : Color.white.opacity(0.66)
        let valueColor = light ? Color.appText : Color.white

        HStack(spacing: 7) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(titleColor)
                Text(value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(valueColor)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Capsule().fill(light ? Color.appSurface.opacity(0.92) : Color.appElevated))
        .overlay(
            Capsule()
                .stroke(light ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)
        )
    }
}

struct StatsMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.13)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(light ? .appMuted : .gray)

                Text(value)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.appText)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(light ? .appMuted : .gray)
                    .lineLimit(1)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.16), lineWidth: 1))
    }
}

struct StatsBadgeChip: View {
    let text: String
    let isOn: Bool
    let color: Color

    var body: some View {
        let light = isLightAppTheme()

        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundColor(isOn ? .black : (light ? .appMuted : .gray))
            .frame(width: 26, height: 22)
            .background(Capsule().fill(isOn ? color : (light ? Color.appSurface : Color.appBorder)))
            .shadow(color: isOn ? color.opacity(0.45) : .clear, radius: 7)
            .overlay(
                Capsule()
                    .stroke(light && !isOn ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)
            )
    }
}

enum StatsFormatters {
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
