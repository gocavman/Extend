////
////  WaterState.swift
////  Extend
////
////  Observable singleton managing water intake logs, goals, and Apple Health sync.
////

import Foundation
import HealthKit
import Observation
import WidgetKit

private let appGroupID  = "group.com.cavanmannenbach.extend"
private let logsKey     = "water_logs"
private let goalKey     = "water_daily_goal_oz"
private let unitKey     = "water_unit"
private let exportHKKey = "water_export_healthkit"
private let importHKKey = "water_import_healthkit"
private let lastSyncKey = "water_last_hk_sync"

@Observable
public final class WaterState {
    public static let shared = WaterState()

    // MARK: - Stored data

    public var logs: [WaterLog] = []

    // MARK: - Preferences (persisted via UserDefaults)

    public var dailyGoalOz: Double {
        didSet {
            defaults.set(dailyGoalOz, forKey: goalKey)
            persistWidgetData()
        }
    }

    public var unit: WaterUnit {
        didSet {
            defaults.set(unit.rawValue, forKey: unitKey)
        }
    }

    public var exportToHealthKit: Bool {
        didSet { defaults.set(exportToHealthKit, forKey: exportHKKey) }
    }

    public var importFromHealthKit: Bool {
        didSet { defaults.set(importFromHealthKit, forKey: importHKKey) }
    }

    public var lastHealthKitSync: Date? {
        didSet {
            if let d = lastHealthKitSync { defaults.set(d, forKey: lastSyncKey) }
            else { defaults.removeObject(forKey: lastSyncKey) }
        }
    }

    private let defaults: UserDefaults

    // MARK: - Init

    private init() {
        let ud = UserDefaults(suiteName: appGroupID) ?? .standard
        self.defaults = ud
        self.dailyGoalOz  = ud.object(forKey: goalKey) as? Double ?? 64.0
        self.unit         = WaterUnit(rawValue: ud.string(forKey: unitKey) ?? "") ?? .oz
        self.exportToHealthKit  = ud.object(forKey: exportHKKey) as? Bool ?? false
        self.importFromHealthKit = ud.object(forKey: importHKKey) as? Bool ?? false
        self.lastHealthKitSync = ud.object(forKey: lastSyncKey) as? Date
        loadLogs()
    }

    // MARK: - CRUD

    public func addLog(_ log: WaterLog) {
        logs.append(log)
        saveLogs()
        persistWidgetData()
        if exportToHealthKit { Task { await exportLog(log) } }
    }

    public func addOz(_ oz: Double) {
        addLog(WaterLog(amountOz: oz))
    }

    public func deleteLog(id: UUID) {
        logs.removeAll { $0.id == id }
        saveLogs()
        persistWidgetData()
    }

    public func updateLog(_ log: WaterLog) {
        if let idx = logs.firstIndex(where: { $0.id == log.id }) {
            logs[idx] = log
            saveLogs()
            persistWidgetData()
        }
    }

    // MARK: - Queries

    public var sortedLogs: [WaterLog] {
        logs.sorted { $0.loggedAt > $1.loggedAt }
    }

    public func logsForDate(_ date: Date) -> [WaterLog] {
        let cal = Calendar.current
        return logs.filter { cal.isDate($0.loggedAt, inSameDayAs: date) }
    }

    public func totalOzForDate(_ date: Date) -> Double {
        logsForDate(date).reduce(0) { $0 + $1.amountOz }
    }

    public var todayOz: Double { totalOzForDate(Date()) }

    public var todayFraction: Double {
        min(todayOz / max(dailyGoalOz, 1), 1.0)
    }

    /// Returns (date, totalOz) for the past `days` calendar days, oldest first.
    public func dailyTotals(days: Int) -> [(date: Date, oz: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: date, oz: totalOzForDate(date))
        }
    }

    /// Consecutive days (ending today) where the goal was met.
    public var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = cal.startOfDay(for: Date())
        while true {
            let total = totalOzForDate(date)
            if total >= dailyGoalOz {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Longest ever goal streak.
    public var longestStreak: Int {
        guard !logs.isEmpty else { return 0 }
        let cal = Calendar.current
        // Collect all unique days that have logs, sorted ascending
        let days = Set(logs.map { cal.startOfDay(for: $0.loggedAt) }).sorted()
        guard let first = days.first, let last = days.last else { return 0 }
        var best = 0
        var current = 0
        var cursor = first
        while cursor <= last {
            if totalOzForDate(cursor) >= dailyGoalOz {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return best
    }

    // MARK: - Persistence

    private func saveLogs() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        defaults.set(data, forKey: logsKey)
    }

    private func loadLogs() {
        guard let data = defaults.data(forKey: logsKey),
              let decoded = try? JSONDecoder().decode([WaterLog].self, from: data) else { return }
        logs = decoded
    }

    /// Write today's totals to shared UserDefaults so the widget/watch can read them.
    public func persistWidgetData() {
        defaults.set(todayOz, forKey: "water_today_oz")
        defaults.set(dailyGoalOz, forKey: "water_goal_oz")
        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWidget.Water")
    }

    // MARK: - Reset

    public func resetAll() {
        logs = []
        saveLogs()
        persistWidgetData()
    }

    // MARK: - HealthKit Export

    private let hkStore = HKHealthStore()

    private func exportLog(_ log: WaterLog) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let type = HKQuantityType(.dietaryWater)
        // Request write permission
        guard (try? await hkStore.requestAuthorization(toShare: [type], read: [])) != nil else { return }
        let litres = log.amountOz * 0.0295735
        let qty = HKQuantity(unit: .liter(), doubleValue: litres)
        let sample = HKQuantitySample(type: type, quantity: qty, start: log.loggedAt, end: log.loggedAt)
        try? await hkStore.save(sample)
        // Tag the log with the HK UUID
        var tagged = log
        tagged.healthKitUUID = sample.uuid
        updateLog(tagged)
    }

    // MARK: - HealthKit Import

    @MainActor
    public func syncFromHealthKit() async {
        guard importFromHealthKit, HKHealthStore.isHealthDataAvailable() else { return }
        let type = HKQuantityType(.dietaryWater)
        guard (try? await hkStore.requestAuthorization(toShare: [], read: [type])) != nil else { return }

        let cal = Calendar.current
        // Import last 30 days
        let start = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: Date())) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let existingHKIDs = Set(logs.compactMap { $0.healthKitUUID })

        let samples: [HKQuantitySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            hkStore.execute(q)
        }

        var newLogs: [WaterLog] = []
        for sample in samples {
            guard !existingHKIDs.contains(sample.uuid) else { continue }
            let oz = sample.quantity.doubleValue(for: .fluidOunceUS())
            newLogs.append(WaterLog(
                amountOz: oz,
                loggedAt: sample.startDate,
                healthKitUUID: sample.uuid
            ))
        }

        if !newLogs.isEmpty {
            logs.append(contentsOf: newLogs)
            saveLogs()
            persistWidgetData()
        }
        lastHealthKitSync = Date()
    }
}
