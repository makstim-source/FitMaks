import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case original = "original"
    case originalV2 = "original_v2"
    case cleanLight = "clean_light"
    case performanceDark = "performance_dark"
    case earthFuel = "earth_fuel"
    case iphoneGlass = "iphone_glass"

    static let storageKey = "selectedThemeID"
    static let defaultID = AppTheme.originalV2.rawValue
    static let areAlternateThemesEnabled = true
    static let selectableThemes: [AppTheme] = [.original, .originalV2, .earthFuel, .iphoneGlass]

    var id: String { rawValue }

    static func resolvedTheme(for storedID: String) -> AppTheme {
        guard areAlternateThemesEnabled else { return .original }

        switch storedID {
        case "neonPulse", "morningAir", "midnight", "dune":
            return .original
        case AppTheme.cleanLight.rawValue, AppTheme.performanceDark.rawValue:
            return .originalV2
        default:
            return AppTheme(rawValue: storedID) ?? .original
        }
    }

    static func normalizedSelectableID(for storedID: String) -> String {
        let theme = resolvedTheme(for: storedID)
        if selectableThemes.contains(theme) {
            return theme.rawValue
        }
        return AppTheme.originalV2.rawValue
    }

    static var current: AppTheme {
        let storedID = UserDefaults.standard.string(forKey: storageKey) ?? defaultID
        return resolvedTheme(for: storedID)
    }

    var palette: AppPalette {
        switch self {
        case .original:
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
                surface: Color(red: 28/255, green: 31/255, blue: 37/255).opacity(0.84),
                elevated: Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.92),
                text: .white,
                muted: .gray,
                border: Color.white.opacity(0.08),
                accentText: .black,
                scrim: Color.black.opacity(0.55),
                preferredScheme: .dark
            )
        case .originalV2:
            return AppPalette(
                name: "Neon Core",
                subtitle: "Premium neon sport",
                description: "Same FitMaks DNA, but more polished: richer depth, cleaner glow, more premium contrast.",
                primary: Color(red: 190/255, green: 255/255, blue: 70/255),
                secondary: Color(red: 48/255, green: 191/255, blue: 255/255),
                action: Color(red: 255/255, green: 148/255, blue: 52/255),
                purple: Color(red: 201/255, green: 115/255, blue: 255/255),
                backgroundStart: Color(red: 6/255, green: 14/255, blue: 18/255),
                backgroundMid: Color(red: 14/255, green: 24/255, blue: 33/255),
                backgroundEnd: Color(red: 2/255, green: 5/255, blue: 9/255),
                surface: Color(red: 18/255, green: 39/255, blue: 48/255).opacity(0.88),
                elevated: Color(red: 7/255, green: 16/255, blue: 22/255).opacity(0.94),
                text: Color(red: 244/255, green: 247/255, blue: 249/255),
                muted: Color(red: 154/255, green: 171/255, blue: 178/255),
                border: Color(red: 86/255, green: 217/255, blue: 255/255).opacity(0.18),
                accentText: Color(red: 7/255, green: 12/255, blue: 14/255),
                scrim: Color.black.opacity(0.58),
                preferredScheme: .dark
            )
        case .cleanLight:
            return AppPalette(
                name: "Verdant Studio",
                subtitle: "Sage, slate, sea-glass",
                description: "A calmer green theme built on graphite, eucalyptus and sea-glass, not neon spinach.",
                primary: Color(red: 168/255, green: 198/255, blue: 122/255),
                secondary: Color(red: 112/255, green: 178/255, blue: 182/255),
                action: Color(red: 223/255, green: 148/255, blue: 104/255),
                purple: Color(red: 136/255, green: 133/255, blue: 162/255),
                backgroundStart: Color(red: 8/255, green: 13/255, blue: 16/255),
                backgroundMid: Color(red: 16/255, green: 23/255, blue: 26/255),
                backgroundEnd: Color(red: 5/255, green: 8/255, blue: 10/255),
                surface: Color(red: 28/255, green: 36/255, blue: 37/255).opacity(0.91),
                elevated: Color(red: 12/255, green: 17/255, blue: 19/255).opacity(0.97),
                text: Color(red: 241/255, green: 245/255, blue: 241/255),
                muted: Color(red: 160/255, green: 170/255, blue: 165/255),
                border: Color(red: 124/255, green: 166/255, blue: 160/255).opacity(0.22),
                accentText: Color(red: 10/255, green: 14/255, blue: 15/255),
                scrim: Color.black.opacity(0.58),
                preferredScheme: .dark
            )
        case .performanceDark:
            return AppPalette(
                name: "Gilded Night",
                subtitle: "Ink, brass, midnight blue",
                description: "A dark premium theme with smoked navy surfaces and brass accents used like jewelry, not paint.",
                primary: Color(red: 214/255, green: 184/255, blue: 116/255),
                secondary: Color(red: 121/255, green: 145/255, blue: 182/255),
                action: Color(red: 183/255, green: 116/255, blue: 84/255),
                purple: Color(red: 124/255, green: 117/255, blue: 145/255),
                backgroundStart: Color(red: 6/255, green: 9/255, blue: 14/255),
                backgroundMid: Color(red: 15/255, green: 18/255, blue: 26/255),
                backgroundEnd: Color(red: 5/255, green: 6/255, blue: 10/255),
                surface: Color(red: 27/255, green: 29/255, blue: 38/255).opacity(0.91),
                elevated: Color(red: 12/255, green: 14/255, blue: 20/255).opacity(0.97),
                text: Color(red: 245/255, green: 237/255, blue: 223/255),
                muted: Color(red: 173/255, green: 163/255, blue: 146/255),
                border: Color(red: 177/255, green: 155/255, blue: 110/255).opacity(0.20),
                accentText: Color(red: 17/255, green: 13/255, blue: 10/255),
                scrim: Color.black.opacity(0.60),
                preferredScheme: .dark
            )
        case .earthFuel:
            return AppPalette(
                name: "Pastel Day",
                subtitle: "Warm & quiet",
                description: "Sage, dusty rose, and oatmeal. Calm enough for a yoga studio, readable enough for a gym.",
                primary: Color(red: 126/255, green: 156/255, blue: 120/255),
                secondary: Color(red: 132/255, green: 146/255, blue: 172/255),
                action: Color(red: 192/255, green: 136/255, blue: 112/255),
                purple: Color(red: 168/255, green: 132/255, blue: 152/255),
                backgroundStart: Color(red: 240/255, green: 236/255, blue: 230/255),
                backgroundMid: Color(red: 236/255, green: 233/255, blue: 226/255),
                backgroundEnd: Color(red: 234/255, green: 230/255, blue: 224/255),
                surface: Color(red: 252/255, green: 249/255, blue: 244/255).opacity(0.94),
                elevated: Color(red: 254/255, green: 252/255, blue: 248/255).opacity(0.97),
                text: Color(red: 52/255, green: 42/255, blue: 38/255),
                muted: Color(red: 132/255, green: 118/255, blue: 110/255),
                border: Color(red: 168/255, green: 152/255, blue: 138/255).opacity(0.30),
                accentText: .white,
                scrim: Color.black.opacity(0.30),
                preferredScheme: .light
            )
        case .iphoneGlass:
            return AppPalette(
                name: "iPhone Glass",
                subtitle: "Dark liquid glass",
                description: "Cold graphite glass, sapphire chrome, aqua highlights, and crisp Apple-like contrast on a dark stage.",
                primary: Color(red: 120/255, green: 240/255, blue: 219/255),
                secondary: Color(red: 114/255, green: 157/255, blue: 255/255),
                action: Color(red: 255/255, green: 142/255, blue: 111/255),
                purple: Color(red: 142/255, green: 158/255, blue: 210/255),
                backgroundStart: Color(red: 6/255, green: 10/255, blue: 16/255),
                backgroundMid: Color(red: 12/255, green: 18/255, blue: 28/255),
                backgroundEnd: Color(red: 2/255, green: 4/255, blue: 9/255),
                surface: Color(red: 24/255, green: 34/255, blue: 52/255).opacity(0.90),
                elevated: Color(red: 11/255, green: 17/255, blue: 27/255).opacity(0.95),
                text: Color(red: 243/255, green: 247/255, blue: 255/255),
                muted: Color(red: 149/255, green: 164/255, blue: 194/255),
                border: Color.white.opacity(0.15),
                accentText: Color(red: 15/255, green: 18/255, blue: 28/255),
                scrim: Color.black.opacity(0.48),
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
    let scrim: Color
    let preferredScheme: ColorScheme
}

