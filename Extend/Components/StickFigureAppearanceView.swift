import SwiftUI

/// View for customizing stick figure appearance colors
struct StickFigureAppearanceView: View {
    @State private var appearance = StickFigureAppearance.shared
    @Environment(\.dismiss) var dismiss
    var onDismiss: (() -> Void)?  // Callback when appearance changes are complete
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Appearance")
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
                    VStack(spacing: 16) {
                        // Head
                        ColorPickerRow(
                            label: "Head",
                            color: $appearance.headColor
                        )
                        
                        // Torso
                        ColorPickerRow(
                            label: "Torso",
                            color: $appearance.torsoColor
                        )
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Arms Section
                        Text("Arms")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            VStack(spacing: 8) {
                                Text("Left Upper")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.leftUpperArmColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Right Upper")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.rightUpperArmColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Left Lower")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.leftLowerArmColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Right Lower")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.rightLowerArmColor)
                                    .labelsHidden()
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Legs Section
                        Text("Legs")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            VStack(spacing: 8) {
                                Text("Left Upper")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.leftUpperLegColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Right Upper")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.rightUpperLegColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Left Lower")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.leftLowerLegColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Right Lower")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.rightLowerLegColor)
                                    .labelsHidden()
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Accessories
                        Text("Accessories")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            VStack(spacing: 8) {
                                Text("Hands")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.handColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Feet")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.footColor)
                                    .labelsHidden()
                            }
                            
                            VStack(spacing: 8) {
                                Text("Joints")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                ColorPicker("", selection: $appearance.jointColor)
                                    .labelsHidden()
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Reset button
                        Button(action: {
                            appearance.resetToDefaults()
                        }) {
                            Text("Reset to Defaults")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
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
