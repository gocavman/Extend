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
        let hasTopModules = !state.topNavBarModules.isEmpty
        let hasBottomModules = !state.bottomNavBarModules.isEmpty
        let selectedModule = state.selectedModuleID.flatMap { registry.moduleWithID($0) }
        let shouldHideNavBars = selectedModule?.hidesNavBars ?? false
        
        if hasTopModules && hasBottomModules {
            // MARK: - Both NavBars Layout
            return AnyView(
                VStack(spacing: 0) {
                    if !shouldHideNavBars {
                        navBarBackground
                            .ignoresSafeArea(edges: .top)
                            .frame(height: 0)
                        
                        ModuleNavBar(position: .top)
                    }
                
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
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !shouldHideNavBars {
                        ModuleNavBar(position: .bottom)
                        
                        navBarBackground
                            .ignoresSafeArea(edges: .bottom)
                            .frame(height: 0)
                    }
                }
                .onAppear {
                    registerSampleModules()
                    if let firstModule = registry.visibleModules.first {
                        state.selectModule(firstModule.id)
                    }
                }
            )
        } else if hasTopModules {
            // MARK: - Top NavBar Only Layout
            return AnyView(
                VStack(spacing: 0) {
                    if !shouldHideNavBars {
                        navBarBackground
                            .ignoresSafeArea(edges: .top)
                            .frame(height: 0)
                        
                        ModuleNavBar(position: .top)
                    }
                
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
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !shouldHideNavBars {
                        navBarBackground
                            .ignoresSafeArea(edges: .bottom)
                            .frame(height: 0)
                    }
                }
                .onAppear {
                    registerSampleModules()
                    if let firstModule = registry.visibleModules.first {
                        state.selectModule(firstModule.id)
                    }
                }
            )
        } else {
            // MARK: - Bottom NavBar Layout (Default)
            return AnyView(
                VStack(spacing: 0) {
                    if !shouldHideNavBars {
                        navBarBackground
                            .ignoresSafeArea(edges: .top)
                            .frame(height: 0)
                    }
                    
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
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !shouldHideNavBars {
                        ModuleNavBar(position: .bottom)
                        
                        navBarBackground
                            .ignoresSafeArea(edges: .bottom)
                            .frame(height: 0)
                    }
                }
                .onAppear {
                    registerSampleModules()
                    if let firstModule = registry.visibleModules.first {
                        state.selectModule(firstModule.id)
                    }
                }
            )
        }
    }
    
    // ...existing code...
    
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
        let voiceTrainerModule = VoiceTrainerModule()
        let game1Module = Game1Module()

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
        registry.registerModule(voiceTrainerModule)
        registry.registerModule(game1Module)

        // Only set default navbar modules on first launch (when both are empty)
        // This preserves user customizations
        if state.topNavBarModules.isEmpty && state.bottomNavBarModules.isEmpty {
            // Set default navbar modules using ModuleIDs (UUID-based identification)
            // Bottom (5 max): Dashboard, Workout, Generate, Quick, Settings
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

    private var navBarBackground: some View {
        Group {
            if state.navBarUseGradient {
                LinearGradient(
                    colors: [state.navBarBackgroundColor, state.navBarGradientSecondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                state.navBarBackgroundColor
            }
        }
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
