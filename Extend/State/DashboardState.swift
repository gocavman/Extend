////
////  DashboardState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import Foundation
import Observation

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

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
            defaults.set(encoded, forKey: tilesKey)
        }
        CloudKitSyncEngine.shared.push(.dashboardTiles)
    }
    
    private func loadTiles() {
        if let data = defaults.data(forKey: tilesKey),
           let decoded = try? JSONDecoder().decode([DashboardTile].self, from: data) {
            // Drop orphan stat-card tiles whose statCardType decoded to nil —
            // these reference enum cases that have since been removed (e.g.
            // Total Workouts, Day Streaks, Total Time, Longest Streak, Rest
            // Days). The DashboardTile decoder tolerates the missing case
            // for forward-compat; this filter keeps the dashboard clean.
            tiles = decoded.filter { tile in
                tile.tileType != .statCard || tile.statCardType != nil
            }
            // Persist the cleaned list so the next load skips the filter.
            if tiles.count != decoded.count {
                saveTiles()
            }
        } else {
            tiles = createDefaultTiles()
            saveTiles()
        }
    }
    
    private func saveClickCounts() {
        let dict = tileClickCounts.mapKeys { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(dict) {
            defaults.set(encoded, forKey: clickCountsKey)
        }
    }
    
    private func loadClickCounts() {
        if let data = defaults.data(forKey: clickCountsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            tileClickCounts = decoded.compactMapKeys { UUID(uuidString: $0) }
        }
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    public func reloadFromDefaults() {
        loadTiles()
    }
    
    private func createDefaultTiles() -> [DashboardTile] {
        var order = 0
        var tiles: [DashboardTile] = []

        // Helper: create a graph/large stat card without any accent bar
        func graphCard(_ type: StatCardType, icon: String) -> DashboardTile {
            DashboardTile(
                title: type.rawValue,
                icon: icon,
                order: order,
                tileType: .statCard,
                statCardType: type,
                size: .large,
                accentPlacement: .none,
                accentColorHex: "#CCCCCC"
            )
        }

        // Large tiles
        tiles.append(DashboardTile(
            title: StatCardType.todaysPlan.rawValue,
            icon: "calendar.badge.checkmark",
            order: order,
            tileType: .statCard,
            statCardType: .todaysPlan,
            size: .large,
            accentPlacement: .none,
            accentColorHex: "#CCCCCC"
        ))
        order += 1

        tiles.append(graphCard(.workoutFrequency, icon: "chart.bar"))
        order += 1

        tiles.append(graphCard(.muscleGroupDistribution, icon: "chart.pie"))
        order += 1

        tiles.append(graphCard(.volumeThisWeek, icon: "scalemass"))
        order += 1

        tiles.append(graphCard(.personalRecord, icon: "medal"))
        order += 1

        tiles.append(graphCard(.oneRepMax, icon: "trophy"))
        order += 1
        
        tiles.append(graphCard(.waterIntake14Days, icon: "drop"))
        order += 1
        
        tiles.append(graphCard(.topDurations, icon: "stopwatch"))
        order += 1
        
        tiles.append(graphCard(.topDistances, icon: "ruler"))
        order += 1

        tiles.append(graphCard(.topGearDistances, icon: "shoe"))
        order += 1

        // Favorite Exercise → leaderboard tile, placed directly above
        // Favorite Day so the two "what do I do most" cards sit together.
        tiles.append(graphCard(.favoriteExercise, icon: "star"))
        order += 1

        tiles.append(graphCard(.favoriteDay, icon: "calendar"))
        order += 1

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
