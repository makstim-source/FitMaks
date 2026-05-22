import SwiftUI

extension ContentView {
    func bodySharePayload(metric: BodyChartMetric, range: WeightChartRange) -> FitMaksSharePayload? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
        let sourceEntries = allBodyMetrics
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }

        let entries = sourceEntries
            .compactMap { entry -> FitMaksShareWeightPoint? in
                guard let value = metric.value(from: entry) else { return nil }
                return FitMaksShareWeightPoint(
                    label: entry.date.formatted(.dateTime.day().month(.abbreviated)),
                    value: value
                )
            }

        guard let first = entries.first, let last = entries.last else {
            return nil
        }

        return .weight(
            FitMaksShareWeightSnapshot(
                title: "My body",
                subtitle: "\(metric.title) · \(range.title)",
                accentColor: metric.color,
                leadingValue: metric.formatted(first.value),
                trailingValue: metric.formatted(last.value),
                weightValue: nil,
                fatValue: nil,
                muscleValue: nil,
                xAxisLabels: shareXAxisLabels(from: entries),
                points: entries
            )
        )
    }

    func achievementPostOptions(limit: Int? = nil) -> [FitMaksPostOption] {
        let all = homeAchievementCollection.all.filter { $0.isUnlocked || $0.current > 0 }
        let source = limit.map { Array(all.prefix($0)) } ?? all

        return source.map {
            FitMaksPostOption(
                id: UUID(),
                title: $0.title,
                payload: viewModel.achievementSharePayload(from: $0)
            )
        }
    }

    func universalPostOptions() -> [FitMaksPostOption] {
        var options: [FitMaksPostOption] = [
            FitMaksPostOption(id: todaySharePayload().id, title: "Today", payload: todaySharePayload()),
            FitMaksPostOption(id: streakSharePayload().id, title: "Summary", payload: streakSharePayload()),
            FitMaksPostOption(id: streakBoardSharePayload().id, title: "Board", payload: streakBoardSharePayload())
        ]

        for range in WeightChartRange.allCases {
            for metric in BodyChartMetric.allCases {
                if let payload = bodySharePayload(metric: metric, range: range) {
                    options.append(
                        FitMaksPostOption(
                            id: payload.id,
                            title: "\(metric.title) · \(range.title)",
                            payload: payload
                        )
                    )
                }
            }
        }

        options.append(contentsOf: achievementPostOptions(limit: nil))
        return options
    }

    func todaySharePayload() -> FitMaksSharePayload {
        let caloriesAboveTarget = dailyCaloriesConsumed > maxCalories
        let caloriesOutsideGrace = dailyCaloriesConsumed > dailyProgress.calorieGraceLimit
        let calorieSubtitle = caloriesAboveTarget
            ? (caloriesOutsideGrace ? "over" : "grace")
            : "deficit"

        let headline = posterDayline(for: viewModel.selectedDate)

        let subheadline = "\(viewModel.formatDate(viewModel.selectedDate)) · \(viewModel.modeLabel(currentDayMode))"

        return .today(
            FitMaksShareTodaySnapshot(
                dateLabel: viewModel.formatDate(viewModel.selectedDate),
                modeLabel: viewModel.modePostLabel(currentDayMode),
                modeEmoji: currentDayMode.emoji,
                modeSymbolName: viewModel.modeShareSymbol(currentDayMode),
                headline: headline,
                subheadline: subheadline,
                isPerfectDay: dailyProgress.isPerfect,
                metrics: [
                    FitMaksShareMetric(
                        title: "Calories",
                        value: caloriesAboveTarget
                            ? "\(Int(dailyCaloriesConsumed - maxCalories))"
                            : "\(Int(max(dailyCaloriesRemaining, 0)))",
                        subtitle: calorieSubtitle,
                        progress: min(max(dailyCaloriesConsumed / max(maxCalories, 1), 0), 1),
                        color: caloriesOutsideGrace ? .red : .neonGreen,
                        systemImage: caloriesOutsideGrace ? "exclamationmark.triangle.fill" : "leaf.fill"
                    ),
                    FitMaksShareMetric(
                        title: "Protein",
                        value: "\(Int(dailyProtein))",
                        subtitle: "grams",
                        progress: min(max(dailyProtein / max(targetProtein, 1), 0), 1),
                        color: .neonCyan,
                        systemImage: "drop.fill"
                    ),
                    FitMaksShareMetric(
                        title: "Steps",
                        value: "\(Int(dailyProgress.effectiveSteps))",
                        subtitle: "goal 10k",
                        progress: min(max(dailyProgress.effectiveSteps / max(targetSteps, 1), 0), 1),
                        color: viewModel.getStepsColor(steps: dailyProgress.effectiveSteps, target: targetSteps),
                        systemImage: "shoeprints.fill"
                    )
                ]
            )
        )
    }

    func streakSharePayload() -> FitMaksSharePayload {
        .streak(
            FitMaksShareStreakSnapshot(
                current: homePerfectStreak,
                target: Int(AppRules.weeklyStreakTarget),
                best30: homePerfectStreak,
                perfect30: min(homePerfectStreak, 30)
            )
        )
    }

    func streakBoardSharePayload() -> FitMaksSharePayload {
        .streakBoard(
            FitMaksShareStreakBoardSnapshot(
                rows: homeRecentSevenDayStats.map { stat in
                    let isOver = stat.hasFood && stat.consumed > stat.calorieGraceLimit
                    return FitMaksShareStreakBoardRow(
                        dayName: StatsFormatters.dayName(stat.date),
                        dayNumber: StatsFormatters.dayNumber(stat.date),
                        modeEmoji: stat.mode.emoji,
                        calorieWin: stat.calorieWin,
                        proteinWin: stat.proteinWin,
                        stepWin: stat.stepWin,
                        isPerfect: stat.isPerfect,
                        calorieTitle: isOver ? "kcal over" : "kcal deficit",
                        calorieValue: stat.hasFood ? "\(abs(Int(stat.target - stat.consumed)))" : "—",
                        calorieColor: isOver ? .red : .neonGreen,
                        proteinValue: "\(Int(stat.protein))/\(Int(stat.proteinTarget))g",
                        stepsValue: "\(StatsFormatters.compactWholeSteps(stat.effectiveSteps))/10k",
                        stepsColor: stat.stepBonus > 0 ? .fitOrange : .yellow
                    )
                }
            )
        )
    }

    func foodSharePayload(for entry: FoodEntry) -> FitMaksSharePayload {
        .food(
            FitMaksShareFoodSnapshot(
                name: cleanShareFoodName(entry.name),
                subtitle: viewModel.formatDate(entry.date),
                caloriesText: "\(Int(entry.calories)) kcal",
                proteinText: "\(Int(entry.protein))g",
                breakdownLines: shareBreakdownLines(from: entry.ingredients),
                image: entry.uiImage
            )
        )
    }

    func workoutSharePayload(for entry: TrainingEntry) -> FitMaksSharePayload {
        let lowercased = "\(entry.name.lowercased()) \(entry.aiSummary?.lowercased() ?? "")"
        let systemImage: String
        let accentColor: Color
        if lowercased.contains("strength") || lowercased.contains("gym") || lowercased.contains("leg") || lowercased.contains("upper body") || lowercased.contains("lower body") || lowercased.contains("weight") {
            systemImage = "dumbbell.fill"
            accentColor = .fitPurple
        } else if lowercased.contains("padel") || lowercased.contains("tennis") {
            systemImage = "tennis.racket"
            accentColor = .fitOrange
        } else {
            systemImage = "figure.run"
            accentColor = .neonCyan
        }

        return .workout(
            FitMaksShareWorkoutSnapshot(
                name: workoutShareTitle(for: entry),
                subtitle: entry.aiSummary?.isEmpty == false ? entry.aiSummary ?? viewModel.formatDate(entry.date) : viewModel.formatDate(entry.date),
                caloriesText: "\(Int(entry.caloriesBurned)) kcal",
                stepsText: (entry.steps ?? 0) > 0 ? "\(Int(entry.steps ?? 0))" : nil,
                durationText: entry.duration.isEmpty ? nil : entry.duration,
                tonnageText: entry.tonnageKg.map { "\(Int($0)) kg" },
                systemImage: systemImage,
                accentColor: accentColor,
                image: nil
            )
        )
    }

    private func shareBreakdownLines(from ingredients: String) -> [String] {
        ShareFormatters.breakdownLines(from: ingredients)
    }

    private func compactWorkoutTitle(_ raw: String) -> String {
        ShareFormatters.compactWorkoutTitle(raw)
    }

    private func workoutShareTitle(for entry: TrainingEntry) -> String {
        let base = compactWorkoutTitle(entry.name)
        let fullWeekday = ShareFormatters.weekdayName(for: entry.date)
        let shortWeekday = ShareFormatters.shortWeekdayName(for: entry.date)

        let full = "\(fullWeekday) \(base)"
        if full.count <= 28 {
            return full
        }

        let short = "\(shortWeekday) \(base)"
        if short.count <= 28 {
            return short
        }

        let maxBaseLength = max(12, 28 - shortWeekday.count - 1)
        return "\(shortWeekday) \(ShareFormatters.truncatedWordBoundary(base, maxLength: maxBaseLength))"
    }

    private func cleanShareFoodName(_ raw: String) -> String {
        ShareFormatters.cleanFoodName(raw)
    }

    private func shareXAxisLabels(from points: [FitMaksShareWeightPoint]) -> [String] {
        ShareFormatters.xAxisLabels(from: points.map(\.label))
    }

    private func posterDayline(for date: Date) -> String {
        ShareFormatters.posterDayline(for: date)
    }
}

