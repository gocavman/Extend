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
            }
            .sheet(item: $editingGroup) { group in
                MuscleGroupEditor(title: "Edit Muscle Group", group: group) { updated in
                    state.updateGroup(updated)
                }
            }
        }
    }
}

// MARK: - Thumbnail (reusable in list + workout info panel)

public struct MuscleGroupThumbnail: View {
    public let group: MuscleGroup
    public let size: CGFloat

    public init(group: MuscleGroup, size: CGFloat = 40) {
        self.group = group
        self.size = size
    }

    public var body: some View {
        Group {
            if let data = group.customPrimaryImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
            } else if let name = group.primaryImageAssetName, !name.isEmpty {
                Image(name)
                    .resizable().scaledToFill()
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(size * 0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
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

    // Image option selection
    enum ImageOption: String, CaseIterable {
        case male = "Option 1 (Male)"
        case female = "Option 2 (Female)"
        case custom = "Custom"
    }
    @State private var selectedOption: ImageOption = .male

    init(title: String, group: MuscleGroup? = nil, onSave: @escaping (MuscleGroup) -> Void) {
        self.title = title
        self.onSave = onSave
        _group = State(initialValue: group ?? MuscleGroup(name: ""))
    }

    // The JSON pair for this muscle name
    private var imagePairs: (male: (primary: String?, secondary: String?), female: (primary: String?, secondary: String?))? {
        MuscleGroupsState.shared.imagePairs(for: group.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $group.name)
                }

                Section("Image") {
                    Picker("Source", selection: $selectedOption) {
                        ForEach(ImageOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedOption) { _, newOption in
                        applyOption(newOption)
                    }

                    // Primary image
                    imageRow(
                        label: "Primary",
                        assetName: group.primaryImageAssetName,
                        customData: group.customPrimaryImageData,
                        slot: .primary
                    )

                    // Secondary image
                    imageRow(
                        label: "Secondary",
                        assetName: group.secondaryImageAssetName,
                        customData: group.customSecondaryImageData,
                        slot: .secondary
                    )
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
            .onAppear {
                // Pre-select the option that matches stored data
                if group.customPrimaryImageData != nil || group.customSecondaryImageData != nil {
                    selectedOption = .custom
                } else if let primary = group.primaryImageAssetName {
                    selectedOption = primary.hasPrefix("Female") ? .female : .male
                }
            }
        }
    }

    // MARK: - Image row helper

    @ViewBuilder
    private func imageRow(label: String, assetName: String?, customData: Data?, slot: ImageSlot) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)

            Spacer()

            // Thumbnail preview
            Group {
                if let data = customData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                } else if let name = assetName, !name.isEmpty {
                    Image(name)
                        .resizable().scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(6)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if selectedOption == .custom {
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

    // MARK: - Apply option

    private func applyOption(_ option: ImageOption) {
        switch option {
        case .male:
            let pair = imagePairs?.male
            group.primaryImageAssetName = pair?.primary
            group.secondaryImageAssetName = pair?.secondary
            group.customPrimaryImageData = nil
            group.customSecondaryImageData = nil
        case .female:
            let pair = imagePairs?.female
            group.primaryImageAssetName = pair?.primary
            group.secondaryImageAssetName = pair?.secondary
            group.customPrimaryImageData = nil
            group.customSecondaryImageData = nil
        case .custom:
            // Keep whatever is already stored; user will tap Choose
            break
        }
    }
}

#Preview {
    MuscleGroupsModuleView()
        .environment(MuscleGroupsState.shared)
}
