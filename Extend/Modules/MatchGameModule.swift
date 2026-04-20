////
////  MatchGameModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 4/20/26.
////

import SwiftUI
import UIKit

public struct MatchGameModule: AppModule {
    public let id: UUID = ModuleIDs.matchGame
    public let displayName: String = "Workout Match"
    public let iconName: String = "square.grid.2x2.fill"
    public let description: String = "Match challenge game"

    public var order: Int = 0
    public var isVisible: Bool = true
    public var hidesNavBars: Bool { true }

    public var moduleView: AnyView {
        let view = MatchGameModuleView(module: self)
        return AnyView(view)
    }
}

// MARK: - Match Game Module View

private struct MatchGameModuleView: UIViewControllerRepresentable {
    let module: MatchGameModule

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = MatchGameViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}
