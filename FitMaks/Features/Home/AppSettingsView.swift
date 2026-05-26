import SwiftUI
import StoreKit

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingThemeSelection = false
    @State private var isShowingPaywall = false
    @State private var isShowingSignOutConfirm = false
    @State private var isShowingDeleteConfirm = false

    private var neonPurple: Color { .fitPurple }

    private var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    private var selectedThemeName: String {
        AppTheme.current.palette.name
    }

    var body: some View {
        NavigationView {
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        subscriptionCard
                        if AppTheme.areAlternateThemesEnabled {
                            themeCard
                        }
                        accountCard
                        supportCard
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(neonPurple)
                    .bold()
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .fullScreenCover(isPresented: $isShowingThemeSelection) {
            ThemeSelectionView(isFirstRun: false) {
                isShowingThemeSelection = false
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
        .alert("Sign Out", isPresented: $isShowingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                AuthService.shared.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data stays on this device, but iCloud sync will stop until you sign in again.")
        }
        .alert("Delete Account", isPresented: $isShowingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                AuthService.shared.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your Apple ID link from ShapeForge. Your local data stays on this device. To fully delete iCloud data, go to Settings → Apple ID → iCloud → Manage Storage.")
        }
    }

    private var subscriptionCard: some View {
        let sub = SubscriptionManager.shared

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: sub.isPro ? "crown.fill" : "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(sub.isPro ? .neonGreen : .fitOrange)

                        Text(sub.isPro ? "ShapeForge Pro" : "Free Plan")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.appText)
                    }

                    if sub.isPro {
                        Text("All features unlocked")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appMuted)
                    } else {
                        Text("\(AIUsageLimiter.scansRemaining) AI scans left today")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appMuted)
                    }
                }

                Spacer()

                if !sub.isPro {
                    Button {
                        isShowingPaywall = true
                    } label: {
                        Text("Upgrade")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.appAccentText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.neonGreen))
                            .shadow(color: .neonGreen.opacity(0.3), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }

            if sub.isPro {
                Button {
                    Task {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            try? await AppStore.showManageSubscriptions(in: windowScene)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                            .font(.system(size: 13, weight: .bold))
                        Text("Manage Subscription")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await sub.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.appMuted)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(themeCardGradient())
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(sub.isPro ? Color.neonGreen.opacity(0.22) : Color.appBorder, lineWidth: 1)
                )
        )
        .shadow(color: sub.isPro ? .neonGreen.opacity(0.1) : .clear, radius: 14, y: 7)
    }

    private var themeCard: some View {
        Button {
            isShowingThemeSelection = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.neonGreen.opacity(0.18))

                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.neonGreen)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Theme")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(.appText)

                    Text(selectedThemeName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.appMuted)
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AuthService.shared.isSignedIn ? Color.neonGreen.opacity(0.18) : Color.appSurface)

                    Image(systemName: AuthService.shared.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AuthService.shared.isSignedIn ? .neonGreen : .appMuted)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    if AuthService.shared.isSignedIn {
                        Text(AuthService.shared.displayName ?? "Apple ID connected")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(.appText)

                        Text(AuthService.shared.email ?? "iCloud sync active")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.appMuted)
                    } else {
                        Text("Not signed in")
                            .font(.headline)
                            .fontWeight(.heavy)
                            .foregroundColor(.appText)

                        Text("Data is local only")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.appMuted)
                    }
                }

                Spacer()
            }

            if AuthService.shared.isSignedIn {
                Button {
                    isShowingSignOutConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .bold))
                        Text("Sign Out")
                            .font(.subheadline)
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    isShowingDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                        Text("Delete Account")
                            .font(.subheadline)
                            .fontWeight(.heavy)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    AuthService.shared.startSignIn()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .bold))
                        Text("Sign in with Apple")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.appAccentText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                }
                .buttonStyle(.plain)

                if let error = AuthService.shared.lastError {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.neonCyan)

                Text("Support & Legal")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.appText)
            }

            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.appMuted)

                Text(appVersionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appMuted)
            }

            Link(destination: URL(string: "https://aback-spot-4bb.notion.site/Privacy-Policy-for-ShapeForge-34bd5554b61f80a49697e680e256a038")!) {
                settingsLinkRow(title: "Privacy Policy", icon: "hand.raised.fill")
            }

            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                settingsLinkRow(title: "Terms of Use", icon: "doc.text.fill")
            }

            Link(destination: URL(string: "mailto:m@makstim.fi")!) {
                settingsLinkRow(title: "Contact Support", icon: "envelope.fill")
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func settingsLinkRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.appMuted)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.appText)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.caption.bold())
                .foregroundColor(.appMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}
