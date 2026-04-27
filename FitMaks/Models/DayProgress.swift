import Foundation

enum AppRules {
    static let caloriePerfectToleranceRatio: Double = 0.03
    static let completionToleranceRatio: Double = 0.03
    static let weeklyStreakTarget: Double = 7

    static var calorieGraceLabel: String { "+3% calorie grace" }
    static var completionGraceLabel: String { "3% grace" }

    static func calorieGrace(for target: Double) -> Double {
        max(target * caloriePerfectToleranceRatio, 0)
    }

    static func caloriePerfectLimit(for target: Double) -> Double {
        target + calorieGrace(for: target)
    }

    static func completionMinimum(for target: Double) -> Double {
        max(target * (1 - completionToleranceRatio), 0)
    }
}

struct DayTargets: Equatable {
    let baseCalories: Double
    let baseProtein: Double
    let calorieBonus: Double
    let proteinBonus: Double
    let stepBonus: Double
    let steps: Double

    var calories: Double { baseCalories + calorieBonus }
    var protein: Double { baseProtein + proteinBonus }
}

struct DayProgress: Equatable, Identifiable {
    let date: Date
    let consumed: Double
    let target: Double
    let mode: DayMode
    let protein: Double
    let proteinTarget: Double
    let steps: Double
    let uploadedSteps: Double
    let stepBonus: Double
    let stepTarget: Double
    let hasFood: Bool

    var id: Date { date }
    var countedSteps: Double { max(steps, uploadedSteps) }
    var effectiveSteps: Double { countedSteps + stepBonus }

    var calorieGraceLimit: Double {
        AppRules.caloriePerfectLimit(for: target)
    }

    var proteinMinimum: Double {
        AppRules.completionMinimum(for: proteinTarget)
    }

    var stepMinimum: Double {
        AppRules.completionMinimum(for: stepTarget)
    }

    var calorieWin: Bool {
        hasFood && consumed > 0 && consumed <= calorieGraceLimit
    }

    var proteinWin: Bool {
        hasFood && protein >= proteinMinimum
    }

    var stepWin: Bool {
        effectiveSteps >= stepMinimum
    }

    var isPerfect: Bool {
        calorieWin && proteinWin && stepWin
    }

    func isPastDay(relativeTo now: Date = Date(), calendar: Calendar = .current) -> Bool {
        date < calendar.startOfDay(for: now)
    }

    func isPerfectPastDay(relativeTo now: Date = Date(), calendar: Calendar = .current) -> Bool {
        isPastDay(relativeTo: now, calendar: calendar) && isPerfect
    }
}

enum DayProgressEngine {
    static let defaultStepTarget: Double = 10_000
    static let gymStepBonus: Double = 5_000

    static func targets(
        baseCalories: Double,
        baseProtein: Double,
        mode: DayMode,
        trainingCalories: Double = 0,
        stepTarget: Double = defaultStepTarget
    ) -> DayTargets {
        let bonuses = bonuses(for: mode, trainingCalories: trainingCalories)

        return DayTargets(
            baseCalories: baseCalories,
            baseProtein: baseProtein,
            calorieBonus: bonuses.calories,
            proteinBonus: bonuses.protein,
            stepBonus: bonuses.steps,
            steps: stepTarget
        )
    }

    static func progress(
        date: Date,
        foodEntries: [FoodEntry],
        trainingCalories: Double = 0,
        mode: DayMode,
        baseCalories: Double,
        baseProtein: Double,
        steps: Double,
        uploadedSteps: Double = 0,
        stepTarget: Double = defaultStepTarget
    ) -> DayProgress {
        let consumed = foodEntries.reduce(0) { $0 + $1.calories }
        let protein = foodEntries.reduce(0) { $0 + $1.protein }

        return progress(
            date: date,
            consumedCalories: consumed,
            consumedProtein: protein,
            hasFood: !foodEntries.isEmpty,
            mode: mode,
            trainingCalories: trainingCalories,
            baseCalories: baseCalories,
            baseProtein: baseProtein,
            steps: steps,
            uploadedSteps: uploadedSteps,
            stepTarget: stepTarget
        )
    }

    static func progress(
        date: Date,
        consumedCalories: Double,
        consumedProtein: Double,
        hasFood: Bool,
        mode: DayMode,
        trainingCalories: Double = 0,
        baseCalories: Double,
        baseProtein: Double,
        steps: Double,
        uploadedSteps: Double = 0,
        stepTarget: Double = defaultStepTarget
    ) -> DayProgress {
        let targets = targets(
            baseCalories: baseCalories,
            baseProtein: baseProtein,
            mode: mode,
            trainingCalories: trainingCalories,
            stepTarget: stepTarget
        )

        return DayProgress(
            date: date,
            consumed: consumedCalories,
            target: targets.calories,
            mode: mode,
            protein: consumedProtein,
            proteinTarget: targets.protein,
            steps: steps,
            uploadedSteps: uploadedSteps,
            stepBonus: targets.stepBonus,
            stepTarget: targets.steps,
            hasFood: hasFood
        )
    }

    static func currentPerfectStreak(
        in days: [DayProgress],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var count = 0

        for day in days.sorted(by: { $0.date > $1.date }) {
            if calendar.isDate(day.date, inSameDayAs: now) && !day.isPerfect {
                continue
            }

            if day.isPerfect {
                count += 1
            } else {
                break
            }
        }

        return count
    }

    static func bestPerfectStreak(
        in days: [DayProgress],
        skipIncompleteToday: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var best = 0
        var current = 0

        for day in days.sorted(by: { $0.date < $1.date }) {
            if skipIncompleteToday && calendar.isDate(day.date, inSameDayAs: now) && !day.isPerfect {
                continue
            }

            if day.isPerfect {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }

        return best
    }

    static let workoutCalorieCreditRatio: Double = 0.7

    private static func bonuses(for mode: DayMode, trainingCalories: Double = 0) -> (calories: Double, protein: Double, steps: Double) {
        let creditedCardio = trainingCalories > 0
            ? trainingCalories * workoutCalorieCreditRatio
            : 500

        switch mode {
        case .chill:
            return (0, 0, 0)
        case .cardio:
            return (creditedCardio, 15, 0)
        case .gym:
            return (300, 25, gymStepBonus)
        case .cardioGym:
            return (creditedCardio + 300, 40, gymStepBonus)
        }
    }
}
