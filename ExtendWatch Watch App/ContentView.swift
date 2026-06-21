//
//  ContentView.swift
//  ExtendWatch Watch App
//

import SwiftUI
import WidgetKit

extension Notification.Name {
    static let watchWaterDataUpdated       = Notification.Name("watchWaterDataUpdated")
    static let watchPlanDataUpdated        = Notification.Name("watchPlanDataUpdated")
    static let watchLibraryDataUpdated     = Notification.Name("watchLibraryDataUpdated")
    static let watchPageVisibilityChanged  = Notification.Name("watchPageVisibilityChanged")
}

/// Root tab view. Pages are conditionally included based on user visibility settings;
/// Settings is always present so a hidden page can be re-enabled.
struct RootView: View {
    @State private var selectedTab: String = "plan"
    @State private var visibility: WatchPageVisibility = readWatchPageVisibility()
    /// Watches for iPhone-driven workout sessions so the live UI can be
    /// presented over the regular pages while one is running.
    @State private var workoutManager = WatchWorkoutSessionManager.shared
    /// Set when the user taps the system dismiss X on the live-workout cover,
    /// or anywhere else that wants to confirm ending an in-progress session.
    @State private var showEndConfirmation: Bool = false

    /// Changes whenever any visibility toggle flips. Used as the TabView's `id`
    /// so SwiftUI rebuilds the page container from scratch when pages are added
    /// or removed — without this, watchOS sometimes leaves a re-added page
    /// blank until the app is relaunched.
    private var visibilityKey: String {
        "\(visibility.showPlan ? 1 : 0)\(visibility.showSteps ? 1 : 0)\(visibility.showWater ? 1 : 0)\(visibility.showLibrary ? 1 : 0)"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if visibility.showPlan {
                WatchPlanDetailView().tag("plan")
            }
            if visibility.showLibrary {
                WatchLibraryView().tag("library")
            }
            if visibility.showSteps {
                WatchStepsView().tag("steps")
            }
            if visibility.showWater {
                WatchWaterView().tag("water")
            }
            WatchSettingsView().tag("settings")
        }
        .tabViewStyle(.page)
        .id(visibilityKey)
        .onOpenURL { url in
            guard url.scheme == "extendwatch" else { return }
            switch url.host {
            case "plan"     where visibility.showPlan:    selectedTab = "plan"
            case "library"  where visibility.showLibrary: selectedTab = "library"
            case "steps"    where visibility.showSteps:   selectedTab = "steps"
            case "water"    where visibility.showWater:   selectedTab = "water"
            case "settings":                              selectedTab = "settings"
            default:                                      selectedTab = "settings"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchPageVisibilityChanged)) { _ in
            visibility = readWatchPageVisibility()
            // After a rebuild the selection might land on a different page than
            // the user just toggled. Default to settings so re-enabling a page
            // leaves them somewhere predictable, not on a blank screen.
            if !pageVisible(selectedTab) { selectedTab = "settings" }
        }
        .task {
            WatchConnectivityBridge.shared.activate()
            await WatchHealthKit.shared.requestAuthorization()
            await WatchWorkoutSessionManager.shared.requestAuthorization()
            // Reload complications so settings changes take effect
            WidgetCenter.shared.reloadAllTimelines()
        }
        // Live workout overlay — covers the tabs while an iPhone-driven session
        // is running so the user sees HR/calories/duration on the wrist. The
        // system X in the top-left writes `false` back to this binding; we
        // intercept that to surface a confirmation instead of either dismissing
        // silently (the cover stays because isActive is still true) or ending
        // the session by accident.
        .fullScreenCover(isPresented: Binding(
            get: { workoutManager.isActive },
            set: { newValue in
                if !newValue && workoutManager.isActive {
                    showEndConfirmation = true
                }
            }
        )) {
            WatchActiveWorkoutView(manager: workoutManager)
        }
        .confirmationDialog(
            "End workout?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                endActiveWorkout()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("This will save what you've logged so far and stop the live session.")
        }
    }

    /// Ends the active session and forwards the partial log to the iPhone so
    /// the user keeps whatever they completed before tapping X.
    private func endActiveWorkout() {
        guard workoutManager.isActive else { return }
        let logName = workoutManager.pendingLogName
        let activityTypeRaw = workoutManager.activityTypeRaw
        let start = workoutManager.startDate ?? Date()
        let exercises = workoutManager.loggedExercisesForReport()
        let isLocal = workoutManager.isLocallyStarted
        Task {
            let uuid = await workoutManager.end()
            // Only locally-started sessions get forwarded — iPhone-driven ones
            // are already known to iPhone, which builds its own log on end.
            guard isLocal else { return }
            let endDate = Date()
            let duration = endDate.timeIntervalSince(start)
            WatchConnectivityBridge.shared.sendCompletedLog(
                name: logName,
                completedAt: endDate,
                duration: duration,
                hkActivityTypeRaw: activityTypeRaw,
                hkWorkoutUUID: uuid,
                exercises: exercises.isEmpty ? nil : exercises
            )
        }
    }

    private func pageVisible(_ tag: String) -> Bool {
        switch tag {
        case "plan":     return visibility.showPlan
        case "library":  return visibility.showLibrary
        case "steps":    return visibility.showSteps
        case "water":    return visibility.showWater
        case "settings": return true
        default:         return false
        }
    }
}

#Preview {
    RootView()
}
