////
////  WatchWaterProvider.swift
////  ExtendWatch
////
////  WidgetKit TimelineProvider for the Water complication.
////  Reads today's water intake from HealthKit and caches the result in App Group UserDefaults.
////

import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Entry

struct WatchWaterEntry: TimelineEntry {
    let date: Date
    let todayOz: Double
    let goalOz: Double
    let unit: String
}

// MARK: - Provider

struct WatchWaterProvider: TimelineProvider {

    private let store = HKHealthStore()
    private let cachedOzKey = "watch_cached_water_oz"
    private let appGroupID  = "group.com.cavanmannenbach.extend"

    func placeholder(in context: Context) -> WatchWaterEntry {
        WatchWaterEntry(date: Date(), todayOz: 40, goalOz: 64, unit: "oz")
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWaterEntry) -> Void) {
        completion(makeEntryFromCache())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWaterEntry>) -> Void) {
        Task {
            let oz = await queryWaterOz()
            cacheOz(oz)

            let entry = WatchWaterEntry(
                date: Date(),
                todayOz: oz,
                goalOz: readWaterGoalOz(),
                unit: readWaterUnit()
            )
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    // MARK: - HealthKit

    private func queryWaterOz() async -> Double {
        guard HKHealthStore.isHealthDataAvailable() else { return readWaterTodayOz() }
        let type = HKQuantityType(.dietaryWater)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, s, _ in
                let litres = s?.sumQuantity()?.doubleValue(for: .liter()) ?? 0
                // Convert litres → oz: 1 L = 33.814 oz
                let oz = litres > 0 ? litres * 33.814 : readWaterTodayOz()
                cont.resume(returning: oz)
            }
            store.execute(q)
        }
    }

    // MARK: - Cache

    private func makeEntryFromCache() -> WatchWaterEntry {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let oz = defaults.double(forKey: cachedOzKey)
        return WatchWaterEntry(
            date: Date(),
            todayOz: oz > 0 ? oz : readWaterTodayOz(),
            goalOz: readWaterGoalOz(),
            unit: readWaterUnit()
        )
    }

    private func cacheOz(_ oz: Double) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(oz, forKey: cachedOzKey)
    }
}
