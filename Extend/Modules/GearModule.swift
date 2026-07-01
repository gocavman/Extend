////
////  GearModule.swift
////  Extend
////

import SwiftUI
import UIKit

/// Module for tracking wearable / consumable gear (shoes, bikes, straps, etc.).
///
/// Distinct from `EquipmentModule`: gear resolves usage by matching a log's
/// date against the gear's ownership window and the log's exercises against
/// the gear's linked exercises — no writes to `LoggedExercise.usedEquipmentIDs`
/// at log time, so adding a new pair of shoes retroactively surfaces every
/// prior run inside the window without mutating history.
public struct GearModule: AppModule {
    public let id: UUID = ModuleIDs.gear
    public let displayName: String = "Gear"
    public let iconName: String = "shoe"
    public let description: String = "Track shoes, bikes, and other wearable gear"

    public var order: Int = 15
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(GearModuleView())
    }
}

private struct GearModuleView: View {
    @Environment(GearState.self) var state
    @Environment(ExercisesState.self) var exercisesState
    @Environment(WorkoutLogState.self) var logState

    @State private var searchText: String = ""
    @State private var showingAdd = false
    @State private var editingItem: Gear?
    @State private var deletingItem: Gear?
    @State private var statsItem: Gear?
    @State private var historyItem: Gear?

    private var filteredItems: [Gear] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return state.sortedItems }
        return state.sortedItems.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.brand.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Gear")
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

                if !state.favoriteItems.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(state.favoriteItems) { item in
                            VStack(spacing: 0) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    statsItem = item
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: item.sfSymbol ?? GearState.defaultSFSymbol(for: item.name))
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
                    SearchField(text: $searchText, placeholder: "Search gear...")

                    ForEach(filteredItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.sfSymbol ?? GearState.defaultSFSymbol(for: item.name))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.08))
                                .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                if !item.brand.isEmpty {
                                    Text(item.brand)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if item.retiredDate != nil {
                                    Text("Retired")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsItem = item
                            }

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                state.toggleFavorite(item)
                            }) {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(item.isFavorite ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                historyItem = item
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                statsItem = item
                            }) {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

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

                    if filteredItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "shoe")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(.secondary)
                            Text("No Gear Yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Add shoes, bikes, or other wearable gear. Set a start date and link it to activities — mileage and sessions will accumulate from qualifying logs automatically.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .fullScreenCover(isPresented: $showingAdd) {
                    GearEditor(title: "Add Gear") { updated in
                        state.addItem(
                            name: updated.name,
                            brand: updated.brand,
                            sfSymbol: updated.sfSymbol,
                            linkedExerciseIDs: updated.linkedExerciseIDs,
                            startDate: updated.startDate,
                            retiredDate: updated.retiredDate,
                            retirementThresholdMeters: updated.retirementThresholdMeters
                        )
                    }
                }
                .fullScreenCover(item: $editingItem) { item in
                    GearEditor(
                        title: "Edit Gear",
                        initial: item
                    ) { updated in
                        state.updateItem(updated)
                    } onDelete: {
                        state.removeItem(id: item.id)
                    }
                }
                .fullScreenCover(item: $historyItem) { item in
                    GearHistorySheet(gear: item, logState: logState, gearState: state)
                }
                .alert("Delete Gear?", isPresented: .constant(deletingItem != nil)) {
                    Button("Cancel", role: .cancel) { deletingItem = nil }
                    Button("Delete", role: .destructive) {
                        if let g = deletingItem {
                            state.removeItem(id: g.id)
                            deletingItem = nil
                        }
                    }
                } message: {
                    Text("This will permanently delete the gear item. Historical logs are not affected.")
                }
            }
            .fullScreenCover(item: $statsItem) { item in
                GearStatsView(gear: item)
                    .environment(logState)
                    .environment(state)
                    .environment(exercisesState)
            }
        }
    }
}

// MARK: - Gear Editor

