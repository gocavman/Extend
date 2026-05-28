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

    /// Filename (not full path) of a user-uploaded custom primary image stored on disk.
    public var customPrimaryImageFilename: String?

    /// Filename (not full path) of a user-uploaded custom secondary image stored on disk.
    public var customSecondaryImageFilename: String?

    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        primaryImageAssetName: String? = nil,
        secondaryImageAssetName: String? = nil,
        customPrimaryImageFilename: String? = nil,
        customSecondaryImageFilename: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.primaryImageAssetName = primaryImageAssetName
        self.secondaryImageAssetName = secondaryImageAssetName
        self.customPrimaryImageFilename = customPrimaryImageFilename
        self.customSecondaryImageFilename = customSecondaryImageFilename
        self.isFavorite = isFavorite
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

        // New fields
        customPrimaryImageFilename = try container.decodeIfPresent(String.self, forKey: .customPrimaryImageFilename)
        customSecondaryImageFilename = try container.decodeIfPresent(String.self, forKey: .customSecondaryImageFilename)

        // Legacy migration: if old Data blobs exist, write them to disk and store filenames
        if customPrimaryImageFilename == nil,
           let data = try container.decodeIfPresent(Data.self, forKey: .customPrimaryImageData) {
            let filename = "muscle_\(id.uuidString)_primary.png"
            MuscleGroup.writeImageData(data, filename: filename)
            customPrimaryImageFilename = filename
        }
        if customSecondaryImageFilename == nil,
           let data = try container.decodeIfPresent(Data.self, forKey: .customSecondaryImageData) {
            let filename = "muscle_\(id.uuidString)_secondary.png"
            MuscleGroup.writeImageData(data, filename: filename)
            customSecondaryImageFilename = filename
        }

        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(primaryImageAssetName, forKey: .primaryImageAssetName)
        try container.encodeIfPresent(secondaryImageAssetName, forKey: .secondaryImageAssetName)
        try container.encodeIfPresent(customPrimaryImageFilename, forKey: .customPrimaryImageFilename)
        try container.encodeIfPresent(customSecondaryImageFilename, forKey: .customSecondaryImageFilename)
        try container.encode(isFavorite, forKey: .isFavorite)
        // Note: legacy imageAssetName / customPrimaryImageData / customSecondaryImageData keys are intentionally not written
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
        case imageAssetName                 // legacy — read-only for migration
        case primaryImageAssetName
        case secondaryImageAssetName
        case customPrimaryImageData         // legacy — read-only for migration
        case customSecondaryImageData       // legacy — read-only for migration
        case customPrimaryImageFilename
        case customSecondaryImageFilename
        case isFavorite
    }

    // MARK: - Disk helpers

    /// Directory where custom muscle images are stored.
    public static var imageStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MuscleImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func writeImageData(_ data: Data, filename: String) {
        let url = imageStorageDirectory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
    }
}
