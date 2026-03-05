import SwiftUI

/// View for customizing stick figure appearance colors and muscle development
struct StickFigureAppearanceView: View {
    @State private var appearance = StickFigureAppearance.shared
    @State private var muscleSystem = MuscleSystem.shared
    @State private var gameState: StickFigureGameState?
    @State private var colorSectionExpanded = false
    @State private var musclesSectionExpanded = true  // Can be minimized
    @Environment(\.dismiss) var dismiss
    var onDismiss: (() -> Void)?  // Callback when appearance changes are complete
    
    @State private var refreshTrigger = UUID()  // Force refresh when muscles change
    
    init(gameState: StickFigureGameState? = nil, onDismiss: (() -> Void)? = nil) {
        _gameState = State(initialValue: gameState)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Customization")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        // Call callback before dismissing so game can update immediately
                        onDismiss?()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color(red: 0.95, green: 0.95, blue: 0.98))
                .border(Color.gray.opacity(0.3), width: 1)
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 12) {
                        // MARK: - Color Section (Minimized by default)
                        DisclosureGroup(
                            isExpanded: $colorSectionExpanded,
                            content: {
                                VStack(spacing: 12) {
                                    // Head
                                    ColorPickerRow(label: "Head", color: $appearance.headColor)
                                    
                                    // Torso
                                    ColorPickerRow(label: "Torso", color: $appearance.torsoColor)
                                    
                                    Divider()
                                    
                                    // Arms
                                    Text("Arms").font(.caption).fontWeight(.semibold).padding(.top, 4)
                                    HStack(spacing: 8) {
                                        VStack(spacing: 6) {
                                            Text("L Upper").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.leftUpperArmColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("R Upper").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.rightUpperArmColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("L Lower").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.leftLowerArmColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("R Lower").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.rightLowerArmColor).labelsHidden()
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Legs
                                    Text("Legs").font(.caption).fontWeight(.semibold).padding(.top, 4)
                                    HStack(spacing: 8) {
                                        VStack(spacing: 6) {
                                            Text("L Upper").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.leftUpperLegColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("R Upper").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.rightUpperLegColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("L Lower").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.leftLowerLegColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("R Lower").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.rightLowerLegColor).labelsHidden()
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Accessories
                                    Text("Accessories").font(.caption).fontWeight(.semibold).padding(.top, 4)
                                    HStack(spacing: 8) {
                                        VStack(spacing: 6) {
                                            Text("Hands").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.handColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("Feet").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.footColor).labelsHidden()
                                        }
                                        VStack(spacing: 6) {
                                            Text("Joints").font(.caption2).foregroundColor(.gray)
                                            ColorPicker("", selection: $appearance.jointColor).labelsHidden()
                                        }
                                        Spacer()
                                    }
                                    
                                    Divider()
                                    
                                    // Reset button
                                    Button(action: { appearance.resetToDefaults() }) {
                                        Text("Reset Colors")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(8)
                                            .background(Color.red.opacity(0.7))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(12)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            },
                            label: {
                                HStack {
                                    Image(systemName: "paintpalette.fill")
                                        .foregroundColor(.blue)
                                    Text("Colors")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        
                        // MARK: - Points Section (Maximized by default)
                        DisclosureGroup(
                            isExpanded: $musclesSectionExpanded,
                            content: {
                                VStack(spacing: 10) {
                                    Text("(0 = Extra Small, 25 = Small, 50 = Stand, 75 = Large, 100 = Extra Large)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, 8)
                                    
                                    ForEach(muscleSystem.config?.muscles ?? [], id: \.id) { muscle in
                                        HStack(spacing: 8) {
                                            Text(muscle.name)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .frame(maxWidth: 80, alignment: .leading)
                                            
                                            Spacer()
                                            
                                            // Minus 5 button
                                            Button(action: {
                                                if let gameState = gameState {
                                                    gameState.muscleState.addPoints(-5, to: muscle.id)
                                                    gameState.saveMuscleState()
                                                    refreshTrigger = UUID()
                                                }
                                            }) {
                                                Text("-5")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .frame(width: 28, height: 24)
                                                    .background(Color.red.opacity(0.7))
                                                    .cornerRadius(4)
                                            }
                                            
                                            // Minus 1 button
                                            Button(action: {
                                                if let gameState = gameState {
                                                    gameState.muscleState.addPoints(-1, to: muscle.id)
                                                    gameState.saveMuscleState()
                                                    refreshTrigger = UUID()
                                                }
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.red)
                                            }
                                            
                                            // Points display
                                            Text("\(Int(gameState?.muscleState.getPoints(for: muscle.id) ?? 0))")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .frame(width: 35, alignment: .center)
                                            
                                            // Plus 1 button
                                            Button(action: {
                                                if let gameState = gameState {
                                                    gameState.muscleState.addPoints(1, to: muscle.id)
                                                    gameState.saveMuscleState()
                                                    refreshTrigger = UUID()
                                                }
                                            }) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.green)
                                            }
                                            
                                            // Plus 5 button
                                            Button(action: {
                                                if let gameState = gameState {
                                                    gameState.muscleState.addPoints(5, to: muscle.id)
                                                    gameState.saveMuscleState()
                                                    refreshTrigger = UUID()
                                                }
                                            }) {
                                                Text("+5")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .frame(width: 28, height: 24)
                                                    .background(Color.green.opacity(0.7))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    
                                    Divider()
                                        .padding(.vertical, 8)
                                    
                                    // Quick action buttons
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            if let gameState = gameState {
                                                // Reset all muscles to 0
                                                if let muscles = muscleSystem.config?.muscles {
                                                    for muscle in muscles {
                                                        gameState.muscleState.setPoints(0, for: muscle.id)
                                                    }
                                                    gameState.saveMuscleState()
                                                    refreshTrigger = UUID()
                                                }
                                            }
                                        }) {
                                            Text("Reset All")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(6)
                                                .background(Color.orange.opacity(0.7))
                                                .cornerRadius(4)
                                        }
                                        
                                        Button(action: {
                                            if let gameState = gameState {
                                                // Max all muscles to 100
                                                if let muscles = muscleSystem.config?.muscles {
                                                    for muscle in muscles {
                                                        gameState.muscleState.setPoints(100, for: muscle.id)
                                                    }
                                                    gameState.saveMuscleState()
                                                    refreshTrigger = UUID()
                                                }
                                            }
                                        }) {
                                            Text("Max All")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(6)
                                                .background(Color.green.opacity(0.7))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .id(refreshTrigger)  // Force re-render when muscles change
                            },
                            label: {
                                HStack {
                                    Image(systemName: "figure.stand")
                                        .foregroundColor(.green)
                                    Text("Muscles")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

/// Helper view for a single color picker row
struct ColorPickerRow: View {
    let label: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
            
            Spacer()
            
            ColorPicker("", selection: $color)
                .labelsHidden()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    StickFigureAppearanceView()
}
