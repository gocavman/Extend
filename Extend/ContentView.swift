//
//  ContentView.swift
//  Extend
//
//  Created by CAVAN MANNENBACH on 2/12/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    @Environment(DashboardState.self) var dashboardState
    
    var body: some View {
        ZStack {
            let hasTopModules = !state.topNavBarModules.isEmpty
            let hasBottomModules = !state.bottomNavBarModules.isEmpty
            
            if hasTopModules && hasBottomModules {
                // MARK: - Both NavBars Layout
                VStack(spacing: 0) {
                    ModuleNavBar(position: .top)
                    
                    ZStack {
                        if let selectedModuleID = state.selectedModuleID,
                           let selectedModule = registry.moduleWithID(selectedModuleID) {
                            selectedModule.moduleView
                                .transition(.opacity)
                        } else {
                            EmptyStateView()
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    ModuleNavBar(position: .bottom)
                }
            } else if hasTopModules {
                // MARK: - Top NavBar Only Layout
                VStack(spacing: 0) {
                    ModuleNavBar(position: .top)
                    
                    ZStack {
                        if let selectedModuleID = state.selectedModuleID,
                           let selectedModule = registry.moduleWithID(selectedModuleID) {
                            selectedModule.moduleView
                                .transition(.opacity)
                        } else {
                            EmptyStateView()
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // MARK: - Bottom NavBar Layout (Default)
                VStack(spacing: 0) {
                    ZStack {
                        if let selectedModuleID = state.selectedModuleID,
                           let selectedModule = registry.moduleWithID(selectedModuleID) {
                            selectedModule.moduleView
                                .transition(.opacity)
                        } else {
                            EmptyStateView()
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    ModuleNavBar(position: .bottom)
                }
            }
        }
        .onAppear {
            // Register sample modules on app launch
            registerSampleModules()
            
            // Select first module by default
            if let firstModule = registry.visibleModules.first {
                state.selectModule(firstModule.id)
            }
        }
    }
    
    private func registerSampleModules() {
        let dashboardModule = DashboardModule()
        let workoutModule = WorkoutModule()
        let quickWorkoutModule = QuickWorkoutModule()
        let timerModule = TimerModule()
        let progressModule = ProgressModule()
        let exercisesModule = ExercisesModule()
        let muscleGroupsModule = MuscleGroupsModule()
        let equipmentModule = EquipmentModule()
        let generateModule = GenerateModule()
        let settingsModule = SettingsModule()

        registry.registerModule(dashboardModule)
        registry.registerModule(workoutModule)
        registry.registerModule(quickWorkoutModule)
        registry.registerModule(timerModule)
        registry.registerModule(progressModule)
        registry.registerModule(exercisesModule)
        registry.registerModule(muscleGroupsModule)
        registry.registerModule(equipmentModule)
        registry.registerModule(generateModule)
        registry.registerModule(settingsModule)

        // Set default navbar modules using ModuleIDs (UUID-based identification)
        // Bottom (5 max): Dashboard, Workout, Generate, Quick Workout, Settings
        // Top: Log, Timer, Exercises, Muscles, Equipment
        state.setBottomNavBarModules([
            ModuleIDs.dashboard,
            ModuleIDs.workouts,
            ModuleIDs.generate,
            ModuleIDs.quickWorkout,
            ModuleIDs.settings
        ])
        
        state.setTopNavBarModules([
            ModuleIDs.progress,
            ModuleIDs.timer,
            ModuleIDs.exercises,
            ModuleIDs.muscles,
            ModuleIDs.equipment
        ])
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Module Selected")
                .font(.headline)
            
            Text("Select a module from the navbar to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
    }
}

#Preview {
    ContentView()
        .environment(ModuleRegistry.shared)
        .environment(ModuleState.shared)
}
