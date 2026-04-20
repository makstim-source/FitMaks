import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    private init() {}

    func fetchSteps(for date: Date, completion: @escaping (Double) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            completion(0)
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: [stepType]) { success, _ in
            guard success else {
                completion(0)
                return
            }

            let start = Calendar.current.startOfDay(for: date)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                completion(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            }

            self.healthStore.execute(query)
        }
    }

    func fetchWeeklySteps(completion: @escaping ([String: Double]) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            completion([:])
            return
        }

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { _, results, _ in
            var stepsByDay: [String: Double] = [:]

            results?.enumerateStatistics(from: start, to: end) { stat, _ in
                stepsByDay[DateFormatter.yyyyMMdd.string(from: stat.startDate)] =
                    stat.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            }

            completion(stepsByDay)
        }

        healthStore.execute(query)
    }

    func fetchSteps(from startDate: Date, to endDate: Date, completion: @escaping ([String: Double]) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        else {
            completion([:])
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: [stepType]) { success, _ in
            guard success else {
                completion([:])
                return
            }

            let calendar = Calendar.current
            let start = calendar.startOfDay(for: startDate)
            let endStart = calendar.startOfDay(for: endDate)
            let end = calendar.date(byAdding: .day, value: 1, to: endStart) ?? endStart
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )

            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, results, _ in
                var stepsByDay: [String: Double] = [:]

                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    stepsByDay[DateFormatter.yyyyMMdd.string(from: stat.startDate)] =
                        stat.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                }

                completion(stepsByDay)
            }

            self.healthStore.execute(query)
        }
    }
}
