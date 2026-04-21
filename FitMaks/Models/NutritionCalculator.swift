import Foundation

enum NutritionCalculator {
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
