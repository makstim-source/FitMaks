import SwiftUI

struct MetricStepperCard: View {
    var title: String
    @Binding var value: Double
    var unit: String
    var range: ClosedRange<Double>
    var step: Double
    var decimals: Int
    var accentColor: Color

    private var formattedValue: String {
        decimals == 0
            ? "\(Int(value.rounded()))"
            : String(format: "%.\(decimals)f", value)
    }

    private var progress: Double {
        min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.appMuted)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(formattedValue)
                            .font(.system(size: 31, weight: .black))
                            .foregroundColor(.appText)

                        Text(unit)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appMuted)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    stepButton(systemName: "minus") {
                        value = max(range.lowerBound, value - step)
                    }

                    stepButton(systemName: "plus") {
                        value = min(range.upperBound, value + step)
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appText.opacity(0.08))

                    Capsule()
                        .fill(accentColor)
                        .frame(width: proxy.size.width * CGFloat(progress))
                        .shadow(color: accentColor.opacity(0.45), radius: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.appElevated))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.appAccentText)
                .frame(width: 42, height: 42)
                .background(Circle().fill(accentColor))
                .shadow(color: accentColor.opacity(0.35), radius: 8)
        }
        .buttonRepeatBehavior(.enabled)
    }
}

struct WeightTrendChart: View {
    var metric: BodyChartMetric
    var range: WeightChartRange
    var accentColor: Color

    @Binding var selectedDate: Date?
    @Binding var isInteracting: Bool
    var onSelectionChanged: () -> Void

    private let metricEntries: [BodyMetricEntry]
    private let chartEntries: [BodyMetricEntry]
    private let minValue: Double
    private let valueRange: Double
    private let chartStartDate: Date
    private let chartEndDate: Date

    init(
        entries: [BodyMetricEntry],
        metric: BodyChartMetric,
        range: WeightChartRange,
        accentColor: Color,
        selectedDate: Binding<Date?>,
        isInteracting: Binding<Bool>,
        onSelectionChanged: @escaping () -> Void
    ) {
        self.metric = metric
        self.range = range
        self.accentColor = accentColor
        self._selectedDate = selectedDate
        self._isInteracting = isInteracting
        self.onSelectionChanged = onSelectionChanged

        let sortedEntries = entries
            .filter { metric.value(from: $0) != nil }
            .sorted { $0.date < $1.date }
        let values = sortedEntries.compactMap { metric.value(from: $0) }
        let lowValue = values.min() ?? 0
        let highValue = values.max() ?? 1
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        self.metricEntries = sortedEntries
        self.chartEntries = Self.thinnedEntries(sortedEntries, metric: metric, range: range)
        self.minValue = lowValue
        self.valueRange = max(highValue - lowValue, metric == .weight ? 1 : 0.5)
        self.chartStartDate = calendar.date(byAdding: .day, value: -(range.days - 1), to: todayStart) ?? todayStart
        self.chartEndDate = Date()
    }

