////
////  TimerModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UIKit

/// Module for managing and running interval timers.
public struct TimerModule: AppModule {
    public let id: UUID = ModuleIDs.timer
    public let displayName: String = "Timer"
    public let iconName: String = "timer"
    public let description: String = "Manage and run interval timers"

    public var order: Int = 4
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(TimerModuleView())
    }
}

// MARK: - List Screen

private struct TimerModuleView: View {
    @Environment(TimerState.self) var timerState

    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var editingConfig: TimerConfig?
    @State private var deletingConfig: TimerConfig?
    @State private var activeConfig: TimerConfig?
    @State private var historyConfig: TimerConfig?
    @State private var statsConfig: TimerConfig?

    private var filteredConfigs: [TimerConfig] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = timerState.configs.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.type.rawValue.localizedCaseInsensitiveContains(trimmed) ||
            $0.notes.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Timer")
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

                List {
                    // Favorites tiles
                    if !timerState.favoriteConfigs.isEmpty {
                        Section {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                                ForEach(timerState.favoriteConfigs) { config in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        activeConfig = config
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: config.type.iconName)
                                                .font(.system(size: 20))
                                                .foregroundColor(.primary)
                                            Text(config.name)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                            Text(config.type.rawValue)
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(width: 70, height: 80)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    // Search
                    Section {
                        SearchField(text: $searchText, placeholder: "Search timers...")
                    }

                    // All timers
                    if filteredConfigs.isEmpty {
                        Text(timerState.configs.isEmpty ? "No timers yet" : "No timers found")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filteredConfigs) { config in
                            TimerRowView(
                                config: config,
                                onPlay: { activeConfig = config },
                                onEdit: { editingConfig = config },
                                onClone: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    timerState.cloneConfig(config)
                                },
                                onToggleFavorite: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    timerState.toggleFavorite(id: config.id)
                                },
                                onHistory: { historyConfig = config },
                                onStats: { statsConfig = config }
                            )
                            .padding(.vertical, 6)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    editingConfig = config
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.primary)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    deletingConfig = config
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .fullScreenCover(item: $activeConfig) { config in
                ActiveTimerView(config: config)
            }
            .fullScreenCover(isPresented: $showingAdd) {
                TimerEditorView(title: "Add Timer") { config in
                    timerState.addConfig(config)
                }
            }
            .fullScreenCover(item: $editingConfig) { config in
                TimerEditorView(title: "Edit Timer", initial: config) { updated in
                    timerState.updateConfig(updated)
                } onDelete: {
                    timerState.removeConfig(id: config.id)
                }
            }
            .fullScreenCover(item: $historyConfig) { config in
                TimerHistorySheet(config: config, logState: WorkoutLogState.shared)
            }
            .fullScreenCover(item: $statsConfig) { config in
                TimerStatsView(config: config)
                    .environment(WorkoutLogState.shared)
            }
            .alert("Delete Timer?", isPresented: .constant(deletingConfig != nil)) {
                Button("Cancel", role: .cancel) { deletingConfig = nil }
                Button("Delete", role: .destructive) {
                    if let c = deletingConfig {
                        timerState.removeConfig(id: c.id)
                        deletingConfig = nil
                    }
                }
            } message: {
                Text("This will permanently delete the timer configuration.")
            }
            .onAppear {
                launchPendingTimerIfNeeded()
            }
            .onChange(of: timerState.pendingLaunchID) { _, _ in
                launchPendingTimerIfNeeded()
            }
        }
    }

    private func launchPendingTimerIfNeeded() {
        guard let id = timerState.pendingLaunchID else { return }
        timerState.pendingLaunchID = nil
        if let config = timerState.configs.first(where: { $0.id == id }) {
            activeConfig = config
        }
    }
}

// MARK: - Row View

