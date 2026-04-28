//
//  FitMaksTests.swift
//  FitMaksTests
//
//  Created by Maksimilian Timofeev on 17.4.2026.
//

import Foundation
import Testing
import UIKit
@testable import FitMaks

struct FitMaksTests {

    @Test func historicalWeightLogsDoNotReplaceProfileWeight() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let latest = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 8)))
        let historical = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 8)))

        #expect(!BodyMetricProfileSync.shouldPromoteProfileWeight(candidateDate: historical, currentLatestDate: latest, calendar: calendar))
    }

    @Test func currentDayWeightLogsCanReplaceProfileWeight() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let latest = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 8)))
        let sameDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 6)))

        #expect(BodyMetricProfileSync.shouldPromoteProfileWeight(candidateDate: sameDay, currentLatestDate: latest, calendar: calendar))
    }

    @Test func dailyBestWeightKeepsLowerSameDayResult() async throws {
        #expect(BodyMetricDailyBest.shouldReplace(
            existingWeight: 81.4,
            existingScore: 2,
            candidateWeight: 81.1,
            candidateScore: 1
        ))
        #expect(!BodyMetricDailyBest.shouldReplace(
            existingWeight: 81.1,
            existingScore: 1,
            candidateWeight: 81.4,
            candidateScore: 4
        ))
    }

    @Test func dailyBestWeightUsesRicherMetricsWhenWeightTies() async throws {
        #expect(BodyMetricDailyBest.shouldReplace(
            existingWeight: 81.30,
            existingScore: 1,
            candidateWeight: 81.32,
            candidateScore: 3
        ))
        #expect(!BodyMetricDailyBest.shouldReplace(
            existingWeight: 81.30,
            existingScore: 3,
            candidateWeight: 81.32,
            candidateScore: 1
        ))
    }

    @Test func pastDailySetupUsesFrozenGoalSnapshot() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 8)))
        let past = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21, hour: 8)))
        let setup = DailySetup(date: past, mode: .chill, baseCalories: 2_000, baseProtein: 180)

        #expect(setup.resolvedBaseCalories(for: past, fallback: 1_700, now: now, calendar: calendar) == 2_000)
        #expect(setup.resolvedBaseProtein(for: past, fallback: 150, now: now, calendar: calendar) == 180)
    }

    @Test func currentDaySetupUsesLiveGoals() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 8)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 6)))
        let setup = DailySetup(date: today, mode: .chill, baseCalories: 2_000, baseProtein: 180)

        #expect(setup.resolvedBaseCalories(for: today, fallback: 1_700, now: now, calendar: calendar) == 1_700)
        #expect(setup.resolvedBaseProtein(for: today, fallback: 150, now: now, calendar: calendar) == 150)
    }

    @Test func proteinRecommendationUsesSustainableGoalMultipliers() async throws {
        #expect(NutritionCalculator.recommendedProtein(weight: 80, goal: "Maintain") == 144)
        #expect(NutritionCalculator.recommendedProtein(weight: 80, goal: "Lose Weight") == 160)
        #expect(NutritionCalculator.recommendedProtein(weight: 80, goal: "Recomp") == 176)
        #expect(NutritionCalculator.recommendedProtein(weight: 80, goal: "Build Muscle") == 176)
    }

    @Test func calorieRecommendationUsesSharedFormula() async throws {
        let bmr = NutritionCalculator.bmr(gender: "Male", age: 30, weight: 80, height: 180)
        let maintenance = NutritionCalculator.maintenanceCalories(
            gender: "Male",
            age: 30,
            weight: 80,
            height: 180,
            activityLevel: "Moderate"
        )

        #expect(abs(bmr - 1_780) < 0.001)
        #expect(abs(maintenance - 2_581) < 0.001)
        #expect(abs(NutritionCalculator.recommendedCalories(
            gender: "Male",
            age: 30,
            weight: 80,
            height: 180,
            activityLevel: "Moderate",
            goal: "Lose Weight"
        ) - 2_081) < 0.001)
        #expect(abs(NutritionCalculator.recommendedCalories(
            gender: "Male",
            age: 30,
            weight: 80,
            height: 180,
            activityLevel: "Moderate",
            goal: "Recomp"
        ) - 2_381) < 0.001)
        #expect(abs(NutritionCalculator.recommendedCalories(
            gender: "Male",
            age: 30,
            weight: 80,
            height: 180,
            activityLevel: "Moderate",
            goal: "Build Muscle"
        ) - 2_831) < 0.001)
    }

    @Test func perfectDayAcceptsThreePercentGrace() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))

        let progress = DayProgressEngine.progress(
            date: yesterday,
            consumedCalories: 2_060,
            consumedProtein: 175,
            hasFood: true,
            mode: .chill,
            baseCalories: 2_000,
            baseProtein: 180,
            steps: 9_700
        )

        #expect(progress.calorieWin)
        #expect(progress.proteinWin)
        #expect(progress.stepWin)
        #expect(progress.isPerfectPastDay(relativeTo: now, calendar: calendar))
    }

    @Test func perfectDayRejectsValuesOutsideGrace() async throws {
        let progress = DayProgressEngine.progress(
            date: Date(),
            consumedCalories: 2_061,
            consumedProtein: 174,
            hasFood: true,
            mode: .chill,
            baseCalories: 2_000,
            baseProtein: 180,
            steps: 9_699
        )

        #expect(!progress.calorieWin)
        #expect(!progress.proteinWin)
        #expect(!progress.stepWin)
    }

    @Test func trainingModeAddsCaloriesAndProteinBudget() async throws {
        let cardioTargets = DayProgressEngine.targets(
            baseCalories: 2_000,
            baseProtein: 180,
            mode: .cardio
        )

        let gymTargets = DayProgressEngine.targets(
            baseCalories: 2_000,
            baseProtein: 180,
            mode: .gym
        )

        #expect(cardioTargets.calories == 2_500)
        #expect(cardioTargets.protein == 195)
        #expect(cardioTargets.stepBonus == 0)
        #expect(gymTargets.calories == 2_300)
        #expect(gymTargets.protein == 205)
        #expect(gymTargets.stepBonus == 5_000)
    }

    @Test func cardioTrainingCaloriesReplaceEstimatedBonus() async throws {
        let targets = DayProgressEngine.targets(
            baseCalories: 2_000,
            baseProtein: 180,
            mode: .cardio,
            trainingCalories: 642
        )

        let credited = 642 * DayProgressEngine.workoutCalorieCreditRatio
        #expect(targets.calorieBonus == credited)
        #expect(targets.calories == 2_000 + credited)
        #expect(targets.protein == 195)
    }

    @Test func legacyPadelModeLoadsAsCardio() async throws {
        #expect(DayMode.fromStoredValue("Padel 🎾") == .cardio)
    }

    @Test func dayModeCanRepresentCardioAndGymTogether() async throws {
        let combined = DayMode.cardio.merged(with: .gym)

        #expect(combined == .cardioGym)
        #expect(combined.includes(.cardio))
        #expect(combined.includes(.gym))
        #expect(!combined.includes(.chill))
        #expect(combined.toggled(.cardio) == .gym)
        #expect(combined.toggled(.gym) == .cardio)
    }

    @Test func combinedTrainingModeStacksCardioAndGymBudgets() async throws {
        let targets = DayProgressEngine.targets(
            baseCalories: 2_000,
            baseProtein: 180,
            mode: .cardioGym,
            trainingCalories: 640
        )

        let creditedCardio = 640 * DayProgressEngine.workoutCalorieCreditRatio
        #expect(targets.calorieBonus == creditedCardio + 300)
        #expect(targets.proteinBonus == 40)
        #expect(targets.stepBonus == 5_000)
    }

    @Test func gymStepCreditCanCloseMovementGoal() async throws {
        let progress = DayProgressEngine.progress(
            date: Date(),
            consumedCalories: 2_000,
            consumedProtein: 205,
            hasFood: true,
            mode: .gym,
            baseCalories: 2_000,
            baseProtein: 180,
            steps: 4_700
        )

        #expect(progress.stepBonus == 5_000)
        #expect(progress.effectiveSteps == 9_700)
        #expect(progress.stepWin)
    }

    @Test func uploadedWorkoutStepsCanTemporarilyCoverLateHealthSync() async throws {
        let progress = DayProgressEngine.progress(
            date: Date(),
            consumedCalories: 2_000,
            consumedProtein: 180,
            hasFood: true,
            mode: .cardio,
            baseCalories: 2_000,
            baseProtein: 180,
            steps: 2_000,
            uploadedSteps: 9_700
        )

        #expect(progress.countedSteps == 9_700)
        #expect(progress.effectiveSteps == 9_700)
        #expect(progress.stepWin)
    }

    @Test func healthStepsReplaceUploadedWorkoutStepsWhenHigher() async throws {
        let progress = DayProgressEngine.progress(
            date: Date(),
            consumedCalories: 2_000,
            consumedProtein: 180,
            hasFood: true,
            mode: .cardio,
            baseCalories: 2_000,
            baseProtein: 180,
            steps: 11_000,
            uploadedSteps: 9_700
        )

        #expect(progress.countedSteps == 11_000)
        #expect(progress.effectiveSteps == 11_000)
    }

    @Test func currentStreakSkipsIncompleteToday() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))

        let days = [
            perfectProgress(on: twoDaysAgo),
            perfectProgress(on: yesterday),
            DayProgressEngine.progress(
                date: today,
                consumedCalories: 0,
                consumedProtein: 0,
                hasFood: false,
                mode: .chill,
                baseCalories: 2_000,
                baseProtein: 180,
                steps: 0
            )
        ]

        #expect(DayProgressEngine.currentPerfectStreak(in: days, now: today, calendar: calendar) == 2)
    }

    @Test func achievementEngineBuildsUnlockableRewards() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let last30Stats = try (0..<30).map { index in
            let daysBack = 29 - index
            let date = try #require(calendar.date(byAdding: .day, value: -daysBack, to: today))
            return perfectProgress(on: date)
        }
        let recentSevenStats = Array(last30Stats.suffix(7))
        let achievements = AchievementEngine.achievements(
            last30Stats: last30Stats,
            recentSevenDayStats: recentSevenStats,
            now: today,
            calendar: calendar
        )

        let monthlyCrown = try #require(achievements.first { $0.title == "Monthly Crown" })
        let proteinStatue = try #require(achievements.first { $0.title == "Protein Statue" })
        let deficitMedal = try #require(achievements.first { $0.title == "Deficit Medal" })

        #expect(monthlyCrown.isUnlocked)
        #expect(proteinStatue.isUnlocked)
        #expect(deficitMedal.isUnlocked)
        #expect(monthlyCrown.current == 30)
    }

    @Test func achievementEngineTracksStepVaultFromEffectiveSteps() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let recentSevenStats = try (0..<7).map { index in
            let date = try #require(calendar.date(byAdding: .day, value: -index, to: today))
            return DayProgressEngine.progress(
                date: date,
                consumedCalories: 2_000,
                consumedProtein: 205,
                hasFood: true,
                mode: .gym,
                baseCalories: 2_000,
                baseProtein: 180,
                steps: 5_000
            )
        }
        let achievements = AchievementEngine.achievements(
            last30Stats: recentSevenStats,
            recentSevenDayStats: recentSevenStats,
            now: today,
            calendar: calendar
        )
        let stepVault = try #require(achievements.first { $0.title == "70k Step Vault" })

        #expect(stepVault.current == 70_000)
        #expect(stepVault.isUnlocked)
    }

    @Test func achievementEngineUsesCurrentStreakForProgress() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))

        let last30Stats = try (0..<30).map { index in
            let daysBack = 29 - index
            let date = try #require(calendar.date(byAdding: .day, value: -daysBack, to: today))

            if daysBack >= 9 && daysBack <= 15 {
                return perfectProgress(on: date)
            }

            if daysBack == 1 || daysBack == 2 {
                return perfectProgress(on: date)
            }

            return DayProgressEngine.progress(
                date: date,
                consumedCalories: 2_400,
                consumedProtein: 120,
                hasFood: true,
                mode: .chill,
                baseCalories: 2_000,
                baseProtein: 180,
                steps: 4_000
            )
        }

        let recentSevenStats = Array(last30Stats.suffix(7))
        let achievements = AchievementEngine.achievements(
            last30Stats: last30Stats,
            recentSevenDayStats: recentSevenStats,
            now: today,
            calendar: calendar
        )

        let weeklyFlame = try #require(achievements.first { $0.title == "7-Day Flame" })

        #expect(weeklyFlame.current == 2)
        #expect(!weeklyFlame.isUnlocked)
    }

    @Test func achievementEngineBuildsChaosBadgesFromRealBehavior() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        var foodEntries: [FoodEntry] = []

        let last30Stats = try (0..<30).map { index in
            let daysBack = 29 - index
            let date = try #require(calendar.date(byAdding: .day, value: -daysBack, to: today))

            if [0, 2, 4, 6, 8, 10, 12, 14, 16, 18].contains(daysBack) {
                foodEntries.append(dummyFood(name: "Chicken Breast Bowl", date: date))
            }

            if daysBack == 2 {
                return DayProgressEngine.progress(
                    date: date,
                    consumedCalories: 2_300,
                    consumedProtein: 150,
                    hasFood: true,
                    mode: .cardio,
                    baseCalories: 2_000,
                    baseProtein: 180,
                    steps: 8_000
                )
            }

            if daysBack == 1 {
                return DayProgressEngine.progress(
                    date: date,
                    consumedCalories: 2_000,
                    consumedProtein: 190,
                    hasFood: true,
                    mode: .gym,
                    baseCalories: 2_000,
                    baseProtein: 180,
                    steps: 10_000
                )
            }

            if daysBack == 3 {
                return DayProgressEngine.progress(
                    date: date,
                    consumedCalories: 2_000,
                    consumedProtein: 190,
                    hasFood: true,
                    mode: .gym,
                    baseCalories: 2_000,
                    baseProtein: 180,
                    steps: 10_000
                )
            }

            return DayProgressEngine.progress(
                date: date,
                consumedCalories: 1_900,
                consumedProtein: 190,
                hasFood: daysBack <= 14,
                mode: daysBack == 0 ? .gym : .chill,
                baseCalories: 2_000,
                baseProtein: 180,
                steps: daysBack == 0 ? 10_000 : 4_000
            )
        }

        let recentSevenStats = Array(last30Stats.suffix(7))
        let collection = AchievementEngine.achievementCollection(
            last30Stats: last30Stats,
            recentSevenDayStats: recentSevenStats,
            foodEntries: foodEntries,
            now: today,
            calendar: calendar
        )

        let chickenInvestor = try #require(collection.chaos.first { $0.title == "Chicken Breast Investor" })
        let gymRatLite = try #require(collection.chaos.first { $0.title == "Gym Rat Lite" })
        let backOnTrack = try #require(collection.chaos.first { $0.title == "Back on Track, Baby" })
        let fridgeBadge = try #require(collection.chaos.first { $0.title == "Didn’t Eat the Whole Fridge" })

        #expect(chickenInvestor.current == 10)
        #expect(chickenInvestor.isUnlocked)
        #expect(gymRatLite.current == 3)
        #expect(gymRatLite.isUnlocked)
        #expect(backOnTrack.current == 1)
        #expect(backOnTrack.isUnlocked)
        #expect(fridgeBadge.current == 0)
        #expect(collection.orderedChaos.first?.isUnlocked == true)
    }

    @Test func homePerfectStreakCapsAtWeeklyTarget() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 21)))
        let days = try (0..<10).map { index in
            let date = try #require(calendar.date(byAdding: .day, value: -index, to: today))
            return perfectProgress(on: date)
        }

        #expect(AchievementEngine.homePerfectStreak(in: days, now: today, calendar: calendar) == 7)
    }

    @Test func aiResultImageResolverUsesDeclaredSourcePhoto() async throws {
        let firstImage = UIImage()
        let secondImage = UIImage()
        let fallbackImage = UIImage()
        let item = ProcessingItem(images: [firstImage, secondImage])
        let result = foodResult(sourcePhotoNumber: 2)

        let resolved = AIResultImageResolver.image(
            for: item,
            result: result,
            resultIndex: 0,
            fallbackImage: fallbackImage,
            emojiImage: { _ in fallbackImage }
        )

        #expect(resolved === secondImage)
    }

    @Test func aiResultImageResolverFallsBackToResultIndex() async throws {
        let firstImage = UIImage()
        let secondImage = UIImage()
        let fallbackImage = UIImage()
        let item = ProcessingItem(images: [firstImage, secondImage])

        let resolved = AIResultImageResolver.image(
            for: item,
            result: foodResult(sourcePhotoNumber: nil),
            resultIndex: 1,
            fallbackImage: fallbackImage,
            emojiImage: { _ in fallbackImage }
        )

        #expect(resolved === secondImage)
    }

    @Test func aiProcessingEngineHidesCancelledImplementationDetail() async throws {
        let message = AIProcessingEngine.friendlyError(
            "AI Error: cancelled",
            fallback: "Analysis failed."
        )

        #expect(message == "The AI request was interrupted. Please try again.")
    }

    @Test func aiProcessingEngineUsesFallbackForEmptyErrors() async throws {
        let message = AIProcessingEngine.friendlyError(
            "   ",
            fallback: "Analysis failed."
        )

        #expect(message == "Analysis failed.")
    }

    private func foodResult(sourcePhotoNumber: Int?) -> FoodResult {
        FoodResult(
            food_name: "Protein",
            emoji: "🥤",
            source_photo_number: sourcePhotoNumber,
            calories: 100,
            protein: 20,
            ingredients_breakdown: "",
            ai_response_text: ""
        )
    }

    private func perfectProgress(on date: Date) -> DayProgress {
        DayProgressEngine.progress(
            date: date,
            consumedCalories: 2_000,
            consumedProtein: 180,
            hasFood: true,
            mode: .chill,
            baseCalories: 2_000,
            baseProtein: 180,
            steps: 10_000
        )
    }

    private func dummyFood(name: String, date: Date) -> FoodEntry {
        FoodEntry(
            image: UIImage(),
            name: name,
            calories: 200,
            protein: 30,
            ingredients: "Chicken, rice",
            date: date
        )
    }

    // MARK: - AI Response Decoding

    @Test func foodResultDecodesFlexibleNumbers() async throws {
        let json = """
        {"food_name":"Chicken","emoji":"🍗","calories":"350","protein":42,"ingredients_breakdown":"Chicken;200g;350;42","ai_response_text":"Grilled chicken breast"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(FoodResult.self, from: json)
        #expect(result.food_name == "Chicken")
        #expect(result.calories == 350)
        #expect(result.protein == 42)
        #expect(result.emoji == "🍗")
    }

    @Test func foodResultDecodesIntCaloriesAsDouble() async throws {
        let json = """
        {"food_name":"Rice","calories":200,"protein":5,"ingredients_breakdown":"","ai_response_text":""}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(FoodResult.self, from: json)
        #expect(result.calories == 200)
        #expect(result.protein == 5)
        #expect(result.emoji == nil)
        #expect(result.source_photo_number == nil)
    }

    @Test func foodResultDecodesMissingOptionalFields() async throws {
        let json = """
        {"food_name":"Salad","calories":120.5,"protein":"15.2","ingredients_breakdown":"Lettuce;100g;20;1\\nChicken;150g;100;14.2","ai_response_text":"A healthy salad"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(FoodResult.self, from: json)
        #expect(result.food_name == "Salad")
        #expect(abs(result.calories - 120.5) < 0.01)
        #expect(abs(result.protein - 15.2) < 0.01)
    }

    @Test func trainingResultDecodesFlexibleNumbers() async throws {
        let json = """
        {"activity_name":"Running","calories_burned":"450","steps":"6500","day_mode":"Cardio","duration":"45 min","ai_summary":"Good run!"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(TrainingResult.self, from: json)
        #expect(result.activity_name == "Running")
        #expect(result.calories_burned == 450)
        #expect(result.steps == 6500)
        #expect(result.day_mode == "Cardio")
    }

    @Test func trainingResultHandlesMissingOptionals() async throws {
        let json = """
        {"activity_name":"Yoga","calories_burned":120}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(TrainingResult.self, from: json)
        #expect(result.activity_name == "Yoga")
        #expect(result.steps == nil)
        #expect(result.day_mode == nil)
        #expect(result.duration == "")
        #expect(result.ai_summary == "")
    }

    @Test func dailySummaryResultDecodes() async throws {
        let json = """
        {"ai_summary":"Great job today! 💪 You hit your protein target."}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(DailySummaryResult.self, from: json)
        #expect(result.ai_summary.contains("Great job"))
    }

    @Test func recipeResultDecodesFlexibleNumbers() async throws {
        let json = """
        {"recipe_name":"Protein Bowl","cooking_instructions":"Mix chicken with rice","estimated_calories":"550","estimated_protein":"45"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(RecipeResult.self, from: json)
        #expect(result.recipe_name == "Protein Bowl")
        #expect(result.estimated_calories == 550)
        #expect(result.estimated_protein == 45)
    }

    @Test func bodyMetricScanResultHandlesPartialData() async throws {
        let json = """
        {"weight_kg":"81.4","body_fat_percent":null,"ai_summary":"Weight recorded"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(BodyMetricScanResult.self, from: json)
        #expect(result.weight_kg == 81.4)
        #expect(result.body_fat_percent == nil)
        #expect(result.muscle_percent == nil)
        #expect(result.ai_summary == "Weight recorded")
    }

    @Test func bodyMetricScanResultDecodesAllFields() async throws {
        let json = """
        {"measured_date":"2026-04-28","weight_kg":80.5,"body_fat_percent":"15.2","muscle_percent":42,"water_percent":"55.1","visceral_fat":8,"metabolic_age":"25","ai_summary":"Good metrics"}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(BodyMetricScanResult.self, from: json)
        #expect(result.measured_date == "2026-04-28")
        #expect(result.weight_kg == 80.5)
        #expect(abs((result.body_fat_percent ?? 0) - 15.2) < 0.01)
        #expect(result.muscle_percent == 42)
        #expect(abs((result.water_percent ?? 0) - 55.1) < 0.01)
        #expect(result.visceral_fat == 8)
        #expect(result.metabolic_age == 25)
    }

    @Test func foodItemsResultDecodesArray() async throws {
        let json = """
        {"items":[{"food_name":"Apple","calories":95,"protein":0,"ingredients_breakdown":"","ai_response_text":""},{"food_name":"Banana","calories":105,"protein":1,"ingredients_breakdown":"","ai_response_text":""}]}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(FoodItemsResult.self, from: json)
        #expect(result.items.count == 2)
        #expect(result.items[0].food_name == "Apple")
        #expect(result.items[1].food_name == "Banana")
    }

    @Test func recipeListResultDecodesMultipleRecipes() async throws {
        let json = """
        {"recipes":[{"recipe_name":"Bowl A","cooking_instructions":"Step 1","estimated_calories":400,"estimated_protein":35},{"recipe_name":"Bowl B","cooking_instructions":"Step 2","estimated_calories":500,"estimated_protein":40}]}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(RecipeListResult.self, from: json)
        #expect(result.recipes.count == 2)
        #expect(result.recipes[0].recipe_name == "Bowl A")
    }

    @Test func dailySummaryDecodesFromMarkdownWrappedJSON() async throws {
        let raw = "```json\n{\"ai_summary\": \"You did great!\"}\n```"
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let mdQuotes = "```"
        clean = clean.replacingOccurrences(of: mdQuotes + "json", with: "")
        clean = clean.replacingOccurrences(of: mdQuotes, with: "")

        let start = try #require(clean.firstIndex(of: "{"))
        let end = try #require(clean.lastIndex(of: "}"))
        let data = try #require(String(clean[start...end]).data(using: .utf8))

        let result = try JSONDecoder().decode(DailySummaryResult.self, from: data)
        #expect(result.ai_summary == "You did great!")
    }

    @Test func plainTextFallbackWrapsAsDailySummary() async throws {
        let plainText = "Hey! Looking good today 💪"
        let escaped = plainText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let wrapped = "{\"ai_summary\":\"\(escaped)\"}".data(using: .utf8)!

        let result = try JSONDecoder().decode(DailySummaryResult.self, from: wrapped)
        #expect(result.ai_summary == plainText)
    }

    @Test func plainTextFallbackHandlesQuotesAndNewlines() async throws {
        let plainText = "She said \"eat more protein\"\nand then left."
        let escaped = plainText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        let wrapped = "{\"ai_summary\":\"\(escaped)\"}".data(using: .utf8)!

        let result = try JSONDecoder().decode(DailySummaryResult.self, from: wrapped)
        #expect(result.ai_summary == plainText)
    }

    // MARK: - AI Review Models

    @Test func aiResultDestinationDiaryDoesNotUseFridgeQueue() async throws {
        let dest = AIResultDestination.diary(Date())
        #expect(!dest.usesFridgeQueue)
    }

    @Test func aiResultDestinationFridgeUsesFridgeQueue() async throws {
        #expect(AIResultDestination.fridge.usesFridgeQueue)
        #expect(AIResultDestination.receipt.usesFridgeQueue)
        #expect(AIResultDestination.meals.usesFridgeQueue)
    }

    @Test func aiResultDestinationActionTitleIncludesCount() async throws {
        #expect(AIResultDestination.diary(Date()).actionTitle(count: 3) == "Add 3 to Diary")
        #expect(AIResultDestination.fridge.actionTitle(count: 5) == "Save 5 to Fridge")
        #expect(AIResultDestination.receipt.actionTitle(count: 2) == "Save 2 to Fridge")
        #expect(AIResultDestination.meals.actionTitle(count: 4) == "Save 4 to Meals")
    }

    @Test func aiResultImageResolverUsesEmojiForTextPrompt() async throws {
        let fallback = UIImage()
        let emojiImg = UIImage()
        let item = ProcessingItem(images: [], textPrompt: "200g chicken and rice")

        let resolved = AIResultImageResolver.image(
            for: item,
            result: foodResult(sourcePhotoNumber: nil),
            resultIndex: 0,
            fallbackImage: fallback,
            emojiImage: { _ in emojiImg }
        )

        #expect(resolved === emojiImg)
    }

    @Test func aiResultImageResolverFallsBackToFallbackImage() async throws {
        let fallback = UIImage()
        let item = ProcessingItem(images: [])

        let resolved = AIResultImageResolver.image(
            for: item,
            result: foodResult(sourcePhotoNumber: 5),
            resultIndex: 99,
            fallbackImage: fallback,
            emojiImage: { _ in UIImage() }
        )

        #expect(resolved === fallback)
    }

    @Test func aiProcessingEngineFriendlyErrorPassesThroughRealErrors() async throws {
        let message = AIProcessingEngine.friendlyError(
            "Rate limit exceeded",
            fallback: "Analysis failed."
        )
        #expect(message == "Rate limit exceeded")
    }

    @Test func aiProcessingEngineFriendlyErrorHandlesNil() async throws {
        let message = AIProcessingEngine.friendlyError(nil, fallback: "Analysis failed.")
        #expect(message == "Analysis failed.")
    }
}
