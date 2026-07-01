////
////  GearState.swift
////  Extend
////

import Foundation
import Observation

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// State management for the Gear list (shoes, bikes, straps, etc.).
///
/// Gear intentionally does not attach itself to `LoggedExercise.usedEquipmentIDs`
/// at log time. Instead, `logs(for:)` and friends resolve usage on the fly by
/// intersecting a gear item's active window (`startDate` … `retiredDate`) with
/// each log's `completedAt` and matching the log's exercises against
/// `linkedExerciseIDs`. This is why adding a new pair of shoes with a start
/// date a month ago will "pick up" every qualifying run since that date
/// without ever mutating historical logs.
@Observable
public final class GearState {
    public static let shared = GearState()

    public var items: [Gear] = []

    private let storageKey = "gear_items"

    private init() {
        loadItems()
    }

    public var sortedItems: [Gear] {
        items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public var favoriteItems: [Gear] {
        items.filter { $0.isFavorite }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func toggleFavorite(_ item: Gear) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
            saveItems()
        }
    }

    public func addItem(
        name: String,
        brand: String = "",
        sfSymbol: String? = nil,
        linkedExerciseIDs: [UUID] = [],
        startDate: Date = Date(),
        retiredDate: Date? = nil,
        retirementThresholdMeters: Double? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(Gear(
            name: trimmed,
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            sfSymbol: sfSymbol,
            linkedExerciseIDs: linkedExerciseIDs,
            startDate: startDate,
            retiredDate: retiredDate,
            retirementThresholdMeters: retirementThresholdMeters
        ))
        saveItems()
    }

    public func updateItem(_ item: Gear) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }

    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }

    /// Wipe all gear items — used by Settings' "Erase All Data" flow. Gear
    /// ships with no defaults, so reset means "empty".
    public func resetItems() {
        items = []
        saveItems()
    }

    // MARK: - Usage resolution

    /// Logs that a piece of gear should count toward. A log qualifies when:
    ///   1) `log.completedAt` sits inside the gear's `[startDate, retiredDate]` window, and
    ///   2) at least one of the log's exercises has an `exerciseID` in `linkedExerciseIDs`.
    public func logs(for gear: Gear, in logs: [WorkoutLog]) -> [WorkoutLog] {
        let linked = Set(gear.linkedExerciseIDs)
        guard !linked.isEmpty else { return [] }
        return logs.filter { log in
            gear.isActive(on: log.completedAt) &&
            log.exercises.contains { linked.contains($0.exerciseID) }
        }
    }

    /// Cumulative distance (meters) across all qualifying logs.
    public func totalDistanceMeters(for gear: Gear, in logs: [WorkoutLog]) -> Double {
        let linked = Set(gear.linkedExerciseIDs)
        return self.logs(for: gear, in: logs).reduce(0.0) { partial, log in
            partial + log.exercises
                .filter { linked.contains($0.exerciseID) }
                .reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
        }
    }

    /// Cumulative active seconds across all qualifying logs.
    public func totalActiveSeconds(for gear: Gear, in logs: [WorkoutLog]) -> Int {
        let linked = Set(gear.linkedExerciseIDs)
        return self.logs(for: gear, in: logs).reduce(0) { partial, log in
            partial + log.exercises
                .filter { linked.contains($0.exerciseID) }
                .reduce(0) { $0 + $1.activeSeconds }
        }
    }

    public func sessionCount(for gear: Gear, in logs: [WorkoutLog]) -> Int {
        self.logs(for: gear, in: logs).count
    }

    // MARK: - Default icon suggestion

    public static func defaultSFSymbol(for name: String) -> String {
        let lower = name.lowercased()
        switch true {
        case lower.contains("shoe"), lower.contains("runner"),
             lower.contains("sneaker"), lower.contains("trainer"),
             lower.contains("nike"), lower.contains("adidas"),
             lower.contains("hoka"), lower.contains("brooks"),
             lower.contains("asics"), lower.contains("saucony"),
             lower.contains("altra"), lower.contains("new balance"):
            return "shoe"
        case lower.contains("boot"), lower.contains("hike"):
            return "shoe.2"
        case lower.contains("bike"), lower.contains("bicycle"), lower.contains("cycle"):
            return "bicycle"
        case lower.contains("watch"), lower.contains("garmin"), lower.contains("apple watch"):
            return "applewatch"
        case lower.contains("strap"), lower.contains("hr "), lower.contains("heart rate"):
            return "heart.fill"
        default:
            return "shoe"
        }
    }

    // MARK: - Persistence

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: storageKey)
        }
        CloudKitSyncEngine.shared.push(.gear)
    }

    private func loadItems() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Gear].self, from: data) {
            items = decoded
        } else {
            items = []
            saveItems()
        }
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    public func reloadFromDefaults() {
        loadItems()
    }
}