private struct GearEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ExercisesState.self) var exercisesState

    let title: String
    let initial: Gear
    let onSave: (Gear) -> Void
    let onDelete: (() -> Void)?

    @AppStorage("distanceUnit") private var distanceUnit: String = "mi"

    @State private var name: String
    @State private var brand: String
    @State private var selectedSymbol: String
    @State private var startDate: Date
    @State private var hasRetiredDate: Bool
    @State private var retiredDate: Date
    @State private var linkedIDs: Set<UUID>
    @State private var hasRetirementThreshold: Bool
    @State private var retirementThresholdDisplay: Double
    @State private var showDeleteConfirm = false
    @State private var showSymbolPicker = false
    @State private var showExercisePicker = false

    init(
        title: String,
        initial: Gear = Gear(name: ""),
        onSave: @escaping (Gear) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initial.name)
        _brand = State(initialValue: initial.brand)
        _selectedSymbol = State(initialValue: initial.sfSymbol ?? GearState.defaultSFSymbol(for: initial.name.isEmpty ? "shoe" : initial.name))
        _startDate = State(initialValue: initial.startDate)
        _hasRetiredDate = State(initialValue: initial.retiredDate != nil)
        _retiredDate = State(initialValue: initial.retiredDate ?? Date())
        _linkedIDs = State(initialValue: Set(initial.linkedExerciseIDs))
        _hasRetirementThreshold = State(initialValue: initial.retirementThresholdMeters != nil)
        let unit = UserDefaults.standard.string(forKey: "distanceUnit") ?? "mi"
        _retirementThresholdDisplay = State(initialValue: DistanceFormatter.value(
            meters: initial.retirementThresholdMeters ?? DistanceFormatter.meters(from: 500, unit: unit),
            unit: unit
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name (e.g. Nike Pegasus 40)", text: $name)
                    TextField("Brand (optional)", text: $brand)
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

                Section {
                    Button(action: { showExercisePicker = true }) {
                        HStack {
                            Text("Linked Activities")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(linkedSummary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("Choose the exercises/activities this gear applies to (e.g. Running). Logs of these exercises inside the ownership window will count toward this gear's stats — no manual tagging needed.")
                }

                Section {
                    DatePicker("First used", selection: $startDate, displayedComponents: .date)
                    Toggle("Retired", isOn: $hasRetiredDate)
                    if hasRetiredDate {
                        DatePicker("Retired on", selection: $retiredDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Ownership Window")
                } footer: {
                    Text("Only logs whose date falls inside this window are counted. Retire a pair when you stop using it so a new pair's stats don't overlap.")
                }

                Section {
                    Toggle("Retirement Threshold", isOn: $hasRetirementThreshold)
                    if hasRetirementThreshold {
                        HStack {
                            Text("Retire at")
                            Spacer()
                            TextField("500", value: $retirementThresholdDisplay, format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(distanceUnit)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Optional. The stats screen will warn as cumulative distance approaches this value.")
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Gear")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let start = Calendar.current.startOfDay(for: startDate)
                        let end: Date?
                        if hasRetiredDate {
                            let dayStart = Calendar.current.startOfDay(for: retiredDate)
                            end = Calendar.current.date(byAdding: .day, value: 1, to: dayStart).map { $0.addingTimeInterval(-1) }
                        } else {
                            end = nil
                        }
                        let thresholdMeters: Double? = hasRetirementThreshold
                            ? DistanceFormatter.meters(from: retirementThresholdDisplay, unit: distanceUnit)
                            : nil
                        var updated = initial
                        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.sfSymbol = selectedSymbol
                        updated.startDate = start
                        updated.retiredDate = end
                        updated.linkedExerciseIDs = Array(linkedIDs)
                        updated.retirementThresholdMeters = thresholdMeters
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Gear?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete the gear item. Historical logs are not affected.")
            }
            .fullScreenCover(isPresented: $showSymbolPicker) {
                GearSymbolPicker(selectedSymbol: $selectedSymbol)
            }
            .fullScreenCover(isPresented: $showExercisePicker) {
                GearExercisePicker(selectedIDs: $linkedIDs)
                    .environment(exercisesState)
            }
        }
    }

    private var linkedSummary: String {
        if linkedIDs.isEmpty { return "None" }
        let names = exercisesState.exercises
            .filter { linkedIDs.contains($0.id) }
            .map { $0.name }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names.count) selected"
    }
}

// MARK: - Symbol Picker

private struct GearSymbolPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSymbol: String
    @State private var searchText = ""

    private let allSymbols: [(category: String, symbols: [String])] = [
        ("Footwear", [
            "shoe", "shoe.fill", "shoe.2", "shoe.2.fill",
            "shoeprints.fill", "figure.run", "figure.walk", "figure.hiking",
        ]),
        ("Cycling", [
            "bicycle", "figure.outdoor.cycle", "figure.indoor.cycle",
        ]),
        ("Wearables", [
            "applewatch", "airpods", "heart.fill", "waveform.path.ecg",
        ]),
        ("Other", [
            "backpack.fill", "duffle.bag.fill",
            "figure.pool.swim", "figure.skiing.downhill",
            "flame.fill", "bolt.fill", "star.fill",
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

// MARK: - Exercise Picker

private struct GearExercisePicker: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ExercisesState.self) var exercisesState
    @Binding var selectedIDs: Set<UUID>
    @State private var searchText = ""

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = exercisesState.exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search exercises...", text: $searchText)
                            .autocorrectionDisabled()
                    }
                }
                ForEach(filtered) { ex in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedIDs.contains(ex.id) {
                            selectedIDs.remove(ex.id)
                        } else {
                            selectedIDs.insert(ex.id)
                        }
                    }) {
                        HStack {
                            Text(ex.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedIDs.contains(ex.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Linked Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Gear Stats View

private struct GearStatsView: View {
    let gear: Gear

    @AppStorage("distanceUnit") private var distanceUnit: String = "mi"
    @Environment(WorkoutLogState.self) var logState
    @Environment(GearState.self) var gearState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: StatsTimeRange = .oneMonth

    private var qualifyingLogs: [WorkoutLog] {
        let start = max(timeRange.startDate, gear.startDate)
        let end = gear.retiredDate ?? .distantFuture
        return gearState.logs(for: gear, in: logState.logs)
            .filter { $0.completedAt >= start && $0.completedAt <= end }
            .sorted { $0.completedAt < $1.completedAt }
    }

    /// Lifetime totals — ignore the picker's window so the retirement gauge
    /// reflects actual accumulated wear.
    private var lifetimeDistanceMeters: Double {
        gearState.totalDistanceMeters(for: gear, in: logState.logs)
    }

    private var lifetimeSessions: Int {
        gearState.sessionCount(for: gear, in: logState.logs)
    }

    private var linkedExercises: [Exercise] {
        let set = Set(gear.linkedExerciseIDs)
        return exercisesState.exercises.filter { set.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Lifetime summary card
                    lifetimeSummary
                        .padding(.horizontal, 16)

                    if let threshold = gear.retirementThresholdMeters, threshold > 0 {
                        retirementGauge(threshold: threshold)
                            .padding(.horizontal, 16)
                    }

                    Picker("Time Range", selection: $timeRange) {
                        ForEach(StatsTimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if qualifyingLogs.isEmpty {
                        emptyState
                    } else {
                        rangeSummary
                            .padding(.horizontal, 16)
                    }

                    if !linkedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Linked Activities")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)
                            ForEach(linkedExercises) { ex in
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(ex.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(gear.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    private var lifetimeSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime")
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack(spacing: 0) {
                summaryCell(label: "Sessions", value: "\(lifetimeSessions)")
                Divider().frame(height: 32)
                summaryCell(label: "Distance", value: DistanceFormatter.format(meters: lifetimeDistanceMeters, unit: distanceUnit))
                Divider().frame(height: 32)
                summaryCell(label: "Since", value: gear.startDate.formatted(.dateTime.year(.twoDigits).month(.abbreviated).day()))
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }

    private func retirementGauge(threshold: Double) -> some View {
        let progress = min(lifetimeDistanceMeters / threshold, 1.0)
        let percent = Int(progress * 100)
        let color: Color = progress >= 1.0 ? .red : (progress >= 0.9 ? .orange : .accentColor)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Retirement Threshold")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(percent)%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            ProgressView(value: progress)
                .tint(color)
            HStack {
                Text(DistanceFormatter.format(meters: lifetimeDistanceMeters, unit: distanceUnit))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(DistanceFormatter.format(meters: threshold, unit: distanceUnit))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }

    private var rangeSummary: some View {
        let linked = Set(gear.linkedExerciseIDs)
        let distanceM = qualifyingLogs.reduce(0.0) { partial, log in
            partial + log.exercises.filter { linked.contains($0.exerciseID) }.reduce(0.0) { $0 + ($1.distanceMeters ?? 0) }
        }
        let seconds = qualifyingLogs.reduce(0) { partial, log in
            partial + log.exercises.filter { linked.contains($0.exerciseID) }.reduce(0) { $0 + $1.activeSeconds }
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("This Range")
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack(spacing: 0) {
                summaryCell(label: "Sessions", value: "\(qualifyingLogs.count)")
                Divider().frame(height: 32)
                summaryCell(label: "Distance", value: DistanceFormatter.format(meters: distanceM, unit: distanceUnit))
                Divider().frame(height: 32)
                summaryCell(label: "Duration", value: formatMinutes(seconds))
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("No Data")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(gear.linkedExerciseIDs.isEmpty
                ? "Link this gear to at least one activity to see stats."
                : "No logs of linked activities in this window yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatMinutes(_ seconds: Int) -> String {
        if seconds == 0 { return "—" }
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h)h" : "\(h)h \(rem)m"
    }
}

// MARK: - History Sheet

private struct GearHistorySheet: View {
    @AppStorage("distanceUnit") private var distanceUnit: String = "mi"
    @Environment(\.dismiss) var dismiss

    let gear: Gear
    let logState: WorkoutLogState
    let gearState: GearState
    @State private var timeRange: StatsTimeRange = .oneMonth

    private var sessions: [WorkoutLog] {
        let start = max(timeRange.startDate, gear.startDate)
        let end = gear.retiredDate ?? .distantFuture
        return gearState.logs(for: gear, in: logState.sortedLogs)
            .filter { $0.completedAt >= start && $0.completedAt <= end }
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
                            Text("No qualifying logs for this gear in the selected window.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(sessions) { log in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(log.completedAt, style: .date)
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text(log.completedAt, style: .time)
                                            .font(.caption).foregroundColor(.secondary)
                                        Spacer()
                                        Text(log.workoutName)
                                            .font(.caption).foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    let linked = Set(gear.linkedExerciseIDs)
                                    let matching = log.exercises.filter { linked.contains($0.exerciseID) }
                                    ForEach(matching) { ex in
                                        HStack {
                                            Text(ex.exerciseName)
                                                .font(.caption)
                                            Spacer()
                                            if let d = ex.distanceMeters, d > 0 {
                                                Text(DistanceFormatter.format(meters: d, unit: distanceUnit))
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("History: \(gear.name)")
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
    GearModuleView()
        .environment(GearState.shared)
        .environment(ExercisesState.shared)
        .environment(WorkoutLogState.shared)
}
