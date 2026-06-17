////
////  ExercisesModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import CloudKit

/// Module for managing exercises
public struct ExercisesModule: AppModule {
    public let id: UUID = ModuleIDs.exercises
    public let displayName: String = "Exercises"
    public let iconName: String = "figure.strengthtraining.traditional"
    public let description: String = "Add and manage exercises with muscle groups and equipment"
    
    public var order: Int = 6
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(ExercisesModuleView())
    }
}

private struct ExercisesModuleView: View {
    @Environment(ExercisesState.self) var state
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    @Environment(WorkoutLogState.self) var logState

    @State private var searchText: String = ""
    @State private var showingAdd = false
    @State private var editingExercise: Exercise?
    @State private var deletingExercise: Exercise?
    @State private var statsExercise: Exercise?
    @State private var historyExercise: Exercise?
    @State private var startingWorkout: Workout?
    
    private var filteredExercises: [Exercise] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            return state.exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return state.exercises
            .filter { matchesSearch($0, searchKey: trimmedSearch) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with title and add button
                HStack {
                    Text("Exercises")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingAdd = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Favorites grid — 3-piece tiles (lives outside List so it never disrupts row identity)
                if !state.favoriteExercises.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(state.favoriteExercises) { exercise in
                            VStack(spacing: 0) {
                                // Top: launch button
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    launchExercise(exercise)
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.system(size: 18, weight: .semibold))
                                        Text(exercise.name)
                                            .font(.caption2).fontWeight(.semibold)
                                            .lineLimit(2).multilineTextAlignment(.center)
                                    }
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 57)
                                }
                                .buttonStyle(.plain)

                                Divider()

