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
    @State private var showingAdd = false
    @State private var editingItem: Equipment?
    
    var body: some View {
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
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingItem = item
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)

                            Text(item.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: { editingItem = item }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(item.name)")
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") {
                            editingItem = item
                        }
                        Button(role: .destructive) {
                            state.removeItem(id: item.id)
                        } label: {
                            Text("Delete")
                        }
                    }
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
                            state.removeItem(id: item.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
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
                }
            }
        }
    }
}

private struct EquipmentEditor: View {
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
    EquipmentModuleView()
        .environment(EquipmentState.shared)
}
