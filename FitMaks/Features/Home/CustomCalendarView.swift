import SwiftUI

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @AppStorage("userActivity") private var activityLevel: String = "Moderate"

    var allEntries: [FoodEntry]
    var allTrainingEntries: [TrainingEntry]
    var baseCalories: Double
    var baseProtein: Double
    var targetSteps: Double
    var allSetups: [DailySetup]
    var onWeeklyReport: ((Date) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currentMonthOffset: Int = 0
    @State private var stepsByDay: [String: Double] = [:]
    @State private var progressCache: [String: CachedDayInfo] = [:]

    private struct CachedDayInfo {
        let hasEntries: Bool
        let calorieWin: Bool
        let proteinWin: Bool
        let stepWin: Bool
        let isPerfect: Bool
        let mode: DayMode
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                HStack {
                    Button(action: { currentMonthOffset -= 1 }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.neonGreen)
                            .font(.title2)
                    }

                    Spacer()

                    Text(monthYearString(for: currentMonthOffset))
                        .font(.title3)
                        .bold()
                        .foregroundColor(.appText)

                    Spacer()

                    Button(action: { currentMonthOffset += 1 }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(currentMonthOffset < 0 ? .neonGreen : .appMuted)
                            .font(.title2)
                    }
                    .disabled(currentMonthOffset >= 0)
                }
                .padding(.horizontal)
                .padding(.top, 25)

                HStack(spacing: 0) {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.appMuted)
                            .frame(maxWidth: .infinity)
                    }
                    Color.clear.frame(width: 26)
                }

                let weeks = extractWeeks()
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            if let date = week[index] {
                                calendarCell(for: date)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 76)
                            }
                        }
                        weekReportButton(for: week)
                            .frame(width: 28)
                    }
                }

                calendarLegend
            }
            .padding()
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(colors: [.appBackgroundStart, .appBackgroundMid, .appBackgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            loadStepsForVisibleMonth()
            rebuildProgressCache()
        }
        .onChange(of: currentMonthOffset) { _, _ in
            loadStepsForVisibleMonth()
            rebuildProgressCache()
        }
        .onChange(of: stepsByDay) { _, _ in
            rebuildProgressCache()
        }
    }

    @ViewBuilder
    private func calendarCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date()))!
        let isFuture = date >= dayAfterTomorrow
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let cached = progressCache[dateID]

        CalendarDayCell(
            date: date,
            isSelected: isSelected,
            isFuture: isFuture,
            hasEntries: cached?.hasEntries ?? false,
            calorieGoalMet: cached?.calorieWin ?? false,
            proteinGoalMet: cached?.proteinWin ?? false,
            stepsGoalMet: cached?.stepWin ?? false,
            isPerfectDay: cached?.isPerfect ?? false,
            mode: cached?.mode ?? .chill
        ) {
            selectedDate = date
            dismiss()
        }
    }

    @ViewBuilder
    private func weekReportButton(for week: [Date?]) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = week.compactMap { $0 }
        let allPast = !dates.isEmpty && dates.allSatisfy { calendar.startOfDay(for: $0) < today }
        let hasAnyData = allPast && dates.contains { date in
            allEntries.contains { calendar.isDate($0.date, inSameDayAs: date) }
            || allTrainingEntries.contains { calendar.isDate($0.date, inSameDayAs: date) }
        }

        if hasAnyData, let monday = dates.first, onWeeklyReport != nil {
            Button {
                onWeeklyReport?(monday)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("W")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundColor(.neonGreen)
                .frame(width: 26, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.neonGreen.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.neonGreen.opacity(0.22), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 26, height: 38)
        }
    }

    private func extractWeeks() -> [[Date?]] {
        let flat = extractDates()
        var weeks: [[Date?]] = []
        var i = 0
        while i < flat.count {
            let end = min(i + 7, flat.count)
            var week = Array(flat[i..<end])
            while week.count < 7 { week.append(nil) }
            weeks.append(week)
            i += 7
        }
        return weeks
    }

    private func monthYearString(for offset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let date = Calendar.current.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private var calendarLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: .neonGreen, text: "Deficit")
            legendItem(color: .neonCyan, text: "Protein")
            legendItem(color: .yellow, text: "10k steps")
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("Perfect")
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.yellow)
        }
        .padding(.top, 4)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.appMuted)
    }

    private var calendarSetupIndex: [String: DailySetup] {
        Dictionary(allSetups.map { ($0.dateID, $0) }, uniquingKeysWith: { _, new in new })
    }

    private func dayMode(for date: Date) -> DayMode {
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let modeString = calendarSetupIndex[dateID]?.mode
        return DayMode.fromStoredValue(modeString)
    }

    private func rebuildProgressCache() {
        let calendar = Calendar.current
        let dates = extractDates().compactMap { $0 }
        let index = calendarSetupIndex

        var foodByDay: [String: [FoodEntry]] = [:]
        for entry in allEntries {
            let key = DateFormatter.yyyyMMdd.string(from: entry.date)
            foodByDay[key, default: []].append(entry)
        }

        var trainingByDay: [String: (calories: Double, steps: Double)] = [:]
        for entry in allTrainingEntries {
            let key = DateFormatter.yyyyMMdd.string(from: entry.date)
            var existing = trainingByDay[key] ?? (0, 0)
            existing.calories += entry.caloriesBurned
            existing.steps += max(entry.steps ?? 0, 0)
            trainingByDay[key] = existing
        }

        var newCache: [String: CachedDayInfo] = [:]
        for date in dates {
            let dateID = DateFormatter.yyyyMMdd.string(from: date)
            let setup = index[dateID]
            let mode = DayMode.fromStoredValue(setup?.mode)
            let dayFood = foodByDay[dateID] ?? []
            let training = trainingByDay[dateID] ?? (0, 0)
            let progress = DayProgressEngine.progress(
                date: date,
                foodEntries: dayFood,
                trainingCalories: training.calories,
                mode: mode,
                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCalories) ?? baseCalories,
                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProtein) ?? baseProtein,
                steps: stepsByDay[dateID] ?? 0,
                uploadedSteps: training.steps,
                activityLevel: activityLevel,
                stepTarget: targetSteps
            )
            newCache[dateID] = CachedDayInfo(
                hasEntries: !dayFood.isEmpty,
                calorieWin: progress.calorieWin,
                proteinWin: progress.proteinWin,
                stepWin: progress.stepWin,
                isPerfect: progress.isPerfectPastDay(),
                mode: mode
            )
        }
        progressCache = newCache
    }

    private func loadStepsForVisibleMonth() {
        let range = visibleMonthRange()

        HealthKitManager.shared.fetchSteps(from: range.start, to: range.end) { steps in
            DispatchQueue.main.async {
                stepsByDay.merge(steps) { _, new in new }
            }
        }
    }

    private func visibleMonthRange() -> (start: Date, end: Date) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let target = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: target)) ?? target
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<2
        let end = calendar.date(byAdding: .day, value: range.count - 1, to: start) ?? start

        return (start, end)
    }

    private func extractDates() -> [Date?] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let target = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: target)) ?? target
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<2

        var firstWeekday = calendar.component(.weekday, from: start) - calendar.firstWeekday
        if firstWeekday < 0 {
            firstWeekday += 7
        }

        var dates: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                dates.append(date)
            }
        }

        return dates
    }
}

