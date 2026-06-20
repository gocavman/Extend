////
////  WatchLibraryView.swift
////  ExtendWatch
////
////  Browse-everything entry point on the Watch. Lists the user's full
////  library of workouts / exercises / timers / voice trainers — anything
////  the iPhone has — and lets the user start a live HKWorkoutSession for
////  any of them directly from the wrist. The session lifecycle (live UI +
////  iPhone-side log delivery on Finish) reuses the same plumbing the
////  plan view uses.
////

import SwiftUI

struct WatchLibraryView: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshToken: UUID = UUID()
    @State private var pendingStartItem: WatchLibraryItem? = nil
    @State private var isStarting: Bool = false
    @State private var searchText: String = ""

    private var library: WatchLibrarySnapshot {
        _ = refreshToken
        return readWatchLibrarySnapshot()
    }

    private func filtered(_ items: [WatchLibraryItem]) -> [WatchLibraryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if library.workouts.isEmpty && library.exercises.isEmpty
                    && library.timers.isEmpty && library.voiceTrainers.isEmpty {
                    emptyView
                } else {
                    section("Workouts", items: filtered(library.workouts))
                    section("Exercises", items: filtered(library.exercises))
                    section("Timers", items: filtered(library.timers))
                    section("Voice Trainers", items: filtered(library.voiceTrainers))
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

    @ViewBuilder
    private func section(_ title: String, items: [WatchLibraryItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
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

    private var emptyView: some View {
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
        .listRowBackground(Color.clear)
    }

    private func startSession(for item: WatchLibraryItem) {
        guard !isStarting else { return }
        isStarting = true
        // Workouts get launched with their blueprint (set-by-set runner);
        // every other kind starts a simple "duration-only" session.
        let blueprint: WatchWorkoutBlueprint? = {
            guard item.kind == "workout" else { return nil }
            let bp = readWatchLibrarySnapshot().workoutBlueprints[item.id]
            return (bp?.exercises.isEmpty == false) ? bp : nil
        }()
        Task {
            await WatchWorkoutSessionManager.shared.start(
                activityTypeRaw: item.hkActivityTypeRaw,
                name: item.name,
                isLocal: true,
                logName: item.logName,
                blueprint: blueprint
            )
            await MainActor.run {
                pendingStartItem = nil
                isStarting = false
            }
        }
    }
}

#Preview {
    WatchLibraryView()
}
