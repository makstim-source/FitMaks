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

    @Environment(\.dismiss) private var dismiss
    @State private var currentMonthOffset: Int = 0
    @State private var stepsByDay: [String: Double] = [:]

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

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

                HStack {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.appMuted)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(extractDates().enumerated()), id: \.offset) { _, date in
                        if let date {
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let isFuture = date > Date()
                            let dailyEntries = allEntries.filter {
                                Calendar.current.isDate($0.date, inSameDayAs: date)
                            }
                            let trainingCalories = allTrainingEntries
                                .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
                                .reduce(0) { $0 + $1.caloriesBurned }
                            let uploadedTrainingSteps = allTrainingEntries
                                .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
                                .reduce(0) { $0 + max($1.steps ?? 0, 0) }
                            let dateID = DateFormatter.yyyyMMdd.string(from: date)
                            let steps = stepsByDay[dateID] ?? 0
                            let setup = calendarSetupIndex[dateID]
                            let mode = DayMode.fromStoredValue(setup?.mode)
                            let progress = DayProgressEngine.progress(
                                date: date,
                                foodEntries: dailyEntries,
                                trainingCalories: trainingCalories,
                                mode: mode,
                                baseCalories: setup?.resolvedBaseCalories(for: date, fallback: baseCalories) ?? baseCalories,
                                baseProtein: setup?.resolvedBaseProtein(for: date, fallback: baseProtein) ?? baseProtein,
                                steps: steps,
                                uploadedSteps: uploadedTrainingSteps,
                                activityLevel: activityLevel,
                                stepTarget: targetSteps
                            )
                            let calorieGoalMet = progress.calorieWin
                            let proteinGoalMet = progress.proteinWin
                            let stepsGoalMet = progress.stepWin
                            let isPerfectDay = progress.isPerfectPastDay()

                            CalendarDayCell(
                                date: date,
                                isSelected: isSelected,
                                isFuture: isFuture,
                                hasEntries: !dailyEntries.isEmpty,
                                calorieGoalMet: calorieGoalMet,
                                proteinGoalMet: proteinGoalMet,
                                stepsGoalMet: stepsGoalMet,
                                isPerfectDay: isPerfectDay,
                                mode: mode
                            ) {
                                selectedDate = date
                                dismiss()
                            }
                        } else {
                            Color.clear.frame(width: 40, height: 76)
                        }
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
        .onAppear(perform: loadStepsForVisibleMonth)
        .onChange(of: currentMonthOffset) { _, _ in
            loadStepsForVisibleMonth()
        }
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

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if isPerfectDay {
                    perfectMedal
                } else {
                    standardCircle
                }

                Text("\(dayNumber)")
                    .font(.system(size: isPerfectDay ? 16 : 15, weight: isPerfectDay ? .heavy : (isSelected ? .bold : .medium)))
                    .foregroundColor(dayTextColor)

                if isPerfectDay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.9), radius: 6)
                        .offset(x: 15, y: -16)
                }
            }
            .frame(width: 50, height: 50)
            .scaleEffect(isPerfectDay ? 1.06 : 1)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                    .frame(width: 52, height: 52)
            )
            .shadow(color: perfectGlowColor, radius: isPerfectDay ? 12 : 0, x: 0, y: 0)
            .opacity(isFuture ? 0.35 : 1)
            .onTapGesture {
                if !isFuture {
                    onTap()
                }
            }

            if isFuture {
                Color.clear.frame(height: 4)
            } else {
                HStack(spacing: 3) {
                    statusPip(isMet: calorieGoalMet, color: .neonGreen)
                    statusPip(isMet: proteinGoalMet, color: .neonCyan)
                    statusPip(isMet: stepsGoalMet, color: .yellow)
                }
            }

            if isFuture {
                Color.clear.frame(height: 12)
            } else if mode == .chill {
                Color.clear.frame(height: 22)
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
            HStack(spacing: -5) {
                modeBadgeIcon("figure.run", color: .neonGreen)
                    .zIndex(2)
                modeBadgeIcon("figure.strengthtraining.traditional", color: .fitOrange)
            }
            .frame(height: 19)
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
                        endRadius: 21
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.appText.opacity(0.42), lineWidth: 1))
                .shadow(color: color.opacity(isPerfectDay ? 0.95 : 0.72), radius: isPerfectDay ? 10 : 7, x: 0, y: 0)

            if isText {
                Text(symbol)
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.appText)
                    .offset(y: -0.5)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.black.opacity(0.88))
                    .shadow(color: .white.opacity(0.24), radius: 1, x: 0, y: 1)
            }
        }
    }

    private var standardCircle: some View {
        ZStack {
            Circle()
                .fill(standardFillColor)
                .frame(width: 40, height: 40)

            if proteinGoalMet {
                Circle()
                    .stroke(Color.neonCyan, lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .shadow(color: .neonCyan.opacity(0.5), radius: 4)
            }

            if stepsGoalMet {
                Circle()
                    .stroke(Color.yellow.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 48, height: 48)
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
                        endRadius: 32
                    )
                )
                .frame(width: 44, height: 44)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.yellow, .neonGreen, .neonCyan, .yellow],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 50, height: 50)

            Circle()
                .stroke(Color.appText.opacity(0.9), lineWidth: 1)
                .frame(width: 37, height: 37)
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
