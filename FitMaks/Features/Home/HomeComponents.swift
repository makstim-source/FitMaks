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
        themeBackground()
    }
}

struct HomeIconButton: View {
    var systemName: String
    var color: Color
    var action: () -> Void

    var body: some View {
        let pastel = isPastelDayTheme()

        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(
                    Group {
                        if pastel {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(themeChromeGradient())
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.18), lineWidth: 1))
                        } else {
                            Circle()
                                .fill(themeChromeGradient())
                                .overlay(Circle().stroke(color.opacity(0.16), lineWidth: 1))
                        }
                    }
                )
                .shadow(color: themeShadowColor().opacity(pastel ? 0.45 : 0.9), radius: pastel ? 7 : 12, y: pastel ? 2 : 4)
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
        let pastel = isPastelDayTheme()
        let glass = isIPhoneGlassTheme()
        let ringWidth: CGFloat = pastel ? 5.5 : 7
        let tileCorner: CGFloat = pastel ? 22 : 18

        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)
                .lineLimit(1)

            ZStack {
                Circle()
                    .stroke(glass ? Color.appBorder : (pastel ? Color.appBorder.opacity(0.5) : Color.appElevated), lineWidth: ringWidth)

                Circle()
                    .trim(from: 0, to: baseProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(glass ? 0.55 : (pastel ? 0.25 : 0.55)), radius: combinedProgress >= 1 ? (glass ? 13 : (pastel ? 7 : 13)) : (glass ? 6 : (pastel ? 2 : 6)))

                if combinedProgress > baseProgress {
                    Circle()
                        .trim(from: baseProgress, to: combinedProgress)
                        .stroke(
                            highlightColor,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: highlightColor.opacity(glass ? 0.58 : (pastel ? 0.28 : 0.58)), radius: combinedProgress >= 1 ? (glass ? 13 : (pastel ? 8 : 13)) : (glass ? 7 : (pastel ? 3 : 7)))
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
        .padding(.vertical, pastel ? 8 : 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: tileCorner)
                .fill(
                    pastel
                        ? themeCardGradient()
                        : LinearGradient(
                            colors: [Color.appSurface, Color.white.opacity(0.06), Color.appSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: tileCorner)
                        .stroke(pastel ? Color.appBorder.opacity(0.95) : color.opacity(0.09), lineWidth: 1)
                )
        )
        .shadow(color: themeShadowColor().opacity(pastel ? 0.18 : 0.55), radius: pastel ? 7 : 12, x: 0, y: pastel ? 3 : 6)
        .accessibilityIdentifier("metric_\(title)")
    }
}

struct HomeDockButton: View {
    var title: String
    var systemName: String
    var color: Color
    var action: () -> Void

    var body: some View {
        let pastel = isPastelDayTheme()
        let iphoneGlass = isIPhoneGlassTheme()

        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(
                            iphoneGlass
                                ? LinearGradient(
                                    colors: [color.opacity(0.18), color.opacity(0.06), Color.appSurface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [color.opacity(0.14), color.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 46, height: 46)

                    Circle()
                        .stroke(color.opacity(iphoneGlass ? 0.28 : 0.18), lineWidth: 1)
                        .frame(width: 46, height: 46)

                    Image(systemName: systemName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(color)
                }
                .shadow(color: color.opacity(iphoneGlass ? 0.22 : 0.12), radius: 8, y: 3)

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
                        .stroke(Color.appElevated, lineWidth: 2)
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
                .fill(themeCardGradient())
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.16), lineWidth: 1))
        )
        .shadow(color: themeShadowColor().opacity(0.45), radius: 8, x: 0, y: 4)
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
        let pastel = isPastelDayTheme()

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
                    .background(Capsule().fill(pastel ? accentColor.opacity(0.78) : accentColor))
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
                        .fill(Color.appBorder)

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
                        .fill(Color.appText.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(x: max(0, min(width - 6, width * markerProgress - 3)))
                }
            }
            .frame(height: pastel ? 4 : 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, pastel ? 10 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: pastel ? 18 : 14)
                .fill(themeCardGradient())
                .overlay(
                    RoundedRectangle(cornerRadius: pastel ? 18 : 14)
                        .stroke(pastel ? Color.appBorder.opacity(0.95) : accentColor.opacity(0.13), lineWidth: 1)
                )
        )
        .shadow(color: themeShadowColor().opacity(pastel ? 0.12 : 0.38), radius: pastel ? 6 : 8, x: 0, y: pastel ? 2 : 4)
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
        let pastel = isPastelDayTheme()

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
                    .background(Capsule().fill(pastel ? accentColor.opacity(0.78) : accentColor))
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
                        .fill(Color.appBorder)

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
            .frame(height: pastel ? 4 : 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, pastel ? 10 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: pastel ? 18 : 14)
                .fill(themeCardGradient())
                .overlay(
                    RoundedRectangle(cornerRadius: pastel ? 18 : 14)
                        .stroke(pastel ? Color.appBorder.opacity(0.95) : accentColor.opacity(0.13), lineWidth: 1)
                )
        )
        .shadow(color: themeShadowColor().opacity(pastel ? 0.12 : 0.38), radius: pastel ? 6 : 8, x: 0, y: pastel ? 2 : 4)
    }
}

