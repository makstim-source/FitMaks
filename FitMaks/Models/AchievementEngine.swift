import Foundation
import SwiftUI

struct StatsAchievement: Identifiable {
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    let threshold: Int
    let current: Int
    let color: Color
    let unit: StatsAchievementUnit

    var id: String { title }
    var isUnlocked: Bool { current >= threshold }
    var progress: Double { min(Double(current) / Double(max(threshold, 1)), 1) }
    var progressText: String { isUnlocked ? "Unlocked" : "\(unit.format(min(current, threshold)))/\(unit.format(threshold))" }
    var currentText: String { "\(unit.format(min(current, threshold))) of \(unit.format(threshold))" }
}

enum StatsAchievementUnit {
    case days
    case steps

    func format(_ value: Int) -> String {
        switch self {
        case .days:
            return "\(value)d"
        case .steps:
            return compactWholeSteps(value)
        }
    }

    private func compactWholeSteps(_ value: Int) -> String {
        guard value >= 1000 else {
            return "\(value)"
        }

        return "\(Int((Double(value) / 1000).rounded()))k"
    }
}

enum AchievementEngine {
    static let weeklyPerfectTarget = 7
    static let stepVaultTarget = 70_000

    static func currentPerfectStreak(
        in days: [DayProgress],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        DayProgressEngine.currentPerfectStreak(in: days, now: now, calendar: calendar)
    }

    static func bestPerfectStreak(
        in days: [DayProgress],
        skipIncompleteToday: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        DayProgressEngine.bestPerfectStreak(
            in: days,
            skipIncompleteToday: skipIncompleteToday,
            now: now,
            calendar: calendar
        )
    }

    static func homePerfectStreak(
        in days: [DayProgress],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        min(currentPerfectStreak(in: days, now: now, calendar: calendar), weeklyPerfectTarget)
    }

    static func bestStreak(
        in days: [DayProgress],
        skipIncompleteToday: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current,
        predicate: (DayProgress) -> Bool
    ) -> Int {
        var best = 0
        var current = 0

        for day in days.sorted(by: { $0.date < $1.date }) {
            if skipIncompleteToday && calendar.isDate(day.date, inSameDayAs: now) && !predicate(day) {
                continue
            }

            if predicate(day) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }

        return best
    }

    static func effectiveSteps(in days: [DayProgress]) -> Int {
        Int(days.map(\.effectiveSteps).reduce(0, +).rounded())
    }

    static func achievements(
        last30Stats: [DayProgress],
        recentSevenDayStats: [DayProgress],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [StatsAchievement] {
        let bestPerfectStreak30 = bestPerfectStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        )
        let bestProteinStreak30 = bestStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        ) { $0.proteinWin }
        let bestCalorieStreak30 = bestStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        ) { $0.calorieWin }
        let currentSevenDayEffectiveSteps = effectiveSteps(in: recentSevenDayStats)

        return [
            StatsAchievement(
                title: "7-Day Flame",
                subtitle: "Perfect days in a row",
                detail: "Unlock this by closing 7 perfect days in a row. A perfect day means calories are inside target grace, protein is closed, and movement is done.",
                icon: "flame.fill",
                threshold: weeklyPerfectTarget,
                current: bestPerfectStreak30,
                color: .fitOrange,
                unit: .days
            ),
            StatsAchievement(
                title: "14-Day Trophy",
                subtitle: "14 perfect days in a row",
                detail: "Two full weeks of perfect days without breaking the chain. This is the long-game consistency trophy.",
                icon: "trophy.fill",
                threshold: 14,
                current: bestPerfectStreak30,
                color: .yellow,
                unit: .days
            ),
            StatsAchievement(
                title: "Monthly Crown",
                subtitle: "30-day perfect streak",
                detail: "The big one: 30 perfect days in a row. Calories, protein, and movement all closed for a full month.",
                icon: "crown.fill",
                threshold: 30,
                current: bestPerfectStreak30,
                color: .neonGreen,
                unit: .days
            ),
            StatsAchievement(
                title: "Protein Statue",
                subtitle: "7 protein closes in a row",
                detail: "Close your protein target 7 days in a row. The target includes the 3% grace so tiny measurement errors do not punish you.",
                icon: "figure.strengthtraining.traditional",
                threshold: weeklyPerfectTarget,
                current: bestProteinStreak30,
                color: .neonCyan,
                unit: .days
            ),
            StatsAchievement(
                title: "Deficit Medal",
                subtitle: "7 calorie wins in a row",
                detail: "Stay inside your calorie target for 7 days in a row. The app still respects the 3% grace window for normal AI estimation noise.",
                icon: "medal.fill",
                threshold: weeklyPerfectTarget,
                current: bestCalorieStreak30,
                color: .neonGreen,
                unit: .days
            ),
            StatsAchievement(
                title: "70k Step Vault",
                subtitle: "70k steps in last 7 days",
                detail: "Reach 70,000 effective steps across the last 7 days. Gym step credit counts here too, because lifters deserve a fair movement path.",
                icon: "shoeprints.fill",
                threshold: stepVaultTarget,
                current: currentSevenDayEffectiveSteps,
                color: .yellow,
                unit: .steps
            )
        ]
    }
}
