//
//  ContentView.swift
//  ExtendWatch Watch App
//

import SwiftUI

/// Root tab view: Plan list (tab 0) and Steps/Distance (tab 1).
struct RootView: View {
    var body: some View {
        TabView {
            WatchPlanDetailView()
            WatchStepsView()
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
