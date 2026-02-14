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
            exercises = decoded
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
        // Helper function to create exercises with primary and secondary muscle groups and equipment
        func exercise(
            name: String,
            primaryMuscleGroupIDs: [UUID],
            secondaryMuscleGroupIDs: [UUID] = [],
            equipmentIDs: [UUID]
        ) -> Exercise {
            Exercise(
                name: name,
                notes: "",
                primaryMuscleGroupIDs: primaryMuscleGroupIDs,
                secondaryMuscleGroupIDs: secondaryMuscleGroupIDs,
                equipmentIDs: equipmentIDs
            )
        }
        
        // Get UUID references for muscle groups and equipment
        // Biceps: 00000010-0000-0000-0000-000000000000
        // Triceps: 00000011-0000-0000-0000-000000000000
        // Pecs: 00000012-0000-0000-0000-000000000000
        // Delts: 00000013-0000-0000-0000-000000000000
        // Traps: 00000014-0000-0000-0000-000000000000
        // Lats: 00000015-0000-0000-0000-000000000000
        // Quads: 00000016-0000-0000-0000-000000000000
        // Glutes: 00000017-0000-0000-0000-000000000000
        // Hamstrings: 00000018-0000-0000-0000-000000000000
        // Calves: 00000019-0000-0000-0000-000000000000
        // Abs: 00000020-0000-0000-0000-000000000000
        // Obliques: 00000021-0000-0000-0000-000000000000
        // Heart: 00000022-0000-0000-0000-000000000000
        
        // Equipment UUIDs from EquipmentModule
        let noneID = UUID(uuidString: "00000100-0000-0000-0000-000000000000")!
        let dumbbellID = UUID(uuidString: "00000101-0000-0000-0000-000000000000")!
        let barbellID = UUID(uuidString: "00000102-0000-0000-0000-000000000000")!
        let benchID = UUID(uuidString: "00000103-0000-0000-0000-000000000000")!
        let pullupBarID = UUID(uuidString: "00000104-0000-0000-0000-000000000000")!
        let ropeID = UUID(uuidString: "00000105-0000-0000-0000-000000000000")!
        let jumpRopeID = UUID(uuidString: "00000106-0000-0000-0000-000000000000")!
        let kettlebellID = UUID(uuidString: "00000107-0000-0000-0000-000000000000")!
        let rowerID = UUID(uuidString: "00000108-0000-0000-0000-000000000000")!
        let assaultBikeID = UUID(uuidString: "00000109-0000-0000-0000-000000000000")!
        let treadmillID = UUID(uuidString: "0000010A-0000-0000-0000-000000000000")!
        let stairclimberID = UUID(uuidString: "0000010B-0000-0000-0000-000000000000")!
        let ellipticalID = UUID(uuidString: "0000010C-0000-0000-0000-000000000000")!
        let battleRopesID = UUID(uuidString: "0000010D-0000-0000-0000-000000000000")!
        let abWheelID = UUID(uuidString: "0000010E-0000-0000-0000-000000000000")!
        
        // Muscle group UUIDs - using same format
        let absID = UUID(uuidString: "00000020-0000-0000-0000-000000000000")!
        let bicepsID = UUID(uuidString: "00000010-0000-0000-0000-000000000000")!
        let calvesID = UUID(uuidString: "00000019-0000-0000-0000-000000000000")!
        let deltsID = UUID(uuidString: "00000013-0000-0000-0000-000000000000")!
        let fullBodyID = UUID(uuidString: "0000002A-0000-0000-0000-000000000000")!
        let forearmID = UUID(uuidString: "00000023-0000-0000-0000-000000000000")!
        let glutesID = UUID(uuidString: "00000017-0000-0000-0000-000000000000")!
        let gripID = UUID(uuidString: "00000024-0000-0000-0000-000000000000")!
        let hamstringsID = UUID(uuidString: "00000018-0000-0000-0000-000000000000")!
        let heartID = UUID(uuidString: "00000022-0000-0000-0000-000000000000")!
        let latsID = UUID(uuidString: "00000015-0000-0000-0000-000000000000")!
        let lowerBackID = UUID(uuidString: "00000026-0000-0000-0000-000000000000")!
        let obliquesID = UUID(uuidString: "00000021-0000-0000-0000-000000000000")!
        let pecsID = UUID(uuidString: "00000012-0000-0000-0000-000000000000")!
        let rhomboidsID = UUID(uuidString: "00000028-0000-0000-0000-000000000000")!
        let quadsID = UUID(uuidString: "00000016-0000-0000-0000-000000000000")!
        let trapsID = UUID(uuidString: "00000014-0000-0000-0000-000000000000")!
        let tricepsID = UUID(uuidString: "00000011-0000-0000-0000-000000000000")!
        let upperBackID = UUID(uuidString: "00000029-0000-0000-0000-000000000000")!
        
        return [
            exercise(name: "Ab Wheel", primaryMuscleGroupIDs: [absID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [abWheelID]),
            exercise(name: "Assault Bike", primaryMuscleGroupIDs: [quadsID, hamstringsID], equipmentIDs: [assaultBikeID]),
            exercise(name: "Barbell Rows", primaryMuscleGroupIDs: [latsID, bicepsID], secondaryMuscleGroupIDs: [trapsID], equipmentIDs: [barbellID]),
            exercise(name: "Battle Ropes", primaryMuscleGroupIDs: [deltsID, pecsID], equipmentIDs: [battleRopesID]),
            exercise(name: "Bench (Incline)", primaryMuscleGroupIDs: [pecsID, deltsID], secondaryMuscleGroupIDs: [tricepsID], equipmentIDs: [barbellID, dumbbellID, benchID]),
            exercise(name: "Bench (Regular)", primaryMuscleGroupIDs: [pecsID, tricepsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [barbellID, benchID]),
            exercise(name: "Bicep Curls", primaryMuscleGroupIDs: [bicepsID], secondaryMuscleGroupIDs: [forearmID], equipmentIDs: [dumbbellID]),
            exercise(name: "Bulgarian Split Squats", primaryMuscleGroupIDs: [quadsID, glutesID], secondaryMuscleGroupIDs: [hamstringsID], equipmentIDs: [dumbbellID, benchID, noneID]),
            exercise(name: "Burpees", primaryMuscleGroupIDs: [pecsID, quadsID], secondaryMuscleGroupIDs: [heartID], equipmentIDs: [noneID]),
            exercise(name: "Calf Raises", primaryMuscleGroupIDs: [calvesID], equipmentIDs: [dumbbellID, barbellID, noneID]),
            exercise(name: "Close Grip Bench", primaryMuscleGroupIDs: [tricepsID, pecsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [barbellID, benchID]),
            exercise(name: "Chin Ups", primaryMuscleGroupIDs: [bicepsID, latsID], equipmentIDs: [pullupBarID]),
            exercise(name: "Concentration Curls", primaryMuscleGroupIDs: [bicepsID], secondaryMuscleGroupIDs: [forearmID], equipmentIDs: [dumbbellID]),
            exercise(name: "Crunches", primaryMuscleGroupIDs: [absID], equipmentIDs: [noneID]),
            exercise(name: "Deadlift", primaryMuscleGroupIDs: [hamstringsID, glutesID], secondaryMuscleGroupIDs: [latsID, trapsID], equipmentIDs: [barbellID]),
            exercise(name: "Dips", primaryMuscleGroupIDs: [tricepsID, pecsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [noneID, benchID]),
            exercise(name: "Dumbbell Rows", primaryMuscleGroupIDs: [latsID, bicepsID], secondaryMuscleGroupIDs: [trapsID], equipmentIDs: [dumbbellID]),
            exercise(name: "Elliptical", primaryMuscleGroupIDs: [quadsID, hamstringsID], equipmentIDs: [ellipticalID]),
            exercise(name: "EZ Bar Curls", primaryMuscleGroupIDs: [bicepsID], secondaryMuscleGroupIDs: [forearmID], equipmentIDs: [barbellID]),
            exercise(name: "Farmer's Carry", primaryMuscleGroupIDs: [gripID, forearmID, deltsID], secondaryMuscleGroupIDs: [absID, quadsID, glutesID], equipmentIDs: [dumbbellID, kettlebellID]),
            exercise(name: "Front Raises", primaryMuscleGroupIDs: [deltsID], secondaryMuscleGroupIDs: [pecsID], equipmentIDs: [dumbbellID, barbellID]),
            exercise(name: "Goblet Squat", primaryMuscleGroupIDs: [quadsID, glutesID], secondaryMuscleGroupIDs: [hamstringsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Hammer Curls", primaryMuscleGroupIDs: [bicepsID], secondaryMuscleGroupIDs: [forearmID], equipmentIDs: [dumbbellID]),
            exercise(name: "Jog", primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID], secondaryMuscleGroupIDs: [heartID], equipmentIDs: [noneID, treadmillID]),
            exercise(name: "Jumping Jacks", primaryMuscleGroupIDs: [quadsID, calvesID, deltsID], equipmentIDs: [noneID]),
            exercise(name: "Jump Rope", primaryMuscleGroupIDs: [calvesID], equipmentIDs: [jumpRopeID]),
            exercise(name: "Kettlebell Clean", primaryMuscleGroupIDs: [glutesID, hamstringsID], secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Kettlebell Row", primaryMuscleGroupIDs: [latsID, rhomboidsID], secondaryMuscleGroupIDs: [bicepsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Kettlebell Snatch", primaryMuscleGroupIDs: [glutesID, hamstringsID], secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Kettlebell Swing", primaryMuscleGroupIDs: [glutesID, hamstringsID], secondaryMuscleGroupIDs: [lowerBackID, deltsID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Lateral Raises", primaryMuscleGroupIDs: [deltsID], secondaryMuscleGroupIDs: [trapsID], equipmentIDs: [dumbbellID]),
            exercise(name: "Leg Raises", primaryMuscleGroupIDs: [absID, quadsID], equipmentIDs: [noneID]),
            exercise(name: "Lunges", primaryMuscleGroupIDs: [quadsID, glutesID], secondaryMuscleGroupIDs: [hamstringsID], equipmentIDs: [dumbbellID, noneID]),
            exercise(name: "Military Press", primaryMuscleGroupIDs: [deltsID, tricepsID], secondaryMuscleGroupIDs: [pecsID], equipmentIDs: [dumbbellID, barbellID]),
            exercise(name: "Mountain Climbers", primaryMuscleGroupIDs: [absID, pecsID], equipmentIDs: [noneID]),
            exercise(name: "Overhead Press", primaryMuscleGroupIDs: [deltsID, tricepsID], secondaryMuscleGroupIDs: [upperBackID, absID], equipmentIDs: [kettlebellID]),
            exercise(name: "Plank", primaryMuscleGroupIDs: [absID], secondaryMuscleGroupIDs: [deltsID, trapsID], equipmentIDs: [noneID]),
            exercise(name: "Preacher Curls", primaryMuscleGroupIDs: [bicepsID], secondaryMuscleGroupIDs: [forearmID], equipmentIDs: [barbellID, dumbbellID]),
            exercise(name: "Pull Ups (Close Grip)", primaryMuscleGroupIDs: [latsID, bicepsID, tricepsID], equipmentIDs: [pullupBarID]),
            exercise(name: "Pull Ups (Kipping)", primaryMuscleGroupIDs: [latsID, bicepsID], equipmentIDs: [pullupBarID]),
            exercise(name: "Pull Ups (Standard)", primaryMuscleGroupIDs: [latsID, bicepsID], equipmentIDs: [pullupBarID]),
            exercise(name: "Pull Ups (Wide Grip)", primaryMuscleGroupIDs: [latsID, deltsID], equipmentIDs: [pullupBarID]),
            exercise(name: "Push Ups (Diamond)", primaryMuscleGroupIDs: [tricepsID], secondaryMuscleGroupIDs: [pecsID], equipmentIDs: [noneID]),
            exercise(name: "Push Ups (Military)", primaryMuscleGroupIDs: [tricepsID, pecsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [noneID]),
            exercise(name: "Push Ups (Standard)", primaryMuscleGroupIDs: [pecsID, tricepsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [noneID]),
            exercise(name: "Push Ups (Wide)", primaryMuscleGroupIDs: [pecsID, deltsID], equipmentIDs: [noneID]),
            exercise(name: "Rower", primaryMuscleGroupIDs: [latsID, quadsID], secondaryMuscleGroupIDs: [hamstringsID], equipmentIDs: [rowerID]),
            exercise(name: "Run", primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID], secondaryMuscleGroupIDs: [heartID], equipmentIDs: [noneID, treadmillID]),
            exercise(name: "Russian Twist", primaryMuscleGroupIDs: [absID, obliquesID], equipmentIDs: [noneID, dumbbellID]),
            exercise(name: "Sit Ups", primaryMuscleGroupIDs: [absID], equipmentIDs: [noneID]),
            exercise(name: "Skull Crusher", primaryMuscleGroupIDs: [tricepsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [barbellID, dumbbellID, ropeID]),
            exercise(name: "Squat Jumps", primaryMuscleGroupIDs: [quadsID, glutesID], equipmentIDs: [noneID]),
            exercise(name: "Squats", primaryMuscleGroupIDs: [quadsID, glutesID], secondaryMuscleGroupIDs: [hamstringsID], equipmentIDs: [barbellID, dumbbellID, kettlebellID, noneID]),
            exercise(name: "Stairclimber", primaryMuscleGroupIDs: [quadsID, glutesID], secondaryMuscleGroupIDs: [calvesID], equipmentIDs: [stairclimberID]),
            exercise(name: "Step Ups", primaryMuscleGroupIDs: [quadsID, glutesID], secondaryMuscleGroupIDs: [hamstringsID, calvesID], equipmentIDs: [dumbbellID, benchID, noneID]),
            exercise(name: "Treadmill", primaryMuscleGroupIDs: [quadsID, hamstringsID, calvesID], equipmentIDs: [treadmillID]),
            exercise(name: "Tricep Extensions", primaryMuscleGroupIDs: [tricepsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [dumbbellID]),
            exercise(name: "Tricep Kickbacks", primaryMuscleGroupIDs: [tricepsID], secondaryMuscleGroupIDs: [deltsID], equipmentIDs: [dumbbellID]),
            exercise(name: "Toes to Bar", primaryMuscleGroupIDs: [absID, gripID], equipmentIDs: [pullupBarID]),
            exercise(name: "Turkish Get Ups", primaryMuscleGroupIDs: [fullBodyID], equipmentIDs: [kettlebellID, dumbbellID]),
            exercise(name: "Walk", primaryMuscleGroupIDs: [quadsID, hamstringsID], secondaryMuscleGroupIDs: [calvesID, heartID], equipmentIDs: [noneID]),
            exercise(name: "Yoga", primaryMuscleGroupIDs: [fullBodyID], equipmentIDs: [noneID])
        ]
    }
}
