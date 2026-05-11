import SwiftUI
import SwiftData

@main
struct FitMaksApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenSignIn") private var hasSeenSignIn = false
    @AppStorage(AppTheme.storageKey) private var selectedThemeID = AppTheme.defaultID
    @State private var isShowingLaunchSplash = true

    let modelContainer: ModelContainer

    init() {
        let config = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.MaksTim.FitMaks")
        )
        do {
            modelContainer = try ModelContainer(
                for: FoodEntry.self, FavoriteFood.self, TrainingEntry.self,
                     DailySetup.self, BodyMetricEntry.self, SavedRecipe.self,
                     ShoppingItem.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        ICloudSettingsSync.startObserving()
        ICloudSettingsSync.pullFromICloud()
    }

    private var selectedTheme: AppTheme {
        AppTheme.resolvedTheme(for: selectedThemeID)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !hasSeenSignIn {
                        SignInView {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                hasSeenSignIn = true
                                ICloudSettingsSync.pullFromICloud()
                            }
                        }
                        .transition(.opacity)
                    } else if !hasCompletedOnboarding {
                        OnboardingView {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                hasCompletedOnboarding = true
                                ICloudSettingsSync.pushToICloud()
                            }
                        }
                        .transition(.opacity)
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
            .id(selectedTheme.id)
            .preferredColorScheme(selectedTheme.palette.preferredScheme)
            .task {
                guard isShowingLaunchSplash else { return }
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation(.easeInOut(duration: 0.42)) {
                    isShowingLaunchSplash = false
                }
            }
        }
        .modelContainer(modelContainer)
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

    @AppStorage("userGender") private var gender: String = "Male"
    @AppStorage("userAge") private var age: Int = 30
    @AppStorage("userWeight") private var weight: Double = 80.0
    @AppStorage("userHeight") private var height: Double = 180.0
    @AppStorage("userGoal") private var goal: String = "Lose Weight"
    @AppStorage("userActivity") private var activityLevel: String = "Moderate"
    @AppStorage("useCustomGoals") private var useCustomGoals: Bool = false

    @State private var page = 0

    private let introPages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "FitMaks",
            title: "LOG YOUR DAY",
            subtitle: "Just snap your food or upload a workout screenshot.",
            systemName: "sparkles",
            color: .neonGreen
        ),
        OnboardingPage(
            eyebrow: "FitMaks",
            title: "AI DOES THE BORING PART.",
            subtitle: "AI detects items, estimates calories and protein.",
            systemName: "camera.macro",
            color: .neonCyan
        ),
        OnboardingPage(
            eyebrow: "FitMaks",
            title: "CONSISTENCY WINS.",
            subtitle: "Close your targets, build streaks, and unlock achievements.",
            systemName: "flame.fill",
            color: .yellow
        )
    ]

    private let goalOptions: [(title: String, subtitle: String, key: String, color: Color)] = [
        ("Cut", "Lose fat", "Lose Weight", .neonGreen),
        ("Recomp", "Lean + muscle", "Recomp", .neonCyan),
        ("Maintain", "Hold shape", "Maintain", .fitPurple),
        ("Build", "Gain muscle", "Build Muscle", .orange)
    ]

    private let activityOptions: [ActivityOption] = [
        ActivityOption(key: "Sedentary", title: "Desk job", subtitle: "Mostly sitting"),
        ActivityOption(key: "Light", title: "On your feet", subtitle: "Retail, teaching"),
        ActivityOption(key: "Moderate", title: "Active lifestyle", subtitle: "Walking + errands"),
        ActivityOption(key: "Active", title: "Physical job", subtitle: "Construction, warehouse")
    ]

    @State private var disclaimerAccepted = false

    private var pageCount: Int { introPages.count + 3 }
    private var bodySetupPageIndex: Int { introPages.count }
    private var goalSetupPageIndex: Int { introPages.count + 1 }
    private var disclaimerPageIndex: Int { introPages.count + 2 }
    private var currentColor: Color {
        if page < introPages.count {
            return introPages[page].color
        }

        return page == bodySetupPageIndex ? .fitPurple : .neonGreen
    }

    private var recommendedCalories: Double {
        NutritionCalculator.recommendedCalories(
            gender: gender,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityLevel,
            goal: goal
        )
    }

    private var recommendedProtein: Double {
        NutritionCalculator.recommendedProtein(weight: weight, goal: goal)
    }

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
                        useCustomGoals = false
                        onComplete()
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appMuted)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                TabView(selection: $page) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        onboardingContent(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 14) {
                    HStack(spacing: 7) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Capsule()
                                .fill(index == page ? currentColor : Color.appText.opacity(0.14))
                                .frame(width: index == page ? 24 : 7, height: 7)
                                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: page)
                        }
                    }

                    Button(action: primaryAction) {
                        let disabled = page == disclaimerPageIndex && !disclaimerAccepted

                        HStack {
                            Text(page == pageCount - 1 ? "Start tracking" : "Next")
                                .font(.system(size: 17, weight: .black))

                            Image(systemName: page == pageCount - 1 ? "checkmark" : "arrow.right")
                                .font(.system(size: 15, weight: .black))
                        }
                        .foregroundColor(.appAccentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(currentColor.opacity(disabled ? 0.35 : 1))
                                .shadow(color: currentColor.opacity(disabled ? 0 : 0.45), radius: 18, x: 0, y: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    Text(page < introPages.count
                         ? "You can change anything later."
                         : "Tip: AI nutrition is an estimate. If something looks off, tap the food card and correct it.")
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
                .fill(currentColor.opacity(0.18))
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

    @ViewBuilder
    private func onboardingContent(for index: Int) -> some View {
        if index < introPages.count {
            onboardingPage(introPages[index])
        } else if index == bodySetupPageIndex {
            bodySetupPage
        } else if index == goalSetupPageIndex {
            goalSetupPage
        } else {
            disclaimerPage
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
                    .padding(.horizontal, 18)
            }

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 20)
    }

    private func primaryAction() {
        if page == pageCount - 1 {
            guard disclaimerAccepted else { return }
            useCustomGoals = false
            onComplete()
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                page += 1
            }
        }
    }

    private var bodySetupPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                setupHeader(
                    eyebrow: "YOUR STARTING POINT",
                    title: "Set your body data.",
                    subtitle: "FitMaks uses this to calculate calories and protein before your first scan.",
                    systemName: "person.crop.circle.badge.checkmark",
                    color: .fitPurple
                )

                HStack(spacing: 10) {
                    setupChoiceButton(title: "Male", subtitle: "Formula", isSelected: gender == "Male", color: .fitPurple) {
                        gender = "Male"
                    }
                    setupChoiceButton(title: "Female", subtitle: "Formula", isSelected: gender == "Female", color: .fitPurple) {
                        gender = "Female"
                    }
                }

                onboardingSlider(title: "Age", value: Binding(
                    get: { Double(age) },
                    set: { age = Int($0.rounded()) }
                ), range: 16...80, step: 1, valueText: "\(age)y", color: .fitPurple)

                onboardingSlider(title: "Weight", value: $weight, range: 40...160, step: 0.5, valueText: "\(String(format: "%.1f", weight))kg", color: .neonGreen)

                onboardingSlider(title: "Height", value: $height, range: 140...220, step: 1, valueText: "\(Int(height.rounded()))cm", color: .neonCyan)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var goalSetupPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                setupHeader(
                    eyebrow: "FIRST TARGETS",
                    title: "Choose your goal.",
                    subtitle: "We will calculate a starting target. You can change it anytime in Profile.",
                    systemName: "target",
                    color: .neonGreen
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(goalOptions, id: \.key) { option in
                        setupChoiceButton(title: option.title, subtitle: option.subtitle, isSelected: goal == option.key, color: option.color) {
                            goal = option.key
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Normal week")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.appMuted)
                        .tracking(0.8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(activityOptions) { option in
                            setupChoiceButton(title: option.title, subtitle: option.subtitle, isSelected: activityLevel == option.key, color: .fitPurple) {
                                activityLevel = option.key
                            }
                        }
                    }
                }

                liveTargetPreview
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var disclaimerPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                setupHeader(
                    eyebrow: "IMPORTANT",
                    title: "Before you start.",
                    subtitle: "Please read and accept the following.",
                    systemName: "heart.text.clipboard",
                    color: .fitOrange
                )

                VStack(alignment: .leading, spacing: 14) {
                    disclaimerItem(
                        icon: "stethoscope",
                        title: "Not medical advice",
                        text: "FitMaks provides AI-powered nutritional estimates for informational purposes only. It is not a substitute for professional medical advice, diagnosis, or treatment."
                    )

                    disclaimerItem(
                        icon: "brain.head.profile",
                        title: "AI estimates may be inaccurate",
                        text: "Calorie and macro calculations are approximate. Always verify important nutritional data with product labels or a registered dietitian."
                    )

                    disclaimerItem(
                        icon: "person.badge.shield.checkmark",
                        title: "Consult a professional",
                        text: "Before starting any diet or fitness program, consult your doctor or qualified healthcare provider, especially if you have medical conditions."
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.appSurface)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
                )

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        disclaimerAccepted.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: disclaimerAccepted ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(disclaimerAccepted ? .neonGreen : .appMuted)

                        Text("I understand and accept")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(.appText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(disclaimerAccepted ? Color.neonGreen.opacity(0.10) : Color.appElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(disclaimerAccepted ? Color.neonGreen.opacity(0.35) : Color.appBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func disclaimerItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.fitOrange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.appText)

                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setupHeader(eyebrow: String, title: String, subtitle: String, systemName: String, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.22), Color.appSurface, Color.appElevated],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)
                    .rotationEffect(.degrees(-5))
                    .overlay(RoundedRectangle(cornerRadius: 34).stroke(color.opacity(0.25), lineWidth: 1))

                Image(systemName: systemName)
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 14)
            }

            VStack(spacing: 7) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(color)
                    .tracking(1.2)

                Text(title)
                    .font(.system(size: 27, weight: .black))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    private func setupChoiceButton(title: String, subtitle: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(isSelected ? .appAccentText : .appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(isSelected ? .appAccentText.opacity(0.72) : .appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 19)
                    .fill(isSelected ? color : Color.appSurface)
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(isSelected ? color.opacity(0.65) : Color.appBorder, lineWidth: 1))
            )
            .shadow(color: isSelected ? color.opacity(0.22) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func onboardingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .tracking(0.8)

                Spacer()

                Text(valueText)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(color)
            }

            Slider(value: value, in: range, step: step)
                .tint(color)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
    }

    private var liveTargetPreview: some View {
        HStack(spacing: 10) {
            onboardingTargetCard(title: "Calories", value: "\(Int(recommendedCalories))", unit: "kcal", color: .neonGreen)
            onboardingTargetCard(title: "Protein", value: "\(Int(recommendedProtein))", unit: "g", color: .neonCyan)
        }
    }

    private func onboardingTargetCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.22), lineWidth: 1))
    }
}

private struct OnboardingPage {
    let eyebrow: String
    let title: String
    let subtitle: String
    let systemName: String
    let color: Color
}