struct HomeStatsPanelBackground: View {
    var isPerfectPastDay: Bool

    var body: some View {
        let glass = isIPhoneGlassTheme()
        let pastel = isPastelDayTheme() && !glass

        if isPerfectPastDay {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.neonGreen.opacity(pastel ? 0.08 : 0.14),
                            Color.neonCyan.opacity(pastel ? 0.04 : 0.05),
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
                                    Color.neonGreen.opacity(pastel ? 0.18 : 0.30),
                                    Color.neonCyan.opacity(pastel ? 0.06 : 0.10),
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
                .fill(
                    pastel
                        ? themeCardGradient()
                        : LinearGradient(
                            colors: [Color.appElevated, Color.appSurface.opacity(0.5), Color.appElevated],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(pastel ? Color.appBorder.opacity(0.9) : Color.white.opacity(0.04), lineWidth: 1)
                )
        }
    }
}

struct HomeStatsPanelCelebrationOverlay: View {
    var isPerfectPastDay: Bool

    var body: some View {
        let glass = isIPhoneGlassTheme()
        let pastel = isPastelDayTheme() && !glass

        ZStack(alignment: .top) {
            if isPerfectPastDay {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))

                    Text("PERFECT DAY")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.7)
                }
                .foregroundColor(glass ? .appText : .appAccentText)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: glass
                                    ? [Color.neonGreen.opacity(0.32), Color.neonCyan.opacity(0.22)]
                                    : (pastel
                                        ? [Color.neonGreen.opacity(0.82), Color.neonCyan.opacity(0.68)]
                                        : [Color.neonGreen.opacity(0.99), Color.fitOrange.opacity(0.90)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.neonGreen.opacity(glass ? 0.28 : 0.22), lineWidth: 0.8)
                        )
                )
                .shadow(color: Color.neonGreen.opacity(glass ? 0.32 : (pastel ? 0.18 : 0.46)), radius: 12, x: 0, y: 0)
                .shadow(color: Color.neonGreen.opacity(glass ? 0.16 : (pastel ? 0.08 : 0.24)), radius: 24, x: 0, y: 0)
                .offset(y: -8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct CopyDayPickerSheet: View {
    var dates: [Date]
    var allFoodEntries: [FoodEntry]
    var onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(dates, id: \.self) { date in
                        let foods = foodEntries(for: date)
                        let totalCal = foods.reduce(0) { $0 + $1.calories }
                        let totalProt = foods.reduce(0) { $0 + $1.protein }

                        Button {
                            onPick(date)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(dayTitle(for: date))
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundColor(.appText)

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Label("\(Int(totalCal))", systemImage: "flame.fill")
                                            .foregroundColor(.neonGreen)
                                        Label("\(Int(totalProt))g", systemImage: "drop.fill")
                                            .foregroundColor(.neonCyan)
                                    }
                                    .font(.system(size: 11, weight: .heavy))
                                }

                                if foods.isEmpty {
                                    Text("No meals")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.appMuted)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(foods, id: \.id) { entry in
                                                VStack(spacing: 4) {
                                                    if let img = entry.uiImage {
                                                        Image(uiImage: img)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 52, height: 52)
                                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.neonGreen.opacity(0.12))
                                                            .frame(width: 52, height: 52)
                                                            .overlay(
                                                                Image(systemName: "fork.knife")
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(.neonGreen)
                                                            )
                                                    }

                                                    Text(shortFoodName(entry.name, maxChars: 10))
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.appMuted)
                                                        .lineLimit(1)
                                                        .frame(width: 52)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.appSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.appBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(
                LinearGradient(
                    colors: [Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Copy from another day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonGreen)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func foodEntries(for date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        return allFoodEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { ($0.createdAt ?? $0.date) < ($1.createdAt ?? $1.date) }
    }

    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return "\(ShareFormatters.weekdayName(for: date)) · \(DateFormatter.shortDate.string(from: date))"
    }
}
