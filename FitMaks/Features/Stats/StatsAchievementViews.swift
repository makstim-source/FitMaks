import SwiftUI

struct StatsAchievementsCard: View {
    let collection: StatsAchievementCollection
    @Binding var selectedAchievement: StatsAchievement?

    private let coreColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    private var unlockedChaosCount: Int { collection.chaos.filter(\.isUnlocked).count }
    private var wideChaosIDs: Set<String> {
        Set(
            collection.orderedChaos
                .filter(isWideCandidate)
                .prefix(3)
                .map(\.id)
        )
    }
    private var chaosRows: [ChaosBadgeRow] {
        var rows: [ChaosBadgeRow] = []
        let badges = collection.orderedChaos
        var index = 0

        while index < badges.count {
            let current = badges[index]

            if shouldUseWideTile(for: current) {
                rows.append(.single(current))
                index += 1
                continue
            }

            if index + 1 < badges.count {
                let next = badges[index + 1]
                if !shouldUseWideTile(for: next) {
                    rows.append(.pair(current, next))
                    index += 2
                    continue
                }
            }

            rows.append(.single(current))
            index += 1
        }

        return rows
    }

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trophy Case")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appText)

                Spacer()

                Text("core + chaos")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
            }

            Text("Core trophies show the serious streaks. Chaos badges catch the funny, honest, and oddly shareable parts of real progress.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Label("Core Trophies", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.appText)

                LazyVGrid(columns: coreColumns, spacing: 10) {
                    ForEach(collection.core) { achievement in
                        Button {
                            selectedAchievement = achievement
                        } label: {
                            StatsAchievementTile(achievement: achievement, layout: .core)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Chaos Badges", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.appText)

                    Spacer()

                    Text("\(unlockedChaosCount)/\(collection.chaos.count) unlocked")
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(light ? .appAccentText : .neonGreen)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(light ? Color.appSurface : Color.neonGreen.opacity(0.12)))
                        .overlay(
                            Capsule()
                                .stroke(light ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                }

                Text("Side quests with more personality: chicken era, bounce-back days, gym brain, honest cheat-meal logs, and other crimes against average behavior.")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)

                VStack(spacing: 10) {
                    ForEach(Array(chaosRows.enumerated()), id: \.offset) { _, row in
                        switch row {
                        case .single(let achievement):
                            Button {
                                selectedAchievement = achievement
                            } label: {
                                StatsAchievementTile(achievement: achievement, layout: .chaosWide)
                            }
                            .buttonStyle(.plain)

                        case .pair(let leading, let trailing):
                            HStack(spacing: 10) {
                                Button {
                                    selectedAchievement = leading
                                } label: {
                                    StatsAchievementTile(achievement: leading, layout: .chaosCompact)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    selectedAchievement = trailing
                                } label: {
                                    StatsAchievementTile(achievement: trailing, layout: .chaosCompact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
    }

    private func shouldUseWideTile(for achievement: StatsAchievement) -> Bool {
        wideChaosIDs.contains(achievement.id)
    }

    private func isWideCandidate(_ achievement: StatsAchievement) -> Bool {
        achievement.title.count >= 20
            || achievement.subtitle.count >= 30
            || achievement.rarity == .hard
            || achievement.rarity == .legendary
    }
}

enum ChaosBadgeRow {
    case single(StatsAchievement)
    case pair(StatsAchievement, StatsAchievement)
}

enum StatsAchievementTileLayout {
    case core
    case chaosCompact
    case chaosWide
}

struct StatsAchievementUnlockBanner: View {
    let achievement: StatsAchievement
    var onDismiss: () -> Void

    var body: some View {
        let light = isLightAppTheme()

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                achievement.color.opacity(0.96),
                                Color.appText,
                                achievement.color.opacity(0.68)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: achievement.icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.appAccentText)
            }
            .frame(width: 50, height: 50)
            .shadow(color: achievement.color.opacity(0.55), radius: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Achievement unlocked")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(achievement.color)
                    .tracking(0.8)

                Text(achievement.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.appText)
                    .lineLimit(1)

                Text(achievement.subtitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.appMuted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(light ? Color.appSurface : Color.appText.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appElevated.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(achievement.color.opacity(0.38), lineWidth: 1.2)
                )
        )
        .shadow(color: achievement.color.opacity(0.22), radius: 22, x: 0, y: 10)
    }
}

struct StatsAchievementUnlockPopup: View {
    let achievement: StatsAchievement
    var onPost: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        let light = isLightAppTheme()

        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                achievement.color.opacity(0.9),
                                achievement.color.opacity(0.34),
                                .clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 68
                        )
                    )
                    .frame(width: 124, height: 124)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                achievement.color.opacity(0.98),
                                Color.appText,
                                achievement.color.opacity(0.68)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)

                Image(systemName: achievement.icon)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.appAccentText)
            }
            .shadow(color: achievement.color.opacity(0.42), radius: 24, y: 8)

            VStack(spacing: 7) {
                Text("Achievement unlocked")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(achievement.color)
                    .tracking(1)

                Text(achievement.title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                Text(achievement.subtitle)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.appMuted)
                    .multilineTextAlignment(.center)
            }

            Text(achievement.detail)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Text("Later")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onPost) {
                    HStack(spacing: 7) {
                        Image(systemName: "camera.fill")
                        Text("Post it")
                    }
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.appAccentText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(achievement.color))
                    .shadow(color: achievement.color.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    light
                        ? LinearGradient(
                            colors: [
                                Color.appElevated,
                                Color.appSurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.11, blue: 0.13),
                                Color(red: 0.08, green: 0.09, blue: 0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(achievement.color.opacity(0.34), lineWidth: 1.2)
                )
        )
        .shadow(color: light ? Color.black.opacity(0.08) : .black.opacity(0.22), radius: 30, y: 14)
    }
}

