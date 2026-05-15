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
    @State private var showingAdd = false
    @State private var editingGroup: MuscleGroup?

    var body: some View {
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

            List {
                ForEach(state.sortedGroups) { group in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingGroup = group
                    }) {
                        HStack(spacing: 12) {
                            MuscleGroupThumbnail(group: group, size: 40)

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
                        Button("Edit") { editingGroup = group }
                        Button(role: .destructive) {
                            state.removeGroup(id: group.id)
                        } label: { Text("Delete") }
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
                            state.removeGroup(id: group.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
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
                }
                .environment(state)
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

    @State private var group: MuscleGroup

    // Photo picker
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var activeSlot: ImageSlot = .primary
    @State private var showingPhotoPicker = false

    init(title: String, group: MuscleGroup? = nil, onSave: @escaping (MuscleGroup) -> Void) {
        self.title = title
        self.onSave = onSave
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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

#Preview {
    MuscleGroupsModuleView()
        .environment(MuscleGroupsState.shared)
}
