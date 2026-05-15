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

    @State private var showingAdd = false
    @State private var editingItem: Equipment?
    @State private var deletingItem: Equipment?
    @State private var statsItem: Equipment?

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

                List {
                    ForEach(state.sortedItems) { item in
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
                .sheet(isPresented: $showingAdd) {
                    EquipmentEditor(title: "Add Equipment") { name in
                        state.addItem(name: name)
                    }
                }
                .sheet(item: $editingItem) { item in
                    EquipmentEditor(title: "Edit Equipment", initialName: item.name) { name in
                        var updated = item
                        updated.name = name
                        state.updateItem(updated)
                    } onDelete: {
                        state.removeItem(id: item.id)
                    }
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

#Preview {
    EquipmentModuleView()
        .environment(EquipmentState.shared)
        .environment(ExercisesState.shared)
        .environment(WorkoutLogState.shared)
}
