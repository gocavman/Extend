import SwiftUI
import UIKit

/// Stick Figure Animator module — opens the editor directly on launch.
public struct StickFigureAnimatorModule: AppModule {
    public let id: UUID = ModuleIDs.stickFigureAnimator
    public let displayName: String = "Animator"
    public let iconName: String = "figure.stand"
    public let description: String = "Create custom stick figure animations"

    public var order: Int = 100
    public var isVisible: Bool = true
    public var hidesNavBars: Bool { true }

    public var moduleView: AnyView {
        AnyView(StickFigureAnimatorModuleView())
    }
}

// MARK: - Module View

private struct StickFigureAnimatorModuleView: View {
    @Environment(ModuleState.self) private var moduleState

    var body: some View {
        StickFigureEditorWrapper(onClose: {
            moduleState.selectModule(ModuleIDs.dashboard)
        })
        .ignoresSafeArea()
        .navigationBarHidden(true)
    }
}

// MARK: - UIViewControllerRepresentable wrapper

private struct StickFigureEditorWrapper: UIViewControllerRepresentable {
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> StickFigureGameplayEditorViewController {
        let vc = StickFigureGameplayEditorViewController()
        vc.gameState = nil  // standalone animator — no gameplay state
        vc.onDismiss = onClose
        return vc
    }

    func updateUIViewController(_ uiViewController: StickFigureGameplayEditorViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {}
}

#Preview {
    StickFigureAnimatorModuleView()
}