private struct TimerRowView: View {
    let config: TimerConfig
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onClone: () -> Void
    let onToggleFavorite: () -> Void
    let onHistory: () -> Void
    let onStats: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: play icon, name, action buttons
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 20))

                HStack(spacing: 6) {
                    Text(config.name.isEmpty ? "Unnamed Timer" : config.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(config.type.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary)
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Star / favorite
                Button(action: onToggleFavorite) {
                    Image(systemName: config.isFavorite ? "star.fill" : "star")
                        .foregroundColor(config.isFavorite ? .primary : .gray)
                }
                .buttonStyle(.plain)

                // History
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onHistory()
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Stats
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onStats()
                }) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Clone
                Button(action: onClone) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Edit
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEdit()
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }

            Text(config.parameterSummary)
                .font(.caption2)
                .foregroundColor(.secondary)
            if !config.notes.isEmpty {
                Text(config.notes)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPlay()
        }
    }
}

// MARK: - Editor

private struct TimerEditorView: View {
    @Environment(\.dismiss) var dismiss

    let title: String
    let initial: TimerConfig?
    let onSave: (TimerConfig) -> Void
    let onDelete: (() -> Void)?

    @State private var config: TimerConfig
    @State private var showDeleteConfirm = false

    init(title: String, initial: TimerConfig? = nil, onSave: @escaping (TimerConfig) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        self.onDelete = onDelete
        _config = State(initialValue: initial ?? TimerConfig())
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Details") {
                    TextField("Name", text: $config.name)
                    TextField("Notes (optional)", text: $config.notes, axis: .vertical)
                        .lineLimit(1...6)
                }

                // Type picker — switching presets defaults
                Section("Type") {
                    Picker("Timer Type", selection: $config.type) {
                        ForEach(TimerType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .onChange(of: config.type) { _, newType in
                        config = config.applying(type: newType)
                    }
                    Text(config.type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Direction (Standard and AMRAP only) — no section header
                if config.type == .standard || config.type == .amrap {
                    Section {
                        Picker("Direction", selection: $config.direction) {
                            ForEach(TimerDirection.allCases) { dir in
                                Text(dir.rawValue).tag(dir)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Duration / Work+Rest
                if config.type == .interval || config.type == .tabata || config.type == .emom {
                    // Work + Rest side by side — no section header
                    Section {
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("Work")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                DurationStepper(label: "", seconds: $config.duration)
                            }
                            Divider()
                            VStack(spacing: 2) {
                                Text("Rest")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                DurationStepper(label: "", seconds: $config.restDuration)
                            }
                        }
                    }
                } else if config.type != .ladder {
                    // Standard / AMRAP — Duration in left column, right empty — no section header
                    Section {
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("Duration")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                DurationStepper(label: "", seconds: $config.duration)
                            }
                            Divider()
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }

                // Rounds — left column wheel, right empty — no section header
                if config.type == .interval || config.type == .tabata || config.type == .emom || config.type == .ladder {
                    Section {
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("Rounds")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                Picker("", selection: $config.rounds) {
                                    ForEach(1...999, id: \.self) { n in Text("\(n)").tag(n) }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .clipped()
                            }
                            Divider()
                            Color.clear.frame(maxWidth: .infinity)
                        }
                        .frame(height: 110)
                    }
                }

                // Ladder-specific — no section header
                if config.type == .ladder {
                    Section {
                        // Duration + Peak Rounds side by side
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("Duration")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                DurationStepper(label: "", seconds: $config.duration)
                            }
                            Divider()
                            VStack(spacing: 2) {
                                Text("Peak Rounds")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                Picker("", selection: $config.ladderPeakRounds) {
                                    ForEach(1...50, id: \.self) { n in Text("\(n)").tag(n) }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .clipped()
                            }
                        }
                        .frame(height: 130)

                        // Step Size + Rest side by side
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("Step Size")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                DurationStepper(label: "", seconds: $config.ladderStep)
                            }
                            Divider()
                            VStack(spacing: 2) {
                                Text("Rest Between Steps")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                DurationStepper(label: "", seconds: $config.restDuration)
                            }
                        }
                    }
                }

                // Warmup & Cooldown — no section header, labels above wheels are sufficient
                Section {
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("Warmup")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            DurationStepper(label: "", seconds: $config.warmupDuration)
                        }
                        Divider()
                        VStack(spacing: 2) {
                            Text("Cooldown")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            DurationStepper(label: "", seconds: $config.cooldownDuration)
                        }
                    }
                }

