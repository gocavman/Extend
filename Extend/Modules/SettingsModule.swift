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

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// Settings module for app configuration
public struct SettingsModule: AppModule {
    public let id: UUID = ModuleIDs.settings
    public let displayName: String = "Settings"
    public let iconName: String = "gear"
    public let description: String = "App settings and preferences"
    
    public var order: Int = 4
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(SettingsModuleView(presentedAsSheet: false))
    }

    /// Use this when presenting Settings as a full-screen sheet (e.g. from the dashboard gear icon).
    public var sheetView: AnyView {
        AnyView(SettingsModuleView(presentedAsSheet: true))
    }
}

// MARK: - Settings View

private struct SettingsModuleView: View {
    var presentedAsSheet: Bool = false

    @Environment(\.dismiss) var dismiss
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var moduleState
    @Environment(DashboardState.self) var dashboardState
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(DashboardHeaderState.self) var dashboardHeaderState
    @Environment(VoiceTrainerState.self) var voiceTrainerState
    @Environment(HealthKitState.self) var healthKitState
    @Environment(ExercisesState.self) var exercisesState

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("appColorScheme") private var appColorScheme: String = "light"
    @AppStorage("keepScreenOnDuringSession") private var keepScreenOnDuringSession: Bool = true

    private var preferredScheme: ColorScheme? {
        appColorScheme == "dark" ? .dark : .light
    }

    @State private var showingResetAlert = false
    @State private var isSyncingHealthKit = false
    @State private var isNavBarSectionExpanded = false
    @State private var isNavBarColorExpanded = false
    @State private var isDashboardSectionExpanded = false
    @State private var isMusclesSectionExpanded = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var importResult: ImportResult? = nil

