////
////  MuscleGroupsModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit
import PhotosUI

/// Module for managing muscle groups.
public struct MuscleGroupsModule: AppModule {
    public let id: UUID = ModuleIDs.muscles
    public let displayName: String = "Muscles"
    public let iconName: String = "figure.strengthtraining.traditional"
    public let description: String = "Add and manage muscles"

    public var order: Int = 7
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(MuscleGroupsModuleView())
    }
}

// MARK: - List view

private struct MuscleGroupsModuleView: View {
    @Environment(MuscleGroupsState.self) var state
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState

    @State private var searchText: String = ""
    @State private var showingAdd = false
    @State private var editingGroup: MuscleGroup?
    @State private var deletingGroup: MuscleGroup?
    @State private var statsGroup: MuscleGroup?
    @State private var historyGroup: MuscleGroup?

    private var filteredGroups: [MuscleGroup] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return state.sortedGroups }
        return state.sortedGroups.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Muscles")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingAdd = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Favorites grid — lives outside the List so it never disrupts List row identity
                if !state.favoriteGroups.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                        ForEach(state.favoriteGroups) { group in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsGroup = group
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black)
                                    Text(group.name)
                                        .font(.caption).fontWeight(.semibold).foregroundColor(.black)
                                        .lineLimit(2).multilineTextAlignment(.center)
                                }
                                .frame(width: 70, height: 80)
                                .background(Color(red: 0.92, green: 0.92, blue: 0.94))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List {
                    SearchField(text: $searchText, placeholder: "Search muscles...")

                    ForEach(filteredGroups) { group in
                        HStack(spacing: 12) {
                            MuscleGroupThumbnail(group: group, size: 40)

                            Text(group.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    statsGroup = group
                                }

                            // Favorite star
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                state.toggleFavorite(group)
                            }) {
                                Image(systemName: group.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(group.isFavorite ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)

                            // History button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                historyGroup = group
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("History for \(group.name)")

                            // Graph icon — navigate to stats
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsGroup = group
                            }) {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Stats for \(group.name)")

                            // Edit icon
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingGroup = group
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(group.name)")
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingGroup = group
                            } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.blue)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                deletingGroup = group
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
                .sheet(isPresented: $showingAdd) {
                    MuscleGroupEditor(title: "Add Muscle Group") { updated in
                        state.groups.append(updated)
                        state.updateGroup(updated)
                    }
                    .environment(state)
                }
                .sheet(item: $editingGroup) { group in
                    MuscleGroupEditor(title: "Edit Muscle Group", group: group) { updated in
                        state.updateGroup(updated)
                    } onDelete: {
                        state.removeGroup(id: group.id)
                    }
                    .environment(state)
                }
                .sheet(item: $historyGroup) { group in
                    MuscleGroupHistorySheet(group: group, logState: logState, exercisesState: exercisesState)
                }
                .alert("Delete Muscle Group?", isPresented: .constant(deletingGroup != nil)) {
                    Button("Cancel", role: .cancel) { deletingGroup = nil }
                    Button("Delete", role: .destructive) {
                        if let g = deletingGroup {
                            state.removeGroup(id: g.id)
                            deletingGroup = nil
                        }
                    }
                } message: {
                    Text("This will permanently delete the muscle group.")
                }
            }
            .navigationDestination(item: $statsGroup) { group in
                MuscleStatsView(muscleGroup: group)
                    .environment(logState)
                    .environment(exercisesState)
            }
        }
    }
}

// MARK: - Thumbnail (reusable in list + workout info panel)
// Shows primary image. If a secondary also exists, both are shown side-by-side within the given size.

public struct MuscleGroupThumbnail: View {
    public let group: MuscleGroup
    public let size: CGFloat

    public init(group: MuscleGroup, size: CGFloat = 40) {
        self.group = group
        self.size = size
    }

    private var hasPrimary: Bool {
        group.customPrimaryImageData != nil || (group.primaryImageAssetName ?? "").isEmpty == false
    }

    private var hasSecondary: Bool {
        group.customSecondaryImageData != nil || (group.secondaryImageAssetName ?? "").isEmpty == false
    }

    public var body: some View {
        if hasPrimary && hasSecondary {
            // Side-by-side: each image gets half the width
            HStack(spacing: 2) {
                singleImage(data: group.customPrimaryImageData, assetName: group.primaryImageAssetName)
                    .frame(width: (size - 2) / 2, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.1))
                singleImage(data: group.customSecondaryImageData, assetName: group.secondaryImageAssetName)
                    .frame(width: (size - 2) / 2, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.1))
            }
            .frame(width: size, height: size)
        } else if hasPrimary {
            singleImage(data: group.customPrimaryImageData, assetName: group.primaryImageAssetName)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: size, height: size)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
        }
    }

    @ViewBuilder
    private func singleImage(data: Data?, assetName: String?) -> some View {
        if let data, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable().scaledToFit()
        } else if let name = assetName, !name.isEmpty {
            Image(name)
                .resizable().scaledToFit()
        } else {
            Color.clear
        }
    }
}

// MARK: - Editor

private enum ImageSlot { case primary, secondary }