enum ShareFormatters {
    static func breakdownLines(from ingredients: String) -> [String] {
        ingredients
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func compactWorkoutTitle(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "Workout", with: "")
            .replacingOccurrences(of: "Training", with: "")
            .replacingOccurrences(of: "Session", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > 40 else {
            return cleaned.isEmpty ? raw : cleaned
        }

        let words = cleaned.split(separator: " ")
        var result = ""
        for word in words {
            let candidate = result.isEmpty ? String(word) : "\(result) \(word)"
            if candidate.count > 40 {
                break
            }
            result = candidate
        }

        return result.isEmpty ? String(cleaned.prefix(40)) : result
    }

    static func cleanFoodName(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "👨‍🍳 ", with: "")
            .replacingOccurrences(of: "❄️ ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func xAxisLabels(from labels: [String]) -> [String] {
        guard !labels.isEmpty else { return [] }
        if labels.count == 1 { return [labels[0]] }

        let first = labels.first
        let middle = labels[labels.count / 2]
        let last = labels.last

        return [first, middle, last]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, label in
                if result.last != label {
                    result.append(label)
                }
            }
    }

    static func posterDayline(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 2: return "What a Monday."
        case 3: return "Full push Tuesday."
        case 4: return "Winning Wednesday."
        case 5: return "Locked-in Thursday."
        case 6: return "No-slip Friday."
        case 7: return "Strong Saturday."
        case 1: return "Sunday reset."
        default: return "Today."
        }
    }

    static func weekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func shortWeekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func truncatedWordBoundary(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let lastSpace = prefix.lastIndex(of: " ") {
            let trimmed = prefix[..<lastSpace].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 8 {
                return String(trimmed)
            }
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension HomeViewModel {
    func modeShareSymbol(_ mode: DayMode) -> String {
        switch mode {
        case .chill:
            return "moon.zzz.fill"
        case .cardio:
            return "figure.run"
        case .gym:
            return "dumbbell.fill"
        case .cardioGym:
            return "figure.mixed.cardio"
        }
    }
}
