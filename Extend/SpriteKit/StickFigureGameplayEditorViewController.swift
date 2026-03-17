import UIKit
import SwiftUI
import SpriteKit

// MARK: - StickFigureGameplayEditorViewController
/// Full-screen editor for stick figure customization in gameplay
class StickFigureGameplayEditorViewController: UIViewController, UIColorPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    // MARK: - Properties
    private var skView: SKView?
    private var editorScene: StickFigureEditorScene?
    private var colorPickerEditorScene: StickFigureEditorScene?  // Store scene for color picker delegate
    
    private let topContainer = UIView()
    private let bottomContainer = UIView()
    private let controlsTableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private var figureScale: CGFloat = 1.0  // Multiplier for display size (1.0 = normal size)
    private var skeletonSizeTorso: CGFloat = 1.0   // Spine/torso connector thickness multiplier
    private var skeletonSizeArm: CGFloat = 1.0     // Arm connector thickness multiplier
    private var skeletonSizeLeg: CGFloat = 1.0     // Leg connector thickness multiplier
    private var jointShapeSize: CGFloat = 1.0  // Joint circle size multiplier
    private var shoulderWidthMultiplier: CGFloat = 1.0  // Controls distance between shoulders (1.0 = normal)
    private var waistWidthMultiplier: CGFloat = 1.0  // Controls distance between hips (1.0 = normal)
    private var waistThicknessMultiplier: CGFloat = 0.5  // Controls triangle point position (0.0 = top of mid-torso, 1.0 = bottom/waist)
    private var neckLength: CGFloat = 1.0  // Neck length multiplier
    private var neckWidth: CGFloat = 1.0  // Neck width multiplier
    private var handSize: CGFloat = 1.0  // Hand size multiplier
    private var footSize: CGFloat = 1.0  // Foot size multiplier
    private var fusiformUpperTorso: CGFloat = 4.0
    private var fusiformLowerTorso: CGFloat = 4.0
    private var fusiformBicep: CGFloat = 2.0
    private var fusiformTricep: CGFloat = 1.0
    private var fusiformLowerArms: CGFloat = 3.0
    private var fusiformUpperLegs: CGFloat = 4.0
    private var fusiformLowerLegs: CGFloat = 4.0
    private var fusiformShoulders: CGFloat = 0.0  // Shoulder tapering
    private var fusiformDeltoids: CGFloat = 0.0  // Deltoid (shoulder cap) tapering
    private var peakPositionBicep: CGFloat = 0.5  // Peak position for bicep
    private var peakPositionTricep: CGFloat = 0.5  // Peak position for tricep
    private var peakPositionLowerArms: CGFloat = 0.35  // Peak position for lower arms
    private var peakPositionUpperLegs: CGFloat = 0.2  // Peak position for upper legs
    private var peakPositionLowerLegs: CGFloat = 0.2  // Peak position for lower legs
    private var peakPositionUpperTorso: CGFloat = 0.5  // Peak position for upper torso
    private var peakPositionLowerTorso: CGFloat = 0.5  // Peak position for lower torso
    private var peakPositionDeltoids: CGFloat = 0.3  // Peak position for deltoids
    private var armMuscleSide: String = "normal"  // normal, flipped, or both
    
    // Individual stroke thickness properties for each body part
    private var strokeThicknessJoints: CGFloat = 2.0
    private var strokeThicknessUpperTorso: CGFloat = 5.0
    private var strokeThicknessLowerTorso: CGFloat = 5.0
    private var strokeThicknessBicep: CGFloat = 4.0
    private var strokeThicknessTricep: CGFloat = 3.0
    private var strokeThicknessLowerArms: CGFloat = 4.0
    private var strokeThicknessUpperLegs: CGFloat = 5.0
    private var strokeThicknessLowerLegs: CGFloat = 4.0
    private var strokeThicknessFullTorso: CGFloat = 1.0
    private var strokeThicknessDeltoids: CGFloat = 4.0
    private var strokeThicknessTrapezius: CGFloat = 4.0
    
    // Position offset
    var figureOffsetX: CGFloat = 0
    var figureOffsetY: CGFloat = 0
    
    // Colors for each body part (stored in dictionary for closure capture)
    var bodyPartColors: [String: UIColor] = [
        "head": .black,
        "torso": .black,
        "leftShoulder": .black,
        "rightShoulder": .black,
        "leftUpperArm": .black,
        "rightUpperArm": .black,
        "leftLowerArm": .black,
        "rightLowerArm": .black,
        "leftUpperLeg": .black,
        "rightUpperLeg": .black,
        "leftLowerLeg": .black,
        "rightLowerLeg": .black
    ]
    
    // Color picker properties
    private var pendingColorKey: String?
    private var pendingColorButton: UIButton?
    
    // Coordinate label reference for updating
    weak var coordinateLabel: UILabel?
    
    // Angle properties for joint positioning
    var neckRotation: CGFloat = 0
    var upperTorsoRotation: CGFloat = 0  // Rotation of upper torso (neck to midTorso) around midTorso
    var lowerTorsoRotation: CGFloat = 0  // Rotation of lower torso (midTorso to waist) around waist
    var waistTorsoAngle: CGFloat = 0  // Rotation of entire upper body around waist (waist pivot)
    var torsoRotation: CGFloat = 0
    var leftShoulderAngle: CGFloat = 0
    var leftElbowAngle: CGFloat = 0
    var rightShoulderAngle: CGFloat = 0
    var rightElbowAngle: CGFloat = 0
    var leftHipAngle: CGFloat = 0
    var rightHipAngle: CGFloat = 0
    var leftKneeAngle: CGFloat = 0
    var rightKneeAngle: CGFloat = 0
    var leftFootAngle: CGFloat = 0
    var rightFootAngle: CGFloat = 0
    
    var showInteractiveJoints: Bool = true
    var showObjectControls: Bool = true  // Show/hide object control dots (move, rotate, resize, delete)
    var sceneZoom: CGFloat = 1.0  // Zoom level for editor view (1.0 = normal, 2.0 = 2x zoom)
    
    // Section expansion state
    private var expandedSections: Set<Int> = [7]  // Expanded by default (section 7 Frames visible; others collapsed including colors)
    
    var gameState: StickFigureGameState?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupEditor()
        
        // Initialize angle values from Stand frame BEFORE rendering
        loadStandFrameValues()
        
        // Render the initial stick figure with joints
        updateFigure()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Top container - 50% of screen (non-scrollable)
        topContainer.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        
        // Bottom container - 50% of screen (tableView)
        bottomContainer.backgroundColor = .white
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)
        
        // Table view for controls
        controlsTableView.translatesAutoresizingMaskIntoConstraints = false
        controlsTableView.delegate = self
        controlsTableView.dataSource = self
        bottomContainer.addSubview(controlsTableView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Top container
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.heightAnchor.constraint(equalTo: topContainer.widthAnchor),
            
            // Bottom container
            bottomContainer.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Table view
            controlsTableView.topAnchor.constraint(equalTo: bottomContainer.topAnchor),
            controlsTableView.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor),
            controlsTableView.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            controlsTableView.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor)
        ])
        
        // Add header
        addHeader()
    }
    
    private func addHeader() {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 1.0)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        let titleLabel = UILabel()
        titleLabel.text = "STICK FIGURE EDITOR"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        // Show Joints toggle - small dot button
        let jointsButton = UIButton(type: .system)
        jointsButton.setTitle("●", for: .normal)
        jointsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        jointsButton.tintColor = showInteractiveJoints ? .white : UIColor.white.withAlphaComponent(0.5)
        jointsButton.translatesAutoresizingMaskIntoConstraints = false
        jointsButton.addTarget(self, action: #selector(toggleJointsFromHeader(_:)), for: .touchUpInside)
        // REMOVED: headerView.addSubview(jointsButton)  - old button no longer shown
        
        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("↻", for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        refreshButton.tintColor = .white
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.addTarget(self, action: #selector(refreshPressed), for: .touchUpInside)
        headerView.addSubview(refreshButton)
        
        // Interactive Controls toggle - small circle button to show/hide interactive joint dots and object controls
        let interactiveControlsButton = UIButton(type: .system)
        interactiveControlsButton.setTitle("○", for: .normal)
        interactiveControlsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        interactiveControlsButton.tintColor = .white
        interactiveControlsButton.translatesAutoresizingMaskIntoConstraints = false
        interactiveControlsButton.addTarget(self, action: #selector(toggleInteractiveControls(_:)), for: .touchUpInside)
        headerView.addSubview(interactiveControlsButton)
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        headerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            refreshButton.trailingAnchor.constraint(equalTo: interactiveControlsButton.leadingAnchor, constant: -8),
            refreshButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            interactiveControlsButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            interactiveControlsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            interactiveControlsButton.widthAnchor.constraint(equalToConstant: 24),
            interactiveControlsButton.heightAnchor.constraint(equalToConstant: 24),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupEditor() {
        let sceneWidth = view.bounds.width
        let sceneSize = CGSize(width: sceneWidth, height: sceneWidth)  // Perfect square!
        editorScene = StickFigureEditorScene(size: sceneSize)
        editorScene?.gameState = gameState
        editorScene?.viewController = self
        
        skView = SKView(frame: topContainer.bounds)
        skView?.presentScene(editorScene)
        skView?.ignoresSiblingOrder = true
        
        if let skView = skView {
            topContainer.addSubview(skView)
            skView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                skView.topAnchor.constraint(equalTo: topContainer.topAnchor, constant: 2),
                skView.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
                skView.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
                skView.heightAnchor.constraint(equalTo: skView.widthAnchor)  // Keep it square!
            ])
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return 8  // Display, Scale, Stroke, Fusiform, Joints, Colors, Save/Load, Objects
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let isExpanded = expandedSections.contains(section)
        
        switch section {
        case 0: return 2  // Zoom, Position buttons (Show Joints moved to header)
        case 1: return isExpanded ? 9 : 0  // Figure Scale, Joint Shape Size, Shoulder Width, Waist Width, Waist Thickness, Neck Length, Neck Width, Hand Size, Foot Size (Skeleton Size removed)
        case 2: return isExpanded ? 10 : 0  // Stroke Joints, Upper Torso, Lower Torso, Upper Arms, Lower Arms, Upper Legs, Lower Legs, Full Torso, Deltoids, Trapezius
        case 3: return isExpanded ? 18 : 0  // 9 fusiform (upper/lower torso, bicep, tricep, lower arms, upper legs, lower legs, shoulders, deltoids) + 8 peak position sliders + armMuscleSide
        case 4: return isExpanded ? 3 : 0  // 3 Skeleton Size sliders: Torso, Arm, Leg
        case 5: return isExpanded ? 11 : 0  // 11 Joint sliders: head, leftShoulder, rightShoulder, leftElbow, rightElbow, leftKnee, rightKnee, leftCalf, rightCalf, waistRotation, neckRotation
        case 6: return isExpanded ? 12 : 0  // Color pickers for each body part (added shoulders)
        case 7: return 2  // Frames label + Save + Load (now on same row), Objects label + Add Object button
        case 8: return 0  // Objects handled in section 7 now
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return nil  // No header for display section
        case 1: return "FIGURE SCALE & THICKNESS"
        case 2: return "STROKE THICKNESS"
        case 3: return "FUSIFORM"
        case 4: return "SKELETON"
        case 5: return "JOINT ANGLES"
        case 6: return "COLORS"
        case 7: return nil  // Header in cell now
        case 8: return nil  // Removed
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Make sections 1, 2, 3, 4, 5, and 6 collapsible
        guard section == 1 || section == 2 || section == 3 || section == 4 || section == 5 || section == 6 else { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        
        let label = UILabel()
        label.text = self.tableView(tableView, titleForHeaderInSection: section) ?? ""
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let arrow = UILabel()
        let isExpanded = expandedSections.contains(section)
        arrow.text = isExpanded ? "▼" : "▶"
        arrow.font = UIFont.systemFont(ofSize: 11)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(arrow)
        headerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            arrow.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            arrow.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 16),
            
            label.leadingAnchor.constraint(equalTo: arrow.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16)
        ])
        
        // Add tap gesture to toggle expansion
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleSectionExpansion(_:)))
        tapGesture.delegate = self
        headerView.addGestureRecognizer(tapGesture)
        headerView.tag = section  // Store section number in tag
        headerView.isUserInteractionEnabled = true
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "controlCell")
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            // Position buttons (X/Y controls) - smaller buttons - FIRST ROW
            let container = UIStackView()
            container.axis = .horizontal
            container.spacing = 2
            container.distribution = .fillEqually  // Changed to fillEqually for even spacing
            container.translatesAutoresizingMaskIntoConstraints = false
            
            // Left X buttons
            let leftXStack = UIStackView()
            leftXStack.axis = .horizontal
            leftXStack.spacing = 2
            leftXStack.distribution = .fillEqually
            
            let leftBtn = UIButton(type: .system)
            leftBtn.setTitle("← X", for: .normal)
            leftBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            leftBtn.addAction(UIAction { _ in self.figureOffsetX -= 1; self.updateFigure() }, for: .touchUpInside)
            leftXStack.addArrangedSubview(leftBtn)
            
            let rightBtn = UIButton(type: .system)
            rightBtn.setTitle("X →", for: .normal)
            rightBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            rightBtn.addAction(UIAction { _ in self.figureOffsetX += 1; self.updateFigure() }, for: .touchUpInside)
            leftXStack.addArrangedSubview(rightBtn)
            
            // Center coordinate label
            let coordLabel = UILabel()
            coordLabel.text = String(format: "X: %.0f\nY: %.0f", figureOffsetX, figureOffsetY)
            coordLabel.font = UIFont.systemFont(ofSize: 9, weight: .regular)
            coordLabel.textAlignment = .center
            coordLabel.textColor = .gray
            coordLabel.numberOfLines = 2
            coordLabel.translatesAutoresizingMaskIntoConstraints = false
            
            // Right Y buttons
            let rightYStack = UIStackView()
            rightYStack.axis = .horizontal
            rightYStack.spacing = 2
            rightYStack.distribution = .fillEqually
            
            let upBtn = UIButton(type: .system)
            upBtn.setTitle("↑ Y", for: .normal)
            upBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            upBtn.addAction(UIAction { _ in self.figureOffsetY += 1; self.updateFigure() }, for: .touchUpInside)
            rightYStack.addArrangedSubview(upBtn)
            
            let downBtn = UIButton(type: .system)
            downBtn.setTitle("Y ↓", for: .normal)
            downBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            downBtn.addAction(UIAction { _ in self.figureOffsetY -= 1; self.updateFigure() }, for: .touchUpInside)
            rightYStack.addArrangedSubview(downBtn)
            
            // Add all to main container with equal widths
            container.addArrangedSubview(leftXStack)
            container.addArrangedSubview(coordLabel)
            container.addArrangedSubview(rightYStack)
            
            cell.contentView.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -6),
                cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 42)
            ])
            
            // Store reference to coordinate label for dynamic updates
            self.coordinateLabel = coordLabel
            
            
        case (0, 1):
            // Zoom slider with +/- buttons
            let label = UILabel()
            label.text = "Zoom"
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            let slider = UISlider()
            slider.minimumValue = 0.5
            slider.maximumValue = 3.0
            slider.value = Float(sceneZoom)
            slider.translatesAutoresizingMaskIntoConstraints = false
            
            let valueLabel = UILabel()
            valueLabel.text = String(format: "%.1f×", sceneZoom)
            valueLabel.font = UIFont.systemFont(ofSize: 12)
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
            
            // Minus button for zoom
            let minusBtn = UIButton(type: .system)
            minusBtn.setTitle("−", for: .normal)
            minusBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            minusBtn.translatesAutoresizingMaskIntoConstraints = false
            minusBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
            minusBtn.addAction(UIAction { [weak self] _ in
                let currentZoom = CGFloat(slider.value)
                let newZoom = max(0.5, currentZoom - 0.1)
                slider.value = Float(newZoom)
                valueLabel.text = String(format: "%.1f×", newZoom)
                self?.sceneZoom = newZoom
                self?.editorScene?.updateZoom(newZoom)
            }, for: .touchUpInside)
            
            // Plus button for zoom
            let plusBtn = UIButton(type: .system)
            plusBtn.setTitle("+", for: .normal)
            plusBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            plusBtn.translatesAutoresizingMaskIntoConstraints = false
            plusBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
            plusBtn.addAction(UIAction { [weak self] _ in
                let currentZoom = CGFloat(slider.value)
                let newZoom = min(3.0, currentZoom + 0.1)
                slider.value = Float(newZoom)
                valueLabel.text = String(format: "%.1f×", newZoom)
                self?.sceneZoom = newZoom
                self?.editorScene?.updateZoom(newZoom)
            }, for: .touchUpInside)
            
            slider.addAction(UIAction { [weak self, weak valueLabel] _ in
                let newZoom = CGFloat(slider.value)
                self?.sceneZoom = newZoom
                valueLabel?.text = String(format: "%.1f×", newZoom)
                self?.editorScene?.updateZoom(newZoom)
            }, for: .valueChanged)
            
            cell.contentView.addSubview(label)
            cell.contentView.addSubview(minusBtn)
            cell.contentView.addSubview(slider)
            cell.contentView.addSubview(valueLabel)
            cell.contentView.addSubview(plusBtn)
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                
                minusBtn.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
                minusBtn.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                
                slider.leadingAnchor.constraint(equalTo: minusBtn.trailingAnchor, constant: 4),
                slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -4),
                slider.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                
                valueLabel.trailingAnchor.constraint(equalTo: plusBtn.leadingAnchor, constant: -4),
                valueLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                
                plusBtn.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                plusBtn.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                
                cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
            ])
            
            
        case (1, 0):
            // Figure Scale slider
            addSliderCell(cell, label: "Figure Scale", value: figureScale, min: 0.5, max: 2.0, increment: 0.1, onChange: { [weak self] val in
                self?.figureScale = val
                self?.updateFigure()
            })
            
        case (1, 1):
            // Joint Shape Size slider (was previously at 1, 2)
            addSliderCell(cell, label: "Joint Shape Size", value: jointShapeSize, min: 0.0, max: 30.0, increment: 0.1, onChange: { [weak self] val in
                self?.jointShapeSize = val
                self?.updateFigure()
            })
            
        case (1, 2):
            // Shoulder Width slider (was previously at 1, 3)
            addSliderCell(cell, label: "Shoulder Width", value: shoulderWidthMultiplier, min: 0.0, max: 2.0, increment: 0.1, onChange: { [weak self] val in
                self?.shoulderWidthMultiplier = val
                self?.updateFigure()
            })
            
        case (1, 3):
            // Waist Width slider (was previously at 1, 4)
            addSliderCell(cell, label: "Waist Width", value: waistWidthMultiplier, min: 0.0, max: 2.0, increment: 0.1, onChange: { [weak self] val in
                self?.waistWidthMultiplier = val
                self?.updateFigure()
            })
            
        case (1, 4):
            // Waist Thickness slider - now controls triangle point position (was previously at 1, 5)
            addSliderCell(cell, label: "Waist Point", value: waistThicknessMultiplier, min: 0.0, max: 0.9, increment: 0.1, onChange: { [weak self] val in
                self?.waistThicknessMultiplier = val
                self?.updateFigure()
            })
            
        case (1, 5):
            // Neck Length slider (was previously at 1, 6)
            addSliderCell(cell, label: "Neck Length", value: neckLength, min: 0.5, max: 30.0, increment: 0.1, onChange: { [weak self] val in
                self?.neckLength = val
                self?.updateFigure()
            })
            
        case (1, 6):
            // Neck Width slider (was previously at 1, 7)
            addSliderCell(cell, label: "Neck Width", value: neckWidth, min: 0.5, max: 10.0, increment: 0.1, onChange: { [weak self] val in
                self?.neckWidth = val
                self?.updateFigure()
            })
            
        case (1, 7):
            // Hand Size slider (was previously at 1, 8)
            addSliderCell(cell, label: "Hand Size", value: handSize, min: 0.5, max: 10.0, increment: 0.1, onChange: { [weak self] val in
                self?.handSize = val
                self?.updateFigure()
            })
            
        case (1, 8):
            // Foot Size slider (was previously at 1, 9)
            addSliderCell(cell, label: "Foot Size", value: footSize, min: 0.5, max: 10.0, increment: 0.1, onChange: { [weak self] val in
                self?.footSize = val
                self?.updateFigure()
            })
            
        // Skeleton size sliders - NEW SECTION 4
        case (4, 0):
            addSliderCell(cell, label: "Torso Skeleton", value: skeletonSizeTorso, min: 0.0, max: 5.0, increment: 0.1, onChange: { [weak self] val in
                self?.skeletonSizeTorso = val
                self?.updateFigure()
            })
            
        case (4, 1):
            addSliderCell(cell, label: "Arm Skeleton", value: skeletonSizeArm, min: 0.0, max: 5.0, increment: 0.1, onChange: { [weak self] val in
                self?.skeletonSizeArm = val
                self?.updateFigure()
            })
            
        case (4, 2):
            addSliderCell(cell, label: "Leg Skeleton", value: skeletonSizeLeg, min: 0.0, max: 5.0, increment: 0.1, onChange: { [weak self] val in
                self?.skeletonSizeLeg = val
                self?.updateFigure()
            })
            
        // Stroke sliders - SECTION 2
        case (2, 0):
            // Stroke - Joints
            addSliderCell(cell, label: "Joints", value: strokeThicknessJoints, min: 0.0, max: 10.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessJoints = val
                self?.updateFigure()
            })
            
        case (2, 1):
            // Stroke - Upper Torso
            addSliderCell(cell, label: "Upper Torso", value: strokeThicknessUpperTorso, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessUpperTorso = val
                self?.updateFigure()
            })
            
        case (2, 2):
            // Stroke - Lower Torso
            addSliderCell(cell, label: "Lower Torso", value: strokeThicknessLowerTorso, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessLowerTorso = val
                self?.updateFigure()
            })
            
        case (2, 3):
            // Stroke - Bicep
            addSliderCell(cell, label: "Bicep", value: strokeThicknessBicep, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessBicep = val
                self?.updateFigure()
            })
            
        case (2, 4):
            // Stroke - Tricep
            addSliderCell(cell, label: "Tricep", value: strokeThicknessTricep, min: 0.0, max: 15.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessTricep = val
                self?.updateFigure()
            })
            
        case (2, 5):
            // Stroke - Lower Arms
            addSliderCell(cell, label: "Lower Arms", value: strokeThicknessLowerArms, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessLowerArms = val
                self?.updateFigure()
            })
            
        case (2, 6):
            // Stroke - Upper Legs
            addSliderCell(cell, label: "Upper Legs", value: strokeThicknessUpperLegs, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessUpperLegs = val
                self?.updateFigure()
            })
            
        case (2, 6):
            // Stroke - Lower Legs
            addSliderCell(cell, label: "Lower Legs", value: strokeThicknessLowerLegs, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessLowerLegs = val
                self?.updateFigure()
            })
            
        case (2, 7):
            // Stroke - Full Torso
            addSliderCell(cell, label: "Full Torso", value: strokeThicknessFullTorso, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessFullTorso = val
                self?.updateFigure()
            })
            
        case (2, 8):
            // Stroke - Deltoids
            addSliderCell(cell, label: "Deltoids", value: strokeThicknessDeltoids, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessDeltoids = val
                self?.updateFigure()
            })
            
        case (2, 9):
            // Stroke - Trapezius
            addSliderCell(cell, label: "Trapezius", value: strokeThicknessTrapezius, min: 0.0, max: 20.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessTrapezius = val
                self?.updateFigure()
            })
            
        // Fusiform sliders - NOW SECTION 3
        case (3, 0): addSliderCell(cell, label: "Upper Torso", value: fusiformUpperTorso, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformUpperTorso = val; self?.updateFigure() })
        case (3, 1): addSliderCell(cell, label: "Lower Torso", value: fusiformLowerTorso, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformLowerTorso = val; self?.updateFigure() })
        case (3, 2): addSliderCell(cell, label: "Bicep", value: fusiformBicep, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformBicep = val; self?.updateFigure() })
        case (3, 3): addSliderCell(cell, label: "Tricep", value: fusiformTricep, min: 0, max: 5, increment: 0.1, onChange: { [weak self] val in self?.fusiformTricep = val; self?.updateFigure() })
        case (3, 4): addSliderCell(cell, label: "Lower Arms", value: fusiformLowerArms, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformLowerArms = val; self?.updateFigure() })
        case (3, 5): addSliderCell(cell, label: "Upper Legs", value: fusiformUpperLegs, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformUpperLegs = val; self?.updateFigure() })
        case (3, 6): addSliderCell(cell, label: "Lower Legs", value: fusiformLowerLegs, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformLowerLegs = val; self?.updateFigure() })
        case (3, 7): addSliderCell(cell, label: "Shoulders", value: fusiformShoulders, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformShoulders = val; self?.updateFigure() })
        case (3, 8): addSliderCell(cell, label: "Deltoids", value: fusiformDeltoids, min: 0, max: 10, increment: 0.1, onChange: { [weak self] val in self?.fusiformDeltoids = val; self?.updateFigure() })
        
        // Peak position sliders
        case (3, 9): addSliderCell(cell, label: "Peak Bicep", value: peakPositionBicep, min: 0.1, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionBicep = val; self?.updateFigure() })
        case (3, 10): addSliderCell(cell, label: "Peak Tricep", value: peakPositionTricep, min: 0.1, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionTricep = val; self?.updateFigure() })
        case (3, 11): addSliderCell(cell, label: "Peak Lower Arm", value: peakPositionLowerArms, min: 0.1, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionLowerArms = val; self?.updateFigure() })
        case (3, 12): addSliderCell(cell, label: "Peak Upper Leg", value: peakPositionUpperLegs, min: 0.1, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionUpperLegs = val; self?.updateFigure() })
        case (3, 13): addSliderCell(cell, label: "Peak Lower Leg", value: peakPositionLowerLegs, min: 0.1, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionLowerLegs = val; self?.updateFigure() })
        case (3, 14): addSliderCell(cell, label: "Peak Upper Torso", value: peakPositionUpperTorso, min: 0.0, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionUpperTorso = val; self?.updateFigure() })
        case (3, 15): addSliderCell(cell, label: "Peak Lower Torso", value: peakPositionLowerTorso, min: 0.1, max: 1.0, increment: 0.05, onChange: { [weak self] val in self?.peakPositionLowerTorso = val; self?.updateFigure() })
        case (3, 16): addSliderCell(cell, label: "Peak Deltoids", value: peakPositionDeltoids, min: 0.1, max: 0.9, increment: 0.05, onChange: { [weak self] val in self?.peakPositionDeltoids = val; self?.updateFigure() })
        case (3, 17): addSegmentedControlCell(cell, label: "Arm Muscle Side", value: armMuscleSide, options: ["normal", "flipped", "both"], onChange: { [weak self] val in self?.armMuscleSide = val; self?.updateFigure() })
        
        // Joint sliders - SECTION 5 (was previously section 4)
        case (5, 0): addSliderCell(cell, label: "Head", value: neckRotation, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.neckRotation = val; self?.updateFigure() })
        case (5, 1): addSliderCell(cell, label: "L Shoulder", value: leftShoulderAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.leftShoulderAngle = val; self?.updateFigure() })
        case (5, 2): addSliderCell(cell, label: "R Shoulder", value: rightShoulderAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.rightShoulderAngle = val; self?.updateFigure() })
        case (5, 3): addSliderCell(cell, label: "L Elbow", value: leftElbowAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.leftElbowAngle = val; self?.updateFigure() })
        case (5, 4): addSliderCell(cell, label: "R Elbow", value: rightElbowAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.rightElbowAngle = val; self?.updateFigure() })
        case (5, 5): addSliderCell(cell, label: "L Upper Leg", value: leftKneeAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.leftKneeAngle = val; self?.updateFigure() })
        case (5, 6): addSliderCell(cell, label: "R Upper Leg", value: rightKneeAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.rightKneeAngle = val; self?.updateFigure() })
        case (5, 7): addSliderCell(cell, label: "L Calf", value: leftFootAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.leftFootAngle = val; self?.updateFigure() })
        case (5, 8): addSliderCell(cell, label: "R Calf", value: rightFootAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.rightFootAngle = val; self?.updateFigure() })
        case (5, 9): addSliderCell(cell, label: "Waist Rotation", value: waistTorsoAngle, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.waistTorsoAngle = val; self?.updateFigure() })
        case (5, 10): addSliderCell(cell, label: "Mid Torso Rotation", value: lowerTorsoRotation, min: -180, max: 180, increment: 1, onChange: { [weak self] val in self?.lowerTorsoRotation = val; self?.updateFigure() })
        
        // Color picker buttons - SECTION 6 (was previously section 5)
        case (6, 0):
            addColorButton(cell, label: "Head", colorKey: "head")
        case (6, 1):
            addColorButton(cell, label: "Torso", colorKey: "torso")
        case (6, 2):
            addColorButton(cell, label: "L Shoulder", colorKey: "leftShoulder")
        case (6, 3):
            addColorButton(cell, label: "R Shoulder", colorKey: "rightShoulder")
        case (6, 4):
            addColorButton(cell, label: "L Upper Arm", colorKey: "leftUpperArm")
        case (6, 5):
            addColorButton(cell, label: "R Upper Arm", colorKey: "rightUpperArm")
        case (6, 6):
            addColorButton(cell, label: "L Lower Arm", colorKey: "leftLowerArm")
        case (6, 7):
            addColorButton(cell, label: "R Lower Arm", colorKey: "rightLowerArm")
        case (6, 8):
            addColorButton(cell, label: "L Upper Leg", colorKey: "leftUpperLeg")
        case (6, 9):
            addColorButton(cell, label: "R Upper Leg", colorKey: "rightUpperLeg")
        case (6, 10):
            addColorButton(cell, label: "L Lower Leg", colorKey: "leftLowerLeg")
        case (6, 11):
            addColorButton(cell, label: "R Lower Leg", colorKey: "rightLowerLeg")
            
        case (7, 0):
            // Frames label with Save and Load buttons on same row
            let container = UIStackView()
            container.axis = .horizontal
            container.spacing = 8
            container.distribution = .fill
            container.translatesAutoresizingMaskIntoConstraints = false
            
            // Frames label
            let framesLabel = UILabel()
            framesLabel.text = "Frames:"
            framesLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            framesLabel.textColor = .darkGray
            framesLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            // Save button
            let saveBtn = UIButton(type: .system)
            saveBtn.setTitle("SAVE", for: .normal)
            saveBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            saveBtn.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
            saveBtn.setTitleColor(.white, for: .normal)
            saveBtn.layer.cornerRadius = 4
            saveBtn.addTarget(self, action: #selector(savePressed), for: .touchUpInside)
            
            // Load button
            let loadBtn = UIButton(type: .system)
            loadBtn.setTitle("LOAD", for: .normal)
            loadBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            loadBtn.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)
            loadBtn.setTitleColor(.white, for: .normal)
            loadBtn.layer.cornerRadius = 4
            loadBtn.addTarget(self, action: #selector(loadPressed), for: .touchUpInside)
            
            container.addArrangedSubview(framesLabel)
            container.addArrangedSubview(saveBtn)
            container.addArrangedSubview(loadBtn)
            
            cell.contentView.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
                saveBtn.widthAnchor.constraint(equalToConstant: 60),
                loadBtn.widthAnchor.constraint(equalToConstant: 60)
            ])
            
        case (7, 1):
            // Objects label with Add Object button (was previously 6, 1)
            let container = UIStackView()
            container.axis = .horizontal
            container.spacing = 8
            container.distribution = .fill
            container.translatesAutoresizingMaskIntoConstraints = false
            
            // Objects label
            let objectsLabel = UILabel()
            objectsLabel.text = "Objects:"
            objectsLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            objectsLabel.textColor = .darkGray
            objectsLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            // Add object button - same width as SAVE/LOAD buttons
            let btn = UIButton(type: .system)
            btn.setTitle("+ ADD", for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            btn.backgroundColor = UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1.0)
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 4
            btn.addTarget(self, action: #selector(addObjectPressed), for: .touchUpInside)
            
            container.addArrangedSubview(objectsLabel)
            container.addArrangedSubview(btn)
            
            cell.contentView.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
                btn.widthAnchor.constraint(equalToConstant: 60)
            ])
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 || indexPath.section == 6 || indexPath.section == 7 {
            return UITableView.automaticDimension
        }
        return UITableView.automaticDimension
    }
    
    private func addSliderCell(_ cell: UITableViewCell, label: String, value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat, increment: CGFloat = 1.0, onChange: @escaping (CGFloat) -> Void) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let slider = UISlider()
        slider.minimumValue = Float(minVal)
        slider.maximumValue = Float(maxVal)
        slider.value = Float(value)
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        // Determine if we should show decimals based on increment
        let showDecimals = increment < 1.0
        let valLbl = UILabel()
        if showDecimals {
            valLbl.text = String(format: "%.1f", value)
        } else {
            valLbl.text = String(format: "%.0f", value)
        }
        valLbl.font = UIFont.systemFont(ofSize: 11)
        valLbl.translatesAutoresizingMaskIntoConstraints = false
        valLbl.widthAnchor.constraint(equalToConstant: 50).isActive = true
        
        // Minus button
        let minusBtn = UIButton(type: .system)
        minusBtn.setTitle("−", for: .normal)
        minusBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        minusBtn.translatesAutoresizingMaskIntoConstraints = false
        minusBtn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        minusBtn.addAction(UIAction { _ in
            let currentVal = CGFloat(slider.value)
            let newVal = max(minVal, currentVal - increment)
            slider.value = Float(newVal)
            if showDecimals {
                valLbl.text = String(format: "%.1f", newVal)
            } else {
                valLbl.text = String(format: "%.0f", newVal)
            }
            onChange(newVal)
        }, for: .touchUpInside)
        
        // Plus button
        let plusBtn = UIButton(type: .system)
        plusBtn.setTitle("+", for: .normal)
        plusBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        plusBtn.translatesAutoresizingMaskIntoConstraints = false
        plusBtn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        plusBtn.addAction(UIAction { _ in
            let currentVal = CGFloat(slider.value)
            let newVal = min(maxVal, currentVal + increment)
            slider.value = Float(newVal)
            if showDecimals {
                valLbl.text = String(format: "%.1f", newVal)
            } else {
                valLbl.text = String(format: "%.0f", newVal)
            }
            onChange(newVal)
        }, for: .touchUpInside)
        
        slider.addAction(UIAction { _ in
            let newVal = CGFloat(slider.value)
            if showDecimals {
                valLbl.text = String(format: "%.1f", newVal)
            } else {
                valLbl.text = String(format: "%.0f", newVal)
            }
            onChange(newVal)
        }, for: .valueChanged)
        
        cell.contentView.addSubview(lbl)
        cell.contentView.addSubview(minusBtn)
        cell.contentView.addSubview(slider)
        cell.contentView.addSubview(valLbl)
        cell.contentView.addSubview(plusBtn)
        
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            lbl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            minusBtn.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            minusBtn.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            slider.leadingAnchor.constraint(equalTo: minusBtn.trailingAnchor, constant: 4),
            slider.trailingAnchor.constraint(equalTo: valLbl.leadingAnchor, constant: -4),
            slider.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            valLbl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            plusBtn.leadingAnchor.constraint(equalTo: valLbl.trailingAnchor, constant: 4),
            plusBtn.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            plusBtn.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    private func addSegmentedControlCell(_ cell: UITableViewCell, label: String, value: String, options: [String], onChange: @escaping (String) -> Void) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let segmentedControl = UISegmentedControl(items: options)
        segmentedControl.selectedSegmentIndex = options.firstIndex(of: value) ?? 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        segmentedControl.addAction(UIAction { _ in
            let selectedOption = options[segmentedControl.selectedSegmentIndex]
            onChange(selectedOption)
        }, for: .valueChanged)
        
        cell.contentView.addSubview(lbl)
        cell.contentView.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            lbl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            segmentedControl.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            segmentedControl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            segmentedControl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    private func addColorButton(_ cell: UITableViewCell, label: String, colorKey: String) {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 14)
        
        let colorBtn = UIButton(type: .system)
        colorBtn.backgroundColor = bodyPartColors[colorKey] ?? .black
        colorBtn.layer.cornerRadius = 6
        colorBtn.layer.borderColor = UIColor.black.cgColor
        colorBtn.layer.borderWidth = 1
        colorBtn.translatesAutoresizingMaskIntoConstraints = false
        colorBtn.addTarget(self, action: #selector(colorButtonPressed(_:)), for: .touchUpInside)
        colorBtn.tag = colorKey.hashValue
        pendingColorButton = colorBtn
        
        container.addArrangedSubview(labelView)
        container.addArrangedSubview(UIView())  // Spacer
        container.addArrangedSubview(colorBtn)
        
        cell.contentView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            colorBtn.widthAnchor.constraint(equalToConstant: 44),
            colorBtn.heightAnchor.constraint(equalToConstant: 44),
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    // MARK: - Actions
    @objc private func toggleJoints(_ sender: UISwitch) {
        showInteractiveJoints = sender.isOn
        updateFigure()
    }
    
    @objc private func toggleJointsFromHeader(_ sender: UIButton) {
        showInteractiveJoints = !showInteractiveJoints
        sender.tintColor = showInteractiveJoints ? .white : UIColor.white.withAlphaComponent(0.5)
        updateFigure()
    }
    
    @objc private func toggleInteractiveControls(_ sender: UIButton) {
        // Toggle joint and object control visibility while preserving zoom
        let currentZoom = sceneZoom  // Save current zoom
        showInteractiveJoints = !showInteractiveJoints
        showObjectControls = !showObjectControls  // Toggle object controls too
        sender.tintColor = showInteractiveJoints ? .white : UIColor.white.withAlphaComponent(0.5)
        updateFigure()
        // Update object control visibility
        updateObjectControlVisibility()
        sceneZoom = currentZoom  // Restore zoom
        editorScene?.currentZoom = currentZoom
        editorScene?.updateZoom(currentZoom)
    }
    
    /// Update the visibility of object control dots based on showObjectControls setting
    private func updateObjectControlVisibility() {
        guard let editorScene = editorScene else { return }
        
        // Find all objects and update their control dots
        editorScene.children.forEach { node in
            if node.name?.hasPrefix("object_") == true {
                if showObjectControls {
                    // Check if dots exist
                    let hasDots = node.children.contains { child in
                        child.name?.hasPrefix("object_move_") == true ||
                        child.name?.hasPrefix("object_resize_") == true ||
                        child.name?.hasPrefix("object_rotate_") == true ||
                        child.name?.hasPrefix("object_delete_") == true
                    }
                    
                    if !hasDots {
                        // Dots don't exist - create them
                        if node is SKShapeNode {
                            // It's a box
                            let width = (node.userData?["width"] as? CGFloat) ?? 50
                            let height = (node.userData?["height"] as? CGFloat) ?? 50
                            addBoxObjectControls(to: node, in: editorScene, width: width, height: height)
                        } else if let spriteNode = node as? SKSpriteNode {
                            // It's an image object
                            let asset = (node.userData?["assetName"] as? String) ?? node.name ?? "Object"
                            addImageObjectControls(to: spriteNode, assetName: asset)
                        }
                    } else {
                        // Dots exist, just show them
                        node.children.forEach { child in
                            if let dot = child as? SKShapeNode, child.name?.hasPrefix("object_") == true {
                                dot.isHidden = false
                            }
                        }
                    }
                } else {
                    // Hide all dots
                    node.children.forEach { child in
                        if let dot = child as? SKShapeNode, child.name?.hasPrefix("object_") == true {
                            dot.isHidden = true
                        }
                    }
                }
            }
        }
    }
    
    private func addImageObjectControls(to sprite: SKSpriteNode, assetName: String) {
        // Add center dot for moving the object
        let moveDot = SKShapeNode(circleOfRadius: 3)
        moveDot.fillColor = .white
        moveDot.strokeColor = .darkGray
        moveDot.lineWidth = 1
        moveDot.position = CGPoint(x: 0, y: 0)
        moveDot.name = "object_move_\(assetName)"
        moveDot.zPosition = 12
        sprite.addChild(moveDot)
        
        // Add rotate dot
        let rotateDot = SKShapeNode(circleOfRadius: 3)
        rotateDot.fillColor = .yellow
        rotateDot.strokeColor = .darkGray
        rotateDot.lineWidth = 1
        rotateDot.position = CGPoint(x: 25, y: 25)
        rotateDot.name = "object_rotate_\(assetName)"
        rotateDot.zPosition = 12
        sprite.addChild(rotateDot)
        
        // Add resize dot
        let resizeDot = SKShapeNode(circleOfRadius: 3)
        resizeDot.fillColor = .cyan
        resizeDot.strokeColor = .darkGray
        resizeDot.lineWidth = 1
        resizeDot.position = CGPoint(x: 25, y: -25)
        resizeDot.name = "object_resize_\(assetName)"
        resizeDot.zPosition = 12
        sprite.addChild(resizeDot)
        
        // Add delete dot
        let deleteDot = SKShapeNode(circleOfRadius: 3)
        deleteDot.fillColor = .red
        deleteDot.strokeColor = .darkGray
        deleteDot.lineWidth = 1
        deleteDot.position = CGPoint(x: -25, y: 25)
        deleteDot.name = "object_delete_\(assetName)"
        deleteDot.zPosition = 12
        sprite.addChild(deleteDot)
    }
    
    @objc private func toggleSectionExpansion(_ gesture: UITapGestureRecognizer) {
        guard let headerView = gesture.view else { return }
        let section = headerView.tag
        
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
        
        // Reload the entire section with animation
        controlsTableView.reloadSections([section], with: .fade)
    }
    
    @objc private func refreshPressed() {
        print("🎮 Refreshing stick figure to default Stand frame")
        figureScale = 1.0  // Reset figure scale to default
        sceneZoom = 1.0  // Reset zoom to default
        editorScene?.updateZoom(1.0)  // Update editor scene zoom
        loadStandFrameValues()
        
        // Remove all objects from the editor scene
        if let editorScene = editorScene {
            editorScene.children.forEach { node in
                if node.name?.hasPrefix("object_") == true {
                    node.removeFromParent()
                }
            }
            print("🎮 Cleared all objects from scene")
        }
        
        controlsTableView.reloadData()  // Reload table to show updated values
        updateFigure()
    }
    
    private func loadStandFrameValues() {
        // Ensure gameState is initialized with a standFrame
        guard let gameState = gameState else {
            print("🎮 ERROR: No gameState provided to editor")
            return
        }
        
        // If standFrame isn't loaded yet, initialize it
        if gameState.standFrame == nil {
            print("🎮 Initializing standFrame in gameState...")
            gameState.initializeRoom("level_1")  // Load default Stand frame
            print("🎮 After initializeRoom: standFrame = \(gameState.standFrame != nil ? "SET" : "STILL NIL")")
        }
        
        // Load the default Stand frame from animations.json
        if let standFrame = gameState.standFrame {
            
            // Load ALL scale and thickness values from standFrame
            figureScale = standFrame.scale
            // Load individual stroke thickness values from standFrame
            strokeThicknessJoints = standFrame.strokeThicknessJoints
            strokeThicknessUpperTorso = standFrame.strokeThicknessUpperTorso
            strokeThicknessLowerTorso = standFrame.strokeThicknessLowerTorso
            strokeThicknessBicep = standFrame.strokeThicknessBicep
            strokeThicknessTricep = standFrame.strokeThicknessTricep
            strokeThicknessLowerArms = standFrame.strokeThicknessLowerArms
            strokeThicknessUpperLegs = standFrame.strokeThicknessUpperLegs
            strokeThicknessLowerLegs = standFrame.strokeThicknessLowerLegs
            strokeThicknessFullTorso = standFrame.strokeThicknessFullTorso
            strokeThicknessDeltoids = standFrame.strokeThicknessDeltoids
            strokeThicknessTrapezius = standFrame.strokeThicknessTrapezius
            // Note: jointShapeSize is editor-only property, not in StickFigure2D
            skeletonSizeTorso = standFrame.skeletonSizeTorso
            skeletonSizeArm = standFrame.skeletonSizeArm
            skeletonSizeLeg = standFrame.skeletonSizeLeg
            shoulderWidthMultiplier = standFrame.shoulderWidthMultiplier
            waistWidthMultiplier = standFrame.waistWidthMultiplier
            waistThicknessMultiplier = standFrame.waistThicknessMultiplier
            neckLength = standFrame.neckLength
            neckWidth = standFrame.neckWidth
            handSize = standFrame.handSize
            footSize = standFrame.footSize
            
            // Fusiforms - load from standFrame
            fusiformUpperTorso = standFrame.fusiformUpperTorso
            fusiformLowerTorso = standFrame.fusiformLowerTorso
            fusiformBicep = standFrame.fusiformBicep
            fusiformTricep = standFrame.fusiformTricep
            fusiformLowerArms = standFrame.fusiformLowerArms
            fusiformUpperLegs = standFrame.fusiformUpperLegs
            fusiformLowerLegs = standFrame.fusiformLowerLegs
            fusiformShoulders = standFrame.fusiformShoulders
            fusiformDeltoids = standFrame.fusiformDeltoids
            
            // Peak positions - load from standFrame
            peakPositionBicep = standFrame.peakPositionBicep
            peakPositionTricep = standFrame.peakPositionTricep
            peakPositionLowerArms = standFrame.peakPositionLowerArms
            peakPositionUpperLegs = standFrame.peakPositionUpperLegs
            peakPositionLowerLegs = standFrame.peakPositionLowerLegs
            peakPositionUpperTorso = standFrame.peakPositionUpperTorso
            peakPositionLowerTorso = standFrame.peakPositionLowerTorso
            peakPositionDeltoids = standFrame.peakPositionDeltoids
            armMuscleSide = standFrame.armMuscleSide
            
            // Load ALL angles from standFrame
            neckRotation = CGFloat(standFrame.headAngle)
            upperTorsoRotation = CGFloat(standFrame.torsoRotationAngle)
            lowerTorsoRotation = CGFloat(standFrame.midTorsoAngle)
            waistTorsoAngle = CGFloat(standFrame.waistTorsoAngle)  // Load waist rotation
            torsoRotation = CGFloat(standFrame.waistTorsoAngle)  // Also update torsoRotation for compatibility
            leftShoulderAngle = CGFloat(standFrame.leftShoulderAngle)
            leftElbowAngle = CGFloat(standFrame.leftElbowAngle)
            rightShoulderAngle = CGFloat(standFrame.rightShoulderAngle)
            rightElbowAngle = CGFloat(standFrame.rightElbowAngle)
            leftHipAngle = CGFloat(standFrame.leftHipAngle)
            rightHipAngle = CGFloat(standFrame.rightHipAngle)
            leftKneeAngle = CGFloat(standFrame.leftKneeAngle)
            rightKneeAngle = CGFloat(standFrame.rightKneeAngle)
            leftFootAngle = CGFloat(standFrame.leftFootAngle)
            rightFootAngle = CGFloat(standFrame.rightFootAngle)
            
            // Reset position to Stand frame's waist position (centered)
            figureOffsetX = 0
            figureOffsetY = 0
            
            // Reset colors to black (Stand frame default - avoid SwiftUI Color conversion in UIKit)
            bodyPartColors = [
                "head": .black,
                "torso": .black,
                "leftUpperArm": .black,
                "rightUpperArm": .black,
                "leftLowerArm": .black,
                "rightLowerArm": .black,
                "leftUpperLeg": .black,
                "rightUpperLeg": .black,
                "leftLowerLeg": .black,
                "rightLowerLeg": .black
            ]
            
            //print("🎮 ✓ Loaded Stand frame - scale:\(standFrame.scale), fusiform: bicep=\(standFrame.fusiformBicep), tricep=\(standFrame.fusiformTricep), angles: shoulder:\(standFrame.leftShoulderAngle)°, elbow:\(standFrame.leftElbowAngle)°, knee:\(standFrame.leftKneeAngle)°")
        }
    }
    
    // MARK: - Update Figure
    func updateFigure() {
        //print("🎮 DEBUG updateFigure: fusiformShoulders=\(fusiformShoulders), skeletonSizeTorso=\(skeletonSizeTorso) skeletonSizeArm=\(skeletonSizeArm) skeletonSizeLeg=\(skeletonSizeLeg) jointShapeSize=\(jointShapeSize)")
        
        // Update coordinate label if it exists
        coordinateLabel?.text = String(format: "X: %.0f\nY: %.0f", figureOffsetX, figureOffsetY)
        
        editorScene?.updateWithValues(
            figureScale: figureScale,
            skeletonSizeTorso: skeletonSizeTorso,
            skeletonSizeArm: skeletonSizeArm,
            skeletonSizeLeg: skeletonSizeLeg,
            jointShapeSize: jointShapeSize,
            shoulderWidthMultiplier: shoulderWidthMultiplier,
            waistWidthMultiplier: waistWidthMultiplier,
            waistThicknessMultiplier: waistThicknessMultiplier,
            neckLength: neckLength,
            neckWidth: neckWidth,
            handSize: handSize,
            footSize: footSize,
            fusiformUpperTorso: fusiformUpperTorso,
            fusiformLowerTorso: fusiformLowerTorso,
            fusiformBicep: fusiformBicep,
            fusiformTricep: fusiformTricep,
            fusiformLowerArms: fusiformLowerArms,
            fusiformUpperLegs: fusiformUpperLegs,
            fusiformLowerLegs: fusiformLowerLegs,
            fusiformShoulders: fusiformShoulders,
            fusiformDeltoids: fusiformDeltoids,
            peakPositionBicep: peakPositionBicep,
            peakPositionTricep: peakPositionTricep,
            peakPositionLowerArms: peakPositionLowerArms,
            peakPositionUpperLegs: peakPositionUpperLegs,
            peakPositionLowerLegs: peakPositionLowerLegs,
            peakPositionUpperTorso: peakPositionUpperTorso,
            peakPositionLowerTorso: peakPositionLowerTorso,
            peakPositionDeltoids: peakPositionDeltoids,
            armMuscleSide: armMuscleSide,
            figureOffsetX: figureOffsetX,
            figureOffsetY: figureOffsetY,
            neckRotation: neckRotation,
            upperTorsoRotation: upperTorsoRotation,
            lowerTorsoRotation: lowerTorsoRotation,
            waistTorsoAngle: waistTorsoAngle,
            torsoRotation: torsoRotation,
            leftShoulderAngle: leftShoulderAngle,
            leftElbowAngle: leftElbowAngle,
            rightShoulderAngle: rightShoulderAngle,
            rightElbowAngle: rightElbowAngle,
            leftHipAngle: leftHipAngle,
            leftKneeAngle: leftKneeAngle,
            rightHipAngle: rightHipAngle,
            rightKneeAngle: rightKneeAngle,
            leftFootAngle: leftFootAngle,
            rightFootAngle: rightFootAngle,
            strokeThicknessJoints: strokeThicknessJoints,
            strokeThicknessUpperTorso: strokeThicknessUpperTorso,
            strokeThicknessLowerTorso: strokeThicknessLowerTorso,
            strokeThicknessBicep: strokeThicknessBicep,
            strokeThicknessTricep: strokeThicknessTricep,
            strokeThicknessLowerArms: strokeThicknessLowerArms,
            strokeThicknessUpperLegs: strokeThicknessUpperLegs,
            strokeThicknessLowerLegs: strokeThicknessLowerLegs,
            strokeThicknessFullTorso: strokeThicknessFullTorso,
            strokeThicknessDeltoids: strokeThicknessDeltoids,
            strokeThicknessTrapezius: strokeThicknessTrapezius,
            bodyPartColors: bodyPartColors,
            showInteractiveJoints: showInteractiveJoints
        )
    }
    
    // MARK: - Button Actions
    @objc private func savePressed() {
        print("🎮 Save button pressed")
        let alert = UIAlertController(title: "Save Frame", message: "Enter name and frame number", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Frame name"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Frame number"
            textField.keyboardType = .numberPad
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let frameNumberStr = alert.textFields?[1].text ?? "0"
            let frameNumber = Int(frameNumberStr) ?? 0
            
            // Create a temporary StickFigure2D with current angles to use with SavedEditFrame initializer
            var tempPose = self.gameState?.standFrame ?? StickFigure2D()
            tempPose.headAngle = self.neckRotation
            tempPose.torsoRotationAngle = self.upperTorsoRotation  // Upper torso rotation around neck (purple dot - minute hand)
            tempPose.midTorsoAngle = self.lowerTorsoRotation       // Upper torso rotation around midTorso
            tempPose.waistTorsoAngle = self.waistTorsoAngle        // Entire upper body rotation around waist (orange dot)
            tempPose.leftShoulderAngle = self.leftShoulderAngle
            tempPose.leftElbowAngle = self.leftElbowAngle
            tempPose.rightShoulderAngle = self.rightShoulderAngle
            tempPose.rightElbowAngle = self.rightElbowAngle
            tempPose.leftHipAngle = self.leftHipAngle
            tempPose.rightHipAngle = self.rightHipAngle
            tempPose.leftKneeAngle = self.leftKneeAngle
            tempPose.rightKneeAngle = self.rightKneeAngle
            tempPose.leftFootAngle = self.leftFootAngle
            tempPose.rightFootAngle = self.rightFootAngle
            // Set all the fusiform and multiplier properties
            tempPose.fusiformShoulders = self.fusiformShoulders
            tempPose.peakPositionBicep = self.peakPositionBicep
            tempPose.peakPositionTricep = self.peakPositionTricep
            tempPose.peakPositionLowerArms = self.peakPositionLowerArms
            tempPose.peakPositionUpperLegs = self.peakPositionUpperLegs
            tempPose.peakPositionLowerLegs = self.peakPositionLowerLegs
            tempPose.peakPositionUpperTorso = self.peakPositionUpperTorso
            tempPose.peakPositionLowerTorso = self.peakPositionLowerTorso
            tempPose.shoulderWidthMultiplier = self.shoulderWidthMultiplier
            tempPose.waistWidthMultiplier = self.waistWidthMultiplier
            tempPose.waistThicknessMultiplier = self.waistThicknessMultiplier
            tempPose.skeletonSizeTorso = self.skeletonSizeTorso
            tempPose.skeletonSizeArm = self.skeletonSizeArm
            tempPose.skeletonSizeLeg = self.skeletonSizeLeg
            tempPose.neckLength = self.neckLength
            tempPose.neckWidth = self.neckWidth
            tempPose.handSize = self.handSize
            tempPose.footSize = self.footSize
            // Set individual stroke thickness values
            tempPose.strokeThicknessJoints = self.strokeThicknessJoints
            tempPose.strokeThicknessUpperTorso = self.strokeThicknessUpperTorso
            tempPose.strokeThicknessLowerTorso = self.strokeThicknessLowerTorso
            tempPose.strokeThicknessBicep = self.strokeThicknessBicep
            tempPose.strokeThicknessTricep = self.strokeThicknessTricep
            tempPose.strokeThicknessLowerArms = self.strokeThicknessLowerArms
            tempPose.strokeThicknessUpperLegs = self.strokeThicknessUpperLegs
            tempPose.strokeThicknessLowerLegs = self.strokeThicknessLowerLegs
            tempPose.strokeThicknessFullTorso = self.strokeThicknessFullTorso
            tempPose.strokeThicknessDeltoids = self.strokeThicknessDeltoids
            tempPose.strokeThicknessTrapezius = self.strokeThicknessTrapezius
            
            // Create EditModeValues to use with SavedEditFrame initializer
            let editValues = EditModeValues(
                figureScale: self.figureScale,
                fusiformUpperTorso: self.fusiformUpperTorso,
                fusiformLowerTorso: self.fusiformLowerTorso,
                fusiformBicep: self.fusiformBicep,
                fusiformTricep: self.fusiformTricep,
                fusiformLowerArms: self.fusiformLowerArms,
                fusiformUpperLegs: self.fusiformUpperLegs,
                fusiformLowerLegs: self.fusiformLowerLegs,
                fusiformShoulders: self.fusiformShoulders,
                fusiformDeltoids: self.fusiformDeltoids,
                peakPositionBicep: self.peakPositionBicep,
                peakPositionTricep: self.peakPositionTricep,
                peakPositionLowerArms: self.peakPositionLowerArms,
                peakPositionUpperLegs: self.peakPositionUpperLegs,
                peakPositionLowerLegs: self.peakPositionLowerLegs,
                peakPositionUpperTorso: self.peakPositionUpperTorso,
                peakPositionLowerTorso: self.peakPositionLowerTorso,
                peakPositionDeltoids: self.peakPositionDeltoids,
                skeletonSizeTorso: self.skeletonSizeTorso,
                skeletonSizeArm: self.skeletonSizeArm,
                skeletonSizeLeg: self.skeletonSizeLeg,
                jointShapeSize: self.jointShapeSize,
                shoulderWidthMultiplier: self.shoulderWidthMultiplier,
                waistWidthMultiplier: self.waistWidthMultiplier,
                waistThicknessMultiplier: self.waistThicknessMultiplier,
                neckLength: self.neckLength,
                neckWidth: self.neckWidth,
                handSize: self.handSize,
                footSize: self.footSize,
                strokeThicknessJoints: self.strokeThicknessJoints,
                strokeThicknessUpperTorso: self.strokeThicknessUpperTorso,
                strokeThicknessLowerTorso: self.strokeThicknessLowerTorso,
                strokeThicknessBicep: self.strokeThicknessBicep,
                strokeThicknessTricep: self.strokeThicknessTricep,
                strokeThicknessLowerArms: self.strokeThicknessLowerArms,
                strokeThicknessUpperLegs: self.strokeThicknessUpperLegs,
                strokeThicknessLowerLegs: self.strokeThicknessLowerLegs,
                strokeThicknessFullTorso: self.strokeThicknessFullTorso,
                strokeThicknessDeltoids: self.strokeThicknessDeltoids,
                strokeThicknessTrapezius: self.strokeThicknessTrapezius,
                armMuscleSide: self.armMuscleSide,
                showGrid: true,
                showJoints: self.showInteractiveJoints,
                positionX: self.figureOffsetX,
                positionY: self.figureOffsetY,
                bodyPartColors: self.bodyPartColors,
                showInteractiveJoints: self.showInteractiveJoints
            )
            
            // Extract objects from the editor scene (both image sprites and box shapes)
            var frameObjects: [EditorObject] = []
            if let editorScene = self.editorScene {
                for node in editorScene.children {
                    // Handle image objects (SKSpriteNode)
                    if let sprite = node as? SKSpriteNode, sprite.name?.hasPrefix("object_") == true {
                        let assetName = (sprite.userData?["assetName"] as? String) ?? "Unknown"
                        let editorObject = EditorObject(
                            assetName: assetName,
                            position: sprite.position,
                            rotation: sprite.zRotation,
                            scaleX: sprite.xScale,
                            scaleY: sprite.yScale
                        )
                        frameObjects.append(editorObject)
                        print("🎮 Saving image object: \(assetName) at \(sprite.position) scale: \(sprite.xScale)")
                    }
                    // Handle box objects (SKShapeNode) - store as special editor objects with type prefix
                    else if let shapeNode = node as? SKShapeNode, shapeNode.name?.hasPrefix("object_box_") == true {
                        var width = shapeNode.userData?["width"] as? CGFloat ?? 50
                        var height = shapeNode.userData?["height"] as? CGFloat ?? 50
                        let color = shapeNode.userData?["color"] as? String ?? "#FF0000"
                        
                        // Apply scale to get actual dimensions being saved
                        width *= shapeNode.xScale
                        height *= shapeNode.yScale
                        
                        // Use a special naming scheme to identify this as a box when loading
                        let boxAssetName = "BOX_\(color)_\(Int(width))_\(Int(height))"
                        let editorObject = EditorObject(
                            assetName: boxAssetName,
                            position: shapeNode.position,
                            rotation: shapeNode.zRotation,
                            scaleX: 1.0,  // Scale is baked into width/height, so set to 1.0
                            scaleY: 1.0   // Scale is baked into width/height, so set to 1.0
                        )
                        frameObjects.append(editorObject)
                        print("🎮 Saving box object: \(color) \(Int(width))x\(Int(height)) at \(shapeNode.position)")
                    }
                }
            }
            
            let frame = SavedEditFrame(name: name, frameNumber: frameNumber, from: editValues, pose: tempPose, objects: frameObjects)
            SavedFramesManager.shared.saveFrame(frame)
            
            let successAlert = UIAlertController(title: "Saved!", message: "Frame '\(name)' (Frame #\(frameNumber)) has been saved with \(frameObjects.count) objects", preferredStyle: .alert)
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func loadPressed() {
        print("🎮 Load button pressed")
        let frameList = FrameListViewController()
        frameList.onFrameSelected = { [weak self] frame in
            self?.applyFrame(frame)
        }
        let navController = UINavigationController(rootViewController: frameList)
        present(navController, animated: true)
    }
    
    @objc private func addObjectPressed() {
        print("🎮 Add object button pressed")
        let alert = UIAlertController(title: "Add Object", message: "Select object type", preferredStyle: .actionSheet)
        
        // Image assets
        let assets = ["Apple", "Dumbbell", "Kettlebell", "Shaker"]
        
        for asset in assets {
            alert.addAction(UIAlertAction(title: asset, style: .default) { [weak self] _ in
                self?.addImageObject(asset: asset)
            })
        }
        
        // Add Box option
        alert.addAction(UIAlertAction(title: "Box", style: .default) { [weak self] _ in
            self?.addBoxObject()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func addImageObject(asset: String) {
        print("🎮 Adding image object: \(asset)")
        addObject(asset: asset)
    }
    
    private func addBoxObject() {
        print("🎮 Adding box object with color picker")
        guard let scene = editorScene else {
            print("🎮 ❌ ERROR: editorScene is nil!")
            return
        }
        
        // Show color picker for the box
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = .red  // Default color
        colorPicker.delegate = self
        colorPicker.supportsAlpha = false
        
        print("🎮 Presenting color picker, editorScene size: \(scene.size)")
        
        // Store reference to editor scene for use in delegate
        self.colorPickerEditorScene = scene
        
        present(colorPicker, animated: true)
    }
    
    // Add UIColorPickerViewControllerDelegate method to handle color selection
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        print("🎮 Color picker finished")
        let selectedColor = viewController.selectedColor
        print("🎮 Selected color: \(selectedColor.toHexString())")
        
        guard let editorScene = colorPickerEditorScene else {
            print("🎮 ❌ ERROR: colorPickerEditorScene is nil!")
            dismiss(animated: true)
            return
        }
        
        print("🎮 Editor scene found, creating box...")
        
        // Create box with selected color
        let boxObject = AnimationObject(boxAt: CGPoint(x: editorScene.size.width / 2, y: editorScene.size.height / 2 - 100), width: 50, height: 50, color: selectedColor.toHexString(), rotation: 0)
        
        // Create sprite node for visualization
        let boxNode = SKShapeNode(rectOf: CGSize(width: 50, height: 50))
        boxNode.fillColor = selectedColor
        boxNode.strokeColor = .black
        boxNode.lineWidth = 2
        boxNode.position = CGPoint(x: editorScene.size.width / 2, y: editorScene.size.height / 2 - 100)
        boxNode.zPosition = 5
        boxNode.name = "object_box_\(boxObject.id)"
        
        // Store object data
        boxNode.userData = NSMutableDictionary()
        boxNode.userData?["type"] = "box"
        boxNode.userData?["boxObject"] = boxObject
        boxNode.userData?["color"] = selectedColor.toHexString()
        boxNode.userData?["width"] = 50.0
        boxNode.userData?["height"] = 50.0
        boxNode.userData?["rotation"] = 0.0
        
        if showObjectControls {
            addBoxObjectControls(to: boxNode, in: editorScene, width: 50, height: 50)
        }
        
        editorScene.addChild(boxNode)
        print("🎮 Box object added with color: \(selectedColor.toHexString())")
        
        colorPickerEditorScene = nil
        dismiss(animated: true)
    }
    
    private func addBoxObjectControls(to boxNode: SKNode, in scene: SKScene, width: CGFloat = 50, height: CGFloat = 50) {
        // Calculate half-dimensions for dot positioning
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        // Add move dot (center of box)
        let moveDot = SKShapeNode(circleOfRadius: 6)
        moveDot.fillColor = .blue
        moveDot.strokeColor = .darkGray
        moveDot.lineWidth = 1
        moveDot.position = CGPoint(x: 0, y: 0)  // Center of the box
        moveDot.name = "object_move_\(boxNode.name ?? "")"
        moveDot.zPosition = 10
        boxNode.addChild(moveDot)
        
        // Add resize width dot (right edge) - GREEN
        let resizeWidthDot = SKShapeNode(circleOfRadius: 6)
        resizeWidthDot.fillColor = .green
        resizeWidthDot.strokeColor = .darkGray
        resizeWidthDot.lineWidth = 1
        resizeWidthDot.position = CGPoint(x: halfWidth, y: 0)
        resizeWidthDot.name = "object_resize_width_\(boxNode.name ?? "")"
        resizeWidthDot.zPosition = 10
        boxNode.addChild(resizeWidthDot)
        
        // Add resize height dot (top edge) - YELLOW
        let resizeHeightDot = SKShapeNode(circleOfRadius: 6)
        resizeHeightDot.fillColor = .yellow
        resizeHeightDot.strokeColor = .darkGray
        resizeHeightDot.lineWidth = 1
        resizeHeightDot.position = CGPoint(x: 0, y: halfHeight)
        resizeHeightDot.name = "object_resize_height_\(boxNode.name ?? "")"
        resizeHeightDot.zPosition = 10
        boxNode.addChild(resizeHeightDot)
        
        // Add rotate dot (top-right corner)
        let rotateDot = SKShapeNode(circleOfRadius: 6)
        rotateDot.fillColor = .purple
        rotateDot.strokeColor = .darkGray
        rotateDot.lineWidth = 1
        rotateDot.position = CGPoint(x: halfWidth, y: halfHeight)
        rotateDot.name = "object_rotate_\(boxNode.name ?? "")"
        rotateDot.zPosition = 10
        boxNode.addChild(rotateDot)
        
        // Add delete dot (bottom-right corner)
        let deleteDot = SKShapeNode(circleOfRadius: 6)
        deleteDot.fillColor = .red
        deleteDot.strokeColor = .darkGray
        deleteDot.lineWidth = 1
        deleteDot.position = CGPoint(x: halfWidth, y: -halfHeight)
        deleteDot.name = "object_delete_\(boxNode.name ?? "")"
        deleteDot.zPosition = 10
        boxNode.addChild(deleteDot)
    }
    
    private func addObject(asset: String) {
        print("🎮 Adding object: \(asset)")
        // Add the object to the editor scene
        guard let editorScene = editorScene else { return }
        
        // Load the asset image
        let imageName: String
        switch asset {
        case "Apple": imageName = "Apple"
        case "Dumbbell": imageName = "Dumbbell"
        case "Kettlebell": imageName = "Kettlebell"
        case "Shaker": imageName = "Shaker"
        default: imageName = "Apple"
        }
        
        // Create a sprite node for the object
        let sprite = SKSpriteNode(imageNamed: imageName)
        // Position below the center of the figure (lower on screen)
        sprite.position = CGPoint(x: editorScene.size.width / 2, y: editorScene.size.height / 2 - 100)
        sprite.zPosition = 5  // Behind the stick figure but in front of grid
        // Scale to fit in a square (50x50), maintaining aspect ratio
        sprite.size = CGSize(width: 50, height: 50)
        sprite.name = "object_\(asset)"
        
        // Store object data for saving
        sprite.userData = NSMutableDictionary()
        sprite.userData?["assetName"] = asset
        sprite.userData?["rotation"] = 0.0
        sprite.userData?["scale"] = 1.0
        
        // Make sprite interactive with physics
        sprite.physicsBody = SKPhysicsBody(circleOfRadius: 25)
        sprite.physicsBody?.isDynamic = false
        sprite.physicsBody?.affectedByGravity = false
        
        // Add control dots only if showObjectControls is true
        if showObjectControls {
            // Add center dot for moving the object
            let moveDot = SKShapeNode(circleOfRadius: 3)
            moveDot.fillColor = .white
            moveDot.strokeColor = .darkGray
            moveDot.lineWidth = 1
            moveDot.position = CGPoint(x: 0, y: 0)  // Center of object
            moveDot.name = "object_move_\(asset)"
            moveDot.zPosition = 12
            sprite.addChild(moveDot)
            
            // Add rotate dot (top-right corner of object) - small circle for control
            let rotateDot = SKShapeNode(circleOfRadius: 3)
            rotateDot.fillColor = .yellow
            rotateDot.strokeColor = .darkGray
            rotateDot.lineWidth = 1
            rotateDot.position = CGPoint(x: 25, y: 25)  // Top-right relative to object (scaled with size)
            rotateDot.name = "object_rotate_\(asset)"
            rotateDot.zPosition = 12
            sprite.addChild(rotateDot)
            
            // Add resize dot (bottom-right corner of object) - small circle for control (enlarge/shrink)
            let resizeDot = SKShapeNode(circleOfRadius: 3)
            resizeDot.fillColor = .cyan
            resizeDot.strokeColor = .darkGray
            resizeDot.lineWidth = 1
            resizeDot.position = CGPoint(x: 25, y: -25)  // Bottom-right relative to object (scaled with size)
            resizeDot.name = "object_resize_\(asset)"
            resizeDot.zPosition = 12
            sprite.addChild(resizeDot)
            
            // Add delete dot (top-left corner of object) - red for delete
            let deleteDot = SKShapeNode(circleOfRadius: 3)
            deleteDot.fillColor = .red
            deleteDot.strokeColor = .darkGray
            deleteDot.lineWidth = 1
            deleteDot.position = CGPoint(x: -25, y: 25)  // Top-left relative to object (scaled with size)
            deleteDot.name = "object_delete_\(asset)"
            deleteDot.zPosition = 12
            sprite.addChild(deleteDot)
        }
        
        editorScene.addChild(sprite)
        print("🎮 Added \(asset) object to scene at position \(sprite.position)")
    }
    
    private func applyFrame(_ frame: SavedEditFrame) {
        //print("🎮 Applying frame: \(frame.name)")
        //print("🎮 DEBUG applyFrame: positionX=\(frame.positionX), positionY=\(frame.positionY)")
        // Restore all angles
        neckRotation = frame.headAngle
        upperTorsoRotation = frame.torsoRotationAngle
        lowerTorsoRotation = frame.midTorsoAngle  // Upper torso rotation around midTorso
        waistTorsoAngle = frame.waistTorsoAngle  // Upper body rotation around waist
        torsoRotation = frame.waistTorsoAngle  // Compatibility: also set torsoRotation
        leftShoulderAngle = frame.leftShoulderAngle
        leftElbowAngle = frame.leftElbowAngle
        rightShoulderAngle = frame.rightShoulderAngle
        rightElbowAngle = frame.rightElbowAngle
        leftHipAngle = frame.leftHipAngle
        rightHipAngle = frame.rightHipAngle
        leftKneeAngle = frame.leftKneeAngle
        rightKneeAngle = frame.rightKneeAngle
        leftFootAngle = frame.leftFootAngle
        rightFootAngle = frame.rightFootAngle
        
        // Restore figure scale and thickness
        figureScale = frame.figureScale
        // Restore individual stroke thickness values
        strokeThicknessJoints = frame.strokeThicknessJoints
        strokeThicknessUpperTorso = frame.strokeThicknessUpperTorso
        strokeThicknessLowerTorso = frame.strokeThicknessLowerTorso
        strokeThicknessBicep = frame.strokeThicknessBicep
        strokeThicknessTricep = frame.strokeThicknessTricep
        strokeThicknessLowerArms = frame.strokeThicknessLowerArms
        strokeThicknessUpperLegs = frame.strokeThicknessUpperLegs
        strokeThicknessLowerLegs = frame.strokeThicknessLowerLegs
        strokeThicknessFullTorso = frame.strokeThicknessFullTorso
        strokeThicknessDeltoids = frame.strokeThicknessDeltoids
        strokeThicknessTrapezius = frame.strokeThicknessTrapezius
        
        // Restore fusiform
        fusiformUpperTorso = frame.fusiformUpperTorso
        fusiformLowerTorso = frame.fusiformLowerTorso
        fusiformBicep = frame.fusiformBicep
        fusiformTricep = frame.fusiformTricep
        fusiformLowerArms = frame.fusiformLowerArms
        fusiformUpperLegs = frame.fusiformUpperLegs
        fusiformLowerLegs = frame.fusiformLowerLegs
        
        // Restore position offsets
        figureOffsetX = frame.positionX
        figureOffsetY = frame.positionY
        //print("🎮 DEBUG applyFrame after assignment: figureOffsetX=\(figureOffsetX), figureOffsetY=\(figureOffsetY)")
        
        // Restore all multiplier and size properties
        skeletonSizeTorso = frame.skeletonSizeTorso
        skeletonSizeArm = frame.skeletonSizeArm
        skeletonSizeLeg = frame.skeletonSizeLeg
        jointShapeSize = frame.jointShapeSize
        shoulderWidthMultiplier = frame.shoulderWidthMultiplier
        waistWidthMultiplier = frame.waistWidthMultiplier
        waistThicknessMultiplier = frame.waistThicknessMultiplier
        neckLength = frame.neckLength
        neckWidth = frame.neckWidth
        handSize = frame.handSize
        footSize = frame.footSize
        
        // Restore peak positions and fusiform shoulders
        fusiformShoulders = frame.fusiformShoulders
        peakPositionBicep = frame.peakPositionBicep
        peakPositionTricep = frame.peakPositionTricep
        peakPositionLowerArms = frame.peakPositionLowerArms
        peakPositionUpperLegs = frame.peakPositionUpperLegs
        peakPositionLowerLegs = frame.peakPositionLowerLegs
        peakPositionUpperTorso = frame.peakPositionUpperTorso
        peakPositionLowerTorso = frame.peakPositionLowerTorso
        
        // Clear existing objects
        if let editorScene = editorScene {
            editorScene.children.forEach { node in
                if node.name?.hasPrefix("object_") == true {
                    node.removeFromParent()
                }
            }
        }
        
        // Load objects from frame
        for editorObject in frame.objects {
            // Check if this is a box (identified by BOX_ prefix)
            if editorObject.assetName.hasPrefix("BOX_") {
                // Parse box properties from assetName format: BOX_#RRGGBB_width_height
                let parts = editorObject.assetName.split(separator: "_")
                if parts.count >= 4 {
                    let color = String(parts[1])  // #RRGGBB
                    let width = CGFloat(Int(parts[2]) ?? 50)
                    let height = CGFloat(Int(parts[3]) ?? 50)
                    let boxColor = UIColor(hex: color) ?? .red
                    
                    // Create the box node
                    let boxNode = SKShapeNode(rectOf: CGSize(width: width, height: height))
                    boxNode.fillColor = boxColor
                    boxNode.strokeColor = .black
                    boxNode.lineWidth = 2
                    boxNode.position = editorObject.position
                    boxNode.zRotation = editorObject.rotation
                    boxNode.xScale = editorObject.scaleX
                    boxNode.yScale = editorObject.scaleY
                    boxNode.zPosition = 5
                    boxNode.name = "object_box_\(UUID())"
                    
                    // Store box data
                    boxNode.userData = NSMutableDictionary()
                    boxNode.userData?["type"] = "box"
                    boxNode.userData?["color"] = color
                    boxNode.userData?["width"] = width
                    boxNode.userData?["height"] = height
                    boxNode.userData?["rotation"] = editorObject.rotation
                    
                    if showObjectControls {
                        addBoxObjectControls(to: boxNode, in: editorScene!, width: width, height: height)
                    }
                    
                    editorScene?.addChild(boxNode)
                    print("🎮 Loaded box: \(color) \(Int(width))x\(Int(height)) at \(boxNode.position)")
                }
            } else {
                // Load as image object
                addObject(asset: editorObject.assetName)
                // Update the position, rotation, and scale of the last added object
                if let lastObject = editorScene?.children.last(where: { $0.name?.hasPrefix("object_") == true }) as? SKSpriteNode {
                    lastObject.position = editorObject.position
                    lastObject.zRotation = editorObject.rotation
                    lastObject.xScale = editorObject.scaleX
                    lastObject.yScale = editorObject.scaleY
                    print("🎮 Loaded object: \(editorObject.assetName) at \(lastObject.position)")
                }
            }
        }
        
        // Reload table view to show updated values
        controlsTableView.reloadData()
        updateFigure()
    }
    
    @objc private func closePressed() {
        dismiss(animated: true)
    }
    
    // MARK: - UIColorPickerViewControllerDelegate
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        // Check if this is for a box color (colorPickerEditorScene will be set)
        if colorPickerEditorScene != nil {
            print("🎮 Box color picker finished")
            let selectedColor = viewController.selectedColor
            print("🎮 Selected color: \(selectedColor.toHexString())")
            
            guard let editorScene = colorPickerEditorScene else {
                viewController.dismiss(animated: true)
                return
            }
            
            print("🎮 Editor scene found, creating box...")
            
            // Create box with selected color
            let boxObject = AnimationObject(boxAt: CGPoint(x: editorScene.size.width / 2, y: editorScene.size.height / 2 - 100), width: 50, height: 50, color: selectedColor.toHexString(), rotation: 0)
            
            // Create sprite node for visualization
            let boxNode = SKShapeNode(rectOf: CGSize(width: 50, height: 50))
            boxNode.fillColor = selectedColor
            boxNode.strokeColor = .black
            boxNode.lineWidth = 2
            boxNode.position = CGPoint(x: editorScene.size.width / 2, y: editorScene.size.height / 2 - 100)
            boxNode.zPosition = 5
            boxNode.name = "object_box_\(boxObject.id)"
            
            // Store object data
            boxNode.userData = NSMutableDictionary()
            boxNode.userData?["type"] = "box"
            boxNode.userData?["boxObject"] = boxObject
            boxNode.userData?["color"] = selectedColor.toHexString()
            boxNode.userData?["width"] = 50.0
            boxNode.userData?["height"] = 50.0
            boxNode.userData?["rotation"] = 0.0
            
            if showObjectControls {
                addBoxObjectControls(to: boxNode, in: editorScene)
            }
            
            editorScene.addChild(boxNode)
            print("🎮 Box object added with color: \(selectedColor.toHexString())")
            
            colorPickerEditorScene = nil
            viewController.dismiss(animated: true)
        }
        // Otherwise it's for body part color
        else if let colorKey = pendingColorKey {
            bodyPartColors[colorKey] = viewController.selectedColor
            pendingColorButton?.backgroundColor = viewController.selectedColor
            print("🎨 Color picker: Set \(colorKey) to color \(viewController.selectedColor)")
            updateFigure()
            viewController.dismiss(animated: true)  // Dismiss the color picker, not the entire editor
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if info[.originalImage] is UIImage {
            // Image selected - TODO: Add selected image to the scene
        }
        dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    @objc private func colorButtonPressed(_ sender: UIButton) {
        let colorPickerVC = UIColorPickerViewController()
        colorPickerVC.delegate = self
        
        // Map the color keys in the same order as they appear in cellForRowAt for section 4
        let colorKeys = ["head", "torso", "leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftUpperLeg", "rightUpperLeg", "leftLowerLeg", "rightLowerLeg"]
        
        // Find which button was pressed and set the pending color key
        // The button should have been tagged with the colorKey.hashValue in addColorButton
        for (_, key) in colorKeys.enumerated() {
            if key.hashValue == sender.tag {
                pendingColorKey = key
                break
            }
        }
        
        pendingColorButton = sender
        present(colorPickerVC, animated: true)
    }
}

// MARK: - Editor Scene
class StickFigureEditorScene: SKScene {
    var gameState: StickFigureGameState?
    private var characterNode: SKNode?
    private var draggedJoint: SKNode?
    private var draggedObject: SKNode?
    private var dragOffset: CGPoint = .zero
    private var draggedJointName: String?
    private var lastDragPosition: CGPoint = .zero
    private var gridNode: SKNode?
    var currentZoom: CGFloat = 1.0
    weak var viewController: StickFigureGameplayEditorViewController?
    
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        
        // Draw grid
        drawGrid()
        
        // Display stick figure
        renderStickFigure()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Check for object manipulation dots first (rotate/resize/delete/move)
        let nodes = self.nodes(at: location)
        for node in nodes {
            if let shapeNode = node as? SKShapeNode {
                if let nodeName = shapeNode.name {
                    if nodeName.hasPrefix("object_move_") {
                        // Parent could be either an SKSpriteNode (image) or SKShapeNode (box)
                        draggedObject = shapeNode.parent
                        draggedJointName = nodeName  // Track operation type
                        lastDragPosition = location
                        if let draggedObject = draggedObject {
                            dragOffset = CGPoint(x: location.x - draggedObject.position.x,
                                                y: location.y - draggedObject.position.y)
                        }
                        print("🎮 Started moving object")
                        return
                    } else if nodeName.hasPrefix("object_rotate_") {
                        draggedObject = shapeNode.parent
                        draggedJointName = nodeName  // Reuse this to track operation type
                        lastDragPosition = location
                        print("🎮 Started rotating object")
                        return
                    } else if nodeName.hasPrefix("object_resize_") {
                        draggedObject = shapeNode.parent
                        draggedJointName = nodeName  // Reuse this to track operation type
                        lastDragPosition = location
                        print("🎮 Started resizing object")
                        return
                    } else if nodeName.hasPrefix("object_delete_") {
                        // Delete the object
                        if let objectToDelete = shapeNode.parent {
                            objectToDelete.removeFromParent()
                            print("🎮 Deleted object")
                            return
                        }
                    }
                }
            }
        }
        
        // Then check if tapping on an object sprite itself
        if let tappedObject = atPoint(location) as? SKSpriteNode,
           tappedObject.name?.hasPrefix("object_") == true {
            draggedObject = tappedObject
            draggedJointName = nil  // Not a special dot
            dragOffset = CGPoint(x: location.x - tappedObject.position.x,
                                y: location.y - tappedObject.position.y)
            lastDragPosition = location
            print("🎮 Started dragging object: \(tappedObject.name ?? "unknown")")
            return
        }
        
        // Check if a joint was tapped - get all nodes at location
        for node in nodes {
            if let shapeNode = node as? SKShapeNode, let nodeName = shapeNode.name, nodeName.hasPrefix("joint_") {
                draggedJoint = shapeNode
                draggedJointName = nodeName
                dragOffset = CGPoint(x: location.x - shapeNode.position.x,
                                    y: location.y - shapeNode.position.y)
                lastDragPosition = location
                print("🎮 Started dragging joint: \(nodeName)")
                return
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Handle object manipulation (movement/rotation/resizing)
        if let draggedObject = draggedObject, let operation = draggedJointName {
            if operation.hasPrefix("object_move_") {
                // Move the object
                let newPos = CGPoint(x: location.x - dragOffset.x,
                                    y: location.y - dragOffset.y)
                draggedObject.position = newPos
                print("🎮 Object moved")
            } else if operation.hasPrefix("object_rotate_") {
                // Calculate rotation based on horizontal drag
                let dx = location.x - lastDragPosition.x
                if abs(dx) > 0 {
                    let rotation = CGFloat(dx) * 0.02
                    draggedObject.zRotation += rotation
                    print("🎮 Object rotated: \(draggedObject.zRotation)")
                }
            } else if operation.hasPrefix("object_resize_width_") {
                // Resize WIDTH only (GREEN dot) - horizontal drag affects x scale
                let dx = location.x - lastDragPosition.x
                if abs(dx) > 0 {
                    let scaleFactor = 1.0 + (dx * 0.02)
                    draggedObject.xScale *= scaleFactor
                    
                    // Counter-scale the control dots so they don't shrink/grow
                    for child in draggedObject.children {
                        if let dotNode = child as? SKShapeNode {
                            dotNode.xScale /= scaleFactor
                        }
                    }
                    
                    print("🎮 Width resized: xScale = \(draggedObject.xScale)")
                }
            } else if operation.hasPrefix("object_resize_height_") {
                // Resize HEIGHT only (YELLOW dot) - vertical drag affects y scale
                let dy = location.y - lastDragPosition.y
                if abs(dy) > 0 {
                    let scaleFactor = 1.0 + (dy * 0.02)
                    draggedObject.yScale *= scaleFactor
                    
                    // Counter-scale the control dots so they don't shrink/grow
                    for child in draggedObject.children {
                        if let dotNode = child as? SKShapeNode {
                            dotNode.yScale /= scaleFactor
                        }
                    }
                    
                    print("🎮 Height resized: yScale = \(draggedObject.yScale)")
                }
            } else if operation.hasPrefix("object_resize_") {
                // Fallback for other resize operations (both dimensions)
                let dx = location.x - lastDragPosition.x
                let dy = location.y - lastDragPosition.y
                let dragMagnitude = (dx + dy) * 0.02
                if abs(dragMagnitude) > 0 {
                    let scaleFactor = 1.0 + dragMagnitude
                    draggedObject.xScale *= scaleFactor
                    draggedObject.yScale *= scaleFactor
                    
                    // Counter-scale the control dots so they don't shrink/grow
                    for child in draggedObject.children {
                        if let dotNode = child as? SKShapeNode {
                            dotNode.xScale /= scaleFactor
                            dotNode.yScale /= scaleFactor
                        }
                    }
                }
            } else {
                // Normal object dragging
                let newPos = CGPoint(x: location.x - dragOffset.x,
                                    y: location.y - dragOffset.y)
                draggedObject.position = newPos
            }
            lastDragPosition = location
            return
        }
        
        // Handle joint dragging
        guard let draggedJoint = draggedJoint else { return }
        
        // Update joint position with offset for visual feedback
        let newPos = CGPoint(x: location.x - dragOffset.x,
                            y: location.y - dragOffset.y)
        draggedJoint.position = newPos
        
        // Calculate angle delta from movement - SLOW AND CONTROLLED
        if let jointName = draggedJointName {
            let dx = location.x - lastDragPosition.x
            let dy = location.y - lastDragPosition.y
            
            // Handle center joint specially - only moves the figure
            if jointName == "joint_center" {
                viewController?.figureOffsetX += dx
                viewController?.figureOffsetY += dy
            } else {
                // For all other joints (including midTorso): increase sensitivity to 2.0 degrees per pixel
                // INVERTED: negative dx gives positive angle (drag right = rotate up)
                let angleDelta = -dx * 2.0
                updateAngleByDelta(jointName: jointName, angleDelta: angleDelta)
            }
            
            lastDragPosition = location
            viewController?.updateFigure()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggedJoint = nil
        draggedObject = nil
        draggedJointName = nil
        print("🎮 Finished dragging")
    }
    
    private func updateAngleByDelta(jointName: String, angleDelta: CGFloat) {
        // Get current angle and apply delta based on joint hierarchy
        let currentAngle: CGFloat
        
        switch jointName {
        case "joint_head":
            // Head dot: rotates the head around the neck (neckRotation)
            currentAngle = viewController?.neckRotation ?? 0
            viewController?.neckRotation = currentAngle + angleDelta
            
        case "joint_neck":
            // Neck dot: rotates everything ABOVE the midTorso (upper torso, shoulders, arms, head, neck) around the midTorso
            currentAngle = viewController?.lowerTorsoRotation ?? 0
            viewController?.lowerTorsoRotation = currentAngle + angleDelta
            
        case "joint_midTorso":
            // MidTorso dot: rotates the ENTIRE UPPER BODY around the waist
            // This should update waistTorsoAngle, not lowerTorsoRotation
            // waistTorsoAngle rotates midTorso around waist, which in turn rotates everything above it
            currentAngle = viewController?.waistTorsoAngle ?? 0
            viewController?.waistTorsoAngle = currentAngle + angleDelta
            
        case "joint_leftShoulder":
            // Left Shoulder: rotates left arm around neck
            currentAngle = viewController?.leftShoulderAngle ?? 0
            viewController?.leftShoulderAngle = currentAngle + angleDelta
            
        case "joint_rightShoulder":
            // Right Shoulder: rotates right arm around neck
            currentAngle = viewController?.rightShoulderAngle ?? 0
            viewController?.rightShoulderAngle = currentAngle + angleDelta
            
        case "joint_leftElbow":
            // Left Elbow: rotates upper left arm
            currentAngle = viewController?.leftShoulderAngle ?? 0
            viewController?.leftShoulderAngle = currentAngle + angleDelta
            
        case "joint_rightElbow":
            // Right Elbow: rotates upper right arm
            currentAngle = viewController?.rightShoulderAngle ?? 0
            viewController?.rightShoulderAngle = currentAngle + angleDelta
            
        case "joint_leftHand":
            // Left Hand: rotates lower left arm (forearm)
            currentAngle = viewController?.leftElbowAngle ?? 0
            viewController?.leftElbowAngle = currentAngle + angleDelta
            
        case "joint_rightHand":
            // Right Hand: rotates lower right arm (forearm)
            currentAngle = viewController?.rightElbowAngle ?? 0
            viewController?.rightElbowAngle = currentAngle + angleDelta
            
        case "joint_leftHip":
            // Left Hip: rotates upper left leg around waist
            currentAngle = viewController?.leftHipAngle ?? 0
            viewController?.leftHipAngle = currentAngle + angleDelta
            
        case "joint_rightHip":
            // Right Hip: rotates upper right leg around waist
            currentAngle = viewController?.rightHipAngle ?? 0
            viewController?.rightHipAngle = currentAngle + angleDelta
            
        case "joint_leftKnee":
            // Left Knee: rotates lower left leg around left knee
            currentAngle = viewController?.leftKneeAngle ?? 0
            viewController?.leftKneeAngle = currentAngle + angleDelta
            
        case "joint_rightKnee":
            // Right Knee: rotates lower right leg around right knee
            currentAngle = viewController?.rightKneeAngle ?? 0
            viewController?.rightKneeAngle = currentAngle + angleDelta
            
        case "joint_leftFoot":
            // Left Foot: rotates foot around left ankle
            currentAngle = viewController?.leftFootAngle ?? 0
            viewController?.leftFootAngle = currentAngle + angleDelta
            
        case "joint_rightFoot":
            // Right Foot: rotates foot around right ankle
            currentAngle = viewController?.rightFootAngle ?? 0
            viewController?.rightFootAngle = currentAngle + angleDelta
            
        default:
            break
        }
        
        // Update the figure
        viewController?.updateFigure()
    }
    
    private func drawGrid() {
        let gridSpacing: CGFloat = 20
        let gridColor = SKColor.gray.withAlphaComponent(0.3)
        
        // Vertical lines
        var x: CGFloat = 0
        while x < size.width {
            let line = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: -size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            line.path = path.cgPath
            line.strokeColor = gridColor
            line.lineWidth = 0.5
            line.position = CGPoint(x: x, y: 0)
            line.zPosition = 2
            addChild(line)
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y < size.height {
            let line = SKShapeNode()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -size.width, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            line.path = path.cgPath
            line.strokeColor = gridColor
            line.lineWidth = 0.5
            line.position = CGPoint(x: 0, y: y)
            line.zPosition = 2
            addChild(line)
            y += gridSpacing
        }
        
        // Draw crosshairs at center
        let crosshair = SKShapeNode()
        let crossPath = UIBezierPath()
        crossPath.move(to: CGPoint(x: -size.width, y: 0))
        crossPath.addLine(to: CGPoint(x: size.width, y: 0))
        crossPath.move(to: CGPoint(x: 0, y: -size.height))
        crossPath.addLine(to: CGPoint(x: 0, y: size.height))
        crosshair.path = crossPath.cgPath
        crosshair.strokeColor = SKColor.red.withAlphaComponent(0.6)
        crosshair.lineWidth = 1
        crosshair.position = CGPoint(x: size.width / 2, y: size.height / 2)
        crosshair.zPosition = 3
        addChild(crosshair)
    }
    
    private func renderStickFigure() {
        guard let gameState = gameState, let standFrame = gameState.standFrame else {
            print("🎮 ERROR: No game state or stand frame")
            return
        }
        
        // Remove existing character
        characterNode?.removeFromParent()
        
        // Create character node at center
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2)
        container.zPosition = 10
        
        // Render the actual stick figure using GameScene's renderStickFigure method
        // We need to create a temporary GameScene with gameState to access the rendering method
        let tempScene = GameScene(size: size)
        tempScene.gameState = gameState  // PASS the gameState so rendering works correctly
        let stickFigureNode = tempScene.renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2, jointShapeSize: 1.0)
        container.addChild(stickFigureNode)
        
        addChild(container)
        characterNode = container
    }
    
    func updateWithValues(
        figureScale: CGFloat,
        skeletonSizeTorso: CGFloat = 1.0,
        skeletonSizeArm: CGFloat = 1.0,
        skeletonSizeLeg: CGFloat = 1.0,
        jointShapeSize: CGFloat = 1.0,
        shoulderWidthMultiplier: CGFloat = 1.0,
        waistWidthMultiplier: CGFloat = 1.0,
        waistThicknessMultiplier: CGFloat = 0.5,
        neckLength: CGFloat = 1.0,
        neckWidth: CGFloat = 1.0,
        handSize: CGFloat = 1.0,
        footSize: CGFloat = 1.0,
        fusiformUpperTorso: CGFloat,
        fusiformLowerTorso: CGFloat,
        fusiformBicep: CGFloat,
        fusiformTricep: CGFloat,
        fusiformLowerArms: CGFloat,
        fusiformUpperLegs: CGFloat,
        fusiformLowerLegs: CGFloat,
        fusiformShoulders: CGFloat = 0.0,
        fusiformDeltoids: CGFloat = 0.0,
        peakPositionBicep: CGFloat = 0.5,
        peakPositionTricep: CGFloat = 0.5,
        peakPositionLowerArms: CGFloat = 0.35,
        peakPositionUpperLegs: CGFloat = 0.2,
        peakPositionLowerLegs: CGFloat = 0.2,
        peakPositionUpperTorso: CGFloat = 0.5,
        peakPositionLowerTorso: CGFloat = 0.5,
        peakPositionDeltoids: CGFloat = 0.3,
        armMuscleSide: String = "normal",
        figureOffsetX: CGFloat = 0,
        figureOffsetY: CGFloat = 0,
        neckRotation: CGFloat = 0,
        upperTorsoRotation: CGFloat = 0,
        lowerTorsoRotation: CGFloat = 0,
        waistTorsoAngle: CGFloat = 0,
        torsoRotation: CGFloat = 0,
        leftShoulderAngle: CGFloat = 0,
        leftElbowAngle: CGFloat = 0,
        rightShoulderAngle: CGFloat = 0,
        rightElbowAngle: CGFloat = 0,
        leftHipAngle: CGFloat = 0,
        leftKneeAngle: CGFloat = 0,
        rightHipAngle: CGFloat = 0,
        rightKneeAngle: CGFloat = 0,
        leftFootAngle: CGFloat = 0,
        rightFootAngle: CGFloat = 0,
        strokeThicknessJoints: CGFloat = 2.0,
        strokeThicknessUpperTorso: CGFloat = 5.0,
        strokeThicknessLowerTorso: CGFloat = 4.5,
        strokeThicknessBicep: CGFloat = 4.0,
        strokeThicknessTricep: CGFloat = 3.0,
        strokeThicknessLowerArms: CGFloat = 3.5,
        strokeThicknessUpperLegs: CGFloat = 4.5,
        strokeThicknessLowerLegs: CGFloat = 3.5,
        strokeThicknessFullTorso: CGFloat = 1.0,
        strokeThicknessDeltoids: CGFloat = 4.0,
        strokeThicknessTrapezius: CGFloat = 4.0,
        bodyPartColors: [String: UIColor] = [:],
        showInteractiveJoints: Bool = true
    ) {
        // Update the stick figure with new values
        print("🎮 Updating editor scene with new values: fusiformShoulders=\(fusiformShoulders)")
        print("🎮 Angles - Neck:\(Int(neckRotation))° Torso:\(Int(torsoRotation))° LShoulder:\(Int(leftShoulderAngle))° LElbow:\(Int(leftElbowAngle))°")
        
        guard let gameState = gameState, let standFrame = gameState.standFrame else { return }
        
        // Remove old character
        characterNode?.removeFromParent()
        
        // Create updated frame with angles
        var updatedFrame = standFrame
        updatedFrame.fusiformUpperTorso = fusiformUpperTorso
        updatedFrame.fusiformLowerTorso = fusiformLowerTorso
        updatedFrame.fusiformBicep = fusiformBicep
        updatedFrame.fusiformTricep = fusiformTricep
        updatedFrame.fusiformLowerArms = fusiformLowerArms
        updatedFrame.fusiformShoulders = fusiformShoulders
        updatedFrame.fusiformDeltoids = fusiformDeltoids
        updatedFrame.fusiformUpperLegs = fusiformUpperLegs
        updatedFrame.fusiformLowerLegs = fusiformLowerLegs
        updatedFrame.peakPositionBicep = peakPositionBicep
        updatedFrame.peakPositionTricep = peakPositionTricep
        updatedFrame.peakPositionLowerArms = peakPositionLowerArms
        updatedFrame.peakPositionUpperLegs = peakPositionUpperLegs
        updatedFrame.peakPositionLowerLegs = peakPositionLowerLegs
        updatedFrame.peakPositionUpperTorso = peakPositionUpperTorso
        updatedFrame.peakPositionLowerTorso = peakPositionLowerTorso
        updatedFrame.peakPositionDeltoids = peakPositionDeltoids
        updatedFrame.armMuscleSide = armMuscleSide
        updatedFrame.shoulderWidthMultiplier = shoulderWidthMultiplier
        updatedFrame.waistWidthMultiplier = waistWidthMultiplier
        updatedFrame.waistThicknessMultiplier = waistThicknessMultiplier
        updatedFrame.skeletonSizeTorso = skeletonSizeTorso
        updatedFrame.skeletonSizeArm = skeletonSizeArm
        updatedFrame.skeletonSizeLeg = skeletonSizeLeg
        updatedFrame.neckLength = neckLength
        updatedFrame.neckWidth = neckWidth
        updatedFrame.handSize = handSize
        updatedFrame.footSize = footSize
        
        // Set stroke thickness values
        updatedFrame.strokeThicknessJoints = strokeThicknessJoints
        updatedFrame.strokeThicknessUpperTorso = strokeThicknessUpperTorso
        updatedFrame.strokeThicknessLowerTorso = strokeThicknessLowerTorso
        updatedFrame.strokeThicknessBicep = strokeThicknessBicep
        updatedFrame.strokeThicknessTricep = strokeThicknessTricep
        updatedFrame.strokeThicknessLowerArms = strokeThicknessLowerArms
        updatedFrame.strokeThicknessUpperLegs = strokeThicknessUpperLegs
        updatedFrame.strokeThicknessLowerLegs = strokeThicknessLowerLegs
        updatedFrame.strokeThicknessFullTorso = strokeThicknessFullTorso
        updatedFrame.strokeThicknessDeltoids = strokeThicknessDeltoids
        updatedFrame.strokeThicknessTrapezius = strokeThicknessTrapezius
        
        //print("🎮 DEBUG updateWithValues: Setting skeletonSizeTorso=\(skeletonSizeTorso) skeletonSizeArm=\(skeletonSizeArm) skeletonSizeLeg=\(skeletonSizeLeg) jointShapeSize=\(jointShapeSize) on updatedFrame")
        
        // Apply angles to the frame - map to existing properties
        updatedFrame.headAngle = neckRotation           // Maps neckRotation to headAngle
        updatedFrame.torsoRotationAngle = upperTorsoRotation  // Maps upperTorsoRotation to torsoRotationAngle
        updatedFrame.midTorsoAngle = lowerTorsoRotation      // Maps lowerTorsoRotation to midTorsoAngle
        updatedFrame.waistTorsoAngle = waistTorsoAngle      // Maps waistTorsoAngle (rotates entire upper body around waist)
        updatedFrame.leftShoulderAngle = leftShoulderAngle
        updatedFrame.leftElbowAngle = leftElbowAngle
        updatedFrame.rightShoulderAngle = rightShoulderAngle
        updatedFrame.rightElbowAngle = rightElbowAngle
        updatedFrame.leftKneeAngle = leftKneeAngle
        updatedFrame.rightKneeAngle = rightKneeAngle
        updatedFrame.leftFootAngle = leftFootAngle
        updatedFrame.rightFootAngle = rightFootAngle
        
        // Note: Colors are stored in bodyPartColors but rendering happens in GameScene
        // The colors will be applied through the rendering pipeline
        
        // Create character node centered vertically with offset
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2 + figureOffsetX, y: size.height / 2 + figureOffsetY)
        container.zPosition = 10
        
        // Apply colors from bodyPartColors to the frame before rendering
        // Convert UIColor to SwiftUI Color by creating temporary appearance
        let appearance = StickFigureAppearance()
        appearance.headColor = bodyPartColors["head"].map { Color($0) } ?? .black
        appearance.torsoColor = bodyPartColors["torso"].map { Color($0) } ?? .black
        appearance.leftUpperArmColor = bodyPartColors["leftUpperArm"].map { Color($0) } ?? .black
        appearance.rightUpperArmColor = bodyPartColors["rightUpperArm"].map { Color($0) } ?? .black
        appearance.leftLowerArmColor = bodyPartColors["leftLowerArm"].map { Color($0) } ?? .black
        appearance.rightLowerArmColor = bodyPartColors["rightLowerArm"].map { Color($0) } ?? .black
        appearance.leftUpperLegColor = bodyPartColors["leftUpperLeg"].map { Color($0) } ?? .black
        appearance.rightUpperLegColor = bodyPartColors["rightUpperLeg"].map { Color($0) } ?? .black
        appearance.leftLowerLegColor = bodyPartColors["leftLowerLeg"].map { Color($0) } ?? .black
        appearance.rightLowerLegColor = bodyPartColors["rightLowerLeg"].map { Color($0) } ?? .black
        
        // Apply appearance to the frame
        appearance.applyToStickFigure(&updatedFrame)
        
        // Render the actual stick figure with consistent scale
        let tempScene = GameScene(size: size)
        tempScene.gameState = gameState  // PASS the gameState so rendering works correctly
        // Base scale 1.2 provides good visibility, multiplied by figureScale slider for adjustment
        let renderScale = 1.2 * figureScale
        let stickFigureNode = tempScene.renderStickFigure(updatedFrame, at: CGPoint.zero, scale: renderScale, jointShapeSize: jointShapeSize)
        
        container.addChild(stickFigureNode)
        
        print("🎮 Editor: Added stick figure with \(stickFigureNode.children.count) child nodes, scale: \(renderScale), container zPos: \(container.zPosition)")
        
        // Draw interactive joints if enabled
        if showInteractiveJoints {
            let renderScale = 1.2 * figureScale  // Use same scale as figure
            drawInteractiveJoints(on: container, frame: updatedFrame, scale: renderScale)
        }
        
        addChild(container)
        
        // Preserve the current zoom level when updating the figure
        container.setScale(currentZoom)
        
        characterNode = container
    }
    
    private func drawInteractiveJoints(on container: SKNode, frame: StickFigure2D, scale: CGFloat) {
        // Position joints at actual body part positions using StickFigure2D computed properties
        let jointRadius: CGFloat = 4  // Half the previous size (was 8)
        let jointColor = SKColor.blue
        let centerDotRadius: CGFloat = 6
        let centerDotColor = SKColor.red
        
        // Base canvas dimensions for coordinate conversion
        let baseCanvasSize = CGSize(width: 600, height: 720)
        let baseCenter = CGPoint(x: baseCanvasSize.width / 2, y: baseCanvasSize.height / 2)
        
        // Helper function to convert from base canvas coords to scene coords
        func toScenePos(_ pos: CGPoint) -> CGPoint {
            return CGPoint(x: (pos.x - baseCenter.x) * scale, y: (baseCenter.y - pos.y) * scale)
        }
        
        // Draw center dot at waist position (for moving the entire figure)
        let centerDot = SKShapeNode(circleOfRadius: centerDotRadius)
        centerDot.fillColor = centerDotColor
        centerDot.strokeColor = centerDotColor
        centerDot.lineWidth = 1
        centerDot.position = toScenePos(frame.waistPosition)
        centerDot.name = "joint_center"
        centerDot.zPosition = 11
        container.addChild(centerDot)
        
        // Define joints with actual body part positions
        let jointPositions: [(CGPoint, String)] = [
            (frame.headPosition, "head"),
            (frame.neckPosition, "neck"),  // Neck dot - controls upper torso rotation
            (frame.midTorsoPosition, "midTorso"),  // MidTorso dot - controls waist rotation (rotates entire upper body around waist)
            (frame.leftShoulderPosition, "leftShoulder"),
            (frame.rightShoulderPosition, "rightShoulder"),
            (frame.leftUpperArmEnd, "leftElbow"),
            (frame.rightUpperArmEnd, "rightElbow"),
            (frame.leftForearmEnd, "leftHand"),
            (frame.rightForearmEnd, "rightHand"),
            (frame.leftHipPosition, "leftHip"),
            (frame.rightHipPosition, "rightHip"),
            (frame.leftUpperLegEnd, "leftKnee"),
            (frame.rightUpperLegEnd, "rightKnee"),
            (frame.leftLowerLegEnd, "leftFoot"),
            (frame.rightLowerLegEnd, "rightFoot")
        ]
        
        for (pos, name) in jointPositions {
            let scenePos = toScenePos(pos)
            let joint = SKShapeNode(circleOfRadius: jointRadius)
            joint.fillColor = jointColor
            joint.strokeColor = SKColor.blue.withAlphaComponent(0.7)
            joint.lineWidth = 1
            joint.position = scenePos
            joint.name = "joint_\(name)"
            joint.zPosition = 11
            container.addChild(joint)
        }
    }
    
    func updateZoom(_ zoom: CGFloat) {
        currentZoom = zoom
        // Apply zoom to character node directly
        if let characterNode = characterNode {
            characterNode.setScale(zoom)
        }
        print("🎮 Zoom updated to \(zoom)x")
    }
    
    private func applyColorsToNode(_ node: SKNode, colors: [String: UIColor]) {
        // Recursively apply colors to all child nodes based on their names
        for child in node.children {
            if let shapeNode = child as? SKShapeNode {
                // Map node names to color keys
                let colorMap: [String: String] = [
                    "head": "head",
                    "torso": "torso",
                    "leftUpperArm": "leftUpperArm",
                    "rightUpperArm": "rightUpperArm",
                    "leftLowerArm": "leftLowerArm",
                    "rightLowerArm": "rightLowerArm",
                    "leftUpperLeg": "leftUpperLeg",
                    "rightUpperLeg": "rightUpperLeg",
                    "leftLowerLeg": "leftLowerLeg",
                    "rightLowerLeg": "rightLowerLeg"
                ]
                
                // Check if this node's name matches any color key
                if let nodeName = child.name {
                    for (pattern, colorKey) in colorMap {
                        if nodeName.contains(pattern) {
                            if let color = colors[colorKey] {
                                shapeNode.strokeColor = color
                                shapeNode.fillColor = color.withAlphaComponent(0.1)
                            }
                            break
                        }
                    }
                } else if let spriteNode = child as? SKSpriteNode {
                    // Apply color tint to sprite nodes
                    if let nodeName = child.name {
                        let colorMap: [String: String] = [
                            "head": "head",
                            "torso": "torso",
                            "leftUpperArm": "leftUpperArm",
                            "rightUpperArm": "rightUpperArm",
                            "leftLowerArm": "leftLowerArm",
                            "rightLowerArm": "rightLowerArm",
                            "leftUpperLeg": "leftUpperLeg",
                            "rightUpperLeg": "rightUpperLeg",
                            "leftLowerLeg": "leftLowerLeg",
                            "rightLowerLeg": "rightLowerLeg"
                        ]
                        
                        for (pattern, colorKey) in colorMap {
                            if nodeName.contains(pattern) {
                                if let color = colors[colorKey] {
                                    spriteNode.color = color
                                    spriteNode.colorBlendFactor = 0.5
                                }
                            }
                            break
                        }
                    }
                }
            }
            
            // Recursively apply colors to child nodes
            applyColorsToNode(child, colors: colors)
        }
    }
}

// MARK: - Frame List View Controller
class FrameListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    var frames: [SavedEditFrame] = []
    var filteredFrames: [SavedEditFrame] = []
    var bundleFrameIds: Set<UUID> = []  // Track which frames are in animations.json
    var selectedFrame: SavedEditFrame?
    var onFrameSelected: ((SavedEditFrame) -> Void)?
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Saved Frames"
        view.backgroundColor = .white
        
        // Load saved frames from local storage
        var allFrames = SavedFramesManager.shared.getAllFrames()
        
        // Load frames from animations.json (bundle) and track their IDs
        let bundleFrames = AnimationStorage.shared.loadFrames()
        
        // Add bundle frames to the list if not already present, and track their IDs
        for bundleFrame in bundleFrames {
            bundleFrameIds.insert(bundleFrame.id)
            
            // Always create SavedEditFrame from bundle version to get latest values
            let pose = bundleFrame.pose.toStickFigure2D()
            let editValues = EditModeValues(
                    figureScale: pose.scale,
                    fusiformUpperTorso: pose.fusiformUpperTorso,
                    fusiformLowerTorso: pose.fusiformLowerTorso,
                    fusiformBicep: pose.fusiformBicep,
                    fusiformTricep: pose.fusiformTricep,
                    fusiformLowerArms: pose.fusiformLowerArms,
                    fusiformUpperLegs: pose.fusiformUpperLegs,
                    fusiformLowerLegs: pose.fusiformLowerLegs,
                    fusiformShoulders: pose.fusiformShoulders,
                    fusiformDeltoids: pose.fusiformDeltoids,
                    peakPositionBicep: pose.peakPositionBicep,
                    peakPositionTricep: pose.peakPositionTricep,
                    peakPositionLowerArms: pose.peakPositionLowerArms,
                    peakPositionUpperLegs: pose.peakPositionUpperLegs,
                    peakPositionLowerLegs: pose.peakPositionLowerLegs,
                    peakPositionUpperTorso: pose.peakPositionUpperTorso,
                    peakPositionLowerTorso: pose.peakPositionLowerTorso,
                    peakPositionDeltoids: pose.peakPositionDeltoids,
                    skeletonSizeTorso: pose.skeletonSizeTorso,
                    skeletonSizeArm: pose.skeletonSizeArm,
                    skeletonSizeLeg: pose.skeletonSizeLeg,
                    jointShapeSize: nil,
                    shoulderWidthMultiplier: pose.shoulderWidthMultiplier,
                    waistWidthMultiplier: pose.waistWidthMultiplier,
                    waistThicknessMultiplier: pose.waistThicknessMultiplier,
                    neckLength: pose.neckLength,
                    neckWidth: pose.neckWidth,
                    handSize: pose.handSize,
                    footSize: pose.footSize,
                    strokeThicknessJoints: pose.strokeThicknessJoints,
                    strokeThicknessUpperTorso: pose.strokeThicknessUpperTorso,
                    strokeThicknessLowerTorso: pose.strokeThicknessLowerTorso,
                    strokeThicknessBicep: pose.strokeThicknessBicep,
                    strokeThicknessTricep: pose.strokeThicknessTricep,
                    strokeThicknessLowerArms: pose.strokeThicknessLowerArms,
                    strokeThicknessUpperLegs: pose.strokeThicknessUpperLegs,
                    strokeThicknessLowerLegs: pose.strokeThicknessLowerLegs,
                    strokeThicknessFullTorso: pose.strokeThicknessFullTorso,
                    strokeThicknessDeltoids: pose.strokeThicknessDeltoids,
                    strokeThicknessTrapezius: pose.strokeThicknessTrapezius,
                    armMuscleSide: pose.armMuscleSide,
                    showGrid: true,
                    showJoints: true,
                    positionX: pose.figureOffsetX,
                    positionY: pose.figureOffsetY,
                    bodyPartColors: nil,
                    showInteractiveJoints: nil
                )
                //print("🎮 DEBUG: Bundle frame loaded - name=\(bundleFrame.name), figureOffsetX=\(pose.figureOffsetX), figureOffsetY=\(pose.figureOffsetY)")
                // Convert AnimationObjects to EditorObjects
                let editorObjects = bundleFrame.objects.map { animObj in
                    EditorObject(
                        assetName: animObj.imageName,
                        position: animObj.position,
                        rotation: animObj.rotation,
                        scaleX: animObj.scale,
                        scaleY: animObj.scale
                    )
                }
                let savedFrame = SavedEditFrame(id: bundleFrame.id, name: bundleFrame.name, frameNumber: bundleFrame.frameNumber, from: editValues, pose: pose, objects: editorObjects, timestamp: bundleFrame.createdAt)
                // Remove local version if it exists, then add bundle version
                allFrames.removeAll { $0.id == bundleFrame.id }
                allFrames.append(savedFrame)
        }
        
        // Sort by timestamp (newest first)
        frames = allFrames.sorted { $0.timestamp > $1.timestamp }
        filteredFrames = frames
        
        // Setup navigation
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closePressed))
        
        // Create two right bar button items: Regenerate and Sync
        let regenerateBtn = UIBarButtonItem(title: "Regenerate", style: .plain, target: self, action: #selector(regenerateInterpolationPressed))
        let syncBtn = UIBarButtonItem(title: "Sync", style: .plain, target: self, action: #selector(syncFromBundlePressed))
        navigationItem.rightBarButtonItems = [syncBtn, regenerateBtn]
        
        // Setup search bar
        searchBar.placeholder = "Search frames..."
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        // Setup table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
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
        
        // Empty state message
        if frames.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No saved frames yet\n\nTap \"SAVE FRAME\" to create one"
            emptyLabel.numberOfLines = 0
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = .gray
            emptyLabel.font = UIFont.systemFont(ofSize: 14)
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(emptyLabel)
            
            NSLayoutConstraint.activate([
                emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
    }
    
    @objc private func closePressed() {
        dismiss(animated: true)
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFrames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let frame = filteredFrames[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "frameCell")
        cell.selectionStyle = .none
        
        // Show green checkmark if frame is in animations.json
        let checkmark = bundleFrameIds.contains(frame.id) ? "✓" : ""
        
        // Add frame number to the display using actual frameNumber property
        let frameNumberStr = String(format: "Frame %d", frame.frameNumber)
        cell.textLabel?.text = "\(checkmark) \(frame.name) - \(frameNumberStr)".trimmingCharacters(in: .whitespaces)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        cell.detailTextLabel?.text = dateFormatter.string(from: frame.timestamp)
        cell.detailTextLabel?.textColor = .gray
        cell.textLabel?.textColor = bundleFrameIds.contains(frame.id) ? .systemGreen : .black
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        
        // Add action buttons - icon buttons on the right side
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Rename button
        let renameBtn = UIButton(type: .system)
        renameBtn.setImage(UIImage(systemName: "pencil"), for: .normal)
        renameBtn.tintColor = .gray
        renameBtn.translatesAutoresizingMaskIntoConstraints = false
        renameBtn.addAction(UIAction { _ in
            self.showRenameDialog(for: frame, at: indexPath)
        }, for: .touchUpInside)
        
        // Copy button
        let copyBtn = UIButton(type: .system)
        copyBtn.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyBtn.tintColor = UIColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
        copyBtn.translatesAutoresizingMaskIntoConstraints = false
        copyBtn.addAction(UIAction { _ in
            self.copyFrameToClipboard(frame)
        }, for: .touchUpInside)
        
        // Delete button
        let deleteBtn = UIButton(type: .system)
        deleteBtn.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteBtn.tintColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.addAction(UIAction { _ in
            self.deleteFrame(frame, at: indexPath)
        }, for: .touchUpInside)
        
        stackView.addArrangedSubview(renameBtn)
        stackView.addArrangedSubview(copyBtn)
        stackView.addArrangedSubview(deleteBtn)
        
        cell.contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            renameBtn.widthAnchor.constraint(equalToConstant: 20),
            renameBtn.heightAnchor.constraint(equalToConstant: 20),
            copyBtn.widthAnchor.constraint(equalToConstant: 20),
            copyBtn.heightAnchor.constraint(equalToConstant: 20),
            deleteBtn.widthAnchor.constraint(equalToConstant: 24),
            deleteBtn.heightAnchor.constraint(equalToConstant: 24),
            
            stackView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let frame = filteredFrames[indexPath.row]
        onFrameSelected?(frame)
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    private func showRenameDialog(for frame: SavedEditFrame, at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Rename Frame", message: "Enter new name", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = frame.name
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                SavedFramesManager.shared.renameFrame(id: frame.id, newName: newName)
                self.frames[indexPath.row].name = newName
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func copyFrameToClipboard(_ frame: SavedEditFrame) {
        if let jsonString = SavedFramesManager.shared.exportFrameAsJSON(frame: frame) {
            UIPasteboard.general.string = jsonString
            
            let alert = UIAlertController(title: "Copied!", message: "Frame JSON copied to clipboard. You can paste it into animations.json", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
            print("✅ Frame JSON copied: \(frame.name)")
        }
    }
    
    private func deleteFrame(_ frame: SavedEditFrame, at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Delete Frame?", message: "This cannot be undone", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            SavedFramesManager.shared.deleteFrame(id: frame.id)
            
            // Remove from main frames array
            if let frameIndex = self.frames.firstIndex(where: { $0.id == frame.id }) {
                self.frames.remove(at: frameIndex)
            }
            
            // Update filtered frames and table in a batch
            self.tableView.beginUpdates()
            
            // Remove from filtered array if it exists
            if let filteredIndex = self.filteredFrames.firstIndex(where: { $0.id == frame.id }) {
                self.filteredFrames.remove(at: filteredIndex)
                // Delete the row from the table using the filtered index
                self.tableView.deleteRows(at: [IndexPath(row: filteredIndex, section: 0)], with: .fade)
            }
            
            self.tableView.endUpdates()
            
            // If no frames left, reload to update empty state
            if self.filteredFrames.isEmpty {
                self.tableView.reloadData()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterFrames()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filterFrames()
    }
    
    private func filterFrames() {
        let searchText = searchBar.text?.lowercased() ?? ""
        
        if searchText.isEmpty {
            filteredFrames = frames
        } else {
            filteredFrames = frames.filter { frame in
                frame.name.lowercased().contains(searchText)
            }
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Sync from Bundle
    @objc private func syncFromBundlePressed() {
        let alert = UIAlertController(
            title: "Sync from Bundle?",
            message: "This will replace your local frames with the ones from animations.json. This cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Sync", style: .destructive) { [weak self] _ in
            let result = SavedFramesManager.shared.syncFromBundle()
            
            if result.success {
                // Reload frames from UserDefaults
                self?.frames = SavedFramesManager.shared.getAllFrames()
                self?.filteredFrames = self?.frames ?? []
                self?.tableView.reloadData()
                
                // Show success alert
                let successAlert = UIAlertController(
                    title: "Sync Complete",
                    message: result.message,
                    preferredStyle: .alert
                )
                successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(successAlert, animated: true)
            } else {
                // Show error alert
                let errorAlert = UIAlertController(
                    title: "Sync Failed",
                    message: result.message,
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(errorAlert, animated: true)
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Regenerate Interpolation
    @objc private func regenerateInterpolationPressed() {
        let alert = UIAlertController(
            title: "Regenerate Interpolation?",
            message: "This will regenerate the interpolation values in game_muscles.json based on the current Stand frames from animations.json.\n\nThis ensures your custom Stand frame changes are reflected in muscle progression.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Regenerate", style: .default) { [weak self] _ in
            self?.performInterpolationRegeneration()
        })
        
        present(alert, animated: true)
    }
    
    private func performInterpolationRegeneration() {
        // Load the Stand frames from animations.json
        guard let standFrames = self.loadStandFramesFromBundle() else {
            let errorAlert = UIAlertController(
                title: "Error",
                message: "Could not load Stand frames from animations.json",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errorAlert, animated: true)
            return
        }
        
        // Regenerate interpolation values based on Stand frames
        if MuscleSystem.shared.regenerateInterpolationFromStandFrames(standFrames: standFrames) {
            let successAlert = UIAlertController(
                title: "Success",
                message: "Interpolation values regenerated from Stand frames. game_muscles.json has been updated.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        } else {
            let errorAlert = UIAlertController(
                title: "Error",
                message: "Failed to regenerate interpolation values",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errorAlert, animated: true)
        }
    }
    
    private func loadStandFramesFromBundle() -> [AnimationFrame]? {
        let standFrames = AnimationStorage.shared.loadFrames().filter { frame in
            let isStandFrame = ["Extra Small Stand", "Small Stand", "Stand", "Large Stand", "Extra Large Stand"].contains(frame.name)
            return isStandFrame && frame.frameNumber == 0
        }
        
        guard !standFrames.isEmpty else { return nil }
        return standFrames
    }
}

// MARK: - UIColor Extension for Hex Conversion

extension UIColor {
    func toHexString() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let redInt = Int(lround(Double(red) * 255))
        let greenInt = Int(lround(Double(green) * 255))
        let blueInt = Int(lround(Double(blue) * 255))
        
        let hexString = String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
        
        return hexString
    }
}