private struct MuscleGroupEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(MuscleGroupsState.self) var state

    let title: String
    let onSave: (MuscleGroup) -> Void
    let onDelete: (() -> Void)?

    @State private var group: MuscleGroup

    // Photo picker
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var activeSlot: ImageSlot = .primary
    @State private var showingPhotoPicker = false
    @State private var showDeleteConfirm = false

    init(title: String, group: MuscleGroup? = nil, onSave: @escaping (MuscleGroup) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.onSave = onSave
        self.onDelete = onDelete
        _group = State(initialValue: group ?? MuscleGroup(name: ""))
    }

    private var isCustomMode: Bool {
        state.selectedBodyOption == .custom
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $group.name)
                }

                Section("Image") {
                    // Preview row — always visible
                    HStack(spacing: 16) {
                        Spacer()
                        imagePreview(data: group.customPrimaryImageData, assetName: group.primaryImageAssetName, label: "Primary")
                        if group.secondaryImageAssetName != nil || group.customSecondaryImageData != nil {
                            imagePreview(data: group.customSecondaryImageData, assetName: group.secondaryImageAssetName, label: "Secondary")
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if isCustomMode {
                        // Custom mode: show choose / clear buttons for each slot
                        imageRow(
                            label: "Primary",
                            assetName: group.primaryImageAssetName,
                            customData: group.customPrimaryImageData,
                            slot: .primary
                        )
                        imageRow(
                            label: "Secondary",
                            assetName: group.secondaryImageAssetName,
                            customData: group.customSecondaryImageData,
                            slot: .secondary
                        )
                    } else {
                        Text("Images are controlled by the Image Set option in Settings → Muscles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
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
                        onSave(group)
                        dismiss()
                    }
                    .disabled(group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Muscle Group?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete the muscle group.")
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $photoPickerItem,
                matching: .images
            )
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            switch activeSlot {
                            case .primary:
                                group.customPrimaryImageData = data
                                group.primaryImageAssetName = nil
                            case .secondary:
                                group.customSecondaryImageData = data
                                group.secondaryImageAssetName = nil
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Large preview helper (shown at top of Image section)

    @ViewBuilder
    private func imagePreview(data: Data?, assetName: String?, label: String) -> some View {
        VStack(spacing: 4) {
            Group {
                if let data, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFit()
                } else if let name = assetName, !name.isEmpty {
                    Image(name).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .frame(width: 144, height: 144)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(12)
                }
            }
            .frame(width: 144, height: 144)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Image row helper (Custom mode only)

    @ViewBuilder
    private func imageRow(label: String, assetName: String?, customData: Data?, slot: ImageSlot) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)

            Spacer()

            Button(action: {
                activeSlot = slot
                showingPhotoPicker = true
            }) {
                Text("Choose")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)

            if (slot == .primary && customData != nil) || (slot == .secondary && customData != nil) {
                Button(action: {
                    switch slot {
                    case .primary:
                        group.customPrimaryImageData = nil
                    case .secondary:
                        group.customSecondaryImageData = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Muscle Group History Sheet

private struct MuscleGroupHistorySheet: View {
    @Environment(\.dismiss) var dismiss

    let group: MuscleGroup
    let logState: WorkoutLogState
    let exercisesState: ExercisesState

    // Exercise IDs that target this muscle (primary or secondary)
    private var targetExerciseIDs: Set<UUID> {
        Set(exercisesState.exercises
            .filter {
                $0.primaryMuscleGroupIDs.contains(group.id) ||
                $0.secondaryMuscleGroupIDs.contains(group.id)
            }
            .map { $0.id })
    }

    // Sessions containing at least one relevant exercise, newest first
    private struct SessionEntry: Identifiable {
        let id: UUID
        let date: Date
        let workoutName: String
        let exercises: [(name: String, sets: [LoggedSet])]
    }

    private var sessions: [SessionEntry] {
        let ids = targetExerciseIDs
        return logState.sortedLogs.compactMap { log in
            let relevant = log.exercises.filter { ids.contains($0.exerciseID) && !$0.sets.isEmpty }
            guard !relevant.isEmpty else { return nil }
            return SessionEntry(
                id: log.id,
                date: log.completedAt,
                workoutName: log.workoutName,
                exercises: relevant.map { (name: $0.exerciseName, sets: $0.sets) }
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.secondary)
                        Text("No History")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Complete workouts with exercises targeting this muscle to see history here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(session.date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(session.date, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(session.workoutName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                ForEach(Array(session.exercises.enumerated()), id: \.offset) { _, entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        HStack {
                                            Text("Set").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                            Text("Reps").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
                                            Text("Weight").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        ForEach(Array(entry.sets.enumerated()), id: \.offset) { idx, set in
                                            HStack {
                                                Text("\(idx + 1)").font(.caption).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                                                Text("\(set.reps)").font(.caption).frame(maxWidth: .infinity, alignment: .center)
                                                Text(set.weight == 0 ? "—" : String(format: "%.1f lbs", set.weight)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(uiColor: .systemGray6))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History: \(group.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MuscleGroupsModuleView()
        .environment(MuscleGroupsState.shared)
        .environment(WorkoutLogState.shared)
        .environment(ExercisesState.shared)
}
