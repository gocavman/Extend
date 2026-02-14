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
    
    public init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        order: Int,
        targetModuleID: UUID? = nil,
        tileType: TileType = .moduleShortcut
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.order = order
        self.targetModuleID = targetModuleID
        self.tileType = tileType
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
