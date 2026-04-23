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

        #expect(targets.calorieBonus == 642)
        #expect(targets.calories == 2_642)
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

        #expect(targets.calorieBonus == 940)
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

}
