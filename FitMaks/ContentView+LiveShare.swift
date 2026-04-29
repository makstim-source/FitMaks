import SwiftUI

extension ContentView {
    func latestWeightSharePayload() -> FitMaksSharePayload? {
        let entries = allBodyMetrics
            .prefix(30)
            .reversed()
            .map {
                FitMaksShareWeightPoint(
                    label: $0.date.formatted(.dateTime.day().month(.abbreviated)),
                    value: $0.weightKg
                )
            }

        guard let first = entries.first, let last = entries.last else {
            return nil
        }

        return .weight(
            FitMaksShareWeightSnapshot(
                title: "Weight trend",
                subtitle: "Last 30 days",
                accentColor: .neonGreen,
                leadingValue: "\(String(format: "%.1f", first.value)) kg",
                trailingValue: "\(String(format: "%.1f", last.value)) kg",
                points: entries
            )
        )
    }

    func achievementPostOptions(limit: Int? = nil) -> [FitMaksPostOption] {
        let source = limit.map { Array(homeAchievementCollection.all.prefix($0)) } ?? homeAchievementCollection.all

        return source.map {
            FitMaksPostOption(
                id: UUID(),
                title: $0.title,
                payload: achievementSharePayload(from: $0)
            )
        }
    }

    func universalPostOptions() -> [FitMaksPostOption] {
        var options: [FitMaksPostOption] = [
            FitMaksPostOption(id: todaySharePayload().id, title: "Today", payload: todaySharePayload()),
            FitMaksPostOption(id: streakSharePayload().id, title: "Summary", payload: streakSharePayload()),
            FitMaksPostOption(id: streakBoardSharePayload().id, title: "Board", payload: streakBoardSharePayload())
        ]

        if let weightPayload = latestWeightSharePayload() {
            options.append(FitMaksPostOption(id: weightPayload.id, title: "Weight", payload: weightPayload))
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

        let headline: String
        if isPerfectPastDay {
            headline = "Perfect day."
        } else if dailyProgress.proteinWin && dailyProgress.calorieWin {
            headline = "Clean day."
        } else if dailyProgress.stepWin {
            headline = "Still moving."
        } else {
            headline = "Today, readable."
        }

        let subheadline = "\(formatDate(selectedDate)) · \(modeLabel(currentDayMode))"

        return .today(
            FitMaksShareTodaySnapshot(
                dateLabel: formatDate(selectedDate),
                modeLabel: modePostLabel(currentDayMode),
                modeEmoji: currentDayMode.emoji,
                modeSymbolName: modeShareSymbol(currentDayMode),
                headline: headline,
                subheadline: subheadline,
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
                        value: "\(Int(dailyProtein))g",
                        subtitle: "of \(Int(targetProtein))g",
                        progress: min(max(dailyProtein / max(targetProtein, 1), 0), 1),
                        color: .neonCyan,
                        systemImage: "drop.fill"
                    ),
                    FitMaksShareMetric(
                        title: "Steps",
                        value: "\(Int(dailyProgress.effectiveSteps))",
                        subtitle: dailyProgress.uploadedSteps > 0
                            ? "screen"
                            : (dailyProgress.stepBonus > 0 ? "+\(Int(dailyProgress.stepBonus / 1000))k gym" : "of 10k"),
                        progress: min(max(dailyProgress.countedSteps / max(targetSteps, 1), 0), 1),
                        color: getStepsColor(steps: dailyProgress.effectiveSteps, target: targetSteps),
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

    func achievementSharePayload(from achievement: StatsAchievement) -> FitMaksSharePayload {
        .achievement(
            FitMaksShareAchievementSnapshot(
                title: achievement.title,
                subtitle: achievement.subtitle,
                detail: achievement.detail,
                progressText: achievement.progressText,
                icon: achievement.icon,
                color: achievement.color,
                isUnlocked: achievement.isUnlocked
            )
        )
    }

    func foodSharePayload(for entry: FoodEntry) -> FitMaksSharePayload {
        .food(
            FitMaksShareFoodSnapshot(
                name: cleanShareFoodName(entry.name),
                subtitle: formatDate(entry.date),
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
                name: compactWorkoutTitle(entry.name),
                subtitle: entry.aiSummary?.isEmpty == false ? entry.aiSummary ?? formatDate(entry.date) : formatDate(entry.date),
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
        ingredients
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func compactWorkoutTitle(_ raw: String) -> String {
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

    private func cleanShareFoodName(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "👨‍🍳 ", with: "")
            .replacingOccurrences(of: "❄️ ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func modeShareSymbol(_ mode: DayMode) -> String {
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
