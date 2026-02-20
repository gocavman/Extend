////
////  StickFigureAnimatorModule.swift
////  Extend
////
////  Created by AI Assistant on 2/20/26.
////

import SwiftUI

/// Stick Figure Animator module for creating custom animations
public struct StickFigureAnimatorModule: AppModule {
    public let id: UUID = ModuleIDs.stickFigureAnimator
    public let displayName: String = "Animator"
    public let iconName: String = "figure.stand"
    public let description: String = "Create custom stick figure animations"
    
    public var order: Int = 100
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(StickFigureAnimatorModuleView())
    }
}

// MARK: - Stick Figure Animator View

private struct StickFigureAnimatorModuleView: View {
    @State private var clothing = ClothingStyle.load()
    @State private var showAnimationEditor = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Animation Creator")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                
                List {
                    Button(action: { showAnimationEditor = true }) {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Create New Animation")
                                    .font(.headline)
                                Text("Design custom stick figure poses")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                
                Spacer()
            }
            .navigationTitle("Stick Figure Animator")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAnimationEditor) {
                DraggableJointEditorView(clothing: $clothing)
            }
        }
    }
}

#Preview {
    StickFigureAnimatorModuleView()
}
