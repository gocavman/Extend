////
////  DashboardState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import Foundation
import Observation

/// State management for Dashboard tiles
/// Persists across app sessions
@Observable
public final class DashboardState {
    public static let shared = DashboardState()
    
    public var tiles: [DashboardTile] = []
    public var tileClickCounts: [UUID: Int] = [:]
    
    private let tilesKey = "dashboard_tiles"
    private let clickCountsKey = "dashboard_tile_click_counts"
    
    private init() {
        loadTiles()
        loadClickCounts()
    }
    
    // MARK: - Tile Management
    
    /// Add a new tile
    public func addTile(_ tile: DashboardTile) {
        var newTile = tile
        newTile.order = tiles.max(by: { $0.order < $1.order })?.order ?? 0 + 1
        tiles.append(newTile)
        saveTiles()
    }
    
    /// Update an existing tile
    public func updateTile(_ tile: DashboardTile) {
        if let index = tiles.firstIndex(where: { $0.id == tile.id }) {
            tiles[index] = tile
            saveTiles()
        }
    }
    
    /// Delete a tile
    public func deleteTile(_ id: UUID) {
        tiles.removeAll { $0.id == id }
        saveTiles()
    }
    
    /// Reset tiles to default
    public func resetTiles() {
        tiles = createDefaultTiles()
        tileClickCounts.removeAll()
        saveTiles()
        saveClickCounts()
    }
    
    /// Increment click count for a tile
    public func incrementClickCount(for tileID: UUID) {
        tileClickCounts[tileID, default: 0] += 1
        saveClickCounts()
    }
    
    // MARK: - Persistence
    
    private func saveTiles() {
        if let encoded = try? JSONEncoder().encode(tiles) {
            UserDefaults.standard.set(encoded, forKey: tilesKey)
        }
    }
    
    private func loadTiles() {
        if let data = UserDefaults.standard.data(forKey: tilesKey),
           let decoded = try? JSONDecoder().decode([DashboardTile].self, from: data) {
            tiles = decoded
        } else {
            tiles = createDefaultTiles()
            saveTiles()
        }
    }
    
    private func saveClickCounts() {
        let dict = tileClickCounts.mapKeys { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: clickCountsKey)
        }
    }
    
    private func loadClickCounts() {
        if let data = UserDefaults.standard.data(forKey: clickCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            tileClickCounts = decoded.compactMapKeys { UUID(uuidString: $0) }
        }
    }
    
    private func createDefaultTiles() -> [DashboardTile] {
        var order = 0
        var tiles: [DashboardTile] = []

        tiles.append(
            DashboardTile(
                title: StatCardType.workoutFrequency.rawValue,
                icon: "chart.bar",
                order: order,
                tileType: .statCard,
                statCardType: .workoutFrequency,
                size: .large
            )
        )
        order += 1

        tiles.append(
            DashboardTile(
                title: StatCardType.muscleGroupDistribution.rawValue,
                icon: "chart.pie",
                order: order,
                tileType: .statCard,
                statCardType: .muscleGroupDistribution,
                size: .large
            )
        )
        order += 1

        tiles.append(
            DashboardTile(
                title: StatCardType.totalWorkouts.rawValue,
                icon: "list.bullet",
                order: order,
                tileType: .statCard,
                statCardType: .totalWorkouts,
                size: .small
            )
        )
        order += 1

        tiles.append(
            DashboardTile(
                title: StatCardType.dayStreaks.rawValue,
                icon: "flame",
                order: order,
                tileType: .statCard,
                statCardType: .dayStreaks,
                size: .small
            )
        )
        order += 1

        tiles.append(
            DashboardTile(
                title: StatCardType.totalTime.rawValue,
                icon: "clock",
                order: order,
                tileType: .statCard,
                statCardType: .totalTime,
                size: .small
            )
        )

        return tiles
    }
}

// MARK: - Dictionary Extensions

private extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
    
    func compactMapKeys<T>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}