                if HealthKitState.shared.exportStrengthWorkouts {
                    Section("Apple Health Activity") {
                        HKActivityTypePicker(rawValue: $config.healthKitActivityType)
                    }
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
                        onSave(config)
                        dismiss()
                    }
                    .disabled(config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Timer?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete the timer configuration.")
            }
        }
    }
}

// MARK: - Stepper helpers

/// Inline minutes + seconds wheel picker. Seconds column snaps to 5-second increments.
private struct DurationStepper: View {
    let label: String
    @Binding var seconds: Int

    private var minutes: Int { seconds / 60 }
    private var secs: Int { (seconds % 60) / 5 * 5 }  // snap to nearest 5s

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.subheadline)
            }
            HStack(spacing: 0) {
                // Minutes wheel
                Picker("", selection: Binding(
                    get: { minutes },
                    set: { seconds = $0 * 60 + secs }
                )) {
                    ForEach(0..<100, id: \.self) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                // Seconds wheel (0, 5, 10 … 55)
                Picker("", selection: Binding(
                    get: { secs },
                    set: { seconds = minutes * 60 + $0 }
                )) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { s in
                        Text("\(s) sec").tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 120)
        }
    }
}

private struct IntStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if value > range.lowerBound { value -= 1 }
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            Text("\(value)")
                .font(.subheadline.monospacedDigit())
                .frame(width: 44, alignment: .center)
                .padding(6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(6)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if value < range.upperBound { value += 1 }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Active Timer

/// A single phase in the timer sequence.
private struct TimerPhase {
    let label: String
    let duration: Int           // 0 = count-up with no end
    let isCountUp: Bool
}

private struct ActiveTimerView: View {
    @Environment(\.dismiss) var dismiss

    let config: TimerConfig

    // Phase sequence
    @State private var phases: [TimerPhase] = []
    @State private var phaseIndex: Int = 0
    @State private var phaseElapsed: Int = 0   // seconds elapsed in current phase
    @State private var totalElapsed: Int = 0   // total session seconds
    @State private var isRunning = false
    @State private var timerTask: Task<Void, Never>?
    @State private var amrapRounds = 0
    @State private var showingCancelConfirm = false

    private var currentPhase: TimerPhase? {
        guard phaseIndex < phases.count else { return nil }
        return phases[phaseIndex]
    }

    private var phaseRemaining: Int {
        guard let p = currentPhase, !p.isCountUp, p.duration > 0 else { return 0 }
        return max(0, p.duration - phaseElapsed)
    }

    private var displaySeconds: Int {
        guard let p = currentPhase else { return 0 }
        if p.isCountUp || p.duration == 0 { return phaseElapsed }
        return phaseRemaining
    }

    private var totalDuration: Int {
        phases.reduce(0) { $0 + ($1.duration == 0 ? config.duration : $1.duration) }
    }

    private var sessionProgress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = phases.prefix(phaseIndex).reduce(0) { $0 + ($1.duration == 0 ? config.duration : $1.duration) } + phaseElapsed
        return min(1.0, Double(elapsed) / Double(totalDuration))
    }

    // Progress within the current phase (0.0 → 1.0), always increasing
    private var phaseProgress: Double {
        guard let p = currentPhase else { return 0 }
        let duration = p.duration == 0 ? config.duration : p.duration
        guard duration > 0 else { return 0 }
        return min(1.0, Double(phaseElapsed) / Double(duration))
    }

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color(UIColor.secondarySystemBackground)
                    Color.black.opacity(0.85)
                        .frame(width: geo.size.width * sessionProgress)
                }
            }
            .frame(height: 4)

            ScrollView {
                VStack(spacing: 24) {
                    // Phase label
                    Text(currentPhase?.label ?? "Done")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.top, 24)

                    // Big clock with circular progress ring
                    ZStack {
                        // Track ring
                        Circle()
                            .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 10)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: phaseProgress)
                            .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: phaseProgress)

                        // Time text
                        Text(formatTime(displaySeconds))
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                    }
                    .frame(width: 240, height: 240)

                    // Phase navigation
                    HStack(spacing: 32) {
                        Button(action: previousPhase) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(phaseIndex > 0 ? .primary : .gray)
                        }
                        .buttonStyle(.plain)
                        .disabled(phaseIndex == 0)

                        // Play / Pause
                        Button(action: toggleTimer) {
                            Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Button(action: nextPhase) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(phaseIndex < phases.count - 1 ? .primary : .gray)
                        }
                        .buttonStyle(.plain)
                        .disabled(phaseIndex >= phases.count - 1)
                    }

                    // Restart
                    Button(action: restartTimer) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Restart")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // AMRAP round counter
                    if config.type == .amrap {
                        VStack(spacing: 8) {
                            Text("Rounds Completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 20) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if amrapRounds > 0 { amrapRounds -= 1 }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)

                                Text("\(amrapRounds)")
                                    .font(.system(size: 40, weight: .bold, design: .monospaced))

                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    amrapRounds += 1
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
                    }

                    // Config summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Configuration")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(buildConfigSummary())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(config.name.isEmpty ? config.type.rawValue : config.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { showingCancelConfirm = true }
                    .tint(.red)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Complete") {
                    saveToLog()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Stop Timer?", isPresented: $showingCancelConfirm) {
            Button("Keep Going", role: .cancel) { }
            Button("Stop", role: .destructive) { dismiss() }
        } message: {
            Text("The timer session will be discarded.")
        }
        .onAppear {
            buildPhases()
            if TimerState.shared.keepScreenOn {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        .onDisappear {
            timerTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        } // NavigationStack
    }

    // MARK: - Phase Building

    private func buildPhases() {
        phases = buildPhaseList()
        phaseIndex = 0
        phaseElapsed = 0
        totalElapsed = 0
    }

    private func buildPhaseList() -> [TimerPhase] {
        var list: [TimerPhase] = []

        // Warmup
        if config.warmupDuration > 0 {
            list.append(TimerPhase(label: "Warmup", duration: config.warmupDuration, isCountUp: false))
        }

        switch config.type {
        case .standard:
            let isUp = config.direction == .countUp
            list.append(TimerPhase(label: "Go", duration: isUp ? 0 : config.duration, isCountUp: isUp))

        case .interval:
            for r in 1...max(1, config.rounds) {
                list.append(TimerPhase(label: "Interval \(r) of \(config.rounds) — Work", duration: config.duration, isCountUp: false))
                if config.restDuration > 0 && r < config.rounds {
                    list.append(TimerPhase(label: "Interval \(r) of \(config.rounds) — Rest", duration: config.restDuration, isCountUp: false))
                }
            }

        case .tabata:
            for r in 1...max(1, config.rounds) {
                list.append(TimerPhase(label: "Tabata \(r) of \(config.rounds) — Work", duration: config.duration, isCountUp: false))
                if r < config.rounds {
                    list.append(TimerPhase(label: "Tabata \(r) of \(config.rounds) — Rest", duration: config.restDuration, isCountUp: false))
                }
            }

        case .emom:
            for r in 1...max(1, config.rounds) {
                list.append(TimerPhase(label: "Minute \(r) of \(config.rounds)", duration: 60, isCountUp: false))
            }

        case .amrap:
            list.append(TimerPhase(label: "AMRAP — Go!", duration: config.duration, isCountUp: false))

        case .ladder:
            let peak = max(1, config.ladderPeakRounds)
            var steps: [Int] = []
            for i in 1...peak { steps.append(i * config.ladderStep) }
            for i in stride(from: peak - 1, through: 1, by: -1) { steps.append(i * config.ladderStep) }
            let total = steps.count
            for (idx, dur) in steps.enumerated() {
                list.append(TimerPhase(label: "Ladder \(idx + 1) of \(total) — \(dur)s", duration: dur, isCountUp: false))
                if config.restDuration > 0 && idx < total - 1 {
                    list.append(TimerPhase(label: "Rest", duration: config.restDuration, isCountUp: false))
                }
            }
        }

        // Cooldown
        if config.cooldownDuration > 0 {
            list.append(TimerPhase(label: "Cooldown", duration: config.cooldownDuration, isCountUp: false))
        }

        return list
    }

    // MARK: - Timer Control

    private func toggleTimer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isRunning.toggle()
        if isRunning {
            startTick()
        } else {
            timerTask?.cancel()
        }
    }

    private func startTick() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run { tick() }
            }
        }
    }

    private func tick() {
        guard isRunning else { return }
        phaseElapsed += 1
        totalElapsed += 1

        guard let p = currentPhase else {
            isRunning = false
            timerTask?.cancel()
            return
        }

        // Advance phase when duration is reached (count-down only)
        if !p.isCountUp && p.duration > 0 && phaseElapsed >= p.duration {
            if phaseIndex < phases.count - 1 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                phaseIndex += 1
                phaseElapsed = 0
            } else {
                // All phases done
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isRunning = false
                timerTask?.cancel()
            }
        }
    }

    private func nextPhase() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if phaseIndex < phases.count - 1 {
            phaseIndex += 1
            phaseElapsed = 0
        }
    }

    private func previousPhase() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if phaseIndex > 0 {
            phaseIndex -= 1
            phaseElapsed = 0
        }
    }

    private func restartTimer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        timerTask?.cancel()
        isRunning = false
        phaseIndex = 0
        phaseElapsed = 0
        totalElapsed = 0
        amrapRounds = 0
    }

    // MARK: - Logging

    private func saveToLog() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let name = config.name.isEmpty ? config.type.rawValue : config.name
        let log = WorkoutLog(
            workoutName: "\(config.type.rawValue) – \(name)",
            completedAt: Date(),
            exercises: [],
            notes: buildLogNotes(),
            duration: TimeInterval(totalElapsed)
        )
        WorkoutLogState.shared.addLog(
            log,
            exportToHealthKit: HealthKitState.shared.exportStrengthWorkouts,
            activityTypeRaw: config.healthKitActivityType
        )
        ModuleState.shared.selectModule(ModuleIDs.progress)
        dismiss()
    }

    private func buildLogNotes() -> String {
        var lines: [String] = []
        lines.append("Type: \(config.type.rawValue)")
        if !config.name.isEmpty { lines.append("Name: \(config.name)") }
        lines.append("Duration: \(formattedDuration(config.duration))")
        if config.type != .standard && config.type != .amrap {
            lines.append("Rounds: \(config.rounds)")
        }
        if config.type == .interval || config.type == .tabata || config.type == .emom {
            lines.append("Rest: \(formattedDuration(config.restDuration))")
        }
        if config.warmupDuration > 0 { lines.append("Warmup: \(formattedDuration(config.warmupDuration))") }
        if config.cooldownDuration > 0 { lines.append("Cooldown: \(formattedDuration(config.cooldownDuration))") }
        if config.type == .ladder {
            lines.append("Ladder Step: \(config.ladderStep)s | Peak: \(config.ladderPeakRounds) rounds")
        }
        if config.type == .amrap {
            lines.append("Rounds Completed: \(amrapRounds)")
        }
        let elapsedPhase = phases.prefix(phaseIndex).reduce(0) { $0 + $1.duration } + phaseElapsed
        lines.append("Session Time: \(formattedDuration(elapsedPhase))")
        if !config.notes.isEmpty { lines.append("Notes: \(config.notes)") }
        return lines.joined(separator: "\n")
    }

    private func buildConfigSummary() -> String {
        var lines: [String] = [config.parameterSummary]
        if config.warmupDuration > 0 { lines.append("Warmup: \(formattedDuration(config.warmupDuration))") }
        if config.cooldownDuration > 0 { lines.append("Cooldown: \(formattedDuration(config.cooldownDuration))") }
        return lines.joined(separator: " · ")
    }

    // MARK: - Formatting

    private func formatTime(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private func formattedDuration(_ s: Int) -> String {
        if s >= 60 {
            let m = s / 60; let sec = s % 60
            return sec == 0 ? "\(m)m" : "\(m)m \(sec)s"
        }
        return "\(s)s"
    }
}

#Preview {
    TimerModuleView()
        .environment(TimerState.shared)
}
