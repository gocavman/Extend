////
////  WelcomeTourModule.swift
////  Extend
////
////  Welcome modal shown on first launch / after reset, with optional
////  coach-mark spotlight tour of the main UI regions.
////

import SwiftUI

// MARK: - Anchor preference key for frame detection

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourStop: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourStop: Anchor<CGRect>], nextValue: () -> [TourStop: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Tour stops

enum TourStop: String, CaseIterable {
    case bottomNavBar
    case topNavBar
    case settingsGear
    case dashboardBody

    var title: String {
        switch self {
        case .bottomNavBar:  return "Main Navigation"
        case .topNavBar:     return "Secondary Navigation"
        case .settingsGear:  return "Settings"
        case .dashboardBody: return "Dashboard"
        }
    }

    var description: String {
        switch self {
        case .bottomNavBar:
            return "Your primary modules live here — Dashboard, Workout, Exercises, Planner, and Logs. Fully customizable in Settings."
        case .topNavBar:
            return "Extra modules like Voice Trainer, Generate Workout, Timer, Muscles, and Equipment live up here. Fully customizable in Settings."
        case .settingsGear:
            return "Tap the gear to open Settings, where you can change the theme, rearrange navigation bars, customize the dashboard, manage HealthKit sync, and more."
        case .dashboardBody:
            return "Your dashboard is pre-loaded with tiles. Scroll through and quickly access the most important data. Rearrange, and swap them out in Settings. You can also add shortcuts to run favorite workouts and exercises."
        }
    }
}

// MARK: - Welcome Modal

struct WelcomeModal: View {
    @Binding var isPresented: Bool
    @Binding var showTour: Bool
    @Binding var showHelp: Bool
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @State private var dontShowAgain: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Icon + Title
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.primary)
                .padding(.bottom, 12)

            Text("Welcome to Extend")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 2) {
                Text("Your personal workout tracker.")
                    .font(.subheadline)
                //Text("")
                    //.font(.caption)
                    //.italic()
                //Text("Just tracking. As it should be.")
                    //.font(.subheadline)
            }
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 6)
            .padding(.horizontal, 24)

            Divider()
                .padding(.vertical, 24)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    if dontShowAgain { hasSeenWelcome = true }
                    isPresented = false
                    showTour = true
                }) {
                    HStack {
                        Image(systemName: "map")
                        Text("Take a Tour")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                }

                Button(action: {
                    if dontShowAgain { hasSeenWelcome = true }
                    isPresented = false
                    showHelp = true
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("View Help")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemFill))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                Button(action: {
                    if dontShowAgain { hasSeenWelcome = true }
                    isPresented = false
                }) {
                    Text("Dismiss — Jump Right In")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)

            // "Don't show again" checkbox
            Button(action: { dontShowAgain.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                        .foregroundColor(dontShowAgain ? .primary : .secondary)
                    Text("Don't show this again")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
        .padding(.horizontal, 24)
        .frame(maxWidth: 400)
    }
}

// MARK: - Tour Overlay

struct TourOverlay: View {
    @Binding var isPresented: Bool
    let anchorRects: [TourStop: CGRect]
    /// Called when the tour finishes via "Done" — used to re-show the welcome modal.
    var onDone: (() -> Void)? = nil

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @State private var currentStopIndex: Int = 0

    private var stops: [TourStop] { TourStop.allCases }
    private var currentStop: TourStop { stops[currentStopIndex] }
    private var isLastStop: Bool { currentStopIndex == stops.count - 1 }

    var body: some View {
        // Both this GeometryReader and the one in ContentView's overlayPreferenceValue
        // use ignoresSafeArea, so they share the same full-screen coordinate space.
        // The anchor rects are therefore directly usable without any safe-area offset.
        GeometryReader { geo in
            let screenH = geo.size.height   // full screen height (safe areas included)
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom

            let hlRect: CGRect = {
                if let rect = anchorRects[currentStop] {
                    if currentStop == .dashboardBody {
                        // Derive rect from screen geometry — more reliable than the VStack bounds.
                        let topY = rect.minY + 10
                        let bottomNavBarTop = screenH - safeBottom - 70   // ~70pt navbar height
                        let clampedBottom = min(rect.maxY, bottomNavBarTop) - 10
                        return CGRect(x: 0, y: topY,
                                      width: geo.size.width, height: max(clampedBottom - topY, 80))
                    } else {
                        return rect.insetBy(dx: -8, dy: -8)
                    }
                }
                // Fallback: centre strip
                return CGRect(x: 0, y: screenH * 0.4, width: geo.size.width, height: screenH * 0.2)
            }()

            // For the dashboard stop, centre the card inside the large highlight region.
            // For all other stops, place the card in whichever half has more room.
            let centerInHighlight = currentStop == .dashboardBody
            let placeAbove = !centerInHighlight && (hlRect.midY > screenH / 2)

            ZStack(alignment: .topLeading) {
                // Dimmed backdrop
                DimmedCutoutView(
                    highlightRect: hlRect,
                    cornerRadius: currentStop == .settingsGear ? 20 : 12
                )
                .ignoresSafeArea()

                // Inner shadow around the cutout edge so it stands out against light content
                CutoutShadowView(
                    highlightRect: hlRect,
                    cornerRadius: currentStop == .settingsGear ? 20 : 12
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Snap-in highlight border
                SnapInBorderView(rect: hlRect, cornerRadius: currentStop == .settingsGear ? 20 : 12)
                    .id(currentStopIndex)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Callout card
                if centerInHighlight {
                    // Dashboard: float the card in the vertical middle of the highlight
                    calloutCard
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, hlRect.minY + (hlRect.height - 180) / 2)
                } else if placeAbove {
                    // Card sits between safe-area top and the highlight top
                    calloutCard
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(
                            height: max(hlRect.minY - safeTop - 24, 60),
                            alignment: .bottom
                        )
                        .padding(.top, safeTop + 8)
                } else {
                    // Card sits between the highlight bottom and safe-area bottom
                    calloutCard
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(
                            height: max(screenH - safeBottom - hlRect.maxY - 24, 60),
                            alignment: .top
                        )
                        .padding(.top, hlRect.maxY + 12)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: currentStopIndex)
        }
        .ignoresSafeArea()
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentStop.title)
                .font(.headline)
                .fontWeight(.bold)

            Text(currentStop.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                HStack(spacing: 6) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { idx, _ in
                        Circle()
                            .fill(idx == currentStopIndex ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                Button(action: {
                    if isLastStop {
                        isPresented = false
                        // Re-show the welcome modal unless the user ticked "don't show again"
                        if !hasSeenWelcome {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onDone?()
                            }
                        }
                    } else {
                        withAnimation { currentStopIndex += 1 }
                    }
                }) {
                    Text(isLastStop ? "Done" : "Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.primary)
                        .cornerRadius(20)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Cutout shadow

/// Draws a soft dark shadow just inside the cutout edge so the highlighted
/// area stands out against light-coloured content behind it.
private struct CutoutShadowView: View {
    let highlightRect: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(Color.black.opacity(0.35), lineWidth: 6)
            .blur(radius: 6)
            .frame(width: highlightRect.width, height: highlightRect.height)
            .position(x: highlightRect.midX, y: highlightRect.midY)
    }
}

// MARK: - Snap-in border

/// A CAShapeLayer-based border that snaps in around the highlight on each stop.
/// Drawn directly on a full-screen UIView so coordinate positioning is exact.
private struct SnapInBorderView: UIViewRepresentable {
    let rect: CGRect
    let cornerRadius: CGFloat

    func makeUIView(context: Context) -> SnapInBorderUIView {
        let view = SnapInBorderUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.configure(rect: rect, cornerRadius: cornerRadius)
        return view
    }

    func updateUIView(_ uiView: SnapInBorderUIView, context: Context) {}
}

final class SnapInBorderUIView: UIView {
    private let borderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        borderLayer.lineWidth = 3
        layer.addSublayer(borderLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(rect: CGRect, cornerRadius: CGFloat) {
        // Start 20% larger
        let scale: CGFloat = 1.2
        let startRect = rect.insetBy(
            dx: -(rect.width * (scale - 1) / 2),
            dy: -(rect.height * (scale - 1) / 2)
        )
        borderLayer.path = UIBezierPath(roundedRect: startRect, cornerRadius: cornerRadius * scale).cgPath
        borderLayer.opacity = 0

        // Animate to exact rect with a spring feel using CABasicAnimation + CASpringAnimation
        let pathAnim = CASpringAnimation(keyPath: "path")
        pathAnim.fromValue = borderLayer.path
        pathAnim.toValue = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        pathAnim.mass = 1
        pathAnim.stiffness = 180
        pathAnim.damping = 18
        pathAnim.initialVelocity = 0
        pathAnim.duration = pathAnim.settlingDuration
        pathAnim.fillMode = .forwards
        pathAnim.isRemovedOnCompletion = false

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0
        opacityAnim.toValue = 1
        opacityAnim.duration = 0.15
        opacityAnim.fillMode = .forwards
        opacityAnim.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        borderLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        borderLayer.opacity = 1
        CATransaction.commit()

        borderLayer.add(pathAnim, forKey: "snapPath")
        borderLayer.add(opacityAnim, forKey: "fadeIn")
    }
}

// MARK: - Dimmed cutout shape

private struct DimmedCutoutView: View {
    let highlightRect: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        Color.black.opacity(0.82)
            .mask(
                CutoutShape(rect: highlightRect, cornerRadius: cornerRadius)
                    .fill(style: FillStyle(eoFill: true))
            )
    }
}

private struct CutoutShape: Shape {
    let rect: CGRect
    let cornerRadius: CGFloat

    func path(in bounds: CGRect) -> Path {
        var path = Path()
        // Outer rectangle (full screen)
        path.addRect(bounds)
        // Inner rounded rectangle (cutout)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

// MARK: - Anchor tag modifier

extension View {
    /// Tag this view so the tour overlay can capture its frame.
    func tourAnchor(_ stop: TourStop) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [stop: $0] }
    }
}
