import SwiftUI

private let fillerWords: Set<String> = ["and", "with", "in", "on", "the", "a", "of", "for", "from", "с", "и", "в", "на", "из", "для", "по", "к", "от", "до"]

func shortFoodName(_ name: String, maxChars: Int = 22) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard trimmed.count > maxChars else { return trimmed }
    let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    var result: [String] = []
    for word in words {
        let candidate = (result + [word]).joined(separator: " ")
        if candidate.count > maxChars { break }
        result.append(word)
    }
    while let last = result.last, fillerWords.contains(last.lowercased()) {
        result.removeLast()
    }
    return result.isEmpty ? String(trimmed.prefix(maxChars)) : result.joined(separator: " ")
}

struct HomeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.appBackgroundStart,
                Color.appBackgroundMid,
                Color.appBackgroundEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.neonCyan.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 45)
                .offset(x: 80, y: -95)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.neonGreen.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: -120, y: 80)
        }
    }
}

struct HomeIconButton: View {
    var systemName: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Color.appSurface)
                        .overlay(Circle().stroke(color.opacity(0.16), lineWidth: 1))
                )
                .shadow(color: color.opacity(0.18), radius: 10)
        }
        .buttonStyle(.plain)
    }
}

struct HomeMetricTile: View {
    var title: String
    var value: String
    var subtitle: String
    var progress: Double
    var bonusProgress: Double = 0
    var bonusColor: Color? = nil
    var color: Color
    var systemName: String

    var body: some View {
        let baseProgress = CGFloat(min(max(progress, 0), 1))
        let combinedProgress = CGFloat(min(max(progress + bonusProgress, 0), 1))
        let highlightColor = bonusColor ?? color

        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)
                .lineLimit(1)

            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.34), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: baseProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.55), radius: combinedProgress >= 1 ? 13 : 6)

                if combinedProgress > baseProgress {
                    Circle()
                        .trim(from: baseProgress, to: combinedProgress)
                        .stroke(
                            highlightColor,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: highlightColor.opacity(0.58), radius: combinedProgress >= 1 ? 13 : 7)
                }

                VStack(spacing: 0) {
                    Image(systemName: systemName)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(color)
                        .padding(.bottom, 1)

                    Text(value)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.appText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(subtitle)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 5)
            }
            .frame(width: 74, height: 74)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.09), lineWidth: 1))
        )
        .accessibilityIdentifier("metric_\(title)")
    }
}

struct HomeDockButton: View {
    var title: String
    var systemName: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appSurface, Color.appElevated],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Circle()
                        .stroke(color.opacity(0.22), lineWidth: 1)
                        .frame(width: 44, height: 44)

                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.92), color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(color: color.opacity(0.22), radius: 10, y: 4)

                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.appMuted)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dock_\(title)")
    }
}

struct HomeMacroSummaryPill: View {
    var title: String
    var value: String
    var subtitle: String = ""
    var progress: Double = 0
    var color: Color
    var systemName: String = ""

    var body: some View {
        let clamped = CGFloat(min(max(progress, 0), 1))

        HStack(spacing: 8) {
            if !systemName.isEmpty {
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.34), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: clamped)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.45), radius: clamped >= 1 ? 5 : 2)
                    Image(systemName: systemName)
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(color)
                }
                .frame(width: 20, height: 20)
            }

            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(color)
                .tracking(0.5)
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.appText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.appSurface.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.16), lineWidth: 1))
        )
    }
}

struct HomeCarbControlCard: View {
    var consumed: Double
    var baseTarget: Double
    var activeTarget: Double

    private var burnThreshold: Double {
        max(min(baseTarget * 0.7, activeTarget), 0)
    }

    private var fuelBonus: Double {
        max(activeTarget - baseTarget, 0)
    }

    private var accentColor: Color {
        if consumed > activeTarget {
            return .red
        }
        if consumed <= burnThreshold {
            return .neonGreen
        }
        if consumed <= baseTarget {
            return .yellow
        }
        return fuelBonus > 0 ? .neonCyan : .yellow
    }

    private var statusLabel: String {
        if consumed > activeTarget {
            return "Over"
        }
        if consumed <= burnThreshold {
            return "Low"
        }
        if consumed <= baseTarget {
            return "Base"
        }
        return fuelBonus > 0 ? "Fuel" : "Near"
    }

    private var helperText: String {
        if fuelBonus > 0 {
            return "base \(Int(baseTarget.rounded()))g · cap \(Int(activeTarget.rounded()))g"
        }
        return "cap \(Int(activeTarget.rounded()))g"
    }

