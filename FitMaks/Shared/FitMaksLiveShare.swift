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
    let subtitle: String
    let detail: String
    let progressText: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
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

    var id: UUID {
        switch self {
        case .today(let snapshot): return snapshot.id
        case .streak(let snapshot): return snapshot.id
        case .streakBoard(let snapshot): return snapshot.id
        case .achievement(let snapshot): return snapshot.id
        case .weight(let snapshot): return snapshot.id
        case .food(let snapshot): return snapshot.id
        case .workout(let snapshot): return snapshot.id
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
            return "Weight Trend"
        case .food:
            return "Food Highlight"
        case .workout:
            return "Workout Highlight"
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
            return "Weight"
        case .food:
            return "Food"
        case .workout:
            return "Workout"
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
    @State private var contentOffsetY: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var saveConfirmationText: String?
    @State private var isShowingFoodBreakdown = false
    @State private var selectedCategoryKey: String?

    private let canvasSize = CGSize(width: 1080, height: 1920)
    private let options: [FitMaksPostOption]

    init(payload: FitMaksSharePayload, options: [FitMaksPostOption] = []) {
        _payload = State(initialValue: payload)
        self.options = options
    }

    var body: some View {
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
                        ZStack {
                            FitMaksLiveCanvas(
                                payload: payload,
                                backgroundImage: displayedBackgroundImage,
                                contentOffsetY: (contentOffsetY + dragOffsetY) / scale,
                                isShowingFoodBreakdown: isShowingFoodBreakdown
                            )
                            .frame(width: 1080, height: 1920)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: proxy.size.width, height: proxy.size.width * (16.0 / 9.0), alignment: .topLeading)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffsetY = value.translation.height
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            contentOffsetY += dragOffsetY
                                            contentOffsetY = max(-420, min(10, contentOffsetY))
                                            dragOffsetY = 0
                                        }
                                    }
                            )

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
                                            .foregroundColor(.white)

                                        Text("Pick a background and make it story-ready.")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.74))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 26)
                                            .fill(Color.black.opacity(0.34))
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
                    }
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.08), lineWidth: 1))
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

                        HStack(spacing: 8) {
                            if let activeCategoryKey,
                               optionsForCategory(activeCategoryKey).count > 1 {
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

                            if case .food(let snapshot) = payload, !snapshot.breakdownLines.isEmpty {
                                liveControlChip(
                                    title: isShowingFoodBreakdown ? "Hide breakdown" : "Add breakdown",
                                    isSelected: isShowingFoodBreakdown
                                ) {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                        isShowingFoodBreakdown.toggle()
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
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
                        Label("Save", systemImage: "arrow.down.circle.fill")
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
                        backgroundMode = .photo
                    }
                }
            }
        }
        .onChange(of: cameraImage) { _, image in
            if let image {
                backgroundImage = image
                backgroundMode = .photo
            }
        }
        .onChange(of: payload.id) { _, _ in
            if case .food(let snapshot) = payload {
                isShowingFoodBreakdown = !snapshot.breakdownLines.isEmpty
            } else {
                isShowingFoodBreakdown = false
            }
            selectedCategoryKey = payload.categoryKey
        }
        .onAppear {
            if case .food(let snapshot) = payload {
                isShowingFoodBreakdown = !snapshot.breakdownLines.isEmpty
            }
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
        if !combined.contains(where: { $0.payload.id == payload.id }) {
            combined.insert(FitMaksPostOption(id: payload.id, title: payload.title, payload: payload), at: 0)
        }
        return combined
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

    private func optionsForCategory(_ key: String) -> [FitMaksPostOption] {
        pickerOptions.filter { $0.payload.categoryKey == key }
    }

    private func categoryTitle(for key: String) -> String {
        pickerOptions.first(where: { $0.payload.categoryKey == key })?.payload.categoryTitle ?? key.capitalized
    }

    private func pickerAccentColor(for key: String) -> Color {
        pickerOptions.first(where: { $0.payload.categoryKey == key })?.payload.accentColor ?? .neonGreen
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

    @MainActor
    private func saveImage() {
        let screenScale = (UIScreen.main.bounds.width - 32) / canvasSize.width
        let canvasOffset = contentOffsetY / screenScale

        let renderer: ImageRenderer<AnyView>
        if displayedBackgroundImage == nil {
            let overlayCard = AnyView(
                FitMaksLiveExportCard(payload: payload, isShowingFoodBreakdown: isShowingFoodBreakdown)
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
                    contentOffsetY: canvasOffset,
                    isShowingFoodBreakdown: isShowingFoodBreakdown
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
    var contentOffsetY: CGFloat = 0
    var isShowingFoodBreakdown: Bool = false

    var body: some View {
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
        .background(Color.black)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let backgroundImage {
            Image(uiImage: backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1920)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.06),
                            Color.black.opacity(0.14),
                            Color.black.opacity(0.34)
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
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 420, height: 420)
                    .blur(radius: 36)
                    .offset(x: -240, y: 340)
            }
        }
    }

    @ViewBuilder
    private var payloadCard: some View {
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
                FitMaksLiveFoodCard(snapshot: snapshot, isShowingBreakdown: isShowingFoodBreakdown)
            case .workout(let snapshot):
                FitMaksLiveWorkoutCard(snapshot: snapshot)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("FitMaks App")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.18)))
                .padding(22)
        }
    }
}

