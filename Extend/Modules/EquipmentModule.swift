////
////  EquipmentModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit

/// Module for managing equipment.
public struct EquipmentModule: AppModule {
    public let id: UUID = ModuleIDs.equipment
    public let displayName: String = "Equipment"
    public let iconName: String = "figure.walk.treadmill"
    public let description: String = "Add and manage equipment"

    public var order: Int = 8
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(EquipmentModuleView())
    }
}

private struct EquipmentModuleView: View {
    @Environment(EquipmentState.self) var state
    @Environment(ExercisesState.self) var exercisesState
    @Environment(WorkoutLogState.self) var logState

    @State private var searchText: String = ""
    @State private var showingAdd = false
    @State private var editingItem: Equipment?
    @State private var deletingItem: Equipment?
    @State private var statsItem: Equipment?
    @State private var historyItem: Equipment?

    private var filteredItems: [Equipment] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return state.sortedItems }
        return state.sortedItems.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with title and add button
                HStack {
                    Text("Equipment")
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
                if !state.favoriteItems.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                        ForEach(state.favoriteItems) { item in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsItem = item
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "figure.walk.treadmill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black)
                                    Text(item.name)
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
                    SearchField(text: $searchText, placeholder: "Search equipment...")

                    ForEach(filteredItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "figure.walk.treadmill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)

                            Text(item.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    statsItem = item
                                }

                            // Favorite star
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                state.toggleFavorite(item)
                            }) {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(item.isFavorite ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)

                            // History button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                historyItem = item
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)

                            // Usage/stats button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsItem = item
                            }) {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)

                            // Edit button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingItem = item
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingItem = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                deletingItem = item
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .fullScreenCover(isPresented: $showingAdd) {
                    EquipmentEditor(title: "Add Equipment") { name in
                        state.addItem(name: name)
                    }
                }
                .fullScreenCover(item: $editingItem) { item in
                    EquipmentEditor(title: "Edit Equipment", initialName: item.name) { name in
                        var updated = item
                        updated.name = name
                        state.updateItem(updated)
                    } onDelete: {
                        state.removeItem(id: item.id)
                    }
                }
                .fullScreenCover(item: $historyItem) { item in
                    EquipmentHistorySheet(equipment: item, logState: logState, exercisesState: exercisesState)
                }
                .alert("Delete Equipment?", isPresented: .constant(deletingItem != nil)) {
                    Button("Cancel", role: .cancel) { deletingItem = nil }
                    Button("Delete", role: .destructive) {
                        if let e = deletingItem {
                            state.removeItem(id: e.id)
                            deletingItem = nil
                        }
                    }
                } message: {
                    Text("This will permanently delete the equipment.")
                }
            }
            .navigationDestination(item: $statsItem) { item in
                EquipmentStatsView(equipment: item)
                    .environment(logState)
                    .environment(exercisesState)
            }
        }
    }
}

private struct EquipmentEditor: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let initialName: String
    let onSave: (String) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String
    @State private var showDeleteConfirm = false

    init(title: String, initialName: String = "", onSave: @escaping (String) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
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
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Equipment?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete the equipment.")
            }
        }
    }
}

// MARK: - Equipment History Sheet

private struct EquipmentHistorySheet: View {
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(\.dismiss) var dismiss

    let equipment: Equipment
    let logState: WorkoutLogState
    let exercisesState: ExercisesState

    private struct SessionEntry: Identifiable {
        let id: UUID
        let date: Date
        let workoutName: String
        let exercises: [(name: String, sets: [LoggedSet])]
    }

    private var sessions: [SessionEntry] {
        logState.sortedLogs.compactMap { log in
            // Only include exercises where the user confirmed they used this equipment
            let relevant = log.exercises.filter { $0.usedEquipmentIDs.contains(equipment.id) }
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
                        Text("Complete workouts and toggle this equipment as used to see history here.")
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
                                                Text(set.weight == 0 ? "—" : String(format: "%.1f \(weightUnit)", set.weight)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
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
            .navigationTitle("History: \(equipment.name)")
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
    EquipmentModuleView()
        .environment(EquipmentState.shared)
        .environment(ExercisesState.shared)
        .environment(WorkoutLogState.shared)
}
