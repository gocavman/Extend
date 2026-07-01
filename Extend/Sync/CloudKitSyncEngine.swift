////
////  CloudKitSyncEngine.swift
////  Extend
////
////  Lightweight CloudKit sync layer that mirrors each state type as a single
////  CKRecord whose payload field is a CKAsset (JSON file). The existing
////  UserDefaults + JSON pattern stays untouched; CloudKit is purely additive.
////

import Foundation
import CloudKit
import Observation

// MARK: - Payload wrapper structs

/// Bundles workouts array + favorites so they stay atomically in sync.
struct WorkoutsPayload: Codable {
    var workouts: [Workout]
    var favoriteIDs: [UUID]
}

/// Bundles water logs + goal + unit for atomic sync.
struct WaterPayload: Codable {
    var logs: [WaterLog]
    var goalOz: Double
    var unit: WaterUnit
}

/// Bundles training plans + active plan IDs for atomic sync.
/// `activePlanID` (legacy single-id) is preserved for older app versions
/// that only know about one active plan; new builds prefer `activePlanIDs`.
struct TrainingPlanPayload: Codable {
    var plans: [TrainingPlan]
    var activePlanID: UUID?
    var activePlanIDs: [UUID]?
}

/// Bundles all ModuleState UI preference fields for atomic sync.
struct UIPreferencesPayload: Codable {
    var topNavBarModules: [String]          // UUID strings
    var bottomNavBarModules: [String]       // UUID strings
    var navBarBackgroundColor: RGBAColor?
    var navBarTextColor: RGBAColor?
    var navBarUseGradient: Bool
    var navBarGradientSecondaryColor: RGBAColor?
    var navBarGradientDirection: String?    // GradientDirection rawValue
    var dashboardBackgroundColor: RGBAColor?
    var dashboardBackgroundColorUserSet: Bool
    var dashboardUseGradient: Bool
    var dashboardGradientSecondaryColor: RGBAColor?
    var dashboardGradientDirection: String?
    var dashboardTileBackgroundColor: RGBAColor?
    var dashboardTileBorderColor: RGBAColor?
    var dashboardTileColorsUserSet: Bool

    struct RGBAColor: Codable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double
    }
}

// MARK: - SyncKey

/// Maps each logical data type to its stable CloudKit record name and local defaults key.
enum SyncKey: String, CaseIterable {
    case workoutLogs             = "extend_workout_logs"
    case journalEntries          = "extend_journal_entries"
    case workouts                = "extend_workouts"
    case waterLogs               = "extend_water_logs"
    case exercises               = "extend_exercises"
    case muscleGroups            = "extend_muscle_groups"
    case equipment               = "extend_equipment"
    case gear                    = "extend_gear"
    case trainingPlans           = "extend_training_plans"
    case dashboardTiles          = "extend_dashboard_tiles"
    case timerConfigs            = "extend_timer_configs"
    case voiceTrainerConfigs     = "extend_voice_trainer_configs"
    case generateFilterPresets   = "extend_generate_filter_presets"
    case uiPreferences           = "extend_ui_preferences"
    case deletedHealthKitWorkoutUUIDs = "extend_deleted_hk_workout_uuids"
    case deletedHealthKitWaterUUIDs   = "extend_deleted_hk_water_uuids"

    /// The CloudKit record type name (must match the CloudKit Dashboard schema).
    var recordType: String {
        switch self {
        case .workoutLogs:                  return "WorkoutLogs"
        case .journalEntries:               return "JournalEntries"
        case .workouts:                     return "Workouts"
        case .waterLogs:                    return "WaterLogs"
        case .exercises:                    return "Exercises"
        case .muscleGroups:                 return "MuscleGroups"
        case .equipment:                    return "Equipment"
        case .gear:                         return "Gear"
        case .trainingPlans:                return "TrainingPlans"
        case .dashboardTiles:               return "DashboardTiles"
        case .timerConfigs:                 return "TimerConfigs"
        case .voiceTrainerConfigs:          return "VoiceTrainerConfigs"
        case .generateFilterPresets:        return "GenerateFilterPresets"
        case .uiPreferences:                return "UIPreferences"
        case .deletedHealthKitWorkoutUUIDs: return "DeletedHKWorkoutUUIDs"
        case .deletedHealthKitWaterUUIDs:   return "DeletedHKWaterUUIDs"
        }
    }

