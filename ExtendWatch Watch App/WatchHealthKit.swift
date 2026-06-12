////
////  WatchHealthKit.swift
////  ExtendWatch
////
////  Queries HealthKit for today's step count and walking/running distance
////  directly on the Watch. Used by both the live WatchStepsView and the
////  steps complication timeline provider.
////

import Foundation
import HealthKit

/// Lightweight HealthKit helper for the Watch app.
/// Queries step count and walking/running distance for a given day.
@MainActor
final class WatchHealthKit {

    static let shared = WatchHealthKit()

    private let store = HKHealthStore()

    private let stepType     = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)

    // MARK: - Authorization

    /// Requests HealthKit read access. Call once on app launch.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types: Set<HKObjectType> = [stepType, distanceType]
        try? await store.requestAuthorization(toShare: [], read: types)
    }

    // MARK: - Queries

    /// Returns today's cumulative step count (0 if unavailable).
    func todaySteps() async -> Double {
        await querySum(type: stepType, unit: .count(), for: Date())
    }

    /// Returns today's walking/running distance in metres (0 if unavailable).
    func todayDistanceMetres() async -> Double {
        await querySum(type: distanceType, unit: .meter(), for: Date())
    }

    /// Returns today's walking/running distance in kilometres.
    func todayDistanceKm() async -> Double {
        await todayDistanceMetres() / 1000.0
    }

    /// Returns today's walking/running distance in miles.
    func todayDistanceMiles() async -> Double {
        await todayDistanceMetres() / 1609.344
    }

    // MARK: - Private helpers

    private func querySum(type: HKQuantityType, unit: HKUnit, for date: Date) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
