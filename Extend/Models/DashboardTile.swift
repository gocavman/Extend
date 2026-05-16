////
////  DashboardTile.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import Foundation
import SwiftUI

/// Represents a tile on the dashboard
/// Tiles are shortcuts to modules and other content
public struct DashboardTile: Identifiable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var icon: String
    public var order: Int
    public var targetModuleID: UUID?
    public var tileType: TileType
    public var statCardType: StatCardType?
    public var size: TileSize
    public var blankAction: BlankTileAction?

    /// Appearance
    public var accentPlacement: AccentPlacement
    public var accentColorHex: String   // stored as hex string for Codable
    public var tileTintHex: String?     // nil = default background, otherwise tints entire tile

    /// Shortcut tile: references a saved item by ID (Workout or TimerConfig)
    public var shortcutType: ShortcutType?
    public var shortcutItemID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        order: Int,
        targetModuleID: UUID? = nil,
        tileType: TileType = .moduleShortcut,
        statCardType: StatCardType? = nil,
        size: TileSize = .small,
        blankAction: BlankTileAction? = nil,
        accentPlacement: AccentPlacement = .none,
        accentColorHex: String = "#CCCCCC",
        tileTintHex: String? = nil,
        shortcutType: ShortcutType? = nil,
        shortcutItemID: UUID? = nil
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
        self.accentPlacement = accentPlacement
        self.accentColorHex = accentColorHex
        self.tileTintHex = tileTintHex
        self.shortcutType = shortcutType
        self.shortcutItemID = shortcutItemID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DashboardTile, rhs: DashboardTile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Color Helpers

public extension DashboardTile {
    var accentColor: Color { Color(hex: accentColorHex) ?? .gray }
    var tileTintColor: Color? { tileTintHex.flatMap { Color(hex: $0) } }
}

public extension Color {
    /// Parse a hex string like "#RRGGBB" or "RRGGBB"
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str = String(str.dropFirst()) }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Return hex string "#RRGGBB"
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Enums

/// Types of tiles that can appear on the dashboard
public enum TileType: String, Codable, CaseIterable {
    case moduleShortcut = "Module Shortcut"
    case statCard = "Stat Card"
    case quickAction = "Quick Action"
    case graph = "Graph"
    case shortcut = "Shortcut"
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
    case volumeThisWeek = "Volume This Week"
    case longestStreak = "Longest Streak"
    case restDays = "Rest Days (14 days)"
    case personalRecord = "Personal Record"
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

/// Which edge (or none) receives a colored accent bar
public enum AccentPlacement: String, Codable, CaseIterable {
    case none   = "None"
    case left   = "Left"
    case top    = "Top"
    case right  = "Right"
    case bottom = "Bottom"
}

/// Saved-item shortcut types for dashboard tiles
public enum ShortcutType: String, Codable, CaseIterable {
    case workout = "Workout"
    case timer   = "Timer"
}
