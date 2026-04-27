import Foundation

struct ActivityOption: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let subtitle: String

    var multiplier: Double {
        NutritionCalculator.activityMultiplier(for: key)
    }
}

struct PendingBodyMetricScan {
    let weightKg: Double
    let bodyFatPercent: Double?
    let musclePercent: Double?
    let waterPercent: Double?
    let visceralFat: Double?
    let metabolicAge: Double?
    let note: String
}

struct GoalSnapshot {
    let gender: String
    let age: Int
    let weight: Double
    let height: Double
    let goal: String
    let activityLevel: String
    let useCustomGoals: Bool
    let customCalories: Double
    let customProtein: Double
}
