////
////  WatchLibraryView.swift
////  ExtendWatch
////
////  Browse-everything entry point on the Watch. A small hub of category tiles
////  (Recents, Favorites, Workouts, Exercises, Timers, Voice Trainers) keeps
////  the first screen short on a 40-45mm display; each tile pushes a drill-down
////  list of just that category. Drill-down lists reuse the same "Start a
////  session" confirmation alert the previous combined list used.
////
////  Recents and Favorites are projected on the iPhone side
////  (TrainingPlanState.refreshMultiDaySnapshots → WatchLibrarySnapshot.recents
////  + WatchLibraryItem.isFavorite).
////

import SwiftUI

struct WatchLibraryView: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshToken: UUID = UUID()
    @State private var pendingStartItem: WatchLibraryItem? = nil
    @State private var isStarting: Bool = false

    private var library: WatchLibrarySnapshot {
        _ = refreshToken
        return readWatchLibrarySnapshot()
    }

    private var favorites: [WatchLibraryItem] {
        (library.workouts + library.exercises + library.timers + library.voiceTrainers)
            .filter { $0.isFavorite }
    }

    private var isLibraryEmpty: Bool {
        library.workouts.isEmpty && library.exercises.isEmpty
            && library.timers.isEmpty && library.voiceTrainers.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLibraryEmpty {
                    emptyHubView
                } else {
                    hubList
                }
            }
            .navigationTitle("Library")
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchLibraryDataUpdated)) { _ in
            refreshToken = UUID()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToken = UUID() }
        }
        .alert(
            pendingStartItem?.name ?? "",
            isPresented: Binding(
                get: { pendingStartItem != nil },
                set: { if !$0 { pendingStartItem = nil } }
            )
        ) {
            Button("Start", role: .none) {
                if let item = pendingStartItem { startSession(for: item) }
            }
            Button("Cancel", role: .cancel) { pendingStartItem = nil }
        } message: {
            Text("Start a session on this watch? The log will sync to your iPhone when you finish.")
        }
    }

    // MARK: - Hub

    private var hubList: some View {
        List {
            hubTile(
                title: "Recents",
                icon: "clock.arrow.circlepath",
                count: library.recents.count,
                items: library.recents
            )
            hubTile(
                title: "Favorites",
                icon: "star.fill",
                count: favorites.count,
                items: favorites
            )
            hubTile(
                title: "Workouts",
                icon: "dumbbell.fill",
                count: library.workouts.count,
                items: library.workouts
            )
            hubTile(
                title: "Exercises",
                icon: "figure.strengthtraining.traditional",
                count: library.exercises.count,
                items: library.exercises
            )
            hubTile(
                title: "Timers",
                icon: "timer",
                count: library.timers.count,
                items: library.timers
            )
            hubTile(
                title: "Voice Trainers",
                icon: "waveform",
                count: library.voiceTrainers.count,
                items: library.voiceTrainers
            )
        }
    }

    @ViewBuilder
    private func hubTile(title: String, icon: String, count: Int, items: [WatchLibraryItem]) -> some View {
        NavigationLink {
            WatchLibraryCategoryView(
                title: title,
                items: items,
                pendingStartItem: $pendingStartItem
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    // MARK: - Empty state

    private var emptyHubView: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 20)
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No items yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Add workouts on your iPhone to populate the library.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Start

    private func startSession(for item: WatchLibraryItem) {
        guard !isStarting else { return }
        isStarting = true
        // Workouts get the blueprint runner; voice trainers get their
        // playback config; everything else is duration-only.
        let snapshot = readWatchLibrarySnapshot()
        let blueprint: WatchWorkoutBlueprint? = {
            guard item.kind == "workout" else { return nil }
            let bp = snapshot.workoutBlueprints[item.id]
            return (bp?.exercises.isEmpty == false) ? bp : nil
        }()
        let voiceConfig: WatchVoiceTrainerConfig? = {
            guard item.kind == "voice" else { return nil }
            return snapshot.voiceConfigs[item.id]
        }()
        Task {
            await WatchWorkoutSessionManager.shared.start(
                activityTypeRaw: item.hkActivityTypeRaw,
                name: item.name,
                isLocal: true,
                logName: item.logName,
                blueprint: blueprint,
                voiceConfig: voiceConfig
            )
            await MainActor.run {
                pendingStartItem = nil
                isStarting = false
            }
        }
    }
}

// MARK: - Drill-down list

/// Per-category list pushed from the hub. Knows only how to render rows and
/// surface a tap up to the hub via `pendingStartItem` — the hub owns the
/// confirmation alert + session start so navigation can stay shallow.
private struct WatchLibraryCategoryView: View {
    let title: String
    let items: [WatchLibraryItem]
    @Binding var pendingStartItem: WatchLibraryItem?

    var body: some View {
        Group {
            if items.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            pendingStartItem = item
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16)
                                Text(item.name)
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(title)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 20)
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Text("Nothing here yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WatchLibraryView()
}
