import SwiftUI

enum WeightChartRange: CaseIterable, Identifiable {
    case days30
    case days90
    case days180

    var id: Int { days }

    var days: Int {
        switch self {
        case .days30:
            return 30
        case .days90:
            return 90
        case .days180:
            return 180
        }
    }

    var title: String {
        switch self {
        case .days30:
            return "30D"
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
        switch self {
        case .weight:
            return .neonGreen
        case .fat:
            return .fitOrange
        case .muscle:
            return .neonCyan
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
