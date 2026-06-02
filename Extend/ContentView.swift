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

    @AppStorage("appColorScheme") private var appColorScheme: String = "light"

    private var preferredScheme: ColorScheme? {
        switch appColorScheme {
        case "dark": return .dark
        default: return .light
        }
    }

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
        .preferredColorScheme(preferredScheme)
    }

    /// Whether the stored navbar background color is still the default (near-white).
    private var isDefaultNavBarColor: Bool {
        let c = UIColor(state.navBarBackgroundColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return abs(Double(r) - 0.98) < 0.01 && abs(Double(g) - 0.98) < 0.01 && abs(Double(b) - 1.0) < 0.01
    }

    private var effectiveNavBarBgColor: Color {
        isDefaultNavBarColor ? Color(UIColor.systemBackground) : state.navBarBackgroundColor
    }

    private var navBarBackground: some View {
        Group {
            if state.navBarUseGradient {
                let effectiveSecondary: Color = {
                    let c = UIColor(state.navBarGradientSecondaryColor)
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    c.getRed(&r, green: &g, blue: &b, alpha: &a)
                    let isDefault = abs(Double(r) - 0.96) < 0.01 && abs(Double(g) - 0.96) < 0.01 && abs(Double(b) - 0.97) < 0.01
                    return isDefault ? Color(UIColor.secondarySystemBackground) : state.navBarGradientSecondaryColor
                }()
                LinearGradient(
                    colors: [effectiveNavBarBgColor, effectiveSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                effectiveNavBarBgColor
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
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    ContentView()
        .environment(ModuleRegistry.shared)
        .environment(ModuleState.shared)
}
