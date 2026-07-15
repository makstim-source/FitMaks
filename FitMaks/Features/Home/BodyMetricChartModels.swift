import SwiftUI

enum WeightChartRange: CaseIterable, Identifiable {
    case days14
    case days30
    case days60
    case days90
    case days180

    var id: Int { days }

    var days: Int {
        switch self {
        case .days14:
            return 14
        case .days30:
            return 30
        case .days60:
            return 60
        case .days90:
            return 90
        case .days180:
            return 180
        }
    }

    var title: String {
        switch self {
        case .days14:
            return "14D"
        case .days30:
            return "30D"
        case .days60:
            return "60D"
        case .days90:
            return "90D"
        case .days180:
            return "180D"
        }
    }
}

enum BodyChartMetric: CaseIterable, Identifiable {
    case weight
    case fat
    case muscle

    var id: String { title }

    var title: String {
        switch self {
        case .weight:
            return "Weight"
        case .fat:
            return "Fat"
        case .muscle:
            return "Muscle"
        }
    }

    var emptyName: String {
        switch self {
        case .weight:
            return "weight"
        case .fat:
            return "body fat"
        case .muscle:
            return "muscle"
        }
    }

    var unit: String {
        switch self {
        case .weight:
            return "kg"
        case .fat, .muscle:
            return "%"
        }
    }

    var systemName: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .fat:
            return "flame.fill"
        case .muscle:
            return "figure.strengthtraining.traditional"
        }
    }

    var color: Color {
        let light = isLightAppTheme()

        switch self {
        case .weight:
            return light ? Color(red: 0.43, green: 0.53, blue: 0.93) : .neonGreen
        case .fat:
            return light ? Color(red: 0.92, green: 0.53, blue: 0.43) : .fitOrange
        case .muscle:
            return light ? Color(red: 0.41, green: 0.72, blue: 0.64) : .neonCyan
        }
    }

    func value(from entry: BodyMetricEntry) -> Double? {
        switch self {
        case .weight:
            return entry.weightKg
        case .fat:
            return entry.bodyFatPercent
        case .muscle:
            return entry.musclePercent
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .weight:
            return "\(String(format: "%.1f", value)) kg"
        case .fat, .muscle:
            return "\(String(format: "%.1f", value))%"
        }
    }
}
