////
////  ModuleSettingsView.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI

/// Settings view for managing module visibility, ordering, and configuration.
/// iOS-only component.
@available(iOS 16.0, *)
public struct ModuleSettingsView: View {
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("Module Settings")
                        .font(.headline)
                    
                    Text("Customize your modules and order")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(24)
                
                Divider()
                
                // Settings List
                List {
                    // MARK: - App Settings Section
                    Section("App Settings") {
                        Picker("NavBar Position", selection: .init(
                            get: { state.navBarPosition },
                            set: { state.navBarPosition = $0 }
                        )) {
                            ForEach(NavBarPosition.allCases, id: \.self) { position in
                                Text(position.rawValue).tag(position)
                            }
                        }
                    }
                    
                    // MARK: - Modules Section
                    Section("Modules") {
                        ForEach(registry.registeredModules, id: \.id) { module in
                            ModuleSettingRow(
                                module: module,
                                onVisibilityChange: { isVisible in
                                    registry.setModuleVisibility(id: module.id, isVisible: isVisible)
                                },
                                onMoveUp: {
                                    registry.moveModule(id: module.id, direction: .up)
                                },
                                onMoveDown: {
                                    registry.moveModule(id: module.id, direction: .down)
                                }
                            )
                        }
                    }
                    .headerProminence(.increased)
                }
                .listStyle(.plain)
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Settings sheet is no longer used
                    }
                    .fontWeight(.semibold)
                }
            }
            #endif
        }
    }
}

// MARK: - Module Setting Row

@available(iOS 16.0, *)
private struct ModuleSettingRow: View {
    let module: AnyAppModule
    let onVisibilityChange: (Bool) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: module.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                // Module Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(module.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Visibility Toggle
                Toggle("", isOn: .init(
                    get: { module.isVisible },
                    set: { onVisibilityChange($0) }
                ))
            }
            
            // Order Controls
            HStack(spacing: 8) {
                Button(action: onMoveUp) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                        Text("Up")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
                
                Button(action: onMoveDown) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                        Text("Down")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let registry = ModuleRegistry.shared
    let state = ModuleState.shared
    
    return ModuleSettingsView()
        .environment(registry)
        .environment(state)
        .onAppear {
            registry.clearAllModules()
            registry.registerModule(WorkoutModule())
            registry.registerModule(TimerModule())
            registry.registerModule(ProgressModule())
        }
}
