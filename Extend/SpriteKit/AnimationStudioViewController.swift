import UIKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers
import SwiftUI

// MARK: - AnimationStudioViewController

/// Full-screen Animation Studio — pick saved frames, play them as a walking animation, export GIF.
class AnimationStudioViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    // MARK: - UI
    private let previewView = SKView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var previewScene: AnimationStageScene?
    private var headerTopView: UIView?
    private var controlBarView: UIView?

    // Collapse / expand panel
    private var tableCollapsed = false
    private var previewHeightConstraint: NSLayoutConstraint?
    private weak var collapseChevron: UIButton?

    // Weak refs for live control bar updates
    private weak var delayValueLabel: UILabel?
    private weak var playStopButton: UIButton?
    private weak var loopToggle: UISwitch?


    // MARK: - Data model

    /// A named group of frames (e.g. all "Stand" frames)
    private struct FrameGroup {
        let name: String
        let indices: [Int]
    }

    private var allFrames: [SavedEditFrame] = []
    private var groups: [FrameGroup] = []
    private var filteredGroups: [FrameGroup] = []
    private var searchText: String = ""

    // Persistent search bar — kept alive across reloads so it never loses focus
    private let persistentSearchBar = UISearchBar()

    // MARK: - Animation state
    private var sequenceItems: [(frameIndex: Int, label: String)] = []
    private var frameDelay: Double = 0.25
    private var loopEnabled: Bool = true
    private var isPlaying: Bool = false

    // MARK: - Section layout
    // Section 0        — ANIMATION SEQUENCE (1 auto-height row)
    // Section 1        — SEARCH BAR (1 row)
    // Sections 2…G+1   — one section per filtered FrameGroup
    private var numGroups: Int { filteredGroups.count }

    // Chip scroll view — kept alive so it doesn't flicker on reload
    private let chipScrollView = UIScrollView()
    private let chipStackView = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .systemBackground

        allFrames = SavedFramesManager.shared.getAllFrames()
            .sorted { $0.frameNumber < $1.frameNumber }
        buildGroups()

        persistentSearchBar.placeholder = "Search frames..."
        persistentSearchBar.searchBarStyle = .minimal
        persistentSearchBar.delegate = self

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
        applySearch()
    }

    private func applySearch() {
        if searchText.isEmpty {
            filteredGroups = groups
        } else {
            let q = searchText.lowercased()
            filteredGroups = groups.filter { $0.name.lowercased().contains(q) }
        }
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

        var gifConfig = UIButton.Configuration.filled()
        gifConfig.title = "GIF"
        gifConfig.baseForegroundColor = .white
        gifConfig.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        gifConfig.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
        gifConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = UIFont.systemFont(ofSize: 12, weight: .bold); return a
        }
        let gifButton = UIButton(configuration: gifConfig)
        gifButton.layer.cornerRadius = 6
        gifButton.translatesAutoresizingMaskIntoConstraints = false
        gifButton.addTarget(self, action: #selector(exportGIFTapped), for: .touchUpInside)
        headerView.addSubview(gifButton)

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
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            gifButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -10),
            gifButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        self.headerTopView = headerView
    }

    /// Compact control bar sitting between the preview and the tableView.
    /// Row 1: ▶ Play/Stop  |  🔍- Zoom Out  |  🔍+ Zoom In
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

        let zoomOutBtn = makeBarButton(title: "−", color: .systemOrange)
        zoomOutBtn.addTarget(self, action: #selector(zoomOutTapped), for: .touchUpInside)
        zoomOutBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)

        let zoomInBtn = makeBarButton(title: "+", color: .systemOrange)
        zoomInBtn.addTarget(self, action: #selector(zoomInTapped), for: .touchUpInside)
        zoomInBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)

        let btnStack = UIStackView(arrangedSubviews: [playBtn, zoomOutBtn, zoomInBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 8
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(btnStack)

        // --- Row 2: speed + loop ---
        // Studio is pinned to light appearance; force explicit label colors
        // so a stray dark-mode trait can't render these white-on-white.
        let speedLabel = UILabel()
        speedLabel.text = "Speed"
        speedLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        speedLabel.textColor = .black
        speedLabel.translatesAutoresizingMaskIntoConstraints = false

        let valLabel = UILabel()
        valLabel.text = String(format: "%.2fs", frameDelay)
        valLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        valLabel.textColor = .darkGray
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
        loopLabel.textColor = .black
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
        previewView.backgroundColor = .white
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

        // Chevron strip sits at bottom of previewView
        let chevronStrip = UIView()
        chevronStrip.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        chevronStrip.translatesAutoresizingMaskIntoConstraints = false
        previewView.addSubview(chevronStrip)

        let chevronBtn = UIButton(type: .system)
        chevronBtn.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        chevronBtn.tintColor = .white
        chevronBtn.translatesAutoresizingMaskIntoConstraints = false
        chevronBtn.addTarget(self, action: #selector(toggleTableCollapse), for: .touchUpInside)
        chevronStrip.addSubview(chevronBtn)
        collapseChevron = chevronBtn

        NSLayoutConstraint.activate([
            chevronStrip.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            chevronStrip.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            chevronStrip.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            chevronStrip.heightAnchor.constraint(equalToConstant: 22),
            chevronBtn.centerXAnchor.constraint(equalTo: chevronStrip.centerXAnchor),
            chevronBtn.centerYAnchor.constraint(equalTo: chevronStrip.centerYAnchor)
        ])

        let heightConstraint = previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.33)
        previewHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: bar.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,

            tableView.topAnchor.constraint(equalTo: previewView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    @objc private func toggleTableCollapse() {
        tableCollapsed.toggle()
        let chevron = collapseChevron

        if tableCollapsed {
            // Collapse: stretch preview to safe-area bottom, hide tableView
            previewHeightConstraint?.isActive = false
            previewHeightConstraint = previewView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            previewHeightConstraint?.isActive = true

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                chevron?.transform = CGAffineTransform(rotationAngle: .pi)
                self.tableView.alpha = 0
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.tableView.isHidden = true
            }
        } else {
            // Expand: show tableView, restore 33% height split
            tableView.isHidden = false
            tableView.alpha = 0

            previewHeightConstraint?.isActive = false
            previewHeightConstraint = previewView.heightAnchor.constraint(
                equalTo: view.heightAnchor, multiplier: 0.33)
            previewHeightConstraint?.isActive = true

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                chevron?.transform = .identity
                self.tableView.alpha = 1
                self.view.layoutIfNeeded()
            }
        }
    }

    private func setupScene() {
        let w = previewView.bounds.width
        guard w > 0 else { return }
        // Use a fixed square scene so figure scale never changes when the view resizes
        let size = CGSize(width: w, height: w)
        let scene = AnimationStageScene(size: size)
        scene.scaleMode = .aspectFill
        previewScene = scene
        previewView.presentScene(scene)
        previewView.ignoresSiblingOrder = true

        // Pinch to zoom
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePreviewPinch(_:)))
        previewView.addGestureRecognizer(pinch)

        // Pan to move camera when zoomed in
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePreviewPan(_:)))
        pan.minimumNumberOfTouches = 2
        previewView.addGestureRecognizer(pan)

        if let standFrame = allFrames.first(where: { $0.name.lowercased() == "stand" && $0.frameNumber == 0 })
                         ?? allFrames.first(where: { $0.name.lowercased() == "stand" })
                         ?? allFrames.first {
            previewScene?.showStillFrame(standFrame)
        } else {
            previewScene?.showStillFigure(StickFigure2D())
        }
    }

    // MARK: - Preview gestures

    private var pinchStartZoom: CGFloat = 1.0

    @objc private func handlePreviewPinch(_ gr: UIPinchGestureRecognizer) {
        if gr.state == .began { pinchStartZoom = previewScene?.currentZoom ?? 1.0 }
        previewScene?.setZoom(pinchStartZoom * gr.scale)
    }

    @objc private func handlePreviewPan(_ gr: UIPanGestureRecognizer) {
        guard let scene = previewScene, scene.currentZoom > 1.01 else { return }
        let t = gr.translation(in: previewView)
        // Convert UIKit points to scene points (scene may have different size)
        let sceneScale = scene.size.width / previewView.bounds.width
        scene.panCamera(by: CGPoint(x: -t.x * sceneScale, y: t.y * sceneScale))
        gr.setTranslation(.zero, in: previewView)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 + numGroups   // sequence + search + frame groups
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }   // sequence
        if section == 1 { return 1 }   // search bar
        let g = section - 2
        guard g >= 0, g < filteredGroups.count else { return 0 }
        return filteredGroups[g].indices.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return nil }  // custom header view used instead
        if section == 1 { return nil }  // search bar — no header
        let g = section - 2
        guard g >= 0, g < filteredGroups.count else { return nil }
        return filteredGroups[g].name.uppercased()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 0 else { return nil }
        let header = UIView()
        header.backgroundColor = .clear

        let title = UILabel()
        title.text = "ANIMATION SEQUENCE"
        title.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabel
        title.translatesAutoresizingMaskIntoConstraints = false

        let saveBtn = makeHeaderButton(title: "Save", color: .systemGreen)
        saveBtn.addTarget(self, action: #selector(saveSequenceTapped), for: .touchUpInside)

        let loadBtn = makeHeaderButton(title: "Load", color: .systemBlue)
        loadBtn.addTarget(self, action: #selector(loadSequenceTapped), for: .touchUpInside)

        let clearBtn = makeHeaderButton(title: "Clear", color: .systemRed)
        clearBtn.addTarget(self, action: #selector(clearSequenceTapped), for: .touchUpInside)

        let btnStack = UIStackView(arrangedSubviews: [saveBtn, loadBtn, clearBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 6
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(title)
        header.addSubview(btnStack)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            btnStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            btnStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            header.heightAnchor.constraint(equalToConstant: 32)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 32 : UITableView.automaticDimension
    }

    private func makeHeaderButton(title: String, color: UIColor) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseForegroundColor = color
        config.baseBackgroundColor = color.withAlphaComponent(0.12)
        config.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = UIFont.systemFont(ofSize: 11, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.layer.cornerRadius = 6
        return btn
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.selectionStyle = .none
        cell.accessoryType = .none

        if indexPath.section == 0 {
            buildSequenceCell(cell)
        } else if indexPath.section == 1 {
            buildSearchCell(cell)
        } else {
            let g = indexPath.section - 2
            guard g >= 0, g < filteredGroups.count else { return cell }
            let frameIndex = filteredGroups[g].indices[indexPath.row]
            buildFramePickerCell(cell, frameIndex: frameIndex)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return UITableView.automaticDimension }
        if indexPath.section == 1 { return 44 }
        return 34
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return 60 }
        if indexPath.section == 1 { return 44 }
        return 34
    }

    // MARK: - Tap to add frame to sequence

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section > 1 else { return }
        let g = indexPath.section - 2
        guard g >= 0, g < filteredGroups.count else { return }
        let frameIndex = filteredGroups[g].indices[indexPath.row]
        let frame = allFrames[frameIndex]
        let label = frame.name.isEmpty
            ? "Frame \(frame.frameNumber)"
            : "\(frame.name) #\(frame.frameNumber)"
        sequenceItems.append((frameIndex: frameIndex, label: label))
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
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = count > 0 ? "×\(count) +" : "+"
        badge.font = UIFont.monospacedSystemFont(ofSize: 11, weight: count > 0 ? .bold : .regular)
        badge.textColor = count > 0 ? .systemGreen : .tertiaryLabel
        badge.translatesAutoresizingMaskIntoConstraints = false
        cell.selectionStyle = .default

        cell.contentView.addSubview(label)
        cell.contentView.addSubview(badge)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -4),
            badge.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -14),
            badge.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
    }

    private func buildSearchCell(_ cell: UITableViewCell) {
        // Use the persistent search bar so focus is never lost on reload
        let searchBar = persistentSearchBar
        searchBar.removeFromSuperview()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            searchBar.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            searchBar.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
        ])
    }

    private func buildSequenceCell(_ cell: UITableViewCell) {
        // Reuse the persistent chip scroll view — just re-parent it into the cell
        let sv = chipScrollView
        sv.removeFromSuperview()
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.translatesAutoresizingMaskIntoConstraints = false

        let stack = chipStackView
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Remove stale chips and rebuild
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if sequenceItems.isEmpty {
            let placeholder = UILabel()
            placeholder.text = "Tap frames below to build a sequence"
            placeholder.font = UIFont.systemFont(ofSize: 12)
            placeholder.textColor = .tertiaryLabel
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(placeholder)
        } else {
            for (idx, item) in sequenceItems.enumerated() {
                let chip = makeSequenceChip(label: item.label, index: idx)
                stack.addArrangedSubview(chip)
            }
        }

        if !sv.subviews.contains(stack) {
            sv.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor, constant: -8),
                stack.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor, constant: 6),
                stack.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor, constant: -6),
                stack.heightAnchor.constraint(equalTo: sv.frameLayoutGuide.heightAnchor, constant: -12)
            ])
        }

        cell.contentView.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            sv.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            sv.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            sv.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Scroll to end so latest chip is visible
        if !sequenceItems.isEmpty {
            DispatchQueue.main.async {
                let rightEdge = CGPoint(x: max(0, sv.contentSize.width - sv.bounds.width), y: 0)
                sv.setContentOffset(rightEdge, animated: false)
            }
        }
    }

    private func makeSequenceChip(label: String, index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = .black
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let xBtn = UIButton(type: .system)
        xBtn.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)), for: .normal)
        xBtn.tintColor = .secondaryLabel
        xBtn.translatesAutoresizingMaskIntoConstraints = false
        xBtn.tag = index
        xBtn.addTarget(self, action: #selector(removeChipTapped(_:)), for: .touchUpInside)

        container.addSubview(lbl)
        container.addSubview(xBtn)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 7),
            lbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            xBtn.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 3),
            xBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            xBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            xBtn.widthAnchor.constraint(equalToConstant: 16),
            container.heightAnchor.constraint(equalToConstant: 28)
        ])
        return container
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        stopPlayback()
        dismiss(animated: true)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applySearch()
        // Reload only the frame group sections (section 2+) to preserve search bar focus
        let oldCount = tableView.numberOfSections
        let newCount = 2 + filteredGroups.count
        tableView.performBatchUpdates({
            if newCount > oldCount {
                tableView.insertSections(IndexSet(integersIn: oldCount..<newCount), with: .none)
            } else if newCount < oldCount {
                tableView.deleteSections(IndexSet(integersIn: newCount..<oldCount), with: .none)
            }
            // Reload any sections that exist in both old and new
            let reloadCount = min(oldCount, newCount)
            if reloadCount > 2 {
                tableView.reloadSections(IndexSet(integersIn: 2..<reloadCount), with: .none)
            }
        }, completion: nil)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    @objc private func removeChipTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx >= 0, idx < sequenceItems.count else { return }
        sequenceItems.remove(at: idx)
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
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
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        showDefaultStill()
    }

    @objc private func saveSequenceTapped() {
        guard !sequenceItems.isEmpty else {
            showAlert(title: "Empty Sequence", message: "Add frames to the sequence before saving.")
            return
        }
        let alert = UIAlertController(title: "Save Animation", message: "Enter a name for this animation.", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "e.g. Walk Cycle"
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let finalName = name.isEmpty ? "Untitled" : name
            let frameIDs = self.sequenceItems.compactMap { item -> UUID? in
                guard item.frameIndex < self.allFrames.count else { return nil }
                return self.allFrames[item.frameIndex].id
            }
            let animation = SavedAnimation(name: finalName, frameIDs: frameIDs)
            SavedAnimationsManager.shared.save(animation)
            self.showAlert(title: "Saved", message: "\"\(finalName)\" saved with \(frameIDs.count) frame(s).")
        })
        present(alert, animated: true)
    }

    @objc private func loadSequenceTapped() {
        let browser = SavedAnimationsBrowserViewController { [weak self] animation in
            guard let self else { return }
            // Resolve frame IDs back to indices
            let idToIndex: [UUID: Int] = Dictionary(
                uniqueKeysWithValues: self.allFrames.enumerated().map { ($1.id, $0) }
            )
            let items: [(frameIndex: Int, label: String)] = animation.frameIDs.compactMap { id in
                guard let idx = idToIndex[id] else { return nil }
                let frame = self.allFrames[idx]
                let label = frame.name.isEmpty ? "Frame \(frame.frameNumber)" : "\(frame.name) #\(frame.frameNumber)"
                return (frameIndex: idx, label: label)
            }
            self.sequenceItems = items
            self.stopPlayback()
            self.tableView.reloadData()
            if let last = items.last {
                self.previewScene?.showStillFrame(self.allFrames[last.frameIndex])
            }
        }
        let nav = UINavigationController(rootViewController: browser)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
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

    /// Derive a display name for the current animation sequence (used in the exported filename).
    private func animationExportName() -> String {
        // Use the most common frame name in the sequence, falling back to "animation"
        let names = sequenceItems.compactMap { item -> String? in
            let f = allFrames[item.frameIndex]
            return f.name.isEmpty ? nil : f.name
        }
        if let first = names.first {
            // If all names are the same, use that; otherwise join unique names
            let unique = NSOrderedSet(array: names).array as! [String]
            return unique.count == 1 ? first : unique.joined(separator: "_")
        }
        return "animation"
    }

    /// Compute the tightest bounding rect (in UIKit/pixel coords, top-left origin) that contains
    /// all figure + object content across every frame, then add padding.
    ///
    /// Uses SKNode.calculateAccumulatedFrame() which returns the exact bounds of the node tree
    /// in the parent's coordinate space (SK convention: Y-up, origin at bottom-left).
    /// We convert those SK coords to UIKit pixel coords (Y-down) for CGImage.cropping.
    private func contentBoundingRect(frames: [SavedEditFrame], canvasSize: CGSize,
                                     padding: CGFloat = 24,
                                     scene: GameScene) -> CGRect {
        var skUnion: CGRect? = nil

        for frame in frames {
            let node = buildExportNode(for: frame, canvasSize: canvasSize, scene: scene)
            // calculateAccumulatedFrame needs the node in a scene to resolve coordinates,
            // but we only need the geometry — add temporarily without display.
            scene.addChild(node)
            // accumulated frame is in scene coords (SK space: Y-up, origin bottom-left)
            let skFrame = node.calculateAccumulatedFrame()
            node.removeFromParent()

            guard skFrame.width > 0, skFrame.height > 0 else { continue }
            skUnion = skUnion.map { $0.union(skFrame) } ?? skFrame
        }

        guard let skRect = skUnion else {
            return CGRect(origin: .zero, size: canvasSize)
        }

        // Expand by padding in SK space, clamped to the canvas.
        let skX0 = max(0, skRect.minX - padding)
        let skY0 = max(0, skRect.minY - padding)
        let skX1 = min(canvasSize.width,  skRect.maxX + padding)
        let skY1 = min(canvasSize.height, skRect.maxY + padding)

        // Convert from SK coords (Y-up, origin bottom-left) to UIKit pixel coords (Y-down).
        // The top edge in UIKit = canvasHeight - skY1 (the SK maximum Y).
        let uiY = canvasSize.height - skY1
        let uiW = skX1 - skX0
        let uiH = skY1 - skY0
        return CGRect(x: skX0, y: uiY, width: uiW, height: uiH)
    }

    private func exportGIF(frames: [SavedEditFrame]) {
        // Use a large internal canvas so the bounding-box crop has enough resolution
        let canvasSize = CGSize(width: 512, height: 512)
        let padding: CGFloat = 24

        // Create a single SKView + scene for all frames. Adding the view to the window
        // ensures SKView.texture(from:crop:) renders reliably for every frame.
        let renderView = SKView(frame: CGRect(origin: .zero, size: canvasSize))
        renderView.isHidden = true
        view.addSubview(renderView)
        defer { renderView.removeFromSuperview() }

        let renderScene = GameScene(size: canvasSize)
        renderScene.scaleMode = .fill
        renderView.presentScene(renderScene)
        // Set white AFTER presentScene — GameScene.didMove(to:) overwrites backgroundColor,
        // so we must override it again here.
        renderScene.backgroundColor = .white

        // Use SK node accumulated frames to find the true content bounding rect.
        let cropRect = contentBoundingRect(frames: frames, canvasSize: canvasSize,
                                           padding: padding,
                                           scene: renderScene)

        // Output GIF at the cropped size (max 512 on longest side to keep file small)
        let cropAspect = cropRect.width / max(cropRect.height, 1)
        let gifSize: CGSize
        if cropAspect >= 1 {
            let w = min(512, cropRect.width)
            gifSize = CGSize(width: w, height: (w / cropAspect).rounded())
        } else {
            let h = min(512, cropRect.height)
            gifSize = CGSize(width: (h * cropAspect).rounded(), height: h)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let baseName = animationExportName()
            .components(separatedBy: .whitespacesAndNewlines).joined(separator: "_")
        let filename = "\(baseName)_\(timestamp).gif"

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

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
            if let cgImg = renderFrameToCGImage(savedFrame, size: canvasSize, cropRect: cropRect,
                                                outputSize: gifSize, renderView: renderView, scene: renderScene) {
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

    /// Build the SK node tree for a frame (figure + objects) using a shared GameScene.
    /// The returned node is positioned at (0,0) and sized to `canvasSize`.
    private func buildExportNode(for frame: SavedEditFrame, canvasSize: CGSize, scene: GameScene) -> SKNode {
        let figure = frame.toStickFigure2D()
        let renderScale = min(canvasSize.width, canvasSize.height) / 520.0
        let scaleFactor = renderScale / 1.2

        let container = SKNode()
        let offsetX = CGFloat(frame.positionX) * scaleFactor
        let offsetY = CGFloat(frame.positionY) * scaleFactor
        // Position relative to canvas centre
        container.position = CGPoint(x: canvasSize.width / 2 + offsetX, y: canvasSize.height / 2 + offsetY)

        let figNode = scene.renderStickFigure(figure, at: .zero, scale: renderScale)
        container.addChild(figNode)

        for obj in frame.objects {
            let editorCenter = obj.editorSceneWidth / 2
            let dx = (obj.position.x - editorCenter) * scaleFactor - offsetX
            let dy = (obj.position.y - editorCenter) * scaleFactor - offsetY
            let pos = CGPoint(x: dx, y: dy)

            if obj.assetName.hasPrefix("BOX_") {
                let stripped = String(obj.assetName.dropFirst(4))
                let parts = stripped.components(separatedBy: "_")
                let hexColor = parts.first ?? "#000000"
                let w = CGFloat(parts.dropFirst().first.flatMap { Double($0) } ?? 40)
                let h = CGFloat(parts.dropFirst(2).first.flatMap { Double($0) } ?? 40)
                let box = SKShapeNode(rectOf: CGSize(width: w * obj.scaleX * scaleFactor,
                                                      height: h * obj.scaleY * scaleFactor))
                box.fillColor = UIColor(hex: hexColor) ?? .darkGray
                box.strokeColor = .black
                box.lineWidth = 1
                box.position = pos
                box.zRotation = obj.rotation
                container.addChild(box)
            } else if obj.assetName.hasPrefix("EMOJI_") {
                let emoji = String(obj.assetName.dropFirst(6))
                let label = SKLabelNode(text: emoji)
                label.fontSize = 40 * obj.scaleX * scaleFactor
                label.verticalAlignmentMode = .center
                label.position = pos
                label.zRotation = obj.rotation
                container.addChild(label)
            } else {
                let sprite = SKSpriteNode(imageNamed: obj.assetName)
                sprite.size = CGSize(
                    width: (obj.baseWidth ?? 40) * obj.scaleX * scaleFactor,
                    height: (obj.baseHeight ?? 40) * obj.scaleY * scaleFactor
                )
                sprite.position = pos
                sprite.zRotation = obj.rotation
                container.addChild(sprite)
            }
        }
        return container
    }

    /// Render a SavedEditFrame (figure + objects) to a CGImage cropped to cropRect
    /// and scaled to outputSize. All rendering is done at scale 1 (not screen scale)
    /// to keep GIF frame pixel dimensions predictable and file size small.
    private func renderFrameToCGImage(_ frame: SavedEditFrame, size: CGSize,
                                      cropRect: CGRect, outputSize: CGSize,
                                      renderView: SKView, scene: GameScene) -> CGImage? {
        let node = buildExportNode(for: frame, canvasSize: size, scene: scene)
        scene.addChild(node)
        defer { node.removeFromParent() }

        // 1. Capture the full canvas. crop rect is in scene (SK) coords (bottom-left origin).
        let fullCropSK = CGRect(origin: .zero, size: size)
        guard let texture = renderView.texture(from: scene, crop: fullCropSK) else { return nil }

        // Force scale=1 so the CGImage is exactly `size` pixels, not 2x/3x screen scale.
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1

        // texture.cgImage() is Y-flipped (SK convention). Drawing via UIImage corrects the flip.
        let fullCG = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: texture.cgImage()).draw(in: CGRect(origin: .zero, size: size))
        }.cgImage

        // 2. Crop in pixel space. cropRect is already in UIKit coords (top-left origin, scale 1).
        guard let full = fullCG, let cropped = full.cropping(to: cropRect) else { return nil }

        // 3. Scale to outputSize at scale 1.
        return UIGraphicsImageRenderer(size: outputSize, format: fmt).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: outputSize))
        }.cgImage
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SavedAnimationsBrowserViewController

class SavedAnimationsBrowserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    private let onLoad: (SavedAnimation) -> Void
    private var allAnimations: [SavedAnimation] = []
    private var filtered: [SavedAnimation] = []
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar()

    init(onLoad: @escaping (SavedAnimation) -> Void) {
        self.onLoad = onLoad
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Saved Animations"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        searchBar.placeholder = "Search animations..."
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AnimCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(searchBar)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        reload()
    }

    private func reload() {
        allAnimations = SavedAnimationsManager.shared.getAll()
        applyFilter()
    }

    private func applyFilter() {
        let q = searchBar.text?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        filtered = q.isEmpty ? allAnimations : allAnimations.filter { $0.name.lowercased().contains(q) }
        tableView.reloadData()
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filtered.isEmpty ? 1 : filtered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AnimCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        if filtered.isEmpty {
            var config = cell.defaultContentConfiguration()
            config.text = "No saved animations"
            config.secondaryText = "Build a sequence and tap Save."
            config.textProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell
        }

        let anim = filtered[indexPath.row]
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        // Name label
        let nameLabel = UILabel()
        nameLabel.text = anim.name
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .black
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Sub info
        let countLabel = UILabel()
        countLabel.text = "\(anim.frameCount) frame\(anim.frameCount == 1 ? "" : "s")  •  \(formatter.string(from: anim.updatedAt))"
        countLabel.font = UIFont.systemFont(ofSize: 11)
        countLabel.textColor = .darkGray
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [nameLabel, countLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10)
        ])
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !filtered.isEmpty else { return }
        let anim = filtered[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onLoad(anim)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !filtered.isEmpty else { return nil }
        let anim = filtered[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            SavedAnimationsManager.shared.delete(id: anim.id)
            self?.reload()
            done(true)
        }

        let clone = UIContextualAction(style: .normal, title: "Clone") { [weak self] _, _, done in
            _ = SavedAnimationsManager.shared.clone(anim)
            self?.reload()
            done(true)
        }
        clone.backgroundColor = .systemOrange

        let rename = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, done in
            guard let self else { done(false); return }
            let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
            alert.addTextField { tf in tf.text = anim.name }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in done(false) })
            alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
                let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
                if !name.isEmpty {
                    SavedAnimationsManager.shared.rename(id: anim.id, newName: name)
                    self?.reload()
                }
                done(true)
            })
            self.present(alert, animated: true)
        }
        rename.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [delete, clone, rename])
    }

    // MARK: - Search

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { applyFilter() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
}