private struct FitMaksLiveExportCard: View {
    let payload: FitMaksSharePayload
    let isShowingFoodBreakdown: Bool

    var body: some View {
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
                FitMaksLiveFoodCard(snapshot: snapshot, isShowingBreakdown: isShowingFoodBreakdown)
            case .workout(let snapshot):
                FitMaksLiveWorkoutCard(snapshot: snapshot)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("FitMaks App")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.18)))
                .padding(22)
        }
        .padding(24)
        .background(Color.clear)
    }
}

private struct FitMaksLiveTodayCard: View {
    let snapshot: FitMaksShareTodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    livePosterTag(snapshot.dateLabel.uppercased(), color: .neonGreen)

                    Text(snapshot.headline)
                        .font(.system(size: 68, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(2)

                }

                Spacer(minLength: 20)

                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 138, height: 138)

                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 96, height: 96)

                        Image(systemName: snapshot.modeSymbolName)
                            .font(.system(size: 46, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.18), radius: 10)
                    }

                    Text(snapshot.modeLabel)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white.opacity(0.82))
                }
            }

            HStack(spacing: 18) {
                ForEach(snapshot.metrics) { metric in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 10)
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

                            VStack(spacing: 6) {
                                Image(systemName: metric.systemImage)
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundColor(metric.color)

                                Text(metric.value)
                                    .font(.system(size: 44, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(metric.subtitle)
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(.white.opacity(0.68))
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Text(metric.title.uppercased())
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(metric.color)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 10) {
                livePosterTag("FitMaks Daily Card", color: .white.opacity(0.72))
                Text("Track it. Close it. Post it.")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white.opacity(0.58))
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }
}

private struct FitMaksLiveStreakCard: View {
    let snapshot: FitMaksShareStreakSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("STREAK MODE")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.fitOrange)
                .tracking(1.4)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Protect the streak.")
                        .font(.system(size: 72, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text("Current flame \(snapshot.current)/\(snapshot.target).")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white.opacity(0.74))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(snapshot.current)")
                        .font(.system(size: 120, weight: .black))
                        .foregroundColor(.white)

                    Text("days")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.fitOrange, .neonGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(min(Double(snapshot.current) / Double(max(snapshot.target, 1)), 1)))
                }
            }
            .frame(height: 20)

            HStack(spacing: 14) {
                liveStatPill(title: "Best 30d", value: "\(snapshot.best30)d", accent: .fitOrange)
                liveStatPill(title: "Perfect days", value: "\(snapshot.perfect30)/30", accent: .neonGreen)
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }
}

private struct FitMaksLiveAchievementCard: View {
    let snapshot: FitMaksShareAchievementSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    livePosterTag(snapshot.isUnlocked ? "Achievement unlocked!" : "Side quest", color: snapshot.color)

                    Text(snapshot.title)
                        .font(.system(size: 62, weight: .black))
                        .foregroundColor(.white)
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
                        .fill(Color.white.opacity(0.09))
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

            Text(snapshot.subtitle)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(.white.opacity(0.76))

            if !snapshot.isUnlocked || !snapshot.progressText.lowercased().contains("unlock") {
                Text(snapshot.progressText)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(snapshot.color.opacity(0.22)))
            }

            Text(snapshot.detail)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.70))
                .lineSpacing(4)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.05))
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                livePosterTag("Streak mode", color: .fitOrange)
                Spacer()
                Text("C / P / S")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white.opacity(0.56))
            }

            Text("7-Day Streak Board")
                .font(.system(size: 42, weight: .black))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(snapshot.rows) { row in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(row.dayName)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(.gray)

                                Text(row.dayNumber)
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 48)

                            Text(row.modeEmoji)
                                .font(.title3)
                                .frame(width: 30)

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
                            .fill(row.isPerfect ? Color.neonGreen.opacity(0.13) : Color.white.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(row.isPerfect ? Color.yellow.opacity(0.38) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }
        }
        .padding(28)
        .background(liveCardBackground)
    }
}

