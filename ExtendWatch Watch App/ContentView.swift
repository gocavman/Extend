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
            let target: String
            switch url.host {
            case "plan"     where visibility.showPlan:    target = "plan"
            case "library"  where visibility.showLibrary: target = "library"
            case "steps"    where visibility.showSteps:   target = "steps"
            case "water"    where visibility.showWater:   target = "water"
            case "settings":                              target = "settings"
            default:                                      target = "settings"
            }
            // Snap straight to the target page instead of letting the page-
            // style TabView slide between the previously-active tab and the
            // complication's target. Without the animation suppression the
            // swipe takes long enough that it reads as "wrong page, then
            // pause, then right page" on cold launch.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = target
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
        // Live workout overlay — covers the tabs while a session is running
        // so the user sees HR/calories/duration on the wrist. The cover is
        // marked non-dismissable on purpose: the system X tap on watchOS
        // forcibly unmounts the cover even when the binding setter tries to
        // veto, which orphans the HKWorkoutSession (it keeps running but the
        // user has no UI to control it). Every active-workout view already
        // provides an explicit Stop / Finish button — that's the supported
        // way out, and it properly ends the session before dismissing.
        .fullScreenCover(isPresented: .constant(workoutManager.isActive)) {
            WatchActiveWorkoutView(manager: workoutManager)
                .interactiveDismissDisabled(true)
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
