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

    public init(id: UUID = UUID(), name: String, imageAssetName: String? = nil, isFavorite: Bool = false, sfSymbol: String? = nil) {
        self.id = id
        self.name = name
        self.imageAssetName = imageAssetName
        self.isFavorite = isFavorite
        self.sfSymbol = sfSymbol
    }

    // MARK: - Backward-compatible decoding
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
