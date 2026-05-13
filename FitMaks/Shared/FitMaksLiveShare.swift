import SwiftUI
import PhotosUI
import UIKit

struct FitMaksShareMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    let systemImage: String
}

struct FitMaksShareTodaySnapshot: Identifiable {
    let id = UUID()
    let dateLabel: String
    let modeLabel: String
    let modeEmoji: String
    let modeSymbolName: String
    let headline: String
    let subheadline: String
    let isPerfectDay: Bool
    let metrics: [FitMaksShareMetric]
}

struct FitMaksShareStreakSnapshot: Identifiable {
    let id = UUID()
    let current: Int
    let target: Int
    let best30: Int
    let perfect30: Int
}

struct FitMaksShareStreakBoardRow: Identifiable {
    let id = UUID()
    let dayName: String
    let dayNumber: String
    let modeEmoji: String
    let calorieWin: Bool
    let proteinWin: Bool
    let stepWin: Bool
    let isPerfect: Bool
    let calorieTitle: String
    let calorieValue: String
    let calorieColor: Color
    let proteinValue: String
    let stepsValue: String
    let stepsColor: Color
}

struct FitMaksShareStreakBoardSnapshot: Identifiable {
    let id = UUID()
    let rows: [FitMaksShareStreakBoardRow]
}

struct FitMaksShareAchievementSnapshot: Identifiable {
    let id = UUID()
    let title: String
    let familyLabel: String
    let subtitle: String
    let detail: String
    let goalText: String
    let progressText: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let progress: Double
    let hasStarted: Bool
}

struct FitMaksShareWeightPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct FitMaksShareWeightSnapshot: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let accentColor: Color
    let leadingValue: String
    let trailingValue: String
    let weightValue: String?
    let fatValue: String?
    let muscleValue: String?
    let xAxisLabels: [String]
    let points: [FitMaksShareWeightPoint]
}

struct FitMaksShareFoodSnapshot: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let caloriesText: String
    let proteinText: String
    let breakdownLines: [String]
    let image: UIImage?
}

struct FitMaksShareWeeklySnapshot: Identifiable {
    let id = UUID()
    let dateRange: String
    let score: Int
    let scoreLabel: String
    let perfectDays: Int
    let avgCalories: String
    let avgProtein: String
    let avgCarbs: String
    let avgFat: String
    let totalSteps: String
    let dayResults: [FitMaksShareWeeklyDay]
    let scoreColor: Color
}

struct FitMaksShareWeeklyDay: Identifiable {
    let id = UUID()
    let label: String
    let dayNumber: String
    let modeEmoji: String
    let modeLabel: String
    let isPerfect: Bool
    let calorieWin: Bool
    let proteinWin: Bool
    let stepWin: Bool
}

struct FitMaksShareWorkoutSnapshot: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let caloriesText: String
    let stepsText: String?
    let durationText: String?
    let tonnageText: String?
    let systemImage: String
    let accentColor: Color
    let image: UIImage?
}

struct FitMaksPostOption: Identifiable {
    let id: UUID
    let title: String
    let payload: FitMaksSharePayload
}

enum FitMaksSharePayload: Identifiable {
    case today(FitMaksShareTodaySnapshot)
    case streak(FitMaksShareStreakSnapshot)
    case streakBoard(FitMaksShareStreakBoardSnapshot)
    case achievement(FitMaksShareAchievementSnapshot)
    case weight(FitMaksShareWeightSnapshot)
    case food(FitMaksShareFoodSnapshot)
    case workout(FitMaksShareWorkoutSnapshot)
    case weeklyReport(FitMaksShareWeeklySnapshot)

    var id: UUID {
        switch self {
        case .today(let snapshot): return snapshot.id
        case .streak(let snapshot): return snapshot.id
        case .streakBoard(let snapshot): return snapshot.id
        case .achievement(let snapshot): return snapshot.id
        case .weight(let snapshot): return snapshot.id
        case .food(let snapshot): return snapshot.id
        case .workout(let snapshot): return snapshot.id
        case .weeklyReport(let snapshot): return snapshot.id
        }
    }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .streak:
            return "7-Day Streak"
        case .streakBoard:
            return "Streak Board"
        case .achievement:
            return "Achievement"
        case .weight:
            return "My body"
        case .food:
            return "Food Highlight"
        case .workout:
            return "Workout Highlight"
        case .weeklyReport:
            return "Weekly Report"
        }
    }

    var accentColor: Color {
        switch self {
        case .today:
            return .neonGreen
        case .streak:
            return .fitOrange
        case .streakBoard:
            return .fitOrange
        case .achievement(let snapshot):
            return snapshot.color
        case .weight(let snapshot):
            return snapshot.accentColor
        case .food:
            return .neonGreen
        case .workout:
            return .neonCyan
        case .weeklyReport(let snapshot):
            return snapshot.scoreColor
        }
    }

    var categoryKey: String {
        switch self {
        case .today:
            return "today"
        case .streak:
            return "streak"
        case .streakBoard:
            return "streak"
        case .achievement:
            return "achievement"
        case .weight:
            return "weight"
        case .food:
            return "food"
        case .workout:
            return "workout"
        case .weeklyReport:
            return "weeklyReport"
        }
    }

    var categoryTitle: String {
        switch self {
        case .today:
            return "Today"
        case .streak:
            return "Streak"
        case .streakBoard:
            return "Streak"
        case .achievement:
            return "Achievements"
        case .weight:
            return "My body"
        case .food:
            return "Food"
        case .workout:
            return "Workout"
        case .weeklyReport:
            return "Weekly"
        }
    }
}

private enum FitMaksLiveBackgroundMode: String, CaseIterable, Identifiable {
    case clean
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            return "Clean"
        case .photo:
            return "Photo"
        }
    }
}

