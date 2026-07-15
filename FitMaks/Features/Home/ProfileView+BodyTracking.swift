import SwiftUI
import SwiftData

// MARK: - Body Tracking Card & Components
extension ProfileView {

    var weightTrackerCard: some View {
        let light = isLightAppTheme()
        let chartMetrics = selectedChartBodyMetrics

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("BODY TRACKER", systemImage: "chart.xyaxis.line")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(light ? .appAccentText.opacity(0.78) : .neonGreen)
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

                if let payload = weightSharePayload() {
                    Button {
                        livePayload = payload
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(selectedBodyChartMetric.color)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.appSurface))
                            .overlay(Circle().stroke(selectedBodyChartMetric.color.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
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
                aiWeightAnalysisCard
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
                        .tint(light ? selectedBodyChartMetric.color : .neonGreen)

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
                .stroke(light ? Color.appBorder.opacity(0.75) : Color.neonGreen.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: light ? Color.black.opacity(0.04) : Color.neonGreen.opacity(0.10), radius: 22, x: 0, y: 10)
    }

    var emptyWeightState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start with one check-in.")
                .font(.headline)
                .fontWeight(.heavy)
                .foregroundColor(.appText)

            Text("Type your weight, import Apple Health, upload a smart-scale screenshot, or photograph the scale. ShapeForge will build the trend and body-composition story here.")
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

    // MARK: - Composition Grid

    var bodyCompositionGrid: some View {
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

    var weightRangePicker: some View {
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

    var weightInsightText: some View {
        Text(weightInsight)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.appMuted)
            .lineSpacing(3)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.appSurface))
    }

    var weightInsight: String {
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

    // MARK: - AI Weight Analysis

    var aiWeightAnalysisCard: some View {
        let isPro = SubscriptionManager.shared.isPro
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.fitPurple)
                Text("AI WEIGHT ANALYSIS")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .tracking(0.8)
                Spacer()
                if !isPro {
                    Text("PRO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.neonGreen))
                }
            }

            if isPro {
                if aiWeightLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(.fitPurple)
                        Text("Analyzing trends...")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                } else if let aiWeightInsight {
                    Text(aiWeightInsight)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else if aiWeightError != nil {
                    Button {
                        Task { await loadAIWeightInsight() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry analysis")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.fitPurple)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await loadAIWeightInsight() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text("Analyze my weight trend")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.fitPurple)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ZStack {
                    Text("Your weight has been trending down by 0.3 kg over the past 30 days, consistent with your caloric deficit. Protein adherence is strong.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appText)
                        .lineSpacing(3)
                        .blur(radius: 5)

                    Button {
                        isShowingPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Unlock AI Analysis")
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.neonGreen))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isPro ? Color.fitPurple.opacity(0.18) : Color.appBorder, lineWidth: 1)
                )
        )
    }

    func loadAIWeightInsight() async {
        guard !aiWeightLoading else { return }
        aiWeightLoading = true
        aiWeightError = nil

        let rangeMetrics = cachedRangeMetrics.isEmpty ? Array(bodyMetrics.prefix(30)) : cachedRangeMetrics
        let weightData = rangeMetrics
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }
            .map { (DateFormatter.yyyyMMdd.string(from: $0.date), $0.weightKg) }

        guard !weightData.isEmpty else {
            aiWeightLoading = false
            aiWeightError = "No weight data in this range."
            return
        }

        let (result, error) = await GeminiService.shared.analyzeWeightTrendAsync(
            weightEntries: weightData,
            targetCalories: Int(selectedCalories),
            targetProtein: Int(selectedProtein),
            userName: AuthService.shared.displayName
        )
        aiWeightLoading = false
        if let result {
            aiWeightInsight = result
        } else {
            aiWeightError = error ?? "Analysis failed."
        }
    }

    // MARK: - History

    var bodyMetricHistory: some View {
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

    var bodyMetricHistorySheet: some View {
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

    // MARK: - Manual Weight Sheet

    var manualWeightSheet: some View {
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

    // MARK: - Scanned Date Confirmation

    var scannedDateConfirmationSheet: some View {
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

    // MARK: - Chart Selection Helpers

    func noteBodyChartSelection() {
        lastBodyChartSelectionAt = Date()
    }

    func clearBodyChartSelection() {
        withAnimation(.easeOut(duration: 0.12)) {
            selectedBodyChartPointDate = nil
            isInteractingWithBodyChart = false
        }
    }

    func clearBodyChartSelectionIfExternalTap() {
        guard selectedBodyChartPointDate != nil, !isInteractingWithBodyChart else {
            return
        }

        guard Date().timeIntervalSince(lastBodyChartSelectionAt) > 0.22 else {
            return
        }

        clearBodyChartSelection()
    }

    // MARK: - Body Metric UI Components

    func trendPill(_ delta: Double) -> some View {
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

    func bodyMetricActionButton(title: String, systemName: String, color: Color, action: @escaping () -> Void) -> some View {
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

    func appleHealthImportButton(action: @escaping () -> Void) -> some View {
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

    func bodyMetricMiniCard(title: String, value: String, metric: BodyChartMetric) -> some View {
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

    func bodyMetricReadoutCard(title: String, value: String, color: Color) -> some View {
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

    func bodyMetricHistoryRow(_ entry: BodyMetricEntry) -> some View {
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

    func bodyInputField(title: String, value: Binding<String>, unit: String, required: Bool) -> some View {
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

    // MARK: - Body Metric CRUD

    func prepareManualWeightSheet() {
        manualBodyMetricDate = Date()
        manualWeightText = latestBodyMetric.map { String(format: "%.1f", $0.weightKg) } ?? String(format: "%.1f", weight)
        manualBodyFatText = latestBodyMetric?.bodyFatPercent.map { String(format: "%.1f", $0) } ?? ""
        manualMuscleText = latestBodyMetric?.musclePercent.map { String(format: "%.1f", $0) } ?? ""
        manualWaterText = latestBodyMetric?.waterPercent.map { String(format: "%.1f", $0) } ?? ""
    }

    func saveManualBodyMetric() {
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

    func analyzeBodyImage(_ image: UIImage) {
        guard AIUsageLimiter.canScan else { isShowingPaywall = true; selectedBodyImage = nil; return }
        AIUsageLimiter.recordScan()
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

    func savePendingScannedBodyMetric() {
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

    func importHealthBodyMetrics() {
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

    func upsertHealthBodyMetric(_ snapshot: HealthBodyMetricSnapshot) {
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

    func addBodyMetric(
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
    func mergeIntoDailyBestIfNeeded(_ candidate: BodyMetricEntry) -> Bool {
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

    func updateBodyMetric(_ entry: BodyMetricEntry, with candidate: BodyMetricEntry) {
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

    func deleteBodyMetric(_ entry: BodyMetricEntry) {
        let deletedID = entry.id
        modelContext.delete(entry)

        if latestBodyMetric?.id == deletedID {
            if let nextLatest = bodyMetrics.first(where: { $0.id != deletedID }) {
                weight = nextLatest.weightKg
            }
        }
    }

    // MARK: - Sharing

    func weightSharePayload() -> FitMaksSharePayload? {
        let points = selectedChartBodyMetrics.compactMap { entry -> FitMaksShareWeightPoint? in
            guard let value = selectedBodyChartMetric.value(from: entry) else {
                return nil
            }

            return FitMaksShareWeightPoint(
                label: entry.date.formatted(.dateTime.day().month(.abbreviated)),
                value: value
            )
        }

        guard let first = points.first, let last = points.last else {
            return nil
        }

        return .weight(
            FitMaksShareWeightSnapshot(
                title: "My body",
                subtitle: selectedWeightRange.title,
                accentColor: selectedBodyChartMetric.color,
                leadingValue: bodyChartMetricShareValue(first.value),
                trailingValue: bodyChartMetricShareValue(last.value),
                weightValue: nil,
                fatValue: nil,
                muscleValue: nil,
                xAxisLabels: shareXAxisLabels(from: points),
                points: points
            )
        )
    }

    func profilePostOptions() -> [FitMaksPostOption] {
        WeightChartRange.allCases.flatMap { range in
            BodyChartMetric.allCases.compactMap { metric in
                let periodStart = Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: Date()) ?? Date()
                let entries = bodyMetrics
                    .filter { $0.date >= periodStart }
                    .compactMap { entry -> FitMaksShareWeightPoint? in
                        guard let value = metric.value(from: entry) else { return nil }
                        return FitMaksShareWeightPoint(
                            label: entry.date.formatted(.dateTime.day().month(.abbreviated)),
                            value: value
                        )
                    }

                guard let first = entries.first, let last = entries.last else { return nil }
                let payload = FitMaksSharePayload.weight(
                    FitMaksShareWeightSnapshot(
                        title: "My body",
                        subtitle: "\(metric.title) · \(range.title)",
                        accentColor: metric.color,
                        leadingValue: shareValue(first.value, for: metric),
                        trailingValue: shareValue(last.value, for: metric),
                        weightValue: nil,
                        fatValue: nil,
                        muscleValue: nil,
                        xAxisLabels: shareXAxisLabels(from: entries),
                        points: entries
                    )
                )

                return FitMaksPostOption(
                    id: payload.id,
                    title: "\(metric.title) · \(range.title)",
                    payload: payload
                )
            }
        }
    }

    func selectedChartEntries(for metric: BodyChartMetric) -> [BodyMetricEntry] {
        selectedChartBodyMetrics.filter { metric.value(from: $0) != nil }
    }

    func shareTitle(for metric: BodyChartMetric) -> String {
        switch metric {
        case .weight:
            return "My body"
        case .fat:
            return "My body"
        case .muscle:
            return "My body"
        }
    }

    func shareValue(_ value: Double, for metric: BodyChartMetric) -> String {
        switch metric {
        case .weight:
            return "\(String(format: "%.1f", value)) kg"
        case .fat, .muscle:
            return "\(String(format: "%.1f", value))%"
        }
    }

    var bodyChartMetricShareTitle: String {
        switch selectedBodyChartMetric {
        case .weight:
            return "My body"
        case .fat:
            return "My body"
        case .muscle:
            return "My body"
        }
    }

    func mergedPostOptions() -> [FitMaksPostOption] {
        let local = profilePostOptions()
        guard !postOptions.isEmpty else { return local }

        let withoutGlobalBody = postOptions.filter { $0.payload.categoryKey != "weight" }
        return withoutGlobalBody + local
    }

    func shareXAxisLabels(from points: [FitMaksShareWeightPoint]) -> [String] {
        guard !points.isEmpty else { return [] }
        if points.count == 1 { return [points[0].label] }

        let first = points.first?.label
        let middle = points[points.count / 2].label
        let last = points.last?.label

        return [first, middle, last]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, label in
                if result.last != label {
                    result.append(label)
                }
            }
    }

    func bodyChartMetricShareValue(_ value: Double) -> String {
        switch selectedBodyChartMetric {
        case .weight:
            return "\(String(format: "%.1f", value)) kg"
        case .fat, .muscle:
            return "\(String(format: "%.1f", value))%"
        }
    }

    // MARK: - Helpers

    func dateFromAIString(_ value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return DateFormatter.yyyyMMdd.date(from: value)
    }

    func percentText(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }

        return "\(String(format: "%.1f", value))%"
    }

    func number(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalized)
    }
}
