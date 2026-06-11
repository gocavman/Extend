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

    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false

    @State private var showWelcome: Bool = false
    @State private var showTour: Bool = false
    @State private var showHelpFromWelcome: Bool = false
    @State private var tourAnchorRects: [TourStop: CGRect] = [:]

    private var preferredScheme: ColorScheme? {
        switch appColorScheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil  // "system" — follow iOS setting
        }
    }

    var body: some View {
        let hasTopModules = !state.topNavBarModules.isEmpty
        let selectedModule = state.selectedModuleID.flatMap { registry.moduleWithID($0) }
        let shouldHideNavBars = selectedModule?.hidesNavBars ?? false

        // Single stable VStack — no branch switching, so SwiftUI never tears down
        // the view tree when top/bottom navbar membership changes.
        ZStack {
            VStack(spacing: 0) {
                if hasTopModules && !shouldHideNavBars {
                    // height:0 + ignoresSafeArea lets the background bleed into the
                    // top safe area without taking up any layout space.
                    topSafeAreaFill
                        .ignoresSafeArea(edges: .top)
                        .frame(height: 0)

                    ModuleNavBar(position: .top)
                        .tourAnchor(.topNavBar)
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
                        .tourAnchor(.bottomNavBar)

                    // Same trick for the bottom safe area.
                    bottomSafeAreaFill
                        .ignoresSafeArea(edges: .bottom)
                        .frame(height: 0)
                }
            }

            // Welcome modal — centered card
            if showWelcome {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                WelcomeModal(isPresented: $showWelcome, showTour: $showTour, showHelp: $showHelpFromWelcome)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        // Resolve all tour anchors at the ZStack level — the common ancestor of all tagged views.
        // The GeometryProxy here shares the same coordinate space as the anchored views.
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            // Use ignoresSafeArea so this GeometryReader shares the same full-screen
            // coordinate space as TourOverlay's GeometryReader (which also ignores safe area).
            GeometryReader { geo in
                Color.clear
                    .onChange(of: anchors.count) { _, _ in
                        tourAnchorRects = anchors.reduce(into: [:]) { $0[$1.key] = geo[$1.value] }
                    }
                    .onAppear {
                        tourAnchorRects = anchors.reduce(into: [:]) { $0[$1.key] = geo[$1.value] }
                    }
            }
            .ignoresSafeArea()
        }
        // Tour overlay rendered after preference resolution, on top of everything
        .overlay {
            if showTour {
                TourOverlay(isPresented: $showTour, anchorRects: tourAnchorRects) {
                    withAnimation { showWelcome = true }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showWelcome)
        .animation(.easeInOut(duration: 0.25), value: showTour)
        .preferredColorScheme(preferredScheme)
        .fullScreenCover(isPresented: $showHelpFromWelcome) {
            NavigationStack {
                HelpView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showHelpFromWelcome = false }
                        }
                    }
            }
        }
        .onAppear {
            if !hasSeenWelcome {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { showWelcome = true }
                }
            }
        }
        .onChange(of: hasSeenWelcome) { _, newValue in
            // Re-show the modal when reset clears this flag back to false
            if !newValue && !showWelcome {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { showWelcome = true }
                }
            }
        }
    }

    // MARK: - Helpers

    private var isDefaultNavBarColor: Bool {
        let c = UIColor(state.navBarBackgroundColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return abs(Double(r) - 0.98) < 0.01 && abs(Double(g) - 0.98) < 0.01 && abs(Double(b) - 1.0) < 0.01
    }

    private var effectiveNavBarBgColor: Color {
        isDefaultNavBarColor ? Color(UIColor.systemBackground) : state.navBarBackgroundColor
    }

    private var effectiveSecondaryColor: Color {
        let c = UIColor(state.navBarGradientSecondaryColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let isDefault = abs(Double(r) - 0.96) < 0.01 && abs(Double(g) - 0.96) < 0.01 && abs(Double(b) - 0.97) < 0.01
        return isDefault ? Color(UIColor.secondarySystemBackground) : state.navBarGradientSecondaryColor
    }

    /// Fill for the top safe area (above the top navbar).
    /// For vertical gradient this should be solid colorA so the gradient appears
    /// to start at the very top of the screen.
    /// For horizontal gradient it matches the navbar gradient seamlessly.
    /// For no gradient it's just the flat bg color.
    private var topSafeAreaFill: some View {
        Group {
            if state.navBarUseGradient {
                switch state.navBarGradientDirection {
                case .horizontal:
                    LinearGradient(
                        colors: [effectiveNavBarBgColor, effectiveSecondaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                case .vertical:
                    // Safe area is above the bar — hold solid colorA (the start color).
                    effectiveNavBarBgColor
                }
            } else {
                effectiveNavBarBgColor
            }
        }
    }

    /// Fill for the bottom safe area (below the bottom navbar).
    /// For vertical gradient this should be solid colorB so the gradient appears
    /// to end at the very bottom of the screen.
    private var bottomSafeAreaFill: some View {
        Group {
            if state.navBarUseGradient {
                switch state.navBarGradientDirection {
                case .horizontal:
                    LinearGradient(
                        colors: [effectiveNavBarBgColor, effectiveSecondaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                case .vertical:
                    // Bottom bar is reversed (secondary→primary), so the very bottom
                    // edge is colorA (primary). Hold that solid so it blends seamlessly.
                    effectiveNavBarBgColor
                }
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
