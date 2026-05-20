////
////  Exercise.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Exercise model with muscle group and equipment relationships
public struct Exercise: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var notes: String
    public var primaryMuscleGroupIDs: [UUID]  // Primary muscles worked
    public var secondaryMuscleGroupIDs: [UUID]  // Secondary muscles engaged
    public var equipmentIDs: [UUID]           // References to Equipment UUIDs
    public var defaultEquipmentIDs: [UUID]    // Equipment pre-selected when starting a workout
    public var isFavorite: Bool
    /// Raw value of HKWorkoutActivityType. nil = use .other at export time (Quick Workout).
    public var healthKitActivityType: UInt?
    
    // For backwards compatibility, expose combined muscles
    public var muscleGroupIDs: [UUID] {
        Array(Set(primaryMuscleGroupIDs + secondaryMuscleGroupIDs))
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        primaryMuscleGroupIDs: [UUID] = [],
        secondaryMuscleGroupIDs: [UUID] = [],
        equipmentIDs: [UUID] = [],
        defaultEquipmentIDs: [UUID] = [],
        isFavorite: Bool = false,
        healthKitActivityType: UInt? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.primaryMuscleGroupIDs = primaryMuscleGroupIDs
        self.secondaryMuscleGroupIDs = secondaryMuscleGroupIDs
        self.equipmentIDs = equipmentIDs
        self.defaultEquipmentIDs = defaultEquipmentIDs
        self.isFavorite = isFavorite
        self.healthKitActivityType = healthKitActivityType
    }

    // MARK: - Backward-compatible decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        primaryMuscleGroupIDs = try container.decodeIfPresent([UUID].self, forKey: .primaryMuscleGroupIDs) ?? []
        secondaryMuscleGroupIDs = try container.decodeIfPresent([UUID].self, forKey: .secondaryMuscleGroupIDs) ?? []
        equipmentIDs = try container.decodeIfPresent([UUID].self, forKey: .equipmentIDs) ?? []
        defaultEquipmentIDs = try container.decodeIfPresent([UUID].self, forKey: .defaultEquipmentIDs) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        healthKitActivityType = try container.decodeIfPresent(UInt.self, forKey: .healthKitActivityType)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, primaryMuscleGroupIDs, secondaryMuscleGroupIDs, equipmentIDs, defaultEquipmentIDs, isFavorite, healthKitActivityType
    }
}
