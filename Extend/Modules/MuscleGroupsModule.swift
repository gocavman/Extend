////
////  MuscleGroupsModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit

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

private struct MuscleGroupsModuleView: View {
    @Environment(MuscleGroupsState.self) var state
    @State private var showingAdd = false
    @State private var editingGroup: MuscleGroup?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and add button
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

            List {
                ForEach(state.sortedGroups) { group in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingGroup = group
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)

                            Text(group.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: { editingGroup = group }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(group.name)")
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") {
                            editingGroup = group
                        }
                        Button(role: .destructive) {
                            state.removeGroup(id: group.id)
                        } label: {
                            Text("Delete")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            editingGroup = group
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            state.removeGroup(id: group.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MuscleGroupEditor(title: "Add Muscle Group") { name in
                    state.addGroup(name: name)
                }
            }
            .sheet(item: $editingGroup) { group in
                MuscleGroupEditor(title: "Edit Muscle Group", initialName: group.name) { name in
                    var updated = group
                    updated.name = name
                    state.updateGroup(updated)
                }
            }
        }
    }
}

private struct MuscleGroupEditor: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let initialName: String
    let onSave: (String) -> Void
    
    @State private var name: String
    
    init(title: String, initialName: String = "", onSave: @escaping (String) -> Void) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Text("Image support coming soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
        }
    }
}

#Preview {
    MuscleGroupsModuleView()
        .environment(MuscleGroupsState.shared)
}
