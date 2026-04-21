import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case neonPulse
    case morningAir
    case midnight
    case dune

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
                subtitle: "Warm clean light",
                description: "Quiet oatmeal, sage and ink-blue. Softer for daytime use without feeling medical.",
                primary: Color(red: 92/255, green: 156/255, blue: 38/255),
                secondary: Color(red: 0/255, green: 126/255, blue: 191/255),
                action: Color(red: 201/255, green: 115/255, blue: 65/255),
                purple: Color(red: 129/255, green: 92/255, blue: 161/255),
                backgroundStart: Color(red: 251/255, green: 247/255, blue: 238/255),
                backgroundMid: Color(red: 239/255, green: 234/255, blue: 220/255),
                backgroundEnd: Color(red: 226/255, green: 232/255, blue: 225/255),
                surface: Color.white.opacity(0.78),
                elevated: Color.white.opacity(0.92),
                text: Color(red: 28/255, green: 34/255, blue: 36/255),
                muted: Color(red: 92/255, green: 101/255, blue: 103/255),
                border: Color(red: 31/255, green: 38/255, blue: 41/255).opacity(0.10),
                accentText: Color(red: 248/255, green: 246/255, blue: 239/255),
                preferredScheme: .light
            )
        case .midnight:
            return AppPalette(
                name: "Midnight",
                subtitle: "Premium low contrast",
                description: "Deep graphite with mineral green and quiet blue. Still dark, but less aggressive.",
                primary: Color(red: 180/255, green: 238/255, blue: 88/255),
                secondary: Color(red: 43/255, green: 177/255, blue: 242/255),
                action: Color(red: 223/255, green: 160/255, blue: 107/255),
                purple: Color(red: 174/255, green: 143/255, blue: 222/255),
                backgroundStart: Color(red: 12/255, green: 16/255, blue: 20/255),
                backgroundMid: Color(red: 19/255, green: 24/255, blue: 31/255),
                backgroundEnd: Color(red: 5/255, green: 7/255, blue: 10/255),
                surface: Color.white.opacity(0.06),
                elevated: Color.black.opacity(0.26),
                text: Color(red: 238/255, green: 242/255, blue: 239/255),
                muted: Color(red: 132/255, green: 142/255, blue: 146/255),
                border: Color.white.opacity(0.085),
                accentText: Color(red: 8/255, green: 12/255, blue: 18/255),
                preferredScheme: .dark
            )
        case .dune:
            return AppPalette(
                name: "Dune",
                subtitle: "Warm editorial",
                description: "Espresso, amber and muted teal. Cozy evening mode without turning everything orange.",
                primary: Color(red: 170/255, green: 209/255, blue: 89/255),
                secondary: Color(red: 71/255, green: 190/255, blue: 196/255),
                action: Color(red: 214/255, green: 103/255, blue: 70/255),
                purple: Color(red: 183/255, green: 116/255, blue: 166/255),
                backgroundStart: Color(red: 24/255, green: 18/255, blue: 15/255),
                backgroundMid: Color(red: 38/255, green: 29/255, blue: 24/255),
                backgroundEnd: Color(red: 12/255, green: 9/255, blue: 8/255),
                surface: Color.white.opacity(0.065),
                elevated: Color.black.opacity(0.28),
                text: Color(red: 249/255, green: 236/255, blue: 216/255),
                muted: Color(red: 170/255, green: 151/255, blue: 128/255),
                border: Color.white.opacity(0.095),
                accentText: Color(red: 24/255, green: 15/255, blue: 8/255),
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
        .onAppear(perform: normalizeSelection)
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

    private func normalizeSelection() {
        guard AppTheme(rawValue: selectedThemeID) == nil else { return }
        selectedThemeID = AppTheme.defaultID
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
        .onAppear(perform: normalizeSelection)
    }

    private func normalizeSelection() {
        guard AppTheme(rawValue: selectedThemeID) == nil else { return }
        selectedThemeID = AppTheme.defaultID
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