struct FitMaksLiveView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var payload: FitMaksSharePayload

    @State private var backgroundMode: FitMaksLiveBackgroundMode = .clean
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var isShowingCamera = false
    @State private var cameraImage: UIImage?
    @State private var backgroundOffset = CGSize.zero
    @State private var backgroundDragOffset = CGSize.zero
    @State private var backgroundZoom: CGFloat = 1
    @State private var backgroundZoomDelta: CGFloat = 1
    @State private var contentOffsetY: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var saveConfirmationText: String?
    @State private var selectedCategoryKey: String?

    private let canvasSize = CGSize(width: 1080, height: 1920)
    private let options: [FitMaksPostOption]

    init(payload: FitMaksSharePayload, options: [FitMaksPostOption] = []) {
        _payload = State(initialValue: payload)
        self.options = options
    }

    var body: some View {
        let light = isLightAppTheme()

        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackgroundStart, Color.appBackgroundMid, Color.appBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        liveControlChip(
                            title: "Clean",
                            isSelected: backgroundMode == .clean
                        ) {
                            backgroundMode = .clean
                        }

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            liveChipLabel(
                                title: "+ Library",
                                isSelected: backgroundMode == .photo && backgroundImage != nil
                            )
                        }

                        liveControlChip(title: "+ Camera", isSelected: false) {
                            isShowingCamera = true
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    GeometryReader { proxy in
                        let scale = proxy.size.width / 1080
                        let dragRegionWidth = proxy.size.width * 0.86
                        let dragRegionHeight = proxy.size.height * contentDragRegionHeightRatio
                        let dragRegionCenterY = proxy.size.height - ((66 * scale) + (dragRegionHeight / 2)) + ((contentOffsetY + dragOffsetY) * scale)
                        let dragRegionFrame = CGRect(
                            x: (proxy.size.width - dragRegionWidth) / 2,
                            y: dragRegionCenterY - dragRegionHeight / 2,
                            width: dragRegionWidth,
                            height: dragRegionHeight
                        )
                        ZStack {
                            FitMaksLiveCanvas(
                                payload: payload,
                                backgroundImage: displayedBackgroundImage,
                                backgroundOffset: CGSize(
                                    width: (backgroundOffset.width + backgroundDragOffset.width) / scale,
                                    height: (backgroundOffset.height + backgroundDragOffset.height) / scale
                                ),
                                backgroundScale: backgroundZoom * backgroundZoomDelta,
                                contentOffsetY: contentOffsetY + dragOffsetY
                            )
                            .frame(width: 1080, height: 1920)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: proxy.size.width, height: proxy.size.width * (16.0 / 9.0), alignment: .topLeading)
                            .contentShape(Rectangle())

                            if displayedBackgroundImage == nil {
                                PhotosPicker(
                                    selection: $selectedPhotoItem,
                                    matching: .images
                                ) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 44, weight: .black))
                                            .foregroundColor(payload.accentColor)

                                        Text("Add photo")
                                            .font(.system(size: 18, weight: .black))
                                            .foregroundColor(light ? .appText : .white)

                                        Text("Pick a background and make it story-ready.")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(light ? .appMuted : .white.opacity(0.74))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 26)
                                            .fill(light ? Color.appElevated.opacity(0.96) : Color.black.opacity(0.34))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 26)
                                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 7]))
                                                    .foregroundColor(payload.accentColor.opacity(0.5))
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .overlay {
                            FitMaksPostGestureCaptureView(
                                contentFrame: dragRegionFrame,
                                enableBackgroundGestures: displayedBackgroundImage != nil,
                                onContentDragChanged: { translationY in
                                    dragOffsetY = translationY / scale
                                },
                                onContentDragEnded: { translationY in
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                        contentOffsetY += translationY / scale
                                        contentOffsetY = max(-1450, min(20, contentOffsetY))
                                        dragOffsetY = 0
                                    }
                                },
                                onBackgroundPanChanged: { translation in
                                    backgroundDragOffset = translation
                                },
                                onBackgroundPanEnded: { translation in
                                    let proposed = CGSize(
                                        width: backgroundOffset.width + translation.width,
                                        height: backgroundOffset.height + translation.height
                                    )
                                    backgroundOffset = clampedBackgroundOffset(
                                        proposed,
                                        image: displayedBackgroundImage,
                                        previewScale: scale,
                                        zoom: backgroundZoom * backgroundZoomDelta
                                    )
                                    backgroundDragOffset = .zero
                                },
                                onBackgroundZoomChanged: { value in
                                    backgroundZoomDelta = value
                                },
                                onBackgroundZoomEnded: { value in
                                    let nextZoom = min(max(backgroundZoom * value, 1), 2.4)
                                    let proposedOffset = CGSize(
                                        width: backgroundOffset.width + backgroundDragOffset.width,
                                        height: backgroundOffset.height + backgroundDragOffset.height
                                    )
                                    backgroundZoom = nextZoom
                                    backgroundZoomDelta = 1
                                    backgroundOffset = clampedBackgroundOffset(
                                        proposedOffset,
                                        image: displayedBackgroundImage,
                                        previewScale: scale,
                                        zoom: nextZoom
                                    )
                                    backgroundDragOffset = .zero
                                }
                            )
                        }
                    }
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(light ? Color.appBorder.opacity(0.72) : Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: payload.accentColor.opacity(0.22), radius: 26, x: 0, y: 14)
                    .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        if !pickerCategoryKeys.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(pickerCategoryKeys, id: \.self) { key in
                                        let isSelected = activeCategoryKey == key
                                        let accent = pickerAccentColor(for: key)
                                        Button {
                                            if let firstOption = optionsForCategory(key).first {
                                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                                    selectedCategoryKey = key
                                                    payload = firstOption.payload
                                                }
                                            }
                                        } label: {
                                            Text(categoryTitle(for: key))
                                                .font(.system(size: 13, weight: .heavy))
                                                .foregroundColor(isSelected ? .appAccentText : .appText)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(Capsule().fill(isSelected ? accent : Color.appElevated))
                                                .overlay(Capsule().stroke(isSelected ? accent.opacity(0.22) : Color.appBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if activeCategoryKey == "weight" {
                            VStack(alignment: .leading, spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(bodyMetricTitles, id: \.self) { metricTitle in
                                            let isSelected = selectedBodyMetricTitle == metricTitle
                                            Button {
                                                selectBodyOption(metricTitle: metricTitle, rangeTitle: selectedBodyRangeTitle)
                                            } label: {
                                                Text(metricTitle)
                                                    .font(.system(size: 13, weight: .heavy))
                                                    .foregroundColor(isSelected ? .appAccentText : .appText)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 10)
                                                    .background(Capsule().fill(isSelected ? payload.accentColor : Color.appElevated))
                                                    .overlay(Capsule().stroke(isSelected ? payload.accentColor.opacity(0.22) : Color.appBorder, lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(bodyRangeTitles, id: \.self) { rangeTitle in
                                            let isSelected = selectedBodyRangeTitle == rangeTitle
                                            Button {
                                                selectBodyOption(metricTitle: selectedBodyMetricTitle, rangeTitle: rangeTitle)
                                            } label: {
                                                Text(rangeTitle)
                                                    .font(.system(size: 13, weight: .heavy))
                                                    .foregroundColor(isSelected ? .appAccentText : .appText)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 10)
                                                    .background(Capsule().fill(isSelected ? payload.accentColor : Color.appElevated))
                                                    .overlay(Capsule().stroke(isSelected ? payload.accentColor.opacity(0.22) : Color.appBorder, lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            HStack(spacing: 8) {
                                if let activeCategoryKey,
                                   optionsForCategory(activeCategoryKey).count > 1 {
                                    if activeCategoryKey == "streak" {
                                        HStack(spacing: 6) {
                                            ForEach(optionsForCategory(activeCategoryKey)) { option in
                                                let isSelected = option.payload.id == payload.id
                                                Button {
                                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                                        payload = option.payload
                                                    }
                                                } label: {
                                                    Text(option.title)
                                                        .font(.system(size: 13, weight: .heavy))
                                                        .foregroundColor(isSelected ? .appAccentText : .appText)
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 10)
                                                        .background(Capsule().fill(isSelected ? payload.accentColor : Color.appElevated))
                                                        .overlay(Capsule().stroke(isSelected ? payload.accentColor.opacity(0.22) : Color.appBorder, lineWidth: 1))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    } else {
                                        Menu {
                                            ForEach(optionsForCategory(activeCategoryKey)) { option in
                                                Button(option.title) {
                                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                                        payload = option.payload
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                                    .font(.system(size: 13, weight: .black))

                                                Text(activeSelectionTitle)
                                                    .font(.system(size: 13, weight: .heavy))
                                                    .lineLimit(1)

                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 10, weight: .black))
                                            }
                                            .foregroundColor(.appText)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Capsule().fill(Color.appElevated))
                                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if let saveConfirmationText {
                        Text(saveConfirmationText)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.appAccentText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(payload.accentColor))
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("FitMaks Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.appMuted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveImage()
                    } label: {
                        Text("Save")
                            .fontWeight(.black)
                    }
                    .foregroundColor(payload.accentColor)
                }
            }
        }
        .preferredColorScheme(AppTheme.current.palette.preferredScheme)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        backgroundImage = image
                        backgroundOffset = .zero
                        backgroundDragOffset = .zero
                        backgroundZoom = 1
                        backgroundZoomDelta = 1
                        backgroundMode = .photo
                    }
                }
            }
        }
        .onChange(of: cameraImage) { _, image in
            if let image {
                backgroundImage = image
                backgroundOffset = .zero
                backgroundDragOffset = .zero
                backgroundZoom = 1
                backgroundZoomDelta = 1
                backgroundMode = .photo
            }
        }
        .onChange(of: payload.id) { _, _ in
            selectedCategoryKey = payload.categoryKey
        }
        .onAppear {
            selectedCategoryKey = payload.categoryKey
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            ImagePicker(selectedImage: $cameraImage, sourceType: .camera)
        }
    }

    private var displayedBackgroundImage: UIImage? {
        backgroundMode == .photo ? backgroundImage : nil
    }

    private var pickerOptions: [FitMaksPostOption] {
        var combined = options
        if !combined.contains(where: { optionIdentity($0) == optionIdentity(for: payload, title: $0.title) }) {
            combined.insert(FitMaksPostOption(id: payload.id, title: payload.title, payload: payload), at: 0)
        }
        var seen = Set<String>()
        return combined.filter { option in
            let key = optionIdentity(option)
            return seen.insert(key).inserted
        }
    }

    private var pickerCategoryKeys: [String] {
        var seen = Set<String>()
        return pickerOptions.compactMap { option in
            let key = option.payload.categoryKey
            if seen.insert(key).inserted {
                return key
            }
            return nil
        }
    }

    private var activeCategoryKey: String? {
        selectedCategoryKey ?? payload.categoryKey
    }

    private var activeSelectionTitle: String {
        optionsForCategory(activeCategoryKey ?? payload.categoryKey)
            .first(where: { $0.payload.id == payload.id })?.title ?? payload.title
    }

    private var bodyMetricTitles: [String] {
        ["Weight", "Fat", "Muscle"]
    }

    private var bodyRangeTitles: [String] {
        WeightChartRange.allCases.map(\.title)
    }

    private var selectedBodyMetricTitle: String {
        bodyTitleParts(from: activeSelectionTitle).metric
    }

    private var selectedBodyRangeTitle: String {
        bodyTitleParts(from: activeSelectionTitle).range
    }

    private func optionsForCategory(_ key: String) -> [FitMaksPostOption] {
        pickerOptions.filter { $0.payload.categoryKey == key }
    }

    private func categoryTitle(for key: String) -> String {
        pickerOptions.first(where: { $0.payload.categoryKey == key })?.payload.categoryTitle ?? key.capitalized
    }

    private func pickerAccentColor(for key: String) -> Color {
        pickerOptions.first(where: { $0.payload.categoryKey == key })?.payload.accentColor ?? .neonGreen
    }

    private func optionIdentity(_ option: FitMaksPostOption) -> String {
        optionIdentity(for: option.payload, title: option.title)
    }

    private func optionIdentity(for payload: FitMaksSharePayload, title: String) -> String {
        "\(payload.categoryKey)|\(title)"
    }

    private func bodyTitleParts(from title: String) -> (metric: String, range: String) {
        let parts = title
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let metric = parts.first.flatMap { bodyMetricTitles.contains($0) ? $0 : nil } ?? "Weight"
        let range = parts.dropFirst().first.flatMap { bodyRangeTitles.contains($0) ? $0 : nil } ?? "30D"
        return (metric, range)
    }

    private func selectBodyOption(metricTitle: String, rangeTitle: String) {
        guard let option = optionsForCategory("weight").first(where: {
            let parts = bodyTitleParts(from: $0.title)
            return parts.metric == metricTitle && parts.range == rangeTitle
        }) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            payload = option.payload
            selectedCategoryKey = "weight"
        }
    }

    private func liveControlChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(isSelected ? .appAccentText : .appText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(isSelected ? payload.accentColor : Color.appElevated))
                .overlay(Capsule().stroke(isSelected ? payload.accentColor.opacity(0.2) : Color.appBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func liveChipLabel(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(isSelected ? .appAccentText : .appText)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Capsule().fill(isSelected ? payload.accentColor : Color.appElevated))
            .overlay(Capsule().stroke(isSelected ? payload.accentColor.opacity(0.2) : Color.appBorder, lineWidth: 1))
    }

    private var contentDragRegionHeightRatio: CGFloat {
        switch payload {
        case .today, .weight, .achievement, .food, .workout:
            return 0.26
        case .streak, .weeklyReport:
            return 0.24
        case .streakBoard:
            return 0.38
        }
    }

    private func clampedBackgroundOffset(
        _ offset: CGSize,
        image: UIImage?,
        previewScale: CGFloat,
        zoom: CGFloat
    ) -> CGSize {
        guard let image else { return .zero }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let fillScale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let baseWidth = imageSize.width * fillScale
        let baseHeight = imageSize.height * fillScale
        let scaledWidth = baseWidth * zoom
        let scaledHeight = baseHeight * zoom

        let maxXCanvas = max(0, (scaledWidth - canvasSize.width) / 2)
        let maxYCanvas = max(0, (scaledHeight - canvasSize.height) / 2)
        let maxXPreview = maxXCanvas * previewScale
        let maxYPreview = maxYCanvas * previewScale

        return CGSize(
            width: min(max(offset.width, -maxXPreview), maxXPreview),
            height: min(max(offset.height, -maxYPreview), maxYPreview)
        )
    }

    @MainActor
    private func saveImage() {
        let screenScale = (UIScreen.main.bounds.width - 32) / canvasSize.width
        let canvasOffset = contentOffsetY
        let canvasBackgroundOffset = CGSize(
            width: backgroundOffset.width / screenScale,
            height: backgroundOffset.height / screenScale
        )

        let renderer: ImageRenderer<AnyView>
        if displayedBackgroundImage == nil {
            let overlayCard = AnyView(
                FitMaksLiveExportCard(payload: payload)
                    .environment(\.colorScheme, .dark)
            )
            renderer = ImageRenderer(content: overlayCard)
            renderer.scale = 1
            renderer.proposedSize = .unspecified
            renderer.isOpaque = false
        } else {
            let rendered = AnyView(
                FitMaksLiveCanvas(
                    payload: payload,
                    backgroundImage: displayedBackgroundImage,
                    backgroundOffset: canvasBackgroundOffset,
                    backgroundScale: backgroundZoom,
                    contentOffsetY: canvasOffset
                )
                .frame(width: canvasSize.width, height: canvasSize.height)
                .environment(\.colorScheme, .dark)
            )
            renderer = ImageRenderer(content: rendered)
            renderer.scale = 1
            renderer.proposedSize = .init(width: canvasSize.width, height: canvasSize.height)
            renderer.isOpaque = true
        }

        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            saveConfirmationText = "Saved"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                saveConfirmationText = nil
            }
        }
    }
}

private struct FitMaksLiveCanvas: View {
    let payload: FitMaksSharePayload
    var backgroundImage: UIImage?
    var backgroundOffset: CGSize = .zero
    var backgroundScale: CGFloat = 1
    var contentOffsetY: CGFloat = 0
    var body: some View {
        let light = isLightAppTheme()

        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()

                payloadCard
                    .padding(.horizontal, 52)
                    .padding(.bottom, 66)
            }
            .offset(y: contentOffsetY)
        }
        .clipped()
        .background(light ? Color.appBackgroundStart : Color.black)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        let light = isLightAppTheme()

        if let backgroundImage {
            Image(uiImage: backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1920)
                .scaleEffect(backgroundScale)
                .offset(backgroundOffset)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            light ? Color.white.opacity(0.04) : Color.black.opacity(0.06),
                            light ? Color.appBackgroundStart.opacity(0.10) : Color.black.opacity(0.14),
                            light ? Color.appBackgroundMid.opacity(0.24) : Color.black.opacity(0.34)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.appBackgroundStart,
                        Color.appBackgroundMid,
                        payload.accentColor.opacity(0.32)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(payload.accentColor.opacity(0.26))
                    .frame(width: 580, height: 580)
                    .blur(radius: 40)
                    .offset(x: 260, y: -280)

                Circle()
                    .fill(light ? Color.appSurface.opacity(0.7) : Color.white.opacity(0.08))
                    .frame(width: 420, height: 420)
                    .blur(radius: 36)
                    .offset(x: -240, y: 340)
            }
        }
    }

    @ViewBuilder
    private var payloadCard: some View {
        let light = isLightAppTheme()

        Group {
            switch payload {
            case .today(let snapshot):
                FitMaksLiveTodayCard(snapshot: snapshot)
            case .streak(let snapshot):
                FitMaksLiveStreakCard(snapshot: snapshot)
            case .streakBoard(let snapshot):
                FitMaksLiveStreakBoardCard(snapshot: snapshot)
            case .achievement(let snapshot):
                FitMaksLiveAchievementCard(snapshot: snapshot)
            case .weight(let snapshot):
                FitMaksLiveWeightCard(snapshot: snapshot)
            case .food(let snapshot):
                FitMaksLiveFoodCard(snapshot: snapshot)
            case .workout(let snapshot):
                FitMaksLiveWorkoutCard(snapshot: snapshot)
            case .weeklyReport(let snapshot):
                FitMaksLiveWeeklyCard(snapshot: snapshot)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("FitMaks App")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(light ? .appMuted : .white.opacity(0.42))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(light ? Color.appSurface.opacity(0.92) : Color.black.opacity(0.18)))
                .padding(16)
        }
    }
}

