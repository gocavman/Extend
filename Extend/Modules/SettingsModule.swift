////
////  SettingsModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PhotosUI

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
    @Environment(DashboardHeaderState.self) var dashboardHeaderState
    @Environment(VoiceTrainerState.self) var voiceTrainerState

    @State private var showingResetAlert = false
    @State private var isNavBarSectionExpanded = false
    @State private var isDashboardSectionExpanded = false
    @State private var isVoiceTrainerSectionExpanded = false

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
                    DisclosureGroup("NavBar", isExpanded: $isNavBarSectionExpanded) {
                        NavigationLink(destination: NavBarCustomizationView()) {
                            Text("Customize")
                        }

                        ColorPicker("Background Color", selection: Binding(
                            get: { moduleState.navBarBackgroundColor },
                            set: { moduleState.updateNavBarBackgroundColor($0) }
                        ))

                        Toggle("Use Gradient", isOn: Binding(
                            get: { moduleState.navBarUseGradient },
                            set: { moduleState.updateNavBarUseGradient($0) }
                        ))

                        if moduleState.navBarUseGradient {
                            ColorPicker("Gradient Secondary", selection: Binding(
                                get: { moduleState.navBarGradientSecondaryColor },
                                set: { moduleState.updateNavBarGradientSecondaryColor($0) }
                            ))
                        }

                        ColorPicker("Text Color", selection: Binding(
                            get: { moduleState.navBarTextColor },
                            set: { moduleState.updateNavBarTextColor($0) }
                        ))
                    }

                    // MARK: - Dashboard Section
                    DisclosureGroup("Dashboard", isExpanded: $isDashboardSectionExpanded) {
                        NavigationLink(destination: DashboardCustomizationView()) {
                            Text("Customize")
                        }
                        
                        NavigationLink(destination: DashboardHeaderSettingsView()) {
                            Text("Header")
                        }
                    }

                    // MARK: - Voice Trainer Section
                    DisclosureGroup("Voice Trainer", isExpanded: $isVoiceTrainerSectionExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Start Warning")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            HStack(spacing: 12) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if voiceTrainerState.workoutStartWarning > 0 {
                                        voiceTrainerState.workoutStartWarning -= 1
                                        voiceTrainerState.saveSettings()
                                    }
                                }) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                                .disabled(voiceTrainerState.workoutStartWarning <= 0)
                                
                                Text("\(voiceTrainerState.workoutStartWarning)s")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(minWidth: 40)
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if voiceTrainerState.workoutStartWarning < 30 {
                                        voiceTrainerState.workoutStartWarning += 1
                                        voiceTrainerState.saveSettings()
                                    }
                                }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                                .disabled(voiceTrainerState.workoutStartWarning >= 30)
                            }
                            Text("Countdown before workout starts")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rest End Warning")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            HStack(spacing: 12) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if voiceTrainerState.restEndWarning > 0 {
                                        voiceTrainerState.restEndWarning -= 1
                                        voiceTrainerState.saveSettings()
                                    }
                                }) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                                .disabled(voiceTrainerState.restEndWarning <= 0)
                                
                                Text("\(voiceTrainerState.restEndWarning)s")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(minWidth: 40)
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if voiceTrainerState.restEndWarning < 30 {
                                        voiceTrainerState.restEndWarning += 1
                                        voiceTrainerState.saveSettings()
                                    }
                                }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                                .disabled(voiceTrainerState.restEndWarning >= 30)
                            }
                            Text("Countdown during last seconds of rest")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
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
        // Order: Dashboard, Workout, Generate, Quick, Settings, Log, Timer, Exercises, Muscles, Equipment

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
        dashboardHeaderState.resetDefaults()
        muscleGroupsState.resetGroups()
        equipmentState.resetItems()
        ExercisesState.shared.resetExercises()
        WorkoutsState.shared.resetWorkouts()
        GenerateState.shared.resetGenerated()
        QuickWorkoutState.shared.resetFavorites()
        WorkoutLogState.shared.resetLogs()

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
        
        // Check if currently selected module is being removed
        // Don't navigate if we're currently in Settings (to avoid disrupting the user)
        if let selectedID = state.selectedModuleID, selectedID != settingsModuleID {
            let allModules = bottom + top
            if !allModules.contains(selectedID) {
                // Navigate to Dashboard if the current module is no longer in any navbar
                if allModules.contains(ModuleIDs.dashboard) {
                    state.selectModule(ModuleIDs.dashboard)
                } else if let firstModule = allModules.first {
                    state.selectModule(firstModule)
                }
            }
        }
        
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
    
    @State private var tempSelected: Set<UUID> = []
    
    var availableModules: [AnyAppModule] {
        // Show all modules that aren't already selected
        registry.registeredModules.filter { !selectedModules.contains($0.id) }
    }
    
    private var canAddMore: Bool {
        selectedModules.count + tempSelected.count < maxCount
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(availableModules) { module in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if tempSelected.contains(module.id) {
                            tempSelected.remove(module.id)
                        } else if canAddMore {
                            tempSelected.insert(module.id)
                        }
                    }) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: module.iconName)
                                    .foregroundColor(.black)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(module.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text(module.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if tempSelected.contains(module.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.black)
                            } else if !canAddMore {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddMore && !tempSelected.contains(module.id))
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var newList = selectedModules
                        newList.append(contentsOf: tempSelected)
                        onSave(newList)
                        dismiss()
                    }
                    .disabled(tempSelected.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Dashboard Customization View

@available(iOS 16.0, *)
private struct DashboardCustomizationView: View {
    @Environment(DashboardState.self) var dashboardState
    @Environment(ModuleRegistry.self) var registry
    
    @State private var showingAddTile = false
    @State private var editingTile: DashboardTile?
    
    var body: some View {
        List {
            Section("Tiles") {
                if dashboardState.tiles.isEmpty {
                    Text("No tiles added")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    ForEach(dashboardState.tiles.sorted { $0.order < $1.order }, id: \.id) { tile in
                        HStack(spacing: 12) {
                            Image(systemName: tile.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                .cornerRadius(6)
                            
                            Text(tile.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingTile = tile
                            }) {
                                Image(systemName: "gear")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                dashboardState.deleteTile(tile.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { indices, newOffset in
                        var sortedTiles = dashboardState.tiles.sorted { $0.order < $1.order }
                        sortedTiles.move(fromOffsets: indices, toOffset: newOffset)
                        for (newIndex, tile) in sortedTiles.enumerated() {
                            var updated = tile
                            updated.order = newIndex
                            dashboardState.updateTile(updated)
                        }
                    }
                }
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingAddTile = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.black)
                        Text("Add Tile")
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .navigationTitle("Dashboard Tiles")
        .environment(\.editMode, .constant(.active))
        .sheet(isPresented: $showingAddTile) {
            DashboardAddTileSheet { newTile in
                dashboardState.addTile(newTile)
            }
            .environment(dashboardState)
            .environment(registry)
        }
        .sheet(item: $editingTile) { tile in
            DashboardEditTileSheet(tile: tile) { updatedTile in
                dashboardState.updateTile(updatedTile)
            }
        }
    }
}

// MARK: - Dashboard Add Tile Sheet (Simplified for Settings)

private struct DashboardAddTileSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ModuleRegistry.self) var registry
    @Environment(DashboardState.self) var dashboardState

    @State private var selectedModuleIDs: Set<UUID> = []
    @State private var selectedStatCards: Set<StatCardType> = []
    @State private var selectedBlankIcon: String? = nil

    let onAdd: (DashboardTile) -> Void

    private let icons = [
        "dumbbell", "dumbbell.fill", "heart", "heart.fill", "lungs", "lungs.fill",
        "timer", "chart.line.uptrend.xyaxis", "flame", "target", "star", "bolt", "gear", "square.grid.2x2", "sparkles", "clock", "trophy", "leaf", "sun.max", "moon",
        "eye", "brain", "staroflife.fill", "cross", "cup.and.saucer.fill", "wineglass", "mug.fill",
        "pi", "number", "lightbulb.fill",
        "figure.strengthtraining.traditional", "figure.walk.treadmill", "figure.walk", "person.fill",
        "figure.run", "figure.boxing", "figure.cooldown", "figure.core.training", "figure.cross.training", "figure.dance", "figure.golf", "figure.gymnastics", "figure.yoga", "figure", "figure.hiking", "figure.kickboxing",
        "figure.mind.and.body", "figure.outdoor.cycle", "figure.rower", "figure.stairs",
        "tortoise.fill", "dog.fill", "cat.fill", "pawprint.fill", "lizard.fill", "bird.fill", "ant.fill", "hare.fill", "fish.fill", "fossil.shell.fill", "atom", "tree.fill"
    ]

    private var moduleQuickOptions: [AnyAppModule] {
        let existingTileModuleIDs = Set(dashboardState.tiles.compactMap { $0.targetModuleID })
        return registry.registeredModules
            .filter { !existingTileModuleIDs.contains($0.id) && $0.displayName != "Dashboard" && $0.displayName != "Game 1" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var statCardOptions: [StatCardType] {
        let used = Set(dashboardState.tiles.compactMap { $0.statCardType })
        return StatCardType.allCases.filter { !used.contains($0) }
    }

    private var hasSelection: Bool {
        !selectedModuleIDs.isEmpty || !selectedStatCards.isEmpty || selectedBlankIcon != nil
    }

    private var canAddMore: Bool {
        let currentCount = dashboardState.tiles.count
        let newCount = selectedModuleIDs.count + selectedStatCards.count + (selectedBlankIcon == nil ? 0 : 1)
        return currentCount + newCount <= 10
    }

    private func iconForStatCard(_ statCard: StatCardType) -> String {
        switch statCard {
        case .totalWorkouts: return "list.bullet"
        case .dayStreaks: return "flame"
        case .totalTime: return "clock"
        case .favoriteExercise: return "star"
        case .favoriteDay: return "calendar"
        case .workoutFrequency: return "chart.bar"
        case .muscleGroupDistribution: return "chart.pie"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Modules") {
                    ForEach(moduleQuickOptions, id: \.id) { module in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selectedModuleIDs.contains(module.id) {
                                selectedModuleIDs.remove(module.id)
                            } else {
                                selectedModuleIDs.insert(module.id)
                            }
                        }) {
                            HStack {
                                Text(module.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedModuleIDs.contains(module.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAddMore && !selectedModuleIDs.contains(module.id))
                    }
                }

                Section("Stat Cards") {
                    if statCardOptions.isEmpty {
                        Text("All stat cards are already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(statCardOptions, id: \.self) { stat in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedStatCards.contains(stat) {
                                    selectedStatCards.remove(stat)
                                } else {
                                    selectedStatCards.insert(stat)
                                }
                            }) {
                                HStack {
                                    Text(stat.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedStatCards.contains(stat) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.black)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Mini Games") {
                    if let game1Module = registry.registeredModules.first(where: { $0.displayName == "Game 1" }) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selectedModuleIDs.contains(game1Module.id) {
                                selectedModuleIDs.remove(game1Module.id)
                            } else {
                                selectedModuleIDs.insert(game1Module.id)
                            }
                        }) {
                            HStack {
                                Text("Game 1")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedModuleIDs.contains(game1Module.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAddMore && !selectedModuleIDs.contains(game1Module.id))
                    }
                }

                Section("Blank Tile") {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedBlankIcon = selectedBlankIcon == nil ? icons.first : nil
                    }) {
                        HStack {
                            Text("Add blank tile")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedBlankIcon != nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.black)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if selectedBlankIcon != nil {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedBlankIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .frame(maxWidth: .infinity, maxHeight: 44)
                                        .background(selectedBlankIcon == icon ? Color.black.opacity(0.15) : Color(red: 0.96, green: 0.96, blue: 0.97))
                                        .cornerRadius(8)
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Tile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        
                        for statCard in selectedStatCards {
                            let size: TileSize = (statCard == .workoutFrequency || statCard == .muscleGroupDistribution) ? .large : .small
                            let tile = DashboardTile(
                                title: statCard.rawValue,
                                icon: iconForStatCard(statCard),
                                order: dashboardState.tiles.count,
                                tileType: .statCard,
                                statCardType: statCard,
                                size: size
                            )
                            onAdd(tile)
                        }

                        for moduleID in selectedModuleIDs {
                            // Check if this is Game 1 (special case since it's filtered from moduleQuickOptions)
                            if let game1Module = registry.registeredModules.first(where: { $0.displayName == "Game 1" && $0.id == moduleID }) {
                                let tile = DashboardTile(
                                    title: game1Module.displayName,
                                    icon: game1Module.iconName,
                                    order: dashboardState.tiles.count,
                                    targetModuleID: game1Module.id,
                                    tileType: .moduleShortcut,
                                    size: .small
                                )
                                onAdd(tile)
                            } else if let module = moduleQuickOptions.first(where: { $0.id == moduleID }) {
                                let tile = DashboardTile(
                                    title: module.displayName,
                                    icon: module.iconName,
                                    order: dashboardState.tiles.count,
                                    targetModuleID: module.id,
                                    tileType: .moduleShortcut,
                                    size: .small
                                )
                                onAdd(tile)
                            }
                        }

                        if let blankIcon = selectedBlankIcon {
                            let tile = DashboardTile(
                                title: "",
                                icon: blankIcon,
                                order: dashboardState.tiles.count,
                                targetModuleID: nil,
                                tileType: .moduleShortcut,
                                size: .small,
                                blankAction: .animation1
                            )
                            onAdd(tile)
                        }

                        if hasSelection {
                            dismiss()
                        }
                    }
                    .disabled(!hasSelection)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Dashboard Edit Tile Sheet (Simplified for Settings)

private struct DashboardEditTileSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let tile: DashboardTile
    
    @State private var title: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedSize: TileSize = .small
    @State private var selectedBlankAction: BlankTileAction = .animation1
    
    let onSave: (DashboardTile) -> Void

    private let icons = [
        "dumbbell", "dumbbell.fill", "heart", "heart.fill", "suit.club.fill", "suit.diamond.fill", "suit.spade.fill", "lungs", "lungs.fill",
        "timer", "chart.line.uptrend.xyaxis", "flame", "target", "star", "bolt", "gear", "square.grid.2x2", "sparkles", "clock", "trophy", "leaf", "sun.max", "moon",
        "eye", "brain", "staroflife.fill", "cross", "cup.and.saucer.fill", "wineglass", "mug.fill",
        "pi", "number", "lightbulb.fill",
        "figure.strengthtraining.traditional", "figure.walk.treadmill", "figure.walk", "person.fill",
        "figure.run", "figure.boxing", "figure.cooldown", "figure.core.training", "figure.cross.training", "figure.dance", "figure.golf", "figure.gymnastics", "figure.yoga", "figure", "figure.hiking", "figure.kickboxing",
        "figure.mind.and.body", "figure.outdoor.cycle", "figure.rower", "figure.stairs",
        "tortoise.fill", "dog.fill", "cat.fill", "pawprint.fill", "lizard.fill", "bird.fill", "ant.fill", "hare.fill", "fish.fill", "fossil.shell.fill", "atom", "tree.fill"
    ]
    
    private func availableSizes() -> [TileSize] {
        if tile.tileType == .graph {
            return [.large]
        }
        if tile.tileType == .statCard,
           let statCard = tile.statCardType,
           (statCard == .workoutFrequency || statCard == .muscleGroupDistribution) {
            return [.large]
        }
        return TileSize.allCases
    }

    var body: some View {
        let isBlankTile = tile.targetModuleID == nil && tile.tileType == .moduleShortcut && tile.statCardType == nil
        NavigationStack {
            Form {
                Section("Tile Details") {
                    TextField("Title", text: $title)
                }

                if isBlankTile {
                    Section("Blank Tile Action") {
                        Picker("Action", selection: $selectedBlankAction) {
                            ForEach([BlankTileAction.animation1, BlankTileAction.animation2, BlankTileAction.animation3], id: \.self) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                    }
                }

                Section("Tile Size") {
                    Picker("Size", selection: $selectedSize) {
                        ForEach(availableSizes(), id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            VStack {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .frame(maxWidth: .infinity, maxHeight: 50)
                                        .background(selectedIcon == icon ? Color.black.opacity(0.15) : Color(red: 0.96, green: 0.96, blue: 0.97))
                                        .cornerRadius(8)
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = tile.title
                selectedIcon = tile.icon
                selectedSize = tile.size
                selectedBlankAction = tile.blankAction ?? .animation1
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var updatedTile = tile
                        updatedTile.title = title
                        updatedTile.icon = selectedIcon
                        updatedTile.size = selectedSize
                        updatedTile.blankAction = isBlankTile ? selectedBlankAction : nil
                        onSave(updatedTile)
                        dismiss()
                    }
                    .disabled(!isBlankTile && title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Dashboard Header Settings View

@available(iOS 16.0, *)
private struct DashboardHeaderSettingsView: View {
    @Environment(DashboardHeaderState.self) var dashboardHeaderState
    
    @State private var selectedHeaderImage: PhotosPickerItem? = nil
    @State private var showingClearHeaderImageAlert = false
    
    var body: some View {
        Form {
            Section("Title") {
                TextField(
                    "Title",
                    text: Binding(
                        get: { dashboardHeaderState.title },
                        set: { dashboardHeaderState.updateTitle($0) }
                    )
                )
            }
            
            Section("Image") {
                Picker("Image Style", selection: Binding(
                    get: { dashboardHeaderState.imageStyle },
                    set: { dashboardHeaderState.updateImageStyle($0) }
                )) {
                    ForEach(HeaderImageStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                
                HStack {
                    PhotosPicker(selection: $selectedHeaderImage, matching: .images) {
                        HStack {
                            Text("Choose Image")
                            Spacer()
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                    }

                    if dashboardHeaderState.imageData != nil {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingClearHeaderImageAlert = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Section("Background") {
                ColorPicker("Background Color", selection: Binding(
                    get: { dashboardHeaderState.backgroundColor },
                    set: { dashboardHeaderState.updateBackgroundColor($0) }
                ))

                Toggle("Use Gradient", isOn: Binding(
                    get: { dashboardHeaderState.backgroundUseGradient },
                    set: { dashboardHeaderState.updateBackgroundUseGradient($0) }
                ))

                if dashboardHeaderState.backgroundUseGradient {
                    ColorPicker("Gradient Secondary", selection: Binding(
                        get: { dashboardHeaderState.backgroundGradientSecondaryColor },
                        set: { dashboardHeaderState.updateBackgroundGradientSecondaryColor($0) }
                    ))
                }
            }
            
            Section("Text") {
                ColorPicker("Text Color", selection: Binding(
                    get: { dashboardHeaderState.textColor },
                    set: { dashboardHeaderState.updateTextColor($0) }
                ))
            }
        }
        .navigationTitle("Header")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove dashboard image?", isPresented: $showingClearHeaderImageAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dashboardHeaderState.updateImageData(nil)
            }
        } message: {
            Text("This will remove the custom dashboard header image.")
        }
        .onChange(of: selectedHeaderImage) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    dashboardHeaderState.updateImageData(data)
                }
            }
        }
    }
}

#Preview {
    SettingsModuleView()
        .environment(ModuleState.shared)
}
