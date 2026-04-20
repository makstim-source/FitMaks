import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case neonPulse
    case morningAir
    case midnight
    case dune
    case glacier

    static let storageKey = "selectedThemeID"
    static let defaultID = AppTheme.neonPulse.rawValue

    var id: String { rawValue }

    static var current: AppTheme {
        let storedID = UserDefaults.standard.string(forKey: storageKey) ?? defaultID
        return AppTheme(rawValue: storedID) ?? .neonPulse
    }

    var palette: AppPalette {
        switch self {
        case .neonPulse:
            return AppPalette(
                name: "Original",
                subtitle: "High energy neon",
                description: "The current FitMaks look: bright, sporty, very readable.",
                primary: Color(red: 173/255, green: 255/255, blue: 47/255),
                secondary: Color(red: 6/255, green: 156/255, blue: 232/255),
                action: Color(red: 1.0, green: 0.48, blue: 0.12),
                purple: Color(red: 0.8, green: 0.2, blue: 1.0),
                backgroundStart: Color(red: 7/255, green: 11/255, blue: 15/255),
                backgroundMid: Color(red: 30/255, green: 30/255, blue: 35/255),
                backgroundEnd: Color.black.opacity(0.96),
                surface: Color.white.opacity(0.06),
                elevated: Color.black.opacity(0.30),
                text: .white,
                muted: .gray,
                border: Color.white.opacity(0.08),
                accentText: .black,
                preferredScheme: .dark
            )
        case .morningAir:
            return AppPalette(
                name: "Morning",
                subtitle: "Soft light mode",
                description: "Creamy, calmer, less aggressive for people who dislike hard contrast.",
                primary: Color(red: 58/255, green: 132/255, blue: 91/255),
                secondary: Color(red: 61/255, green: 132/255, blue: 184/255),
                action: Color(red: 224/255, green: 132/255, blue: 73/255),
                purple: Color(red: 149/255, green: 91/255, blue: 180/255),
                backgroundStart: Color(red: 249/255, green: 244/255, blue: 232/255),
                backgroundMid: Color(red: 236/255, green: 242/255, blue: 226/255),
                backgroundEnd: Color(red: 226/255, green: 236/255, blue: 237/255),
                surface: Color.white.opacity(0.72),
                elevated: Color.white.opacity(0.86),
                text: Color(red: 31/255, green: 38/255, blue: 41/255),
                muted: Color(red: 94/255, green: 104/255, blue: 109/255),
                border: Color.black.opacity(0.09),
                accentText: .white,
                preferredScheme: .light
            )
        case .midnight:
            return AppPalette(
                name: "Midnight",
                subtitle: "Calm dark mode",
                description: "A softer dark palette with less laser-neon and more premium focus.",
                primary: Color(red: 125/255, green: 211/255, blue: 167/255),
                secondary: Color(red: 132/255, green: 169/255, blue: 255/255),
                action: Color(red: 232/255, green: 174/255, blue: 117/255),
                purple: Color(red: 190/255, green: 155/255, blue: 255/255),
                backgroundStart: Color(red: 11/255, green: 18/255, blue: 27/255),
                backgroundMid: Color(red: 18/255, green: 25/255, blue: 37/255),
                backgroundEnd: Color(red: 5/255, green: 8/255, blue: 14/255),
                surface: Color.white.opacity(0.065),
                elevated: Color.black.opacity(0.28),
                text: Color(red: 239/255, green: 244/255, blue: 248/255),
                muted: Color(red: 137/255, green: 148/255, blue: 160/255),
                border: Color.white.opacity(0.09),
                accentText: Color(red: 8/255, green: 12/255, blue: 18/255),
                preferredScheme: .dark
            )
        case .dune:
            return AppPalette(
                name: "Dune",
                subtitle: "Warm evening",
                description: "Coffee, honey and clay tones for a warmer lifestyle feel.",
                primary: Color(red: 232/255, green: 194/255, blue: 114/255),
                secondary: Color(red: 110/255, green: 202/255, blue: 185/255),
                action: Color(red: 224/255, green: 113/255, blue: 78/255),
                purple: Color(red: 207/255, green: 126/255, blue: 190/255),
                backgroundStart: Color(red: 27/255, green: 20/255, blue: 16/255),
                backgroundMid: Color(red: 45/255, green: 33/255, blue: 26/255),
                backgroundEnd: Color(red: 14/255, green: 10/255, blue: 8/255),
                surface: Color.white.opacity(0.07),
                elevated: Color.black.opacity(0.30),
                text: Color(red: 250/255, green: 238/255, blue: 222/255),
                muted: Color(red: 176/255, green: 154/255, blue: 134/255),
                border: Color.white.opacity(0.10),
                accentText: Color(red: 22/255, green: 14/255, blue: 9/255),
                preferredScheme: .dark
            )
        case .glacier:
            return AppPalette(
                name: "Glacier",
                subtitle: "Cold clean focus",
                description: "Blue ice, lavender and coral: sharper than Morning, gentler than neon.",
                primary: Color(red: 112/255, green: 225/255, blue: 215/255),
                secondary: Color(red: 155/255, green: 172/255, blue: 255/255),
                action: Color(red: 255/255, green: 130/255, blue: 117/255),
                purple: Color(red: 184/255, green: 143/255, blue: 255/255),
                backgroundStart: Color(red: 11/255, green: 20/255, blue: 30/255),
                backgroundMid: Color(red: 20/255, green: 30/255, blue: 45/255),
                backgroundEnd: Color(red: 4/255, green: 10/255, blue: 18/255),
                surface: Color.white.opacity(0.07),
                elevated: Color.black.opacity(0.26),
                text: Color(red: 237/255, green: 248/255, blue: 255/255),
                muted: Color(red: 142/255, green: 161/255, blue: 176/255),
                border: Color.white.opacity(0.10),
                accentText: Color(red: 5/255, green: 15/255, blue: 22/255),
                preferredScheme: .dark
            )
        }
    }
}

