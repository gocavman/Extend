////
////  ExercisesState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import Observation
import HealthKit

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// State management for exercises with persistence
@Observable
public final class ExercisesState {
    public static let shared = ExercisesState()
    
    @ObservationIgnored private let userDefaultsKey = "exercises_data"
    
    public var exercises: [Exercise] = []

    // Pending IDs for dashboard deep-linking (same pattern as WorkoutsState)
    public var pendingLaunchID: UUID? = nil
    public var pendingStatsID: UUID? = nil
    public var pendingHistoryID: UUID? = nil

    public var favoriteExercises: [Exercise] {
        exercises.filter { $0.isFavorite }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func toggleFavorite(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index].isFavorite.toggle()
            saveExercises()
        }
    }
    
    private init() {
        loadExercises()
    }
    
    // MARK: - Exercise Management
    
    public func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
        saveExercises()
    }
    
    public func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            saveExercises()
        }
    }
    
    public func removeExercise(id: UUID) {
        // Delete exercise image from disk if one exists
        if let exercise = exercises.first(where: { $0.id == id }),
           let filename = exercise.imageFilename {
            let fileURL = Exercise.imageStorageDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
        exercises.removeAll { $0.id == id }
        saveExercises()
    }
    
    public func resetExercises() {
        exercises = Self.createDefaultExercises()
        saveExercises()
    }
    
    // MARK: - Persistence
    
    private func loadExercises() {
        if let data = defaults.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            // Migrate: backfill defaultEquipmentIDs for exercises that have exactly one equipment
            // and no defaults set yet (newly added field, empty on first decode)
            exercises = decoded.map { ex in
                guard ex.defaultEquipmentIDs.isEmpty, ex.equipmentIDs.count == 1 else { return ex }
                var updated = ex
                updated.defaultEquipmentIDs = ex.equipmentIDs
                return updated
            }
            saveExercises()
        } else {
            exercises = Self.createDefaultExercises()
            saveExercises()
        }
    }
    
    private func saveExercises() {
        if let encoded = try? JSONEncoder().encode(exercises) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        CloudKitSyncEngine.shared.push(.exercises)
        // Keep the Watch Library snapshot in sync — adds/edits/deletes and
        // favorite toggles all flow through here.
        TrainingPlanState.shared.refreshWatchLibrary()
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    public func reloadFromDefaults() {
        loadExercises()
    }

    /// Called by CloudKitSyncEngine after pulling new exercise images from CloudKit.
    public func reloadImageCache() {
        // Trigger observation by re-assigning exercises so any image-backed views refresh.
        exercises = exercises
    }
    
    // MARK: - Default Exercises
    
    private static func createDefaultExercises() -> [Exercise] {
        // Helper: auto-defaults to the single equipment if only one; otherwise uses explicit defaultIDs.
        // Pass a stable `id` for exercises referenced by default workouts so they survive reset.
        func exercise(
            id: UUID = UUID(),
            name: String,
            primaryMuscleGroupIDs: [UUID],
            secondaryMuscleGroupIDs: [UUID] = [],
            equipmentIDs: [UUID],
            defaultEquipmentIDs: [UUID]? = nil,
            hkType: HKWorkoutActivityType? = nil
        ) -> Exercise {
            let defaults: [UUID]
            if let explicit = defaultEquipmentIDs {
                defaults = explicit
            } else if equipmentIDs.count == 1 {
                defaults = equipmentIDs
            } else {
                defaults = []
            }
            return Exercise(
                id: id,
                name: name,
                notes: "",
                primaryMuscleGroupIDs: primaryMuscleGroupIDs,
                secondaryMuscleGroupIDs: secondaryMuscleGroupIDs,
                equipmentIDs: equipmentIDs,
                defaultEquipmentIDs: defaults,
                healthKitActivityType: hkType.map { $0.rawValue }
            )
        }

        // Muscle group UUIDs
        let absID        = UUID(uuidString: "00000020-0000-0000-0000-000000000000")!
        let adductorsID  = UUID(uuidString: "0000002C-0000-0000-0000-000000000000")!
        let bicepsID     = UUID(uuidString: "00000010-0000-0000-0000-000000000000")!
        let calvesID     = UUID(uuidString: "00000019-0000-0000-0000-000000000000")!
        let deltsID      = UUID(uuidString: "00000013-0000-0000-0000-000000000000")!
        let forearmID    = UUID(uuidString: "00000023-0000-0000-0000-000000000000")!
        let fullBodyID   = UUID(uuidString: "0000002A-0000-0000-0000-000000000000")!
        let glutesID     = UUID(uuidString: "00000017-0000-0000-0000-000000000000")!
        let gripID       = UUID(uuidString: "00000024-0000-0000-0000-000000000000")!
        let hamstringsID = UUID(uuidString: "00000018-0000-0000-0000-000000000000")!
        let heartID      = UUID(uuidString: "00000022-0000-0000-0000-000000000000")!
        let latsID       = UUID(uuidString: "00000015-0000-0000-0000-000000000000")!
        let lowerBackID  = UUID(uuidString: "00000026-0000-0000-0000-000000000000")!
        let obliquesID   = UUID(uuidString: "00000021-0000-0000-0000-000000000000")!
        let pecsID       = UUID(uuidString: "00000012-0000-0000-0000-000000000000")!
        let quadsID      = UUID(uuidString: "00000016-0000-0000-0000-000000000000")!
        let rhomboidsID  = UUID(uuidString: "00000028-0000-0000-0000-000000000000")!
        let trapsID      = UUID(uuidString: "00000014-0000-0000-0000-000000000000")!
        let tricepsID    = UUID(uuidString: "00000011-0000-0000-0000-000000000000")!
        let upperBackID  = UUID(uuidString: "00000029-0000-0000-0000-000000000000")!

        // Equipment UUIDs
        let noneID        = UUID(uuidString: "00000100-0000-0000-0000-000000000000")!
        let dumbbellID    = UUID(uuidString: "00000101-0000-0000-0000-000000000000")!
        let barbellID     = UUID(uuidString: "00000102-0000-0000-0000-000000000000")!
        let benchID       = UUID(uuidString: "00000103-0000-0000-0000-000000000000")!
        let pullupBarID   = UUID(uuidString: "00000104-0000-0000-0000-000000000000")!
        let jumpRopeID    = UUID(uuidString: "00000106-0000-0000-0000-000000000000")!
        let kettlebellID  = UUID(uuidString: "00000107-0000-0000-0000-000000000000")!
        let rowerID       = UUID(uuidString: "00000108-0000-0000-0000-000000000000")!
        let assaultBikeID = UUID(uuidString: "00000109-0000-0000-0000-000000000000")!
        let treadmillID   = UUID(uuidString: "0000010A-0000-0000-0000-000000000000")!
        let stairclimberID = UUID(uuidString: "0000010B-0000-0000-0000-000000000000")!
        let ellipticalID  = UUID(uuidString: "0000010C-0000-0000-0000-000000000000")!
        let battleRopesID = UUID(uuidString: "0000010D-0000-0000-0000-000000000000")!
        let abWheelID     = UUID(uuidString: "0000010E-0000-0000-0000-000000000000")!
        let bandsID       = UUID(uuidString: "00000110-0000-0000-0000-000000000000")!
        let ringsID       = UUID(uuidString: "00000111-0000-0000-0000-000000000000")!

        let plyoBoxID        = UUID(uuidString: "00000113-0000-0000-0000-000000000000")!
        let medicineBallID   = UUID(uuidString: "00000114-0000-0000-0000-000000000000")!
        let boxingBagID      = UUID(uuidString: "00000112-0000-0000-0000-000000000000")!
        let bicycleOutID     = UUID(uuidString: "00000115-0000-0000-0000-000000000000")!
        let bicycleStatID    = UUID(uuidString: "00000116-0000-0000-0000-000000000000")!
        let ezCurlBarID      = UUID(uuidString: "00000117-0000-0000-0000-000000000000")!
        let latPulldownMachineID = UUID(uuidString: "00000118-0000-0000-0000-000000000000")!
        let dipStationID     = UUID(uuidString: "00000119-0000-0000-0000-000000000000")!
        let chestPressMachineID = UUID(uuidString: "0000011A-0000-0000-0000-000000000000")!
        let legPressMachineID = UUID(uuidString: "0000011B-0000-0000-0000-000000000000")!
        let legCurlMachineID = UUID(uuidString: "0000011C-0000-0000-0000-000000000000")!
        let legExtMachineID  = UUID(uuidString: "0000011D-0000-0000-0000-000000000000")!
        let sledID           = UUID(uuidString: "0000011E-0000-0000-0000-000000000000")!

        return [
            // A
            exercise(name: "Ab Wheel",             primaryMuscleGroupIDs: [absID],                           secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [abWheelID],                                                                  hkType: .traditionalStrengthTraining),
            exercise(name: "Assault Bike",          primaryMuscleGroupIDs: [heartID, fullBodyID],                                                                   equipmentIDs: [assaultBikeID],                                                              hkType: .cycling),

            // A
            exercise(name: "Arnold Press",          primaryMuscleGroupIDs: [deltsID],                         secondaryMuscleGroupIDs: [tricepsID, trapsID],           equipmentIDs: [dumbbellID],                                                                 hkType: .traditionalStrengthTraining),

            // B
            exercise(name: "Battle Ropes",          primaryMuscleGroupIDs: [deltsID, pecsID],                                                                         equipmentIDs: [battleRopesID],                                                              hkType: .highIntensityIntervalTraining),
            exercise(name: "Bench (Close Grip)",    primaryMuscleGroupIDs: [tricepsID, pecsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID, benchID, chestPressMachineID], defaultEquipmentIDs: [benchID], hkType: .traditionalStrengthTraining),
            exercise(name: "Bench (Decline)",       primaryMuscleGroupIDs: [pecsID, tricepsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID, benchID, chestPressMachineID], defaultEquipmentIDs: [benchID], hkType: .traditionalStrengthTraining),
            exercise(name: "Bench (Incline)",       primaryMuscleGroupIDs: [pecsID, deltsID],                 secondaryMuscleGroupIDs: [tricepsID],                   equipmentIDs: [barbellID, dumbbellID, benchID, chestPressMachineID], defaultEquipmentIDs: [benchID], hkType: .traditionalStrengthTraining),
            exercise(name: "Bench (Regular)",       primaryMuscleGroupIDs: [pecsID, tricepsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID, benchID, chestPressMachineID], defaultEquipmentIDs: [benchID], hkType: .traditionalStrengthTraining),
            exercise(name: "Bicep Curls",           primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID, barbellID, ezCurlBarID], defaultEquipmentIDs: [dumbbellID],          hkType: .traditionalStrengthTraining),
            exercise(name: "Bulgarian Split Squats",primaryMuscleGroupIDs: [quadsID, glutesID, adductorsID],  secondaryMuscleGroupIDs: [hamstringsID, calvesID, absID],equipmentIDs: [dumbbellID, benchID, noneID],                                                    hkType: .traditionalStrengthTraining),
            exercise(name: "Sumo Squat",            primaryMuscleGroupIDs: [adductorsID, glutesID, quadsID], secondaryMuscleGroupIDs: [hamstringsID, calvesID, absID, obliquesID, lowerBackID], equipmentIDs: [barbellID, dumbbellID, kettlebellID, noneID], hkType: .traditionalStrengthTraining),
            exercise(name: "Box Jumps",             primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [calvesID, hamstringsID],      equipmentIDs: [plyoBoxID],                                                                  hkType: .highIntensityIntervalTraining),
            exercise(name: "Boxing",                primaryMuscleGroupIDs: [heartID],                                                                                 equipmentIDs: [noneID, boxingBagID],                                                        hkType: .boxing),
            exercise(name: "Burpees",               primaryMuscleGroupIDs: [pecsID, quadsID],                 secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [noneID],                                                                     hkType: .highIntensityIntervalTraining),
            exercise(name: "Ball Slams",            primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [medicineBallID],                                                              hkType: .highIntensityIntervalTraining),

            // C
            exercise(name: "Calf Raises",           primaryMuscleGroupIDs: [calvesID],                                                                                equipmentIDs: [dumbbellID, barbellID, noneID],                                               hkType: .traditionalStrengthTraining),
            exercise(name: "Chest Flies",           primaryMuscleGroupIDs: [pecsID],                          secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [dumbbellID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Chin Ups",              primaryMuscleGroupIDs: [bicepsID, latsID],                                                                        equipmentIDs: [pullupBarID],                                                                hkType: .traditionalStrengthTraining),
            exercise(name: "Concentration Curls",   primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Clean and Jerk",        primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [barbellID],                                                                  hkType: .traditionalStrengthTraining),
            exercise(name: "Crunches",              primaryMuscleGroupIDs: [absID],                                                                                    equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Cycling",               primaryMuscleGroupIDs: [heartID],                         secondaryMuscleGroupIDs: [quadsID, hamstringsID],       equipmentIDs: [bicycleOutID, bicycleStatID],                                                 hkType: .cycling),

            // D
            exercise(name: "Deadlift",              primaryMuscleGroupIDs: [hamstringsID, glutesID],          secondaryMuscleGroupIDs: [latsID, trapsID],             equipmentIDs: [barbellID, dumbbellID, kettlebellID], defaultEquipmentIDs: [barbellID],      hkType: .traditionalStrengthTraining),
            exercise(name: "Dead Hang",             primaryMuscleGroupIDs: [upperBackID],                     secondaryMuscleGroupIDs: [latsID, forearmID],           equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID],          hkType: .traditionalStrengthTraining),
            exercise(name: "Dips",                  primaryMuscleGroupIDs: [tricepsID, pecsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [noneID, benchID, ringsID, dipStationID],                                     hkType: .traditionalStrengthTraining),

            // E
            exercise(name: "Elliptical",            primaryMuscleGroupIDs: [quadsID, hamstringsID],                                                                   equipmentIDs: [ellipticalID],                                                               hkType: .elliptical),

            // F
            exercise(name: "Farmer's Carry",        primaryMuscleGroupIDs: [gripID, forearmID, deltsID],      secondaryMuscleGroupIDs: [absID, quadsID, glutesID],    equipmentIDs: [dumbbellID, kettlebellID],                                                    hkType: .traditionalStrengthTraining),
            exercise(name: "Face Pulls",            primaryMuscleGroupIDs: [deltsID, trapsID],                secondaryMuscleGroupIDs: [rhomboidsID],                 equipmentIDs: [bandsID],                                                                    hkType: .traditionalStrengthTraining),
            exercise(name: "Floor Press",            primaryMuscleGroupIDs: [pecsID],                          secondaryMuscleGroupIDs: [deltsID, tricepsID],          equipmentIDs: [barbellID, dumbbellID],           defaultEquipmentIDs: [dumbbellID],            hkType: .traditionalStrengthTraining),
            exercise(name: "Front Raises",          primaryMuscleGroupIDs: [deltsID],                         secondaryMuscleGroupIDs: [pecsID],                      equipmentIDs: [dumbbellID, barbellID],                                                       hkType: .traditionalStrengthTraining),

            // G
            exercise(name: "Goblet Squat",          primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID, absID, calvesID],equipmentIDs: [kettlebellID, dumbbellID],        defaultEquipmentIDs: [kettlebellID],           hkType: .traditionalStrengthTraining),

            // H
            exercise(name: "Hammer Curls",          primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Hiking",                primaryMuscleGroupIDs: [heartID],                         secondaryMuscleGroupIDs: [quadsID, glutesID],           equipmentIDs: [noneID],                                                                     hkType: .hiking),

            // J
            exercise(name: "Jumping Jacks",         primaryMuscleGroupIDs: [quadsID, calvesID, deltsID],                                                              equipmentIDs: [noneID],                                                                     hkType: .highIntensityIntervalTraining),
            exercise(name: "Jump Rope",             primaryMuscleGroupIDs: [calvesID],                        secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [jumpRopeID],                                                                 hkType: .jumpRope),

            // K
            exercise(name: "Kettlebell Halo",       primaryMuscleGroupIDs: [deltsID, upperBackID],            secondaryMuscleGroupIDs: [tricepsID, absID],            equipmentIDs: [kettlebellID],                                                               hkType: .traditionalStrengthTraining),
            exercise(id: UUID(uuidString: "C59510E0-3885-4D18-B80F-C21AFBE779BD")!, name: "Kettlebell Clean",      primaryMuscleGroupIDs: [glutesID, hamstringsID],          secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID],                                                               hkType: .traditionalStrengthTraining),
            exercise(name: "Kettlebell Snatch",     primaryMuscleGroupIDs: [glutesID, hamstringsID],          secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID],                                                               hkType: .traditionalStrengthTraining),
            exercise(name: "Kettlebell Swing",      primaryMuscleGroupIDs: [glutesID, hamstringsID],          secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID],                                                               hkType: .traditionalStrengthTraining),

            // L
            exercise(name: "Lat Pulldown",          primaryMuscleGroupIDs: [latsID],                          secondaryMuscleGroupIDs: [bicepsID, trapsID, deltsID],  equipmentIDs: [latPulldownMachineID],                                                       hkType: .traditionalStrengthTraining),
            exercise(name: "Lateral Raises",        primaryMuscleGroupIDs: [deltsID],                         secondaryMuscleGroupIDs: [trapsID],                     equipmentIDs: [dumbbellID, bandsID],                                                        hkType: .traditionalStrengthTraining),
            exercise(name: "Leg Curls",             primaryMuscleGroupIDs: [hamstringsID],                    secondaryMuscleGroupIDs: [calvesID],                    equipmentIDs: [legCurlMachineID],                                                           hkType: .traditionalStrengthTraining),
            exercise(name: "Leg Extensions",        primaryMuscleGroupIDs: [quadsID],                                                                                 equipmentIDs: [legExtMachineID],                                                            hkType: .traditionalStrengthTraining),
            exercise(name: "Leg Press",             primaryMuscleGroupIDs: [quadsID, hamstringsID, glutesID], secondaryMuscleGroupIDs: [adductorsID, calvesID],       equipmentIDs: [legPressMachineID],                                                          hkType: .traditionalStrengthTraining),
            exercise(name: "Leg Raises",            primaryMuscleGroupIDs: [absID, quadsID],                                                                          equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Lunge (Forward)",       primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [dumbbellID, barbellID, noneID],                                               hkType: .traditionalStrengthTraining),
            exercise(name: "Lunge (Lateral)",       primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [dumbbellID, noneID],                                                          hkType: .traditionalStrengthTraining),
            exercise(name: "Lunge (Reverse)",       primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [dumbbellID, barbellID, noneID],                                               hkType: .traditionalStrengthTraining),

            // M
            exercise(name: "Military Press",        primaryMuscleGroupIDs: [deltsID, tricepsID],              secondaryMuscleGroupIDs: [pecsID],                      equipmentIDs: [dumbbellID, barbellID],                                                       hkType: .traditionalStrengthTraining),
            exercise(name: "Mountain Climbers",     primaryMuscleGroupIDs: [absID, pecsID],                                                                           equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Muscle Ups",            primaryMuscleGroupIDs: [latsID, tricepsID, pecsID],       secondaryMuscleGroupIDs: [bicepsID, deltsID],           equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID],            hkType: .traditionalStrengthTraining),

            // O
            exercise(id: UUID(uuidString: "82527C8B-1AAF-4702-90DF-F8897614A106")!, name: "Overhead Press",        primaryMuscleGroupIDs: [deltsID, tricepsID],              secondaryMuscleGroupIDs: [upperBackID, absID],          equipmentIDs: [barbellID, dumbbellID, kettlebellID],                                         hkType: .traditionalStrengthTraining),

            // P
            exercise(name: "Pistol Squat",          primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID, calvesID, absID],equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Plank",                 primaryMuscleGroupIDs: [absID],                           secondaryMuscleGroupIDs: [deltsID, trapsID],            equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Preacher Curls",        primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [barbellID, dumbbellID],                                                       hkType: .traditionalStrengthTraining),
            exercise(name: "Pullover",              primaryMuscleGroupIDs: [latsID],                          secondaryMuscleGroupIDs: [pecsID, upperBackID, tricepsID], equipmentIDs: [dumbbellID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Pull Ups (Close Grip)", primaryMuscleGroupIDs: [latsID, bicepsID, tricepsID],                                                             equipmentIDs: [pullupBarID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Pull Ups (Kipping)",    primaryMuscleGroupIDs: [latsID, bicepsID],                                                                        equipmentIDs: [pullupBarID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Pull Ups (Standard)",   primaryMuscleGroupIDs: [latsID, bicepsID],                                                                        equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID],            hkType: .traditionalStrengthTraining),
            exercise(name: "Pull Ups (Wide Grip)",  primaryMuscleGroupIDs: [latsID, deltsID],                                                                         equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID],            hkType: .traditionalStrengthTraining),
            exercise(name: "Push Ups (Decline)",    primaryMuscleGroupIDs: [pecsID, deltsID],                 secondaryMuscleGroupIDs: [tricepsID],                   equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Push Ups (Diamond)",    primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [pecsID],                      equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Push Ups (Military)",   primaryMuscleGroupIDs: [tricepsID, pecsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Push Ups (Standard)",   primaryMuscleGroupIDs: [pecsID, tricepsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [noneID, ringsID],                                                            hkType: .traditionalStrengthTraining),
            exercise(name: "Push Ups (Wide)",       primaryMuscleGroupIDs: [pecsID, deltsID],                                                                         equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),

            // R
            exercise(name: "Renegade Row",           primaryMuscleGroupIDs: [upperBackID],                     secondaryMuscleGroupIDs: [latsID, bicepsID, forearmID], equipmentIDs: [dumbbellID],                                                                  hkType: .traditionalStrengthTraining),
            exercise(name: "Ring Rows",             primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [ringsID],                                                                    hkType: .traditionalStrengthTraining),
            exercise(name: "Romanian Deadlift",     primaryMuscleGroupIDs: [hamstringsID, glutesID],          secondaryMuscleGroupIDs: [lowerBackID, trapsID],         equipmentIDs: [barbellID, dumbbellID, kettlebellID], defaultEquipmentIDs: [barbellID],      hkType: .traditionalStrengthTraining),
            exercise(name: "Rower",                 primaryMuscleGroupIDs: [latsID, quadsID],                 secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [rowerID],                                                                    hkType: .rowing),
            exercise(name: "Row (Bent Over)",        primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [barbellID, dumbbellID],           defaultEquipmentIDs: [barbellID],             hkType: .traditionalStrengthTraining),
            exercise(name: "Row (Dumbbell)",         primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [dumbbellID],                                                                  hkType: .traditionalStrengthTraining),
            exercise(name: "Row (Gorilla)",          primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [kettlebellID, dumbbellID],        defaultEquipmentIDs: [kettlebellID],          hkType: .traditionalStrengthTraining),
            exercise(name: "Row (Inverted)",         primaryMuscleGroupIDs: [upperBackID, latsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [barbellID, ringsID],              defaultEquipmentIDs: [barbellID],             hkType: .traditionalStrengthTraining),
            exercise(name: "Row (Upright)",          primaryMuscleGroupIDs: [deltsID, trapsID],                secondaryMuscleGroupIDs: [bicepsID, forearmID],         equipmentIDs: [barbellID, dumbbellID, kettlebellID],                                         hkType: .traditionalStrengthTraining),
            exercise(name: "Running",               primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID], secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [noneID, treadmillID],                                                        hkType: .running),
            exercise(name: "Russian Twist",         primaryMuscleGroupIDs: [absID, obliquesID],                                                                       equipmentIDs: [noneID, dumbbellID],                                                         hkType: .traditionalStrengthTraining),

            // S
            exercise(name: "Shrugs",                primaryMuscleGroupIDs: [trapsID],                         secondaryMuscleGroupIDs: [deltsID, forearmID],          equipmentIDs: [dumbbellID, barbellID],                                                       hkType: .traditionalStrengthTraining),
            exercise(name: "Sled Push",             primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [sledID],                                                                     hkType: .highIntensityIntervalTraining),
            exercise(name: "Sit Ups",               primaryMuscleGroupIDs: [absID],                                                                                    equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Skull Crusher",         primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID],           defaultEquipmentIDs: [dumbbellID],             hkType: .traditionalStrengthTraining),
            // Catch-all for generic Apple-Health-imported strength sessions —
            // match is by name in resolveOrCreateExercise(for:) so it lands here
            // instead of whichever specific exercise happens to share the tag.
            exercise(name: "Strength Training (Traditional)", primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [noneID],                                                                       hkType: .traditionalStrengthTraining),
            exercise(name: "Squat Jumps",           primaryMuscleGroupIDs: [quadsID, glutesID, calvesID],     secondaryMuscleGroupIDs: [hamstringsID, absID],          equipmentIDs: [noneID],                                                                     hkType: .highIntensityIntervalTraining),
            exercise(id: UUID(uuidString: "D95A4C3A-B832-463C-BCA7-4C47771CE2C9")!, name: "Squats",                primaryMuscleGroupIDs: [quadsID, glutesID, hamstringsID], secondaryMuscleGroupIDs: [absID, calvesID, adductorsID],equipmentIDs: [barbellID, dumbbellID, kettlebellID, noneID],                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Stairclimber",          primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [calvesID],                    equipmentIDs: [stairclimberID],                                                             hkType: .stairClimbing),
            exercise(name: "Step Ups",              primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID, calvesID],      equipmentIDs: [dumbbellID, benchID, noneID],                                                hkType: .stepTraining),
            exercise(name: "Superman",              primaryMuscleGroupIDs: [lowerBackID, glutesID],           secondaryMuscleGroupIDs: [hamstringsID, trapsID],       equipmentIDs: [noneID],                                                                     hkType: .traditionalStrengthTraining),
            exercise(name: "Swimming",              primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [noneID],                                                                     hkType: .swimming),

            // T
            exercise(name: "Toes to Bar",           primaryMuscleGroupIDs: [absID, gripID],                                                                           equipmentIDs: [pullupBarID],                                                                 hkType: .traditionalStrengthTraining),
            exercise(name: "Treadmill",             primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID],                                                         equipmentIDs: [treadmillID],                                                                hkType: .running),
            exercise(name: "Tricep Extensions",     primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [dumbbellID, barbellID, bandsID],                                              hkType: .traditionalStrengthTraining),
            exercise(name: "Tricep Kickbacks",      primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [dumbbellID],                                                                  hkType: .traditionalStrengthTraining),
            exercise(name: "Thruster",              primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [kettlebellID, dumbbellID],                                                    hkType: .traditionalStrengthTraining),
            exercise(name: "Turkish Get Ups",       primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [kettlebellID, dumbbellID],                                                    hkType: .traditionalStrengthTraining),

            // W
            exercise(name: "Walking",               primaryMuscleGroupIDs: [quadsID, hamstringsID],           secondaryMuscleGroupIDs: [calvesID, heartID],           equipmentIDs: [noneID, treadmillID],         defaultEquipmentIDs: [noneID],                hkType: .walking),

            // Y
            exercise(name: "Yoga",                  primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [noneID],                                                                     hkType: .yoga),

            // Z
            exercise(name: "Zottman Curl",          primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID],                                                                  hkType: .traditionalStrengthTraining)
        ]
    }
}
