////
////  SettingsModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Settings module for app configuration
public struct SettingsModule: AppModule {
    public let id: UUID = ModuleIDs.settings
    public let displayName: String = "Settings"
    public let iconName: String = "gear"
    public let description: String = "App settings and preferences"
    
    public var order: Int = 4
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(SettingsModuleView())
    }
}

// MARK: - Settings View

private struct SettingsModuleView: View {
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var moduleState
    @Environment(DashboardState.self) var dashboardState
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState

    @State private var showingResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            NavigationStack {
                Form {
                    // MARK: - NavBar Customization Section
                    Section("NavBar Items") {
                        NavigationLink(destination: NavBarCustomizationView()) {
                            HStack {
                                Text("Customize Items")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                // MARK: - Reset Section
                Section("Reset") {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingResetAlert = true
                    } label: {
                        Text("Reset App")
                    }
                }

                // MARK: - About Section
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("Reset App?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    resetApp()
                }
            } message: {
                Text("This will reset navbars, dashboard tiles, exercises, workouts, muscle groups, and equipment back to defaults.")
            }
            }
        }
    }

    private func resetApp() {
        // Reset to default navbar configuration using ModuleIDs (UUID-based identification)
        // Order: Dashboard, Workout, Generate, Quick Workout, Settings, Log, Timer, Exercises, Muscles, Equipment
        
        let bottomModules: [UUID] = [
            ModuleIDs.dashboard,
            ModuleIDs.workouts,
            ModuleIDs.generate,
            ModuleIDs.quickWorkout,
            ModuleIDs.settings
        ]
        
        let topModules: [UUID] = [
            ModuleIDs.progress,
            ModuleIDs.timer,
            ModuleIDs.exercises,
            ModuleIDs.muscles,
            ModuleIDs.equipment
        ]
        
        moduleState.setBottomNavBarModules(bottomModules)
        moduleState.setTopNavBarModules(topModules)
        
        // Reset data
        dashboardState.resetTiles()
        muscleGroupsState.resetGroups()
        equipmentState.resetItems()
        ExercisesState.shared.resetExercises()
        WorkoutsState.shared.resetWorkouts()
        GenerateState.shared.resetGenerated()
        QuickWorkoutState.shared.resetFavorites()
        
        // Route back to Dashboard after reset
        moduleState.selectModule(ModuleIDs.dashboard)
    }
}

// MARK: - NavBar Customization View

@available(iOS 16.0, *)
private struct NavBarCustomizationView: View {
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state

    @State private var allSelected: [UUID] = []
    @State private var showingAddPicker = false
    @State private var hasInitialized = false
    
    // Store protected module IDs instead of checking by name
    private var dashboardModuleID: UUID {
        ModuleIDs.dashboard
    }
    
    private var settingsModuleID: UUID {
        ModuleIDs.settings
    }

    private var bottomCount: Int {
        min(5, allSelected.count)
    }

    private var topCount: Int {
        max(0, allSelected.count - bottomCount)
    }

    private var availableCount: Int {
        registry.registeredModules
            .filter { !allSelected.contains($0.id) }
            .count
    }

    var body: some View {
        List {
            Section("Items (Max 10)") {
                Text("Bottom navbar shows first 5 items. Top navbar shows any extras.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)

                if allSelected.isEmpty {
                    Text("No items selected")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ForEach(Array(allSelected.enumerated()), id: \.element) { index, moduleID in
                        if let module = registry.registeredModules.first(where: { $0.id == moduleID }) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: module.iconName)
                                        .foregroundColor(.black)
                                    Text(module.displayName)
                                        .font(.subheadline)
                                }

                                Spacer()

                                if moduleID != dashboardModuleID && moduleID != settingsModuleID {
                                    Button(action: {
                                        allSelected.remove(at: index)
                                        saveState()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        allSelected.move(fromOffsets: indices, toOffset: newOffset)
                        saveState()
                    }
                }

                if allSelected.count < 10 && availableCount > 0 {
                    Button(action: { showingAddPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.black)
                            Text("Add Item")
                                .foregroundColor(.black)
                        }
                    }
                    .sheet(isPresented: $showingAddPicker) {
                        ModulePickerView(
                            selectedModules: $allSelected,
                            maxCount: 10,
                            onSave: { modules in
                                allSelected = modules
                                saveState()
                            }
                        )
                    }
                } else {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.gray)
                        Text("Add Item")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("NavBar Items")
        .onAppear {
            if !hasInitialized {
                let topModules = state.topNavBarModules
                let bottomModules = state.bottomNavBarModules
                allSelected = bottomModules + topModules
                hasInitialized = true
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private func saveState() {
        let bottom = Array(allSelected.prefix(bottomCount))
        let top = Array(allSelected.suffix(topCount))
        state.setBottomNavBarModules(bottom)
        state.setTopNavBarModules(top)
    }
}

// MARK: - Navbar Drop Delegate

struct NavBarDropDelegate: DropDelegate {
    let item: UUID
    @Binding var items: [UUID]
    @Binding var draggedItem: UUID?
    @Binding var sourceList: [UUID]
    let isSource: (UUID) -> Bool
    let onUpdate: () -> Void
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        guard draggedItem != item else { return }
        
        // Case 1: Cross-section drag (from other list)
        if isSource(draggedItem) {
            // Remove from source list
            if let fromIndex = sourceList.firstIndex(of: draggedItem) {
                sourceList.remove(at: fromIndex)
                // Add to destination only if space available and not already there
                if items.count < 5 && !items.contains(draggedItem) {
                    items.append(draggedItem)
                }
            }
            onUpdate()
            return
        }
        
        // Case 2: Reorder within same list
        guard let fromIndex = items.firstIndex(of: draggedItem) else { return }
        guard let toIndex = items.firstIndex(of: item) else { return }
        
        if fromIndex != toIndex {
            items.move(fromOffsets: IndexSet(integer: fromIndex),
                       toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            onUpdate()
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

// MARK: - Module Picker View

@available(iOS 16.0, *)
private struct ModulePickerView: View {
    @Environment(ModuleRegistry.self) var registry
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedModules: [UUID]
    let maxCount: Int
    let onSave: ([UUID]) -> Void
    
    var availableModules: [AnyAppModule] {
        // Show all modules that aren't already selected
        registry.registeredModules.filter { !selectedModules.contains($0.id) }
    }
    
    var body: some View {
        List {
            ForEach(availableModules) { module in
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: module.iconName)
                            .foregroundColor(.black)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(module.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if selectedModules.count < maxCount {
                            selectedModules.append(module.id)
                            onSave(selectedModules)
                            dismiss()
                        }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Add Module")
    }
}

#Preview {
    SettingsModuleView()
        .environment(ModuleState.shared)
}