struct AppPalette {
    let name: String
    let subtitle: String
    let description: String
    let primary: Color
    let secondary: Color
    let action: Color
    let purple: Color
    let backgroundStart: Color
    let backgroundMid: Color
    let backgroundEnd: Color
    let surface: Color
    let elevated: Color
    let text: Color
    let muted: Color
    let border: Color
    let accentText: Color
    let preferredScheme: ColorScheme
}

extension Color {
    static var neonGreen: Color { AppTheme.current.palette.primary }
    static var neonCyan: Color { AppTheme.current.palette.secondary }
    static var darkGrey: Color { AppTheme.current.palette.backgroundMid }
    static var fitOrange: Color { AppTheme.current.palette.action }
    static var fitPurple: Color { AppTheme.current.palette.purple }
    static var appText: Color { AppTheme.current.palette.text }
    static var appMuted: Color { AppTheme.current.palette.muted }
    static var appAccentText: Color { AppTheme.current.palette.accentText }
    static var appSurface: Color { AppTheme.current.palette.surface }
    static var appElevated: Color { AppTheme.current.palette.elevated }
    static var appBorder: Color { AppTheme.current.palette.border }
    static var appBackgroundStart: Color { AppTheme.current.palette.backgroundStart }
    static var appBackgroundMid: Color { AppTheme.current.palette.backgroundMid }
    static var appBackgroundEnd: Color { AppTheme.current.palette.backgroundEnd }
}

struct ThemeSelectionView: View {
    var isFirstRun: Bool
    var onContinue: () -> Void

    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: selectedThemeID) ?? .neonPulse
    }

    var body: some View {
        ZStack {
            themeBackground(selectedTheme)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    ThemePickerGrid(selectedThemeID: $selectedThemeID)
                    selectedThemeStory
                    continueButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(selectedTheme.palette.preferredScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isFirstRun ? "CHOOSE YOUR VIBE" : "APP THEME")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.neonGreen)
                .tracking(1.1)

            Text(isFirstRun ? "Make FitMaks feel like yours." : "Change the mood anytime.")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.appText)
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)

            Text("Original stays as the default. Try a softer light mode, a calmer dark mode, or something more editorial.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedThemeStory: some View {
        let palette = selectedTheme.palette

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(palette.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.appText)

                    Text(palette.subtitle)
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.neonGreen)
                }

                Spacer()

                HStack(spacing: -5) {
                    swatch(palette.primary)
                    swatch(palette.secondary)
                    swatch(palette.action)
                }
            }

            Text(palette.description)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appMuted)
                .lineSpacing(3)

            HStack(spacing: 9) {
                previewMetric(title: "Calories", value: "640", color: .neonGreen)
                previewMetric(title: "Protein", value: "142g", color: .neonCyan)
                previewMetric(title: "Streak", value: "3", color: .fitOrange)
            }
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
        )
    }

    private var continueButton: some View {
        Button {
            onContinue()
        } label: {
            HStack {
                Text(isFirstRun ? "Start with \(selectedTheme.palette.name)" : "Use \(selectedTheme.palette.name)")
                    .font(.system(size: 16, weight: .black))

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundColor(.appAccentText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(Color.neonGreen)
                    .shadow(color: .neonGreen.opacity(0.35), radius: 18, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private func previewMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.6)

            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 17).fill(Color.appElevated))
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(Color.appText.opacity(0.22), lineWidth: 1))
    }
}

struct ThemePickerGrid: View {
    @Binding var selectedThemeID: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                ThemeChoiceCard(
                    theme: theme,
                    isSelected: selectedThemeID == theme.rawValue
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedThemeID = theme.rawValue
                    }
                }
            }
        }
    }
}

private struct ThemeChoiceCard: View {
    var theme: AppTheme
    var isSelected: Bool
    var onTap: () -> Void

    private var palette: AppPalette { theme.palette }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [palette.backgroundStart, palette.backgroundMid, palette.backgroundEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 102)

                    HStack(spacing: 6) {
                        Capsule().fill(palette.primary).frame(width: 36, height: 8)
                        Capsule().fill(palette.secondary).frame(width: 24, height: 8)
                        Capsule().fill(palette.action).frame(width: 14, height: 8)
                    }
                    .padding(13)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(palette.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(palette.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.appText)

                    Text(palette.subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(isSelected ? Color.neonGreen.opacity(0.13) : Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(isSelected ? Color.neonGreen.opacity(0.55) : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

func themeBackground(_ theme: AppTheme = .current) -> some View {
    LinearGradient(
        colors: [
            theme.palette.backgroundStart,
            theme.palette.backgroundMid,
            theme.palette.backgroundEnd
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
    .overlay(alignment: .topTrailing) {
        Circle()
            .fill(theme.palette.secondary.opacity(0.13))
            .frame(width: 260, height: 260)
            .blur(radius: 58)
            .offset(x: 90, y: -110)
    }
    .overlay(alignment: .bottomLeading) {
        Circle()
            .fill(theme.palette.primary.opacity(0.12))
            .frame(width: 300, height: 300)
            .blur(radius: 65)
            .offset(x: -125, y: 85)
    }
}
