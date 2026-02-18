////
////  DashboardTile.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import Foundation

/// Represents a tile on the dashboard
/// Tiles are shortcuts to modules and other content
public struct DashboardTile: Identifiable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var icon: String
    public var order: Int
    public var targetModuleID: UUID?  // Link to a module (future expansion)
    public var tileType: TileType
    public var statCardType: StatCardType?  // Type of stat card (if tileType is statCard)
    public var size: TileSize
    public var blankAction: BlankTileAction?
    
    public init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        order: Int,
        targetModuleID: UUID? = nil,
        tileType: TileType = .moduleShortcut,
        statCardType: StatCardType? = nil,
        size: TileSize = .small,
        blankAction: BlankTileAction? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.order = order
        self.targetModuleID = targetModuleID
        self.tileType = tileType
        self.statCardType = statCardType
        self.size = size
        self.blankAction = blankAction
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: DashboardTile, rhs: DashboardTile) -> Bool {
        lhs.id == rhs.id
    }
}

/// Types of tiles that can appear on the dashboard
public enum TileType: String, Codable, CaseIterable {
    case moduleShortcut = "Module Shortcut"
    case statCard = "Stat Card"
    case quickAction = "Quick Action"
    case graph = "Graph"
}

/// Types of stat cards available
public enum StatCardType: String, Codable, CaseIterable {
    case totalWorkouts = "Total Workouts"
    case dayStreaks = "Day Streaks"
    case totalTime = "Total Time"
    case favoriteExercise = "Favorite Exercise"
    case favoriteDay = "Favorite Day"
    case workoutFrequency = "Workout Frequency (14 days)"
    case muscleGroupDistribution = "Muscle Group Distribution (7 days)"
}

/// Tile sizes for the dashboard grid
public enum TileSize: String, Codable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var columns: Int {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        }
    }
}

public enum BlankTileAction: String, Codable, CaseIterable {
    case animation1 = "Animation 1"
    case animation2 = "Animation 2"
    case animation3 = "Animation 3"
    case game1 = "Game 1"
    case game2 = "Game 2"
}
