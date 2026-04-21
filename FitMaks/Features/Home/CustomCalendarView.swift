import SwiftUI

struct CustomCalendarView: View {
    @Binding var selectedDate: Date

    var allEntries: [FoodEntry]
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
                            let isPastDay = date < Calendar.current.startOfDay(for: Date())
                            let isFuture = date > Date()
                            let dailyEntries = allEntries.filter {
                                Calendar.current.isDate($0.date, inSameDayAs: date)
                            }
                            let totalCal = dailyEntries.reduce(0) { $0 + $1.calories }
                            let totalProt = dailyEntries.reduce(0) { $0 + $1.protein }
                            let dateID = DateFormatter.yyyyMMdd.string(from: date)
                            let steps = stepsByDay[dateID] ?? 0
                            let mode = dayMode(for: date)
                            let calorieGoalMet = !dailyEntries.isEmpty && totalCal <= AppRules.caloriePerfectLimit(for: calorieTarget(for: mode))
                            let proteinGoalMet = !dailyEntries.isEmpty && totalProt >= AppRules.completionMinimum(for: proteinTarget(for: mode))
                            let stepsGoalMet = steps >= AppRules.completionMinimum(for: targetSteps)
                            let isPerfectDay = isPastDay && calorieGoalMet && proteinGoalMet && stepsGoalMet

                            CalendarDayCell(
                                date: date,
                                isSelected: isSelected,
                                isFuture: isFuture,
                                hasEntries: !dailyEntries.isEmpty,
                                calorieGoalMet: calorieGoalMet,
                                proteinGoalMet: proteinGoalMet,
                                stepsGoalMet: stepsGoalMet,
                                isPerfectDay: isPerfectDay,
                                modeEmoji: mode.emoji
                            ) {
                                selectedDate = date
                                dismiss()
                            }
                        } else {
                            Color.clear.frame(width: 40, height: 68)
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

    private func dayMode(for date: Date) -> DayMode {
        let dateID = DateFormatter.yyyyMMdd.string(from: date)
        let modeString = allSetups.first(where: { $0.dateID == dateID })?.mode

        return DayMode.fromStoredValue(modeString)
    }

    private func calorieTarget(for mode: DayMode) -> Double {
        switch mode {
        case .chill:
            return baseCalories
        case .padel:
            return baseCalories + 500
        case .gym:
            return baseCalories + 300
        }
    }

    private func proteinTarget(for mode: DayMode) -> Double {
        switch mode {
        case .chill:
            return baseProtein
        case .padel:
            return baseProtein + 15
        case .gym:
            return baseProtein + 25
        }
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
    var modeEmoji: String
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
            } else {
                Text(modeEmoji)
                    .font(.system(size: 10))
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
                            Color.white.opacity(0.95),
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
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
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
