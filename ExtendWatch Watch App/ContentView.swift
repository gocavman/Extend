//
//  ContentView.swift
//  ExtendWatch Watch App
//

import SwiftUI
import WidgetKit

/// Root tab view: Plan list (tab 0), Steps/Distance (tab 1), Water (tab 2), Settings (tab 3).
struct RootView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchPlanDetailView()
                .tag(0)
            WatchStepsView()
                .tag(1)
            WatchWaterView()
                .tag(2)
            WatchSettingsView()
                .tag(3)
        }
        .tabViewStyle(.page)
        .onOpenURL { url in
            guard url.scheme == "extendwatch" else { return }
            switch url.host {
            case "plan":     selectedTab = 0
            case "steps":    selectedTab = 1
            case "water":    selectedTab = 2
            case "settings": selectedTab = 3
            default: break
            }
        }
        .task {
            WatchConnectivityBridge.shared.activate()
            await WatchHealthKit.shared.requestAuthorization()
            // Reload complications so settings changes take effect
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

#Preview {
    RootView()
}
