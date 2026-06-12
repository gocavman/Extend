////
////  WaterLog.swift
////  Extend
////
////  Model for a single water intake entry.
////

import Foundation

// MARK: - Unit preference

public enum WaterUnit: String, Codable, CaseIterable {
    case oz = "oz"
    case ml = "mL"

    public var displayName: String { rawValue }

    /// Convert a value stored in oz to this unit for display.
    public func fromOz(_ oz: Double) -> Double {
        switch self {
        case .oz: return oz
        case .ml: return oz * 29.5735
        }
    }

    /// Convert a value in this unit back to oz for storage.
    public func toOz(_ value: Double) -> Double {
        switch self {
        case .oz: return value
        case .ml: return value / 29.5735
        }
    }
}

// MARK: - Model

public struct WaterLog: Identifiable, Codable, Hashable {
    public let id: UUID
    /// Amount stored in fluid ounces (oz) — always oz internally.
    public var amountOz: Double
    public var loggedAt: Date
    public var notes: String
    /// UUID of an HKQuantitySample written to Apple Health; used for deduplication.
    public var healthKitUUID: UUID?

    public init(
        id: UUID = UUID(),
        amountOz: Double,
        loggedAt: Date = Date(),
        notes: String = "",
        healthKitUUID: UUID? = nil
    ) {
        self.id = id
        self.amountOz = amountOz
        self.loggedAt = loggedAt
        self.notes = notes
        self.healthKitUUID = healthKitUUID
    }
}

// MARK: - Quick-add presets

public enum WaterQuickAdd: Double, CaseIterable {
    case four   = 4
    case six    = 6
    case eight  = 8
    case twelve = 12
    case sixteen = 16

    public var label: String { "\(Int(rawValue)) oz" }
}
