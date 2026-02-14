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
    
    private let tilesKey = "dashboard_tiles"
    
    private init() {
        loadTiles()
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
        saveTiles()
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
    
    private func createDefaultTiles() -> [DashboardTile] {
        let registry = ModuleRegistry.shared
        var defaultTiles: [DashboardTile] = []
        var order = 0
        
        // Add tiles for all modules except Dashboard (it's already the Dashboard itself)
        for module in registry.registeredModules.sorted(by: { $0.order < $1.order }) {
            if module.id != ModuleIDs.dashboard {
                defaultTiles.append(
                    DashboardTile(
                        title: module.displayName,
                        icon: module.iconName,
                        order: order,
                        targetModuleID: module.id,
                        tileType: .moduleShortcut
                    )
                )
                order += 1
            }
        }
        
        return defaultTiles
    }
}