private struct FitMaksLiveExportCard: View {
    let payload: FitMaksSharePayload

    var body: some View {
        let light = isLightAppTheme()

        Group {
            switch payload {
            case .today(let snapshot):
                FitMaksLiveTodayCard(snapshot: snapshot)
            case .streak(let snapshot):
                FitMaksLiveStreakCard(snapshot: snapshot)
            case .streakBoard(let snapshot):
                FitMaksLiveStreakBoardCard(snapshot: snapshot)
            case .achievement(let snapshot):
                FitMaksLiveAchievementCard(snapshot: snapshot)
            case .weight(let snapshot):
                FitMaksLiveWeightCard(snapshot: snapshot)
            case .food(let snapshot):
                FitMaksLiveFoodCard(snapshot: snapshot)
            case .workout(let snapshot):
                FitMaksLiveWorkoutCard(snapshot: snapshot)
            case .weeklyReport(let snapshot):
                FitMaksLiveWeeklyCard(snapshot: snapshot)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("FitMaks App")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(light ? .appMuted : .white.opacity(0.42))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(light ? Color.appSurface.opacity(0.92) : Color.black.opacity(0.18)))
                .padding(16)
        }
        .padding(24)
        .background(Color.clear)
    }
}

private struct FitMaksLiveTodayCard: View {
    let snapshot: FitMaksShareTodaySnapshot

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        livePosterTag(snapshot.dateLabel.uppercased(), color: .neonGreen)
                        if snapshot.isPerfectDay {
                            livePosterTag("PERFECT DAY", color: .yellow)
                                .shadow(color: Color.yellow.opacity(0.28), radius: 6, x: 0, y: 0)
                        }
                    }

                    Text(snapshot.headline)
                        .font(.system(size: 68, weight: .black))
                        .foregroundColor(light ? .appText : .white)
                        .lineLimit(2)
                }

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    Circle()
                        .fill(light ? Color.appSurface.opacity(0.9) : Color.white.opacity(0.06))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: snapshot.modeSymbolName)
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(light ? .appText : .white)
                        )

                    Text(snapshot.modeLabel)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(light ? .appMuted : .white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .frame(width: 128)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                ForEach(snapshot.metrics) { metric in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(light ? Color.appBorder.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 10)
                                .frame(width: 168, height: 168)

                            Circle()
                                .trim(from: 0, to: CGFloat(min(max(metric.progress, 0), 1)))
                                .stroke(
                                    metric.color.opacity(0.95),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 168, height: 168)
                                .shadow(color: metric.color.opacity(metric.progress >= 1 ? 0.56 : 0.34), radius: metric.progress >= 1 ? 16 : 8)

                            VStack(spacing: 2) {
                                Image(systemName: metric.systemImage)
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundColor(metric.color)

                                Text(metric.value)
                                    .font(.system(size: 44, weight: .black))
                                    .monospacedDigit()
                                    .foregroundColor(light ? .appText : .white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(height: 48)

                                Text(metric.subtitle.isEmpty ? " " : metric.subtitle)
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(light ? .appMuted.opacity(metric.subtitle.isEmpty ? 0 : 1) : .white.opacity(metric.subtitle.isEmpty ? 0 : 0.68))
                                    .multilineTextAlignment(.center)
                                    .frame(height: 22)
                            }
                        }

                        Text(metric.title.uppercased())
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(metric.color)
                            .tracking(1)
                    }
                    .frame(width: 228)
                }
                Spacer(minLength: 0)
            }

        }
        .padding(34)
        .background(liveCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 34)
                .stroke(
                    snapshot.isPerfectDay
                        ? LinearGradient(
                            colors: [Color.yellow.opacity(0.7), Color.orange.opacity(0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: snapshot.isPerfectDay ? 1.2 : 0
                )
        )
        .shadow(
            color: snapshot.isPerfectDay ? Color.yellow.opacity(0.2) : .clear,
            radius: snapshot.isPerfectDay ? 12 : 0,
            x: 0,
            y: 6
        )
    }
}

