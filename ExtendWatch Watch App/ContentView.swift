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
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: String = "plan"
    @State private var visibility: WatchPageVisibility = readWatchPageVisibility()
    /// Watches for iPhone-driven workout sessions so the live UI can be
    /// presented over the regular pages while one is running.
    @State private var workoutManager = WatchWorkoutSessionManager.shared
    /// True while the "Discard workout?" alert is up after the system X
    /// dismissed the live cover. Lets us re-present the cover if the user
    /// backs out, or actually cancel the session if they confirm.
    @State private var showingCancelConfirmation: Bool = false
    /// Flips true once we've either received a deep-link URL via .onOpenURL
    /// or waited long enough to assume none is coming. Until then we render
    /// a blank placeholder so cold-starts triggered by a complication tap
    /// don't briefly flash the previously-active tab while the URL handler
    /// is still in flight. Plain warm launches (icon tap, no URL) fall
    /// through to the grace-period timeout below and render normally.
    @State private var initialRouteResolved: Bool = false
    /// Bumped every time we re-arm the placeholder gate on a resume. Used to
    /// cancel any in-flight grace task from a prior cycle so a late timer
    /// can't reveal the tabs before .onOpenURL lands for the current resume.
    @State private var gateGeneration: Int = 0

    /// Changes whenever any visibility toggle flips. Used as the TabView's `id`
    /// so SwiftUI rebuilds the page container from scratch when pages are added
    /// or removed — without this, watchOS sometimes leaves a re-added page
    /// blank until the app is relaunched.
    private var visibilityKey: String {
        "\(visibility.showPlan ? 1 : 0)\(visibility.showSteps ? 1 : 0)\(visibility.showWater ? 1 : 0)\(visibility.showLibrary ? 1 : 0)"
    }

    var body: some View {
        Group {
            if initialRouteResolved {
                tabContent
            } else {
                // Black placeholder while waiting for the deep-link URL to
                // arrive. Imperceptible on warm launches (the grace task
                // flips this within ~250 ms even with no URL).
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            // Cold-launch grace: if no URL arrives in the window, treat
            // the launch as a plain icon tap and reveal the last tab.
            await runGraceTimer(generation: gateGeneration)
        }
        .onChange(of: scenePhase) { _, phase in
            // Warm resumes don't re-fire .task, so without this branch the
            // gate would stay open from the previous launch and the user
            // would see the last-active tab flash before .onOpenURL lands.
            switch phase {
            case .background, .inactive:
                // Re-arm the gate on the way out so the next .active starts
                // with the black placeholder, not the previously-shown tab.
                initialRouteResolved = false
                gateGeneration &+= 1
            case .active:
                // Kick off a fresh grace timer for this resume. If a deep
                // link comes in first, .onOpenURL flips the gate early.
                let gen = gateGeneration
                Task { await runGraceTimer(generation: gen) }
            @unknown default:
                break
            }
        }
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
            // complication's target.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = target
                // Reveal the tabs only after the deep-link target is in
                // place so the very first frame the user sees is the
                // correct page, not the previously-selected one.
                initialRouteResolved = true
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
            // Seed the water complication from HealthKit before the timeline
            // reload below. After a reinstall the App Group is empty, and the
            // iPhone's WC push can be dropped if it runs before the watch app
            // reports itself as installed — without this fallback the
            // complication renders 0 until the user logs more water.
            await seedWaterComplicationFromHealthKit()
            // Reload complications so settings changes take effect
            WidgetCenter.shared.reloadAllTimelines()
        }
        // Live workout overlay — covers the tabs while a session is running
        // so the user sees HR/calories/duration on the wrist. The system X
        // (top-left dismiss) is treated as a *cancel* request: it forcibly
        // unmounts the cover on watchOS, so we catch that in the binding's
        // setter and surface a confirmation alert. Confirming discards the
        // HKWorkout outright; backing out re-presents the cover. The Stop /
        // Finish buttons inside the runners stay as the "save and log" path.
        .fullScreenCover(isPresented: Binding(
            get: { workoutManager.isActive && !showingCancelConfirmation },
            set: { newValue in
                if !newValue && workoutManager.isActive && !showingCancelConfirmation {
                    showingCancelConfirmation = true
                }
            }
        )) {
            WatchActiveWorkoutView(manager: workoutManager)
        }
        .alert("Discard workout?", isPresented: $showingCancelConfirmation) {
            Button("Discard", role: .destructive) {
                Task { await workoutManager.cancel() }
            }
            Button("Keep going", role: .cancel) {
                // Falling through here just dismisses the alert; the cover
                // re-presents on the next render because the binding's `get`
                // now returns true again (manager still active, flag clear).
            }
        } message: {
            Text("This ends the session without saving a log.")
        }
    }

    /// The actual TabView — extracted so the placeholder gate above can
    /// withhold it for the first ~250 ms (or until the deep-link URL
    /// arrives, whichever first).
    @ViewBuilder
    private var tabContent: some View {
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
    }

    /// Waits the grace window and reveals the tabs — unless the gate has
    /// since been re-armed by another resume, in which case this stale
    /// timer drops its result so the newer cycle owns the reveal.
    private func runGraceTimer(generation: Int) async {
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard generation == gateGeneration else { return }
        initialRouteResolved = true
    }

    /// Reads today's water from HealthKit and writes it into the shared App
    /// Group so the WaterComplication's TimelineProvider has something to
    /// render. Idempotent — takes the max of HK and the stored value so a
    /// fresh in-flight watch-side optimistic total isn't reverted.
    private func seedWaterComplicationFromHealthKit() async {
        let hkOz = await WatchHealthKit.shared.todayWaterOz()
        guard hkOz > 0 else { return }
        let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard
        let current = defaults.double(forKey: "water_today_oz")
        defaults.set(max(hkOz, current), forKey: "water_today_oz")
        defaults.set(Calendar.current.startOfDay(for: Date()), forKey: "water_today_date")
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
