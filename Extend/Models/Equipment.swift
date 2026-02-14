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
    
    public init(id: UUID = UUID(), name: String, imageAssetName: String? = nil) {
        self.id = id
        self.name = name
        self.imageAssetName = imageAssetName
    }
}
