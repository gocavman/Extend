//
//  ExtendApp.swift
//  Extend
//
//  Created by CAVAN MANNENBACH on 2/12/26.
//

import SwiftUI
import SwiftData

@main
struct ExtendApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    let registry = ModuleRegistry.shared
    let state = ModuleState.shared
    let dashboardState = DashboardState.shared
    let exercisesState = ExercisesState.shared
    let workoutsState = WorkoutsState.shared
    let generateState = GenerateState.shared
    let muscleGroupsState = MuscleGroupsState.shared
    let equipmentState = EquipmentState.shared
    let quickWorkoutState = QuickWorkoutState.shared
    let workoutLogState = WorkoutLogState.shared
    let voiceTrainerState = VoiceTrainerState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(DashboardState.shared)
                .environment(ModuleRegistry.shared)
                .environment(ModuleState.shared)
                .environment(DashboardHeaderState.shared)
                .environment(exercisesState)
                .environment(workoutsState)
                .environment(generateState)
                .environment(muscleGroupsState)
                .environment(equipmentState)
                .environment(quickWorkoutState)
                .environment(workoutLogState)
                .environment(voiceTrainerState)
        }
        .modelContainer(sharedModelContainer)
    }
}
