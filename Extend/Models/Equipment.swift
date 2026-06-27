////
////  Equipment.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Represents a single equipment entry.
public struct Equipment: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var imageAssetName: String?
    public var isFavorite: Bool
    public var sfSymbol: String?
    /// Optional in-use window. When set, stats and history only count logs whose date falls
    /// within [startDate, endDate]. Either bound may be nil for an open-ended window. Used
    /// for items like shoes where a new pair shouldn't inherit the linked exercise's full
    /// history (e.g. every "Running" log from before the shoes were bought).
    public var startDate: Date?
    public var endDate: Date?

    public init(id: UUID = UUID(), name: String, imageAssetName: String? = nil, isFavorite: Bool = false, sfSymbol: String? = nil, startDate: Date? = nil, endDate: Date? = nil) {
        self.id = id
        self.name = name
        self.imageAssetName = imageAssetName
        self.isFavorite = isFavorite
        self.sfSymbol = sfSymbol
        self.startDate = startDate
        self.endDate = endDate
    }

    // MARK: - Backward-compatible decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageAssetName = try container.decodeIfPresent(String.self, forKey: .imageAssetName)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        sfSymbol = try container.decodeIfPresent(String.self, forKey: .sfSymbol)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, imageAssetName, isFavorite, sfSymbol, startDate, endDate
    }
}