private struct FitMaksLiveStreakCard: View {
    let snapshot: FitMaksShareStreakSnapshot

    private var progress: Double {
        min(Double(snapshot.current) / Double(max(snapshot.target, 1)), 1)
    }

    private var headline: String {
        switch snapshot.current {
        case 7...:
            return "Weekly flame closed."
        case 4...:
            return "This week is moving."
        case 1...:
            return "The streak is alive."
        default:
            return "One clean day starts it."
        }
    }

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 24) {
            HStack {
                livePosterTag("Weekly report", color: .fitOrange)

                Spacer()

                Text(AppRules.calorieGraceLabel)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(light ? .appMuted : .white.opacity(0.66))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.system(size: 66, weight: .black))
                        .foregroundColor(light ? .appText : .white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text("Current flame \(snapshot.current)/\(snapshot.target), with \(snapshot.perfect30) perfect days in the last 30.")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(light ? .appMuted : .white.opacity(0.74))
                        .lineSpacing(3)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.fitOrange.opacity(light ? 0.30 : 0.44),
                                    Color.red.opacity(light ? 0.20 : 0.28),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 6,
                                endRadius: 92
                            )
                        )
                        .frame(width: 180, height: 180)

                    Circle()
                        .fill(light ? Color.appSurface.opacity(0.98) : Color.white.opacity(0.07))
                        .frame(width: 136, height: 136)
                        .overlay(
                            Circle()
                                .stroke(light ? Color.appBorder.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 1)
                        )

                    Image(systemName: "flame.fill")
                        .font(.system(size: 68, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.18, blue: 0.06),
                                    Color.red.opacity(0.86),
                                    Color.fitOrange.opacity(0.42)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .offset(y: -2)
                        .shadow(color: Color.red.opacity(0.38), radius: 14)

                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(snapshot.current)")
                                .font(.system(size: 56, weight: .black))
                            Text("d")
                                .font(.system(size: 20, weight: .black))
                        }
                        .foregroundColor(light ? .appText : .white)
                        .offset(y: 34)

                        Text("current")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(light ? .appMuted : .white.opacity(0.68))
                            .offset(y: 30)
                    }
                }
                .frame(width: 170, height: 170)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(snapshot.current)/\(snapshot.target) weekly flame")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(light ? .appText : .white)

                    Spacer()

                    Text(progress >= 1 ? "Closed" : "In progress")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(progress >= 1 ? .neonGreen : .fitOrange)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(light ? Color.appSurface.opacity(0.92) : Color.white.opacity(0.12))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.fitOrange, .yellow, .neonGreen],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(20, proxy.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 16)

                HStack(spacing: 8) {
                    ForEach(0..<snapshot.target, id: \.self) { index in
                        Capsule()
                            .fill(index < snapshot.current ? Color.fitOrange : (light ? Color.appSurface.opacity(0.9) : Color.white.opacity(0.08)))
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                            .overlay(
                                Capsule()
                                    .stroke(index < snapshot.current ? Color.fitOrange.opacity(0.24) : (light ? Color.appBorder.opacity(0.75) : Color.clear), lineWidth: 1)
                            )
                    }
                }
            }

            HStack(spacing: 12) {
                streakMetricPill(title: "Current", value: "\(snapshot.current)d", accent: .fitOrange, light: light)
                streakMetricPill(title: "Best 30d", value: "\(snapshot.best30)d", accent: .yellow, light: light)
                streakMetricPill(title: "Perfect days", value: "\(snapshot.perfect30)/30", accent: .neonGreen, light: light)
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }

    private func streakMetricPill(title: String, value: String, accent: Color, light: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(accent)
                .tracking(0.8)

            Text(value)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(light ? .appText : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(light ? Color.appSurface.opacity(0.94) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(light ? Color.appBorder.opacity(0.72) : accent.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct FitMaksLiveAchievementCard: View {
    let snapshot: FitMaksShareAchievementSnapshot
    private var isInProgress: Bool { snapshot.hasStarted && !snapshot.isUnlocked }

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if snapshot.isUnlocked {
                        livePosterTag("Achievement unlocked!", color: snapshot.color)
                    } else {
                        HStack(spacing: 8) {
                            livePosterTag(snapshot.familyLabel, color: snapshot.color)
                            if isInProgress {
                                livePosterTag("In progress", color: .fitOrange)
                            }
                        }
                    }

                    Text(snapshot.title)
                        .font(.system(size: 62, weight: .black))
                        .foregroundColor(light ? .appText : .white)
                        .lineLimit(3)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    snapshot.color.opacity(0.34),
                                    snapshot.color.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 84
                            )
                        )
                        .frame(width: 146, height: 146)

                    Circle()
                        .fill(light ? Color.appSurface.opacity(0.92) : Color.white.opacity(0.09))
                        .frame(width: 118, height: 118)

                    Circle()
                        .stroke(snapshot.color.opacity(0.42), lineWidth: 2)
                        .frame(width: 118, height: 118)

                    Image(systemName: snapshot.icon)
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(snapshot.color)
                }
                .frame(width: 146, height: 146)
            }

            HStack(alignment: .center, spacing: 10) {
                Text(snapshot.subtitle)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(light ? .appMuted : .white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                if isInProgress {
                    Text(snapshot.progressText)
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(light ? .appText : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(snapshot.color.opacity(0.22)))
                }
            }

            if isInProgress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(light ? Color.appSurface.opacity(0.92) : Color.white.opacity(0.12))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [snapshot.color.opacity(0.82), snapshot.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * CGFloat(max(0.02, snapshot.progress)))
                    }
                }
                .frame(height: 14)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Goal: \(snapshot.detail)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(light ? .appMuted : .white.opacity(0.70))
                    .lineSpacing(4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(light ? Color.appSurface.opacity(0.88) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(snapshot.color.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .padding(34)
        .background(liveCardBackground)
    }
}

private struct FitMaksLiveStreakBoardCard: View {
    let snapshot: FitMaksShareStreakBoardSnapshot

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 16) {
            livePosterTag("Streak mode", color: .fitOrange)

            Text("7-Day Streak Board")
                .font(.system(size: 42, weight: .black))
                .foregroundColor(light ? .appText : .white)

            Text("Deficit, protein, and steps across your latest seven days.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(light ? .appMuted : .white.opacity(0.62))

            VStack(spacing: 12) {
                ForEach(snapshot.rows) { row in
                    let rowBackground = row.isPerfect
                        ? (light ? Color.neonGreen.opacity(0.09) : Color.neonGreen.opacity(0.14))
                        : (light ? Color.appSurface.opacity(0.88) : Color.white.opacity(0.05))
                    let rowStroke = row.isPerfect
                        ? (light ? Color.yellow.opacity(0.22) : Color.yellow.opacity(0.34))
                        : (light ? Color.appBorder.opacity(0.7) : Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(row.dayName)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(.gray)

                                Text(row.dayNumber)
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(light ? .appText : .white)
                            }
                            .frame(width: 48)

                            Text(row.modeEmoji)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(light ? Color.appSurface.opacity(0.92) : Color.white.opacity(0.05)))

                            HStack(spacing: 6) {
                                liveBoardChip("C", isOn: row.calorieWin, color: .neonGreen)
                                liveBoardChip("P", isOn: row.proteinWin, color: .neonCyan)
                                liveBoardChip("S", isOn: row.stepWin, color: .yellow)
                            }

                            Spacer(minLength: 6)

                            if row.isPerfect {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                    .font(.headline)
                                    .frame(width: 24)
                                    .shadow(color: .yellow.opacity(0.8), radius: 8)
                            }
                        }

                        HStack(spacing: 7) {
                            liveBoardMetricPill(title: row.calorieTitle, value: row.calorieValue, color: row.calorieColor, isOn: row.calorieWin || row.calorieColor == .red)
                            liveBoardMetricPill(title: "protein", value: row.proteinValue, color: .neonCyan, isOn: row.proteinWin)
                            liveBoardMetricPill(title: "steps", value: row.stepsValue, color: row.stepsColor, isOn: row.stepWin)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(rowBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(rowStroke, lineWidth: 1)
                    )
                }
            }
        }
        .padding(28)
        .background(liveCardBackground)
        .frame(maxWidth: 640, alignment: .leading)
    }
}

