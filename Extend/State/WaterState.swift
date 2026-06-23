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
private let authRequestedKey = "water_hk_auth_requested"

@Observable
public final class WaterState {
    public static let shared = WaterState()

    // MARK: - Stored data

    public var logs: [WaterLog] = []

    /// Set to true by a deep link (e.g. from the widget "Other" button) to open the custom entry sheet.
    public var pendingOpenAddLog: Bool = false

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
        importPendingWidgetLogs()
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
        CloudKitSyncEngine.shared.push(.waterLogs)
    }

    private func loadLogs() {
        guard let data = defaults.data(forKey: logsKey),
              let decoded = try? JSONDecoder().decode([WaterLog].self, from: data) else { return }
        logs = decoded
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    public func reloadFromDefaults() {
        loadLogs()
        dailyGoalOz = defaults.object(forKey: goalKey) as? Double ?? 64.0
        unit = WaterUnit(rawValue: defaults.string(forKey: unitKey) ?? "") ?? .oz
        persistWidgetData()
    }

    /// Write today's totals + 7-day history to shared UserDefaults so the widget/watch can read them.
    public func persistWidgetData() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        defaults.set(todayOz, forKey: "water_today_oz")
        // Stamp the day so readers can detect a stale value after midnight rollover.
        defaults.set(today, forKey: "water_today_date")
        defaults.set(dailyGoalOz, forKey: "water_goal_oz")
        defaults.set(unit.rawValue, forKey: "water_unit")
        var weekTotals: [[String: Double]] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            if let day = cal.date(byAdding: .day, value: -daysAgo, to: today) {
                weekTotals.append(["oz": totalOzForDate(day)])
            } else {
                weekTotals.append(["oz": 0])
            }
        }
        if let data = try? JSONEncoder().encode(weekTotals) {
            defaults.set(data, forKey: "water_week_totals")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "ExtendWidget.Water")
        WatchConnectivityReceiver.shared.sendWaterUpdate(todayOz: todayOz, goalOz: dailyGoalOz)
    }

    /// Imports any water logs queued by the widget (e.g. quick-add buttons) into the main log store.
    public func importPendingWidgetLogs() {
        let key = "water_pending_logs"
        struct PendingLog: Codable { let oz: Double; let date: Date }
        guard let data = defaults.data(forKey: key),
              let pending = try? JSONDecoder().decode([PendingLog].self, from: data),
              !pending.isEmpty else { return }
        for p in pending {
            logs.append(WaterLog(amountOz: p.oz, loggedAt: p.date))
        }
        defaults.removeObject(forKey: key)
        saveLogs()
        persistWidgetData()
    }

    // MARK: - Reset

    public func resetAll() {
        logs = []
        // Match fresh-install defaults: HK sync off, auth flag cleared so the
        // next opt-in re-prompts. Without this, "Reset App" left the toggles
        // wherever the user last had them, surprising users who expected a
        // clean slate.
        exportToHealthKit = false
        importFromHealthKit = false
        lastHealthKitSync = nil
        defaults.removeObject(forKey: authRequestedKey)
        saveLogs()
        persistWidgetData()
    }

    // MARK: - HealthKit Export

    private let hkStore = HKHealthStore()

    /// Requests HealthKit authorization for water once per install — both read and
    /// write are bundled into a single prompt rather than asking for write at log
    /// time and read at sync time. The persisted flag prevents the prompt from
    /// re-appearing on every operation; the system's own bookkeeping suppresses
    /// the picker after the first response, but in practice the previous
    /// per-operation calls (separate write- and read-only requests on a fresh
    /// HKHealthStore) kept re-prompting users.
    private func ensureWaterAuthorization() async {
        guard !defaults.bool(forKey: authRequestedKey) else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let type = HKQuantityType(.dietaryWater)
        do {
            try await hkStore.requestAuthorization(toShare: [type], read: [type])
            defaults.set(true, forKey: authRequestedKey)
        } catch {
            // Don't latch the flag if the system errored out — retry next time
            // so the user gets a chance to grant access.
        }
    }

    private func exportLog(_ log: WaterLog) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        await ensureWaterAuthorization()
        let type = HKQuantityType(.dietaryWater)
        // Write the sample in fluid ounces directly so a later oz round-trip
        // is lossless — going through liters with a truncated constant rounded
        // 64 oz down to ~63.9999, which then displayed as 49 % instead of 50 %.
        let qty = HKQuantity(unit: .fluidOunceUS(), doubleValue: log.amountOz)
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
        await ensureWaterAuthorization()
        let type = HKQuantityType(.dietaryWater)

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
