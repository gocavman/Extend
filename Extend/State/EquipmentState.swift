////
////  EquipmentState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

/// State management for equipment list.
@Observable
public final class EquipmentState {
    public static let shared = EquipmentState()
    
    public var items: [Equipment] = []
    
    private let storageKey = "equipment_items"
    
    private init() {
        loadItems()
    }
    
    public var sortedItems: [Equipment] {
        items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public func addItem(name: String, imageAssetName: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(Equipment(name: trimmed, imageAssetName: imageAssetName))
        saveItems()
    }
    
    public func updateItem(_ item: Equipment) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }
    
    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }
    
    public func resetItems() {
        items = defaultItems()
        saveItems()
    }
    
    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Equipment].self, from: data) {
            items = decoded
        } else {
            items = defaultItems()
            saveItems()
        }
    }
    
    private func defaultItems() -> [Equipment] {
        [
            Equipment(id: UUID(uuidString: "00000100-0000-0000-0000-000000000000")!, name: "None"),
            Equipment(id: UUID(uuidString: "0000010E-0000-0000-0000-000000000000")!, name: "Ab wheel"),
            Equipment(id: UUID(uuidString: "00000109-0000-0000-0000-000000000000")!, name: "Assault bike"),
            Equipment(id: UUID(uuidString: "00000110-0000-0000-0000-000000000000")!, name: "Bands"),
            Equipment(id: UUID(uuidString: "00000102-0000-0000-0000-000000000000")!, name: "Barbell"),
            Equipment(id: UUID(uuidString: "0000010D-0000-0000-0000-000000000000")!, name: "Battle ropes"),
            Equipment(id: UUID(uuidString: "00000103-0000-0000-0000-000000000000")!, name: "Bench"),
            Equipment(id: UUID(uuidString: "00000101-0000-0000-0000-000000000000")!, name: "Dumbbell"),
            Equipment(id: UUID(uuidString: "0000010C-0000-0000-0000-000000000000")!, name: "Elliptical machine"),
            Equipment(id: UUID(uuidString: "00000111-0000-0000-0000-000000000000")!, name: "Gymnastic rings"),
            Equipment(id: UUID(uuidString: "00000112-0000-0000-0000-000000000000")!, name: "Heavy bag"),
            Equipment(id: UUID(uuidString: "00000106-0000-0000-0000-000000000000")!, name: "Jump rope"),
            Equipment(id: UUID(uuidString: "00000107-0000-0000-0000-000000000000")!, name: "Kettlebell"),
            Equipment(id: UUID(uuidString: "00000104-0000-0000-0000-000000000000")!, name: "Pull up bar"),
            Equipment(id: UUID(uuidString: "00000105-0000-0000-0000-000000000000")!, name: "Rope"),
            Equipment(id: UUID(uuidString: "00000108-0000-0000-0000-000000000000")!, name: "Rower"),
            Equipment(id: UUID(uuidString: "0000010B-0000-0000-0000-000000000000")!, name: "Stairclimber"),
            Equipment(id: UUID(uuidString: "0000010A-0000-0000-0000-000000000000")!, name: "Treadmill")
        ]
    }
}
