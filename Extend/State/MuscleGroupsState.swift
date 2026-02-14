////
////  MuscleGroupsState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

/// State management for muscle groups.
@Observable
public final class MuscleGroupsState {
    public static let shared = MuscleGroupsState()
    
    public var groups: [MuscleGroup] = []
    
    private let storageKey = "muscle_groups"
    
    private init() {
        loadGroups()
    }
    
    public var sortedGroups: [MuscleGroup] {
        groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public func addGroup(name: String, imageAssetName: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        groups.append(MuscleGroup(name: trimmed, imageAssetName: imageAssetName))
        saveGroups()
    }
    
    public func updateGroup(_ group: MuscleGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }
    
    public func removeGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        saveGroups()
    }
    
    public func resetGroups() {
        groups = defaultGroups()
        saveGroups()
    }
    
    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadGroups() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MuscleGroup].self, from: data) {
            groups = decoded
        } else {
            groups = defaultGroups()
            saveGroups()
        }
    }
    
    private func defaultGroups() -> [MuscleGroup] {
        [
            MuscleGroup(id: UUID(uuidString: "00000020-0000-0000-0000-000000000000")!, name: "Abs"),
            MuscleGroup(id: UUID(uuidString: "00000010-0000-0000-0000-000000000000")!, name: "Biceps"),
            MuscleGroup(id: UUID(uuidString: "00000019-0000-0000-0000-000000000000")!, name: "Calfs"),
            MuscleGroup(id: UUID(uuidString: "00000013-0000-0000-0000-000000000000")!, name: "Delts"),
            MuscleGroup(id: UUID(uuidString: "0000002A-0000-0000-0000-000000000000")!, name: "Full Body"),
            MuscleGroup(id: UUID(uuidString: "00000023-0000-0000-0000-000000000000")!, name: "Forearms"),
            MuscleGroup(id: UUID(uuidString: "00000017-0000-0000-0000-000000000000")!, name: "Glutes"),
            MuscleGroup(id: UUID(uuidString: "00000024-0000-0000-0000-000000000000")!, name: "Grip"),
            MuscleGroup(id: UUID(uuidString: "00000018-0000-0000-0000-000000000000")!, name: "Hamstrings"),
            MuscleGroup(id: UUID(uuidString: "00000022-0000-0000-0000-000000000000")!, name: "Heart"),
            MuscleGroup(id: UUID(uuidString: "00000027-0000-0000-0000-000000000000")!, name: "Hip Flexors"),
            MuscleGroup(id: UUID(uuidString: "00000025-0000-0000-0000-000000000000")!, name: "Legs"),
            MuscleGroup(id: UUID(uuidString: "00000015-0000-0000-0000-000000000000")!, name: "Lats"),
            MuscleGroup(id: UUID(uuidString: "00000026-0000-0000-0000-000000000000")!, name: "Lower Back"),
            MuscleGroup(id: UUID(uuidString: "00000021-0000-0000-0000-000000000000")!, name: "Obliques"),
            MuscleGroup(id: UUID(uuidString: "00000012-0000-0000-0000-000000000000")!, name: "Pecs"),
            MuscleGroup(id: UUID(uuidString: "00000028-0000-0000-0000-000000000000")!, name: "Rhomboids"),
            MuscleGroup(id: UUID(uuidString: "00000016-0000-0000-0000-000000000000")!, name: "Quads"),
            MuscleGroup(id: UUID(uuidString: "00000014-0000-0000-0000-000000000000")!, name: "Traps"),
            MuscleGroup(id: UUID(uuidString: "00000011-0000-0000-0000-000000000000")!, name: "Triceps"),
            MuscleGroup(id: UUID(uuidString: "00000029-0000-0000-0000-000000000000")!, name: "Upper Back")
        ]
    }
}
