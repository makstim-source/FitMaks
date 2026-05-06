import SwiftUI

private let fillerWords: Set<String> = ["and", "with", "in", "on", "the", "a", "of", "for", "from", "с", "и", "в", "на", "из", "для", "по", "к", "от", "до"]

func shortFoodName(_ name: String, maxWords: Int = 3) -> String {
    let words = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    guard words.count > maxWords else { return name }
    var result = Array(words.prefix(maxWords))
    while let last = result.last, fillerWords.contains(last.lowercased()) {
        result.removeLast()
    }
    return result.joined(separator: " ")
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

                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5, height: 3)
                        .offset(x: max(0, min(width - 2, width * markerProgress - 1)))
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

struct HomeFoodRow: View {
    var entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            if let image = entry.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.neonGreen.opacity(0.12))
                    Image(systemName: "fork.knife")
                        .font(.system(size: 15))
                        .foregroundColor(.neonGreen)
                }
                .frame(width: 50, height: 50)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(shortFoodName(entry.name))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label("\(Int(entry.calories))", systemImage: "flame.fill")
                        .foregroundColor(.neonGreen)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Label("\(Int(entry.protein))g", systemImage: "drop.fill")
                        .foregroundColor(.neonCyan)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Label("\(Int(entry.carbs))g", systemImage: "leaf.fill")
                        .foregroundColor(.fitOrange)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Label("\(Int(entry.fat))g", systemImage: "circle.inset.filled")
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.system(size: 10, weight: .heavy))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.appMuted)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
        )
    }
}

struct HomeTrainingRow: View {
    var entry: TrainingEntry

    var body: some View {
        HStack(spacing: 13) {
            if let image = entry.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.25), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.14))
                    Image(systemName: "figure.run")
                        .foregroundColor(.blue)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)

                Label(trainingSummary, systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.appMuted)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.blue.opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.blue.opacity(0.20), lineWidth: 1))
        )
    }

    private var trainingSummary: String {
        let stepsText = (entry.steps ?? 0) > 0 ? " · \(Int(entry.steps ?? 0)) steps" : ""
        let tonnageText = (entry.tonnageKg ?? 0) > 0 ? " · \(Int(entry.tonnageKg ?? 0)) kg" : ""
        return "\(Int(entry.caloriesBurned)) kcal burned\(stepsText)\(tonnageText) · \(entry.duration)"
    }
}

struct TrainingDetailOverlay: View {
    var entry: TrainingEntry
    var onShare: (() -> Void)? = nil
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workout Details")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let onShare {
                    Button(action: onShare) {
                        Label("Post", systemImage: "camera.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.fitOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black))
                            .shadow(color: .fitOrange.opacity(0.35), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onDone) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 16) {
                    if let image = entry.uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.2), lineWidth: 1))
                    }

                    Text(entry.name)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        trainingMetric(value: "\(Int(entry.caloriesBurned))", unit: "kcal", icon: "flame.fill", color: .orange)
                        if !entry.duration.isEmpty {
                            trainingMetric(value: entry.duration, unit: "", icon: "clock.fill", color: .blue)
                        }
                        if let steps = entry.steps, steps > 0 {
                            trainingMetric(value: "\(Int(steps))", unit: "steps", icon: "figure.walk", color: .green)
                        }
                        if let tonnage = entry.tonnageKg, tonnage > 0 {
                            trainingMetric(value: "\(Int(tonnage))", unit: "kg", icon: "dumbbell.fill", color: .purple)
                        }
                    }

                    if let summary = entry.aiSummary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.caption)
                                .fontWeight(.heavy)
                                .foregroundColor(.blue)

                            Text(summary)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.15), lineWidth: 1))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 28/255, green: 28/255, blue: 32/255))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.blue.opacity(0.18), lineWidth: 1))
        )
        .padding(.horizontal, 20)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
    }

    private func trainingMetric(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(.white)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.15), lineWidth: 1))
        )
    }
}

struct HomeProcessingRow: View {
    var item: ProcessingItem

    var body: some View {
        let color: Color = item.isTraining ? .blue : .neonGreen

        HStack(spacing: 13) {
            if let firstImage = item.images.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(Color.black.opacity(0.18).clipShape(RoundedRectangle(cornerRadius: 15)))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.statusTitle ?? (item.textPrompt != nil ? "Reading text..." : item.isTraining ? "FitMaks AI analyzing training..." : "FitMaks AI analyzing food..."))
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(color.opacity(0.55))
                            .frame(width: 32, height: 5)
                    }
                }
            }

            Spacer()
            ProgressView().tint(color)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.24), lineWidth: 1))
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

// MARK: - New Entry Sheet

