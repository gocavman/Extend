////
////  EquipmentState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

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

    public var favoriteItems: [Equipment] {
        items.filter { $0.isFavorite }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func toggleFavorite(_ item: Equipment) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
            saveItems()
        }
    }
    
    public func addItem(name: String, imageAssetName: String? = nil, sfSymbol: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(Equipment(name: trimmed, imageAssetName: imageAssetName, sfSymbol: sfSymbol))
        saveItems()
    }

    /// Returns the best-match SF Symbol name for the given equipment name.
    /// Falls back to a generic symbol if no specific mapping exists.
    public static func defaultSFSymbol(for name: String) -> String {
        let lower = name.lowercased()
        switch true {
        case lower.contains("dumbbell"):            return "dumbbell.fill"
        case lower.contains("kettlebell"):          return "dumbbell.fill"
        case lower.contains("barbell"):             return "dumbbell.fill"
        case lower.contains("pull up"), lower.contains("pullup"),
             lower.contains("pull-up"):             return "dumbbell.fill"
        case lower.contains("treadmill"):           return "figure.walk.treadmill"
        case lower.contains("rower"), lower.contains("rowing"): return "figure.rower"
        case lower.contains("elliptical"):          return "figure.elliptical"
        case lower.contains("stairclimber"),
             lower.contains("stair stepper"),
             lower.contains("stair climber"):       return "figure.stair.stepper"
        case lower.contains("assault bike"):        return "dumbbell.fill"
        case lower.contains("stationary"), lower.contains("spin bike"), lower.contains("bicycle (stationary)"): return "figure.indoor.cycle"
        case lower.contains("bicycle"), lower.contains("bike"): return "figure.outdoor.cycle"
        case lower.contains("jump rope"), lower.contains("jumprope"): return "figure.jumprope"
        case lower.contains("boxing"), lower.contains("punching"): return "figure.boxing"
        case lower.contains("bench"):               return "dumbbell.fill"
        case lower.contains("rope"):                return "dumbbell.fill"
        case lower.contains("band"), lower.contains("resistance band"): return "figure.flexibility"
        case lower.contains("battle ropes"):         return "dumbbell.fill"
        case lower.contains("medicine ball"), lower.contains("med ball"): return "circle.fill"
        case lower.contains("plyo"), lower.contains("box jump"): return "figure.cross.training"
        case lower.contains("gymnastic ring"): return "ring"
        case lower.contains("ab wheel"), lower.contains("abwheel"): return "dumbbell.fill"
        case lower.contains("none"):                return "xmark.circle"
        default:                                    return "dumbbell.fill"
        }
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
            defaults.set(data, forKey: storageKey)
        }
        CloudKitSyncEngine.shared.push(.equipment)
    }
    
    private func loadItems() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Equipment].self, from: data) {
            items = decoded
        } else {
            items = defaultItems()
            saveItems()
        }
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    public func reloadFromDefaults() {
        loadItems()
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
            Equipment(id: UUID(uuidString: "00000112-0000-0000-0000-000000000000")!, name: "Boxing bag"),
            Equipment(id: UUID(uuidString: "00000106-0000-0000-0000-000000000000")!, name: "Jump rope"),
            Equipment(id: UUID(uuidString: "00000114-0000-0000-0000-000000000000")!, name: "Medicine ball"),
            Equipment(id: UUID(uuidString: "00000113-0000-0000-0000-000000000000")!, name: "Plyo box"),
            Equipment(id: UUID(uuidString: "00000107-0000-0000-0000-000000000000")!, name: "Kettlebell"),
            Equipment(id: UUID(uuidString: "00000104-0000-0000-0000-000000000000")!, name: "Pull up bar"),
            Equipment(id: UUID(uuidString: "00000105-0000-0000-0000-000000000000")!, name: "Rope"),
            Equipment(id: UUID(uuidString: "00000108-0000-0000-0000-000000000000")!, name: "Rower"),
            Equipment(id: UUID(uuidString: "0000010B-0000-0000-0000-000000000000")!, name: "Stairclimber"),
            Equipment(id: UUID(uuidString: "0000010A-0000-0000-0000-000000000000")!, name: "Treadmill"),
            Equipment(id: UUID(uuidString: "00000115-0000-0000-0000-000000000000")!, name: "Bicycle (outdoor)"),
            Equipment(id: UUID(uuidString: "00000116-0000-0000-0000-000000000000")!, name: "Bicycle (stationary)"),
            Equipment(id: UUID(uuidString: "00000117-0000-0000-0000-000000000000")!, name: "EZ curl bar"),
            Equipment(id: UUID(uuidString: "00000118-0000-0000-0000-000000000000")!, name: "Lat pulldown machine"),
            Equipment(id: UUID(uuidString: "00000119-0000-0000-0000-000000000000")!, name: "Dip station"),
            Equipment(id: UUID(uuidString: "0000011A-0000-0000-0000-000000000000")!, name: "Chest press machine"),
            Equipment(id: UUID(uuidString: "0000011B-0000-0000-0000-000000000000")!, name: "Leg press machine"),
            Equipment(id: UUID(uuidString: "0000011C-0000-0000-0000-000000000000")!, name: "Leg curl machine"),
            Equipment(id: UUID(uuidString: "0000011D-0000-0000-0000-000000000000")!, name: "Leg extension machine"),
            Equipment(id: UUID(uuidString: "0000011E-0000-0000-0000-000000000000")!, name: "Sled")
        ]
    }
}
