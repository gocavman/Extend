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
    private let userWeightKgKey          = "hk_userWeightKg"
    private let userWeightUnitKey        = "hk_userWeightUnit"
    private let useWatchSessionKey       = "hk_useWatchWorkoutSession"
    private let importCutoffDateKey      = "hk_importCutoffDate"

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

    /// User body weight in kilograms. 0 means "not set" (calorie estimate falls back to ~70kg baseline).
    public var userWeightKg: Double {
        didSet { hkDefaults.set(userWeightKg, forKey: userWeightKgKey) }
    }

    /// Display unit for the weight input UI ("kg" or "lb"). Storage is always kg.
    public var userWeightUnit: String {
        didSet { hkDefaults.set(userWeightUnit, forKey: userWeightUnitKey) }
    }

    /// Route workouts through a live Apple Watch HKWorkoutSession when the
    /// watch is reachable. Produces a single authoritative HKWorkout with real
    /// heart rate / calories instead of an iPhone-side estimate plus a
    /// potential duplicate from a native Watch session.
    public var useWatchWorkoutSession: Bool {
        didSet { hkDefaults.set(useWatchWorkoutSession, forKey: useWatchSessionKey) }
    }

    /// Floor for the HealthKit import window. When set (typically by "Erase
    /// All Data"), `importFromHealthKit` refuses to pull samples that ended
    /// before this date, so historical HK workouts don't resurrect on the
    /// next import — even if the user opts import back on after wiping the
    /// app. `nil` means no floor (default fresh-install behavior: import the
    /// last year).
    public var importCutoffDate: Date? {
        didSet {
            if let date = importCutoffDate {
                hkDefaults.set(date, forKey: importCutoffDateKey)
            } else {
                hkDefaults.removeObject(forKey: importCutoffDateKey)
            }
        }
    }

    // MARK: - Init

    private init() {
        // Default-ON for fresh installs so granting Health permission at
        // first launch immediately produces useful behavior — workouts get
        // exported, no second Settings trip required. Existing users with
        // a stored value (true or false) are unaffected.
        exportStrengthWorkouts = hkDefaults.object(forKey: exportStrengthKey) as? Bool ?? true

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
        userWeightKg           = hkDefaults.object(forKey: userWeightKgKey)   as? Double ?? 0
        userWeightUnit         = hkDefaults.object(forKey: userWeightUnitKey) as? String ?? "lb"
        useWatchWorkoutSession = hkDefaults.object(forKey: useWatchSessionKey) as? Bool ?? true
        importCutoffDate       = hkDefaults.object(forKey: importCutoffDateKey) as? Date
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
        // Zero-out import types so the reset actually stays reset. Previous
        // behavior restored `defaultImportActivityTypes` (every type), which
        // meant the very next launch would silently re-import a year of HK
        // history the user had just wiped.
        importActivityTypes    = []
        lastImportDate         = nil
        authorizationRequested = false
        userWeightKg           = 0
        userWeightUnit         = "lb"
        useWatchWorkoutSession = true
        // Watermark HK import: even if the user opts import back on later,
        // only samples that ended after this instant are eligible. Prevents
        // historical HK workouts (that were tombstoned before the wipe)
        // from resurrecting.
        importCutoffDate       = Date()
    }
}
