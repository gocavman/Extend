//
//  ContentView.swift
//  ExtendWatch Watch App
//

import SwiftUI

/// Root tab view: Plan list (tab 0), Steps/Distance (tab 1), Water (tab 2).
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
        }
        .tabViewStyle(.page)
        .onOpenURL { url in
            guard url.scheme == "extendwatch" else { return }
            switch url.host {
            case "plan":  selectedTab = 0
            case "steps": selectedTab = 1
            case "water": selectedTab = 2
            default: break
            }
        }
        .task {
            WatchConnectivityBridge.shared.activate()
            await WatchHealthKit.shared.requestAuthorization()
        }
    }
}

#Preview {
    RootView()
}