func themeCardGradient(_ theme: AppTheme = .current) -> LinearGradient {
    switch theme {
    case .original:
        return LinearGradient(
            colors: [Color.appSurface, Color.appElevated],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    case .originalV2:
        return LinearGradient(
            colors: [
                theme.palette.surface,
                theme.palette.secondary.opacity(0.12),
                theme.palette.elevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    case .cleanLight:
        return LinearGradient(
            colors: [
                theme.palette.surface,
                theme.palette.secondary.opacity(0.10),
                theme.palette.primary.opacity(0.07),
                theme.palette.elevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    case .performanceDark:
        return LinearGradient(
            colors: [
                theme.palette.surface,
                theme.palette.secondary.opacity(0.09),
                theme.palette.primary.opacity(0.06),
                theme.palette.elevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    case .earthFuel:
        return LinearGradient(
            colors: [
                theme.palette.elevated,
                theme.palette.surface,
                theme.palette.secondary.opacity(0.06),
                theme.palette.elevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    case .iphoneGlass:
        return LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                theme.palette.surface,
                theme.palette.secondary.opacity(0.13),
                theme.palette.elevated
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

func themeChromeGradient(_ theme: AppTheme = .current) -> LinearGradient {
    switch theme {
    case .original:
        return LinearGradient(colors: [Color.appSurface, Color.appElevated], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .originalV2:
        return LinearGradient(colors: [theme.palette.primary.opacity(0.22), theme.palette.surface, theme.palette.elevated], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .cleanLight:
        return LinearGradient(colors: [theme.palette.primary.opacity(0.14), theme.palette.secondary.opacity(0.08), theme.palette.elevated], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .performanceDark:
        return LinearGradient(colors: [theme.palette.primary.opacity(0.10), theme.palette.surface, theme.palette.elevated], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .earthFuel:
        return LinearGradient(colors: [theme.palette.elevated, theme.palette.secondary.opacity(0.08), theme.palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .iphoneGlass:
        return LinearGradient(colors: [Color.white.opacity(0.14), theme.palette.secondary.opacity(0.18), theme.palette.elevated], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

func themeShadowColor(_ theme: AppTheme = .current) -> Color {
    switch theme {
    case .original:
        return Color.black.opacity(0.22)
    case .originalV2:
        return theme.palette.primary.opacity(0.18)
    case .cleanLight:
        return theme.palette.secondary.opacity(0.16)
    case .performanceDark:
        return theme.palette.primary.opacity(0.14)
    case .earthFuel:
        return theme.palette.secondary.opacity(0.28)
    case .iphoneGlass:
        return theme.palette.secondary.opacity(0.22)
    }
}

func themePrimaryButtonGradient(_ theme: AppTheme = .current) -> LinearGradient {
    switch theme {
    case .original:
        return LinearGradient(colors: [theme.palette.primary, theme.palette.primary.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .originalV2:
        return LinearGradient(colors: [theme.palette.primary, theme.palette.action], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .cleanLight:
        return LinearGradient(colors: [theme.palette.primary, theme.palette.secondary.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .performanceDark:
        return LinearGradient(colors: [theme.palette.primary, theme.palette.action], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .earthFuel:
        return LinearGradient(colors: [theme.palette.primary, theme.palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .iphoneGlass:
        return LinearGradient(colors: [theme.palette.secondary, theme.palette.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

func themeAccentButtonGradient(_ theme: AppTheme = .current) -> LinearGradient {
    switch theme {
    case .original:
        return LinearGradient(colors: [theme.palette.action, Color(red: 1.0, green: 0.62, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .originalV2:
        return LinearGradient(colors: [theme.palette.secondary, theme.palette.action], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .cleanLight:
        return LinearGradient(colors: [theme.palette.action, theme.palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .performanceDark:
        return LinearGradient(colors: [theme.palette.secondary, theme.palette.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .earthFuel:
        return LinearGradient(colors: [theme.palette.action, theme.palette.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .iphoneGlass:
        return LinearGradient(colors: [theme.palette.purple, theme.palette.action], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

func themeIdentityButtonGradient(_ theme: AppTheme = .current) -> LinearGradient {
    switch theme {
    case .original:
        return LinearGradient(colors: [theme.palette.purple, theme.palette.purple.opacity(0.86)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .originalV2:
        return LinearGradient(colors: [theme.palette.action, theme.palette.primary.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .cleanLight:
        return LinearGradient(colors: [theme.palette.secondary, theme.palette.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .performanceDark:
        return LinearGradient(colors: [theme.palette.action, theme.palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .earthFuel:
        return LinearGradient(colors: [theme.palette.purple, theme.palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .iphoneGlass:
        return LinearGradient(colors: [theme.palette.primary, theme.palette.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
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
    static var appScrim: Color { AppTheme.current.palette.scrim }
}

func isPastelDayTheme(_ theme: AppTheme = .current) -> Bool {
    theme == .earthFuel || theme == .iphoneGlass
}

func isIPhoneGlassTheme(_ theme: AppTheme = .current) -> Bool {
    theme == .iphoneGlass
}

func isLightAppTheme(_ theme: AppTheme = .current) -> Bool {
    theme.palette.preferredScheme == .light
}

struct ThemeSelectionView: View {
    var isFirstRun: Bool
    var onContinue: () -> Void

    @AppStorage(AppTheme.storageKey) private var savedThemeID = AppTheme.defaultID
    @State private var previewThemeID = ""

    private var selectedTheme: AppTheme {
        AppTheme.resolvedTheme(for: previewThemeID.isEmpty ? savedThemeID : previewThemeID)
    }

    var body: some View {
        ZStack {
            themeBackground(selectedTheme)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    ThemePickerGrid(selectedThemeID: $previewThemeID)
                    selectedThemeStory
                    continueButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(selectedTheme.palette.preferredScheme)
        .onAppear {
            previewThemeID = AppTheme.normalizedSelectableID(for: savedThemeID)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
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
                }

                Spacer()

                if !isFirstRun {
                    Button { onContinue() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.appMuted)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Original stays untouched. Neon Core is the premium neon remix, Pastel Day is the soft daylight alternative, and iPhone Glass is the colder dark-glass take.")
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
                .fill(themeCardGradient(selectedTheme))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.appBorder, lineWidth: 1))
        )
        .shadow(color: themeShadowColor(selectedTheme), radius: 18, x: 0, y: 10)
    }

    private var continueButton: some View {
        Button {
            savedThemeID = previewThemeID
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
                    .fill(themePrimaryButtonGradient(selectedTheme))
                    .shadow(color: themeShadowColor(selectedTheme).opacity(0.85), radius: 18, x: 0, y: 8)
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
        .background(RoundedRectangle(cornerRadius: 17).fill(themeChromeGradient(selectedTheme)))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.appBorder, lineWidth: 1))
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
            ForEach(AppTheme.selectableThemes) { theme in
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
        let normalized = AppTheme.normalizedSelectableID(for: selectedThemeID)
        guard normalized != selectedThemeID else { return }
        selectedThemeID = normalized
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
                        .overlay {
                            ThemePreviewAtmosphere(theme: theme)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                        }

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
                    .fill(themeCardGradient(theme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(isSelected ? theme.palette.primary.opacity(0.60) : Color.appBorder, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .shadow(color: isSelected ? themeShadowColor(theme) : Color.clear, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct ThemePreviewAtmosphere: View {
    var theme: AppTheme

    private var palette: AppPalette { theme.palette }

    var body: some View {
        ZStack {
            switch theme {
            case .original:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.secondary.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 42
                        )
                    )
                    .frame(width: 92, height: 92)
                    .offset(x: 38, y: -26)

                RoundedRectangle(cornerRadius: 20)
                    .fill(palette.primary.opacity(0.16))
                    .frame(width: 88, height: 34)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -18, y: 24)
            case .originalV2:
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [palette.secondary.opacity(0.24), .clear, palette.primary.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(6)

                RoundedRectangle(cornerRadius: 22)
                    .fill(palette.primary.opacity(0.18))
                    .frame(width: 96, height: 30)
                    .rotationEffect(.degrees(22))
                    .offset(x: -12, y: 18)
            case .cleanLight:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.primary.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)
                    .offset(x: -30, y: 18)

                RoundedRectangle(cornerRadius: 18)
                    .fill(palette.secondary.opacity(0.24))
                    .frame(width: 96, height: 22)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 28, y: -12)

                RoundedRectangle(cornerRadius: 22)
                    .fill(palette.action.opacity(0.16))
                    .frame(width: 76, height: 18)
                    .rotationEffect(.degrees(18))
                    .offset(x: 34, y: 24)
            case .performanceDark:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.primary.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 40
                        )
                    )
                    .frame(width: 82, height: 82)
                    .offset(x: -28, y: 18)

                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.secondary.opacity(0.18))
                    .frame(width: 90, height: 18)
                    .offset(x: 26, y: -18)

                RoundedRectangle(cornerRadius: 18)
                    .fill(palette.action.opacity(0.14))
                    .frame(width: 72, height: 20)
                    .rotationEffect(.degrees(-14))
                    .offset(x: 18, y: 20)
            case .earthFuel:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.action.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 42
                        )
                    )
                    .frame(width: 82, height: 82)
                    .offset(x: -30, y: -14)

                RoundedRectangle(cornerRadius: 22)
                    .fill(palette.secondary.opacity(0.22))
                    .frame(width: 104, height: 26)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 24, y: -8)

                RoundedRectangle(cornerRadius: 18)
                    .fill(palette.primary.opacity(0.18))
                    .frame(width: 78, height: 18)
                    .rotationEffect(.degrees(14))
                    .offset(x: -2, y: 24)
            case .iphoneGlass:
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.secondary.opacity(0.28), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 48
                        )
                    )
                    .frame(width: 90, height: 90)
                    .offset(x: 34, y: -18)

                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 108, height: 30)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -20, y: 18)

                RoundedRectangle(cornerRadius: 18)
                    .fill(palette.primary.opacity(0.16))
                    .frame(width: 78, height: 18)
                    .rotationEffect(.degrees(14))
                    .offset(x: 28, y: 28)
            }
        }
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
    .overlay {
        ZStack {
        switch theme {
        case .original:
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.secondary.opacity(0.28), theme.palette.secondary.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: 148, y: -148)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.primary.opacity(0.24), theme.palette.primary.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -148, y: 310)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.secondary.opacity(0.12), theme.palette.primary.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 160)
                .offset(x: -60, y: 80)
        case .originalV2:
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.palette.secondary.opacity(0.16),
                            .clear,
                            theme.palette.primary.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 520, height: 280)
                .rotationEffect(.degrees(-18))
                .offset(x: 50, y: -130)

            Ellipse()
                .fill(theme.palette.primary.opacity(0.12))
                .frame(width: 360, height: 220)
                .offset(x: -70, y: -220)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.secondary.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 150, y: -160)

            RoundedRectangle(cornerRadius: 46)
                .fill(theme.palette.action.opacity(0.10))
                .frame(width: 260, height: 84)
                .rotationEffect(.degrees(14))
                .offset(x: -170, y: 330)
        case .cleanLight:
            Ellipse()
                .fill(theme.palette.primary.opacity(0.16))
                .frame(width: 320, height: 220)
                .offset(x: -140, y: -250)

            RoundedRectangle(cornerRadius: 70)
                .fill(theme.palette.secondary.opacity(0.14))
                .frame(width: 280, height: 94)
                .rotationEffect(.degrees(-15))
                .offset(x: 170, y: -130)

            RoundedRectangle(cornerRadius: 44)
                .fill(theme.palette.action.opacity(0.12))
                .frame(width: 200, height: 62)
                .rotationEffect(.degrees(15))
                .offset(x: -32, y: 330)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.secondary.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .offset(x: 132, y: 300)
        case .performanceDark:
            RoundedRectangle(cornerRadius: 220)
                .fill(theme.palette.secondary.opacity(0.10))
                .frame(width: 430, height: 130)
                .offset(x: 120, y: -285)

            RoundedRectangle(cornerRadius: 30)
                .fill(theme.palette.action.opacity(0.13))
                .frame(width: 220, height: 52)
                .offset(x: 174, y: -170)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.primary.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .offset(x: -168, y: 312)

            RoundedRectangle(cornerRadius: 120)
                .fill(theme.palette.primary.opacity(0.08))
                .frame(width: 290, height: 84)
                .rotationEffect(.degrees(-18))
                .offset(x: -156, y: 340)
        case .earthFuel:
            Ellipse()
                .fill(theme.palette.action.opacity(0.20))
                .frame(width: 280, height: 180)
                .offset(x: -176, y: -264)

            RoundedRectangle(cornerRadius: 44)
                .fill(theme.palette.secondary.opacity(0.15))
                .frame(width: 290, height: 94)
                .rotationEffect(.degrees(-14))
                .offset(x: 164, y: -128)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.primary.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 108
                    )
                )
                .frame(width: 220, height: 220)
                .offset(x: 172, y: 292)

            RoundedRectangle(cornerRadius: 54)
                .fill(theme.palette.purple.opacity(0.12))
                .frame(width: 250, height: 78)
                .rotationEffect(.degrees(16))
                .offset(x: -44, y: 348)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.44), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 82
                    )
                )
                .frame(width: 150, height: 150)
                .offset(x: 30, y: -24)
        case .iphoneGlass:
            RoundedRectangle(cornerRadius: 90)
                .fill(theme.palette.secondary.opacity(0.18))
                .frame(width: 340, height: 110)
                .rotationEffect(.degrees(-13))
                .offset(x: 156, y: -246)

            Ellipse()
                .fill(theme.palette.purple.opacity(0.14))
                .frame(width: 260, height: 180)
                .offset(x: -182, y: -238)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.palette.primary.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 112
                    )
                )
                .frame(width: 228, height: 228)
                .offset(x: 174, y: 298)

            RoundedRectangle(cornerRadius: 52)
                .fill(Color.white.opacity(0.08))
                .frame(width: 276, height: 82)
                .rotationEffect(.degrees(14))
                .offset(x: -60, y: 350)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 84
                    )
                )
                .frame(width: 150, height: 150)
                .offset(x: 16, y: -30)
        }
        }
        .allowsHitTesting(false)
    }
    .clipped()
    .ignoresSafeArea()
}