struct StatsAchievementTile: View {
    let achievement: StatsAchievement
    var layout: StatsAchievementTileLayout = .core

    private var tileOpacity: Double {
        achievement.isUnlocked ? 1 : 0.62
    }

    private var isWide: Bool {
        layout == .chaosWide
    }

    private var minHeight: CGFloat? {
        switch layout {
        case .core:
            return nil
        case .chaosCompact:
            return 154
        case .chaosWide:
            return 138
        }
    }

    private var titleFontSize: CGFloat {
        switch layout {
        case .core:
            return 13
        case .chaosCompact:
            return 13
        case .chaosWide:
            return 16
        }
    }

    private var subtitleFont: Font {
        switch layout {
        case .core, .chaosCompact:
            return .caption2
        case .chaosWide:
            return .caption
        }
    }

    private var titleLineLimit: Int {
        switch layout {
        case .core:
            return 2
        case .chaosCompact:
            return 3
        case .chaosWide:
            return 2
        }
    }

    private var subtitleLineLimit: Int {
        switch layout {
        case .core:
            return 2
        case .chaosCompact:
            return 3
        case .chaosWide:
            return 2
        }
    }

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(
                            achievement.isUnlocked
                                ? LinearGradient(
                                    colors: [
                                        achievement.color.opacity(0.95),
                                        Color.appText,
                                        achievement.color.opacity(0.70)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        achievement.color.opacity(0.08),
                                        achievement.color.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )

                    Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(achievement.isUnlocked ? .appAccentText : .appMuted)

                    if achievement.isUnlocked {
                        Image(systemName: "sparkles")
                            .font(.system(size: isWide ? 13 : 12, weight: .black))
                            .foregroundColor(.appText)
                            .offset(x: 18, y: -17)
                            .opacity(0.92)
                            .shadow(color: light ? achievement.color.opacity(0.20) : .white.opacity(0.75), radius: 7)
                    }
                }
                .frame(width: 42, height: 42)
                .shadow(color: achievement.isUnlocked ? achievement.color.opacity(0.54) : .clear, radius: 15)

                Spacer()

                Text(achievement.progressText)
                    .font(.system(size: isWide ? 11 : 10, weight: .heavy))
                    .foregroundColor(achievement.isUnlocked ? .appAccentText : .appMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(achievement.isUnlocked ? achievement.color : achievement.color.opacity(0.07)))
                    .shadow(color: achievement.isUnlocked ? achievement.color.opacity(0.30) : .clear, radius: 8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: titleFontSize, weight: .black))
                    .foregroundColor(.appText.opacity(tileOpacity))
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(isWide ? 0.84 : 0.76)

                Text(achievement.subtitle)
                    .font(subtitleFont)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineLimit(subtitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appText.opacity(0.08))

                    Capsule()
                        .fill(achievement.color.opacity(achievement.isUnlocked ? 0.95 : 0.58))
                        .frame(width: max(achievement.progress > 0 ? 8 : 0, proxy.size.width * CGFloat(achievement.progress)))
                }
            }
            .frame(height: 7)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    achievement.isUnlocked
                        ? LinearGradient(
                            colors: [
                                achievement.color.opacity(0.22),
                                Color.appSurface,
                                achievement.color.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.appSurface, Color.appSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(achievement.color.opacity(achievement.isUnlocked ? 0.55 : 0.12), lineWidth: achievement.isUnlocked ? 1.5 : 1)
        )
        .shadow(color: achievement.isUnlocked ? achievement.color.opacity(light ? 0.10 : 0.18) : .clear, radius: 12, x: 0, y: 7)
    }
}

struct StatsDetailLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(color)
            .tracking(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

struct StatsAchievementDetailSheet: View {
    let achievement: StatsAchievement
    var onShare: (() -> Void)? = nil

    var body: some View {
        let light = isLightAppTheme()

        ZStack {
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

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(achievement.color.opacity(0.18))

                        Image(systemName: achievement.isUnlocked ? achievement.icon : "lock.fill")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(achievement.color)
                    }
                    .frame(width: 66, height: 66)
                    .shadow(color: achievement.color.opacity(0.35), radius: 16)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(achievement.title)
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.appText)

                            Spacer(minLength: 0)

                            if let onShare {
                                Button(action: onShare) {
                                    Label("Post", systemImage: "camera.fill")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.fitOrange)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(light ? Color.appSurface : Color.appElevated))
                                        .overlay(
                                            Capsule()
                                                .stroke(light ? Color.appBorder.opacity(0.7) : Color.clear, lineWidth: 1)
                                        )
                                        .shadow(color: light ? Color.black.opacity(0.05) : .fitOrange.opacity(0.35), radius: 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(achievement.subtitle)
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundColor(achievement.color)

                        HStack(spacing: 8) {
                            StatsDetailLabel(text: achievement.family.label, color: achievement.color)
                            StatsDetailLabel(text: achievement.rarity.label, color: achievement.color.opacity(0.82))
                        }
                    }
                }

                Text(achievement.detail)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(achievement.isUnlocked ? "Unlocked" : "Progress")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundColor(.appMuted)

                        Spacer()

                        Text(achievement.currentText)
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(achievement.color)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.appText.opacity(0.08))

                            Capsule()
                                .fill(achievement.color)
                                .frame(width: max(achievement.progress > 0 ? 12 : 0, proxy.size.width * CGFloat(achievement.progress)))
                                .shadow(color: achievement.color.opacity(0.42), radius: 12)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(achievement.color.opacity(0.18), lineWidth: 1))

                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
    }
}
