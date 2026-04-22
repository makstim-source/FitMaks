import SwiftUI
import SwiftData

@main
struct FitMaksApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSelectedTheme") private var hasSelectedTheme = false
    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID
    @State private var isShowingLaunchSplash = true

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: selectedThemeID) ?? .neonPulse
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !hasCompletedOnboarding {
                        OnboardingView {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                hasCompletedOnboarding = true
                            }
                        }
                        .transition(.opacity)
                    } else if !hasSelectedTheme {
                        ThemeSelectionView(isFirstRun: true) {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                hasSelectedTheme = true
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        ContentView()
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }

                if isShowingLaunchSplash {
                    LaunchSplashView(theme: selectedTheme)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                        .zIndex(10)
                }
            }
            .preferredColorScheme(selectedTheme.palette.preferredScheme)
            .task {
                guard isShowingLaunchSplash else { return }
                try? await Task.sleep(nanoseconds: 1_450_000_000)
                withAnimation(.easeInOut(duration: 0.42)) {
                    isShowingLaunchSplash = false
                }
            }
        }
        .modelContainer(for: [
            FoodEntry.self,
            FavoriteFood.self,
            TrainingEntry.self,
            DailySetup.self,
            BodyMetricEntry.self,
            SavedRecipe.self,
            ShoppingItem.self // 🔥 Новая база для списка покупок
        ])
    }
}

private struct LaunchSplashView: View {
    var theme: AppTheme

    @State private var pulse = false
    @State private var shimmer = false

    private var palette: AppPalette { theme.palette }

    var body: some View {
        ZStack {
            themeBackground(theme)

            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 42)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.primary.opacity(0.23),
                                    palette.secondary.opacity(0.12),
                                    palette.surface
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 144, height: 144)
                        .rotationEffect(.degrees(pulse ? -4 : 4))
                        .shadow(color: palette.primary.opacity(pulse ? 0.45 : 0.22), radius: pulse ? 30 : 18, x: 0, y: 14)

                    Image(systemName: "sparkles")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(palette.primary)
                        .scaleEffect(pulse ? 1.08 : 0.94)
                        .shadow(color: palette.primary.opacity(0.7), radius: pulse ? 18 : 9)
                }

                VStack(spacing: 8) {
                    Text("FitMaks")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(palette.text)
                        .tracking(1.2)

                    Text("loading your day")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(palette.muted)
                        .tracking(1.6)
                        .textCase(.uppercase)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.surface)
                        .frame(width: 156, height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.primary, palette.secondary, palette.action],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 58, height: 7)
                        .offset(x: shimmer ? 98 : 0)
                }
                .clipShape(Capsule())
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

private struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "WELCOME TO FITMAKS",
            title: "Your day, finally readable.",
            subtitle: "Scan meals, track protein, calories, steps and workouts. Collect days you'll want to look back at.",
            systemName: "sparkles",
            color: .neonGreen
        ),
        OnboardingPage(
            eyebrow: "ADD FOOD FAST",
            title: "Photo first. Edit if needed.",
            subtitle: "Tap + to scan a plate, label or receipt. AI estimates it, then you can tap any food card to correct portions.",
            systemName: "camera.macro",
            color: .neonCyan
        ),
        OnboardingPage(
            eyebrow: "GOALS",
            title: "Set your body data once.",
            subtitle: "Open Profile after setup. Add weight, height, goal and activity so calories and protein adapt to you.",
            systemName: "person.crop.circle.badge.checkmark",
            color: .fitPurple
        ),
        OnboardingPage(
            eyebrow: "THE GAME",
            title: "Chase Perfect Days.",
            subtitle: "Perfect Day means protein closed, movement done and calories under target. Padel adds food budget; Gym adds food budget and a 5k step credit.",
            systemName: "flame.fill",
            color: .yellow
        )
    ]

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                HStack {
                    Text("FitMaks")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.appText)
                        .tracking(1.4)

                    Spacer()

                    Button("Skip") {
                        onComplete()
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appMuted)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        onboardingPage(item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 14) {
                    HStack(spacing: 7) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == page ? pages[page].color : Color.appText.opacity(0.14))
                                .frame(width: index == page ? 24 : 7, height: 7)
                                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: page)
                        }
                    }

                    Button(action: primaryAction) {
                        HStack {
                            Text(page == pages.count - 1 ? "Start tracking" : "Next")
                                .font(.system(size: 17, weight: .black))

                            Image(systemName: page == pages.count - 1 ? "checkmark" : "arrow.right")
                                .font(.system(size: 15, weight: .black))
                        }
                        .foregroundColor(.appAccentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(pages[page].color)
                                .shadow(color: pages[page].color.opacity(0.45), radius: 18, x: 0, y: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Tip: AI nutrition is an estimate. If something looks off, tap the food card and correct it.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 10)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
    }

    private var onboardingBackground: some View {
        LinearGradient(colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(pages[page].color.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 58)
                .offset(x: 100, y: -110)
                .animation(.easeInOut(duration: 0.35), value: page)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.neonGreen.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 65)
                .offset(x: -130, y: 70)
        }
    }

    private func onboardingPage(_ item: OnboardingPage) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            ZStack {
                RoundedRectangle(cornerRadius: 44)
                    .fill(
                        LinearGradient(
                            colors: [
                                item.color.opacity(0.22),
                                Color.appSurface,
                                Color.appElevated
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 188, height: 188)
                    .rotationEffect(.degrees(-6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 44)
                            .stroke(item.color.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: item.color.opacity(0.24), radius: 30, x: 0, y: 18)

                Image(systemName: item.systemName)
                    .font(.system(size: 62, weight: .black))
                    .foregroundColor(item.color)
                    .shadow(color: item.color.opacity(0.75), radius: 20)
            }

            VStack(spacing: 9) {
                Text(item.eyebrow)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(item.color)
                    .tracking(1.2)
                    .multilineTextAlignment(.center)

                Text(item.title)
                    .font(.system(size: 29, weight: .black))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(0)

                Text(item.subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            quickRuleCard(for: item)

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 20)
    }

    private func quickRuleCard(for item: OnboardingPage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(item.color)
                .frame(width: 38, height: 38)
                .background(Circle().fill(item.color.opacity(0.12)))

            Text(quickRuleText)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.appText.opacity(0.86))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
        )
        .padding(.horizontal, 6)
    }

    private var quickRuleText: String {
        switch page {
        case 0:
            return "Use it as a daily cockpit: log, adjust, move on."
        case 1:
            return "Same photo should stay consistent, but portions are still editable."
        case 2:
            return "First thing after onboarding: open Profile and set your numbers."
        default:
            return "Perfect Days are about consistency, not punishment."
        }
    }

    private func primaryAction() {
        if page == pages.count - 1 {
            onComplete()
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                page += 1
            }
        }
    }
}

private struct OnboardingPage {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemName: String
    let color: Color
}
