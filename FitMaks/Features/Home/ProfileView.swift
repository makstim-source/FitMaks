import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \BodyMetricEntry.date, order: .reverse) var bodyMetrics: [BodyMetricEntry]

    @Binding var gender: String
    @Binding var age: Int
    @Binding var weight: Double
    @Binding var height: Double
    @Binding var goal: String
    @Binding var activityLevel: String
    @Binding var useCustomGoals: Bool
    @Binding var customCalories: Double
    @Binding var customProtein: Double
    @Binding var macroRestriction: String
    @Binding var customFat: Double
    @Binding var customCarbs: Double

    var calculatedCalories: Double
    var calculatedProtein: Double
    var postOptions: [FitMaksPostOption] = []

    @State var isShowingGoalSettings = false
    @State var isShowingWeightInput = false
    @State var isShowingBodyImagePicker = false
    @State var selectedBodyImage: UIImage?
    @State var bodyScanSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State var isAnalyzingBodyScan = false
    @State var bodyScanError: String?
    @State var manualWeightText = ""
    @State var manualBodyFatText = ""
    @State var manualMuscleText = ""
    @State var manualWaterText = ""
    @State var manualBodyMetricDate = Date()
    @State var pendingScannedBodyMetric: PendingBodyMetricScan?
    @State var pendingBodyMetricDate = Date()
    @State var isShowingScannedDatePicker = false
    @State var isImportingHealthMetrics = false
    @State var selectedWeightRange: WeightChartRange = .days30
    @State var selectedBodyChartMetric: BodyChartMetric = .weight
    @State var selectedBodyChartPointDate: Date?
    @State var isInteractingWithBodyChart = false
    @State var lastBodyChartSelectionAt = Date.distantPast
    @State var isShowingBodyMetricHistory = false
    @State private var isShowingAppSettings = false
    @State var isShowingPaywall = false
    @State var goalSnapshot: GoalSnapshot?
    @State var livePayload: FitMaksSharePayload?
    @State var cachedRangeMetrics: [BodyMetricEntry] = []
    @State var aiWeightInsight: String?
    @State var aiWeightLoading = false
    @State var aiWeightError: String?

    var neonPurple: Color { .fitPurple }
    let activityOptions: [ActivityOption] = [
        ActivityOption(key: "Sedentary", title: "Desk job", subtitle: "Mostly sitting"),
        ActivityOption(key: "Light", title: "On your feet", subtitle: "Retail, teaching, walks"),
        ActivityOption(key: "Moderate", title: "Active lifestyle", subtitle: "Walking + errands"),
        ActivityOption(key: "Active", title: "Physical job", subtitle: "Construction, warehouse")
    ]

    // MARK: - Computed Properties

    var bmr: Double {
        NutritionCalculator.bmr(gender: gender, age: age, weight: weight, height: height)
    }

    var selectedActivity: ActivityOption {
        activityOptions.first(where: { $0.key == activityLevel }) ?? activityOptions[2]
    }

    var maintenanceCalories: Double {
        NutritionCalculator.maintenanceCalories(
            gender: gender,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityLevel
        )
    }

    private var goalAdjustment: Double {
        NutritionCalculator.calorieAdjustment(for: goal)
    }

    var recommendedCalories: Double {
        maintenanceCalories + goalAdjustment
    }

    var recommendedProtein: Double {
        NutritionCalculator.recommendedProtein(weight: weight, goal: goal)
    }

    private var weeklyWeightChangeKg: Double {
        abs(goalAdjustment) * 7 / 7700
    }

    var selectedCalories: Double {
        useCustomGoals ? customCalories : recommendedCalories
    }

    var selectedProtein: Double {
        useCustomGoals ? customProtein : recommendedProtein
    }

    var latestBodyMetric: BodyMetricEntry? {
        bodyMetrics.first
    }

    private var previousBodyMetric: BodyMetricEntry? {
        bodyMetrics.dropFirst().first
    }

    var weightTrendDelta: Double? {
        guard let latest = latestBodyMetric, let previous = previousBodyMetric else {
            return nil
        }
        return latest.weightKg - previous.weightKg
    }

    private var selectedRangeBodyMetrics: [BodyMetricEntry] { cachedRangeMetrics }

    var selectedChartBodyMetrics: [BodyMetricEntry] {
        selectedRangeBodyMetrics.filter { selectedBodyChartMetric.value(from: $0) != nil }
    }

    var selectedBodyMetricForReadout: BodyMetricEntry? {
        guard let selectedBodyChartPointDate else { return nil }
        return bodyMetrics.first { abs($0.date.timeIntervalSince(selectedBodyChartPointDate)) < 1 }
    }

    var bodyMetricReadoutEntry: BodyMetricEntry? {
        selectedBodyMetricForReadout ?? latestBodyMetric
    }

    var bodyMetricReadoutTitle: String {
        guard let selectedBodyMetricForReadout else { return "Today" }
        return selectedBodyMetricForReadout.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var goalBadgeText: String {
        switch goal {
        case "Lose Weight": return "CUT"
        case "Recomp": return "RECOMP"
        case "Build Muscle": return "BUILD"
        default: return "MAINTAIN"
        }
    }

    var goalBadgeColor: Color {
        switch goal {
        case "Lose Weight": return .neonGreen
        case "Recomp": return .neonCyan
        case "Build Muscle": return .orange
        default: return .fitPurple
        }
    }

    var adjustmentText: String {
        switch goal {
        case "Lose Weight": return "-500 kcal/day"
        case "Recomp": return "-200 kcal/day"
        case "Build Muscle": return "+250 kcal/day"
        default: return "0 kcal/day"
        }
    }

    var adjustmentDetail: String {
        switch goal {
        case "Lose Weight":
            return "Estimated fat loss: about \(String(format: "%.1f", weeklyWeightChangeKg)) kg/week"
        case "Recomp":
            return "Small deficit with high protein for recomposition"
        case "Build Muscle":
            return "Lean surplus: about \(String(format: "%.1f", weeklyWeightChangeKg)) kg/week"
        default:
            return "Designed to keep weight stable"
        }
    }

    var proteinDetail: String {
        NutritionCalculator.proteinDetail(for: goal)
    }

    // MARK: - Body

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
                        goalsHeader
                        recommendationCard
                        changeGoalsButton
                        profileSectionDivider(title: "Body tracking")
                        weightTrackerCard
                        profileSectionDivider(title: "App")
                        appSettingsButton
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            clearBodyChartSelectionIfExternalTap()
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { _ in
                            if selectedBodyChartPointDate != nil && !isInteractingWithBodyChart {
                                clearBodyChartSelection()
                            }
                        }
                )
            }
            .navigationTitle("Profile & Goals")
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
        .onAppear { rebuildRangeMetricsCache() }
        .onChange(of: selectedWeightRange) { _, _ in
            rebuildRangeMetricsCache()
            aiWeightInsight = nil
            aiWeightError = nil
        }
        .onChange(of: bodyMetrics) { _, _ in rebuildRangeMetricsCache() }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .sheet(isPresented: $isShowingGoalSettings) {
            goalSettingsSheet
        }
        .sheet(isPresented: $isShowingWeightInput) {
            manualWeightSheet
        }
        .sheet(isPresented: $isShowingBodyMetricHistory) {
            bodyMetricHistorySheet
        }
        .sheet(isPresented: $isShowingScannedDatePicker) {
            scannedDateConfirmationSheet
        }
        .sheet(isPresented: $isShowingBodyImagePicker) {
            ImagePicker(selectedImage: $selectedBodyImage, sourceType: bodyScanSourceType)
        }
        .fullScreenCover(item: $livePayload) { payload in
            FitMaksLiveView(payload: payload, options: mergedPostOptions())
        }
        .fullScreenCover(isPresented: $isShowingAppSettings) {
            AppSettingsView()
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
        .alert("Weight scan", isPresented: Binding(
            get: { bodyScanError != nil },
            set: { if !$0 { bodyScanError = nil } }
        )) {
            Button("OK", role: .cancel) {
                bodyScanError = nil
            }
        } message: {
            Text(bodyScanError ?? "")
        }
        .onChange(of: selectedBodyImage) { _, image in
            guard let image else { return }
            analyzeBodyImage(image)
        }
    }

    // MARK: - Top-Level Views

    private var goalsHeader: some View {
        HStack(spacing: 14) {
            goalStat(title: "DAILY CALORIES", value: "\(Int(selectedCalories))", unit: "kcal", color: .appText)
            goalStat(title: "DAILY PROTEIN", value: "\(Int(selectedProtein))", unit: "g", color: neonPurple)
        }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("WHY THIS TARGET", systemImage: "function")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(neonPurple)
                        .tracking(0.8)

                    Text("\(Int(recommendedCalories)) kcal/day")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.appText)
                }

                Spacer()

                Text(goalBadgeText)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(goalBadgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(goalBadgeColor.opacity(0.14)))
            }

            VStack(spacing: 10) {
                explanationRow(title: "BMR", value: "\(Int(bmr)) kcal", detail: "Your base burn at rest")
                explanationRow(title: "Maintenance", value: "\(Int(maintenanceCalories)) kcal", detail: "\(selectedActivity.title) x\(String(format: "%.3g", selectedActivity.multiplier))")
                explanationRow(title: "Adjustment", value: adjustmentText, detail: adjustmentDetail)
                explanationRow(title: "Protein", value: "\(Int(recommendedProtein))g", detail: proteinDetail)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(neonPurple.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: neonPurple.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    private var changeGoalsButton: some View {
        Button {
            isShowingGoalSettings = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(neonPurple.opacity(0.18))

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(neonPurple)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Change goals / data")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(.appText)

                    Text("Goal, activity, body numbers and custom targets.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
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

    private var appSettingsButton: some View {
        let sub = SubscriptionManager.shared

        return Button {
            isShowingAppSettings = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(neonPurple.opacity(0.18))

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(neonPurple)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("App settings")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(.appText)

                    Text("Theme, subscription, account and privacy.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(sub.isPro ? "PRO" : "FREE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(sub.isPro ? .appAccentText : .fitOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(sub.isPro ? Color.neonGreen : Color.fitOrange.opacity(0.16))
                        )

                    Text(AuthService.shared.isSignedIn ? "iCloud sync" : "Local only")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundColor(.appMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.appMuted)
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared UI Helpers

    func profileSectionDivider(title: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 1)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(1.2)
                .lineLimit(1)

            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(.appMuted)
            .tracking(0.8)
    }

    func goalStat(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .fontWeight(.heavy)
                .foregroundColor(.appMuted)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color.opacity(0.72))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }

    func explanationRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)

                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.appMuted)
            }

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.heavy)
                .foregroundColor(.appText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }

    func rebuildRangeMetricsCache() {
        let calendar = Calendar.current
        let startDate = calendar.date(
            byAdding: .day,
            value: -(selectedWeightRange.days - 1),
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        cachedRangeMetrics = Array(bodyMetrics.filter { $0.date >= startDate }.reversed())
    }
}
