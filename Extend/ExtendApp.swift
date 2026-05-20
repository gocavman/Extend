//
//  ExtendApp.swift
//  Extend
//
//  Created by CAVAN MANNENBACH on 2/12/26.
//

import SwiftUI
import SwiftData
import HealthKit

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
    let timerState = TimerState.shared
    let voiceTrainerState = VoiceTrainerState()
    let healthKitState = HealthKitState.shared

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
                .environment(timerState)
                .environment(voiceTrainerState)
                .environment(healthKitState)
                .task {
                    // Request HealthKit auth on first launch if any sync is configured
                    guard !healthKitState.authorizationRequested else { return }
                    guard HealthKitService.shared.isAvailable else { return }
                    do {
                        try await HealthKitService.shared.requestAuthorization()
                        healthKitState.authorizationRequested = true
                    } catch {
                        // Non-fatal: user may have declined; we'll check status before each operation
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
