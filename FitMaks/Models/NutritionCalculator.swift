import Foundation

enum NutritionCalculator {
    static func recommendedCalories(
        gender: String,
        age: Int,
        weight: Double,
        height: Double,
        activityLevel: String,
        goal: String
    ) -> Double {
        maintenanceCalories(
            gender: gender,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityLevel
        ) + calorieAdjustment(for: goal)
    }

    static func maintenanceCalories(
        gender: String,
        age: Int,
        weight: Double,
        height: Double,
        activityLevel: String
    ) -> Double {
        bmr(gender: gender, age: age, weight: weight, height: height) * activityMultiplier(for: activityLevel)
    }

    static func bmr(gender: String, age: Int, weight: Double, height: Double) -> Double {
        (10.0 * weight) + (6.25 * height) - (5.0 * Double(age)) + (gender == "Male" ? 5.0 : -161.0)
    }

    static func activityMultiplier(for activityLevel: String) -> Double {
        switch activityLevel {
        case "Light":
            return 1.375
        case "Moderate":
            return 1.55
        case "Active":
            return 1.725
        default:
            return 1.2
        }
    }

    static func calorieAdjustment(for goal: String) -> Double {
        switch goal {
        case "Lose Weight":
            return -500
        case "Build Muscle":
            return 500
        default:
            return 0
        }
    }

    static func recommendedProtein(weight: Double, goal: String) -> Double {
        weight * proteinMultiplier(for: goal)
    }

    static func proteinMultiplier(for goal: String) -> Double {
        switch goal {
        case "Lose Weight":
            return 2.0
        case "Build Muscle":
            return 2.2
        default:
            return 1.8
        }
    }

    static func proteinDetail(for goal: String) -> String {
        "\(String(format: "%.1f", proteinMultiplier(for: goal)))g/kg · \(proteinReason(for: goal))"
    }

    private static func proteinReason(for goal: String) -> String {
        switch goal {
        case "Lose Weight":
            return "higher to protect muscle in a deficit"
        case "Build Muscle":
            return "aggressive growth target"
        default:
            return "steady target for maintenance"
        }
    }
}
