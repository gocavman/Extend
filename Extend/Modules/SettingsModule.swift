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
    @State private var isNavBarColorExpanded = false
    @State private var isDashboardSectionExpanded = false
    @State private var isMusclesSectionExpanded = false

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

                        DisclosureGroup("Color", isExpanded: $isNavBarColorExpanded) {
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

                    // MARK: - Muscles Section
                    DisclosureGroup("Image Set", isExpanded: $isMusclesSectionExpanded) {
                        HStack {
                            Text("Muscles")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { muscleGroupsState.selectedBodyOption },
                                set: { muscleGroupsState.applyBodyOption($0) }
                            )) {
                                Text("Option 1").tag(MuscleGroupsState.BodyImageOption.male)
                                Text("Option 2").tag(MuscleGroupsState.BodyImageOption.female)
                                Text("Custom").tag(MuscleGroupsState.BodyImageOption.custom)
                            }
                            .pickerStyle(.menu)
                        }
                        Text(muscleGroupsState.selectedBodyOption == .custom
                             ? "Custom: Edit each muscle individually to assign images."
                             : muscleGroupsState.selectedBodyOption == .male
                               ? "Option 1: Default images are used for all muscles."
                               : "Option 2: Default images are used for all muscles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                    Text("This will reset the whole app back to default settings; clearing history, logs, favorites and customizations (navbars, dashboard tiles, exercises, workouts, muscle groups, equipment, timers and voice trainers.")
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
            ModuleIDs.progress
        ]

        let topModules: [UUID] = [
            ModuleIDs.timer,
            ModuleIDs.voiceTrainer,
            ModuleIDs.exercises,
            ModuleIDs.muscles,
            ModuleIDs.settings
        ]

        moduleState.setBottomNavBarModules(bottomModules)
        moduleState.setTopNavBarModules(topModules)
        moduleState.resetNavBarAppearance()

        // Reset data
        dashboardState.resetTiles()
        dashboardHeaderState.resetDefaults()
        muscleGroupsState.resetGroups()
        muscleGroupsState.applyBodyOption(.male)
        equipmentState.resetItems()
        ExercisesState.shared.resetExercises()
        WorkoutsState.shared.resetWorkouts()
        GenerateState.shared.resetGenerated()
        GenerateState.shared.resetFilterPresets()
        QuickWorkoutState.shared.resetFavorites()
        TimerState.shared.reset()
        WorkoutLogState.shared.resetLogs()
        voiceTrainerState.resetConfigurations()

        // Reset Game Progress - Workout Buddy (Game 1)
        // Remove the entire stats dictionary and let it reinitialize
        UserDefaults.standard.removeObject(forKey: "game1_stats")
        
        // Reset Game Progress - Workout Match (Match Game)
        UserDefaults.standard.removeObject(forKey: "matchGameCurrentLevel")
        UserDefaults.standard.set(1, forKey: "matchGameCurrentLevel")
        UserDefaults.standard.removeObject(forKey: "matchGameUnlockedLevels")
        UserDefaults.standard.set([1], forKey: "matchGameUnlockedLevels")
        
        // Reset any per-level scores
        if let savedLevels = UserDefaults.standard.array(forKey: "matchGameUnlockedLevels") as? [Int] {
            for levelId in savedLevels {
                UserDefaults.standard.removeObject(forKey: "matchGameScore_\(levelId)")
            }
        }
        
        print("🔄 Game progress reset: Workout Buddy & Workout Match back to level 1")

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

// MARK: - Shared module row (used by both navbar picker and dashboard tile sheet)

private struct ModulePickerRow: View {
    let module: AnyAppModule
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(module.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.black)
            }
        }
        .contentShape(Rectangle())
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
        // Show all modules that aren't already selected, excluding hidden-from-nav modules
        let excluded = ["Animator"]
        return registry.registeredModules.filter { !selectedModules.contains($0.id) && !excluded.contains($0.displayName) }
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
                        ModulePickerRow(module: module, isSelected: tempSelected.contains(module.id))
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
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(TimerState.self) var timerState
    @Environment(VoiceTrainerState.self) var voiceTrainerState
    @Environment(ExercisesState.self) var exercisesState
    
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
            .environment(workoutsState)
            .environment(timerState)
            .environment(voiceTrainerState)
            .environment(exercisesState)
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
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(TimerState.self) var timerState
    @Environment(VoiceTrainerState.self) var voiceTrainerState
    @Environment(ExercisesState.self) var exercisesState

    @State private var searchText: String = ""
    @State private var selectedModuleIDs: Set<UUID> = []
    @State private var selectedStatCards: Set<StatCardType> = []
    @State private var selectedBlankIcon: String? = nil
    @State private var selectedShortcuts: Set<String> = []   // "workout:<uuid>", "timer:<uuid>", or "voicetrainer:<uuid>"

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

    private var existingTileModuleIDs: Set<UUID> {
        Set(dashboardState.tiles.compactMap { $0.targetModuleID })
    }

    private var moduleQuickOptions: [AnyAppModule] {
        registry.registeredModules
            .filter { !existingTileModuleIDs.contains($0.id) && $0.displayName != "Dashboard" && $0.displayName != "Workout Buddy" && $0.displayName != "Workout Match" && $0.displayName != "Animator" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var statCardOptions: [StatCardType] {
        let used = Set(dashboardState.tiles.compactMap { $0.statCardType })
        return StatCardType.allCases.filter { !used.contains($0) }
    }

    private var hasSelection: Bool {
        !selectedModuleIDs.isEmpty || !selectedStatCards.isEmpty || selectedBlankIcon != nil || !selectedShortcuts.isEmpty
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
        case .volumeThisWeek: return "scalemass"
        case .longestStreak: return "trophy"
        case .restDays: return "moon"
        case .personalRecord: return "medal"
        }
    }

    private func descriptionForStatCard(_ statCard: StatCardType) -> String {
        switch statCard {
        case .totalWorkouts:           return "Cumulative count of all completed workouts."
        case .dayStreaks:               return "Your current consecutive active days streak."
        case .totalTime:               return "Total time logged across all workouts."
        case .favoriteExercise:        return "The exercise you perform most frequently."
        case .favoriteDay:             return "The day of the week you work out most often."
        case .workoutFrequency:        return "Bar chart of workout activity over the last 14 days."
        case .muscleGroupDistribution: return "Pie chart of muscle groups trained in the last 7 days."
        case .volumeThisWeek:          return "Total sets × reps × weight logged this week."
        case .longestStreak:           return "Your all-time best consecutive workout streak."
        case .restDays:                return "Days with no workout logged in the last 14 days."
        case .personalRecord:          return "Your heaviest single set weight ever logged."
        }
    }

    private var isSearching: Bool { !searchText.isEmpty }

    private var filteredModuleOptions: [AnyAppModule] {
        guard isSearching else { return moduleQuickOptions }
        return moduleQuickOptions.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredStatCardOptions: [StatCardType] {
        guard isSearching else { return statCardOptions }
        return statCardOptions.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
            descriptionForStatCard($0).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SearchField(text: $searchText, placeholder: "Search tiles...")
                }

                Section("Modules") {
                    if filteredModuleOptions.isEmpty {
                        Text(isSearching ? "No modules match your search" : "All modules are already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(filteredModuleOptions, id: \.id) { module in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedModuleIDs.contains(module.id) {
                                    selectedModuleIDs.remove(module.id)
                                } else {
                                    selectedModuleIDs.insert(module.id)
                                }
                            }) {
                                ModulePickerRow(module: module, isSelected: selectedModuleIDs.contains(module.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Stat Cards") {
                    if filteredStatCardOptions.isEmpty {
                        Text(isSearching ? "No stat cards match your search" : "All stat cards are already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(filteredStatCardOptions, id: \.self) { stat in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedStatCards.contains(stat) {
                                    selectedStatCards.remove(stat)
                                } else {
                                    selectedStatCards.insert(stat)
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stat.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text(descriptionForStatCard(stat))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
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
                    let buddyModule = registry.registeredModules.first(where: { $0.displayName == "Workout Buddy" })
                    let matchModule = registry.registeredModules.first(where: { $0.displayName == "Workout Match" })
                    let buddyAdded = buddyModule.map { existingTileModuleIDs.contains($0.id) } ?? true
                    let matchAdded = matchModule.map { existingTileModuleIDs.contains($0.id) } ?? true
                    let buddyVisible = !buddyAdded && (!isSearching || "Workout Buddy".localizedCaseInsensitiveContains(searchText))
                    let matchVisible = !matchAdded && (!isSearching || "Workout Match".localizedCaseInsensitiveContains(searchText))

                    if !buddyVisible && !matchVisible {
                        Text(isSearching ? "No mini games match your search" : "All mini games are already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        // Workout Buddy
                        if let workoutBuddyModule = buddyModule, buddyVisible {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedModuleIDs.contains(workoutBuddyModule.id) {
                                    selectedModuleIDs.remove(workoutBuddyModule.id)
                                } else {
                                    selectedModuleIDs.insert(workoutBuddyModule.id)
                                }
                            }) {
                                ModulePickerRow(module: workoutBuddyModule, isSelected: selectedModuleIDs.contains(workoutBuddyModule.id))
                            }
                            .buttonStyle(.plain)
                        }

                        // Workout Match
                        if let workoutMatchModule = matchModule, matchVisible {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedModuleIDs.contains(workoutMatchModule.id) {
                                    selectedModuleIDs.remove(workoutMatchModule.id)
                                } else {
                                    selectedModuleIDs.insert(workoutMatchModule.id)
                                }
                            }) {
                                ModulePickerRow(module: workoutMatchModule, isSelected: selectedModuleIDs.contains(workoutMatchModule.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // MARK: Shortcuts
                Section("Shortcuts") {
                    let existingShortcutKeys = Set(dashboardState.tiles.compactMap { t -> String? in
                        guard t.tileType == .shortcut, let st = t.shortcutType, let sid = t.shortcutItemID else { return nil }
                        return "\(st.rawValue.lowercased().replacingOccurrences(of: " ", with: "")):\(sid.uuidString)"
                    })

                    let availableWorkouts      = workoutsState.workouts
                        .filter { !existingShortcutKeys.contains("workout:\($0.id.uuidString)") }
                        .filter { !isSearching || $0.name.localizedCaseInsensitiveContains(searchText) }
                    let availableTimers        = timerState.configs
                        .filter { !existingShortcutKeys.contains("timer:\($0.id.uuidString)") }
                        .filter { !isSearching || $0.name.localizedCaseInsensitiveContains(searchText) || $0.type.rawValue.localizedCaseInsensitiveContains(searchText) }
                    let availableVoiceTrainers = voiceTrainerState.savedConfigurations
                        .filter { !existingShortcutKeys.contains("voicetrainer:\($0.id.uuidString)") }
                        .filter { !isSearching || $0.name.localizedCaseInsensitiveContains(searchText) }
                    let availableExercises     = exercisesState.exercises
                        .filter { !existingShortcutKeys.contains("quickexercise:\($0.id.uuidString)") }
                        .filter { !isSearching || $0.name.localizedCaseInsensitiveContains(searchText) }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                    if availableWorkouts.isEmpty && availableTimers.isEmpty && availableVoiceTrainers.isEmpty && availableExercises.isEmpty {
                        Text(isSearching ? "No shortcuts match your search" : "No saved workouts, timers, trainers, or exercises to add as shortcuts.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        if !availableWorkouts.isEmpty {
                            Text("Workouts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(availableWorkouts) { workout in
                                let key = "workout:\(workout.id.uuidString)"
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if selectedShortcuts.contains(key) { selectedShortcuts.remove(key) } else { selectedShortcuts.insert(key) }
                                }) {
                                    HStack {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .foregroundColor(.secondary)
                                        Text(workout.name).foregroundColor(.primary)
                                        Spacer()
                                        if selectedShortcuts.contains(key) {
                                            Image(systemName: "checkmark").foregroundColor(.black)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !availableTimers.isEmpty {
                            Text("Timers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(availableTimers) { config in
                                let key = "timer:\(config.id.uuidString)"
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if selectedShortcuts.contains(key) { selectedShortcuts.remove(key) } else { selectedShortcuts.insert(key) }
                                }) {
                                    HStack {
                                        Image(systemName: "timer")
                                            .foregroundColor(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(config.name).foregroundColor(.primary)
                                            Text(config.type.rawValue)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedShortcuts.contains(key) {
                                            Image(systemName: "checkmark").foregroundColor(.black)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !availableVoiceTrainers.isEmpty {
                            Text("Voice Trainer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(availableVoiceTrainers) { config in
                                let key = "voicetrainer:\(config.id.uuidString)"
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if selectedShortcuts.contains(key) { selectedShortcuts.remove(key) } else { selectedShortcuts.insert(key) }
                                }) {
                                    HStack {
                                        Image(systemName: "speaker.wave.2")
                                            .foregroundColor(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(config.name).foregroundColor(.primary)
                                            if !config.parameterSummary.isEmpty {
                                                Text(config.parameterSummary)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if selectedShortcuts.contains(key) {
                                            Image(systemName: "checkmark").foregroundColor(.black)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if !availableExercises.isEmpty {
                            Text("Quick Exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(availableExercises) { exercise in
                                let key = "quickexercise:\(exercise.id.uuidString)"
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if selectedShortcuts.contains(key) { selectedShortcuts.remove(key) } else { selectedShortcuts.insert(key) }
                                }) {
                                    HStack {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.secondary)
                                        Text(exercise.name).foregroundColor(.primary)
                                        Spacer()
                                        if selectedShortcuts.contains(key) {
                                            Image(systemName: "checkmark").foregroundColor(.black)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !isSearching || "Blank Tile".localizedCaseInsensitiveContains(searchText) {
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
                } // end Blank Tile visibility
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
                            let isGraph = statCard == .workoutFrequency || statCard == .muscleGroupDistribution
                            let size: TileSize = isGraph ? .large : .small
                            let tile = DashboardTile(
                                title: statCard.rawValue,
                                icon: iconForStatCard(statCard),
                                order: dashboardState.tiles.count,
                                tileType: .statCard,
                                statCardType: statCard,
                                size: size,
                                accentPlacement: isGraph ? .none : .left,
                                accentColorHex: "#CCCCCC"
                            )
                            onAdd(tile)
                        }

                        for moduleID in selectedModuleIDs {
                            // Check if this is Workout Buddy or Workout Match (mini games)
                            if let miniGameModule = registry.registeredModules.first(where: { ($0.displayName == "Workout Buddy" || $0.displayName == "Workout Match") && $0.id == moduleID }) {
                                let tile = DashboardTile(
                                    title: miniGameModule.displayName,
                                    icon: miniGameModule.iconName,
                                    order: dashboardState.tiles.count,
                                    targetModuleID: miniGameModule.id,
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

                        // Shortcut tiles
                        for key in selectedShortcuts {
                            let parts = key.split(separator: ":").map(String.init)
                            guard parts.count == 2, let itemID = UUID(uuidString: parts[1]) else { continue }
                            if parts[0] == "workout", let workout = workoutsState.workouts.first(where: { $0.id == itemID }) {
                                let tile = DashboardTile(
                                    title: workout.name,
                                    icon: "figure.strengthtraining.traditional",
                                    order: dashboardState.tiles.count,
                                    tileType: .shortcut,
                                    size: .small,
                                    shortcutType: .workout,
                                    shortcutItemID: workout.id
                                )
                                onAdd(tile)
                            } else if parts[0] == "timer", let config = timerState.configs.first(where: { $0.id == itemID }) {
                                let tile = DashboardTile(
                                    title: config.name,
                                    icon: "timer",
                                    order: dashboardState.tiles.count,
                                    tileType: .shortcut,
                                    size: .small,
                                    shortcutType: .timer,
                                    shortcutItemID: config.id
                                )
                                onAdd(tile)
                            } else if parts[0] == "voicetrainer", let config = voiceTrainerState.savedConfigurations.first(where: { $0.id == itemID }) {
                                let tile = DashboardTile(
                                    title: config.name,
                                    icon: "speaker.wave.2",
                                    order: dashboardState.tiles.count,
                                    tileType: .shortcut,
                                    size: .small,
                                    shortcutType: .voiceTrainer,
                                    shortcutItemID: config.id
                                )
                                onAdd(tile)
                            } else if parts[0] == "quickexercise", let exercise = exercisesState.exercises.first(where: { $0.id == itemID }) {
                                let tile = DashboardTile(
                                    title: exercise.name,
                                    icon: "bolt.fill",
                                    order: dashboardState.tiles.count,
                                    tileType: .shortcut,
                                    size: .small,
                                    shortcutType: .quickExercise,
                                    shortcutItemID: exercise.id
                                )
                                onAdd(tile)
                            }
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
    @State private var accentPlacement: AccentPlacement = .none
    @State private var accentColor: Color = .gray
    @State private var tileTintEnabled: Bool = false
    @State private var tileTintColor: Color = Color(red: 0.96, green: 0.96, blue: 0.97)

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
        if tile.tileType == .graph { return [.large] }
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

                Section("Accent") {
                    Picker("Placement", selection: $accentPlacement) {
                        ForEach(AccentPlacement.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    if accentPlacement != .none {
                        ColorPicker("Accent Color", selection: $accentColor)
                    }
                }

                Section("Tile Tint") {
                    Toggle("Custom background color", isOn: $tileTintEnabled)
                    if tileTintEnabled {
                        ColorPicker("Tint Color", selection: $tileTintColor)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
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
            .navigationTitle("Edit Tile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = tile.title
                selectedIcon = tile.icon
                selectedSize = tile.size
                selectedBlankAction = tile.blankAction ?? .animation1
                accentPlacement = tile.accentPlacement
                accentColor = tile.accentColor
                tileTintEnabled = tile.tileTintHex != nil
                tileTintColor = tile.tileTintColor ?? Color(red: 0.96, green: 0.96, blue: 0.97)
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
                        updatedTile.accentPlacement = accentPlacement
                        updatedTile.accentColorHex = accentColor.toHexString()
                        updatedTile.tileTintHex = tileTintEnabled ? tileTintColor.toHexString() : nil
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
