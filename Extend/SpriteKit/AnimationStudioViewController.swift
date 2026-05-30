import UIKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers
import SwiftUI

// MARK: - AnimationStudioViewController

/// Full-screen Animation Studio — pick saved frames, play them as a walking animation, export GIF.
class AnimationStudioViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - UI
    private let previewView = SKView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var previewScene: AnimationStageScene?
    private var headerTopView: UIView?
    private var controlBarView: UIView?

    // Weak refs for live control bar updates
    private weak var delayValueLabel: UILabel?
    private weak var playStopButton: UIButton?
    private weak var loopToggle: UISwitch?
    private weak var sequenceLabel: UILabel?

    // MARK: - Data model

    /// A named group of frames (e.g. all "Stand" frames)
    private struct FrameGroup {
        let name: String
        let indices: [Int]
    }

    private var allFrames: [SavedEditFrame] = []
    private var groups: [FrameGroup] = []

    // MARK: - Animation state
    private var sequenceItems: [(frameIndex: Int, label: String)] = []
    private var frameDelay: Double = 0.25
    private var loopEnabled: Bool = true
    private var isPlaying: Bool = false

    // MARK: - Section layout
    // Section 0        — ANIMATION SEQUENCE (1 auto-height row)
    // Sections 1…G     — one section per FrameGroup
    private var numGroups: Int { groups.count }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        allFrames = SavedFramesManager.shared.getAllFrames()
            .sorted { $0.frameNumber < $1.frameNumber }
        buildGroups()

        setupHeader()
        setupControlBar()
        setupLayout()
        tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if previewScene == nil {
            setupScene()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }

    // MARK: - Setup

    private func buildGroups() {
        var seen: [String: Int] = [:]
        var result: [FrameGroup] = []
        for (i, frame) in allFrames.enumerated() {
            let key = frame.name.isEmpty ? "Unnamed" : frame.name
            if let g = seen[key] {
                result[g] = FrameGroup(name: result[g].name, indices: result[g].indices + [i])
            } else {
                seen[key] = result.count
                result.append(FrameGroup(name: key, indices: [i]))
            }
        }
        groups = result
    }

    private func setupHeader() {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.05, green: 0.2, blue: 0.05, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let titleLabel = UILabel()
        titleLabel.text = "ANIMATION STUDIO"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        self.headerTopView = headerView
    }

    /// Compact control bar sitting between the preview and the tableView.
    /// Row 1: ▶ Play/Stop  |  Export GIF  |  🔍- Zoom Out  |  🔍+ Zoom In
    /// Row 2: Speed: [slider] 0.25s   Loop [switch]
    private func setupControlBar() {
        guard let header = headerTopView else { return }

        let bar = UIView()
        bar.backgroundColor = UIColor.secondarySystemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        // Thin top separator
        let sep = UIView()
        sep.backgroundColor = UIColor.separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(sep)

        // --- Row 1: action buttons ---
        let playBtn = makeBarButton(title: "▶  Play", color: .systemGreen)
        playBtn.addTarget(self, action: #selector(playStopTapped), for: .touchUpInside)
        playStopButton = playBtn

        let exportBtn = makeBarButton(title: "GIF", color: .systemBlue)
        exportBtn.addTarget(self, action: #selector(exportGIFTapped), for: .touchUpInside)

        let zoomOutBtn = makeBarButton(title: "−", color: .systemOrange)
        zoomOutBtn.addTarget(self, action: #selector(zoomOutTapped), for: .touchUpInside)
        zoomOutBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)

        let zoomInBtn = makeBarButton(title: "+", color: .systemOrange)
        zoomInBtn.addTarget(self, action: #selector(zoomInTapped), for: .touchUpInside)
        zoomInBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)

        let btnStack = UIStackView(arrangedSubviews: [playBtn, exportBtn, zoomOutBtn, zoomInBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 8
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(btnStack)

        // --- Row 2: speed + loop ---
        let speedLabel = UILabel()
        speedLabel.text = "Speed"
        speedLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        speedLabel.translatesAutoresizingMaskIntoConstraints = false

        let valLabel = UILabel()
        valLabel.text = String(format: "%.2fs", frameDelay)
        valLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        valLabel.textColor = .secondaryLabel
        valLabel.translatesAutoresizingMaskIntoConstraints = false
        valLabel.setContentHuggingPriority(.required, for: .horizontal)
        delayValueLabel = valLabel

        let slider = UISlider()
        slider.minimumValue = 0.02
        slider.maximumValue = 1.0
        slider.value = Float(frameDelay)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addAction(UIAction { [weak self, weak valLabel] _ in
            let v = Double(slider.value)
            self?.frameDelay = v
            valLabel?.text = String(format: "%.2fs", v)
            if self?.isPlaying == true { self?.previewScene?.setFrameDelay(v) }
        }, for: .valueChanged)

        let loopLabel = UILabel()
        loopLabel.text = "Loop"
        loopLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        loopLabel.translatesAutoresizingMaskIntoConstraints = false

        let loopSw = UISwitch()
        loopSw.isOn = loopEnabled
        loopSw.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        loopSw.translatesAutoresizingMaskIntoConstraints = false
        loopSw.addAction(UIAction { [weak self] _ in
            self?.loopEnabled = loopSw.isOn
            self?.previewScene?.setLooping(loopSw.isOn)
        }, for: .valueChanged)
        loopToggle = loopSw

        let speedRow = UIStackView(arrangedSubviews: [speedLabel, slider, valLabel, loopLabel, loopSw])
        speedRow.axis = .horizontal
        speedRow.spacing = 6
        speedRow.alignment = .center
        speedRow.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(speedRow)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: bar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            btnStack.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 6),
            btnStack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            btnStack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            btnStack.heightAnchor.constraint(equalToConstant: 32),

            speedRow.topAnchor.constraint(equalTo: btnStack.bottomAnchor, constant: 5),
            speedRow.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            speedRow.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            speedRow.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -6)
        ])

        // Pin bar just below the header — previewView will be pinned below the bar in setupLayout
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: header.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        controlBarView = bar
    }

    private func makeBarButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = color.withAlphaComponent(0.12)
        btn.tintColor = color
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func setupLayout() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.backgroundColor = UIColor(red: 0.85, green: 0.92, blue: 0.85, alpha: 1.0)
        view.addSubview(previewView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        // Auto-sizing rows for the sequence cell
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)

        guard let bar = controlBarView else { return }

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: bar.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.33),

            tableView.topAnchor.constraint(equalTo: previewView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupScene() {
        let size = CGSize(width: previewView.bounds.width, height: previewView.bounds.height)
        guard size.width > 0, size.height > 0 else { return }
        let scene = AnimationStageScene(size: size)
        scene.scaleMode = .resizeFill
        previewScene = scene
        previewView.presentScene(scene)
        previewView.ignoresSiblingOrder = true

        if let standFrame = allFrames.first(where: { $0.name.lowercased() == "stand" && $0.frameNumber == 0 })
                         ?? allFrames.first(where: { $0.name.lowercased() == "stand" })
                         ?? allFrames.first {
            previewScene?.showStillFrame(standFrame)
        } else {
            previewScene?.showStillFigure(StickFigure2D())
        }
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + numGroups   // sequence + frame groups
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        let g = section - 1
        guard g >= 0, g < groups.count else { return 0 }
        return groups[g].indices.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "ANIMATION SEQUENCE" }
        let g = section - 1
        guard g >= 0, g < groups.count else { return nil }
        return groups[g].name.uppercased()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.selectionStyle = .none
        cell.accessoryType = .none

        if indexPath.section == 0 {
            buildSequenceCell(cell)
        } else {
            let g = indexPath.section - 1
            guard g >= 0, g < groups.count else { return cell }
            let frameIndex = groups[g].indices[indexPath.row]
            buildFramePickerCell(cell, frameIndex: frameIndex)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Sequence row is auto-sizing; frame rows are fixed
        return indexPath.section == 0 ? UITableView.automaticDimension : 46
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 60 : 46
    }

    // MARK: - Tap to add frame to sequence

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section > 0 else { return }
        let g = indexPath.section - 1
        guard g >= 0, g < groups.count else { return }
        let frameIndex = groups[g].indices[indexPath.row]
        let frame = allFrames[frameIndex]
        let label = frame.name.isEmpty
            ? "Frame \(frame.frameNumber)"
            : "\(frame.name) #\(frame.frameNumber)"
        sequenceItems.append((frameIndex: frameIndex, label: label))
        updateSequenceLabel()
        // Reload sequence cell and frame cell for badge update
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0), indexPath], with: .none)
        if !isPlaying {
            previewScene?.showStillFrame(frame)
        }
    }

    // MARK: - Cell Builders

    private func buildFramePickerCell(_ cell: UITableViewCell, frameIndex: Int) {
        let frame = allFrames[frameIndex]
        let count = sequenceItems.filter { $0.frameIndex == frameIndex }.count

        let label = UILabel()
        label.text = "Frame \(frame.frameNumber)"
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = count > 0 ? "×\(count)  +" : "+"
        badge.font = UIFont.monospacedSystemFont(ofSize: 13, weight: count > 0 ? .bold : .regular)
        badge.textColor = count > 0 ? .systemGreen : .tertiaryLabel
        badge.translatesAutoresizingMaskIntoConstraints = false
        cell.selectionStyle = .default

        cell.contentView.addSubview(label)
        cell.contentView.addSubview(badge)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -4),
            badge.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            badge.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
    }

    private func buildSequenceCell(_ cell: UITableViewCell) {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0          // unlimited — cell grows with content
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = sequenceItems.isEmpty
            ? "Tap frames below to build the sequence"
            : sequenceItems.map { $0.label }.joined(separator: " → ")
        sequenceLabel = label

        let backspaceBtn = UIButton(type: .system)
        backspaceBtn.setTitle("⌫", for: .normal)
        backspaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        backspaceBtn.tintColor = .systemRed
        backspaceBtn.translatesAutoresizingMaskIntoConstraints = false
        backspaceBtn.setContentHuggingPriority(.required, for: .horizontal)
        backspaceBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        backspaceBtn.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)

        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("Clear", for: .normal)
        clearBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.setContentHuggingPriority(.required, for: .horizontal)
        clearBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        clearBtn.addTarget(self, action: #selector(clearSequenceTapped), for: .touchUpInside)

        // Buttons sit in a vertical stack pinned to top-right so label can freely grow below
        let btnStack = UIStackView(arrangedSubviews: [clearBtn, backspaceBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 4
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(label)
        cell.contentView.addSubview(btnStack)
        NSLayoutConstraint.activate([
            btnStack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            btnStack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),

            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: btnStack.leadingAnchor, constant: -4),
            label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        stopPlayback()
        dismiss(animated: true)
    }

    @objc private func backspaceTapped() {
        guard !sequenceItems.isEmpty else { return }
        sequenceItems.removeLast()
        updateSequenceLabel()
        tableView.reloadData()
        if !isPlaying {
            if let last = sequenceItems.last {
                previewScene?.showStillFrame(allFrames[last.frameIndex])
            } else {
                showDefaultStill()
            }
        }
    }

    @objc private func clearSequenceTapped() {
        sequenceItems = []
        stopPlayback()
        tableView.reloadData()
        showDefaultStill()
    }

    @objc private func playStopTapped() {
        if isPlaying { stopPlayback() } else { startPlayback() }
    }

    @objc private func exportGIFTapped() {
        let frames = resolvedFrames()
        guard !frames.isEmpty else {
            showAlert(title: "No Frames", message: "Tap saved frames to build an animation sequence first.")
            return
        }
        exportGIF(frames: frames)
    }

    @objc private func zoomInTapped() {
        previewScene?.adjustZoom(by: 0.2)
    }

    @objc private func zoomOutTapped() {
        previewScene?.adjustZoom(by: -0.2)
    }

    // MARK: - Sequence helpers

    private func updateSequenceLabel() {
        if sequenceItems.isEmpty {
            sequenceLabel?.text = "Tap frames below to build the sequence"
        } else {
            sequenceLabel?.text = sequenceItems.map { $0.label }.joined(separator: " → ")
        }
        // Invalidate row height so the cell resizes
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    private func resolvedFrames() -> [SavedEditFrame] {
        sequenceItems.compactMap { item in
            guard item.frameIndex < allFrames.count else { return nil }
            return allFrames[item.frameIndex]
        }
    }

    private func showDefaultStill() {
        if let standFrame = allFrames.first(where: { $0.name.lowercased() == "stand" && $0.frameNumber == 0 }) {
            previewScene?.showStillFrame(standFrame)
        } else {
            previewScene?.showStillFigure(StickFigure2D())
        }
    }

    // MARK: - Playback

    private func startPlayback() {
        let frames = resolvedFrames()
        guard !frames.isEmpty else {
            showAlert(title: "No Sequence", message: "Tap saved frames to build an animation sequence first.")
            return
        }
        isPlaying = true
        playStopButton?.setTitle("⏹  Stop", for: .normal)
        playStopButton?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
        playStopButton?.tintColor = .systemRed
        previewScene?.startAnimation(frames: frames, delay: frameDelay, loop: loopEnabled)
    }

    private func stopPlayback() {
        isPlaying = false
        playStopButton?.setTitle("▶  Play", for: .normal)
        playStopButton?.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
        playStopButton?.tintColor = .systemGreen
        previewScene?.stopAnimation()
    }

    // MARK: - GIF Export

    private func exportGIF(frames: [SavedEditFrame]) {
        let canvasSize = CGSize(width: 512, height: 512)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("animation_\(Int(Date().timeIntervalSince1970)).gif")

        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            showAlert(title: "Export Failed", message: "Could not create GIF destination.")
            return
        }

        let loopCount = loopEnabled ? 0 : 1
        CGImageDestinationSetProperties(dest, [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: loopCount]
        ] as CFDictionary)

        let frameProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: frameDelay]
        ]
        for savedFrame in frames {
            if let cgImg = renderFrameToCGImage(savedFrame.toStickFigure2D(), size: canvasSize) {
                CGImageDestinationAddImage(dest, cgImg, frameProps as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(dest) else {
            showAlert(title: "Export Failed", message: "Could not finalize GIF.")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 60, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }

    private func renderFrameToCGImage(_ figure: StickFigure2D, size: CGSize) -> CGImage? {
        let offscreenView = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = GameScene(size: size)
        scene.backgroundColor = .white
        scene.scaleMode = .aspectFit
        offscreenView.presentScene(scene)
        let scale = min(size.width, size.height) / 600.0
        let node = scene.renderStickFigure(figure, at: .zero, scale: scale)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        scene.addChild(node)
        offscreenView.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            offscreenView.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        return img.cgImage
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AnimationStageScene

/// SpriteKit preview scene. Figure is centered at scene middle.
/// Tap/hold the left half of the scene to move the figure left;
/// tap/hold the right half to move right (like gameplay movement).
class AnimationStageScene: SKScene {

    private var figureNode: SKNode?
    private var frames: [SavedEditFrame] = []
    private var frameIndex: Int = 0
    private var frameDelay: Double = 0.25
    private var looping: Bool = true
    private var isAnimating: Bool = false

    // Movement via touch hold
    private var moveDirection: CGFloat = 0   // -1 left, +1 right, 0 stopped
    private let moveSpeed: CGFloat = 220     // pixels/sec — fast like gameplay
    private var figureX: CGFloat = 0

    // Zoom
    private var zoomScale: CGFloat = 1.0
    private let zoomMin: CGFloat = 0.4
    private let zoomMax: CGFloat = 3.0

    // "Move" animation frames loaded from animations.json (same source as gameplay)
    private var moveFrames: [SavedEditFrame] = []
    private var moveFrameIndex: Int = 0
    private var moveFrameInterval: Double = 0.15
    private var moveTimer: Timer?

    // The last non-move frame to restore when movement stops
    private var idleFrame: SavedEditFrame?
    private var idleFigure: StickFigure2D?

    // Base Y for the figure (center of scene); frames may offset from this
    private var baseFigureY: CGFloat { size.height / 2 }
    // Per-frame Y offset (from SavedEditFrame.positionY)
    private var currentFrameOffsetY: CGFloat = 0

    private var currentFigureY: CGFloat { baseFigureY + currentFrameOffsetY }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.85, green: 0.92, blue: 0.85, alpha: 1.0)
        figureX = size.width / 2
        loadMoveFrames()
    }

    /// Load "Move" frames from saved frames using the frame numbers in the "run" action config.
    private func loadMoveFrames() {
        let allFrames = SavedFramesManager.shared.getAllFrames()
        var frameNumbers = [1, 2, 3, 4, 5, 6, 7, 8]
        if let runConfig = ACTION_CONFIGS.first(where: { $0.id == "run" }),
           let anim = runConfig.stickFigureAnimation {
            frameNumbers = anim.frameNumbers
            moveFrameInterval = anim.baseFrameInterval
        }
        moveFrames = frameNumbers.compactMap { num in
            allFrames.first(where: { $0.name == "Move" && $0.frameNumber == num })
        }
    }

    // MARK: - Public API

    func showStillFigure(_ figure: StickFigure2D) {
        stopMoveAnimation()
        idleFigure = figure
        idleFrame = nil
        figureNode?.removeFromParent()
        figureX = size.width / 2
        currentFrameOffsetY = figure.figureOffsetY
        let node = buildFigureNode(figure)
        node.position = CGPoint(x: figureX, y: currentFigureY)
        node.setScale(zoomScale)
        addChild(node)
        figureNode = node
    }

    func showStillFrame(_ frame: SavedEditFrame) {
        stopMoveAnimation()
        idleFrame = frame
        idleFigure = nil
        figureNode?.removeFromParent()
        figureX = size.width / 2
        currentFrameOffsetY = CGFloat(frame.positionY)
        let node = buildFrameNode(frame)
        node.position = CGPoint(x: figureX, y: currentFigureY)
        node.setScale(zoomScale)
        addChild(node)
        figureNode = node
    }

    func startAnimation(frames: [SavedEditFrame], delay: Double, loop: Bool) {
        guard !frames.isEmpty else { return }
        self.frames = frames
        self.frameDelay = delay
        self.looping = loop
        self.isAnimating = true
        self.frameIndex = 0
        showNextFrame()
    }

    func stopAnimation() {
        isAnimating = false
        removeAction(forKey: "animationTimer")
    }

    func setFrameDelay(_ delay: Double) {
        self.frameDelay = delay
        if isAnimating {
            let current = frames
            stopAnimation()
            startAnimation(frames: current, delay: delay, loop: looping)
        }
    }

    func setLooping(_ loop: Bool) { self.looping = loop }

    func adjustZoom(by delta: CGFloat) {
        zoomScale = max(zoomMin, min(zoomMax, zoomScale + delta))
        figureNode?.setScale(zoomScale)
    }

    // MARK: - Touch handling (hold left half = move left, right half = move right)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let touch = touches.first else { return }
        let newDir: CGFloat = touch.location(in: self).x < size.width / 2 ? -1 : 1
        if newDir != moveDirection {
            moveDirection = newDir
            startMoveAnimation()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let touch = touches.first else { return }
        let newDir: CGFloat = touch.location(in: self).x < size.width / 2 ? -1 : 1
        if newDir != moveDirection {
            moveDirection = newDir
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard moveDirection != 0 else { return }
        moveDirection = 0
        stopMoveAnimation()
        restoreIdleFrame()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard moveDirection != 0 else { return }
        moveDirection = 0
        stopMoveAnimation()
        restoreIdleFrame()
    }

    // MARK: - Move animation cycling

    private func startMoveAnimation() {
        guard !moveFrames.isEmpty else { return }
        moveTimer?.invalidate()
        moveFrameIndex = 0
        showMoveFrame()
        moveTimer = Timer.scheduledTimer(withTimeInterval: moveFrameInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.moveDirection != 0 else { return }
            self.moveFrameIndex = (self.moveFrameIndex + 1) % self.moveFrames.count
            self.showMoveFrame()
        }
    }

    private func stopMoveAnimation() {
        moveTimer?.invalidate()
        moveTimer = nil
    }

    private func showMoveFrame() {
        guard moveFrameIndex < moveFrames.count else { return }
        let frame = moveFrames[moveFrameIndex]
        figureNode?.removeFromParent()
        let node = buildFrameNode(frame)
        node.position = CGPoint(x: figureX, y: currentFigureY)
        node.setScale(zoomScale)
        if moveDirection < 0 { node.xScale = -zoomScale }
        addChild(node)
        figureNode = node
    }

    private func restoreIdleFrame() {
        figureNode?.removeFromParent()
        if let frame = idleFrame {
            currentFrameOffsetY = CGFloat(frame.positionY)
            let node = buildFrameNode(frame)
            node.position = CGPoint(x: figureX, y: currentFigureY)
            node.setScale(zoomScale)
            addChild(node)
            figureNode = node
        } else if let figure = idleFigure {
            currentFrameOffsetY = figure.figureOffsetY
            let node = buildFigureNode(figure)
            node.position = CGPoint(x: figureX, y: currentFigureY)
            node.setScale(zoomScale)
            addChild(node)
            figureNode = node
        }
    }

    // MARK: - Update loop (position only while moving)

    override func update(_ currentTime: TimeInterval) {
        guard moveDirection != 0 else { return }
        let dt: CGFloat = 1.0 / 60.0
        figureX += moveSpeed * moveDirection * dt
        let margin: CGFloat = 40
        figureX = max(margin, min(size.width - margin, figureX))
        figureNode?.position = CGPoint(x: figureX, y: currentFigureY)
    }

    // MARK: - Private

    private func showNextFrame() {
        guard isAnimating, !frames.isEmpty else { return }
        let frame = frames[frameIndex]
        currentFrameOffsetY = CGFloat(frame.positionY)
        figureNode?.removeFromParent()
        let node = buildFrameNode(frame)
        node.position = CGPoint(x: figureX, y: currentFigureY)
        node.setScale(zoomScale)
        addChild(node)
        figureNode = node

        frameIndex += 1
        if frameIndex >= frames.count {
            if looping { frameIndex = 0 } else { isAnimating = false; return }
        }

        run(SKAction.sequence([
            SKAction.wait(forDuration: frameDelay),
            SKAction.run { [weak self] in self?.showNextFrame() }
        ]), withKey: "animationTimer")
    }

    /// Build a rendering node for a SavedEditFrame including figure + any placed objects.
    private func buildFrameNode(_ frame: SavedEditFrame) -> SKNode {
        let container = SKNode()
        let figure = frame.toStickFigure2D()
        let tempScene = GameScene(size: size)
        let renderScale = min(size.width, size.height) / 520.0
        let figNode = tempScene.renderStickFigure(figure, at: .zero, scale: renderScale)
        container.addChild(figNode)

        for obj in frame.objects {
            if obj.assetName.hasPrefix("BOX_") {
                let parts = obj.assetName.dropFirst(4).components(separatedBy: "_")
                let hexColor = parts.first ?? "000000"
                let w = CGFloat(parts.dropFirst().first.flatMap { Double($0) } ?? 40)
                let h = CGFloat(parts.dropFirst(2).first.flatMap { Double($0) } ?? 40)
                let box = SKShapeNode(rectOf: CGSize(width: w * obj.scaleX, height: h * obj.scaleY))
                box.fillColor = UIColor(hex: hexColor) ?? .gray
                box.strokeColor = .clear
                box.position = scenePosition(for: obj)
                box.zRotation = obj.rotation
                container.addChild(box)
            } else if obj.assetName.hasPrefix("EMOJI_") {
                let emoji = String(obj.assetName.dropFirst(6))
                let label = SKLabelNode(text: emoji)
                label.fontSize = 40 * obj.scaleX
                label.verticalAlignmentMode = .center
                label.position = scenePosition(for: obj)
                label.zRotation = obj.rotation
                container.addChild(label)
            } else {
                let sprite = SKSpriteNode(imageNamed: obj.assetName)
                sprite.size = CGSize(
                    width: (obj.baseWidth ?? 40) * obj.scaleX,
                    height: (obj.baseHeight ?? 40) * obj.scaleY
                )
                sprite.position = scenePosition(for: obj)
                sprite.zRotation = obj.rotation
                container.addChild(sprite)
            }
        }

        return container
    }

    private func buildFigureNode(_ figure: StickFigure2D) -> SKNode {
        let tempScene = GameScene(size: size)
        let renderScale = min(size.width, size.height) / 520.0
        return tempScene.renderStickFigure(figure, at: .zero, scale: renderScale)
    }

    private func scenePosition(for obj: EditorObject) -> CGPoint {
        let scaleX = size.width / obj.editorSceneWidth
        let scaleY = scaleX
        return CGPoint(x: obj.position.x * scaleX, y: obj.position.y * scaleY)
    }
}
