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
    public let iconName: String = "dumbbell.fill"
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
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Favorites grid — 3-piece tiles: top=name, bottom-left=stats, bottom-right=history
                if !state.favoriteItems.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(state.favoriteItems) { item in
                            VStack(spacing: 0) {
                                // Top: name button (opens stats)
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    statsItem = item
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: item.sfSymbol ?? EquipmentState.defaultSFSymbol(for: item.name))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(item.name)
                                            .font(.caption2).fontWeight(.semibold).foregroundColor(.primary)
                                            .lineLimit(2).multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 57)
                                }
                                .buttonStyle(.plain)

                                Divider()

                                // Bottom: stats | history
                                HStack(spacing: 0) {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        statsItem = item
                                    }) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 30)
                                    }
                                    .buttonStyle(.plain)

                                    Divider().frame(height: 18)

                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        historyItem = item
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
                    SearchField(text: $searchText, placeholder: "Search equipment...")

                    ForEach(filteredItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.sfSymbol ?? EquipmentState.defaultSFSymbol(for: item.name))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.08))
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
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            // Usage/stats button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsItem = item
                            }) {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            // Edit button
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingItem = item
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.primary)
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
                            .tint(.primary)
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
                    EquipmentEditor(title: "Add Equipment") { name, symbol in
                        state.addItem(name: name, sfSymbol: symbol)
                    }
                }
                .fullScreenCover(item: $editingItem) { item in
                    EquipmentEditor(title: "Edit Equipment", initialName: item.name, initialSymbol: item.sfSymbol ?? EquipmentState.defaultSFSymbol(for: item.name)) { name, symbol in
                        var updated = item
                        updated.name = name
                        updated.sfSymbol = symbol
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
            .fullScreenCover(item: $statsItem) { item in
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
    let initialSymbol: String
    let onSave: (String, String) -> Void
    let onDelete: (() -> Void)?

    @State private var name: String
    @State private var selectedSymbol: String
    @State private var showDeleteConfirm = false
    @State private var showSymbolPicker = false

    init(title: String, initialName: String = "", initialSymbol: String = "dumbbell.fill", onSave: @escaping (String, String) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initialName = initialName
        self.initialSymbol = initialSymbol
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialName)
        _selectedSymbol = State(initialValue: initialSymbol)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                }

                Section("Icon") {
                    Button(action: { showSymbolPicker = true }) {
                        HStack {
                            Image(systemName: selectedSymbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.primary.opacity(0.08))
                                .cornerRadius(8)
                            Text("Change Icon")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
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
                        onSave(name, selectedSymbol)
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
            .sheet(isPresented: $showSymbolPicker) {
                EquipmentSymbolPicker(selectedSymbol: $selectedSymbol)
            }
        }
    }
}

// MARK: - SF Symbol Picker

private struct EquipmentSymbolPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSymbol: String
    @State private var searchText = ""

    // Curated fitness / activity symbols
    private let allSymbols: [(category: String, symbols: [String])] = [
        ("Weights & Strength", [
            "dumbbell.fill", "dumbbell",
            "figure.strengthtraining.functional",
            "figure.strengthtraining.traditional",
            "figure.strengthtraining.functional",
            "figure.highintensity.intervaltraining",
            "figure.cross.training",
        ]),
        ("Cardio", [
            "figure.walk.treadmill",
            "figure.run",
            "figure.walk",
            "figure.rower",
            "figure.elliptical",
            "figure.stair.stepper",
            "figure.indoor.cycle",
            "bicycle",
            "figure.outdoor.cycle",
            "figure.jumprope",
        ]),
        ("Sports & Combat", [
            "figure.boxing",
            "figure.martial.arts",
            "figure.gymnastics",
            "figure.basketball",
            "figure.soccer",
            "figure.tennis",
            "figure.volleyball",
            "figure.skiing.downhill",
            "figure.pool.swim",
        ]),
        ("Bodyweight & Flexibility", [
            "figure.strengthtraining.traditional",
            "figure.core.training",
            "figure.cooldown",
            "figure.flexibility",
            "figure.pilates",
            "figure.yoga",
            "figure.roll",
            "figure.climbing",
            "figure.hand.cycling",
        ]),
        ("Equipment Icons", [
            "rectangle.portrait.fill",
            "circle.fill",
            "square.fill",
            "circle.dotted",
            "xmark.circle",
            "hare.fill",
            "bolt.fill",
            "flame.fill",
            "heart.fill",
            "waveform.path.ecg",
            "timer",
            "stopwatch.fill",
            "target",
            "trophy.fill",
        ]),
    ]

    private var filteredCategories: [(category: String, symbols: [String])] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allSymbols }
        return allSymbols.compactMap { cat in
            let filtered = cat.symbols.filter { $0.lowercased().contains(q) }
            return filtered.isEmpty ? nil : (category: cat.category, symbols: filtered)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search icons...", text: $searchText)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)

                    ForEach(filteredCategories, id: \.category) { cat in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(cat.category)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(cat.symbols, id: \.self) { symbol in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selectedSymbol = symbol
                                        dismiss()
                                    }) {
                                        Image(systemName: symbol)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(selectedSymbol == symbol ? .white : .primary)
                                            .frame(width: 52, height: 52)
                                            .background(selectedSymbol == symbol ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
    @State private var timeRange: StatsTimeRange = .oneMonth

    private struct SessionEntry: Identifiable {
        let id: UUID
        let date: Date
        let workoutName: String
        let exercises: [(name: String, sets: [LoggedSet])]
    }

    private var sessions: [SessionEntry] {
        let start = timeRange.startDate
        return logState.sortedLogs.filter { $0.completedAt >= start }.compactMap { log in
            // Include VoiceTrainer logs that list this equipment directly
            if log.logType == .voiceTrainer && log.logEquipmentIDs.contains(equipment.id) {
                return SessionEntry(
                    id: log.id,
                    date: log.completedAt,
                    workoutName: log.workoutName,
                    exercises: []
                )
            }
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
            VStack(spacing: 0) {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(StatsTimeRange.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

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
