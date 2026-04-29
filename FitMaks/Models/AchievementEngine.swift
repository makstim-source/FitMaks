import Foundation
import SwiftUI

enum StatsAchievementFamily {
    case core
    case chaos

    var label: String {
        switch self {
        case .core:
            return "Core"
        case .chaos:
            return "Side quest"
        }
    }
}

enum StatsAchievementRarity: Int {
    case easy
    case medium
    case hard
    case legendary

    var label: String {
        switch self {
        case .easy:
            return "Easy"
        case .medium:
            return "Medium"
        case .hard:
            return "Hard"
        case .legendary:
            return "Legendary"
        }
    }
}

struct StatsAchievement: Identifiable {
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    let threshold: Int
    let current: Int
    let color: Color
    let unit: StatsAchievementUnit
    let family: StatsAchievementFamily
    let rarity: StatsAchievementRarity

    var id: String { title }
    var isUnlocked: Bool { current >= threshold }
    var progress: Double { min(Double(current) / Double(max(threshold, 1)), 1) }
    var progressText: String { isUnlocked ? "Unlocked" : "\(unit.format(min(current, threshold)))/\(unit.format(threshold))" }
    var currentText: String { "\(unit.format(min(current, threshold))) of \(unit.format(threshold))" }
}

struct StatsAchievementCollection {
    let core: [StatsAchievement]
    let chaos: [StatsAchievement]

    var all: [StatsAchievement] { core + chaos }

    var orderedChaos: [StatsAchievement] {
        chaos.sorted(by: StatsAchievementCollection.compareChaos)
    }

    private static func compareChaos(_ lhs: StatsAchievement, _ rhs: StatsAchievement) -> Bool {
        if lhs.isUnlocked != rhs.isUnlocked {
            return !lhs.isUnlocked && rhs.isUnlocked
        }

        if lhs.progress != rhs.progress {
            return lhs.progress > rhs.progress
        }

        if lhs.rarity.rawValue != rhs.rarity.rawValue {
            return lhs.rarity.rawValue > rhs.rarity.rawValue
        }

        if lhs.current != rhs.current {
            return lhs.current > rhs.current
        }

        return lhs.title < rhs.title
    }
}

enum StatsAchievementUnit {
    case days
    case steps
    case times
    case sessions

    func format(_ value: Int) -> String {
        switch self {
        case .days:
            return "\(value)d"
        case .steps:
            return compactWholeSteps(value)
        case .times:
            return "\(value)x"
        case .sessions:
            return "\(value)"
        }
    }

    private func compactWholeSteps(_ value: Int) -> String {
        guard value >= 1000 else {
            return "\(value)"
        }

        return "\(Int((Double(value) / 1000).rounded()))k"
    }
}

private struct AchievementFoodDaySummary {
    let mealCount: Int
    let searchableText: String

    func contains(_ fragment: String) -> Bool {
        searchableText.contains(fragment)
    }