private struct FitMaksLiveWeightCard: View {
    let snapshot: FitMaksShareWeightSnapshot

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BODY TRACKER")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(snapshot.accentColor)
                        .tracking(1.2)

                    Text(snapshot.title)
                        .font(.system(size: 64, weight: .black))
                        .foregroundColor(light ? .appText : .white)

                    Text(snapshot.subtitle)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(light ? .appMuted : .white.opacity(0.74))
                }

                Spacer()
            }

            if snapshot.points.count >= 2 {
                FitMaksLiveSparkline(
                    points: snapshot.points.map(\.value),
                    accentColor: snapshot.accentColor,
                    valueFormatter: axisValue
                )
                    .frame(height: 240)

                if !snapshot.xAxisLabels.isEmpty {
                    HStack {
                        ForEach(snapshot.xAxisLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(light ? .appMuted : .white.opacity(0.54))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 74)
                    .padding(.trailing, 18)
                }
            }

            HStack(spacing: 14) {
                liveStatPill(title: "From", value: snapshot.leadingValue, accent: snapshot.accentColor)
                liveStatPill(title: "To", value: snapshot.trailingValue, accent: light ? .appText : .white)
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }

    private var axisValue: (Double) -> String {
        { value in
            if snapshot.leadingValue.lowercased().contains("kg") {
                return "\(String(format: "%.0f", value))"
            } else {
                return "\(String(format: "%.0f", value))%"
            }
        }
    }
}

