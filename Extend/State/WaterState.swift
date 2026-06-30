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
private let deletedHKUUIDsKey = "deleted_hk_water_uuids"

@Observable
public final class WaterState {
    public static let shared = WaterState()

    // MARK: - Stored data

    public var logs: [WaterLog] = []

    /// HKQuantitySample UUIDs for water entries the user has explicitly deleted
    /// from the Water history. `syncFromHealthKit` unions this with current log
    /// UUIDs when deduping new HK samples, so a deleted-then-re-fetched water
    /// entry doesn't reappear just because Apple Health still has the sample.
    public private(set) var deletedHealthKitWaterUUIDs: Set<UUID> = []

    /// Set to true by a deep link (e.g. from the widget "Other" button) to open the custom entry sheet.
    public var pendingOpenAddLog: Bool = false

    // MARK: - Preferences (persisted via UserDefaults)

    public var dailyGoalOz: Double {
        didSet {
            guard dailyGoalOz != oldValue else { return }
            defaults.set(dailyGoalOz, forKey: goalKey)
            persistWidgetData()
            // Goal lives inside the WaterLogs CloudKit record alongside the
            // logs themselves, so we have to push it on change. Without this,
            // the next foreground pull (or any other forceSync) re-applies
            // the older server value and the user sees their new goal revert.
            CloudKitSyncEngine.shared.push(.waterLogs)
        }
    }

    public var unit: WaterUnit {
        didSet {
            guard unit != oldValue else { return }
            defaults.set(unit.rawValue, forKey: unitKey)
            // Same reasoning as dailyGoalOz — unit is part of the synced
            // WaterPayload, so a change has to be pushed to avoid revert.
            CloudKitSyncEngine.shared.push(.waterLogs)
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
        // Default-ON for fresh installs — granting Health permission at
        // launch then immediately bidirectionally syncs water without the
        // user needing to flip two Settings toggles. Stored prefs (true or
        // false) are honored for existing users.
        self.exportToHealthKit   = ud.object(forKey: exportHKKey) as? Bool ?? true
        self.importFromHealthKit = ud.object(forKey: importHKKey) as? Bool ?? true
        self.lastHealthKitSync = ud.object(forKey: lastSyncKey) as? Date
        loadLogs()
        loadDeletedHealthKitUUIDs()
        importPendingWidgetLogs()
        // Seed App Group widget keys immediately so the iPhone water widget
        // and the watch complication can render correct values without
        // waiting for the first mutation. Also stamps today's date so stale
        // pre-rollover totals are detected as such by readers.
        persistWidgetData()
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

    /// Delete a water log.
    /// If the log carries a `healthKitUUID`, the UUID is added to
    /// `deletedHealthKitWaterUUIDs` so `syncFromHealthKit` won't recreate the
    /// log on the next sync. When `alsoDeleteFromHealth` is true, the matching
    /// `dietaryWater` sample is also deleted from Apple Health (only possible
    /// for samples this app authored — other-app samples are silently left in
    /// Health and the tombstone alone prevents re-import).
    public func deleteLog(id: UUID, alsoDeleteFromHealth: Bool = false) {
        let hkUUID = logs.first(where: { $0.id == id })?.healthKitUUID
        logs.removeAll { $0.id == id }

        if let hkUUID {
            deletedHealthKitWaterUUIDs.insert(hkUUID)
            saveDeletedHealthKitUUIDs()

            if alsoDeleteFromHealth {
                Task { await HealthKitService.shared.deleteWaterSample(uuid: hkUUID) }
            }
        }

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

    /// Returns (weekStart, totalOz) for the weeks covering the past `days` days,
    /// oldest first. The earliest bucket is the week containing the start-of-range
    /// day; the most recent is the week containing today. Each `oz` is the sum
    /// of all logs within that week (including days before/after the requested
    /// range — buckets are whole weeks so the last bar is a partial-to-date sum).
    public func weeklyTotals(days: Int) -> [(date: Date, oz: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let rangeStart = cal.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) else { return [] }
        let firstWeekStart = cal.dateInterval(of: .weekOfYear, for: rangeStart)?.start ?? rangeStart
        let todayWeekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        var result: [(date: Date, oz: Double)] = []
        var weekStart = firstWeekStart
        while weekStart <= todayWeekStart {
            guard let nextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            let oz = logs
                .filter { $0.loggedAt >= weekStart && $0.loggedAt < nextWeek }
                .reduce(0.0) { $0 + $1.amountOz }
            result.append((date: weekStart, oz: oz))
            weekStart = nextWeek
        }
        return result
    }

    /// Returns (monthStart, totalOz) for the months covering the past `days`
    /// days, oldest first. Same partial-current-bucket semantics as
    /// `weeklyTotals`.
    public func monthlyTotals(days: Int) -> [(date: Date, oz: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let rangeStart = cal.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) else { return [] }
        let firstMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: rangeStart)) ?? rangeStart
        let todayMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
        var result: [(date: Date, oz: Double)] = []
        var monthStart = firstMonthStart
        while monthStart <= todayMonthStart {
            guard let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart) else { break }
            let oz = logs
                .filter { $0.loggedAt >= monthStart && $0.loggedAt < nextMonth }
                .reduce(0.0) { $0 + $1.amountOz }
            result.append((date: monthStart, oz: oz))
            monthStart = nextMonth
        }
        return result
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

    private func saveDeletedHealthKitUUIDs() {
        let encodable = deletedHealthKitWaterUUIDs.map { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(encodable) {
            defaults.set(encoded, forKey: deletedHKUUIDsKey)
        }
        CloudKitSyncEngine.shared.push(.deletedHealthKitWaterUUIDs)
    }

    private func loadDeletedHealthKitUUIDs() {
        guard let data = defaults.data(forKey: deletedHKUUIDsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return }
        deletedHealthKitWaterUUIDs = Set(decoded.compactMap { UUID(uuidString: $0) })
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    public func reloadDeletedHealthKitUUIDsFromDefaults() {
        loadDeletedHealthKitUUIDs()
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
        deletedHealthKitWaterUUIDs = []
        saveDeletedHealthKitUUIDs()
        persistWidgetData()
    }

    // MARK: - HealthKit Export

    private let hkStore = HKHealthStore()

    /// Defers to the app-wide `HealthKitService` auth gate so the water
    /// types ride along with the single consolidated Health permission
    /// sheet shown at first launch instead of triggering a second sheet
    /// when the user first taps Sync. Idempotent.
    private func ensureWaterAuthorization() async {
        guard !defaults.bool(forKey: authRequestedKey) else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await HealthKitService.shared.requestAuthorization()
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

        // Union with `deletedHealthKitWaterUUIDs` so a user-deleted log stays
        // gone — without this, importing from HK would resurrect it on the
        // next sync.
        let existingHKIDs = Set(logs.compactMap { $0.healthKitUUID })
            .union(deletedHealthKitWaterUUIDs)

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
