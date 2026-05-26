import SwiftUI

struct HomeFoodRow: View {
    var entry: FoodEntry
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 10) {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
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

            VStack(alignment: .leading, spacing: 3) {
                Text(shortFoodName(entry.name))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

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
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.appMuted.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
        )
        .task(id: entry.id) {
            let id = entry.id.uuidString
            ImageCache.shared.loadThumbnailAsync(for: id, data: { [entry] in entry.imageData.isEmpty ? nil : entry.imageData }, size: 50) { thumb in
                self.thumbnail = thumb
            }
        }
    }
}

struct HomeTrainingRow: View {
    var entry: TrainingEntry
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 10) {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neonCyan.opacity(0.25), lineWidth: 1))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.neonCyan.opacity(0.14))
                    Image(systemName: "figure.run")
                        .foregroundColor(.blue)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(2)

                Label(trainingSummary, systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.appMuted.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neonCyan.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neonCyan.opacity(0.16), lineWidth: 1))
        )
        .task(id: entry.id) {
            let id = entry.id.uuidString
            ImageCache.shared.loadThumbnailAsync(for: id, data: { [entry] in entry.imageData }, size: 56) { thumb in
                self.thumbnail = thumb
            }
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.appText)
                    if !entry.duration.isEmpty {
                        Text(entry.duration)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.appMuted)
                    }
                }
                Spacer()
                if let onShare {
                    Button(action: onShare) {
                        Label("Post", systemImage: "camera.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.fitOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.appElevated))
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
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        trainingMetric(value: "\(Int(entry.caloriesBurned))", unit: "kcal", icon: "flame.fill", color: .neonGreen)
                        if let steps = entry.steps, steps > 0 {
                            trainingMetric(value: "\(Int(steps))", unit: "steps", icon: "figure.walk", color: .neonCyan)
                        }
                        if let tonnage = entry.tonnageKg, tonnage > 0 {
                            trainingMetric(value: "\(Int(tonnage))", unit: "kg", icon: "dumbbell.fill", color: .fitPurple)
                        }
                    }

                    if let summary = entry.aiSummary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.neonCyan)

                            Text(summary)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.appText.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appSurface)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.neonCyan.opacity(0.12), lineWidth: 1))
                        )
                    }

                    if let image = entry.uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appElevated)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.neonCyan.opacity(0.14), lineWidth: 1))
        )
        .padding(.horizontal, 20)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
    }

    private func trainingMetric(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.appText)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
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
                    .overlay(Color.appElevated.clipShape(RoundedRectangle(cornerRadius: 15)))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.statusTitle ?? (item.textPrompt != nil ? "Reading text..." : item.isTraining ? "ShapeForge AI analyzing..." : "ShapeForge AI analyzing..."))
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
