////
////  HealthKitState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 5/20/26.
////

import Foundation
import HealthKit
import Observation

private let hkDefaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// Stores user preferences for Apple Health sync.
/// Actual HKHealthStore operations live in HealthKitService.
@Observable
public final class HealthKitState {
    public static let shared = HealthKitState()

    // MARK: - Preference keys
    private let exportStrengthKey        = "hk_exportStrength"
    private let importActivityTypesKey   = "hk_importActivityTypes"
    private let lastImportDateKey        = "hk_lastImportDate"
    private let authRequestedKey         = "hk_authRequested"

    // MARK: - Default imported activity types (raw UInt values)
    /// All activity types enabled by default.
    public static let defaultImportActivityTypes: Set<UInt> = Set(
        HKWorkoutActivityTypeHelper.allCases.map { $0.rawValue }
    )

    // MARK: - Preferences

    /// Export completed strength workouts to Apple Health
    public var exportStrengthWorkouts: Bool {
        didSet { hkDefaults.set(exportStrengthWorkouts, forKey: exportStrengthKey) }
    }

    /// Set of HKWorkoutActivityType raw values to import from Apple Health
    public var importActivityTypes: Set<UInt> {
        didSet {
            hkDefaults.set(Array(importActivityTypes), forKey: importActivityTypesKey)
        }
    }

    /// Date of the last successful import run
    public var lastImportDate: Date? {
        didSet {
            if let date = lastImportDate {
                hkDefaults.set(date, forKey: lastImportDateKey)
            } else {
                hkDefaults.removeObject(forKey: lastImportDateKey)
            }
        }
    }

    /// Whether we have already requested HealthKit authorization on this device
    public var authorizationRequested: Bool {
        didSet { hkDefaults.set(authorizationRequested, forKey: authRequestedKey) }
    }

    // MARK: - Init

    private init() {
        exportStrengthWorkouts = hkDefaults.object(forKey: exportStrengthKey) as? Bool ?? false

        if let stored = hkDefaults.object(forKey: "hk_importActivityTypes") as? [UInt] {
            importActivityTypes = Set(stored)
        } else if hkDefaults.object(forKey: "hk_importRunning") != nil {
            // Migrate from old individual boolean keys
            var migrated = Set<UInt>()
            if hkDefaults.bool(forKey: "hk_importRunning")  { migrated.insert(HKWorkoutActivityType.running.rawValue) }
            if hkDefaults.bool(forKey: "hk_importCycling")  { migrated.insert(HKWorkoutActivityType.cycling.rawValue) }
            if hkDefaults.bool(forKey: "hk_importRowing")   { migrated.insert(HKWorkoutActivityType.rowing.rawValue) }
            if hkDefaults.bool(forKey: "hk_importWalking")  {
                migrated.insert(HKWorkoutActivityType.walking.rawValue)
                migrated.insert(HKWorkoutActivityType.hiking.rawValue)
            }
            importActivityTypes = migrated
        } else {
            importActivityTypes = HealthKitState.defaultImportActivityTypes
        }

        lastImportDate         = hkDefaults.object(forKey: lastImportDateKey) as? Date
        authorizationRequested = hkDefaults.object(forKey: authRequestedKey)  as? Bool ?? false
    }

    // MARK: - Computed

    /// True if at least one import activity type is enabled
    public var anyImportEnabled: Bool {
        !importActivityTypes.isEmpty
    }

    /// Whether a specific activity type (by raw value) is enabled for import
    public func isImporting(_ rawValue: UInt) -> Bool {
        importActivityTypes.contains(rawValue)
    }

    /// Toggle import on/off for a specific activity type
    public func toggleImport(_ rawValue: UInt) {
        if importActivityTypes.contains(rawValue) {
            importActivityTypes.remove(rawValue)
        } else {
            importActivityTypes.insert(rawValue)
        }
    }

    // MARK: - Reset

    public func resetAll() {
        exportStrengthWorkouts = false
        importActivityTypes    = HealthKitState.defaultImportActivityTypes
        lastImportDate         = nil
        authorizationRequested = false
    }
}
