////
////  ExercisesState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import Observation

/// State management for exercises with persistence
@Observable
public final class ExercisesState {
    public static let shared = ExercisesState()
    
    @ObservationIgnored private let userDefaultsKey = "exercises_data"
    
    public var exercises: [Exercise] = []

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
        exercises.removeAll { $0.id == id }
        saveExercises()
    }
    
    public func resetExercises() {
        exercises = Self.createDefaultExercises()
        saveExercises()
    }
    
    // MARK: - Persistence
    
    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
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
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Default Exercises
    
    private static func createDefaultExercises() -> [Exercise] {
        // Helper: auto-defaults to the single equipment if only one; otherwise uses explicit defaultIDs
        func exercise(
            name: String,
            primaryMuscleGroupIDs: [UUID],
            secondaryMuscleGroupIDs: [UUID] = [],
            equipmentIDs: [UUID],
            defaultEquipmentIDs: [UUID]? = nil
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
                name: name,
                notes: "",
                primaryMuscleGroupIDs: primaryMuscleGroupIDs,
                secondaryMuscleGroupIDs: secondaryMuscleGroupIDs,
                equipmentIDs: equipmentIDs,
                defaultEquipmentIDs: defaults
            )
        }

        // Muscle group UUIDs
        let absID        = UUID(uuidString: "00000020-0000-0000-0000-000000000000")!
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

        let plyoBoxID     = UUID(uuidString: "00000113-0000-0000-0000-000000000000")!

        return [
            // A
            exercise(name: "Ab Wheel",             primaryMuscleGroupIDs: [absID],                           secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [abWheelID]),
            exercise(name: "Assault Bike",          primaryMuscleGroupIDs: [quadsID, hamstringsID],                                                                   equipmentIDs: [assaultBikeID]),

            // A
            exercise(name: "Arnold Press",          primaryMuscleGroupIDs: [deltsID],                         secondaryMuscleGroupIDs: [tricepsID, trapsID],           equipmentIDs: [dumbbellID]),

            // B
            exercise(name: "Battle Ropes",          primaryMuscleGroupIDs: [deltsID, pecsID],                                                                         equipmentIDs: [battleRopesID]),
            exercise(name: "Bench (Close Grip)",    primaryMuscleGroupIDs: [tricepsID, pecsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID, benchID],  defaultEquipmentIDs: [benchID]),
            exercise(name: "Bench (Decline)",       primaryMuscleGroupIDs: [pecsID, tricepsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID, benchID],  defaultEquipmentIDs: [benchID]),
            exercise(name: "Bench (Incline)",       primaryMuscleGroupIDs: [pecsID, deltsID],                 secondaryMuscleGroupIDs: [tricepsID],                   equipmentIDs: [barbellID, dumbbellID, benchID],  defaultEquipmentIDs: [benchID]),
            exercise(name: "Bench (Regular)",       primaryMuscleGroupIDs: [pecsID, tricepsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID, benchID],  defaultEquipmentIDs: [benchID]),
            exercise(name: "Bicep Curls",           primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID, barbellID],           defaultEquipmentIDs: [dumbbellID]),
            exercise(name: "Bulgarian Split Squats",primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [dumbbellID, benchID, noneID]),
            exercise(name: "Box Jumps",             primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [calvesID, hamstringsID],      equipmentIDs: [plyoBoxID]),
            exercise(name: "Burpees",               primaryMuscleGroupIDs: [pecsID, quadsID],                 secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [noneID]),

            // C
            exercise(name: "Calf Raises",           primaryMuscleGroupIDs: [calvesID],                                                                                equipmentIDs: [dumbbellID, barbellID, noneID]),
            exercise(name: "Chest Flies",           primaryMuscleGroupIDs: [pecsID],                          secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [dumbbellID]),
            exercise(name: "Chin Ups",              primaryMuscleGroupIDs: [bicepsID, latsID],                                                                        equipmentIDs: [pullupBarID]),
            exercise(name: "Concentration Curls",   primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID]),
            exercise(name: "Crunches",              primaryMuscleGroupIDs: [absID],                                                                                    equipmentIDs: [noneID]),

            // D
            exercise(name: "Deadlift",              primaryMuscleGroupIDs: [hamstringsID, glutesID],          secondaryMuscleGroupIDs: [latsID, trapsID],             equipmentIDs: [barbellID, dumbbellID, kettlebellID], defaultEquipmentIDs: [barbellID]),
            exercise(name: "Dips",                  primaryMuscleGroupIDs: [tricepsID, pecsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [noneID, benchID, ringsID]),

            // E
            exercise(name: "Elliptical",            primaryMuscleGroupIDs: [quadsID, hamstringsID],                                                                   equipmentIDs: [ellipticalID]),

            // F
            exercise(name: "Farmer's Carry",        primaryMuscleGroupIDs: [gripID, forearmID, deltsID],      secondaryMuscleGroupIDs: [absID, quadsID, glutesID],    equipmentIDs: [dumbbellID, kettlebellID]),
            exercise(name: "Face Pulls",            primaryMuscleGroupIDs: [deltsID, trapsID],                secondaryMuscleGroupIDs: [rhomboidsID],                 equipmentIDs: [bandsID]),
            exercise(name: "Front Raises",          primaryMuscleGroupIDs: [deltsID],                         secondaryMuscleGroupIDs: [pecsID],                      equipmentIDs: [dumbbellID, barbellID]),

            // G
            exercise(name: "Goblet Squat",          primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID, absID],         equipmentIDs: [kettlebellID, dumbbellID],        defaultEquipmentIDs: [kettlebellID]),

            // H
            exercise(name: "Hammer Curls",          primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [dumbbellID]),
            exercise(name: "Hip Thrusts",           primaryMuscleGroupIDs: [glutesID],                        secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [barbellID, dumbbellID, benchID, noneID], defaultEquipmentIDs: [barbellID]),

            // J
            exercise(name: "Jog",                   primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID], secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [noneID, treadmillID]),
            exercise(name: "Jumping Jacks",         primaryMuscleGroupIDs: [quadsID, calvesID, deltsID],                                                              equipmentIDs: [noneID]),
            exercise(name: "Jump Rope",             primaryMuscleGroupIDs: [calvesID],                        secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [jumpRopeID]),

            // K
            exercise(name: "Kettlebell Halo",       primaryMuscleGroupIDs: [deltsID, upperBackID],            secondaryMuscleGroupIDs: [tricepsID, absID],            equipmentIDs: [kettlebellID]),
            exercise(name: "Kettlebell Clean",      primaryMuscleGroupIDs: [glutesID, hamstringsID],          secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Kettlebell Snatch",     primaryMuscleGroupIDs: [glutesID, hamstringsID],          secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Kettlebell Swing",      primaryMuscleGroupIDs: [glutesID, hamstringsID],          secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID]),

            // L
            exercise(name: "Lateral Raises",        primaryMuscleGroupIDs: [deltsID],                         secondaryMuscleGroupIDs: [trapsID],                     equipmentIDs: [dumbbellID, bandsID]),
            exercise(name: "Leg Raises",            primaryMuscleGroupIDs: [absID, quadsID],                                                                          equipmentIDs: [noneID]),
            exercise(name: "Lunges",                primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [dumbbellID, barbellID, noneID]),

            // M
            exercise(name: "Military Press",        primaryMuscleGroupIDs: [deltsID, tricepsID],              secondaryMuscleGroupIDs: [pecsID],                      equipmentIDs: [dumbbellID, barbellID]),
            exercise(name: "Mountain Climbers",     primaryMuscleGroupIDs: [absID, pecsID],                                                                           equipmentIDs: [noneID]),
            exercise(name: "Muscle Ups",            primaryMuscleGroupIDs: [latsID, tricepsID, pecsID],       secondaryMuscleGroupIDs: [bicepsID, deltsID],           equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID]),

            // O
            exercise(name: "Overhead Press",        primaryMuscleGroupIDs: [deltsID, tricepsID],              secondaryMuscleGroupIDs: [upperBackID, absID],          equipmentIDs: [barbellID, dumbbellID, kettlebellID]),

            // P
            exercise(name: "Pistol Squat",          primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID, calvesID],      equipmentIDs: [noneID]),
            exercise(name: "Plank",                 primaryMuscleGroupIDs: [absID],                           secondaryMuscleGroupIDs: [deltsID, trapsID],            equipmentIDs: [noneID]),
            exercise(name: "Preacher Curls",        primaryMuscleGroupIDs: [bicepsID],                        secondaryMuscleGroupIDs: [forearmID],                   equipmentIDs: [barbellID, dumbbellID]),
            exercise(name: "Pull Ups (Close Grip)", primaryMuscleGroupIDs: [latsID, bicepsID, tricepsID],                                                             equipmentIDs: [pullupBarID]),
            exercise(name: "Pull Ups (Kipping)",    primaryMuscleGroupIDs: [latsID, bicepsID],                                                                        equipmentIDs: [pullupBarID]),
            exercise(name: "Pull Ups (Standard)",   primaryMuscleGroupIDs: [latsID, bicepsID],                                                                        equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID]),
            exercise(name: "Pull Ups (Wide Grip)",  primaryMuscleGroupIDs: [latsID, deltsID],                                                                         equipmentIDs: [pullupBarID, ringsID],             defaultEquipmentIDs: [pullupBarID]),
            exercise(name: "Push Ups (Decline)",    primaryMuscleGroupIDs: [pecsID, deltsID],                 secondaryMuscleGroupIDs: [tricepsID],                   equipmentIDs: [noneID]),
            exercise(name: "Push Ups (Diamond)",    primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [pecsID],                      equipmentIDs: [noneID]),
            exercise(name: "Push Ups (Military)",   primaryMuscleGroupIDs: [tricepsID, pecsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [noneID]),
            exercise(name: "Push Ups (Standard)",   primaryMuscleGroupIDs: [pecsID, tricepsID],               secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [noneID, ringsID]),
            exercise(name: "Push Ups (Wide)",       primaryMuscleGroupIDs: [pecsID, deltsID],                                                                         equipmentIDs: [noneID]),

            // R
            exercise(name: "Rows",                  primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [barbellID, dumbbellID, kettlebellID]),
            exercise(name: "Rower",                 primaryMuscleGroupIDs: [latsID, quadsID],                 secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [rowerID]),
            exercise(name: "Run",                   primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID], secondaryMuscleGroupIDs: [heartID],                     equipmentIDs: [noneID, treadmillID]),
            exercise(name: "Russian Twist",         primaryMuscleGroupIDs: [absID, obliquesID],                                                                       equipmentIDs: [noneID, dumbbellID]),
            exercise(name: "Ring Rows",             primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [ringsID]),
            exercise(name: "Romanian Deadlift",     primaryMuscleGroupIDs: [hamstringsID, glutesID],          secondaryMuscleGroupIDs: [lowerBackID, trapsID],         equipmentIDs: [barbellID, dumbbellID, kettlebellID], defaultEquipmentIDs: [barbellID]),
            exercise(name: "Rows",                  primaryMuscleGroupIDs: [latsID, rhomboidsID],             secondaryMuscleGroupIDs: [bicepsID, trapsID],           equipmentIDs: [barbellID, dumbbellID, kettlebellID]),

            // S
            exercise(name: "Shrugs",                primaryMuscleGroupIDs: [trapsID],                         secondaryMuscleGroupIDs: [deltsID, forearmID],          equipmentIDs: [dumbbellID, barbellID]),
            exercise(name: "Sit Ups",               primaryMuscleGroupIDs: [absID],                                                                                    equipmentIDs: [noneID]),
            exercise(name: "Skull Crusher",         primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [barbellID, dumbbellID],           defaultEquipmentIDs: [dumbbellID]),
            exercise(name: "Squat Jumps",           primaryMuscleGroupIDs: [quadsID, glutesID],                                                                       equipmentIDs: [noneID]),
            exercise(name: "Squats",                primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID],                equipmentIDs: [barbellID, dumbbellID, kettlebellID, noneID]),
            exercise(name: "Stairclimber",          primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [calvesID],                    equipmentIDs: [stairclimberID]),
            exercise(name: "Step Ups",              primaryMuscleGroupIDs: [quadsID, glutesID],               secondaryMuscleGroupIDs: [hamstringsID, calvesID],      equipmentIDs: [dumbbellID, benchID, noneID]),
            exercise(name: "Superman",              primaryMuscleGroupIDs: [lowerBackID, glutesID],           secondaryMuscleGroupIDs: [hamstringsID, trapsID],       equipmentIDs: [noneID]),

            // T
            exercise(name: "Toes to Bar",           primaryMuscleGroupIDs: [absID, gripID],                                                                           equipmentIDs: [pullupBarID]),
            exercise(name: "Treadmill",             primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID],                                                         equipmentIDs: [treadmillID]),
            exercise(name: "Tricep Extensions",     primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [dumbbellID, barbellID, bandsID]),
            exercise(name: "Tricep Kickbacks",      primaryMuscleGroupIDs: [tricepsID],                       secondaryMuscleGroupIDs: [deltsID],                     equipmentIDs: [dumbbellID]),
            exercise(name: "Turkish Get Ups",       primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [kettlebellID, dumbbellID]),

            // W
            exercise(name: "Walk",                  primaryMuscleGroupIDs: [quadsID, hamstringsID],           secondaryMuscleGroupIDs: [calvesID, heartID],           equipmentIDs: [noneID]),

            // Y
            exercise(name: "Yoga",                  primaryMuscleGroupIDs: [fullBodyID],                                                                              equipmentIDs: [noneID])
        ]
    }
}
