////
////  MuscleGroup.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Represents a single muscle group entry.
public struct MuscleGroup: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String

    /// Asset name for the primary (e.g. front-facing) image. Nil means no image assigned.
    public var primaryImageAssetName: String?

    /// Asset name for an optional secondary (e.g. back-facing) image.
    public var secondaryImageAssetName: String?

    /// Base64-encoded PNG data for a user-uploaded custom primary image.
    public var customPrimaryImageData: Data?

    /// Base64-encoded PNG data for a user-uploaded custom secondary image.
    public var customSecondaryImageData: Data?

    public init(
        id: UUID = UUID(),
        name: String,
        primaryImageAssetName: String? = nil,
        secondaryImageAssetName: String? = nil,
        customPrimaryImageData: Data? = nil,
        customSecondaryImageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.primaryImageAssetName = primaryImageAssetName
        self.secondaryImageAssetName = secondaryImageAssetName
        self.customPrimaryImageData = customPrimaryImageData
        self.customSecondaryImageData = customSecondaryImageData
    }

    // MARK: - Backward-compatible decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Legacy field: imageAssetName mapped to primaryImageAssetName
        primaryImageAssetName = try container.decodeIfPresent(String.self, forKey: .primaryImageAssetName)
            ?? container.decodeIfPresent(String.self, forKey: .imageAssetName)
        secondaryImageAssetName = try container.decodeIfPresent(String.self, forKey: .secondaryImageAssetName)
        customPrimaryImageData = try container.decodeIfPresent(Data.self, forKey: .customPrimaryImageData)
        customSecondaryImageData = try container.decodeIfPresent(Data.self, forKey: .customSecondaryImageData)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
        case imageAssetName          // legacy key — read-only for migration
        case primaryImageAssetName
        case secondaryImageAssetName
        case customPrimaryImageData
        case customSecondaryImageData
    }
}
