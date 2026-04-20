import SwiftUI
import SwiftData

@main
struct FitMaksApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    OnboardingView {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            FoodEntry.self,
            FavoriteFood.self,
            TrainingEntry.self,
            DailySetup.self,
            SavedRecipe.self,
            ShoppingItem.self // 🔥 Новая база для списка покупок
        ])
    }
}

private struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "WELCOME TO FITMAKS",
            title: "Your day, finally readable.",
            subtitle: "Scan meals, track protein, calories, steps, workouts, and collect days you will actually want to look back at.",
            systemName: "sparkles",
            color: .neonGreen
        ),
        OnboardingPage(
            eyebrow: "ADD FOOD FAST",
            title: "Photo first. Edit if needed.",
            subtitle: "Tap + to scan a plate, label, receipt, or type food manually. AI gives an estimate, then you can tap the food card to adjust details.",
            systemName: "camera.macro",
            color: .neonCyan
        ),
        OnboardingPage(
            eyebrow: "GOALS",
            title: "Set your body data once.",
            subtitle: "Open Profile after setup and add weight, height, goal, and activity. Protein and calories will adapt to you, not to a random default.",
            systemName: "person.crop.circle.badge.checkmark",
            color: Color(red: 0.95, green: 0.35, blue: 1.0)
        ),
        OnboardingPage(
            eyebrow: "THE GAME",
            title: "Chase Perfect Days.",
            subtitle: "A perfect day means protein closed, 10k steps, and calories under target. Chill, Padel, and Gym adjust your daily budget.",
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
                        .foregroundColor(.white)
                        .tracking(1.4)

                    Spacer()

                    Button("Skip") {
                        onComplete()
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.gray)
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

                VStack(spacing: 18) {
                    HStack(spacing: 7) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == page ? pages[page].color : Color.white.opacity(0.14))
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
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(pages[page].color)
                                .shadow(color: pages[page].color.opacity(0.45), radius: 18, x: 0, y: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Tip: AI nutrition is an estimate. If something looks off, tap the food card and correct it.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 10)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
            }
        }
    }

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 6/255, green: 10/255, blue: 15/255),
                Color.darkGrey,
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        VStack(spacing: 26) {
            Spacer(minLength: 18)

            ZStack {
                RoundedRectangle(cornerRadius: 44)
                    .fill(
                        LinearGradient(
                            colors: [
                                item.color.opacity(0.22),
                                Color.white.opacity(0.055),
                                Color.black.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 230, height: 230)
                    .rotationEffect(.degrees(-6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 44)
                            .stroke(item.color.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: item.color.opacity(0.24), radius: 30, x: 0, y: 18)

                Image(systemName: item.systemName)
                    .font(.system(size: 78, weight: .black))
                    .foregroundColor(item.color)
                    .shadow(color: item.color.opacity(0.75), radius: 20)
            }

            VStack(spacing: 13) {
                Text(item.eyebrow)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(item.color)
                    .tracking(1.2)

                Text(item.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
                    .lineSpacing(1)

                Text(item.subtitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 18)
            }

            quickRuleCard(for: item)

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 20)
    }

    private func quickRuleCard(for item: OnboardingPage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundColor(item.color)
                .frame(width: 42, height: 42)
                .background(Circle().fill(item.color.opacity(0.12)))

            Text(quickRuleText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.86))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 1))
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