    /// The stable CKRecord name used as the record identifier — one record per type per user.
    var recordName: String { rawValue }
}

// MARK: - CloudKitSyncEngine

@Observable
final class CloudKitSyncEngine {

    static let shared = CloudKitSyncEngine()

    // MARK: - State (bindable in UI)

    var isSyncing: Bool = false
    var lastSyncDate: Date? = nil
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var syncError: String? = nil

    // MARK: - Private

    private let container = CKContainer(identifier: "iCloud.com.cavanmannenbach.extend")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

    /// Debounce tasks keyed by SyncKey.rawValue
    private var pendingPushTasks: [String: Task<Void, Never>] = [:]

    /// Persisted timestamps of the last push per record name, used for conflict resolution.
    private var lastPushTimestamps: [String: Date] {
        get {
            guard let data = defaults.data(forKey: "ck_last_push_timestamps"),
                  let dict = try? JSONDecoder().decode([String: Date].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "ck_last_push_timestamps")
            }
        }
    }

    private init() {
        // Re-check account status whenever iCloud account changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.start() }
        }
    }

    // MARK: - Public API

    /// Call once on app launch and on every foreground transition. Checks
    /// account status, then pulls all data. We don't use CKQuerySubscriptions
    /// for cross-device sync because they require queryable indexes per record
    /// type that don't reliably propagate from Dev → Prod, and even when they
    /// do, query subscriptions are the most-restricted subscription kind in
    /// production. Pull-on-foreground is good enough for a personal app where
    /// you re-open it on each device anyway.
    /// Retries the account-status check a few times when the initial call
    /// returns `.couldNotDetermine` — on a fresh install the system can need
    /// a moment to resolve the iCloud account before CloudKit is ready, and
    /// `.CKAccountChanged` doesn't fire in that case (it only fires when the
    /// signed-in account actually changes), so without the retry the engine
    /// silently sits out the whole launch.
    func start() async {
        for attempt in 0..<5 {
            do {
                accountStatus = try await container.accountStatus()
                syncError = nil
            } catch {
                accountStatus = .couldNotDetermine
                syncError = error.localizedDescription
            }
            if accountStatus != .couldNotDetermine { break }
            try? await Task.sleep(for: .seconds(1 << attempt))   // 1s, 2s, 4s, 8s, 16s
        }

        guard accountStatus == .available else { return }

        await pullAll()
    }

    /// Manual re-sync entry point for the user (Settings → "Sync Now").
    /// Re-checks the iCloud account first in case it became available since
    /// the last attempt, then triggers a full pull. Safe to call repeatedly;
    /// `isSyncing` gates the UI's spinner.
    func forceSync() async {
        await start()
    }

    /// Debounced push — waits 2 seconds after the last call before writing to CloudKit.
    /// Called from each state's save function.
    func push(_ key: SyncKey) {
        guard accountStatus == .available else { return }
        pendingPushTasks[key.rawValue]?.cancel()
        pendingPushTasks[key.rawValue] = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await pushRecord(for: key)
        }
    }

    /// Variant for UI preferences — respects the user's opt-out toggle.
    func pushUIPreferences() {
        guard defaults.object(forKey: "ck_sync_ui_prefs") as? Bool ?? true else { return }
        push(.uiPreferences)
    }

    /// Push a custom image (exercise or muscle group) to CloudKit.
    func pushImage(data: Data, recordName: String, fields: [String: CKRecordValue]) {
        guard accountStatus == .available else { return }
        Task {
            await pushImageRecord(data: data, recordName: recordName, fields: fields)
        }
    }

    // MARK: - Pull all

    private func pullAll() async {
        isSyncing = true
        defer { isSyncing = false }

        await withTaskGroup(of: Void.self) { group in
            for key in SyncKey.allCases {
                group.addTask { await self.pullRecord(for: key) }
            }
            group.addTask { await self.pullAllImages() }
        }

        await MainActor.run {
            lastSyncDate = Date()
        }
    }

    // MARK: - Push record

    private func pushRecord(for key: SyncKey) async {
        guard accountStatus == .available else { return }

        guard let payload = buildPayload(for: key) else { return }

        // Write payload to a temp file for CKAsset
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(key.rawValue + "_\(Int(Date().timeIntervalSince1970)).json")

        do {
            try payload.write(to: tempURL)
        } catch {
            syncError = "Failed to write temp file: \(error.localizedDescription)"
            return
        }

        defer { try? FileManager.default.removeItem(at: tempURL) }

        let recordID = CKRecord.ID(recordName: key.recordName)
        let asset = CKAsset(fileURL: tempURL)
        let now = Date()

        do {
            // Try to fetch existing record to get the correct change tag
            let existingRecord: CKRecord
            do {
                existingRecord = try await privateDB.record(for: recordID)
            } catch let fetchError as CKError where fetchError.code == .unknownItem {
                // No existing record — create fresh
                let newRecord = CKRecord(recordType: key.recordType, recordID: recordID)
                newRecord["payload"] = asset
                newRecord["modifiedAt"] = now as CKRecordValue
                try await privateDB.save(newRecord)
                updateLastPushTimestamp(key.recordName, date: now)
                return
            }

            // Update existing record
            existingRecord["payload"] = asset
            existingRecord["modifiedAt"] = now as CKRecordValue
            try await privateDB.save(existingRecord)
            updateLastPushTimestamp(key.recordName, date: now)

        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            // Conflict: server has a newer version — pull instead of overwriting
            await pullRecord(for: key)
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Pull record

    private func pullRecord(for key: SyncKey) async {
        guard accountStatus == .available else { return }

        let recordID = CKRecord.ID(recordName: key.recordName)
        do {
            let record = try await privateDB.record(for: recordID)

            guard let asset = record["payload"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let data = try? Data(contentsOf: fileURL)
            else { return }

            // Conflict guard: skip if we pushed more recently than the server version
            let serverDate = record["modifiedAt"] as? Date ?? Date.distantPast
            let timestamps = lastPushTimestamps
            if let lastPush = timestamps[key.recordName], lastPush > serverDate {
                // Our local version is newer — push ours instead
                await pushRecord(for: key)
                return
            }

            applyPayload(data, for: key)
            notifyStateToReload(key: key)

        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Record doesn't exist on server yet — seed it from local data
            await pushRecord(for: key)
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Image push/pull

    private func pushImageRecord(data: Data, recordName: String, fields: [String: CKRecordValue]) async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(recordName + "_\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: tempURL)
        } catch { return }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let recordID = CKRecord.ID(recordName: recordName)
        let asset = CKAsset(fileURL: tempURL)

        do {
            let record: CKRecord
            do {
                record = try await privateDB.record(for: recordID)
            } catch let e as CKError where e.code == .unknownItem {
                // Determine record type from prefix
                let type_ = recordName.hasPrefix("exercise_image_") ? "ExerciseImages" : "MuscleImages"
                let newRecord = CKRecord(recordType: type_, recordID: recordID)
                newRecord["imageData"] = asset
                for (k, v) in fields { newRecord[k] = v }
                newRecord["modifiedAt"] = Date() as CKRecordValue
                try await privateDB.save(newRecord)
                return
            }
            record["imageData"] = asset
            for (k, v) in fields { record[k] = v }
            record["modifiedAt"] = Date() as CKRecordValue
            try await privateDB.save(record)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func pullAllImages() async {
        guard accountStatus == .available else { return }
        await pullImageType(recordType: "ExerciseImages", isExercise: true)
        await pullImageType(recordType: "MuscleImages", isExercise: false)
    }

    private func pullImageType(recordType: String, isExercise: Bool) async {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        do {
            let (results, _) = try await privateDB.records(matching: query)
            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                guard let asset = record["imageData"] as? CKAsset,
                      let fileURL = asset.fileURL,
                      let data = try? Data(contentsOf: fileURL) else { continue }

                if isExercise {
                    guard let exerciseID = record["exerciseID"] as? String else { continue }
                    let destURL = Exercise.imageStorageDirectory
                        .appendingPathComponent("exercise_\(exerciseID).png")
                    if !FileManager.default.fileExists(atPath: destURL.path) {
                        try? data.write(to: destURL, options: .atomic)
                        // Notify exercises state to reload image cache
                        await MainActor.run { ExercisesState.shared.reloadImageCache() }
                    }
                } else {
                    guard let muscleID = record["muscleID"] as? String,
                          let slot = record["slot"] as? String else { continue }
                    let filename = "muscle_\(muscleID)_\(slot).png"
                    let destURL = MuscleGroup.imageStorageDirectory
                        .appendingPathComponent(filename)
                    if !FileManager.default.fileExists(atPath: destURL.path) {
                        try? data.write(to: destURL, options: .atomic)
                    }
                }
            }
        } catch {
            // Non-fatal: images will sync on next launch
        }
    }

    // MARK: - Payload building (local defaults → Data)

    private func buildPayload(for key: SyncKey) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        switch key {
        case .workoutLogs:
            return defaults.data(forKey: "workout_logs")

        case .journalEntries:
            return defaults.data(forKey: "journal_entries")

        case .workouts:
            guard let workoutsData = defaults.data(forKey: "workouts_data") else { return nil }
            // Decode workouts array, bundle with favorites
            guard let workouts = try? JSONDecoder().decode([Workout].self, from: workoutsData) else { return nil }
            let favoritesData = defaults.data(forKey: "workouts_favorites") ?? Data()
            let favoriteIDs = (try? JSONDecoder().decode([UUID].self, from: favoritesData)) ?? []
            let payload = WorkoutsPayload(workouts: workouts, favoriteIDs: favoriteIDs)
            return try? encoder.encode(payload)

        case .waterLogs:
            let logsData = defaults.data(forKey: "water_logs") ?? Data()
            let logs = (try? JSONDecoder().decode([WaterLog].self, from: logsData)) ?? []
            let goalOz = defaults.object(forKey: "water_daily_goal_oz") as? Double ?? 64.0
            let unitRaw = defaults.string(forKey: "water_unit") ?? WaterUnit.oz.rawValue
            let unit = WaterUnit(rawValue: unitRaw) ?? .oz
            let payload = WaterPayload(logs: logs, goalOz: goalOz, unit: unit)
            return try? encoder.encode(payload)

        case .exercises:
            return defaults.data(forKey: "exercises_data")

        case .muscleGroups:
            return defaults.data(forKey: "muscle_groups")

        case .equipment:
            return defaults.data(forKey: "equipment_items")

        case .gear:
            return defaults.data(forKey: "gear_items")

        case .trainingPlans:
            guard let plansData = defaults.data(forKey: "training_plans_data") else { return nil }
            guard let plans = try? JSONDecoder().decode([TrainingPlan].self, from: plansData) else { return nil }
            let activeIDStr = defaults.string(forKey: "training_active_plan_id")
            let activeID = activeIDStr.flatMap { UUID(uuidString: $0) }
            let activeIDs: [UUID] = {
                guard let data = defaults.data(forKey: "training_active_plan_ids"),
                      let strs = try? JSONDecoder().decode([String].self, from: data) else { return [] }
                return strs.compactMap { UUID(uuidString: $0) }
            }()
            let payload = TrainingPlanPayload(plans: plans,
                                              activePlanID: activeID,
                                              activePlanIDs: activeIDs.isEmpty ? nil : activeIDs)
            return try? encoder.encode(payload)

        case .dashboardTiles:
            return defaults.data(forKey: "dashboard_tiles")

        case .timerConfigs:
            return defaults.data(forKey: "timer_configs")

        case .voiceTrainerConfigs:
            return defaults.data(forKey: "VoiceTrainerConfigs")

        case .generateFilterPresets:
            return defaults.data(forKey: "generate_filter_presets")

        case .uiPreferences:
            return buildUIPreferencesPayload()

        case .deletedHealthKitWorkoutUUIDs:
            return defaults.data(forKey: "deleted_hk_workout_uuids")

        case .deletedHealthKitWaterUUIDs:
            return defaults.data(forKey: "deleted_hk_water_uuids")
        }
    }

    private func buildUIPreferencesPayload() -> Data? {
        func loadRGBA(key: String) -> UIPreferencesPayload.RGBAColor? {
            guard let data = defaults.data(forKey: key),
                  let stored = try? JSONDecoder().decode(_StoredRGBA.self, from: data)
            else { return nil }
            return UIPreferencesPayload.RGBAColor(
                red: stored.red, green: stored.green,
                blue: stored.blue, alpha: stored.alpha
            )
        }

        let payload = UIPreferencesPayload(
            topNavBarModules: defaults.stringArray(forKey: "topNavBarModules") ?? [],
            bottomNavBarModules: defaults.stringArray(forKey: "bottomNavBarModules") ?? [],
            navBarBackgroundColor: loadRGBA(key: "navBarBackgroundColor"),
            navBarTextColor: loadRGBA(key: "navBarTextColor"),
            navBarUseGradient: defaults.bool(forKey: "navBarUseGradient"),
            navBarGradientSecondaryColor: loadRGBA(key: "navBarGradientSecondaryColor"),
            navBarGradientDirection: defaults.string(forKey: "navBarGradientDirection"),
            dashboardBackgroundColor: loadRGBA(key: "dashboardBackgroundColor"),
            dashboardBackgroundColorUserSet: defaults.bool(forKey: "dashboardBackgroundColorUserSet"),
            dashboardUseGradient: defaults.bool(forKey: "dashboardUseGradient"),
            dashboardGradientSecondaryColor: loadRGBA(key: "dashboardGradientSecondaryColor"),
            dashboardGradientDirection: defaults.string(forKey: "dashboardGradientDirection"),
            dashboardTileBackgroundColor: loadRGBA(key: "dashboardTileBackgroundColor"),
            dashboardTileBorderColor: loadRGBA(key: "dashboardTileBorderColor"),
            dashboardTileColorsUserSet: defaults.bool(forKey: "dashboardTileColorsUserSet")
        )
        return try? JSONEncoder().encode(payload)
    }

    // MARK: - Payload applying (Data → local defaults)

    private func applyPayload(_ data: Data, for key: SyncKey) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch key {
        case .workoutLogs:
            defaults.set(data, forKey: "workout_logs")

        case .journalEntries:
            defaults.set(data, forKey: "journal_entries")

        case .workouts:
            guard let payload = try? decoder.decode(WorkoutsPayload.self, from: data) else { return }
            if let encoded = try? JSONEncoder().encode(payload.workouts) {
                defaults.set(encoded, forKey: "workouts_data")
            }
            if let encoded = try? JSONEncoder().encode(payload.favoriteIDs) {
                defaults.set(encoded, forKey: "workouts_favorites")
            }

        case .waterLogs:
            guard let payload = try? decoder.decode(WaterPayload.self, from: data) else { return }
            if let encoded = try? JSONEncoder().encode(payload.logs) {
                defaults.set(encoded, forKey: "water_logs")
            }
            defaults.set(payload.goalOz, forKey: "water_daily_goal_oz")
            defaults.set(payload.unit.rawValue, forKey: "water_unit")

        case .exercises:
            defaults.set(data, forKey: "exercises_data")

        case .muscleGroups:
            defaults.set(data, forKey: "muscle_groups")

        case .equipment:
            defaults.set(data, forKey: "equipment_items")

        case .gear:
            defaults.set(data, forKey: "gear_items")

        case .trainingPlans:
            guard let payload = try? decoder.decode(TrainingPlanPayload.self, from: data) else { return }
            if let encoded = try? JSONEncoder().encode(payload.plans) {
                defaults.set(encoded, forKey: "training_plans_data")
            }
            // Prefer the new multi-active list; fall back to the legacy
            // single id so syncs from older app versions still land.
            let mergedIDs: [UUID] = payload.activePlanIDs ?? payload.activePlanID.map { [$0] } ?? []
            if let encoded = try? JSONEncoder().encode(mergedIDs.map { $0.uuidString }) {
                defaults.set(encoded, forKey: "training_active_plan_ids")
            }
            if let id = mergedIDs.first {
                defaults.set(id.uuidString, forKey: "training_active_plan_id")
            } else {
                defaults.removeObject(forKey: "training_active_plan_id")
                defaults.removeObject(forKey: "training_active_plan_ids")
            }

        case .dashboardTiles:
            defaults.set(data, forKey: "dashboard_tiles")

        case .timerConfigs:
            defaults.set(data, forKey: "timer_configs")

        case .voiceTrainerConfigs:
            defaults.set(data, forKey: "VoiceTrainerConfigs")

        case .generateFilterPresets:
            defaults.set(data, forKey: "generate_filter_presets")

        case .uiPreferences:
            applyUIPreferencesPayload(data)

        case .deletedHealthKitWorkoutUUIDs:
            defaults.set(data, forKey: "deleted_hk_workout_uuids")

        case .deletedHealthKitWaterUUIDs:
            defaults.set(data, forKey: "deleted_hk_water_uuids")
        }
    }

    private func applyUIPreferencesPayload(_ data: Data) {
        guard let payload = try? JSONDecoder().decode(UIPreferencesPayload.self, from: data) else { return }

        func saveRGBA(_ color: UIPreferencesPayload.RGBAColor?, key: String) {
            if let c = color,
               let encoded = try? JSONEncoder().encode(_StoredRGBA(
                red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)) {
                defaults.set(encoded, forKey: key)
            }
        }

        defaults.set(payload.topNavBarModules, forKey: "topNavBarModules")
        defaults.set(payload.bottomNavBarModules, forKey: "bottomNavBarModules")
        saveRGBA(payload.navBarBackgroundColor, key: "navBarBackgroundColor")
        saveRGBA(payload.navBarTextColor, key: "navBarTextColor")
        defaults.set(payload.navBarUseGradient, forKey: "navBarUseGradient")
        saveRGBA(payload.navBarGradientSecondaryColor, key: "navBarGradientSecondaryColor")
        if let dir = payload.navBarGradientDirection {
            defaults.set(dir, forKey: "navBarGradientDirection")
        }
        if payload.dashboardBackgroundColorUserSet {
            saveRGBA(payload.dashboardBackgroundColor, key: "dashboardBackgroundColor")
            defaults.set(true, forKey: "dashboardBackgroundColorUserSet")
        }
        defaults.set(payload.dashboardUseGradient, forKey: "dashboardUseGradient")
        saveRGBA(payload.dashboardGradientSecondaryColor, key: "dashboardGradientSecondaryColor")
        if let dir = payload.dashboardGradientDirection {
            defaults.set(dir, forKey: "dashboardGradientDirection")
        }
        if payload.dashboardTileColorsUserSet {
            saveRGBA(payload.dashboardTileBackgroundColor, key: "dashboardTileBackgroundColor")
            saveRGBA(payload.dashboardTileBorderColor, key: "dashboardTileBorderColor")
            defaults.set(true, forKey: "dashboardTileColorsUserSet")
        }
    }

    // MARK: - State reload dispatch

    @MainActor
    private func notifyStateToReload(key: SyncKey) {
        switch key {
        case .workoutLogs:
            WorkoutLogState.shared.reloadFromDefaults()
        case .journalEntries:
            WorkoutLogState.shared.reloadJournalFromDefaults()
        case .workouts:
            WorkoutsState.shared.reloadFromDefaults()
        case .waterLogs:
            WaterState.shared.reloadFromDefaults()
        case .exercises:
            ExercisesState.shared.reloadFromDefaults()
        case .muscleGroups:
            MuscleGroupsState.shared.reloadFromDefaults()
        case .equipment:
            EquipmentState.shared.reloadFromDefaults()
        case .gear:
            GearState.shared.reloadFromDefaults()
        case .trainingPlans:
            TrainingPlanState.shared.reloadFromDefaults()
            TrainingPlanState.shared.refreshWidgetSnapshot()
        case .dashboardTiles:
            DashboardState.shared.reloadFromDefaults()
        case .timerConfigs:
            TimerState.shared.reloadFromDefaults()
        case .voiceTrainerConfigs:
            VoiceTrainerState.shared.reloadFromDefaults()
        case .generateFilterPresets:
            GenerateState.shared.reloadFromDefaults()
        case .uiPreferences:
            ModuleState.shared.reloadFromDefaults()
        case .deletedHealthKitWorkoutUUIDs:
            WorkoutLogState.shared.reloadDeletedHealthKitUUIDsFromDefaults()
        case .deletedHealthKitWaterUUIDs:
            WaterState.shared.reloadDeletedHealthKitUUIDsFromDefaults()
        }
    }

    // MARK: - Helpers

    private func updateLastPushTimestamp(_ recordName: String, date: Date) {
        var timestamps = lastPushTimestamps
        timestamps[recordName] = date
        lastPushTimestamps = timestamps
    }
}

// MARK: - Internal color storage helper (mirrors ModuleState's NavBarRGBAColor)

private struct _StoredRGBA: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}
