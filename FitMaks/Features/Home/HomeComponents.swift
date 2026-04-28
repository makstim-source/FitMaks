import SwiftUI

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
            VStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.appSurface))
                    .overlay(Circle().stroke(color.opacity(0.18), lineWidth: 1))

                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dock_\(title)")
    }
}

struct HomeFoodRow: View {
    var entry: FoodEntry

    var body: some View {
        HStack(spacing: 13) {
            if let image = entry.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.neonGreen.opacity(0.12))
                    Image(systemName: "fork.knife")
                        .foregroundColor(.neonGreen)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(Int(entry.calories)) kcal", systemImage: "flame.fill")
                        .foregroundColor(.neonGreen)
                    Label("\(Int(entry.protein))g", systemImage: "drop.fill")
                        .foregroundColor(.neonCyan)
                }
                .font(.caption.bold())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.appMuted)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
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
        return "\(Int(entry.caloriesBurned)) kcal burned\(stepsText) · \(entry.duration)"
    }
}

struct TrainingDetailOverlay: View {
    var entry: TrainingEntry
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workout Details")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
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
                            Color.neonGreen.opacity(0.24),
                            Color.neonCyan.opacity(0.18),
                            Color.appElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSurface)
        }
    }
}

struct HomeStatsPanelCelebrationOverlay: View {
    var isPerfectPastDay: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isPerfectPastDay
                    ? LinearGradient(colors: [.neonGreen, .neonCyan, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isPerfectPastDay ? 2 : 0
                )

            if isPerfectPastDay {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))

                    Text("PERFECT DAY")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                }
                .foregroundColor(.appAccentText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.neonGreen))
                .shadow(color: .neonGreen.opacity(0.8), radius: 8, x: 0, y: 0)
                .offset(x: -12, y: -10)
            }
        }
    }
}
