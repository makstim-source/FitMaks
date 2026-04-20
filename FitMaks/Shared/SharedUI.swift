import SwiftUI

struct TypingIndicatorView: View {
    var color: Color
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: 8, height: 8)
                .offset(y: isAnimating ? -3 : 3)
                .animation(.easeInOut(duration: 0.4).repeatForever().delay(0.0), value: isAnimating)

            Circle()
                .frame(width: 8, height: 8)
                .offset(y: isAnimating ? -3 : 3)
                .animation(.easeInOut(duration: 0.4).repeatForever().delay(0.2), value: isAnimating)

            Circle()
                .frame(width: 8, height: 8)
                .offset(y: isAnimating ? -3 : 3)
                .animation(.easeInOut(duration: 0.4).repeatForever().delay(0.4), value: isAnimating)
        }
        .foregroundColor(color)
        .frame(height: 20)
        .onAppear { isAnimating = true }
    }
}

struct TypewriterText: View {
    var text: String
    var isEnabled: Bool
    var speed: UInt64 = 14_000_000

    @State private var displayedText = ""
    @State private var hasAnimated = false

    var body: some View {
        Text(renderedText)
            .onAppear(perform: startIfNeeded)
            .onChange(of: text) { _, _ in
                displayedText = ""
                hasAnimated = false
                startIfNeeded()
            }
    }

    private var renderedText: String {
        guard isEnabled else {
            return text
        }

        return displayedText + (displayedText.count < text.count ? "▌" : "")
    }

    private func startIfNeeded() {
        guard isEnabled else {
            displayedText = text
            return
        }

        guard !hasAnimated else {
            return
        }

        hasAnimated = true
        displayedText = ""

        Task {
            for character in text {
                try? await Task.sleep(nanoseconds: speed)
                await MainActor.run {
                    displayedText.append(character)
                }
            }
        }
    }
}

struct CoachMessageBubble: View {
    var message: ChatMessage
    var accentColor: Color = .neonCyan

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isUser {
                Spacer(minLength: 38)
            } else {
                assistantAvatar
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 7) {
                Text(message.isUser ? "You" : "FitMaks Coach")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(message.isUser ? accentColor.opacity(0.85) : .gray)
                    .tracking(0.6)

                if let image = message.attachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accentColor.opacity(0.5), lineWidth: 1)
                        )
                }

                if !message.text.isEmpty {
                    TypewriterText(text: message.text, isEnabled: !message.isUser && message.shouldTypewrite)
                        .font(.system(size: 15, weight: .medium))
                        .lineSpacing(3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(message.isUser ? .trailing : .leading)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: 292, alignment: message.isUser ? .trailing : .leading)
            .background(bubbleBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(message.isUser ? accentColor.opacity(0.38) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: shadowColor, radius: message.isUser ? 10 : 14, x: 0, y: 6)

            if !message.isUser {
                Spacer(minLength: 38)
            }
        }
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.9), Color.neonGreen.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.black)
        }
        .frame(width: 32, height: 32)
        .shadow(color: accentColor.opacity(0.55), radius: 10)
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: message.isUser
                        ? [accentColor.opacity(0.24), accentColor.opacity(0.10), Color.black.opacity(0.38)]
                        : [Color.white.opacity(0.075), Color.white.opacity(0.035), Color.black.opacity(0.34)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var shadowColor: Color {
        message.isUser ? accentColor.opacity(0.18) : Color.black.opacity(0.24)
    }
}

struct CoachTypingBubble: View {
    var accentColor: Color = .neonCyan

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
            }
            .frame(width: 32, height: 32)

            TypingIndicatorView(color: accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.075))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

            Spacer()
        }
    }
}

struct SwipeToDeleteModifier: ViewModifier {
    var action: () -> Void
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 15).fill(Color.red)
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
            }
            .onTapGesture {
                withAnimation(.spring()) {
                    offset = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    action()
                }
            }

            content
                .background(Color.darkGrey)
                .cornerRadius(15)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                return
                            }

                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -80)
                            } else if offset < 0 && value.translation.width > 0 {
                                offset = min(value.translation.width - 80, 0)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                offset = value.translation.width < -40 ? -80 : 0
                            }
                        }
                )
        }
    }
}

extension View {
    func swipeToDelete(action: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(action: action))
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static let yyyyMM: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}