                                // Bottom: stats | history
                                HStack(spacing: 0) {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        statsExercise = exercise
                                    }) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 30)
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                        .frame(width: 1)
                                        .frame(height: 18)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(UIColor.separator))
                                                .frame(width: 1)
                                        )

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        historyExercise = exercise
                                    }) {
                                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 30)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List {
                    SearchField(text: $searchText, placeholder: "Search exercises...")

                    // Exercises List
                    if filteredExercises.isEmpty {
                        Text("No exercises found")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filteredExercises) { exercise in
                            VStack(alignment: .leading, spacing: 4) {
                                // Top row: play button, name, action buttons
                                HStack(spacing: 12) {
                                    // Play button — launches the exercise directly
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        launchExercise(exercise)
                                    }) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)

                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    // Favorite star
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        state.toggleFavorite(exercise)
                                    }) {
                                        Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                                            .foregroundColor(exercise.isFavorite ? .yellow : .gray)
                                    }
                                    .buttonStyle(.plain)

                                    // History icon — opens exercise history sheet
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        historyExercise = exercise
                                    }) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)

                                    // Graph icon — navigate to stats
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        statsExercise = exercise
                                    }) {
                                        Image(systemName: "chart.bar")
                                            .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)

                                    // Edit icon
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        editingExercise = exercise
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Show muscle groups
                                if !exercise.primaryMuscleGroupIDs.isEmpty || !exercise.secondaryMuscleGroupIDs.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("Muscles:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                        Text(formattedMuscleGroups(primaryIDs: exercise.primaryMuscleGroupIDs,
                                                                   secondaryIDs: exercise.secondaryMuscleGroupIDs))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if !exercise.equipmentIDs.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("Equipment:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                        Text(equipmentNames(exercise.equipmentIDs).joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                let trimmedNotes = exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedNotes.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("Notes:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                        Text(trimmedNotes)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                launchExercise(exercise)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    editingExercise = exercise
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.primary)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    deletingExercise = exercise
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .fullScreenCover(isPresented: $showingAdd) {
                    ExerciseEditor(title: "Add Exercise") { exercise in
                        state.addExercise(exercise)
                    }
                    .environment(muscleGroupsState)
                    .environment(equipmentState)
                }
                .fullScreenCover(item: $editingExercise) { exercise in
                    ExerciseEditor(title: "Edit Exercise", initialExercise: exercise) { updated in
                        state.updateExercise(updated)
                    } onDelete: {
                        state.removeExercise(id: exercise.id)
                    }
                    .environment(muscleGroupsState)
                    .environment(equipmentState)
                }
                .fullScreenCover(item: $historyExercise) { exercise in
                    ExerciseHistorySheet(exercise: exercise, logState: logState)
                }
                .fullScreenCover(item: $startingWorkout) { workout in
                    StartWorkoutView(workout: workout)
                        .environment(ExercisesState.shared)
                        .environment(MuscleGroupsState.shared)
                        .environment(EquipmentState.shared)
                        .environment(WorkoutLogState.shared)
                }
                .alert("Delete Exercise?", isPresented: .constant(deletingExercise != nil)) {
                    Button("Cancel", role: .cancel) { deletingExercise = nil }
                    Button("Delete", role: .destructive) {
                        if let e = deletingExercise {
                            state.removeExercise(id: e.id)
                            deletingExercise = nil
                        }
                    }
                } message: {
                    Text("This will permanently delete the exercise.")
                }
            }
            .fullScreenCover(item: $statsExercise) { exercise in
                ExerciseStatsView(exercise: exercise)
                    .environment(logState)
            }
            .onAppear {
                openPendingLaunchIfNeeded()
                openPendingStatsIfNeeded()
                openPendingHistoryIfNeeded()
            }
            .onChange(of: state.pendingLaunchID) { _, id in
                if id != nil { openPendingLaunchIfNeeded() }
            }
            .onChange(of: state.pendingStatsID) { _, id in
                if id != nil { openPendingStatsIfNeeded() }
            }
            .onChange(of: state.pendingHistoryID) { _, id in
                if id != nil { openPendingHistoryIfNeeded() }
            }
        }
    }

    private func launchExercise(_ exercise: Exercise) {
        startingWorkout = Workout(
            name: "\(exercise.name)",
            notes: "",
            items: [WorkoutItem.exercise(WorkoutExercise(exerciseID: exercise.id))],
            healthKitActivityType: exercise.healthKitActivityType
        )
    }

    private func openPendingLaunchIfNeeded() {
        guard let id = state.pendingLaunchID,
              let exercise = state.exercises.first(where: { $0.id == id }) else { return }
        state.pendingLaunchID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            launchExercise(exercise)
        }
    }

    private func openPendingStatsIfNeeded() {
        guard let id = state.pendingStatsID,
              let exercise = state.exercises.first(where: { $0.id == id }) else { return }
        state.pendingStatsID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            statsExercise = exercise
        }
    }

    private func openPendingHistoryIfNeeded() {
        guard let id = state.pendingHistoryID,
              let exercise = state.exercises.first(where: { $0.id == id }) else { return }
        state.pendingHistoryID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            historyExercise = exercise
        }
    }
    
    private func muscleGroupNames(_ ids: [UUID]) -> [String] {
        ids.compactMap { id in
            muscleGroupsState.sortedGroups.first { $0.id == id }?.name
        }
    }

    private func formattedMuscleGroups(primaryIDs: [UUID], secondaryIDs: [UUID]) -> String {
        let primaryNames = muscleGroupNames(primaryIDs)
        let secondaryNames = muscleGroupNames(secondaryIDs)
        if secondaryNames.isEmpty {
            return primaryNames.joined(separator: ", ")
        }
        let primaryText = primaryNames.joined(separator: ", ")
        let secondaryText = secondaryNames.joined(separator: ", ")
        return "\(primaryText) (\(secondaryText))"
    }

    private func equipmentNames(_ ids: [UUID]) -> [String] {
        ids.compactMap { id in
            equipmentState.sortedItems.first { $0.id == id }?.name
        }
    }
    
    private func matchesSearch(_ exercise: Exercise, searchKey: String) -> Bool {
        if exercise.name.localizedCaseInsensitiveContains(searchKey) {
            return true
        }
        if exercise.notes.localizedCaseInsensitiveContains(searchKey) {
            return true
        }
        let muscleIDs = exercise.primaryMuscleGroupIDs + exercise.secondaryMuscleGroupIDs
        let muscleNames = muscleGroupNames(muscleIDs)
        if muscleNames.contains(where: { $0.localizedCaseInsensitiveContains(searchKey) }) {
            return true
        }
        let equipmentNamesList = equipmentNames(exercise.equipmentIDs)
        if equipmentNamesList.contains(where: { $0.localizedCaseInsensitiveContains(searchKey) }) {
            return true
        }
        return false
    }
}

// MARK: - Exercise Editor