    private var activeSelectedEntry: BodyMetricEntry? {
        guard let selectedDate else {
            return nil
        }

        return metricEntries.first { abs($0.date.timeIntervalSince(selectedDate)) < 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(metric.title) trend")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.appMuted)

                Spacer()

                if
                    let first = metricEntries.first.flatMap({ metric.value(from: $0) }),
                    let last = metricEntries.last.flatMap({ metric.value(from: $0) }),
                    metricEntries.count > 1
                {
                    Text("\(metric.formatted(first)) -> \(metric.formatted(last))")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(accentColor)
                }
            }

            GeometryReader { proxy in
                chartCanvas(size: proxy.size)
            }
            .frame(maxHeight: .infinity)

            chartAxisLabels
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accentColor.opacity(0.16), lineWidth: 1))
        .onChange(of: range) { _, _ in
            selectedDate = nil
            isInteracting = false
        }
        .onDisappear {
            selectedDate = nil
            isInteracting = false
        }
    }

    private func chartCanvas(size: CGSize) -> some View {
        ZStack {
            chartGrid

            if chartEntries.count == 1, let entry = chartEntries.first, let value = metric.value(from: entry) {
                singlePoint(entry: entry, value: value, in: size)
            } else {
                trendLine(in: size)
                trendPoints(in: size)
            }

            if let activeSelectedEntry, let value = metric.value(from: activeSelectedEntry) {
                selectedMarker(
                    entry: activeSelectedEntry,
                    value: value,
                    point: chartPoint(for: activeSelectedEntry, value: value, size: size),
                    chartSize: size
                )
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isInteracting = true
                    if let entry = nearestEntry(for: value.location.x, width: size.width) {
                        selectedDate = entry.date
                        onSelectionChanged()
                    }
                }
                .onEnded { value in
                    if let entry = nearestEntry(for: value.location.x, width: size.width) {
                        selectedDate = entry.date
                        onSelectionChanged()
                    }
                    isInteracting = false
                }
        )
    }

    private var chartAxisLabels: some View {
        HStack {
            ForEach(Array(axisLabels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if index != axisLabels.count - 1 {
                    Spacer()
                }
            }
        }
    }

    private var axisLabels: [String] {
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .days30:
            return [29, 21, 14, 7, 0].compactMap { daysAgo in
                calendar.date(byAdding: .day, value: -daysAgo, to: now)?
                    .formatted(.dateTime.day().month(.abbreviated))
            }
        case .days90:
            return [90, 60, 30, 0].compactMap { daysAgo in
                calendar.date(byAdding: .day, value: -daysAgo, to: now)?
                    .formatted(.dateTime.day().month(.abbreviated))
            }
        case .days180:
            return [6, 4, 2, 0].compactMap { monthsAgo in
                calendar.date(byAdding: .month, value: -monthsAgo, to: now)?
                    .formatted(.dateTime.month(.abbreviated))
            }
        }
    }

    private var chartGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.appText.opacity(0.06))
                    .frame(height: 1)

                Spacer()
            }
        }
    }

    private func trendLine(in size: CGSize) -> some View {
        Path { path in
            for (index, entry) in chartEntries.enumerated() {
                guard let value = metric.value(from: entry) else {
                    continue
                }

                let point = chartPoint(for: entry, value: value, size: size)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(
            LinearGradient(colors: [accentColor, .neonCyan], startPoint: .leading, endPoint: .trailing),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
        .shadow(color: accentColor.opacity(0.35), radius: 10)
    }

    private func trendPoints(in size: CGSize) -> some View {
        ForEach(Array(chartEntries.enumerated()), id: \.element.id) { index, entry in
            if let value = metric.value(from: entry) {
                let point = chartPoint(for: entry, value: value, size: size)
                let isLast = index == chartEntries.count - 1

                Circle()
                    .fill(isLast ? accentColor : Color.appText.opacity(range == .days180 ? 0.52 : 0.65))
                    .frame(width: isLast ? 11 : (range == .days180 ? 5 : 7), height: isLast ? 11 : (range == .days180 ? 5 : 7))
                    .position(point)
            }
        }
    }

    private func singlePoint(entry: BodyMetricEntry, value: Double, in size: CGSize) -> some View {
        Circle()
            .fill(accentColor)
            .frame(width: 13, height: 13)
            .position(chartPoint(for: entry, value: value, size: size))
            .shadow(color: accentColor.opacity(0.5), radius: 10)
    }

    private func selectedMarker(entry: BodyMetricEntry, value: Double, point: CGPoint, chartSize: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.x, y: 0))
                path.addLine(to: CGPoint(x: point.x, y: chartSize.height))
            }
            .stroke(accentColor.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

            Circle()
                .fill(accentColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.appText.opacity(0.85), lineWidth: 2))
                .position(point)

            VStack(spacing: 3) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.appMuted)

                Text(metric.formatted(value))
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color.appElevated)
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(accentColor.opacity(0.22), lineWidth: 1))
            )
            .position(tooltipPosition(for: point, chartSize: chartSize))
        }
    }

    private func chartPoint(for entry: BodyMetricEntry, value: Double, size: CGSize) -> CGPoint {
        let timeSpan = max(chartEndDate.timeIntervalSince(chartStartDate), 1)
        let timeProgress = min(max(entry.date.timeIntervalSince(chartStartDate) / timeSpan, 0), 1)
        let x = CGFloat(timeProgress) * size.width
        let normalized = (value - minValue) / valueRange
        let y = size.height - CGFloat(normalized) * size.height

        return CGPoint(x: x, y: y)
    }

    private func nearestEntry(for x: CGFloat, width: CGFloat) -> BodyMetricEntry? {
        guard width > 0 else {
            return chartEntries.first
        }

        return chartEntries.min { left, right in
            abs(xPosition(for: left, width: width) - x) < abs(xPosition(for: right, width: width) - x)
        }
    }

    private func xPosition(for entry: BodyMetricEntry, width: CGFloat) -> CGFloat {
        let timeSpan = max(chartEndDate.timeIntervalSince(chartStartDate), 1)
        let timeProgress = min(max(entry.date.timeIntervalSince(chartStartDate) / timeSpan, 0), 1)
        return CGFloat(timeProgress) * width
    }

    private static func thinnedEntries(_ entries: [BodyMetricEntry], metric: BodyChartMetric, range: WeightChartRange) -> [BodyMetricEntry] {
        guard range == .days180, entries.count > 70 else {
            return entries
        }

        let threshold = metric == .weight ? 0.25 : 0.2
        var result: [BodyMetricEntry] = []
        var lastKeptEntry: BodyMetricEntry?
        var lastKeptValue: Double?

        for (index, entry) in entries.enumerated() {
            guard let value = metric.value(from: entry) else {
                continue
            }

            let isEdge = index == 0 || index == entries.count - 1
            let daysSinceLast = lastKeptEntry.map {
                abs(Calendar.current.dateComponents([.day], from: $0.date, to: entry.date).day ?? 0)
            } ?? Int.max
            let movedEnough = abs(value - (lastKeptValue ?? value)) >= threshold

            if isEdge || daysSinceLast >= 3 || movedEnough {
                result.append(entry)
                lastKeptEntry = entry
                lastKeptValue = value
            }
        }

        guard result.count > 120 else {
            return result
        }

        let stride = max(Int(ceil(Double(result.count) / 110.0)), 1)
        let sampled = result.enumerated().compactMap { index, entry in
            (index == 0 || index == result.count - 1 || index % stride == 0) ? entry : nil
        }

        return sampled
    }

    private func tooltipPosition(for point: CGPoint, chartSize: CGSize) -> CGPoint {
        let width: CGFloat = 126
        let height: CGFloat = 56
        let x = min(max(point.x, width / 2), chartSize.width - width / 2)
        let preferredY = point.y - 38
        let y = preferredY < height / 2 ? point.y + 42 : preferredY

        return CGPoint(x: x, y: min(max(y, height / 2), chartSize.height - height / 2))
    }
}