struct NewEntrySheet: View {
    var onFromFridge: () -> Void
    var onFromMeals: () -> Void
    var onBuildMeal: () -> Void
    var onCamera: () -> Void
    var onLibrary: () -> Void
    var onTypeText: () -> Void
    var onTraining: () -> Void
    var onTypeTraining: () -> Void
    var onFAQ: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEW ENTRY")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(1)
                    Text("Log something")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.appText)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appMuted)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.appElevated))
                }
                .buttonStyle(.plain)
            }

            newEntrySection("YOUR STUFF", color: .neonGreen) {
                HStack(spacing: 10) {
                    newEntryButton("From Fridge", icon: "refrigerator.fill", color: .neonCyan, surfaceTint: .neonCyan, action: onFromFridge)
                    newEntryButton("From Meals", icon: "fork.knife", color: .fitOrange, surfaceTint: .neonCyan, action: onFromMeals)
                    newEntryButton("Build Meal", icon: "link", color: .yellow, surfaceTint: .neonCyan, action: onBuildMeal)
                }
            }

            newEntrySection("CAPTURE FOOD", color: .fitOrange) {
                HStack(spacing: 10) {
                    newEntryButton("Camera", icon: "camera.fill", color: .neonGreen, surfaceTint: .neonGreen, action: onCamera)
                    newEntryButton("Library", icon: "photo.on.rectangle", color: .yellow, surfaceTint: .neonGreen, action: onLibrary)
                    newEntryButton("Type Food", icon: "pencil", color: .fitPurple, surfaceTint: .neonGreen, action: onTypeText)
                }
            }

            HStack {
                newEntrySection("TRAINING", color: .neonCyan) { EmptyView() }
                Spacer()
                newEntrySection("HELP", color: .fitPurple) { EmptyView() }
            }
            HStack(spacing: 10) {
                newEntryButton("Training Screenshot", icon: "dumbbell.fill", color: .neonCyan, surfaceTint: .fitOrange, action: onTraining)
                newEntryButton("Type Training", icon: "pencil.line", color: .fitPurple, surfaceTint: .fitOrange, action: onTypeTraining)
                newEntryButton("F.A.Q.", icon: "questionmark.circle.fill", color: .fitPurple, surfaceTint: .fitPurple, action: onFAQ)
            }

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appElevated)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.appBackgroundMid, Color.appBackgroundEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func newEntrySection<Content: View>(_ title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)
                .overlay(
                    Rectangle()
                        .fill(color)
                        .frame(height: 2)
                        .offset(y: 8),
                    alignment: .bottom
                )
                .padding(.bottom, 4)
            content()
        }
    }

    private func newEntryButton(_ title: String, icon: String, color: Color, surfaceTint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(color)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )

                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                surfaceTint.opacity(0.11),
                                Color.appSurface.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(surfaceTint.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(color: surfaceTint.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FAQ Sheet

struct FAQSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(icon: String, color: Color, q: String, a: String)] = [
        ("camera.fill", .neonGreen, "How do I log food?",
         "Tap the + button and choose Camera or Library. Take a photo of your meal — AI will recognize the food, estimate weight, and calculate calories, protein, carbs, and fat automatically."),
        ("pencil", .fitPurple, "Can I log food without a photo?",
         "Yes! Use Type Text and describe what you ate, e.g. \"200g chicken breast and rice\". AI will analyze it the same way."),
        ("refrigerator.fill", .neonCyan, "What is the Fridge?",
         "The Fridge stores your favorite foods. When you save a food to the Fridge, you can quickly add it again later without taking a new photo."),
        ("fork.knife", .fitOrange, "What are Meals?",
         "Meals are saved recipes — full dishes you eat regularly. Save any analyzed food as a Meal to reuse it with one tap."),
        ("link", .yellow, "How does Build Meal work?",
         "Build Meal lets you combine items from your Fridge into a custom meal. Select ingredients and adjust portions by grams to create a precise nutritional breakdown."),
        ("dumbbell.fill", .neonCyan, "How do I log training?",
         "You can upload a screenshot from your fitness app (Apple Watch, Strava, etc.) or type a description like \"Padel 2 hours\" or \"Gym: bench press 4x10 80kg\"."),
        ("flame.fill", .neonGreen, "How are calories calculated?",
         "AI analyzes your food photos using visual recognition. It identifies each ingredient, estimates portions, and calculates macros. You can chat with AI to correct any mistakes."),
        ("leaf.fill", .fitOrange, "What are Carbs and Fat targets?",
         "Carbs behave like fuel: rest days keep the cap tighter, while cardio days expand it. Fat is shown as a comfort zone instead of a race to 100%, so you can stay inside a more useful daily range."),
        ("trophy.fill", .yellow, "How do achievements work?",
         "You earn badges for streaks, consistency, and milestones — like hitting your goals 7 days in a row. Check the Badges section to see your progress."),
        ("camera.fill", .fitOrange, "How does Post work?",
         "Tap Post to create a share card of your daily progress, meals, workouts, or achievements. Pick a background, customize the look, and share it to Instagram Stories, friends, or save it.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("F.A.Q.")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.yellow)
                        .tracking(1)
                    Text("How to use FitMaks")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.appText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appMuted)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.appElevated))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        faqRow(icon: item.icon, color: item.color, question: item.q, answer: item.a)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.appBackgroundStart,
                    Color.appBackgroundMid.opacity(0.96),
                    Color.appBackgroundEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.yellow.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .blur(radius: 54)
                    .offset(x: 72, y: -70)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(Color.neonGreen.opacity(0.07))
                    .frame(width: 260, height: 260)
                    .blur(radius: 72)
                    .offset(x: -90, y: 90)
            }
        )
    }

    private func faqRow(icon: String, color: Color, question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.20), color.opacity(0.09)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.22), lineWidth: 1)
                    )
                Text(question)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.appText)
            }
            Text(answer)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appText.opacity(0.78))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.appElevated.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}