    private var markerProgress: CGFloat {
        guard activeTarget > 0 else { return 0 }
        return CGFloat(min(max(baseTarget / activeTarget, 0), 1))
    }

    private var fillProgress: CGFloat {
        guard activeTarget > 0 else { return 0 }
        return CGFloat(min(max(consumed / activeTarget, 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("CARBS", systemImage: "leaf.fill")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.fitOrange)
                    .tracking(0.65)

                Spacer(minLength: 8)

                Text(statusLabel)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.appAccentText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accentColor))
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(consumed.rounded()))g")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(helperText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let greenWidth = width * min(max(CGFloat(burnThreshold / max(activeTarget, 1)), 0), 1)
                let yellowStart = greenWidth
                let yellowWidth = width * min(max(CGFloat(max(baseTarget - burnThreshold, 0) / max(activeTarget, 1)), 0), 1)
                let cyanStart = width * markerProgress
                let cyanWidth = width * min(max(CGFloat(fuelBonus / max(activeTarget, 1)), 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(Color.neonGreen.opacity(0.20))
                        .frame(width: greenWidth)

                    Capsule()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: yellowWidth)
                        .offset(x: yellowStart)

                    if fuelBonus > 0 {
                        Capsule()
                            .fill(Color.neonCyan.opacity(0.18))
                            .frame(width: cyanWidth)
                            .offset(x: cyanStart)
                    }

                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(6, width * fillProgress))

                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(x: max(0, min(width - 6, width * markerProgress - 3)))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.appSurface.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.13), lineWidth: 1)
                )
        )
    }
}

struct HomeFatControlCard: View {
    var consumed: Double
    var target: Double

    private var lowerBound: Double {
        max(target * 0.85, target - 8)
    }

    private var upperBound: Double {
        max(target * 1.15, lowerBound + 6)
    }

    private var scaleMax: Double {
        max(upperBound * 1.35, 1)
    }

    private var accentColor: Color {
        if consumed < lowerBound {
            return .fitOrange
        }
        if consumed > upperBound {
            return .fitPurple
        }
        return .yellow
    }

    private var statusLabel: String {
        if consumed < lowerBound {
            return "Low"
        }
        if consumed > upperBound {
            return "High"
        }
        return "In range"
    }

    private var helperText: String {
        "zone \(Int(lowerBound.rounded()))-\(Int(upperBound.rounded()))g"
    }

    private var currentProgress: CGFloat {
        CGFloat(min(max(consumed / scaleMax, 0), 1))
    }

    private var zoneStartProgress: CGFloat {
        CGFloat(min(max(lowerBound / scaleMax, 0), 1))
    }

    private var zoneWidthProgress: CGFloat {
        CGFloat(min(max((upperBound - lowerBound) / scaleMax, 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("FAT", systemImage: "circle.inset.filled")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.yellow)
                    .tracking(0.65)

                Spacer(minLength: 8)

                Text(statusLabel)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(statusLabel == "In range" ? .black : .appAccentText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accentColor))
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(consumed.rounded()))g")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(helperText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: width * zoneWidthProgress)
                        .offset(x: width * zoneStartProgress)

                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: accentColor.opacity(0.32), radius: 3)
                        .offset(x: max(0, min(width - 6, width * currentProgress - 3)))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.appSurface.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.13), lineWidth: 1)
                )
        )
    }
}

struct HomeStatsPanelBackground: View {
    var isPerfectPastDay: Bool

    var body: some View {
        if isPerfectPastDay {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.neonGreen.opacity(0.16),
                            Color.neonGreen.opacity(0.06),
                            Color.appElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.neonGreen.opacity(0.34),
                                    Color.neonGreen.opacity(0.12),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 72
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 10)
                        .offset(x: 26, y: -30)
                }
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSurface)
        }
    }
}

struct HomeStatsPanelCelebrationOverlay: View {
    var isPerfectPastDay: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if isPerfectPastDay {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))

                    Text("PERFECT DAY")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.7)
                }
                .foregroundColor(.appAccentText)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.neonGreen.opacity(0.99),
                                    Color.yellow.opacity(0.90)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.neonGreen.opacity(0.22), lineWidth: 0.8)
                        )
                )
                .shadow(color: Color.neonGreen.opacity(0.46), radius: 12, x: 0, y: 0)
                .shadow(color: Color.neonGreen.opacity(0.24), radius: 24, x: 0, y: 0)
                .offset(y: -8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
