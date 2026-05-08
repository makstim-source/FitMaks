import SwiftUI

struct NewEntrySheet: View {
    var onFromFridge: () -> Void
    var onFromMeals: () -> Void
    var onBuildMeal: () -> Void
    var onCamera: () -> Void
    var onLibrary: () -> Void
    var onTypeText: () -> Void
    var onTraining: () -> Void
    var onTypeTraining: () -> Void
    var onFAQ: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEW ENTRY")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(1)
                    Text("Log something")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.appText)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appMuted)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.appElevated))
                }
                .buttonStyle(.plain)
            }

            newEntrySection("YOUR STUFF", color: .neonGreen) {
                HStack(spacing: 10) {
                    newEntryButton("From Fridge", icon: "refrigerator.fill", color: .neonCyan, surfaceTint: .neonCyan, action: onFromFridge)
                    newEntryButton("From Meals", icon: "fork.knife", color: .fitOrange, surfaceTint: .neonCyan, action: onFromMeals)
                    newEntryButton("Build Meal", icon: "link", color: .yellow, surfaceTint: .neonCyan, action: onBuildMeal)
                }
            }

            newEntrySection("CAPTURE FOOD", color: .fitOrange) {
                HStack(spacing: 10) {
                    newEntryButton("Camera", icon: "camera.fill", color: .neonGreen, surfaceTint: .neonGreen, action: onCamera)
                    newEntryButton("Library", icon: "photo.on.rectangle", color: .yellow, surfaceTint: .neonGreen, action: onLibrary)
                    newEntryButton("Type Food", icon: "pencil", color: .fitPurple, surfaceTint: .neonGreen, action: onTypeText)
                }
            }

            HStack {
                newEntrySection("TRAINING", color: .neonCyan) { EmptyView() }
                Spacer()
                newEntrySection("HELP", color: .fitPurple) { EmptyView() }
            }
            HStack(spacing: 10) {
                newEntryButton("Training Screenshot", icon: "dumbbell.fill", color: .neonCyan, surfaceTint: .fitOrange, action: onTraining)
                newEntryButton("Type Training", icon: "pencil.line", color: .fitPurple, surfaceTint: .fitOrange, action: onTypeTraining)
                newEntryButton("F.A.Q.", icon: "questionmark.circle.fill", color: .fitPurple, surfaceTint: .fitPurple, action: onFAQ)
            }

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appElevated)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.appBackgroundMid, Color.appBackgroundEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func newEntrySection<Content: View>(_ title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)
                .overlay(
                    Rectangle()
                        .fill(color)
                        .frame(height: 2)
                        .offset(y: 8),
                    alignment: .bottom
                )
                .padding(.bottom, 4)
            content()
        }
    }

    private func newEntryButton(_ title: String, icon: String, color: Color, surfaceTint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(color)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )

                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                surfaceTint.opacity(0.11),
                                Color.appSurface.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(surfaceTint.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(color: surfaceTint.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FAQ Sheet

struct FAQSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(icon: String, color: Color, q: String, a: String)] = [
        ("camera.fill", .neonGreen, "How do I log food?",
         "Tap the + button and choose Camera or Library. Take a photo of your meal — AI will recognize the food, estimate weight, and calculate calories, protein, carbs, and fat automatically."),
        ("pencil", .fitPurple, "Can I log food without a photo?",
         "Yes! Use Type Text and describe what you ate, e.g. \"200g chicken breast and rice\". AI will analyze it the same way."),
        ("refrigerator.fill", .neonCyan, "What is the Fridge?",
         "The Fridge stores your favorite foods. When you save a food to the Fridge, you can quickly add it again later without taking a new photo."),
        ("fork.knife", .fitOrange, "What are Meals?",
         "Meals are saved recipes — full dishes you eat regularly. Save any analyzed food as a Meal to reuse it with one tap."),
        ("link", .yellow, "How does Build Meal work?",
         "Build Meal lets you combine items from your Fridge into a custom meal. Select ingredients and adjust portions by grams to create a precise nutritional breakdown."),
        ("dumbbell.fill", .neonCyan, "How do I log training?",
         "You can upload a screenshot from your fitness app (Apple Watch, Strava, etc.) or type a description like \"Padel 2 hours\" or \"Gym: bench press 4x10 80kg\"."),
        ("flame.fill", .neonGreen, "How are calories calculated?",
         "AI analyzes your food photos using visual recognition. It identifies each ingredient, estimates portions, and calculates macros. You can chat with AI to correct any mistakes."),
        ("leaf.fill", .fitOrange, "What are Carbs and Fat targets?",
         "Carbs behave like fuel: rest days keep the cap tighter, while cardio days expand it. Fat is shown as a comfort zone instead of a race to 100%, so you can stay inside a more useful daily range."),
        ("trophy.fill", .yellow, "How do achievements work?",
         "You earn badges for streaks, consistency, and milestones — like hitting your goals 7 days in a row. Check the Badges section to see your progress."),
        ("camera.fill", .fitOrange, "How does Post work?",
         "Tap Post to create a share card of your daily progress, meals, workouts, or achievements. Pick a background, customize the look, and share it to Instagram Stories, friends, or save it.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("F.A.Q.")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.yellow)
                        .tracking(1)
                    Text("How to use FitMaks")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.appText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appMuted)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.appElevated))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        faqRow(icon: item.icon, color: item.color, question: item.q, answer: item.a)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.appBackgroundStart,
                    Color.appBackgroundMid.opacity(0.96),
                    Color.appBackgroundEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.yellow.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .blur(radius: 54)
                    .offset(x: 72, y: -70)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(Color.neonGreen.opacity(0.07))
                    .frame(width: 260, height: 260)
                    .blur(radius: 72)
                    .offset(x: -90, y: 90)
            }
        )
    }

    private func faqRow(icon: String, color: Color, question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.20), color.opacity(0.09)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.22), lineWidth: 1)
                    )
                Text(question)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.appText)
            }
            Text(answer)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appText.opacity(0.78))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appSurface,
                            Color.appElevated.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: Color.appElevated, radius: 10, x: 0, y: 6)
    }
}
