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
    
    let position: NavBarPosition
    
    public init(position: NavBarPosition = .bottom) {
        self.position = position
    }
    
    private var modulesToShow: [AnyAppModule] {
        let moduleList = position == .top ? state.topNavBarModules : state.bottomNavBarModules
        if moduleList.isEmpty {
            // If no preference set, show all visible modules
            return registry.visibleModules
        }
        return moduleList.compactMap { id in
            registry.visibleModules.first { $0.id == id }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Module Buttons
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(modulesToShow) { module in
                            ModuleNavButton(
                                module: module,
                                isSelected: state.selectedModuleID == module.id
                            ) {
                                state.selectModule(module.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: 60)
            .background(Color(red: 0.98, green: 0.98, blue: 1.0))
            .border(width: 1, edges: [.bottom], color: Color(red: 0.92, green: 0.92, blue: 0.93))
        }
    }
}

// MARK: - Module Nav Button

private struct ModuleNavButton: View {
    let module: AnyAppModule
    let isSelected: Bool
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
            .foregroundColor(isSelected ? .black : .gray)
        }
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.08))
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