private struct CalendarDayCell: View {
    var date: Date
    var isSelected: Bool
    var isFuture: Bool
    var hasEntries: Bool
    var calorieGoalMet: Bool
    var proteinGoalMet: Bool
    var stepsGoalMet: Bool
    var isPerfectDay: Bool
    var mode: DayMode
    var onTap: () -> Void

    private var lightTheme: Bool {
        isLightAppTheme()
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isPerfectDay {
                    perfectMedal
                } else {
                    standardCircle
                }

                Text("\(dayNumber)")
                    .font(.system(size: isPerfectDay ? 14 : 13, weight: isPerfectDay ? .heavy : (isSelected ? .bold : .medium)))
                    .foregroundColor(dayTextColor)

                if isPerfectDay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.9), radius: 5)
                        .offset(x: 13, y: -14)
                }
            }
            .frame(width: 40, height: 40)
            .scaleEffect(isPerfectDay ? 1.06 : 1)
            .overlay(
                Circle()
                    .stroke(lightTheme ? Color.appAccentText.opacity(0.74) : Color.white, lineWidth: isSelected ? 2 : 0)
                    .frame(width: 42, height: 42)
            )
            .shadow(color: perfectGlowColor, radius: isPerfectDay ? 10 : 0, x: 0, y: 0)
            .opacity(isFuture ? 0.35 : 1)
            .onTapGesture {
                if !isFuture {
                    onTap()
                }
            }

            if isFuture {
                Color.clear.frame(height: 3)
            } else {
                HStack(spacing: 2) {
                    statusPip(isMet: calorieGoalMet, color: .neonGreen)
                    statusPip(isMet: proteinGoalMet, color: .neonCyan)
                    statusPip(isMet: stepsGoalMet, color: .yellow)
                }
            }

            if isFuture {
                Color.clear.frame(height: 10)
            } else if mode == .chill {
                Color.clear.frame(height: 18)
            } else {
                modeBadge
            }
        }
    }

    @ViewBuilder
    private var modeBadge: some View {
        switch mode {
        case .chill:
            EmptyView()
        case .cardio:
            modeBadgeIcon("figure.run", color: .neonGreen)
        case .gym:
            modeBadgeIcon("figure.strengthtraining.traditional", color: .fitOrange)
        case .cardioGym:
            HStack(spacing: -4) {
                modeBadgeIcon("figure.run", color: .neonGreen)
                    .zIndex(2)
                modeBadgeIcon("figure.strengthtraining.traditional", color: .fitOrange)
            }
            .frame(height: 16)
        }
    }

    private func modeBadgeIcon(_ symbol: String, color: Color, isText: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.appText,
                            color.opacity(0.98),
                            color.opacity(0.72)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 17
                    )
                )
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.appText.opacity(0.42), lineWidth: 1))
                .shadow(color: color.opacity(isPerfectDay ? 0.95 : 0.72), radius: isPerfectDay ? 8 : 5, x: 0, y: 0)

            if isText {
                Text(symbol)
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.appText)
                    .offset(y: -0.5)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.black.opacity(0.88))
                    .shadow(color: .white.opacity(0.24), radius: 1, x: 0, y: 1)
            }
        }
    }

    private var standardCircle: some View {
        ZStack {
            Circle()
                .fill(standardFillColor)
                .frame(width: 32, height: 32)

            if proteinGoalMet {
                Circle()
                    .stroke(Color.neonCyan, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                    .shadow(color: .neonCyan.opacity(0.5), radius: 3)
            }

            if stepsGoalMet {
                Circle()
                    .stroke(Color.yellow.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var perfectMedal: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.appText,
                            Color.neonGreen.opacity(0.95),
                            Color.yellow.opacity(0.85)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 26
                    )
                )
                .frame(width: 36, height: 36)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.yellow, .neonGreen, .neonCyan, .yellow],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 40, height: 40)

            Circle()
                .stroke(Color.appText.opacity(0.9), lineWidth: 1)
                .frame(width: 30, height: 30)
        }
    }

    private var standardFillColor: Color {
        guard hasEntries else {
            return Color.gray.opacity(0.15)
        }

        return calorieGoalMet ? Color.neonGreen.opacity(0.82) : Color.red.opacity(0.82)
    }

    private var dayTextColor: Color {
        if isPerfectDay {
            return .black
        }

        return hasEntries ? .black : .white
    }

    private var perfectGlowColor: Color {
        isPerfectDay ? Color.yellow.opacity(0.65) : .clear
    }

    private func statusPip(isMet: Bool, color: Color) -> some View {
        Capsule()
            .fill(isMet ? color : Color.gray.opacity(hasEntries ? 0.35 : 0.18))
            .frame(width: isMet ? 9 : 6, height: 4)
            .shadow(color: isMet ? color.opacity(0.6) : .clear, radius: 4)
    }
}
