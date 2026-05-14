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
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                List {
                    // Favorites tiles
                    if !timerState.favoriteConfigs.isEmpty {
                        Section("Favorites") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(timerState.favoriteConfigs) { config in
                                        NavigationLink(value: config) {
                                            VStack(spacing: 4) {
                                                Image(systemName: config.type.iconName)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.black)
                                                Text(config.name)
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.black)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                                Text(config.type.rawValue)
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(width: 70, height: 80)
                                            .padding(8)
                                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .padding(.horizontal, 12)
                            }
                            .frame(height: 100)
                            .listRowInsets(EdgeInsets())
                        }
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
                                onDelete: { deletingConfig = config },
                                onToggleFavorite: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    timerState.toggleFavorite(id: config.id)
                                }
                            )
                            .padding(.vertical, 6)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationDestination(for: TimerConfig.self) { config in
                ActiveTimerView(config: config)
            }
            .navigationDestination(item: $activeConfig) { config in
                ActiveTimerView(config: config)
            }
            .sheet(isPresented: $showingAdd) {
                TimerEditorView(title: "Add Timer") { config in
                    timerState.addConfig(config)
                }
            }
            .sheet(item: $editingConfig) { config in
                TimerEditorView(title: "Edit Timer", initial: config) { updated in
                    timerState.updateConfig(updated)
                }
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
        }
    }
}

// MARK: - Row View

private struct TimerRowView: View {
    let config: TimerConfig
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onClone: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPlay()
            }) {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(config.name.isEmpty ? "Unnamed Timer" : config.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(config.type.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black)
                        .cornerRadius(4)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            // Star / favorite
            Button(action: onToggleFavorite) {
                Image(systemName: config.isFavorite ? "star.fill" : "star")
                    .foregroundColor(config.isFavorite ? .black : .gray)
            }
            .buttonStyle(.plain)

            // Clone
            Button(action: onClone) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)

            // Edit
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onEdit()
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)

            // Delete
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDelete()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Editor

private struct TimerEditorView: View {
    @Environment(\.dismiss) var dismiss

    let title: String
    let initial: TimerConfig?
    let onSave: (TimerConfig) -> Void

    @State private var config: TimerConfig

    init(title: String, initial: TimerConfig? = nil, onSave: @escaping (TimerConfig) -> Void) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        _config = State(initialValue: initial ?? TimerConfig())
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Details") {
                    TextField("Name", text: $config.name)
                    TextField("Notes (optional)", text: $config.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                // Type picker — switching presets defaults
                Section("Type") {
                    Picker("Timer Type", selection: $config.type) {
                        ForEach(TimerType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: config.type) { _, newType in
                        config = config.applying(type: newType)
                    }
                    Text(config.type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Direction (Standard and AMRAP only)
                if config.type == .standard || config.type == .amrap {
                    Section("Direction") {
                        Picker("Direction", selection: $config.direction) {
                            ForEach(TimerDirection.allCases) { dir in
                                Text(dir.rawValue).tag(dir)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Work / main duration
                Section(config.type == .round || config.type == .tabata ? "Work Duration" : "Duration") {
                    DurationStepper(label: "", seconds: $config.duration)
                }

                // Rest duration
                if config.type == .round || config.type == .tabata || config.type == .emom {
                    Section("Rest Duration") {
                        DurationStepper(label: "", seconds: $config.restDuration)
                    }
                }

                // Rounds
                if config.type == .round || config.type == .tabata || config.type == .emom || config.type == .ladder {
                    Section("Rounds") {
                        IntStepper(label: "Rounds", value: $config.rounds, range: 1...999)
                    }
                }

                // Ladder-specific
                if config.type == .ladder {
                    Section("Ladder Settings") {
                        IntStepper(label: "Peak Rounds", value: $config.ladderPeakRounds, range: 1...50)
                        DurationStepper(label: "Step Size", seconds: $config.ladderStep)
                        DurationStepper(label: "Rest Between Steps", seconds: $config.restDuration)
                    }
                }

                // Warmup / Cooldown (all types)
                Section("Warmup & Cooldown") {
                    DurationStepper(label: "Warmup", seconds: $config.warmupDuration)
                    DurationStepper(label: "Cooldown", seconds: $config.cooldownDuration)
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
                        onSave(config)
                        dismiss()
                    }
                    .disabled(config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Stepper helpers

private struct DurationStepper: View {
    let label: String
    @Binding var seconds: Int

    @State private var text: String = ""

    var body: some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .font(.subheadline)
                Spacer()
            }
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if seconds > 0 { seconds = max(0, seconds - 5) }
                text = "\(seconds)"
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.monospacedDigit())
                .frame(width: 60)
                .padding(6)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(6)
                .onChange(of: text) { _, newVal in
                    if let v = Int(newVal) { seconds = max(0, v) }
                }
                .onAppear { text = "\(seconds)" }
                .onChange(of: seconds) { _, newVal in
                    if text != "\(newVal)" { text = "\(newVal)" }
                }

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                seconds += 5
                text = "\(seconds)"
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            if label.isEmpty { Spacer() }
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
                    .foregroundColor(.black)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            Text("\(value)")
                .font(.subheadline.monospacedDigit())
                .frame(width: 44, alignment: .center)
                .padding(6)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(6)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if value < range.upperBound { value += 1 }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.black)
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
    @State private var showSavedToast = false

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

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color(red: 0.93, green: 0.93, blue: 0.95)
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

                    // Big clock
                    Text(formatTime(displaySeconds))
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    // Phase navigation
                    HStack(spacing: 32) {
                        Button(action: previousPhase) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(phaseIndex > 0 ? .black : .gray)
                        }
                        .buttonStyle(.plain)
                        .disabled(phaseIndex == 0)

                        // Play / Pause
                        Button(action: toggleTimer) {
                            Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)

                        Button(action: nextPhase) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(phaseIndex < phases.count - 1 ? .black : .gray)
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
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
                                        .foregroundColor(.black)
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
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(config.name.isEmpty ? config.type.rawValue : config.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: saveToLog) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.black)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text("Saved to Log")
                    .font(.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .onAppear {
            buildPhases()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    // MARK: - Phase Building

    private mutating func buildPhases() {
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

        case .round:
            for r in 1...max(1, config.rounds) {
                list.append(TimerPhase(label: "Round \(r) of \(config.rounds) — Work", duration: config.duration, isCountUp: false))
                if config.restDuration > 0 && r < config.rounds {
                    list.append(TimerPhase(label: "Round \(r) of \(config.rounds) — Rest", duration: config.restDuration, isCountUp: false))
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let name = config.name.isEmpty ? config.type.rawValue : config.name
        let log = WorkoutLog(
            workoutName: "\(config.type.rawValue) – \(name)",
            completedAt: Date(),
            exercises: [],
            notes: buildLogNotes(),
            duration: TimeInterval(totalElapsed)
        )
        WorkoutLogState.shared.addLog(log)
        showSavedToast = true
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run { showSavedToast = false }
        }
    }

    private func buildLogNotes() -> String {
        var lines: [String] = []
        lines.append("Type: \(config.type.rawValue)")
        if !config.name.isEmpty { lines.append("Name: \(config.name)") }
        lines.append("Duration: \(formattedDuration(config.duration))")
        if config.type != .standard && config.type != .amrap {
            lines.append("Rounds: \(config.rounds)")
        }
        if config.type == .round || config.type == .tabata || config.type == .emom {
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
