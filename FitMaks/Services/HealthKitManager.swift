import Foundation
import HealthKit

struct HealthBodyMetricSnapshot {
    let date: Date
    let weightKg: Double
    let bodyFatPercent: Double?
    let musclePercent: Double?
}

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

    func fetchLatestBodyMetrics(completion: @escaping (HealthBodyMetricSnapshot?) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        else {
            completion(nil)
            return
        }

        var readTypes: Set<HKObjectType> = [bodyMassType]

        if let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            readTypes.insert(bodyFatType)
        }

        if let leanBodyMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            readTypes.insert(leanBodyMassType)
        }

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, _ in
            guard success else {
                completion(nil)
                return
            }

            self.fetchLatestQuantity(for: bodyMassType, unit: .gramUnit(with: .kilo)) { weightSample in
                guard let weightSample else {
                    completion(nil)
                    return
                }

                let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
                let leanBodyMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
                let group = DispatchGroup()
                var bodyFatPercent: Double?
                var musclePercent: Double?

                if let bodyFatType {
                    group.enter()
                    self.fetchLatestQuantity(for: bodyFatType, unit: .percent()) { sample in
                        if let sample {
                            bodyFatPercent = sample.value * 100
                        }
                        group.leave()
                    }
                }

                if let leanBodyMassType {
                    group.enter()
                    self.fetchLatestQuantity(for: leanBodyMassType, unit: .gramUnit(with: .kilo)) { sample in
                        if let sample, weightSample.value > 0 {
                            musclePercent = (sample.value / weightSample.value) * 100
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    completion(
                        HealthBodyMetricSnapshot(
                            date: weightSample.date,
                            weightKg: weightSample.value,
                            bodyFatPercent: bodyFatPercent,
                            musclePercent: musclePercent
                        )
                    )
                }
            }
        }
    }

    private func fetchLatestQuantity(
        for type: HKQuantityType,
        unit: HKUnit,
        completion: @escaping ((date: Date, value: Double)?) -> Void
    ) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let value = sample.quantity.doubleValue(for: unit)
            DispatchQueue.main.async {
                completion((sample.endDate, value))
            }
        }

        healthStore.execute(query)
    }
}
