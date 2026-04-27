import SwiftUI
import AuthenticationServices

struct SignInView: View {
    var onContinue: () -> Void

    @State private var animatePulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.neonCyan.opacity(0.15))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: 90, y: -100)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(Color.neonGreen.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -120, y: 80)
                }

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 36)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.neonGreen.opacity(0.23),
                                    Color.neonCyan.opacity(0.12),
                                    Color.appSurface
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(animatePulse ? -3 : 3))
                        .shadow(color: .neonGreen.opacity(0.3), radius: 24)

                    Image(systemName: "sparkles")
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(.neonGreen)
                        .scaleEffect(animatePulse ? 1.06 : 0.96)
                        .shadow(color: .neonGreen.opacity(0.7), radius: 18)
                }

                VStack(spacing: 8) {
                    Text("FitMaks")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.appText)
                        .tracking(1.2)

                    Text("Sign in to sync your data\nacross all your devices")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "icloud.fill", color: .neonCyan, text: "Sync food, workouts & metrics via iCloud")
                    featureRow(icon: "arrow.clockwise", color: .neonGreen, text: "Restore everything after reinstall")
                    featureRow(icon: "lock.shield.fill", color: .fitPurple, text: "Private & secure with Apple ID")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.appSurface)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
                )
                .padding(.horizontal, 30)

                Spacer()

                VStack(spacing: 8) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        AuthService.shared.handleSignIn(result)
                        if AuthService.shared.isSignedIn {
                            onContinue()
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(Capsule())

                    if let error = AuthService.shared.lastError {
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 30)

                Button("Continue without account") {
                    onContinue()
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.appMuted)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.12)))

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appText)
        }
    }
}
