////
////  Exercise.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Exercise model with muscle group and equipment relationships
public struct Exercise: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var notes: String
    public var primaryMuscleGroupIDs: [UUID]  // Primary muscles worked
    public var secondaryMuscleGroupIDs: [UUID]  // Secondary muscles engaged
    public var equipmentIDs: [UUID]    // References to Equipment UUIDs
    
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
        equipmentIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.primaryMuscleGroupIDs = primaryMuscleGroupIDs
        self.secondaryMuscleGroupIDs = secondaryMuscleGroupIDs
        self.equipmentIDs = equipmentIDs
    }
}
