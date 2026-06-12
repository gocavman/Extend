////
////  WatchStepsProvider.swift
////  ExtendWatch
////
////  WidgetKit TimelineProvider for the Steps/Distance Ring complication.
////  Queries HealthKit for today's totals and caches the result in
////  App Group UserDefaults so complication refreshes are fast.
////

import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Entry

struct WatchStepsEntry: TimelineEntry {
    let date: Date
    let steps: Double
    let distanceKm: Double
    let settings: WatchStepsSettings
}

// MARK: - Provider

struct WatchStepsProvider: TimelineProvider {

    private let store = HKHealthStore()
    private let stepsKey    = "watch_cached_steps"
    private let distanceKey = "watch_cached_distance_km"
    private let appGroupID  = "group.com.cavanmannenbach.extend"

    func placeholder(in context: Context) -> WatchStepsEntry {
        WatchStepsEntry(date: Date(), steps: 7342, distanceKm: 5.8, settings: .default)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchStepsEntry) -> Void) {
        let settings = readWatchStepsSettings()
        let cached = cachedValues()
        completion(WatchStepsEntry(date: Date(), steps: cached.steps, distanceKm: cached.km, settings: settings))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchStepsEntry>) -> Void) {
        let settings = readWatchStepsSettings()
        Task {
            let steps = await querySteps()
            let km    = await queryDistanceKm()
            cacheValues(steps: steps, km: km)

            let now   = Date()
            let entry = WatchStepsEntry(date: now, steps: steps, distanceKm: km, settings: settings)
            // Refresh every 15 minutes (WidgetKit budget allows this on Watch)
            let next  = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    // MARK: - HealthKit

    private func querySteps() async -> Double {
        await querySum(type: HKQuantityType(.stepCount), unit: .count())
    }

    private func queryDistanceKm() async -> Double {
        let metres = await querySum(type: HKQuantityType(.distanceWalkingRunning), unit: .meter())
        return metres / 1000.0
    }

    private func querySum(type: HKQuantityType, unit: HKUnit) async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let pred  = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, s, _ in
                cont.resume(returning: s?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    // MARK: - Cache

    private func cachedValues() -> (steps: Double, km: Double) {
        let d = UserDefaults(suiteName: appGroupID) ?? .standard
        return (d.double(forKey: stepsKey), d.double(forKey: distanceKey))
    }

    private func cacheValues(steps: Double, km: Double) {
        let d = UserDefaults(suiteName: appGroupID) ?? .standard
        d.set(steps, forKey: stepsKey)
        d.set(km,    forKey: distanceKey)
    }
}
