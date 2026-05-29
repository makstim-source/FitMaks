import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var subscription = SubscriptionManager.shared

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var isShowingOfferCodeSheet = false
    @State private var isShowingPromoAlert = false
    @State private var promoCodeInput = ""
    @State private var promoError = false

    private let features: [(icon: String, title: String, free: String, pro: String)] = [
        ("camera.fill", "AI Food Scans", "2 / day", "Unlimited"),
        ("sparkles", "AI Coach", "—", "Full access"),
        ("fork.knife", "Meal Critique", "—", "Full access"),
        ("chart.bar.fill", "Weekly Reports", "Basic", "Detailed"),
        ("paintpalette.fill", "Themes", "Default", "All themes"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        featureGrid
                        productCards
                        restoreAndPromoButtons
                        legalLinks
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("ShapeForge Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appMuted)
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .task {
            await subscription.loadProducts()
            selectedProduct = subscription.yearlyProduct ?? subscription.monthlyProduct
        }
        .onChange(of: subscription.products.count) { _, _ in
            if selectedProduct == nil {
                selectedProduct = subscription.yearlyProduct ?? subscription.monthlyProduct
            }
        }
        .offerCodeRedemption(isPresented: $isShowingOfferCodeSheet) { result in
            if case .success = result {
                Task {
                    await subscription.refreshEntitlements()
                    if subscription.isPro { dismiss() }
                }
            }
        }
        .alert("Enter Promo Code", isPresented: $isShowingPromoAlert) {
            TextField("Code", text: $promoCodeInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("Redeem") {
                if subscription.redeemTesterCode(promoCodeInput) {
                    dismiss()
                } else {
                    promoError = true
                }
                promoCodeInput = ""
            }
            Button("Apple Offer Code") { isShowingOfferCodeSheet = true; promoCodeInput = "" }
            Button("Cancel", role: .cancel) { promoCodeInput = "" }
        }
        .alert("Invalid code", isPresented: $promoError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This promo code is not recognized.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 36)
                    .fill(
                        LinearGradient(
                            colors: [Color.neonGreen.opacity(0.22), Color.appSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-5))
                    .shadow(color: .neonGreen.opacity(0.25), radius: 24, y: 12)

                Image(systemName: "crown.fill")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(.neonGreen)
                    .shadow(color: .neonGreen.opacity(0.65), radius: 16)
            }

            Text("Unlock everything.")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)

            Text("Unlimited AI scans, full coach access, detailed reports, and all premium features.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
    }

    private var featureGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FEATURE")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("FREE")
                    .frame(width: 80)
                Text("PRO")
                    .frame(width: 80)
            }
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.appMuted)
            .tracking(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ForEach(features, id: \.title) { feature in
                HStack(spacing: 10) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.neonGreen)
                        .frame(width: 20)

                    Text(feature.title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(feature.free)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appMuted)
                        .frame(width: 80)

                    Text(feature.pro)
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.neonGreen)
                        .frame(width: 80)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if feature.title != features.last?.title {
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.appBorder, lineWidth: 1))
        )
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            if let yearly = subscription.yearlyProduct {
                productCard(yearly, isYearly: true)
            }
            if let monthly = subscription.monthlyProduct {
                productCard(monthly, isYearly: false)
            }

            if subscription.products.isEmpty && !subscription.isLoading {
                VStack(spacing: 10) {
                    Text("Subscriptions are loading...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)

                    Text("Please check your internet connection and try again. If the issue persists, restart the app.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appMuted)
                        .multilineTextAlignment(.center)

                    Button {
                        Task {
                            await subscription.loadProducts()
                            selectedProduct = subscription.yearlyProduct ?? subscription.monthlyProduct
                        }
                    } label: {
                        Text("Retry")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.appAccentText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.neonGreen))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }

            Button {
                guard let product = selectedProduct else { return }
                isPurchasing = true
                Task {
                    await subscription.purchase(product)
                    isPurchasing = false
                    if subscription.isPro { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.appAccentText)
                    }
                    Text("Subscribe")
                        .font(.system(size: 17, weight: .black))
                }
                .foregroundColor(.appAccentText)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule()
                        .fill(selectedProduct == nil || isPurchasing ? Color.gray.opacity(0.45) : Color.neonGreen)
                        .shadow(color: .neonGreen.opacity(0.35), radius: 18, y: 8)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedProduct == nil || isPurchasing)

            if let error = subscription.purchaseError, subscription.products.isEmpty == false {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.fitOrange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var yearlySavingsPercent: Int? {
        guard let monthly = subscription.monthlyProduct,
              let yearly = subscription.yearlyProduct else { return nil }
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let savings = (monthlyAnnual - yearly.price) / monthlyAnnual * 100
        let rounded = NSDecimalNumber(decimal: savings).intValue
        return rounded > 0 ? rounded : nil
    }

    private func yearlyPerMonth(_ yearly: Product) -> String {
        let perMonth = yearly.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = yearly.priceFormatStyle.locale
        formatter.maximumFractionDigits = 2
        return formatter.string(from: perMonth as NSDecimalNumber) ?? ""
    }

    private func productCard(_ product: Product, isYearly: Bool) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button {
            withAnimation(.spring(response: 0.25)) { selectedProduct = product }
        } label: {
            VStack(spacing: 0) {
                if isYearly, let pct = yearlySavingsPercent {
                    Text("SAVE \(pct)% — \(yearlyPerMonth(product))/mo instead of \(subscription.monthlyProduct?.displayPrice ?? "")/mo")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.appAccentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.fitOrange)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.appText)

                        Text(isYearly
                             ? "\(yearlyPerMonth(product))/mo"
                             : product.description)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isYearly ? .neonGreen : .appMuted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(isSelected ? .neonGreen : .appText)

                        Text(isYearly ? "/year" : "/month")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appMuted)
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.neonGreen : Color.appBorder, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: isSelected ? .neonGreen.opacity(0.15) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var restoreAndPromoButtons: some View {
        HStack(spacing: 20) {
            Button {
                Task { await subscription.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appMuted)
            }

            Text("·").foregroundColor(.appMuted.opacity(0.4))

            Button {
                isShowingPromoAlert = true
            } label: {
                Text("Promo Code")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.appMuted)
            }
        }
    }

    private var legalLinks: some View {
        VStack(spacing: 12) {
            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.appMuted.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 4)

            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://aback-spot-4bb.notion.site/Privacy-Policy-for-ShapeForge-34bd5554b61f80a49697e680e256a038")!)
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.appMuted.opacity(0.7))
        }
    }
}
