////
////  ModuleNavBar.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UIKit

/// Dynamic navbar that displays registered modules and handles selection/settings.
/// Updates automatically as modules are registered or visibility changes.
public struct ModuleNavBar: View {
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    @Environment(\.colorScheme) var colorScheme

    let position: NavBarPosition
    
    public init(position: NavBarPosition = .bottom) {
        self.position = position
    }
    
    private var modulesToShow: [AnyAppModule] {
        let moduleList = position == .top ? state.topNavBarModules : state.bottomNavBarModules
        return moduleList.compactMap { id in
            registry.visibleModules.first { $0.id == id }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Module Buttons
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(modulesToShow) { module in
                            ModuleNavButton(
                                module: module,
                                isSelected: state.selectedModuleID == module.id,
                                textColor: effectiveNavBarTextColor
                            ) {
                                state.selectModule(module.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    // Expand to at least the full width so items center when
                    // they fit; scrolls normally when they overflow.
                    .frame(minWidth: geo.size.width)
                }
            }
            .frame(height: 60)
            .background(navBarBackground)
        }
    }

    /// True when the user has not saved a custom navbar background color (stored color matches default near-white).
    private var isDefaultNavBarColor: Bool {
        let c = UIColor(state.navBarBackgroundColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return abs(Double(r) - 0.98) < 0.01 && abs(Double(g) - 0.98) < 0.01 && abs(Double(b) - 1.0) < 0.01
    }

    /// The effective background color: uses a semantic system color for the default so it adapts to dark mode.
    private var effectiveNavBarBgColor: Color {
        isDefaultNavBarColor ? Color(UIColor.systemBackground) : state.navBarBackgroundColor
    }

    /// True when the user has not saved a custom navbar text color (stored color matches default black).
    private var isDefaultNavBarTextColor: Bool {
        let c = UIColor(state.navBarTextColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return abs(Double(r)) < 0.01 && abs(Double(g)) < 0.01 && abs(Double(b)) < 0.01
    }

    /// The effective text/icon color: uses `.primary` for the default so it adapts (white in dark mode).
    private var effectiveNavBarTextColor: Color {
        isDefaultNavBarTextColor ? Color.primary : state.navBarTextColor
    }

    private var navBarBackground: some View {
        Group {
            if state.navBarUseGradient {
                let effectiveSecondary: Color = {
                    let c = UIColor(state.navBarGradientSecondaryColor)
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    c.getRed(&r, green: &g, blue: &b, alpha: &a)
                    let isDefaultSecondary = abs(Double(r) - 0.96) < 0.01 && abs(Double(g) - 0.96) < 0.01 && abs(Double(b) - 0.97) < 0.01
                    return isDefaultSecondary ? Color(UIColor.secondarySystemBackground) : state.navBarGradientSecondaryColor
                }()
                // For vertical gradient on the bottom bar, reverse the colors so
                // primary→secondary flows top-to-bottom on the top bar, and
                // secondary→primary flows top-to-bottom on the bottom bar.
                // This makes both bars feel like one continuous gradient sweep.
                let isReversed = state.navBarGradientDirection == .vertical && position == .bottom
                LinearGradient(
                    colors: isReversed
                        ? [effectiveSecondary, effectiveNavBarBgColor]
                        : [effectiveNavBarBgColor, effectiveSecondary],
                    startPoint: state.navBarGradientDirection.startPoint,
                    endPoint: state.navBarGradientDirection.endPoint
                )
            } else {
                effectiveNavBarBgColor
            }
        }
    }
}

// MARK: - Module Nav Button

private struct ModuleNavButton: View {
    let module: AnyAppModule
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: module.iconName)
                    .font(.system(size: 16, weight: .semibold))

                Text(module.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 60, height: 52)
            .foregroundColor(isSelected ? textColor : textColor.opacity(0.6))
        }
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textColor, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(textColor.opacity(0.08))
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: isSelected)
    }
}

// MARK: - Border Extension

extension View {
    fileprivate func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(
            VStack(spacing: 0) {
                ForEach(edges, id: \.self) { edge in
                    switch edge {
                    case .top:
                        Rectangle().frame(height: width)
                    case .bottom:
                        Spacer()
                        Rectangle().frame(height: width)
                    case .leading:
                        Rectangle().frame(width: width)
                    case .trailing:
                        Rectangle().frame(width: width)
                    }
                }
            }
            .foregroundColor(color),
            alignment: .topLeading
        )
    }
}

#Preview {
    @Previewable @State var registry = ModuleRegistry.shared
    @Previewable @State var state = ModuleState.shared
    
    ModuleNavBar()
        .environment(registry)
        .environment(state)
}
