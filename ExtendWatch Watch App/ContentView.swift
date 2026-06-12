//
//  ContentView.swift
//  ExtendWatch Watch App
//

import SwiftUI

/// Root tab view: Plan list (tab 0), Steps/Distance (tab 1), Water (tab 2).
struct RootView: View {
    var body: some View {
        TabView {
            WatchPlanDetailView()
            WatchStepsView()
            WatchWaterView()
        }
        .tabViewStyle(.page)
        .task {
            await WatchHealthKit.shared.requestAuthorization()
        }
    }
}

#Preview {
    RootView()
}