// MARK: - AnimationStageScene

/// SpriteKit preview scene. Figure is centered at scene middle.
/// Pinch to zoom, drag (when not moving figure) to pan.
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

    // Zoom + pan via SKCameraNode — camera scale is inverse of zoom (scale=0.5 means 2× zoom)
    private var cameraNode = SKCameraNode()
    private var zoomScale: CGFloat = 1.0     // logical zoom: 1.0 = normal, 2.0 = 2× magnified
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

    // Base center of the scene; frames may offset from this
    private var baseFigureY: CGFloat { size.height / 2 }
    // Per-frame offsets (from SavedEditFrame.positionX/Y), scaled to preview pixels
    private var currentFrameOffsetX: CGFloat = 0
    private var currentFrameOffsetY: CGFloat = 0

    private var currentFigureY: CGFloat { baseFigureY + currentFrameOffsetY }

    /// Converts editor-scene pixel offsets (figureOffsetX/Y) to preview scene pixels.
    /// The editor renders figures at scale 1.2; the preview uses renderScale = min(w,h)/520.
    /// scaleFactor = renderScale / 1.2 is the correct ratio for both X and Y.
    private var figurePositionScaleFactor: CGFloat {
        guard size.width > 0, size.height > 0 else { return 1.0 }
        let renderScale = min(size.width, size.height) / 520.0
        return renderScale / 1.2
    }

    override func didMove(to view: SKView) {
        backgroundColor = .white
        figureX = size.width / 2

        // Set up camera — starts at scene centre, natural 1:1 zoom
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode

        loadMoveFrames()
    }



    /// Load "Move" frames from saved frames (frames named "Move", numbers 1–8).
    private func loadMoveFrames() {
        let allFrames = SavedFramesManager.shared.getAllFrames()
        let frameNumbers = [1, 2, 3, 4, 5, 6, 7, 8]
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
        currentFrameOffsetX = CGFloat(figure.figureOffsetX) * figurePositionScaleFactor
        currentFrameOffsetY = CGFloat(figure.figureOffsetY) * figurePositionScaleFactor
        figureX = size.width / 2 + currentFrameOffsetX
        let node = buildFigureNode(figure)
        node.position = CGPoint(x: figureX, y: currentFigureY)
        addChild(node)
        figureNode = node
    }

    func showStillFrame(_ frame: SavedEditFrame) {
        stopMoveAnimation()
        idleFrame = frame
        idleFigure = nil
        figureNode?.removeFromParent()
        currentFrameOffsetX = CGFloat(frame.positionX) * figurePositionScaleFactor
        currentFrameOffsetY = CGFloat(frame.positionY) * figurePositionScaleFactor
        figureX = size.width / 2 + currentFrameOffsetX
        let node = buildFrameNode(frame)
        node.position = CGPoint(x: figureX, y: currentFigureY)
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

    var currentZoom: CGFloat { zoomScale }

    func adjustZoom(by delta: CGFloat) {
        setZoom(zoomScale + delta)
    }

    func setZoom(_ newZoom: CGFloat) {
        zoomScale = max(zoomMin, min(zoomMax, newZoom))
        // Camera scale is the inverse: zoom 2× means camera renders half the scene
        let camScale = 1.0 / zoomScale
        cameraNode.xScale = camScale
        cameraNode.yScale = camScale
    }

    func panCamera(by delta: CGPoint) {
        cameraNode.position = CGPoint(x: cameraNode.position.x + delta.x,
                                      y: cameraNode.position.y + delta.y)
    }

    func resetCamera() {
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        setZoom(1.0)
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
        if moveDirection < 0 { node.xScale = -1 }
        addChild(node)
        figureNode = node
    }

    private func restoreIdleFrame() {
        figureNode?.removeFromParent()
        if let frame = idleFrame {
            currentFrameOffsetY = CGFloat(frame.positionY) * figurePositionScaleFactor
            let node = buildFrameNode(frame)
            node.position = CGPoint(x: figureX, y: currentFigureY)
            addChild(node)
            figureNode = node
        } else if let figure = idleFigure {
            currentFrameOffsetY = CGFloat(figure.figureOffsetY) * figurePositionScaleFactor
            let node = buildFigureNode(figure)
            node.position = CGPoint(x: figureX, y: currentFigureY)
            addChild(node)
            figureNode = node
        }
    }

    // MARK: - Update loop (position + wrap-around while moving)

    override func update(_ currentTime: TimeInterval) {
        guard moveDirection != 0 else { return }
        let dt: CGFloat = 1.0 / 60.0
        figureX += moveSpeed * moveDirection * dt
        // Wrap around: exit left → enter right, exit right → enter left
        if figureX < -40 { figureX = size.width + 40 }
        else if figureX > size.width + 40 { figureX = -40 }
        figureNode?.position = CGPoint(x: figureX, y: currentFigureY)
    }

    // MARK: - Private

    private func showNextFrame() {
        guard isAnimating, !frames.isEmpty else { return }
        let frame = frames[frameIndex]
        currentFrameOffsetX = CGFloat(frame.positionX) * figurePositionScaleFactor
        currentFrameOffsetY = CGFloat(frame.positionY) * figurePositionScaleFactor
        figureX = size.width / 2 + currentFrameOffsetX
        figureNode?.removeFromParent()
        let node = buildFrameNode(frame)
        node.position = CGPoint(x: figureX, y: currentFigureY)
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
        let renderScale = min(size.width, size.height) / 520.0
        // The editor renders the figure at scale 1.2; objects are in editor-pixel space.
        // Use scaleFactor to convert editor pixels → preview pixels.
        let scaleFactor = renderScale / 1.2
        let tempScene = GameScene(size: size)
        let figNode = tempScene.renderStickFigure(figure, at: .zero, scale: renderScale)
        container.addChild(figNode)

        // Objects are stored in absolute editor-scene coordinates. objectPosition() converts
        // them to preview pixels relative to editor center, which already includes figureOffset.
        // The container is placed at (previewCenter + figureOffset * figurePositionScaleFactor), so
        // we subtract the figure offset (in preview-pixel units, i.e. scaled by scaleFactor)
        // to get coordinates relative to the container origin (the figure's position).
        let offsetX = CGFloat(frame.positionX) * scaleFactor
        let offsetY = CGFloat(frame.positionY) * scaleFactor

        for obj in frame.objects {
            var pos = objectPosition(for: obj, scaleFactor: scaleFactor)
            // Remove the embedded figure offset so objects are relative to the container
            pos = CGPoint(x: pos.x - offsetX, y: pos.y - offsetY)
            if obj.assetName.hasPrefix("BOX_") {
                // Format: BOX_#RRGGBB_width_height
                let stripped = String(obj.assetName.dropFirst(4))  // "#000000_66_50"
                let parts = stripped.components(separatedBy: "_")   // ["#000000","66","50"]
                let hexColor = parts.first ?? "#000000"
                let w = CGFloat(parts.dropFirst().first.flatMap { Double($0) } ?? 40)
                let h = CGFloat(parts.dropFirst(2).first.flatMap { Double($0) } ?? 40)
                let box = SKShapeNode(rectOf: CGSize(width: w * obj.scaleX * scaleFactor, height: h * obj.scaleY * scaleFactor))
                box.fillColor = UIColor(hex: hexColor) ?? .darkGray
                box.strokeColor = .black
                box.lineWidth = 1
                box.position = pos
                box.zRotation = obj.rotation
                container.addChild(box)
            } else if obj.assetName.hasPrefix("EMOJI_") {
                let emoji = String(obj.assetName.dropFirst(6))
                let label = SKLabelNode(text: emoji)
                label.fontSize = 40 * obj.scaleX * scaleFactor
                label.verticalAlignmentMode = .center
                label.position = pos
                label.zRotation = obj.rotation
                container.addChild(label)
            } else {
                let sprite = SKSpriteNode(imageNamed: obj.assetName)
                sprite.size = CGSize(
                    width: (obj.baseWidth ?? 40) * obj.scaleX * scaleFactor,
                    height: (obj.baseHeight ?? 40) * obj.scaleY * scaleFactor
                )
                sprite.position = pos
                sprite.zRotation = obj.rotation
                container.addChild(sprite)
            }
        }

        return container
    }

    private func buildFigureNode(_ figure: StickFigure2D) -> SKNode {
        let renderScale = min(size.width, size.height) / 520.0
        let tempScene = GameScene(size: size)
        return tempScene.renderStickFigure(figure, at: .zero, scale: renderScale)
    }

    /// Convert a saved object position to preview scene coordinates relative to the figure center (0,0).
    ///
    /// Object positions in SavedEditFrame are absolute editor-scene coordinates.
    /// The editor's characterNode sits at (editorSceneWidth/2, editorSceneWidth/2).
    /// scaleFactor = renderScale / 1.2 converts editor pixels to preview pixels.
    private func objectPosition(for obj: EditorObject, scaleFactor: CGFloat) -> CGPoint {
        let editorCenter = obj.editorSceneWidth / 2
        let dx = obj.position.x - editorCenter
        let dy = obj.position.y - editorCenter
        return CGPoint(x: dx * scaleFactor, y: dy * scaleFactor)
    }
}
