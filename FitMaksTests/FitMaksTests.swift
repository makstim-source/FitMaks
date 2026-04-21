//
//  FitMaksTests.swift
//  FitMaksTests
//
//  Created by Maksimilian Timofeev on 17.4.2026.
//

import Foundation
import Testing
@testable import FitMaks

struct FitMaksTests {

    @Test func proteinRecommendationUsesSustainableGoalMultipliers() async throws {
        #expect(NutritionCalculator.recommendedProtein(weight: 80, goal: "Maintain") == 144)
        #expect(NutritionCalculator.recommendedProtein(weight: 80, goal: "Lose Weight") == 160)
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
        #expect(abs(maintenance - 2_759) < 0.001)
        #expect(abs(NutritionCalculator.recommendedCalories(
            gender: "Male",
            age: 30,
            weight: 80,
            height: 180,
            activityLevel: "Moderate",
            goal: "Lose Weight"
        ) - 2_259) < 0.001)
        #expect(abs(NutritionCalculator.recommendedCalories(
            gender: "Male",
            age: 30,
            weight: 80,
            height: 180,
            activityLevel: "Moderate",
            goal: "Build Muscle"
        ) - 3_259) < 0.001)
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
        let padelTargets = DayProgressEngine.targets(
            baseCalories: 2_000,
            baseProtein: 180,
            mode: .padel
        )

        let gymTargets = DayProgressEngine.targets(
            baseCalories: 2_000,
            baseProtein: 180,
            mode: .gym
        )

        #expect(padelTargets.calories == 2_500)
        #expect(padelTargets.protein == 195)
        #expect(padelTargets.stepBonus == 0)
        #expect(gymTargets.calories == 2_300)
        #expect(gymTargets.protein == 205)
        #expect(gymTargets.stepBonus == 5_000)
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
