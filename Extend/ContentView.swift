//
//  ContentView.swift
//  Extend
//
//  Created by CAVAN MANNENBACH on 2/12/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    @Environment(DashboardState.self) var dashboardState

    var body: some View {
        let hasTopModules = !state.topNavBarModules.isEmpty
        let selectedModule = state.selectedModuleID.flatMap { registry.moduleWithID($0) }
        let shouldHideNavBars = selectedModule?.hidesNavBars ?? false

        // Single stable VStack — no branch switching, so SwiftUI never tears down
        // the view tree when top/bottom navbar membership changes.
        VStack(spacing: 0) {
            if hasTopModules && !shouldHideNavBars {
                navBarBackground
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)

                ModuleNavBar(position: .top)
            }

            ZStack {
                if let selectedModuleID = state.selectedModuleID,
                   let selectedModule = registry.moduleWithID(selectedModuleID) {
                    selectedModule.moduleView
                        .transition(.opacity)
                } else {
                    EmptyStateView()
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !shouldHideNavBars {
                ModuleNavBar(position: .bottom)

                navBarBackground
                    .ignoresSafeArea(edges: .bottom)
                    .frame(height: 0)
            }
        }
    }

    private var navBarBackground: some View {
        Group {
            if state.navBarUseGradient {
                LinearGradient(
                    colors: [state.navBarBackgroundColor, state.navBarGradientSecondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                state.navBarBackgroundColor
            }
        }
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Module Selected")
                .font(.headline)

            Text("Select a module from the navbar to get started")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
    }
}

#Preview {
    ContentView()
        .environment(ModuleRegistry.shared)
        .environment(ModuleState.shared)
}
