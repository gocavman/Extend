////
////  MuscleGroupsState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation
import Observation

// MARK: - JSON mapping types (muscle_images.json)

private struct MuscleImageMapping: Decodable {
    struct ImagePair: Decodable {
        let primary: String?
        let secondary: String?
    }
    let name: String
    let male: ImagePair
    let female: ImagePair
}

private struct MuscleImageMappingFile: Decodable {
    let mappings: [MuscleImageMapping]
}

// MARK: - State

/// State management for muscle groups.
@Observable
public final class MuscleGroupsState {
    public static let shared = MuscleGroupsState()

    public var groups: [MuscleGroup] = []

    /// The image set option selected globally (male / female).
    /// Stored in UserDefaults so it persists across launches.
    public var selectedBodyOption: BodyImageOption {
        didSet { UserDefaults.standard.set(selectedBodyOption.rawValue, forKey: bodyOptionKey) }
    }

    public enum BodyImageOption: String, CaseIterable {
        case male = "male"
        case female = "female"
        case custom = "custom"
    }

    private let storageKey = "muscle_groups"
    private let bodyOptionKey = "muscle_body_option"

    private init() {
        let raw = UserDefaults.standard.string(forKey: bodyOptionKey) ?? BodyImageOption.male.rawValue
        selectedBodyOption = BodyImageOption(rawValue: raw) ?? .male
        loadGroups()
    }

    public var sortedGroups: [MuscleGroup] {
        groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func addGroup(name: String,
                         primaryImageAssetName: String? = nil,
                         secondaryImageAssetName: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        groups.append(MuscleGroup(name: trimmed,
                                  primaryImageAssetName: primaryImageAssetName,
                                  secondaryImageAssetName: secondaryImageAssetName))
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

    /// Applies the chosen body option to every group, re-seeding images from the JSON mapping.
    /// Custom groups (those not found in the JSON) are left untouched.
    public func applyBodyOption(_ option: BodyImageOption) {
        selectedBodyOption = option
        let mappings = loadImageMappings()
        for i in groups.indices {
            guard let map = mappings.first(where: { $0.name == groups[i].name }) else { continue }
            switch option {
            case .male:
                groups[i].primaryImageAssetName   = map.male.primary
                groups[i].secondaryImageAssetName  = map.male.secondary
                groups[i].customPrimaryImageData   = nil
                groups[i].customSecondaryImageData = nil
            case .female:
                groups[i].primaryImageAssetName   = map.female.primary
                groups[i].secondaryImageAssetName  = map.female.secondary
                groups[i].customPrimaryImageData   = nil
                groups[i].customSecondaryImageData = nil
            case .custom:
                // Clear asset images so the blank placeholder shows; preserve any existing custom data
                groups[i].primaryImageAssetName   = nil
                groups[i].secondaryImageAssetName  = nil
                // Leave customPrimaryImageData / customSecondaryImageData as-is
            }
        }
        saveGroups()
    }

    // MARK: - Persistence

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

    // MARK: - Default groups (seeded from muscle_images.json)

    private func defaultGroups() -> [MuscleGroup] {
        let mappings = loadImageMappings()

        // Fixed UUIDs so references from exercises survive a reset
        let stubs: [(uuid: String, name: String)] = [
            ("00000020-0000-0000-0000-000000000000", "Abs"),
            ("00000010-0000-0000-0000-000000000000", "Biceps"),
            ("00000019-0000-0000-0000-000000000000", "Calfs"),
            ("00000013-0000-0000-0000-000000000000", "Delts"),
            ("0000002A-0000-0000-0000-000000000000", "Full Body"),
            ("00000023-0000-0000-0000-000000000000", "Forearms"),
            ("00000017-0000-0000-0000-000000000000", "Glutes"),
            ("00000024-0000-0000-0000-000000000000", "Grip"),
            ("00000018-0000-0000-0000-000000000000", "Hamstrings"),
            ("00000022-0000-0000-0000-000000000000", "Heart"),
            ("00000025-0000-0000-0000-000000000000", "Legs"),
            ("00000015-0000-0000-0000-000000000000", "Lats"),
            ("00000026-0000-0000-0000-000000000000", "Lower Back"),
            ("00000021-0000-0000-0000-000000000000", "Obliques"),
            ("00000012-0000-0000-0000-000000000000", "Pecs"),
            ("00000028-0000-0000-0000-000000000000", "Rhomboids"),
            ("00000016-0000-0000-0000-000000000000", "Quads"),
            ("00000014-0000-0000-0000-000000000000", "Traps"),
            ("00000011-0000-0000-0000-000000000000", "Triceps"),
            ("00000029-0000-0000-0000-000000000000", "Upper Back")
        ]

        return stubs.compactMap { stub in
            guard let uuid = UUID(uuidString: stub.uuid) else { return nil }
            let map = mappings.first { $0.name == stub.name }
            let malePrimary = map?.male.primary
            let maleSecondary = map?.male.secondary
            // Store both male and female in the primary/secondary slots using male as the default;
            // the UI swaps between them based on selectedBodyOption at display time.
            // We embed both via the JSON so the model holds both option sets.
            // For simplicity we store male in primaryImageAssetName and female in secondaryImageAssetName
            // only when there's no front/back distinction. For muscles that have both front AND back
            // (Delts, Traps, Full Body) we use the MuscleImageAssets helper at display time.
            return MuscleGroup(
                id: uuid,
                name: stub.name,
                primaryImageAssetName: malePrimary,
                secondaryImageAssetName: maleSecondary
            )
        }
    }

    // MARK: - JSON loader

    /// Returns all mappings from muscle_images.json, or empty array if missing/malformed.
    public func loadImageMappings() -> [(name: String, male: (primary: String?, secondary: String?), female: (primary: String?, secondary: String?))] {
        guard let url = Bundle.main.url(forResource: "muscle_images", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(MuscleImageMappingFile.self, from: data)
        else { return [] }
        return file.mappings.map { m in
            (name: m.name,
             male: (primary: m.male.primary, secondary: m.male.secondary),
             female: (primary: m.female.primary, secondary: m.female.secondary))
        }
    }

    /// Returns the male and female image pairs for a given muscle name from the JSON.
    public func imagePairs(for muscleName: String) -> (male: (primary: String?, secondary: String?), female: (primary: String?, secondary: String?))? {
        loadImageMappings().first { $0.name == muscleName }.map { m in
            (male: (primary: m.male.primary, secondary: m.male.secondary),
             female: (primary: m.female.primary, secondary: m.female.secondary))
        }
    }
}