    private enum ImportResult: Identifiable {
        case success(Int)
        case failure(String)
        var id: String {
            switch self {
            case .success(let n): return "success_\(n)"
            case .failure(let m): return "failure_\(m)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title (and back button when presented as a sheet)
            ZStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)

                if presentedAsSheet {
                    HStack {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Dashboard")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            NavigationStack {
                Form {
                    // MARK: - NavBar / Dashboard / Image Set / Weight Unit Section
                    Section {
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

                        DisclosureGroup("Dashboard", isExpanded: $isDashboardSectionExpanded) {
                            NavigationLink(destination: DashboardCustomizationView()) {
                                Text("Customize")
                            }

                            NavigationLink(destination: DashboardHeaderSettingsView()) {
                                Text("Header")
                            }
                        }

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
                                    Text("None").tag(MuscleGroupsState.BodyImageOption.none)
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                            }
                            Text({
                                switch muscleGroupsState.selectedBodyOption {
                                case .male:   return "Option 1: Default images are used for all muscles. Open a muscle in the Muscles section to upload a custom override."
                                case .female: return "Option 2: Default images are used for all muscles. Open a muscle in the Muscles section to upload a custom override."
                                case .none:   return "None: Muscle images are hidden everywhere in the app."
                                }
                            }())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Theme")
                            Spacer()
                            Picker("", selection: $appColorScheme) {
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }

                        HStack {
                            Text("Weight Unit")
                            Spacer()
                            Picker("", selection: $weightUnit) {
                                Text("lbs").tag("lbs")
                                Text("kg").tag("kg")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Keep Screen On During Sessions", isOn: $keepScreenOnDuringSession)
                            Text("Prevents the screen from locking during active timers, workouts, and voice trainer sessions. Uses more battery.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // MARK: - Support Section
                    Section("Support the Developer") {
                        Link(destination: URL(string: "https://paypal.me/gocavman")!) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(Color(red: 0.0, green: 0.45, blue: 0.9))
                                Text("Donate via PayPal")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Link(destination: URL(string: "https://venmo.com/u/Cavan-Mannenbach")!) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(Color(red: 0.18, green: 0.72, blue: 0.40))
                                Text("Donate via Venmo")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // MARK: - Workouts Section
                    Section("Workouts") {
                        Button {
                            showingExportSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.primary)
                                Text("Export Workouts")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(workoutsState.workouts.count)")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        .disabled(workoutsState.workouts.isEmpty)

                        Button {
                            showingImportPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.primary)
                                Text("Import Workouts")
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    // MARK: - Apple Health Section
                    Section("Apple Health") {
                        Toggle("Export Workouts to Health", isOn: Binding(
                            get: { healthKitState.exportStrengthWorkouts },
                            set: { healthKitState.exportStrengthWorkouts = $0 }
                        ))

                        NavigationLink("Import Activities") {
                            ImportActivitiesView()
                                .environment(healthKitState)
                        }

                        if let lastDate = healthKitState.lastImportDate {
                            HStack {
                                Text("Last Synced")
                                Spacer()
                                Text(lastDate, style: .relative)
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }

                        Button {
                            isSyncingHealthKit = true
                            Task {
                                await WorkoutLogState.shared.importFromHealthKit()
                                await WorkoutLogState.shared.exportPendingLogsToHealthKit()
                                isSyncingHealthKit = false
                            }
                        } label: {
                            HStack {
                                Text(isSyncingHealthKit ? "Syncing…" : "Sync Now")
                                    .foregroundColor(.primary)
                                Spacer()
                                if isSyncingHealthKit {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSyncingHealthKit || (!healthKitState.anyImportEnabled && !healthKitState.exportStrengthWorkouts))
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
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.systemBackground))
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
                .alert("Reset App?", isPresented: $showingResetAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        resetApp()
                    }
                } message: {
                    Text("This will reset the whole app back to default settings; clearing history, logs, favorites and customizations (navbars, dashboard tiles, exercises, workouts, muscle groups, equipment, timers and voice trainers).")
                }
                .fullScreenCover(isPresented: $showingExportSheet) {
                    WorkoutExportSheet(
                        workouts: workoutsState.workouts,
                        exercisesState: exercisesState,
                        equipmentState: equipmentState,
                        muscleGroupsState: muscleGroupsState
                    )
                }
                .fileImporter(
                    isPresented: $showingImportPicker,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        do {
                            guard url.startAccessingSecurityScopedResource() else {
                                importResult = .failure("Permission denied for selected file.")
                                return
                            }
                            defer { url.stopAccessingSecurityScopedResource() }
                            let data = try Data(contentsOf: url)
                            let count = try workoutsState.importWorkouts(
                                from: data,
                                exercisesState: exercisesState,
                                equipmentState: equipmentState,
                                muscleGroupsState: muscleGroupsState
                            )
                            importResult = .success(count)
                        } catch {
                            importResult = .failure(error.localizedDescription)
                        }
                    case .failure(let error):
                        importResult = .failure(error.localizedDescription)
                    }
                }
                .alert(item: $importResult) { result in
                    switch result {
                    case .success(let count):
                        return Alert(
                            title: Text("Import Complete"),
                            message: Text("\(count) workout\(count == 1 ? "" : "s") imported successfully."),
                            dismissButton: .default(Text("OK"))
                        )
                    case .failure(let message):
                        return Alert(
                            title: Text("Import Failed"),
                            message: Text(message),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
            }
        }
        .preferredColorScheme(preferredScheme)
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
            ModuleIDs.equipment
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
        HealthKitState.shared.resetAll()

        // Reset Game Progress - Workout Match (Match Game)
        defaults.removeObject(forKey: "matchGameCurrentLevel")
        defaults.set(1, forKey: "matchGameCurrentLevel")
        defaults.removeObject(forKey: "matchGameUnlockedLevels")
        defaults.set([1], forKey: "matchGameUnlockedLevels")
        
        // Reset any per-level scores
        if let savedLevels = defaults.array(forKey: "matchGameUnlockedLevels") as? [Int] {
            for levelId in savedLevels {
                defaults.removeObject(forKey: "matchGameScore_\(levelId)")
            }
        }
        
        print("🔄 Game progress reset: Workout Match back to level 1")

        // Reset Progress module calendar view state
        UserDefaults.standard.removeObject(forKey: "logViewMode")
        UserDefaults.standard.removeObject(forKey: "logShowRibbon")

        // Reset theme to light
        appColorScheme = "light"

        // Route back to Dashboard after reset
        moduleState.selectModule(ModuleIDs.dashboard)
        if presentedAsSheet { dismiss() }
    }
}

// MARK: - Workout Export Sheet

private struct WorkoutExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workouts: [Workout]
    let exercisesState: ExercisesState
    let equipmentState: EquipmentState
    let muscleGroupsState: MuscleGroupsState

    @State private var selectedIDs: Set<UUID> = []
    @State private var shareItem: ExportItem? = nil
    @State private var searchText: String = ""
    @State private var showingExportSuccess = false

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var filteredWorkouts: [Workout] {
        guard !searchText.isEmpty else { return workouts }
        return workouts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.blue)
                Spacer()
                Text("Export Workouts")
                    .font(.headline)
                Spacer()
                Button("Select All") {
                    if selectedIDs.count == filteredWorkouts.count {
                        selectedIDs = []
                    } else {
                        selectedIDs = Set(filteredWorkouts.map { $0.id })
                    }
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            .overlay(alignment: .bottom) { Divider() }

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search workouts", text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            List(filteredWorkouts) { workout in
                Button {
                    if selectedIDs.contains(workout.id) {
                        selectedIDs.remove(workout.id)
                    } else {
                        selectedIDs.insert(workout.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIDs.contains(workout.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedIDs.contains(workout.id) ? .primary : .secondary)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            let exerciseCount = workout.items.filter {
                                if case .exercise = $0 { return true }; return false
                            }.count
                            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))

            // Export button
            Button {
                exportSelected()
            } label: {
                Text("Export \(selectedIDs.count) Workout\(selectedIDs.count == 1 ? "" : "s")")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedIDs.isEmpty ? .secondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedIDs.isEmpty ? Color(uiColor: .systemGray4) : Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .disabled(selectedIDs.isEmpty)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url) {
                showingExportSuccess = true
            }
        }
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your workout\(selectedIDs.count == 1 ? "" : "s") \(selectedIDs.count == 1 ? "was" : "were") exported successfully.")
        }
    }

    private func exportSelected() {
        let toExport = workouts.filter { selectedIDs.contains($0.id) }
        guard let data = WorkoutsState.shared.exportData(
            for: toExport,
            exercisesState: exercisesState,
            equipmentState: equipmentState,
            muscleGroupsState: muscleGroupsState
        ) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date())
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("extend-workouts-\(stamp).json")
        do {
            try data.write(to: tempURL)
            shareItem = ExportItem(url: tempURL)
        } catch {}
    }
}

// MARK: - Share Sheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            if completed { onComplete?() }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
                                        .foregroundColor(.primary)
                                    Text(module.displayName)
                                        .font(.subheadline)
                                }

                                Spacer()

                                if moduleID != dashboardModuleID {
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
                                .foregroundColor(.primary)
                            Text("Add Item")
                                .foregroundColor(.primary)
                        }
                    }
                    .fullScreenCover(isPresented: $showingAddPicker) {
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
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground))
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

// MARK: - Shared module row (used by both navbar picker and dashboard tile sheet)

private struct ModulePickerRow: View {
    let module: AnyAppModule
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
                .background(Color(UIColor.tertiarySystemBackground))
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
                    .foregroundColor(.primary)
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
        return registry.registeredModules
            .filter { !selectedModules.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
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
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
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
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(UIColor.tertiarySystemBackground))
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
                                    .foregroundColor(.primary)
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
                            .foregroundColor(.primary)
                        Text("Add Tile")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Dashboard Tiles")
        .environment(\.editMode, .constant(.active))
        .fullScreenCover(isPresented: $showingAddTile) {
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
        .fullScreenCover(item: $editingTile) { tile in
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
            .filter { !existingTileModuleIDs.contains($0.id) && $0.id != ModuleIDs.dashboard && $0.id != ModuleIDs.matchGame && $0.id != ModuleIDs.stickFigureAnimator }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // PR, 1RM, and Volume can be added multiple times (they're customizable per-tile)
    private let multipleAllowed: Set<StatCardType> = [.personalRecord, .oneRepMax, .volumeThisWeek]

    private var statCardOptions: [StatCardType] {
        let used = Set(dashboardState.tiles.compactMap { $0.statCardType })
        return StatCardType.allCases.filter { !used.contains($0) || multipleAllowed.contains($0) }
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
        case .oneRepMax: return "trophy.fill"
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
        case .oneRepMax:               return "Leaderboard of your best estimated 1-rep maxes by exercise."
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
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listSectionSpacing(0)

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
                                            .foregroundColor(.primary)
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

                // MARK: Animator
                Section("Animator") {
                    let animatorModule = registry.registeredModules.first(where: { $0.id == ModuleIDs.stickFigureAnimator })
                    let animatorAdded = existingTileModuleIDs.contains(ModuleIDs.stickFigureAnimator)
                    let animatorVisible = !animatorAdded && (!isSearching || "Stick Figure Animator".localizedCaseInsensitiveContains(searchText))

                    if !animatorVisible {
                        Text(isSearching ? "No animator tiles match your search" : "Animator tile already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let animatorModule = animatorModule {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selectedModuleIDs.contains(ModuleIDs.stickFigureAnimator) {
                                selectedModuleIDs.remove(ModuleIDs.stickFigureAnimator)
                            } else {
                                selectedModuleIDs.insert(ModuleIDs.stickFigureAnimator)
                            }
                        }) {
                            ModulePickerRow(module: animatorModule, isSelected: selectedModuleIDs.contains(ModuleIDs.stickFigureAnimator))
                        }
                        .buttonStyle(.plain)
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
                                            Image(systemName: "checkmark").foregroundColor(.primary)
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
                                            Image(systemName: "checkmark").foregroundColor(.primary)
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
                                            Image(systemName: "checkmark").foregroundColor(.primary)
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
                                            Image(systemName: "checkmark").foregroundColor(.primary)
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
                                    .foregroundColor(.primary)
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
                                        .background(selectedBlankIcon == icon ? Color.primary.opacity(0.15) : Color(UIColor.tertiarySystemBackground))
                                        .cornerRadius(8)
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                } // end Blank Tile visibility
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
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
                                || statCard == .oneRepMax || statCard == .personalRecord
                                || statCard == .volumeThisWeek || statCard == .favoriteDay
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
                            if let module = registry.registeredModules.first(where: { $0.id == moduleID }) {
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
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(\.dismiss) var dismiss
    @Environment(ExercisesState.self) var exercisesState
    @Environment(WorkoutLogState.self) var logState
    @Environment(WorkoutsState.self) var workoutsState

    let tile: DashboardTile

    @State private var title: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedSize: TileSize = .small
    @State private var selectedBlankAction: BlankTileAction = .animation1
    @State private var accentPlacement: AccentPlacement = .none
    @State private var accentColor: Color = .gray
    @State private var tileTintEnabled: Bool = false
    @State private var tileTintColor: Color = Color(red: 0.96, green: 0.96, blue: 0.97)
    /// For 1RM tiles: nil = auto top-5; non-nil = user-chosen IDs
    @State private var oneRMExerciseIDs: [UUID]? = nil
    /// For PR tiles: nil = auto top-5 by weight; non-nil = user-chosen IDs
    @State private var personalRecordExerciseIDs: [UUID]? = nil
    /// For Volume tiles: nil = all workouts
    @State private var volumeWorkoutName: String? = nil
    /// For Volume tiles: nil = all exercises
    @State private var volumeExerciseID: UUID? = nil

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
        if tile.tileType == .statCard, let statCard = tile.statCardType {
            if statCard == .workoutFrequency || statCard == .muscleGroupDistribution
                || statCard == .volumeThisWeek || statCard == .favoriteDay {
                return [.large]
            }
            if statCard == .oneRepMax || statCard == .personalRecord {
                return [.medium, .large]
            }
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

                // 1RM exercise selection
                if tile.statCardType == .oneRepMax {
                    let eligibleExercises = exercisesState.exercises
                        .filter { logState.bestEstimated1RM(exerciseID: $0.id) != nil }
                        .sorted { $0.name < $1.name }

                    Section {
                        if eligibleExercises.isEmpty {
                            Text("Log sets with 3–10 reps on any exercise to populate this list.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let selected = oneRMExerciseIDs ?? []
                            ForEach(eligibleExercises) { exercise in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    var ids = oneRMExerciseIDs ?? []
                                    if ids.contains(exercise.id) {
                                        ids.removeAll { $0 == exercise.id }
                                    } else if ids.count < 5 {
                                        ids.append(exercise.id)
                                    }
                                    oneRMExerciseIDs = ids.isEmpty ? nil : ids
                                }) {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if let rm = logState.bestEstimated1RM(exerciseID: exercise.id) {
                                            Text(String(format: "%.0f \(weightUnit)", rm))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if selected.contains(exercise.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Exercises (up to 5)")
                    } footer: {
                        Text(oneRMExerciseIDs == nil ? "Showing auto top-5 by best 1RM. Select exercises to pin specific ones." : "Deselect all to revert to auto top-5.")
                            .font(.caption)
                    }
                }

                // PR exercise selection
                if tile.statCardType == .personalRecord {
                    let eligibleExercises = exercisesState.exercises
                        .filter { logState.bestWeight(exerciseID: $0.id) != nil }
                        .sorted { $0.name < $1.name }

                    Section {
                        if eligibleExercises.isEmpty {
                            Text("Log sets with weights on any exercise to populate this list.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let selected = personalRecordExerciseIDs ?? []
                            ForEach(eligibleExercises) { exercise in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    var ids = personalRecordExerciseIDs ?? []
                                    if ids.contains(exercise.id) {
                                        ids.removeAll { $0 == exercise.id }
                                    } else if ids.count < 10 {
                                        ids.append(exercise.id)
                                    }
                                    personalRecordExerciseIDs = ids.isEmpty ? nil : ids
                                }) {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if let w = logState.bestWeight(exerciseID: exercise.id) {
                                            Text(String(format: "%.0f \(weightUnit)", w))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if selected.contains(exercise.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Exercises (up to 10)")
                    } footer: {
                        Text(personalRecordExerciseIDs == nil ? "Showing auto top-5 by best weight. Select exercises to pin specific ones." : "Deselect all to revert to auto top-5.")
                            .font(.caption)
                    }
                }

                // Volume This Week: workout and exercise filter
                if tile.statCardType == .volumeThisWeek {
                    Section {
                        let workoutNames = workoutsState.workouts.map { $0.name }.sorted()
                        if workoutNames.isEmpty {
                            Text("No saved workouts yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: { volumeWorkoutName = nil; volumeExerciseID = nil }) {
                                HStack {
                                    Text("All Workouts")
                                    Spacer()
                                    if volumeWorkoutName == nil {
                                        Image(systemName: "checkmark").foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            ForEach(workoutNames, id: \.self) { name in
                                Button(action: {
                                    volumeWorkoutName = (volumeWorkoutName == name) ? nil : name
                                    volumeExerciseID = nil
                                }) {
                                    HStack {
                                        Text(name)
                                        Spacer()
                                        if volumeWorkoutName == name {
                                            Image(systemName: "checkmark").foregroundColor(.primary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Filter by Workout")
                    } footer: {
                        Text(volumeWorkoutName == nil ? "Showing volume across all workouts." : "Showing volume for \"\(volumeWorkoutName!)\" only.")
                            .font(.caption)
                    }

                    Section {
                        let loggedExercises: [Exercise] = {
                            let loggedIDs = Set(logState.logs.flatMap { $0.exercises }.map { $0.exerciseID })
                            return exercisesState.exercises
                                .filter { loggedIDs.contains($0.id) }
                                .sorted { $0.name < $1.name }
                        }()
                        if loggedExercises.isEmpty {
                            Text("No exercises logged yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: { volumeExerciseID = nil }) {
                                HStack {
                                    Text("All Exercises")
                                    Spacer()
                                    if volumeExerciseID == nil {
                                        Image(systemName: "checkmark").foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            ForEach(loggedExercises) { exercise in
                                Button(action: {
                                    volumeExerciseID = (volumeExerciseID == exercise.id) ? nil : exercise.id
                                }) {
                                    HStack {
                                        Text(exercise.name)
                                        Spacer()
                                        if volumeExerciseID == exercise.id {
                                            Image(systemName: "checkmark").foregroundColor(.primary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Filter by Exercise")
                    } footer: {
                        Text(volumeExerciseID == nil ? "Showing volume across all exercises." : "Showing volume for selected exercise only.")
                            .font(.caption)
                    }
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
                                    .background(selectedIcon == icon ? Color.primary.opacity(0.15) : Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(8)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
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
                oneRMExerciseIDs = tile.oneRMExerciseIDs
                personalRecordExerciseIDs = tile.personalRecordExerciseIDs
                volumeWorkoutName = tile.volumeWorkoutName
                volumeExerciseID = tile.volumeExerciseID
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
                        updatedTile.oneRMExerciseIDs = oneRMExerciseIDs
                        updatedTile.personalRecordExerciseIDs = personalRecordExerciseIDs
                        updatedTile.volumeWorkoutName = volumeWorkoutName
                        updatedTile.volumeExerciseID = volumeExerciseID
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
            Section {
                Toggle("Show Header", isOn: Binding(
                    get: { dashboardHeaderState.isVisible },
                    set: { dashboardHeaderState.updateIsVisible($0) }
                ))
            } footer: {
                Text("When hidden, the settings gear remains visible in the top-right corner.")
                    .font(.caption)
            }

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
                                .foregroundColor(.primary)
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
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground))
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

// MARK: - Import Activities View

private struct ImportActivitiesView: View {
    @Environment(HealthKitState.self) var healthKitState

    var body: some View {
        List {
            Section {
                ForEach(HKWorkoutActivityTypeHelper.allCases) { entry in
                    Toggle(entry.label, isOn: Binding(
                        get: { healthKitState.isImporting(entry.rawValue) },
                        set: { _ in healthKitState.toggleImport(entry.rawValue) }
                    ))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Import Activities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsModuleView()
        .environment(ModuleState.shared)
}