private struct FitMaksLiveFoodCard: View {
    let snapshot: FitMaksShareFoodSnapshot

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 22) {
            shareImageHeader(image: snapshot.image, fallbackColor: .neonGreen, systemName: "fork.knife")

            Text(snapshot.name)
                .font(.system(size: 58, weight: .black))
                .foregroundColor(light ? .appText : .white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            HStack(spacing: 14) {
                liveStatPill(title: "Calories", value: snapshot.caloriesText, accent: .neonGreen)
                liveStatPill(title: "Protein", value: snapshot.proteinText, accent: .neonCyan)
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }
}

private struct FitMaksLiveWorkoutCard: View {
    let snapshot: FitMaksShareWorkoutSnapshot

    private var isStrengthCard: Bool {
        snapshot.systemImage == "dumbbell.fill"
    }

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                livePosterTag(isStrengthCard ? "Strength" : "Cardio", color: snapshot.accentColor)

                Spacer()

                ZStack {
                    Circle()
                        .fill(snapshot.accentColor.opacity(0.14))
                        .frame(width: 68, height: 68)
                    Image(systemName: snapshot.systemImage)
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(snapshot.accentColor)
                }
            }

            Text(snapshot.name)
                .font(.system(size: 62, weight: .black))
                .foregroundColor(light ? .appText : .white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Text(shortenedWorkoutSubtitle)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(light ? .appMuted : .white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(spacing: 12) {
                ForEach(workoutMetrics, id: \.title) { metric in
                    liveStatPill(title: metric.title, value: metric.value, accent: metric.accent)
                }
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }

    private var shortenedWorkoutSubtitle: String {
        let cleaned = snapshot.subtitle
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= 110 {
            return cleaned
        }

        if let sentenceEnd = cleaned.firstIndex(where: { ".!?".contains($0) }) {
            let sentence = String(cleaned[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count <= 110 {
                return sentence
            }
        }

        let prefix = String(cleaned.prefix(110))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace])
        }
        return prefix
    }

    private var workoutMetrics: [(title: String, value: String, accent: Color)] {
        var metrics: [(String, String, Color)] = [
            ("Burned", snapshot.caloriesText, .fitOrange),
            ("Mode", isStrengthCard ? "Strength" : "Cardio", snapshot.accentColor)
        ]

        if let durationText = snapshot.durationText, !durationText.isEmpty {
            metrics[1] = ("Duration", durationText, .neonCyan)
        }

        if let stepsText = snapshot.stepsText, !stepsText.isEmpty {
            metrics.append(("Steps", stepsText, .neonGreen))
        }

        if let tonnageText = snapshot.tonnageText, !tonnageText.isEmpty {
            metrics.append(("Tonnage", tonnageText, .fitPurple))
        }

        if isStrengthCard {
            return Array(metrics.filter { $0.0 != "Steps" }.prefix(3))
        }

        return Array(metrics.filter { $0.0 != "Tonnage" }.prefix(3))
    }
}

private struct FitMaksLiveSparkline: View {
    let points: [Double]
    let accentColor: Color
    var valueFormatter: ((Double) -> String)? = nil

    var body: some View {
        let light = isLightAppTheme()

        GeometryReader { proxy in
            let normalized = normalizedPoints(in: proxy.size)
            let minValue = points.min() ?? 0
            let maxValue = points.max() ?? 0

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(light ? Color.appSurface.opacity(0.88) : Color.white.opacity(0.04))

                if let valueFormatter, points.count >= 2 {
                    sparklineScale(maxValue: maxValue, minValue: minValue, formatter: valueFormatter)
                }

                Path { path in
                    guard let first = normalized.first else { return }
                    path.move(to: first)
                    for point in normalized.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [accentColor, light ? accentColor.opacity(0.55) : .white.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(normalized.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(index == normalized.count - 1 ? accentColor : (light ? Color.appMuted.opacity(0.5) : Color.white.opacity(0.75)))
                        .frame(width: index == normalized.count - 1 ? 24 : 14, height: index == normalized.count - 1 ? 24 : 14)
                        .position(point)
                }
            }
        }
    }

    private func sparklineScale(maxValue: Double, minValue: Double, formatter: @escaping (Double) -> String) -> some View {
        let light = isLightAppTheme()
        let midValue = (maxValue + minValue) / 2

        return ZStack {
            VStack(spacing: 0) {
                sparklineGuideRow(label: formatter(maxValue))
                Spacer()
                sparklineGuideRow(label: formatter(midValue))
                Spacer()
                sparklineGuideRow(label: formatter(minValue))
            }
            .padding(.vertical, 18)

            VStack(spacing: 0) {
                Rectangle().fill(light ? Color.appBorder.opacity(0.8) : Color.white.opacity(0.08)).frame(height: 1)
                Spacer()
                Rectangle().fill(light ? Color.appBorder.opacity(0.65) : Color.white.opacity(0.06)).frame(height: 1)
                Spacer()
                Rectangle().fill(light ? Color.appBorder.opacity(0.55) : Color.white.opacity(0.05)).frame(height: 1)
            }
            .padding(.vertical, 22)
            .padding(.leading, 74)
            .padding(.trailing, 18)
        }
    }

    private func sparklineGuideRow(label: String) -> some View {
        let light = isLightAppTheme()
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(light ? .appMuted : .white.opacity(0.46))
                .frame(width: 46, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }

        let minValue = points.min() ?? 0
        let maxValue = points.max() ?? 1
        let range = max(maxValue - minValue, 0.1)

        return points.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(max(points.count - 1, 1)) * (size.width - 96) + 74
            let normalizedY = (value - minValue) / range
            let y = size.height - (CGFloat(normalizedY) * (size.height - 40) + 20)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct FitMaksLiveWeeklyCard: View {
    let snapshot: FitMaksShareWeeklySnapshot

    var body: some View {
        let light = isLightAppTheme()

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                livePosterTag("WEEKLY REPORT", color: snapshot.scoreColor)
                livePosterTag(snapshot.dateRange.uppercased(), color: .appMuted)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WEEK SCORE")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(light ? .appMuted : .white.opacity(0.62))
                        .tracking(1)

                    Text("\(snapshot.score)%")
                        .font(.system(size: 78, weight: .black))
                        .foregroundColor(snapshot.scoreColor)

                    Text(snapshot.scoreLabel)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(light ? .appText : .white)

                    Text("\(snapshot.perfectDays)/7 perfect days")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(light ? .appMuted : .white.opacity(0.7))
                }

                Spacer()

                VStack(spacing: 10) {
                    weeklySummaryPill(
                        title: "Perfect",
                        value: "\(snapshot.perfectDays)/7",
                        accent: snapshot.scoreColor,
                        symbol: "sparkles"
                    )

                    weeklySummaryPill(
                        title: "Steps",
                        value: snapshot.totalSteps,
                        accent: .fitOrange,
                        symbol: "figure.walk"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("WEEK AT A GLANCE")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(light ? .appText : .white)
                        .tracking(0.8)

                    Spacer()

                    Text("C / P / S")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(light ? .appMuted : .white.opacity(0.54))
                        .tracking(0.8)
                }

                HStack(spacing: 8) {
                    ForEach(snapshot.dayResults) { day in
                        weeklyDayCard(day, light: light)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(light ? Color.appSurface.opacity(0.9) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(light ? Color.appBorder.opacity(0.72) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            HStack(spacing: 14) {
                liveStatPill(title: "Calories", value: snapshot.avgCalories, accent: .neonGreen)
                liveStatPill(title: "Protein", value: snapshot.avgProtein, accent: .neonCyan)
            }

            HStack(spacing: 14) {
                liveStatPill(title: "Carbs", value: snapshot.avgCarbs, accent: .fitOrange)
                liveStatPill(title: "Fat", value: snapshot.avgFat, accent: .fitPurple)
            }

            liveStatPill(title: "Total Steps", value: snapshot.totalSteps, accent: .fitOrange)
        }
        .padding(34)
        .background(liveCardBackground)
    }

    private func weeklyDayCard(_ day: FitMaksShareWeeklyDay, light: Bool) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 1) {
                Text(day.label)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(light ? .appMuted : .white.opacity(0.56))
                    .tracking(0.6)

                Text(day.dayNumber)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(light ? .appText : .white)
            }

            Text(day.modeEmoji)
                .font(.system(size: 18))

            Text(day.modeLabel.uppercased())
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(light ? .appMuted : .white.opacity(0.46))
                .tracking(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                weeklyCheckChip("C", active: day.calorieWin, color: .neonGreen, light: light)
                weeklyCheckChip("P", active: day.proteinWin, color: .neonCyan, light: light)
                weeklyCheckChip("S", active: day.stepWin, color: .fitOrange, light: light)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(day.isPerfect ? snapshot.scoreColor.opacity(light ? 0.14 : 0.18) : (light ? Color.appElevated.opacity(0.8) : Color.white.opacity(0.03)))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(day.isPerfect ? snapshot.scoreColor.opacity(light ? 0.36 : 0.48) : (light ? Color.appBorder.opacity(0.6) : Color.white.opacity(0.08)), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if day.isPerfect {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(snapshot.scoreColor)
                    .padding(7)
            }
        }
    }

    private func weeklyCheckChip(_ title: String, active: Bool, color: Color, light: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(active ? (light ? .black : .black) : (light ? .appMuted : .white.opacity(0.4)))
            .frame(width: 20, height: 20)
            .background(
                Capsule()
                    .fill(active ? color : (light ? Color.appSurface : Color.white.opacity(0.06)))
            )
            .overlay(
                Capsule()
                    .stroke(active ? color.opacity(light ? 0.28 : 0.08) : (light ? Color.appBorder.opacity(0.5) : Color.white.opacity(0.08)), lineWidth: 1)
            )
    }

    private func weeklySummaryPill(title: String, value: String, accent: Color, symbol: String) -> some View {
        let light = isLightAppTheme()

        return HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(light ? .appMuted : .white.opacity(0.55))
                    .tracking(0.7)

                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(light ? .appText : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 176)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(light ? Color.appSurface.opacity(0.9) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(light ? Color.appBorder.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private var liveCardBackground: some View {
    let light = isLightAppTheme()

    return RoundedRectangle(cornerRadius: 34)
        .fill(light ? Color.appElevated : Color(red: 14/255, green: 14/255, blue: 18/255).opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(light ? Color.appBorder : Color.white.opacity(0.10), lineWidth: 1))
}

private func liveStatPill(title: String, value: String, accent: Color) -> some View {
    let light = isLightAppTheme()

    return VStack(alignment: .leading, spacing: 6) {
        Text(title.uppercased())
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(accent)
            .tracking(1)

        Text(value)
            .font(.system(size: 34, weight: .black))
            .foregroundColor(light ? .appText : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 24).fill(light ? Color.appSurface.opacity(0.92) : Color.white.opacity(0.06)))
    .overlay(
        RoundedRectangle(cornerRadius: 24)
            .stroke(light ? Color.appBorder.opacity(0.65) : Color.clear, lineWidth: 1)
    )
}

private func shareImageHeader(image: UIImage?, fallbackColor: Color, systemName: String) -> some View {
    let light = isLightAppTheme()

    return ZStack {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 28)
                .fill(fallbackColor.opacity(0.18))

            Image(systemName: systemName)
                .font(.system(size: 52, weight: .black))
                .foregroundColor(fallbackColor)
        }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 320)
    .clipShape(RoundedRectangle(cornerRadius: 28))
    .overlay(RoundedRectangle(cornerRadius: 28).stroke(light ? Color.appBorder.opacity(0.72) : Color.white.opacity(0.08), lineWidth: 1))
}

private func livePosterTag(_ text: String, color: Color) -> some View {
    Text(text.uppercased())
        .font(.system(size: 22, weight: .heavy))
        .foregroundColor(color)
        .tracking(1)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
}

private func liveBoardChip(_ text: String, isOn: Bool, color: Color) -> some View {
    let light = isLightAppTheme()

    return Text(text)
        .font(.system(size: 14, weight: .black))
        .foregroundColor(isOn ? .black : (light ? .appMuted : .gray))
        .frame(width: 32, height: 26)
        .background(Capsule().fill(isOn ? color : (light ? Color.appSurface.opacity(0.9) : Color.white.opacity(0.07))))
        .shadow(color: isOn ? color.opacity(0.45) : .clear, radius: 7)
        .overlay(
            Capsule()
                .stroke(light && !isOn ? Color.appBorder.opacity(0.65) : Color.clear, lineWidth: 1)
        )
}

private func liveBoardMetricPill(title: String, value: String, color: Color, isOn: Bool) -> some View {
    let light = isLightAppTheme()

    return VStack(alignment: .leading, spacing: 3) {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(isOn ? color : (light ? .appMuted : .gray))
            .tracking(0.5)

        Text(value)
            .font(.system(size: 18, weight: .black))
            .foregroundColor(light ? .appText : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 14).fill(light ? (isOn ? color.opacity(0.10) : Color.appSurface.opacity(0.92)) : color.opacity(isOn ? 0.16 : 0.08)))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(light ? (isOn ? color.opacity(0.18) : Color.appBorder.opacity(0.65)) : color.opacity(isOn ? 0.26 : 0.08), lineWidth: 1))
}

private struct FitMaksPostGestureCaptureView: UIViewRepresentable {
    var contentFrame: CGRect
    var enableBackgroundGestures: Bool
    var onContentDragChanged: (CGFloat) -> Void
    var onContentDragEnded: (CGFloat) -> Void
    var onBackgroundPanChanged: (CGSize) -> Void
    var onBackgroundPanEnded: (CGSize) -> Void
    var onBackgroundZoomChanged: (CGFloat) -> Void
    var onBackgroundZoomEnded: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onContentDragChanged: onContentDragChanged,
            onContentDragEnded: onContentDragEnded,
            onBackgroundPanChanged: onBackgroundPanChanged,
            onBackgroundPanEnded: onBackgroundPanEnded,
            onBackgroundZoomChanged: onBackgroundZoomChanged,
            onBackgroundZoomEnded: onBackgroundZoomEnded
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = GestureCaptureHostView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.contentFrame = contentFrame
        view.enableBackgroundGestures = enableBackgroundGestures

        let contentPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleContentPan(_:)))
        contentPan.minimumNumberOfTouches = 1
        contentPan.maximumNumberOfTouches = 1
        contentPan.cancelsTouchesInView = false
        contentPan.delaysTouchesBegan = false
        contentPan.delaysTouchesEnded = false
        contentPan.delegate = context.coordinator

        let backgroundPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleBackgroundPan(_:)))
        backgroundPan.minimumNumberOfTouches = 2
        backgroundPan.maximumNumberOfTouches = 2
        backgroundPan.cancelsTouchesInView = false
        backgroundPan.delaysTouchesBegan = false
        backgroundPan.delaysTouchesEnded = false
        backgroundPan.delegate = context.coordinator

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.cancelsTouchesInView = false
        pinch.delegate = context.coordinator

        view.contentPanRecognizer = contentPan
        view.backgroundPanRecognizer = backgroundPan
        view.pinchRecognizer = pinch
        view.addGestureRecognizer(contentPan)
        view.addGestureRecognizer(backgroundPan)
        view.addGestureRecognizer(pinch)
        context.coordinator.hostView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? GestureCaptureHostView else { return }
        view.contentFrame = contentFrame
        view.enableBackgroundGestures = enableBackgroundGestures
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var hostView: GestureCaptureHostView?
        let onContentDragChanged: (CGFloat) -> Void
        let onContentDragEnded: (CGFloat) -> Void
        let onBackgroundPanChanged: (CGSize) -> Void
        let onBackgroundPanEnded: (CGSize) -> Void
        let onBackgroundZoomChanged: (CGFloat) -> Void
        let onBackgroundZoomEnded: (CGFloat) -> Void

        init(
            onContentDragChanged: @escaping (CGFloat) -> Void,
            onContentDragEnded: @escaping (CGFloat) -> Void,
            onBackgroundPanChanged: @escaping (CGSize) -> Void,
            onBackgroundPanEnded: @escaping (CGSize) -> Void,
            onBackgroundZoomChanged: @escaping (CGFloat) -> Void,
            onBackgroundZoomEnded: @escaping (CGFloat) -> Void
        ) {
            self.onContentDragChanged = onContentDragChanged
            self.onContentDragEnded = onContentDragEnded
            self.onBackgroundPanChanged = onBackgroundPanChanged
            self.onBackgroundPanEnded = onBackgroundPanEnded
            self.onBackgroundZoomChanged = onBackgroundZoomChanged
            self.onBackgroundZoomEnded = onBackgroundZoomEnded
        }

        @objc
        func handleContentPan(_ recognizer: UIPanGestureRecognizer) {
            let point = recognizer.translation(in: recognizer.view)
            switch recognizer.state {
            case .changed:
                guard abs(point.y) > abs(point.x) else { return }
                onContentDragChanged(point.y)
            case .ended, .cancelled, .failed:
                guard abs(point.y) > abs(point.x) else { return }
                onContentDragEnded(point.y)
            default:
                break
            }
        }

        @objc
        func handleBackgroundPan(_ recognizer: UIPanGestureRecognizer) {
            let point = recognizer.translation(in: recognizer.view)
            let offset = CGSize(width: point.x, height: point.y)
            switch recognizer.state {
            case .changed:
                onBackgroundPanChanged(offset)
            case .ended, .cancelled, .failed:
                onBackgroundPanEnded(offset)
            default:
                break
            }
        }

        @objc
        func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                onBackgroundZoomChanged(recognizer.scale)
            case .ended, .cancelled, .failed:
                onBackgroundZoomEnded(recognizer.scale)
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = hostView else { return false }
            let backgroundPan = gestureRecognizer === view.backgroundPanRecognizer || otherGestureRecognizer === view.backgroundPanRecognizer
            let pinch = gestureRecognizer === view.pinchRecognizer || otherGestureRecognizer === view.pinchRecognizer
            return backgroundPan && pinch
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = hostView else { return false }
            let location = touch.location(in: view)

            if gestureRecognizer === view.contentPanRecognizer {
                return view.contentFrame.contains(location)
            }

            if gestureRecognizer === view.backgroundPanRecognizer || gestureRecognizer === view.pinchRecognizer {
                return view.enableBackgroundGestures
            }

            return false
        }
    }

    final class GestureCaptureHostView: UIView {
        var contentFrame: CGRect = .zero
        var enableBackgroundGestures = false
        weak var contentPanRecognizer: UIPanGestureRecognizer?
        weak var backgroundPanRecognizer: UIPanGestureRecognizer?
        weak var pinchRecognizer: UIPinchGestureRecognizer?

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if enableBackgroundGestures {
                return true
            }
            return contentFrame.contains(point)
        }
    }
}

private extension FitMaksSharePayload {
    var expectsPhotoBackground: Bool {
        switch self {
        case .today, .food:
            return true
        case .streak, .streakBoard, .achievement, .weight, .workout, .weeklyReport:
            return false
        }
    }
}
