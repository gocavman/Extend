////
////  Equipment.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Represents a single equipment entry (dumbbell, barbell, rower, etc.).
///
/// Wearable/consumable items with an ownership window (shoes, bikes, straps)
/// are modeled separately as `Gear`. If you find yourself wanting to bound a
/// piece of equipment to a date range, it should probably be a `Gear` instead.
public struct Equipment: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var imageAssetName: String?
    public var isFavorite: Bool
    public var sfSymbol: String?

    public init(id: UUID = UUID(), name: String, imageAssetName: String? = nil, isFavorite: Bool = false, sfSymbol: String? = nil) {
        self.id = id
        self.name = name
        self.imageAssetName = imageAssetName
        self.isFavorite = isFavorite
        self.sfSymbol = sfSymbol
    }

    // MARK: - Backward-compatible decoding
    // `startDate` / `endDate` used to live here as a shoe-specific hack; they
    // were replaced by the Gear module. We silently ignore them on decode so
    // existing UserDefaults and CloudKit payloads from older builds still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageAssetName = try container.decodeIfPresent(String.self, forKey: .imageAssetName)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        sfSymbol = try container.decodeIfPresent(String.self, forKey: .sfSymbol)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, imageAssetName, isFavorite, sfSymbol
    }
}
