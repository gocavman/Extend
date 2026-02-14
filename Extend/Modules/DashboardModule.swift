////
////  DashboardModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation
import UIKit

/// Dashboard module - the main landing page with customizable tiles
public struct DashboardModule: AppModule {
    public let id: UUID = ModuleIDs.dashboard
    public let displayName: String = "Dashboard"
    public let iconName: String = "square.grid.2x2"
    public let description: String = "Customizable dashboard with shortcuts and quick stats"
    
    public var order: Int = 0  // Always first
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(DashboardModuleView(module: self))
    }
}

// MARK: - Dashboard View

private struct DashboardModuleView: View {
    let module: DashboardModule
    
    @Environment(DashboardState.self) var dashboardState
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    
    @State private var isModifying: Bool = false
    @State private var showingAddTile: Bool = false
    @State private var editingTile: DashboardTile?
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Your fitness at a glance")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 1.0))
            
            // MARK: - Tiles Content
            if dashboardState.tiles.isEmpty && !isModifying {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.dashed")
                        .font(.system(size: 44))
                        .foregroundColor(.gray)
                    
                    Text("No tiles yet")
                        .font(.headline)
                    
                    Text("Tap Modify to add your first tile")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isModifying {
                // In edit mode: show list with drag handles
                List {
                    ForEach(dashboardState.tiles.sorted { $0.order < $1.order }, id: \.id) { tile in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                                .opacity(0.6)
                            
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
                            
                            Button(action: { editingTile = tile }) {
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
                    
                    // Add Tile Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingAddTile = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.black)
                            Text("Add Tile")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            Spacer()
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
            } else {
                // Normal mode: show grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(dashboardState.tiles.sorted { $0.order < $1.order }, id: \.id) { tile in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if let targetID = findModuleID(for: tile) {
                                    state.selectModule(targetID)
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: tile.icon)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text(tile.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(16)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                .cornerRadius(12)
                                .aspectRatio(1, contentMode: .fit)
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            
            Spacer()
            
            // MARK: - Modify Button
            HStack {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isModifying.toggle()
                }) {
                    Text(isModifying ? "Done" : "Modify")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding(16)
        }
        .sheet(item: $editingTile) { tile in
            EditTileSheet(tile: tile) { updatedTile in
                dashboardState.updateTile(updatedTile)
            }
        }
        .sheet(isPresented: $showingAddTile) {
            AddTileSheet { newTile in
                dashboardState.addTile(newTile)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findModuleID(for tile: DashboardTile) -> UUID? {
        // Prefer an explicit target when available
        if let targetID = tile.targetModuleID {
            return targetID
        }

        // Try to find a module matching the tile's title
        let modules = registry.registeredModules
        if let module = modules.first(where: { $0.displayName.lowercased() == tile.title.lowercased() }) {
            return module.id
        }

        return nil
    }
}

// MARK: - Add Tile Sheet

private struct AddTileSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ModuleRegistry.self) var registry
    @Environment(DashboardState.self) var dashboardState

    @State private var title: String = ""
    @State private var selectedIcon: String = "square"
    @State private var selectedType: TileType = .moduleShortcut
    @State private var selectedModuleID: UUID? = nil
    @State private var hasInitialized: Bool = false

    let onAdd: (DashboardTile) -> Void

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

    private var moduleQuickOptions: [AnyAppModule] {
        let existingTileModuleIDs = Set(dashboardState.tiles.compactMap { $0.targetModuleID })
        return registry.registeredModules
            .filter { !existingTileModuleIDs.contains($0.id) && $0.displayName != "Dashboard" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Option") {
                    let pickerID = moduleQuickOptions.count
                    Picker("Module", selection: $selectedModuleID) {
                        Text("Custom").tag(nil as UUID?)
                        ForEach(moduleQuickOptions, id: \.id) { module in
                            Text(module.displayName).tag(module.id as UUID?)
                        }
                    }
                    .id(pickerID)
                    .onChange(of: moduleQuickOptions.count) { _, _ in
                        // If the selected module is no longer available, reset to nil
                        if let selectedID = selectedModuleID,
                           !moduleQuickOptions.contains(where: { $0.id == selectedID }) {
                            selectedModuleID = nil
                        }
                    }
                }
                .onAppear {
                    if !hasInitialized {
                        // Ensure selectedModuleID is valid or nil
                        if let selectedID = selectedModuleID,
                           !moduleQuickOptions.contains(where: { $0.id == selectedID }) {
                            selectedModuleID = nil
                        }
                        hasInitialized = true
                    }
                }

                if let moduleID = selectedModuleID,
                   let module = moduleQuickOptions.first(where: { $0.id == moduleID }) {
                    Section("Tile Details") {
                        HStack {
                            Text("Title")
                            Spacer()
                            Text(module.displayName)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: module.iconName)
                                .foregroundColor(.black)
                        }
                    }
                } else {
                    Section("Tile Details") {
                        TextField("Title", text: $title)
                    }

                    Section("Icon") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                VStack {
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
                }
            }
            .navigationTitle("Add Tile")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if let moduleID = selectedModuleID,
                           let module = moduleQuickOptions.first(where: { $0.id == moduleID }) {
                            let tile = DashboardTile(
                                title: module.displayName,
                                icon: module.iconName,
                                order: 0,
                                targetModuleID: module.id,
                                tileType: .moduleShortcut
                            )
                            onAdd(tile)
                        } else {
                            let tile = DashboardTile(title: title, icon: selectedIcon, order: 0, tileType: selectedType)
                            onAdd(tile)
                        }
                        dismiss()
                    }
                    .disabled(selectedModuleID == nil && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - Edit Tile Sheet

private struct EditTileSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let tile: DashboardTile
    
    @State private var title: String = ""
    @State private var selectedIcon: String = ""
    
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tile Details") {
                    TextField("Title", text: $title)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            VStack {
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
            }
            .navigationTitle("Edit Tile")
            .onAppear {
                title = tile.title
                selectedIcon = tile.icon
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updatedTile = tile
                        updatedTile.title = title
                        updatedTile.icon = selectedIcon
                        onSave(updatedTile)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

#Preview {
    DashboardModuleView(module: DashboardModule())
}
