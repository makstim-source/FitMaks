import Foundation
import HealthKit

struct HealthBodyMetricSnapshot {
    let date: Date
    let weightKg: Double
    let bodyFatPercent: Double?
    let musclePercent: Double?
}

private struct HealthQuantitySnapshot {
    let date: Date
    let value: Double
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var authorizationRequested = false

    private var stepCountType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .stepCount)
    }

    private var bodyMassType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }

    private var bodyFatType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
    }

    private var leanBodyMassType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
    }

    private var defaultReadTypes: Set<HKObjectType> {
        [stepCountType, bodyMassType, bodyFatType, leanBodyMassType].compactMap { $0 }.reduce(into: Set<HKObjectType>()) { result, type in
            result.insert(type)
        }
    }

    private init() {}

    func fetchSteps(for date: Date, completion: @escaping (Double) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = stepCountType
        else {
            completion(0)
            return
        }

        ensureAuthorization { success in
            guard success else {
                DispatchQueue.main.async { completion(0) }
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
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                DispatchQueue.main.async { completion(steps) }
            }

            self.healthStore.execute(query)
        }
    }

    func fetchWeeklySteps(completion: @escaping ([String: Double]) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = stepCountType
        else {
            completion([:])
            return
        }

        ensureAuthorization { success in
            guard success else {
                DispatchQueue.main.async { completion([:]) }
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

                DispatchQueue.main.async { completion(stepsByDay) }
            }

            self.healthStore.execute(query)
        }
    }

    func fetchSteps(from startDate: Date, to endDate: Date, completion: @escaping ([String: Double]) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let stepType = stepCountType
        else {
            completion([:])
            return
        }

        ensureAuthorization { success in
            guard success else {
                DispatchQueue.main.async { completion([:]) }
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

                DispatchQueue.main.async { completion(stepsByDay) }
            }

            self.healthStore.execute(query)
        }
    }

    func fetchLatestBodyMetrics(completion: @escaping (HealthBodyMetricSnapshot?) -> Void) {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .year, value: -1, to: end) ?? end

        fetchBodyMetrics(from: start, to: end) { snapshots in
            completion(snapshots.last)
        }
    }

    func fetchBodyMetrics(from startDate: Date, to endDate: Date, completion: @escaping ([HealthBodyMetricSnapshot]) -> Void) {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let bodyMassType = bodyMassType
        else {
            completion([])
            return
        }

        ensureAuthorization { success in
            guard success else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let bodyFatType = self.bodyFatType
            let leanBodyMassType = self.leanBodyMassType
            let group = DispatchGroup()
            var weightSamples: [HealthQuantitySnapshot] = []
            var bodyFatByDay: [String: HealthQuantitySnapshot] = [:]
            var leanMassByDay: [String: HealthQuantitySnapshot] = [:]

            group.enter()
            self.fetchQuantitySamples(for: bodyMassType, unit: .gramUnit(with: .kilo), from: startDate, to: endDate) { samples in
                weightSamples = samples
                group.leave()
            }

            if let bodyFatType {
                group.enter()
                self.fetchQuantitySamples(for: bodyFatType, unit: .percent(), from: startDate, to: endDate) { samples in
                    bodyFatByDay = self.latestSamplesByDay(samples)
                    group.leave()
                }
            }

            if let leanBodyMassType {
                group.enter()
                self.fetchQuantitySamples(for: leanBodyMassType, unit: .gramUnit(with: .kilo), from: startDate, to: endDate) { samples in
                    leanMassByDay = self.latestSamplesByDay(samples)
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let latestWeightByDay = self.latestSamplesByDay(weightSamples)
                let snapshots = latestWeightByDay.values
                    .sorted { $0.date < $1.date }
                    .map { weightSample in
                        let dayID = DateFormatter.yyyyMMdd.string(from: weightSample.date)
                        let bodyFatPercent = bodyFatByDay[dayID].map { $0.value * 100 }
                        let musclePercent = leanMassByDay[dayID].flatMap { leanSample -> Double? in
                            guard weightSample.value > 0 else {
                                return nil
                            }

                            return (leanSample.value / weightSample.value) * 100
                        }

                        return HealthBodyMetricSnapshot(
                            date: weightSample.date,
                            weightKg: weightSample.value,
                            bodyFatPercent: bodyFatPercent,
                            musclePercent: musclePercent
                        )
                    }

                completion(snapshots)
            }
        }
    }

    private func ensureAuthorization(completion: @escaping (Bool) -> Void) {
        if authorizationRequested {
            completion(true)
            return
        }

        let readTypes = defaultReadTypes
        guard HKHealthStore.isHealthDataAvailable(), !readTypes.isEmpty else {
            completion(false)
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, _ in
            if success { self?.authorizationRequested = true }
            completion(success)
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

    private func fetchQuantitySamples(
        for type: HKQuantityType,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date,
        completion: @escaping ([HealthQuantitySnapshot]) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            let snapshots = (samples as? [HKQuantitySample])?.map {
                HealthQuantitySnapshot(date: $0.endDate, value: $0.quantity.doubleValue(for: unit))
            } ?? []

            DispatchQueue.main.async {
                completion(snapshots)
            }
        }

        healthStore.execute(query)
    }

    private func latestSamplesByDay(_ samples: [HealthQuantitySnapshot]) -> [String: HealthQuantitySnapshot] {
        samples.reduce(into: [:]) { result, sample in
            let dayID = DateFormatter.yyyyMMdd.string(from: sample.date)

            if let existing = result[dayID], existing.date > sample.date {
                return
            }

            result[dayID] = sample
        }
    }
}