private struct FitMaksLiveWeightCard: View {
    let snapshot: FitMaksShareWeightSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BODY TRACKER")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(snapshot.accentColor)
                        .tracking(1.2)

                    Text(snapshot.title)
                        .font(.system(size: 64, weight: .black))
                        .foregroundColor(.white)

                    Text(snapshot.subtitle)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white.opacity(0.74))
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
            }

            HStack(spacing: 14) {
                liveStatPill(title: "From", value: snapshot.leadingValue, accent: snapshot.accentColor)
                liveStatPill(title: "To", value: snapshot.trailingValue, accent: .white)
            }
        }
        .padding(34)
        .background(liveCardBackground)
    }

    private var axisValue: (Double) -> String {
        { value in
            if snapshot.title.lowercased().contains("weight") {
                return "\(String(format: "%.0f", value))"
            } else {
                return "\(String(format: "%.0f", value))%"
            }
        }
    }
}

private struct FitMaksLiveFoodCard: View {
    let snapshot: FitMaksShareFoodSnapshot
    let isShowingBreakdown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            shareImageHeader(image: snapshot.image, fallbackColor: .neonGreen, systemName: "fork.knife")

            Text(snapshot.name)
                .font(.system(size: 58, weight: .black))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(snapshot.subtitle)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(2)

            HStack(spacing: 14) {
                liveStatPill(title: "Calories", value: snapshot.caloriesText, accent: .neonGreen)
                liveStatPill(title: "Protein", value: snapshot.proteinText, accent: .neonCyan)
            }

            if isShowingBreakdown && !snapshot.breakdownLines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Breakdown")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white.opacity(0.74))
                        .tracking(1)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(snapshot.breakdownLines.prefix(5).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.06)))
                }
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
                .foregroundColor(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.6)

            Text(snapshot.subtitle)
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(3)
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

        return metrics
    }
}

private struct FitMaksLiveSparkline: View {
    let points: [Double]
    let accentColor: Color
    var valueFormatter: ((Double) -> String)? = nil

    var body: some View {
        GeometryReader { proxy in
            let normalized = normalizedPoints(in: proxy.size)
            let minValue = points.min() ?? 0
            let maxValue = points.max() ?? 0

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.04))

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
                        colors: [accentColor, .white.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(normalized.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(index == normalized.count - 1 ? accentColor : Color.white.opacity(0.75))
                        .frame(width: index == normalized.count - 1 ? 24 : 14, height: index == normalized.count - 1 ? 24 : 14)
                        .position(point)
                }
            }
        }
    }

    private func sparklineScale(maxValue: Double, minValue: Double, formatter: @escaping (Double) -> String) -> some View {
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
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                Spacer()
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                Spacer()
                Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
            }
            .padding(.vertical, 22)
            .padding(.leading, 74)
            .padding(.trailing, 18)
        }
    }

    private func sparklineGuideRow(label: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white.opacity(0.46))
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

private var liveCardBackground: some View {
    RoundedRectangle(cornerRadius: 34)
        .fill(Color.black.opacity(0.42))
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white.opacity(0.08), lineWidth: 1))
}

private func liveStatPill(title: String, value: String, accent: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title.uppercased())
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(accent)
            .tracking(1)

        Text(value)
            .font(.system(size: 34, weight: .black))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.06)))
}

private func shareImageHeader(image: UIImage?, fallbackColor: Color, systemName: String) -> some View {
    ZStack {
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
    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
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
    Text(text)
        .font(.system(size: 14, weight: .black))
        .foregroundColor(isOn ? .black : .gray)
        .frame(width: 32, height: 26)
        .background(Capsule().fill(isOn ? color : Color.white.opacity(0.07)))
        .shadow(color: isOn ? color.opacity(0.45) : .clear, radius: 7)
}

private func liveBoardMetricPill(title: String, value: String, color: Color, isOn: Bool) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(isOn ? color : .gray)
            .tracking(0.5)

        Text(value)
            .font(.system(size: 18, weight: .black))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(isOn ? 0.16 : 0.08)))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(isOn ? 0.26 : 0.08), lineWidth: 1))
}

private extension FitMaksSharePayload {
    var expectsPhotoBackground: Bool {
        switch self {
        case .today, .food:
            return true
        case .streak, .streakBoard, .achievement, .weight, .workout:
            return false
        }
    }
}
