//
//  ExtendApp.swift
//  Extend
//
//  Created by CAVAN MANNENBACH on 2/12/26.
//

import SwiftUI
import SwiftData
import HealthKit
import WidgetKit

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
    let workoutLogState = WorkoutLogState.shared
    let timerState = TimerState.shared
    let voiceTrainerState = VoiceTrainerState()
    let healthKitState = HealthKitState.shared
    let trainingPlanState = TrainingPlanState.shared
    let waterState = WaterState.shared

    init() {
        // Register all modules synchronously before the first render so the
        // registry is never empty when ContentView draws its first frame.
        let registry = ModuleRegistry.shared
        let state = ModuleState.shared

        registry.registerModule(DashboardModule())
        registry.registerModule(WorkoutModule())
        registry.registerModule(TimerModule())
        registry.registerModule(ProgressModule())
        registry.registerModule(ExercisesModule())
        registry.registerModule(MuscleGroupsModule())
        registry.registerModule(EquipmentModule())
        registry.registerModule(GenerateModule())
        registry.registerModule(SettingsModule())
        registry.registerModule(VoiceTrainerModule())
        registry.registerModule(StickFigureAnimatorModule())
        registry.registerModule(MatchGameModule())
        registry.registerModule(TodaysPlanModule())
        registry.registerModule(WaterModule())

        // Set default navbar layout on first launch
        if state.topNavBarModules.isEmpty && state.bottomNavBarModules.isEmpty {
            state.setBottomNavBarModules([
                ModuleIDs.dashboard,
                ModuleIDs.workouts,
                ModuleIDs.exercises,
                ModuleIDs.todaysPlan,
                ModuleIDs.progress
            ])
            state.setTopNavBarModules([
                ModuleIDs.voiceTrainer,
                ModuleIDs.generate,
                ModuleIDs.timer,
                ModuleIDs.muscles,
                ModuleIDs.equipment
            ])
        }

        // Auto-select the first module if nothing is persisted
        if state.selectedModuleID == nil,
           let first = registry.visibleModules.first {
            state.selectModule(first.id)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(DashboardState.shared)
                .environment(ModuleRegistry.shared)
                .environment(ModuleState.shared)
                .environment(exercisesState)
                .environment(workoutsState)
                .environment(generateState)
                .environment(muscleGroupsState)
                .environment(equipmentState)
                .environment(workoutLogState)
                .environment(timerState)
                .environment(voiceTrainerState)
                .environment(healthKitState)
                .environment(trainingPlanState)
                .environment(waterState)
                .task {
                    // Refresh widget snapshot so Today's Plan widget has current data on launch
                    trainingPlanState.refreshWidgetSnapshot()

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
