import SwiftUI
import SwiftData
import UIKit
import AuthenticationServices

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMetricEntry.date, order: .reverse) private var bodyMetrics: [BodyMetricEntry]

    @Binding var gender: String
    @Binding var age: Int
    @Binding var weight: Double
    @Binding var height: Double
    @Binding var goal: String
    @Binding var activityLevel: String
    @Binding var useCustomGoals: Bool
    @Binding var customCalories: Double
    @Binding var customProtein: Double

    var calculatedCalories: Double
    var calculatedProtein: Double

    @State private var isShowingGoalSettings = false
    @State private var isShowingWeightInput = false
    @State private var isShowingBodyImagePicker = false
    @State private var selectedBodyImage: UIImage?
    @State private var bodyScanSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isAnalyzingBodyScan = false
    @State private var bodyScanError: String?
    @State private var manualWeightText = ""
    @State private var manualBodyFatText = ""
    @State private var manualMuscleText = ""
    @State private var manualWaterText = ""
    @State private var manualBodyMetricDate = Date()
    @State private var pendingScannedBodyMetric: PendingBodyMetricScan?
    @State private var pendingBodyMetricDate = Date()
    @State private var isShowingScannedDatePicker = false
    @State private var isImportingHealthMetrics = false
    @State private var selectedWeightRange: WeightChartRange = .days30
    @State private var selectedBodyChartMetric: BodyChartMetric = .weight
    @State private var selectedBodyChartPointDate: Date?
    @State private var isInteractingWithBodyChart = false
    @State private var lastBodyChartSelectionAt = Date.distantPast
    @State private var isShowingBodyMetricHistory = false
    @State private var isShowingSignOutConfirm = false
    @State private var isShowingDeleteConfirm = false

    private var neonPurple: Color { .fitPurple }
    private let activityOptions: [ActivityOption] = [
        ActivityOption(key: "Sedentary", title: "Desk days", subtitle: "Mostly sitting, little walking"),
        ActivityOption(key: "Light", title: "Daily walks", subtitle: "Walks or 1-2 workouts/week"),
        ActivityOption(key: "Moderate", title: "Train weekly", subtitle: "3-4 workouts and normal walking"),
        ActivityOption(key: "Active", title: "Athlete mode", subtitle: "5+ hard days or physical job")
    ]

    private var bmr: Double {
        NutritionCalculator.bmr(gender: gender, age: age, weight: weight, height: height)
    }

    private var selectedActivity: ActivityOption {
        activityOptions.first(where: { $0.key == activityLevel }) ?? activityOptions[2]
    }

    private var maintenanceCalories: Double {
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

    private var recommendedCalories: Double {
        maintenanceCalories + goalAdjustment
    }

    private var recommendedProtein: Double {
        NutritionCalculator.recommendedProtein(weight: weight, goal: goal)
    }

    private var weeklyWeightChangeKg: Double {
        abs(goalAdjustment) * 7 / 7700
    }

    private var selectedCalories: Double {
        useCustomGoals ? customCalories : recommendedCalories
    }

    private var selectedProtein: Double {
        useCustomGoals ? customProtein : recommendedProtein
    }

    private var latestBodyMetric: BodyMetricEntry? {
        bodyMetrics.first
    }

    private var previousBodyMetric: BodyMetricEntry? {
        bodyMetrics.dropFirst().first
    }

    private var weightTrendDelta: Double? {
        guard let latest = latestBodyMetric, let previous = previousBodyMetric else {
            return nil
        }

        return latest.weightKg - previous.weightKg
    }

    private var selectedRangeBodyMetrics: [BodyMetricEntry] {
        let calendar = Calendar.current
        let startDate = calendar.date(
            byAdding: .day,
            value: -(selectedWeightRange.days - 1),
            to: calendar.startOfDay(for: Date())
        ) ?? Date()

        return Array(bodyMetrics.filter { $0.date >= startDate }.reversed())
    }

    private var selectedChartBodyMetrics: [BodyMetricEntry] {
        selectedRangeBodyMetrics.filter { selectedBodyChartMetric.value(from: $0) != nil }
    }

    private var selectedBodyMetricForReadout: BodyMetricEntry? {
        guard let selectedBodyChartPointDate else {
            return nil
        }

        return bodyMetrics.first { abs($0.date.timeIntervalSince(selectedBodyChartPointDate)) < 1 }
    }

    private var bodyMetricReadoutEntry: BodyMetricEntry? {
        selectedBodyMetricForReadout ?? latestBodyMetric
    }

    private var bodyMetricReadoutTitle: String {
        guard let selectedBodyMetricForReadout else {
            return "Today"
        }

        return selectedBodyMetricForReadout.date.formatted(.dateTime.day().month(.abbreviated))
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
                        goalsHeader
                        recommendationCard
                        changeGoalsButton
                        profileSectionDivider(title: "Body tracking")
                        weightTrackerCard
                        profileSectionDivider(title: "Account")
                        accountCard
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
                    Button("Save") {
                        dismiss()
                    }
                    .foregroundColor(neonPurple)
                    .bold()
                }
            }
        }
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
            Text("This removes your Apple ID link from FitMaks. Your local data stays on this device. To fully delete iCloud data, go to Settings → Apple ID → iCloud → Manage Storage.")
        }
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

                        Text("iCloud sync active")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.neonGreen)
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
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    AuthService.shared.handleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.appBorder, lineWidth: 1))
        )
    }

    private var goalsHeader: some View {
        HStack(spacing: 14) {
            goalStat(title: "DAILY CALORIES", value: "\(Int(selectedCalories))", unit: "kcal", color: .appText)
            goalStat(title: "DAILY PROTEIN", value: "\(Int(selectedProtein))", unit: "g", color: neonPurple)
        }
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

    private func profileSectionDivider(title: String) -> some View {
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

    private var goalSettingsSheet: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        goalsPreviewCard
                        goalAndGenderCard
                        activityCard
                        bodyMetricsCard
                        customGoalsCard
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Goals & Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowingGoalSettings = false
                    }
                    .foregroundColor(neonPurple)
                    .bold()
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .presentationDetents([.large])
    }

    private var goalsPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LIVE TARGET")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(1)

                    Text("\(Int(selectedCalories)) kcal")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(.appText)

                    Text("\(Int(selectedProtein))g protein")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(neonPurple)
                }

                Spacer()

                Text(useCustomGoals ? "CUSTOM" : goalBadgeText)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(useCustomGoals ? neonPurple : goalBadgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill((useCustomGoals ? neonPurple : goalBadgeColor).opacity(0.14)))
            }

            HStack(spacing: 10) {
                goalsPreviewMiniStat(title: "BMR", value: "\(Int(bmr))")
                goalsPreviewMiniStat(title: "Maintain", value: "\(Int(maintenanceCalories))")
                goalsPreviewMiniStat(title: "Week", value: "x\(String(format: "%.3g", selectedActivity.multiplier))")
            }

            Text(useCustomGoals ? "Custom goals are on, so FitMaks will use your manual calorie and protein targets." : "\(selectedActivity.title) · \(adjustmentText) · \(proteinDetail)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .lineSpacing(3)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.neonGreen.opacity(0.18), lineWidth: 1)
        )
    }

    private var weightTrackerCard: some View {
        let chartMetrics = selectedChartBodyMetrics

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("BODY TRACKER", systemImage: "chart.xyaxis.line")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.neonGreen)
                        .tracking(0.8)

                    Text(latestBodyMetric.map { "\(String(format: "%.1f", $0.weightKg)) kg" } ?? "Log your weight")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(selectedBodyChartMetric == .weight ? .neonGreen : .appText)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                selectedBodyChartMetric = .weight
                            }
                        }
                }

                Spacer()

                if let delta = weightTrendDelta {
                    trendPill(delta)
                }
            }

            if bodyMetrics.isEmpty {
                emptyWeightState
            } else {
                weightRangePicker

                if chartMetrics.isEmpty {
                    Text("No \(selectedBodyChartMetric.emptyName.lowercased()) logs in the last \(selectedWeightRange.title.lowercased()).")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appMuted)
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appSurface))
                } else {
                    WeightTrendChart(
                        entries: chartMetrics,
                        metric: selectedBodyChartMetric,
                        range: selectedWeightRange,
                        accentColor: selectedBodyChartMetric.color,
                        selectedDate: $selectedBodyChartPointDate,
                        isInteracting: $isInteractingWithBodyChart,
                        onSelectionChanged: noteBodyChartSelection
                    )
                        .frame(height: 184)
                }

                bodyCompositionGrid
                weightInsightText
                bodyMetricHistory
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    bodyMetricActionButton(title: "Type", systemName: "keyboard.fill", color: .neonGreen) {
                        prepareManualWeightSheet()
                        isShowingWeightInput = true
                    }

                    bodyMetricActionButton(title: "Screenshot", systemName: "photo.on.rectangle.angled", color: .neonCyan) {
                        bodyScanSourceType = .photoLibrary
                        isShowingBodyImagePicker = true
                    }
                }

                appleHealthImportButton {
                    importHealthBodyMetrics()
                }
            }

            if isAnalyzingBodyScan || isImportingHealthMetrics {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.neonGreen)

                    Text(isImportingHealthMetrics ? "Importing Apple Health history..." : "Reading scale data...")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.appMuted)
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.appElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.neonGreen.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.neonGreen.opacity(0.10), radius: 22, x: 0, y: 10)
    }

    private var emptyWeightState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start with one check-in.")
                .font(.headline)
                .fontWeight(.heavy)
                .foregroundColor(.appText)

            Text("Type your weight, import Apple Health, upload a smart-scale screenshot, or photograph the scale. FitMaks will build the trend and body-composition story here.")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.appMuted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
    }

    private var bodyCompositionGrid: some View {
        let entry = bodyMetricReadoutEntry
        let weightValue = entry.map { "\(String(format: "%.1f", $0.weightKg))kg" } ?? "—"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(bodyMetricReadoutTitle) metrics")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Spacer()

                if selectedBodyMetricForReadout != nil {
                    Button {
                        clearBodyChartSelection()
                    } label: {
                        Label("Back to today", systemImage: "arrow.uturn.backward")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundColor(.neonGreen)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                bodyMetricMiniCard(title: "Fat", value: percentText(entry?.bodyFatPercent), metric: .fat)
                bodyMetricMiniCard(title: "Muscle", value: percentText(entry?.musclePercent), metric: .muscle)
                bodyMetricMiniCard(title: "Weight", value: weightValue, metric: .weight)
            }
        }
    }

    private var weightRangePicker: some View {
        HStack(spacing: 8) {
            ForEach(WeightChartRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        clearBodyChartSelection()
                        selectedWeightRange = range
                    }
                } label: {
                    Text(range.title)
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(selectedWeightRange == range ? .appAccentText : .appText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedWeightRange == range ? Color.neonGreen : Color.appSurface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedWeightRange == range ? Color.neonGreen.opacity(0.55) : Color.appBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weightInsightText: some View {
        Text(weightInsight)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.appMuted)
            .lineSpacing(3)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
    }

    private var bodyMetricHistory: some View {
        let visibleHistory = Array(bodyMetrics.prefix(3))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("History")

                Spacer()

                Text("\(bodyMetrics.count) logs")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
            }

            VStack(spacing: 8) {
                ForEach(visibleHistory) { entry in
                    bodyMetricHistoryRow(entry)
                }
            }

            if bodyMetrics.count > visibleHistory.count {
                Button {
                    isShowingBodyMetricHistory = true
                } label: {
                    HStack {
                        Text("Other weigh-ins")
                            .font(.caption)
                            .fontWeight(.heavy)

                        Spacer()

                        Text("\(bodyMetrics.count - visibleHistory.count) more")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundColor(.appMuted)

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.appText)
                    .padding(13)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.appSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bodyMetricHistorySheet: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(bodyMetrics) { entry in
                            bodyMetricHistoryRow(entry)
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Weigh-ins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowingBodyMetricHistory = false
                    }
                    .foregroundColor(neonPurple)
                    .bold()
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .presentationDetents([.large])
    }

    private var weightInsight: String {
        guard let latest = latestBodyMetric else {
            return "Add your first check-in to see progress."
        }

        guard let delta = weightTrendDelta else {
            return "First check-in saved. Add a few more and the trend will become useful instead of noisy."
        }

        let direction = delta < 0 ? "down" : "up"
        let absDelta = abs(delta)
        let dateText = latest.date.formatted(date: .abbreviated, time: .omitted)

        if absDelta < 0.15 {
            return "Stable since the previous check-in. Nice: one reading is noise, the trend is the signal."
        }

        return "Latest check-in \(dateText): \(direction) \(String(format: "%.1f", absDelta)) kg from the previous log. Watch the 7-14 day trend, not one salty dinner."
    }

    private var manualWeightSheet: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LOG BODY DATA")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.neonGreen)
                                .tracking(1)

                            Text("Add what you know.")
                                .font(.system(size: 30, weight: .black))
                                .foregroundColor(.appText)

                            Text("Weight is required. Fat, muscle and water are optional, but useful if your smart scale shows them.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.appMuted)
                                .lineSpacing(3)
                        }

                        VStack(spacing: 12) {
                            DatePicker("Date", selection: $manualBodyMetricDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundColor(.appText)
                                .padding(15)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))

                            bodyInputField(title: "Weight", value: $manualWeightText, unit: "kg", required: true)
                            bodyInputField(title: "Body fat", value: $manualBodyFatText, unit: "%", required: false)
                            bodyInputField(title: "Muscle", value: $manualMuscleText, unit: "%", required: false)
                            bodyInputField(title: "Water", value: $manualWaterText, unit: "%", required: false)
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isShowingWeightInput = false
                    }
                    .foregroundColor(.appMuted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveManualBodyMetric()
                    }
                    .foregroundColor(.neonGreen)
                    .bold()
                    .disabled(number(from: manualWeightText) == nil)
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .presentationDetents([.medium, .large])
    }

    private var scannedDateConfirmationSheet: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DATE NEEDED")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.fitOrange)
                            .tracking(1)

                        Text("When was this measured?")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.appText)

                        Text("I found the body data, but not the date on the screenshot/photo. Pick the date so the graph stays honest.")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.appMuted)
                            .lineSpacing(3)
                    }

                    if let pendingScannedBodyMetric {
                        HStack(spacing: 10) {
                            bodyMetricReadoutCard(title: "Weight", value: "\(String(format: "%.1f", pendingScannedBodyMetric.weightKg))kg", color: .neonGreen)
                            bodyMetricReadoutCard(title: "Fat", value: percentText(pendingScannedBodyMetric.bodyFatPercent), color: .fitOrange)
                            bodyMetricReadoutCard(title: "Muscle", value: percentText(pendingScannedBodyMetric.musclePercent), color: .neonCyan)
                        }
                    }

                    DatePicker("Date", selection: $pendingBodyMetricDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.neonGreen)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 24).fill(Color.appElevated))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.appBorder, lineWidth: 1))

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Weight date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        pendingScannedBodyMetric = nil
                        isShowingScannedDatePicker = false
                    }
                    .foregroundColor(.appMuted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePendingScannedBodyMetric()
                    }
                    .foregroundColor(.neonGreen)
                    .bold()
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .presentationDetents([.large])
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

    private var goalAndGenderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle("Goal")
                Spacer()
                liveTargetBadge
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                goalButton(title: "Cut", subtitle: "Lose fat", key: "Lose Weight", color: .neonGreen)
                goalButton(title: "Recomp", subtitle: "Lean + muscle", key: "Recomp", color: .neonCyan)
                goalButton(title: "Maintain", subtitle: "Hold shape", key: "Maintain", color: .fitPurple)
                goalButton(title: "Build", subtitle: "Gain muscle", key: "Build Muscle", color: .orange)
            }

            Divider()
                .background(Color.appBorder)

            sectionTitle("Body formula")

            HStack(spacing: 10) {
                genderButton("Male")
                genderButton("Female")
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Normal week")

                Spacer()

                liveTargetBadge
            }

            Text("Pick your normal week, not your best week. Calories update instantly.")
                .font(.caption2)
                .foregroundColor(.appMuted)

            VStack(spacing: 10) {
                ForEach(activityOptions) { option in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            calculatorDidChange()
                            activityLevel = option.key
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(activityLevel == option.key ? neonPurple : Color.appSurface)

                                Image(systemName: activityIcon(for: option.key))
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(activityLevel == option.key ? .appAccentText : neonPurple)
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(.subheadline)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.appText)

                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.appMuted)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("x\(String(format: "%.3g", option.multiplier))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(activityLevel == option.key ? neonPurple : .appMuted)

                                Text("\(Int(caloriesForActivity(option.key))) kcal")
                                    .font(.caption2)
                                    .fontWeight(.heavy)
                                    .foregroundColor(activityLevel == option.key ? .appText : .appMuted)
                            }
                        }
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(activityLevel == option.key ? neonPurple.opacity(0.16) : Color.appSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(activityLevel == option.key ? neonPurple.opacity(0.5) : Color.appBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var bodyMetricsCard: some View {
        VStack(spacing: 14) {
            HStack {
                sectionTitle("Your numbers")
                Spacer()
                liveTargetBadge
            }

            HStack {
                Text("Hold +/- for faster changes")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
            }

            MetricStepperCard(
                title: "Age",
                value: Binding(
                    get: { Double(age) },
                    set: {
                        calculatorDidChange()
                        age = Int($0.rounded())
                    }
                ),
                unit: "years",
                range: 10...100,
                step: 1,
                decimals: 0,
                accentColor: neonPurple
            )

            MetricStepperCard(
                title: "Weight",
                value: Binding(
                    get: { weight },
                    set: {
                        calculatorDidChange()
                        weight = $0
                    }
                ),
                unit: "kg",
                range: 40...150,
                step: 0.5,
                decimals: 1,
                accentColor: neonPurple
            )

            MetricStepperCard(
                title: "Height",
                value: Binding(
                    get: { height },
                    set: {
                        calculatorDidChange()
                        height = $0
                    }
                ),
                unit: "cm",
                range: 140...220,
                step: 1,
                decimals: 0,
                accentColor: neonPurple
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    private var customGoalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $useCustomGoals) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Set custom goals")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundColor(.appText)

                    Text("Override the recommendation if you already know your targets.")
                        .font(.caption)
                        .foregroundColor(.appMuted)
                }
            }
            .tint(neonPurple)
            .onChange(of: useCustomGoals) { _, newValue in
                if newValue {
                    if customCalories == 0 {
                        customCalories = recommendedCalories
                    }
                    if customProtein == 0 {
                        customProtein = recommendedProtein
                    }
                }
            }

            if useCustomGoals {
                HStack(spacing: 12) {
                    editableGoalField(title: "Calories", value: $customCalories, unit: "kcal")
                    editableGoalField(title: "Protein", value: $customProtein, unit: "g")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var liveTargetBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .black))

            Text("\(Int(selectedCalories)) kcal · \(Int(selectedProtein))g")
                .font(.caption2)
                .fontWeight(.heavy)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(.neonGreen)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.neonGreen.opacity(0.13)))
    }

    private func goalsPreviewMiniStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.7)

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.appText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
    }

    private func caloriesForActivity(_ activityKey: String) -> Double {
        NutritionCalculator.recommendedCalories(
            gender: gender,
            age: age,
            weight: weight,
            height: height,
            activityLevel: activityKey,
            goal: goal
        )
    }

    private func calculatorDidChange() {
        if useCustomGoals {
            useCustomGoals = false
        }
    }

    private func noteBodyChartSelection() {
        lastBodyChartSelectionAt = Date()
    }

    private func clearBodyChartSelection() {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedBodyChartPointDate = nil
            isInteractingWithBodyChart = false
        }
    }

    private func clearBodyChartSelectionIfExternalTap() {
        guard selectedBodyChartPointDate != nil, !isInteractingWithBodyChart else {
            return
        }

        guard Date().timeIntervalSince(lastBodyChartSelectionAt) > 0.22 else {
            return
        }

        clearBodyChartSelection()
    }

    private func trendPill(_ delta: Double) -> some View {
        let isDown = delta < -0.15
        let isUp = delta > 0.15
        let color: Color = isDown ? .neonGreen : (isUp ? .fitOrange : .neonCyan)
        let symbol = isDown ? "arrow.down.right" : (isUp ? "arrow.up.right" : "equal")
        let text = abs(delta) < 0.15 ? "stable" : "\(delta > 0 ? "+" : "")\(String(format: "%.1f", delta)) kg"

        return Label(text, systemImage: symbol)
            .font(.caption)
            .fontWeight(.heavy)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func bodyMetricActionButton(title: String, systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.appAccentText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(color))
                    .shadow(color: color.opacity(0.30), radius: 8)

                Text(title)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzingBodyScan || isImportingHealthMetrics)
        .opacity(isAnalyzingBodyScan || isImportingHealthMetrics ? 0.55 : 1)
    }

    private func appleHealthImportButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.appAccentText)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(neonPurple))
                    .shadow(color: neonPurple.opacity(0.30), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upload from Apple Health")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.appText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text("Import last 365 days")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(neonPurple)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(neonPurple.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzingBodyScan || isImportingHealthMetrics)
        .opacity(isAnalyzingBodyScan || isImportingHealthMetrics ? 0.55 : 1)
    }

    private func bodyMetricMiniCard(title: String, value: String, metric: BodyChartMetric) -> some View {
        Button {
            if selectedBodyChartPointDate != nil {
                noteBodyChartSelection()
            }

            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedBodyChartMetric = metric
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .tracking(0.8)

                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(value == "—" ? .appMuted : metric.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selectedBodyChartMetric == metric ? metric.color.opacity(0.75) : metric.color.opacity(0.16), lineWidth: selectedBodyChartMetric == metric ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func bodyMetricReadoutCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.appMuted)
                .tracking(0.8)

            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(value == "—" ? .appMuted : color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.16), lineWidth: 1))
    }

    private func bodyMetricHistoryRow(_ entry: BodyMetricEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)

                Text(entry.source)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.appMuted.opacity(0.75))
            }
            .frame(width: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(String(format: "%.1f", entry.weightKg)) kg")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.appText)

                HStack(spacing: 8) {
                    if let bodyFatPercent = entry.bodyFatPercent {
                        Text("Fat \(String(format: "%.1f", bodyFatPercent))%")
                    }

                    if let musclePercent = entry.musclePercent {
                        Text("Muscle \(String(format: "%.1f", musclePercent))%")
                    }
                }
                .font(.caption2)
                .fontWeight(.heavy)
                .foregroundColor(.appMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            Spacer()

            Button(role: .destructive) {
                deleteBodyMetric(entry)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.red)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.red.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
    }

    private func bodyInputField(title: String, value: Binding<String>, unit: String, required: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)

                Text(required ? "Required" : "Optional")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(required ? .neonGreen : .appMuted)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("0", text: value)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)
            }
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
    }

    private func prepareManualWeightSheet() {
        manualBodyMetricDate = Date()
        manualWeightText = latestBodyMetric.map { String(format: "%.1f", $0.weightKg) } ?? String(format: "%.1f", weight)
        manualBodyFatText = latestBodyMetric?.bodyFatPercent.map { String(format: "%.1f", $0) } ?? ""
        manualMuscleText = latestBodyMetric?.musclePercent.map { String(format: "%.1f", $0) } ?? ""
        manualWaterText = latestBodyMetric?.waterPercent.map { String(format: "%.1f", $0) } ?? ""
    }

    private func saveManualBodyMetric() {
        guard let weightKg = number(from: manualWeightText) else {
            return
        }

        addBodyMetric(
            date: manualBodyMetricDate,
            weightKg: weightKg,
            bodyFatPercent: number(from: manualBodyFatText),
            musclePercent: number(from: manualMuscleText),
            waterPercent: number(from: manualWaterText),
            visceralFat: nil,
            metabolicAge: nil,
            note: "Manual check-in",
            source: "Manual"
        )
        isShowingWeightInput = false
    }

    private func analyzeBodyImage(_ image: UIImage) {
        isAnalyzingBodyScan = true
        bodyScanError = nil

        GeminiService.shared.analyzeBodyMetrics(images: [image], note: "") { result, error in
            isAnalyzingBodyScan = false
            selectedBodyImage = nil

            if let result, let weightKg = result.weight_kg {
                let pending = PendingBodyMetricScan(
                    weightKg: weightKg,
                    bodyFatPercent: result.body_fat_percent,
                    musclePercent: result.muscle_percent,
                    waterPercent: result.water_percent,
                    visceralFat: result.visceral_fat,
                    metabolicAge: result.metabolic_age,
                    note: result.ai_summary
                )

                if let date = dateFromAIString(result.measured_date) {
                    addBodyMetric(
                        date: date,
                        weightKg: pending.weightKg,
                        bodyFatPercent: pending.bodyFatPercent,
                        musclePercent: pending.musclePercent,
                        waterPercent: pending.waterPercent,
                        visceralFat: pending.visceralFat,
                        metabolicAge: pending.metabolicAge,
                        note: pending.note,
                        source: "AI scan"
                    )
                } else {
                    pendingScannedBodyMetric = pending
                    pendingBodyMetricDate = Date()
                    isShowingScannedDatePicker = true
                }
            } else {
                bodyScanError = error ?? "I could not read the weight clearly. Try a sharper screenshot/photo or type it manually."
            }
        }
    }

    private func savePendingScannedBodyMetric() {
        guard let pendingScannedBodyMetric else {
            isShowingScannedDatePicker = false
            return
        }

        addBodyMetric(
            date: pendingBodyMetricDate,
            weightKg: pendingScannedBodyMetric.weightKg,
            bodyFatPercent: pendingScannedBodyMetric.bodyFatPercent,
            musclePercent: pendingScannedBodyMetric.musclePercent,
            waterPercent: pendingScannedBodyMetric.waterPercent,
            visceralFat: pendingScannedBodyMetric.visceralFat,
            metabolicAge: pendingScannedBodyMetric.metabolicAge,
            note: pendingScannedBodyMetric.note,
            source: "AI scan"
        )

        self.pendingScannedBodyMetric = nil
        isShowingScannedDatePicker = false
    }

    private func importHealthBodyMetrics() {
        isImportingHealthMetrics = true
        bodyScanError = nil

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate

        HealthKitManager.shared.fetchBodyMetrics(from: startDate, to: endDate) { snapshots in
            isImportingHealthMetrics = false

            guard !snapshots.isEmpty else {
                bodyScanError = "No weight data found in Apple Health for the last year. If you use smart scales, check that they write weight to Health."
                return
            }

            for snapshot in snapshots {
                upsertHealthBodyMetric(snapshot)
            }
        }
    }

    private func upsertHealthBodyMetric(_ snapshot: HealthBodyMetricSnapshot) {
        addBodyMetric(
            date: snapshot.date,
            weightKg: snapshot.weightKg,
            bodyFatPercent: snapshot.bodyFatPercent,
            musclePercent: snapshot.musclePercent,
            waterPercent: nil,
            visceralFat: nil,
            metabolicAge: nil,
            note: "Imported from Apple Health",
            source: "Apple Health"
        )
    }

    private func addBodyMetric(
        date: Date,
        weightKg: Double,
        bodyFatPercent: Double?,
        musclePercent: Double?,
        waterPercent: Double?,
        visceralFat: Double?,
        metabolicAge: Double?,
        note: String,
        source: String
    ) {
        let entry = BodyMetricEntry(
            date: date,
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercent,
            musclePercent: musclePercent,
            waterPercent: waterPercent,
            visceralFat: visceralFat,
            metabolicAge: metabolicAge,
            note: note,
            source: source
        )

        if mergeIntoDailyBestIfNeeded(entry) {
            return
        }

        modelContext.insert(entry)

        if BodyMetricProfileSync.shouldPromoteProfileWeight(
            candidateDate: date,
            currentLatestDate: latestBodyMetric?.date
        ) {
            weight = weightKg
        }
    }

    @discardableResult
    private func mergeIntoDailyBestIfNeeded(_ candidate: BodyMetricEntry) -> Bool {
        let sameDayEntries = bodyMetrics.filter {
            Calendar.current.isDate($0.date, inSameDayAs: candidate.date)
        }

        guard var keeper = sameDayEntries.first else {
            return false
        }

        for entry in sameDayEntries.dropFirst() where BodyMetricDailyBest.shouldReplace(existing: keeper, candidate: entry) {
            keeper = entry
        }

        if BodyMetricDailyBest.shouldReplace(existing: keeper, candidate: candidate) {
            updateBodyMetric(keeper, with: candidate)
        }

        for duplicate in sameDayEntries where duplicate.id != keeper.id {
            modelContext.delete(duplicate)
        }

        if BodyMetricProfileSync.shouldPromoteProfileWeight(
            candidateDate: keeper.date,
            currentLatestDate: latestBodyMetric?.date
        ) {
            weight = keeper.weightKg
        }

        return true
    }

    private func updateBodyMetric(_ entry: BodyMetricEntry, with candidate: BodyMetricEntry) {
        entry.date = candidate.date
        entry.weightKg = candidate.weightKg
        entry.bodyFatPercent = candidate.bodyFatPercent
        entry.musclePercent = candidate.musclePercent
        entry.waterPercent = candidate.waterPercent
        entry.visceralFat = candidate.visceralFat
        entry.metabolicAge = candidate.metabolicAge
        entry.note = candidate.note
        entry.source = candidate.source
    }

    private func deleteBodyMetric(_ entry: BodyMetricEntry) {
        let deletedID = entry.id
        modelContext.delete(entry)

        if latestBodyMetric?.id == deletedID {
            if let nextLatest = bodyMetrics.first(where: { $0.id != deletedID }) {
                weight = nextLatest.weightKg
            }
        }
    }

    private func dateFromAIString(_ value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return DateFormatter.yyyyMMdd.date(from: value)
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return "\(String(format: "%.1f", value))%"
    }

    private func number(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalized)
    }

    private var goalBadgeText: String {
        switch goal {
        case "Lose Weight":
            return "CUT"
        case "Recomp":
            return "RECOMP"
        case "Build Muscle":
            return "BUILD"
        default:
            return "MAINTAIN"
        }
    }

    private var goalBadgeColor: Color {
        switch goal {
        case "Lose Weight":
            return .neonGreen
        case "Recomp":
            return .neonCyan
        case "Build Muscle":
            return .orange
        default:
            return .fitPurple
        }
    }

    private var adjustmentText: String {
        switch goal {
        case "Lose Weight":
            return "-500 kcal/day"
        case "Recomp":
            return "-200 kcal/day"
        case "Build Muscle":
            return "+250 kcal/day"
        default:
            return "0 kcal/day"
        }
    }

    private var adjustmentDetail: String {
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

    private var proteinDetail: String {
        NutritionCalculator.proteinDetail(for: goal)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(.appMuted)
            .tracking(0.8)
    }

    private func goalStat(title: String, value: String, unit: String, color: Color) -> some View {
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

    private func explanationRow(title: String, value: String, detail: String) -> some View {
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

    private func goalButton(title: String, subtitle: String, key: String, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                calculatorDidChange()
                goal = key
            }
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.heavy)
                Text(subtitle)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .opacity(0.7)
            }
            .foregroundColor(goal == key ? .appAccentText : .appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(goal == key ? color : Color.appSurface)
            )
        }
        .buttonStyle(.plain)
    }

    private func genderButton(_ value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                calculatorDidChange()
                gender = value
            }
        } label: {
            Text(value)
                .font(.headline)
                .fontWeight(.heavy)
                .foregroundColor(gender == value ? .appAccentText : .appText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gender == value ? neonPurple : Color.appSurface)
                )
        }
        .buttonStyle(.plain)
    }

    private func editableGoalField(title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.appMuted)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.appText)
                    .multilineTextAlignment(.leading)

                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.appMuted)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
    }

    private func activityIcon(for key: String) -> String {
        switch key {
        case "Sedentary":
            return "chair"
        case "Light":
            return "figure.walk"
        case "Moderate":
            return "figure.run"
        default:
            return "flame.fill"
        }
    }
}