private struct ExerciseEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(EquipmentState.self) var equipmentState
    
    let title: String
    let initialExercise: Exercise?
    let onSave: (Exercise) -> Void
    let onDelete: (() -> Void)?
    
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var primaryMuscleGroupIDs: Set<UUID> = []
    @State private var secondaryMuscleGroupIDs: Set<UUID> = []
    @State private var selectedEquipmentIDs: Set<UUID> = []
    @State private var defaultEquipmentIDs: Set<UUID> = []
    @State private var hasInitialized: Bool = false
    @State private var showSecondaryMuscles: Bool = false
    @State private var showDeleteConfirm = false
    @State private var healthKitActivityType: UInt? = nil
    // Image upload state
    @State private var imageFilename: String? = nil
    @State private var pendingImageData: Data? = nil   // non-nil when user picked a new image
    @State private var removedImage: Bool = false      // true when user explicitly removed the image
    @State private var showImageSourceMenu = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false

    init(title: String, initialExercise: Exercise? = nil, onSave: @escaping (Exercise) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initialExercise = initialExercise
        self.onSave = onSave
        self.onDelete = onDelete

        if let exercise = initialExercise {
            _name = State(initialValue: exercise.name)
            _notes = State(initialValue: exercise.notes)
            _selectedEquipmentIDs = State(initialValue: Set(exercise.equipmentIDs))
            _defaultEquipmentIDs = State(initialValue: Set(exercise.defaultEquipmentIDs))
            _healthKitActivityType = State(initialValue: exercise.healthKitActivityType)
            _imageFilename = State(initialValue: exercise.imageFilename)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...6)
                }

                Section {
                    // Determine which image data to show: pending pick > existing file > nothing
                    let displayData: Data? = {
                        if let d = pendingImageData { return d }
                        if !removedImage, let fn = imageFilename,
                           let d = try? Data(contentsOf: Exercise.imageStorageDirectory.appendingPathComponent(fn)) {
                            return d
                        }
                        return nil
                    }()

                    if let data = displayData {
                        GIFImageView(data: data)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))

                        Button(role: .destructive) {
                            pendingImageData = nil
                            removedImage = true
                        } label: {
                            Label("Remove Image", systemImage: "trash")
                        }
                    } else {
                        Button {
                            showImageSourceMenu = true
                        } label: {
                            Label("Upload Image", systemImage: "photo.badge.plus")
                        }
                        .tint(.primary)
                        .confirmationDialog("Choose Image Source", isPresented: $showImageSourceMenu) {
                            Button("Photo Library") { showPhotoPicker = true }
                            Button("Files (for GIF)") { showFilePicker = true }
                            Button("Cancel", role: .cancel) { }
                        }
                    }
                } header: {
                    Text("Exercise Image")
                        .padding(.leading, -16)
                }
                
                Section("Primary Muscle Groups") {
                    Text("Main muscles worked by this exercise")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                    
                    if muscleGroupsState.sortedGroups.isEmpty {
                        Text("No muscle groups available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(muscleGroupsState.sortedGroups) { group in
                            Toggle(group.name, isOn: Binding(
                                get: { primaryMuscleGroupIDs.contains(group.id) },
                                set: { isSelected in
                                    if isSelected {
                                        primaryMuscleGroupIDs.insert(group.id)
                                    } else {
                                        primaryMuscleGroupIDs.remove(group.id)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                Section("Secondary Muscle Groups (Optional)") {
                    DisclosureGroup(isExpanded: $showSecondaryMuscles) {
                        if muscleGroupsState.sortedGroups.isEmpty {
                            Text("No muscle groups available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(muscleGroupsState.sortedGroups) { group in
                                Toggle(group.name, isOn: Binding(
                                    get: { secondaryMuscleGroupIDs.contains(group.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            secondaryMuscleGroupIDs.insert(group.id)
                                        } else {
                                            secondaryMuscleGroupIDs.remove(group.id)
                                        }
                                    }
                                ))
                            }
                        }
                    } label: {
                        Text("Additional muscles engaged during this exercise")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Equipment") {
                    if equipmentState.sortedItems.isEmpty {
                        Text("No equipment available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(equipmentState.sortedItems) { equipment in
                            let isSelected = selectedEquipmentIDs.contains(equipment.id)
                            Toggle(equipment.name, isOn: Binding(
                                get: { isSelected },
                                set: { on in
                                    if on {
                                        selectedEquipmentIDs.insert(equipment.id)
                                    } else {
                                        selectedEquipmentIDs.remove(equipment.id)
                                        // Remove from defaults if deselected
                                        defaultEquipmentIDs.remove(equipment.id)
                                    }
                                }
                            ))
                            if isSelected {
                                Toggle("Default", isOn: Binding(
                                    get: { defaultEquipmentIDs.contains(equipment.id) },
                                    set: { on in
                                        if on { defaultEquipmentIDs.insert(equipment.id) }
                                        else { defaultEquipmentIDs.remove(equipment.id) }
                                    }
                                ))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                            }
                        }
                    }
                }
                if HealthKitState.shared.exportStrengthWorkouts {
                    Section("Apple Health Activity") {
                        HKActivityTypePicker(rawValue: $healthKitActivityType)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                    if onDelete != nil {
                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 22))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let exerciseID = initialExercise?.id ?? UUID()

                        // Persist image to disk if a new one was picked
                        var finalImageFilename: String? = removedImage ? nil : imageFilename
                        if let data = pendingImageData {
                            let dir = Exercise.imageStorageDirectory
                            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                            let filename = "\(exerciseID).gif"
                            let url = dir.appendingPathComponent(filename)
                            if (try? data.write(to: url)) != nil {
                                finalImageFilename = filename
                                // Push image to CloudKit so other devices receive it
                                CloudKitSyncEngine.shared.pushImage(
                                    data: data,
                                    recordName: "exercise_image_\(exerciseID.uuidString)",
                                    fields: ["exerciseID": exerciseID.uuidString as CKRecordValue]
                                )
                            }
                        } else if removedImage, let fn = imageFilename {
                            // User removed the image: delete the file
                            let url = Exercise.imageStorageDirectory.appendingPathComponent(fn)
                            try? FileManager.default.removeItem(at: url)
                            finalImageFilename = nil
                        }

                        let exercise = Exercise(
                            id: exerciseID,
                            name: name,
                            notes: notes,
                            primaryMuscleGroupIDs: Array(primaryMuscleGroupIDs),
                            secondaryMuscleGroupIDs: Array(secondaryMuscleGroupIDs),
                            equipmentIDs: Array(selectedEquipmentIDs),
                            defaultEquipmentIDs: Array(defaultEquipmentIDs),
                            isFavorite: initialExercise?.isFavorite ?? false,
                            healthKitActivityType: healthKitActivityType,
                            imageFilename: finalImageFilename
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Exercise?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete the exercise.")
            }
            .onAppear {
                if !hasInitialized {
                    if let exercise = initialExercise {
                        primaryMuscleGroupIDs = Set(exercise.primaryMuscleGroupIDs)
                        secondaryMuscleGroupIDs = Set(exercise.secondaryMuscleGroupIDs)
                        selectedEquipmentIDs = Set(exercise.equipmentIDs)
                        defaultEquipmentIDs = Set(exercise.defaultEquipmentIDs)
                        imageFilename = exercise.imageFilename
                    }
                    hasInitialized = true
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                ExerciseImagePickerController { data in
                    pendingImageData = data
                    removedImage = false
                }
            }
            .sheet(isPresented: $showFilePicker) {
                ExerciseFilePickerController { data in
                    pendingImageData = data
                    removedImage = false
                }
            }
        }
    }
}

// MARK: - UIImagePickerController wrapper (preserves GIF data from photo library)

private struct ExerciseImagePickerController: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            // Prefer the original image URL (preserves GIF)
            if let url = info[.imageURL] as? URL, let data = try? Data(contentsOf: url) {
                onPick(data)
            } else if let image = info[.originalImage] as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.85) {
                onPick(data)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - UIDocumentPickerViewController wrapper (for picking GIFs from Files)

private struct ExerciseFilePickerController: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.gif, .image]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
            onPick(data)
        }
    }
}

// MARK: - GIFImageView: animated GIF / static image display

struct GIFImageView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> GIFContainerView {
        let v = GIFContainerView()
        v.setContent(from: data)
        return v
    }

    func updateUIView(_ uiView: GIFContainerView, context: Context) {
        uiView.setContent(from: data)
    }
}

/// A UIView subclass that wraps a UIImageView and reports the image's natural aspect ratio
/// as its intrinsicContentSize, so SwiftUI layout (.aspectRatio / .fit) works correctly.
class GIFContainerView: UIView {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        // Don't resist compression — let SwiftUI control sizing
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setContent(from data: Data) {
        imageView.setGIFContent(from: data)
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        // Return a normalized size that preserves the image's aspect ratio.
        // Using a fixed width of 100 keeps the value small so SwiftUI doesn't try
        // to size the view at raw pixel dimensions (e.g. 640×480 points).
        let size = imageView.image?.size
                ?? imageView.animationImages?.first?.size
        guard let s = size, s.width > 0, s.height > 0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        let normalizedWidth: CGFloat = 100
        return CGSize(width: normalizedWidth, height: normalizedWidth * s.height / s.width)
    }
}

private extension UIImageView {
    /// Decode `data` as an animated GIF (using ImageIO) or fall back to a static UIImage.
    func setGIFContent(from data: Data) {
        // Stop any existing animation first
        stopAnimating()
        animationImages = nil
        image = nil

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            image = UIImage(data: data)
            return
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            image = UIImage(data: data)
            return
        }
        var frames: [UIImage] = []
        var totalDuration: Double = 0
        for i in 0..<count {
            guard let cgImg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any]
            let gifProps = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let delay = (gifProps?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                     ?? (gifProps?[kCGImagePropertyGIFDelayTime as String] as? Double)
                     ?? 0.1
            frames.append(UIImage(cgImage: cgImg))
            totalDuration += delay
        }
        animationImages = frames
        animationDuration = totalDuration
        startAnimating()
    }
}

#Preview {
    ExercisesModuleView()
        .environment(ExercisesState.shared)
        .environment(MuscleGroupsState.shared)
        .environment(EquipmentState.shared)
        .environment(WorkoutLogState.shared)
}