    func containsAny(_ fragments: [String]) -> Bool {
        fragments.contains(where: contains)
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

    static func currentStreak(
        in days: [DayProgress],
        skipIncompleteToday: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current,
        predicate: (DayProgress) -> Bool
    ) -> Int {
        let sortedDays = days.sorted(by: { $0.date < $1.date })
        var streak = 0

        for day in sortedDays.reversed() {
            if skipIncompleteToday && calendar.isDate(day.date, inSameDayAs: now) && !predicate(day) {
                continue
            }

            if predicate(day) {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    static func effectiveSteps(in days: [DayProgress]) -> Int {
        Int(days.map(\.effectiveSteps).reduce(0, +).rounded())
    }

    static func achievements(
        last30Stats: [DayProgress],
        recentSevenDayStats: [DayProgress],
        foodEntries: [FoodEntry] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [StatsAchievement] {
        achievementCollection(
            last30Stats: last30Stats,
            recentSevenDayStats: recentSevenDayStats,
            foodEntries: foodEntries,
            now: now,
            calendar: calendar
        ).all
    }

    static func achievementCollection(
        last30Stats: [DayProgress],
        recentSevenDayStats: [DayProgress],
        foodEntries: [FoodEntry] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StatsAchievementCollection {
        let currentPerfectStreak30 = currentPerfectStreak(
            in: last30Stats,
            now: now,
            calendar: calendar
        )
        let currentProteinStreak30 = currentStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        ) { $0.proteinWin }
        let currentCalorieStreak30 = currentStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        ) { $0.calorieWin }
        let currentSevenDayEffectiveSteps = effectiveSteps(in: recentSevenDayStats)
        let last30IDs = Set(last30Stats.map { dayID(for: $0.date, calendar: calendar) })
        let recentSevenIDs = Set(recentSevenDayStats.map { dayID(for: $0.date, calendar: calendar) })
        let foodSummary30 = foodSummaries(for: foodEntries, matching: last30IDs, calendar: calendar)
        let foodSummary7 = foodSummaries(for: foodEntries, matching: recentSevenIDs, calendar: calendar)
        let sorted30 = last30Stats.sorted(by: { $0.date < $1.date })

        let chickenInvestorDays = foodSummary30.values.filter { $0.contains("chicken") }.count
        let chickenRiceDays = foodSummary30.values.filter { summary in
            summary.contains("chicken") && summary.contains("rice")
        }.count
        let proteinShakeDays = foodSummary30.values.filter { summary in
            summary.containsAny(["whey", "protein shake", "protein drink", "protein yogurt", "protein pudding"])
        }.count
        let saladDays = foodSummary30.values.filter { summary in
            summary.containsAny(["salad", "cucumber", "lettuce"])
        }.count
        let riceDisciplineStreak = currentStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        ) { day in
            let summary = foodSummary30[dayID(for: day.date, calendar: calendar)]
            return day.isPerfect && (summary?.mealCount ?? 0) >= 2
        }
        let preciseCalorieDays = last30Stats.filter { day in
            guard day.hasFood, day.target > 0 else {
                return false
            }

            return abs(day.consumed - day.target) <= max(day.target * 0.01, 15)
        }.count
        let proteinGoblinDays = last30Stats.filter { day in
            day.hasFood && day.protein >= (day.proteinTarget + 20)
        }.count
        let recentGymSessions = recentSevenDayStats.filter { $0.mode.hasGym }.count
        let recentCardioSessions = recentSevenDayStats.filter { $0.mode.hasCardio }.count
        let loggedDamageCount = last30Stats.filter { day in
            day.hasFood && day.consumed > day.calorieGraceLimit
        }.count
        let backOnTrackCount = backOnTrackDays(in: sorted30)
        let loggingStreak = currentStreak(
            in: last30Stats,
            skipIncompleteToday: true,
            now: now,
            calendar: calendar
        ) { $0.hasFood }
        let logMilestone = nextMilestone(for: loggingStreak, milestones: [7, 14])
        let ateLikeAnAdultDays = recentSevenDayStats.filter { day in
            let summary = foodSummary7[dayID(for: day.date, calendar: calendar)]
            return day.calorieWin && day.proteinWin && (summary?.mealCount ?? 0) >= 2
        }.count
        let fridgeRestraintDays = last30Stats.filter { day in
            let summary = foodSummary30[dayID(for: day.date, calendar: calendar)]
            return day.calorieWin && (summary?.mealCount ?? 0) >= 4
        }.count
        let survivedLegDayCount = last30Stats.filter { day in
            day.mode.hasGym && day.stepWin && day.proteinWin
        }.count
        let perfectChillDays = last30Stats.filter { day in
            day.mode == .chill && day.isPerfect
        }.count
        let cardioGymDays = last30Stats.filter { $0.mode == .cardioGym }.count
        let weekendPerfectDays = last30Stats.filter { day in
            day.isPerfect && calendar.isDateInWeekend(day.date)
        }.count
        let doubleScoopDays = last30Stats.filter { day in
            day.hasFood && day.protein >= (day.proteinTarget + 40)
        }.count
        let macroSniperDays = last30Stats.filter { day in
            guard day.hasFood, day.target > 0 else {
                return false
            }

            let calorieDelta = abs(day.target - day.consumed)
            let proteinDelta = max(day.proteinMinimum - day.protein, 0)
            return calorieDelta <= max(day.target * 0.01, 15) && proteinDelta <= 5
        }.count

        let core: [StatsAchievement] = [
            StatsAchievement(
                title: "7-Day Flame",
                subtitle: "Perfect days in a row",
                detail: "Close 7 perfect days in a row. A perfect day means calories are inside target grace, protein is closed, and movement is done.",
                icon: "flame.fill",
                threshold: weeklyPerfectTarget,
                current: currentPerfectStreak30,
                color: .fitOrange,
                unit: .days,
                family: .core,
                rarity: .medium
            ),
            StatsAchievement(
                title: "14-Day Trophy",
                subtitle: "14 perfect days in a row",
                detail: "Two full weeks of perfect days without breaking the chain. This is the long-game consistency trophy.",
                icon: "trophy.fill",
                threshold: 14,
                current: currentPerfectStreak30,
                color: .yellow,
                unit: .days,
                family: .core,
                rarity: .hard
            ),
            StatsAchievement(
                title: "Monthly Crown",
                subtitle: "30-day perfect streak",
                detail: "The big one: 30 perfect days in a row. Calories, protein, and movement all closed for a full month.",
                icon: "crown.fill",
                threshold: 30,
                current: currentPerfectStreak30,
                color: .neonGreen,
                unit: .days,
                family: .core,
                rarity: .legendary
            ),
            StatsAchievement(
                title: "Protein Statue",
                subtitle: "7 protein closes in a row",
                detail: "Close your protein target 7 days in a row. The target includes the 3% grace so tiny measurement errors do not punish you.",
                icon: "figure.strengthtraining.traditional",
                threshold: weeklyPerfectTarget,
                current: currentProteinStreak30,
                color: .neonCyan,
                unit: .days,
                family: .core,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Deficit Medal",
                subtitle: "7 calorie wins in a row",
                detail: "Stay inside your calorie target for 7 days in a row. The app still respects the 3% grace window for normal AI estimation noise.",
                icon: "medal.fill",
                threshold: weeklyPerfectTarget,
                current: currentCalorieStreak30,
                color: .neonGreen,
                unit: .days,
                family: .core,
                rarity: .medium
            ),
            StatsAchievement(
                title: "70k Step Vault",
                subtitle: "70k steps in last 7 days",
                detail: "Reach 70,000 effective steps across the last 7 days. Gym step credit counts here too, because lifters deserve a fair movement path.",
                icon: "shoeprints.fill",
                threshold: stepVaultTarget,
                current: currentSevenDayEffectiveSteps,
                color: .yellow,
                unit: .steps,
                family: .core,
                rarity: .hard
            )
        ]

        let chaos: [StatsAchievement] = [
            StatsAchievement(
                title: "Chicken Breast Investor",
                subtitle: "Log chicken on 10 different days",
                detail: "Your portfolio is dry, high-protein, and extremely serious. Log chicken on 10 separate days inside the last 30 days.",
                icon: "chart.line.uptrend.xyaxis",
                threshold: 10,
                current: chickenInvestorDays,
                color: .yellow,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Chicken, Rice, Repeat",
                subtitle: "Log chicken + rice on 5 days",
                detail: "This is not variety. This is a system. Log a day that contains both chicken and rice 5 different times.",
                icon: "arrow.triangle.2.circlepath.circle.fill",
                threshold: 5,
                current: chickenRiceDays,
                color: .yellow,
                unit: .days,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Rice & Discipline",
                subtitle: "3 clean multi-meal days in a row",
                detail: "Close 3 perfect days in a row while logging at least 2 meals each day. Boring meals. Beautiful consequences.",
                icon: "takeoutbag.and.cup.and.straw.fill",
                threshold: 3,
                current: riceDisciplineStreak,
                color: .neonGreen,
                unit: .days,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Calorie Accountant",
                subtitle: "Land near target 3 times",
                detail: "Finish 3 different days within roughly 1% of your calorie target. Every calorie had paperwork.",
                icon: "function",
                threshold: 3,
                current: preciseCalorieDays,
                color: .fitOrange,
                unit: .days,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Protein Goblin",
                subtitle: "Overshoot protein by 20g on 5 days",
                detail: "Beat your protein target by at least 20g on 5 different days. Sneaky gains behavior.",
                icon: "drop.fill",
                threshold: 5,
                current: proteinGoblinDays,
                color: .neonCyan,
                unit: .days,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Whey Too Serious",
                subtitle: "Log protein shakes on 7 days",
                detail: "Whey, protein drink, protein yogurt, pudding, whatever. If it screams convenience and protein, it counts. Hit 7 separate days.",
                icon: "bolt.circle.fill",
                threshold: 7,
                current: proteinShakeDays,
                color: .neonCyan,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Gym Rat Lite",
                subtitle: "3 gym sessions in 7 days",
                detail: "Hit gym mode 3 times inside the current 7-day window. Not fully feral yet, but definitely heading there.",
                icon: "dumbbell.fill",
                threshold: 3,
                current: recentGymSessions,
                color: .yellow,
                unit: .sessions,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Cardio Addict",
                subtitle: "3 cardio sessions in 7 days",
                detail: "Hit cardio mode 3 times inside the current 7-day window. Suspicious amount of sweat-based decision making.",
                icon: "figure.run",
                threshold: 3,
                current: recentCardioSessions,
                color: .neonCyan,
                unit: .sessions,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Ate Like an Adult",
                subtitle: "5 solid days in the last 7",
                detail: "Close calories and protein with at least 2 logged meals on 5 of the last 7 days. Calm, grown-up consistency.",
                icon: "checkmark.seal.fill",
                threshold: 5,
                current: ateLikeAnAdultDays,
                color: .neonGreen,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Greens for Optics",
                subtitle: "Log salad-style food on 5 days",
                detail: "Salad, cucumber, lettuce, visual responsibility. Log greens on 5 separate days and pretend this was always the plan.",
                icon: "leaf.circle.fill",
                threshold: 5,
                current: saladDays,
                color: .neonGreen,
                unit: .days,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Logged the Damage",
                subtitle: "Log a day that went over",
                detail: "Honesty badge. Log a day that went over your calorie grace window instead of pretending it never happened.",
                icon: "receipt.fill",
                threshold: 1,
                current: loggedDamageCount,
                color: .fitOrange,
                unit: .times,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Back on Track, Baby",
                subtitle: "Bounce back the next day",
                detail: "After a failed logged day, hit a perfect day immediately after. Recovery beats drama.",
                icon: "arrow.uturn.forward.circle.fill",
                threshold: 1,
                current: backOnTrackCount,
                color: .neonGreen,
                unit: .times,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "No Missed Log",
                subtitle: logMilestone == 7
                    ? "7 days in a row with a food log"
                    : "Next ladder: 14 logged days in a row",
                detail: logMilestone == 7
                    ? "Log at least one food entry every day for 7 straight days. Hit that, and the badge ladder upgrades itself to the 14-day version."
                    : "You cleared the 7-day checkpoint. Next: log at least one food entry every day for 14 straight days.",
                icon: "calendar.badge.clock",
                threshold: logMilestone,
                current: loggingStreak,
                color: .yellow,
                unit: .days,
                family: .chaos,
                rarity: .hard
            ),
            StatsAchievement(
                title: "Didn’t Eat the Whole Fridge",
                subtitle: "Stay in target on 3 big food days",
                detail: "Log at least 4 food entries and still finish inside calorie target on 3 different days. Appetite had ideas. You had boundaries.",
                icon: "refrigerator.fill",
                threshold: 3,
                current: fridgeRestraintDays,
                color: .neonGreen,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Chill, But Dangerous",
                subtitle: "3 perfect chill days",
                detail: "No cardio badge, no gym badge, no circus. Just three clean chill-mode days that still got everything done.",
                icon: "moon.stars.fill",
                threshold: 3,
                current: perfectChillDays,
                color: .fitOrange,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Survived Leg Day",
                subtitle: "Gym + steps + protein on the same day",
                detail: "Close gym mode, movement, and protein together. Your legs may be ruined, but the day still counted.",
                icon: "figure.strengthtraining.traditional",
                threshold: 1,
                current: survivedLegDayCount,
                color: .fitOrange,
                unit: .times,
                family: .chaos,
                rarity: .easy
            ),
            StatsAchievement(
                title: "Weekend Damage Control",
                subtitle: "2 perfect weekend days",
                detail: "Close 2 Saturday or Sunday days clean. Chaos may live on weekends, but it does not have to own them.",
                icon: "sparkles.rectangle.stack.fill",
                threshold: 2,
                current: weekendPerfectDays,
                color: .yellow,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Two-A-Day Menace",
                subtitle: "Cardio + gym on 2 days",
                detail: "Light up both cardio and gym on 2 different days. This is not balance. This is theater.",
                icon: "bolt.heart.fill",
                threshold: 2,
                current: cardioGymDays,
                color: .neonCyan,
                unit: .days,
                family: .chaos,
                rarity: .hard
            ),
            StatsAchievement(
                title: "Double Scoop Behavior",
                subtitle: "Overshoot protein by 40g on 2 days",
                detail: "Some people close protein. Some escalate. Beat the protein target by at least 40g on 2 different days.",
                icon: "drop.circle.fill",
                threshold: 2,
                current: doubleScoopDays,
                color: .neonCyan,
                unit: .days,
                family: .chaos,
                rarity: .medium
            ),
            StatsAchievement(
                title: "Still Not Shredded, But Closer",
                subtitle: "Macro sniper 3 times",
                detail: "Finish 3 days with calories extremely close to target while also closing protein. Not dramatic. Just surgical.",
                icon: "scope",
                threshold: 3,
                current: macroSniperDays,
                color: .neonGreen,
                unit: .days,
                family: .chaos,
                rarity: .medium
            )
        ]

        return StatsAchievementCollection(core: core, chaos: chaos)
    }

    private static func backOnTrackDays(in days: [DayProgress]) -> Int {
        guard days.count > 1 else {
            return 0
        }

        var count = 0

        for index in 1..<days.count {
            let previous = days[index - 1]
            let current = days[index]

            if previous.hasFood && !previous.isPerfect && current.isPerfect {
                count += 1
            }
        }

        return count
    }

    private static func nextMilestone(for current: Int, milestones: [Int]) -> Int {
        for milestone in milestones where current <= milestone {
            return milestone
        }

        return milestones.last ?? 1
    }

    private static func dayID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func foodSummaries(
        for foodEntries: [FoodEntry],
        matching dayIDs: Set<String>,
        calendar: Calendar
    ) -> [String: AchievementFoodDaySummary] {
        var grouped: [String: [FoodEntry]] = [:]

        for entry in foodEntries {
            let id = dayID(for: entry.date, calendar: calendar)
            guard dayIDs.contains(id) else {
                continue
            }

            grouped[id, default: []].append(entry)
        }

        return grouped.mapValues { entries in
            let searchableText = entries
                .map { "\($0.name) \($0.ingredients)" }
                .joined(separator: " ")
                .lowercased()

            return AchievementFoodDaySummary(
                mealCount: entries.count,
                searchableText: searchableText
            )
        }
    }
}
