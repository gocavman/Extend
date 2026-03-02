import UIKit
import SpriteKit

// MARK: - StickFigureGameplayEditorViewController
/// Full-screen editor for stick figure customization in gameplay
class StickFigureGameplayEditorViewController: UIViewController, UIColorPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    // MARK: - Properties
    private var skView: SKView?
    private var editorScene: StickFigureEditorScene?
    
    private let topContainer = UIView()
    private let bottomContainer = UIView()
    private let controlsTableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private var figureScale: CGFloat = 1.0  // Multiplier for display size (1.0 = normal size)
    private var strokeThicknessMultiplier: CGFloat = 1.0
    private var skeletonSize: CGFloat = 1.0  // Skeleton line thickness multiplier
    private var jointShapeSize: CGFloat = 1.0  // Joint circle size multiplier
    private var fusiformUpperTorso: CGFloat = 4.0
    private var fusiformLowerTorso: CGFloat = 4.0
    private var fusiformUpperArms: CGFloat = 2.0
    private var fusiformLowerArms: CGFloat = 3.0
    private var fusiformUpperLegs: CGFloat = 4.0
    private var fusiformLowerLegs: CGFloat = 4.0
    
    // Position offset
    var figureOffsetX: CGFloat = 0
    var figureOffsetY: CGFloat = 0
    
    // Colors for each body part (stored in dictionary for closure capture)
    var bodyPartColors: [String: UIColor] = [
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
    
    // Color picker properties
    private var pendingColorKey: String?
    private var pendingColorButton: UIButton?
    
    // Angle properties for joint positioning
    var neckRotation: CGFloat = 0
    var torsoRotation: CGFloat = 0
    var leftShoulderAngle: CGFloat = 0
    var leftElbowAngle: CGFloat = 0
    var rightShoulderAngle: CGFloat = 0
    var rightElbowAngle: CGFloat = 0
    var leftHandAngle: CGFloat = 0
    var rightHandAngle: CGFloat = 0
    var leftHipAngle: CGFloat = 0
    var rightHipAngle: CGFloat = 0
    var leftKneeAngle: CGFloat = 0
    var rightKneeAngle: CGFloat = 0
    var leftFootAngle: CGFloat = 0
    var rightFootAngle: CGFloat = 0
    
    var showInteractiveJoints: Bool = true
    var sceneZoom: CGFloat = 1.0  // Zoom level for editor view (1.0 = normal, 2.0 = 2x zoom)
    
    // Section expansion state
    private var expandedSections: Set<Int> = [0, 4, 5]  // Expanded by default (sections 1, 2, 3 collapsed)
    
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
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.5),
            
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
        headerView.addSubview(jointsButton)
        
        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("↻", for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        refreshButton.tintColor = .white
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.addTarget(self, action: #selector(refreshPressed), for: .touchUpInside)
        headerView.addSubview(refreshButton)
        
        // MidTorso toggle - small circle button for body rotation
        let midTorsoButton = UIButton(type: .system)
        midTorsoButton.setTitle("○", for: .normal)
        midTorsoButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        midTorsoButton.tintColor = .white
        midTorsoButton.translatesAutoresizingMaskIntoConstraints = false
        midTorsoButton.addTarget(self, action: #selector(toggleMidTorso(_:)), for: .touchUpInside)
        headerView.addSubview(midTorsoButton)
        
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
            
            jointsButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            jointsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            jointsButton.widthAnchor.constraint(equalToConstant: 24),
            jointsButton.heightAnchor.constraint(equalToConstant: 24),
            
            refreshButton.trailingAnchor.constraint(equalTo: midTorsoButton.leadingAnchor, constant: -8),
            refreshButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            midTorsoButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            midTorsoButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            midTorsoButton.widthAnchor.constraint(equalToConstant: 24),
            midTorsoButton.heightAnchor.constraint(equalToConstant: 24),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupEditor() {
        let sceneSize = CGSize(width: view.bounds.width, height: view.bounds.height * 0.5)
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
                skView.topAnchor.constraint(equalTo: topContainer.topAnchor),
                skView.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
                skView.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
                skView.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor)
            ])
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return 6  // Display (Show Joints, Zoom, Position), Scale, Fusiform, Joints, Save/Load, Objects
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let isExpanded = expandedSections.contains(section)
        
        switch section {
        case 0: return 2  // Zoom, Position buttons (Show Joints moved to header)
        case 1: return isExpanded ? 4 : 0  // Figure Scale, Stroke, Skeleton Size, Joint Shape Size
        case 2: return isExpanded ? 6 : 0  // Upper Torso, Lower Torso, Upper Arms, Lower Arms, Upper Legs, Lower Legs
        case 3: return isExpanded ? 10 : 0  // 10 Joint sliders: head, leftShoulder, rightShoulder, leftElbow, rightElbow, leftKnee, rightKnee, leftCalf, rightCalf, midTorso
        case 4: return 1  // Save + Load (now on same row)
        case 5: return 1  // Add Object
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return nil  // No header for display section
        case 1: return "FIGURE SCALE & THICKNESS"
        case 2: return "FUSIFORM TAPERING"
        case 3: return "JOINT ANGLES"
        case 4: return "FRAMES"
        case 5: return "OBJECTS"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Make sections 1, 2, and 3 collapsible
        guard section == 1 || section == 2 || section == 3 else { return nil }
        
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
            container.distribution = .fillEqually
            container.translatesAutoresizingMaskIntoConstraints = false
            
            let buttons = [("← X", { self.figureOffsetX -= 5 }), ("X →", { self.figureOffsetX += 5 }), ("↑ Y", { self.figureOffsetY += 5 }), ("Y ↓", { self.figureOffsetY -= 5 })]
            
            for (title, action) in buttons {
                let btn = UIButton(type: .system)
                btn.setTitle(title, for: .normal)
                btn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
                btn.addAction(UIAction { _ in action(); self.updateFigure() }, for: .touchUpInside)
                container.addArrangedSubview(btn)
            }
            
            cell.contentView.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -6),
                cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
            ])
            
            
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
            // Stroke Thickness slider
            addSliderCell(cell, label: "Stroke", value: strokeThicknessMultiplier, min: 0.5, max: 2.0, increment: 0.1, onChange: { [weak self] val in
                self?.strokeThicknessMultiplier = val
                self?.updateFigure()
            })
            
        case (1, 2):
            // Skeleton Size slider
            addSliderCell(cell, label: "Skeleton Size", value: skeletonSize, min: 0.5, max: 2.0, increment: 0.1, onChange: { [weak self] val in
                self?.skeletonSize = val
                self?.updateFigure()
            })
            
        case (1, 3):
            // Joint Shape Size slider
            addSliderCell(cell, label: "Joint Shape Size", value: jointShapeSize, min: 0.5, max: 2.0, increment: 0.1, onChange: { [weak self] val in
                self?.jointShapeSize = val
                self?.updateFigure()
            })
            
        case (2, 0): addSliderCell(cell, label: "Upper Torso", value: fusiformUpperTorso, min: 0, max: 10, onChange: { [weak self] val in self?.fusiformUpperTorso = val; self?.updateFigure() })
        case (2, 1): addSliderCell(cell, label: "Lower Torso", value: fusiformLowerTorso, min: 0, max: 10, onChange: { [weak self] val in self?.fusiformLowerTorso = val; self?.updateFigure() })
        case (2, 2): addSliderCell(cell, label: "Upper Arms", value: fusiformUpperArms, min: 0, max: 10, onChange: { [weak self] val in self?.fusiformUpperArms = val; self?.updateFigure() })
        case (2, 3): addSliderCell(cell, label: "Lower Arms", value: fusiformLowerArms, min: 0, max: 10, onChange: { [weak self] val in self?.fusiformLowerArms = val; self?.updateFigure() })
        case (2, 4): addSliderCell(cell, label: "Upper Legs", value: fusiformUpperLegs, min: 0, max: 10, onChange: { [weak self] val in self?.fusiformUpperLegs = val; self?.updateFigure() })
        case (2, 5): addSliderCell(cell, label: "Lower Legs", value: fusiformLowerLegs, min: 0, max: 10, onChange: { [weak self] val in self?.fusiformLowerLegs = val; self?.updateFigure() })
        
        // Joint sliders - section 3
        case (3, 0): addSliderCell(cell, label: "Head", value: neckRotation, min: -180, max: 180, onChange: { [weak self] val in self?.neckRotation = val; self?.updateFigure() })
        case (3, 1): addSliderCell(cell, label: "Left Shoulder", value: leftShoulderAngle, min: -180, max: 180, onChange: { [weak self] val in self?.leftShoulderAngle = val; self?.updateFigure() })
        case (3, 2): addSliderCell(cell, label: "Right Shoulder", value: rightShoulderAngle, min: -180, max: 180, onChange: { [weak self] val in self?.rightShoulderAngle = val; self?.updateFigure() })
        case (3, 3): addSliderCell(cell, label: "Left Elbow", value: leftElbowAngle, min: -180, max: 180, onChange: { [weak self] val in self?.leftElbowAngle = val; self?.updateFigure() })
        case (3, 4): addSliderCell(cell, label: "Right Elbow", value: rightElbowAngle, min: -180, max: 180, onChange: { [weak self] val in self?.rightElbowAngle = val; self?.updateFigure() })
        case (3, 5): addSliderCell(cell, label: "Left Upper Leg", value: leftKneeAngle, min: -180, max: 180, onChange: { [weak self] val in self?.leftKneeAngle = val; self?.updateFigure() })
        case (3, 6): addSliderCell(cell, label: "Right Upper Leg", value: rightKneeAngle, min: -180, max: 180, onChange: { [weak self] val in self?.rightKneeAngle = val; self?.updateFigure() })
        case (3, 7): addSliderCell(cell, label: "Left Calf", value: leftFootAngle, min: -180, max: 180, onChange: { [weak self] val in self?.leftFootAngle = val; self?.updateFigure() })
        case (3, 8): addSliderCell(cell, label: "Right Calf", value: rightFootAngle, min: -180, max: 180, onChange: { [weak self] val in self?.rightFootAngle = val; self?.updateFigure() })
        case (3, 9): addSliderCell(cell, label: "Mid Torso", value: torsoRotation, min: -180, max: 180, onChange: { [weak self] val in self?.torsoRotation = val; self?.updateFigure() })
            
        case (4, 0):
            // Save and Load buttons on same row, split 50/50
            let container = UIStackView()
            container.axis = .horizontal
            container.spacing = 8
            container.distribution = .fillEqually
            container.translatesAutoresizingMaskIntoConstraints = false
            
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
            
            container.addArrangedSubview(saveBtn)
            container.addArrangedSubview(loadBtn)
            
            cell.contentView.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
            ])
            
        case (5, 0):
            // Add object button
            let btn = UIButton(type: .system)
            btn.setTitle("+ ADD OBJECT", for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
            btn.backgroundColor = UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1.0)
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 4
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.addTarget(self, action: #selector(addObjectPressed), for: .touchUpInside)
            cell.contentView.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                btn.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                btn.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                btn.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                btn.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
            ])
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 || indexPath.section == 4 || indexPath.section == 5 {
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
        
        let slider = UISlider()
        slider.minimumValue = Float(minVal)
        slider.maximumValue = Float(maxVal)
        slider.value = Float(value)
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        let valLbl = UILabel()
        valLbl.text = String(format: "%.1f", value)
        valLbl.font = UIFont.systemFont(ofSize: 11)
        valLbl.translatesAutoresizingMaskIntoConstraints = false
        valLbl.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
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
            valLbl.text = String(format: "%.1f", newVal)
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
            valLbl.text = String(format: "%.1f", newVal)
            onChange(newVal)
        }, for: .touchUpInside)
        
        slider.addAction(UIAction { _ in
            let newVal = CGFloat(slider.value)
            valLbl.text = String(format: "%.1f", newVal)
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
    
    @objc private func toggleMidTorso(_ sender: UIButton) {
        // Show/hide or toggle the midTorso joint visibility in the scene
        print("🎮 MidTorso toggle pressed - currently not assigned to a specific action")
        // This can be used for future midTorso-specific controls
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
        loadStandFrameValues()
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
            
            // Reset scale values
            figureScale = 1.0
            strokeThicknessMultiplier = CGFloat(standFrame.strokeThickness) / 3.0
            skeletonSize = 1.0
            jointShapeSize = 1.0
            
            // Fusiforms - these are NEW properties only in Stand frame
            fusiformUpperTorso = CGFloat(standFrame.fusiformUpperTorso)
            fusiformLowerTorso = CGFloat(standFrame.fusiformLowerTorso)
            fusiformUpperArms = CGFloat(standFrame.fusiformUpperArms)
            fusiformLowerArms = CGFloat(standFrame.fusiformLowerArms)
            fusiformUpperLegs = CGFloat(standFrame.fusiformUpperLegs)
            fusiformLowerLegs = CGFloat(standFrame.fusiformLowerLegs)
            
            // Reset ALL angles to exact Stand frame values
            neckRotation = CGFloat(standFrame.headAngle)
            torsoRotation = CGFloat(standFrame.midTorsoAngle)
            leftShoulderAngle = CGFloat(standFrame.leftShoulderAngle)
            leftElbowAngle = CGFloat(standFrame.leftElbowAngle)
            rightShoulderAngle = CGFloat(standFrame.rightShoulderAngle)
            rightElbowAngle = CGFloat(standFrame.rightElbowAngle)
            leftHandAngle = 0  // Reset hand angles
            rightHandAngle = 0
            leftHipAngle = 0  // Reset hip angles
            rightHipAngle = 0
            leftKneeAngle = CGFloat(standFrame.leftKneeAngle)
            rightKneeAngle = CGFloat(standFrame.rightKneeAngle)
            leftFootAngle = 0  // Reset foot angles
            rightFootAngle = 0
            
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
            
            print("🎮 ✓ Loaded Stand frame - scale:\(standFrame.scale), angles: shoulder:\(standFrame.leftShoulderAngle)°, elbow:\(standFrame.leftElbowAngle)°, knee:\(standFrame.leftKneeAngle)°")
        }
    }
    
    // MARK: - Update Figure
    func updateFigure() {
        editorScene?.updateWithValues(
            figureScale: figureScale,
            strokeThicknessMultiplier: strokeThicknessMultiplier,
            skeletonSize: skeletonSize,
            jointShapeSize: jointShapeSize,
            fusiformUpperTorso: fusiformUpperTorso,
            fusiformLowerTorso: fusiformLowerTorso,
            fusiformUpperArms: fusiformUpperArms,
            fusiformLowerArms: fusiformLowerArms,
            fusiformUpperLegs: fusiformUpperLegs,
            fusiformLowerLegs: fusiformLowerLegs,
            figureOffsetX: figureOffsetX,
            figureOffsetY: figureOffsetY,
            neckRotation: neckRotation,
            torsoRotation: torsoRotation,
            leftShoulderAngle: leftShoulderAngle,
            leftElbowAngle: leftElbowAngle,
            rightShoulderAngle: rightShoulderAngle,
            rightElbowAngle: rightElbowAngle,
            leftHandAngle: leftHandAngle,
            rightHandAngle: rightHandAngle,
            leftHipAngle: leftHipAngle,
            leftKneeAngle: leftKneeAngle,
            rightHipAngle: rightHipAngle,
            rightKneeAngle: rightKneeAngle,
            leftFootAngle: leftFootAngle,
            rightFootAngle: rightFootAngle,
            showInteractiveJoints: showInteractiveJoints
        )
    }
    
    // MARK: - Button Actions
    @objc private func savePressed() {
        print("🎮 Save button pressed")
        let alert = UIAlertController(title: "Save Frame", message: "Enter a name for this frame", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Frame name"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            
            // Create a temporary StickFigure2D with current angles to use with SavedEditFrame initializer
            var tempPose = self.gameState?.standFrame ?? StickFigure2D()
            tempPose.headAngle = self.neckRotation
            tempPose.midTorsoAngle = self.torsoRotation
            tempPose.leftShoulderAngle = self.leftShoulderAngle
            tempPose.leftElbowAngle = self.leftElbowAngle
            tempPose.rightShoulderAngle = self.rightShoulderAngle
            tempPose.rightElbowAngle = self.rightElbowAngle
            tempPose.leftHandAngle = self.leftHandAngle
            tempPose.rightHandAngle = self.rightHandAngle
            tempPose.leftHipAngle = self.leftHipAngle
            tempPose.rightHipAngle = self.rightHipAngle
            tempPose.leftKneeAngle = self.leftKneeAngle
            tempPose.rightKneeAngle = self.rightKneeAngle
            tempPose.leftFootAngle = self.leftFootAngle
            tempPose.rightFootAngle = self.rightFootAngle
            
            // Create EditModeValues to use with SavedEditFrame initializer
            let editValues = EditModeValues(
                figureScale: self.figureScale,
                strokeThicknessMultiplier: self.strokeThicknessMultiplier,
                fusiformUpperTorso: self.fusiformUpperTorso,
                fusiformLowerTorso: self.fusiformLowerTorso,
                fusiformUpperArms: self.fusiformUpperArms,
                fusiformLowerArms: self.fusiformLowerArms,
                fusiformUpperLegs: self.fusiformUpperLegs,
                fusiformLowerLegs: self.fusiformLowerLegs,
                showGrid: true,
                showJoints: self.showInteractiveJoints,
                positionX: self.figureOffsetX,
                positionY: self.figureOffsetY
            )
            
            let frame = SavedEditFrame(name: name, from: editValues, pose: tempPose)
            SavedFramesManager.shared.saveFrame(frame)
            
            let successAlert = UIAlertController(title: "Saved!", message: "Frame '\(name)' has been saved", preferredStyle: .alert)
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
        let alert = UIAlertController(title: "Add Object", message: "Select an asset", preferredStyle: .actionSheet)
        
        let assets = ["Apple", "Dumbbell", "Kettlebell", "Shaker"]
        
        for asset in assets {
            alert.addAction(UIAlertAction(title: asset, style: .default) { [weak self] _ in
                self?.addObject(asset: asset)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
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
        sprite.scale(to: CGSize(width: 50, height: 50))
        sprite.name = "object_\(asset)"
        
        // Make sprite interactive with physics
        sprite.physicsBody = SKPhysicsBody(circleOfRadius: 25)
        sprite.physicsBody?.isDynamic = false
        sprite.physicsBody?.affectedByGravity = false
        
        // Add rotate dot (top-right corner of object)
        let rotateDot = SKShapeNode(circleOfRadius: 5)
        rotateDot.fillColor = .yellow
        rotateDot.strokeColor = .yellow
        rotateDot.lineWidth = 1
        rotateDot.position = CGPoint(x: 25, y: 25)  // Top-right relative to object
        rotateDot.name = "object_rotate_\(asset)"
        rotateDot.zPosition = 6
        sprite.addChild(rotateDot)
        
        // Add resize dot (bottom-right corner of object)
        let resizeDot = SKShapeNode(circleOfRadius: 5)
        resizeDot.fillColor = .cyan
        resizeDot.strokeColor = .cyan
        resizeDot.lineWidth = 1
        resizeDot.position = CGPoint(x: 25, y: -25)  // Bottom-right relative to object
        resizeDot.name = "object_resize_\(asset)"
        resizeDot.zPosition = 6
        sprite.addChild(resizeDot)
        
        editorScene.addChild(sprite)
        print("🎮 Added \(asset) object to scene at position \(sprite.position)")
    }
    
    private func applyFrame(_ frame: SavedEditFrame) {
        print("🎮 Applying frame: \(frame.name)")
        neckRotation = frame.headAngle
        torsoRotation = frame.midTorsoAngle
        leftShoulderAngle = frame.leftShoulderAngle
        leftElbowAngle = frame.leftElbowAngle
        rightShoulderAngle = frame.rightShoulderAngle
        rightElbowAngle = frame.rightElbowAngle
        leftHandAngle = frame.leftHandAngle
        rightHandAngle = frame.rightHandAngle
        leftHipAngle = frame.leftHipAngle
        rightHipAngle = frame.rightHipAngle
        leftKneeAngle = frame.leftKneeAngle
        rightKneeAngle = frame.rightKneeAngle
        leftFootAngle = frame.leftFootAngle
        rightFootAngle = frame.rightFootAngle
        figureScale = frame.figureScale
        strokeThicknessMultiplier = frame.strokeThicknessMultiplier
        fusiformUpperTorso = frame.fusiformUpperTorso
        fusiformLowerTorso = frame.fusiformLowerTorso
        fusiformUpperArms = frame.fusiformUpperArms
        fusiformLowerArms = frame.fusiformLowerArms
        fusiformUpperLegs = frame.fusiformUpperLegs
        fusiformLowerLegs = frame.fusiformLowerLegs
        figureOffsetX = frame.positionX
        figureOffsetY = frame.positionY
        
        // Reload table view to show updated values
        controlsTableView.reloadData()
        updateFigure()
    }
    
    @objc private func closePressed() {
        dismiss(animated: true)
    }
    
    // MARK: - UIColorPickerViewControllerDelegate
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        if let colorKey = pendingColorKey {
            bodyPartColors[colorKey] = viewController.selectedColor
            pendingColorButton?.backgroundColor = viewController.selectedColor
            updateFigure()
        }
        dismiss(animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            print("Selected image: \(image)")
            // TODO: Add selected image to the scene
        }
        dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
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
        
        // First check if tapping on an object
        if let tappedObject = atPoint(location) as? SKSpriteNode,
           tappedObject.name?.hasPrefix("object_") == true {
            draggedObject = tappedObject
            dragOffset = CGPoint(x: location.x - tappedObject.position.x,
                                y: location.y - tappedObject.position.y)
            lastDragPosition = location
            print("🎮 Started dragging object: \(tappedObject.name ?? "unknown")")
            return
        }
        
        // Check if a joint was tapped - get all nodes at location
        let nodes = self.nodes(at: location)
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
        
        // Handle object dragging
        if let draggedObject = draggedObject {
            let newPos = CGPoint(x: location.x - dragOffset.x,
                                y: location.y - dragOffset.y)
            draggedObject.position = newPos
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
            
            // Handle center/midtorso joints specially - moves or rotates the figure
            if jointName == "joint_center" || jointName == "joint_midTorso" {
                viewController?.figureOffsetX += dx
                viewController?.figureOffsetY += dy
            } else {
                // For other joints: increase sensitivity to 2.0 degrees per pixel
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
        case "joint_neck":
            // Neck: rotates mid torso around waist
            currentAngle = viewController?.torsoRotation ?? 0
            viewController?.torsoRotation = currentAngle + angleDelta
            
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
            
        case "joint_midTorso":
            // Mid Torso: rotates upper body around waist
            currentAngle = viewController?.torsoRotation ?? 0
            viewController?.torsoRotation = currentAngle + angleDelta
            
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
        let stickFigureNode = tempScene.renderStickFigure(standFrame, at: CGPoint.zero, scale: 1.2)
        container.addChild(stickFigureNode)
        
        addChild(container)
        characterNode = container
    }
    
    func updateWithValues(
        figureScale: CGFloat,
        strokeThicknessMultiplier: CGFloat,
        skeletonSize: CGFloat = 1.0,
        jointShapeSize: CGFloat = 1.0,
        fusiformUpperTorso: CGFloat,
        fusiformLowerTorso: CGFloat,
        fusiformUpperArms: CGFloat,
        fusiformLowerArms: CGFloat,
        fusiformUpperLegs: CGFloat,
        fusiformLowerLegs: CGFloat,
        figureOffsetX: CGFloat = 0,
        figureOffsetY: CGFloat = 0,
        neckRotation: CGFloat = 0,
        torsoRotation: CGFloat = 0,
        leftShoulderAngle: CGFloat = 0,
        leftElbowAngle: CGFloat = 0,
        rightShoulderAngle: CGFloat = 0,
        rightElbowAngle: CGFloat = 0,
        leftHandAngle: CGFloat = 0,
        rightHandAngle: CGFloat = 0,
        leftHipAngle: CGFloat = 0,
        leftKneeAngle: CGFloat = 0,
        rightHipAngle: CGFloat = 0,
        rightKneeAngle: CGFloat = 0,
        leftFootAngle: CGFloat = 0,
        rightFootAngle: CGFloat = 0,
        showInteractiveJoints: Bool = true
    ) {
        // Update the stick figure with new values
        print("🎮 Updating editor scene with new values")
        print("🎮 Angles - Neck:\(Int(neckRotation))° Torso:\(Int(torsoRotation))° LShoulder:\(Int(leftShoulderAngle))° LElbow:\(Int(leftElbowAngle))°")
        
        guard let gameState = gameState, let standFrame = gameState.standFrame else { return }
        
        // Remove old character
        characterNode?.removeFromParent()
        
        // Create updated frame with angles
        var updatedFrame = standFrame
        updatedFrame.fusiformUpperTorso = fusiformUpperTorso
        updatedFrame.fusiformLowerTorso = fusiformLowerTorso
        updatedFrame.fusiformUpperArms = fusiformUpperArms
        updatedFrame.fusiformLowerArms = fusiformLowerArms
        updatedFrame.fusiformUpperLegs = fusiformUpperLegs
        updatedFrame.fusiformLowerLegs = fusiformLowerLegs
        
        // Apply angles to the frame - map to existing properties
        updatedFrame.headAngle = neckRotation           // Maps neckRotation to headAngle
        updatedFrame.midTorsoAngle = torsoRotation      // Maps torsoRotation to midTorsoAngle
        updatedFrame.leftShoulderAngle = leftShoulderAngle
        updatedFrame.leftElbowAngle = leftElbowAngle
        updatedFrame.rightShoulderAngle = rightShoulderAngle
        updatedFrame.rightElbowAngle = rightElbowAngle
        updatedFrame.leftHandAngle = leftHandAngle
        updatedFrame.rightHandAngle = rightHandAngle
        updatedFrame.leftKneeAngle = leftKneeAngle
        updatedFrame.rightKneeAngle = rightKneeAngle
        updatedFrame.leftFootAngle = leftFootAngle
        updatedFrame.rightFootAngle = rightFootAngle
        
        // Apply stroke thickness multiplier
        updatedFrame.strokeThickness *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessJoints *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessUpperTorso *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessLowerTorso *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessUpperArms *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessLowerArms *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessUpperLegs *= strokeThicknessMultiplier
        updatedFrame.strokeThicknessLowerLegs *= strokeThicknessMultiplier
        
        // Create character node centered vertically with offset
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2 + figureOffsetX, y: size.height / 2 + figureOffsetY)
        container.zPosition = 10
        
        // Render the actual stick figure with consistent scale
        let tempScene = GameScene(size: size)
        tempScene.gameState = gameState  // PASS the gameState so rendering works correctly
        // Base scale 1.2 provides good visibility, multiplied by figureScale slider for adjustment
        let renderScale = 1.2 * figureScale
        let stickFigureNode = tempScene.renderStickFigure(updatedFrame, at: CGPoint.zero, scale: renderScale)
        container.addChild(stickFigureNode)
        
        print("🎮 Editor: Added stick figure with \(stickFigureNode.children.count) child nodes, scale: \(renderScale), container zPos: \(container.zPosition)")
        
        // Draw interactive joints if enabled
        if showInteractiveJoints {
            let renderScale = 1.2 * figureScale  // Use same scale as figure
            drawInteractiveJoints(on: container, frame: updatedFrame, scale: renderScale)
        }
        
        addChild(container)
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
            (frame.neckPosition, "neck"),
            (frame.waistPosition, "midTorso"),  // Add midTorso at waist for rotating the body
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
            
            // Check if this bundle frame is already in saved frames
            if !allFrames.contains(where: { $0.id == bundleFrame.id }) {
                // Convert AnimationFrame to SavedEditFrame
                let pose = bundleFrame.pose.toStickFigure2D()
                let editValues = EditModeValues(
                    figureScale: pose.scale,
                    strokeThicknessMultiplier: pose.strokeThickness,
                    fusiformUpperTorso: pose.fusiformUpperTorso,
                    fusiformLowerTorso: pose.fusiformLowerTorso,
                    fusiformUpperArms: pose.fusiformUpperArms,
                    fusiformLowerArms: pose.fusiformLowerArms,
                    fusiformUpperLegs: pose.fusiformUpperLegs,
                    fusiformLowerLegs: pose.fusiformLowerLegs,
                    showGrid: true,
                    showJoints: true,
                    positionX: 0,
                    positionY: 0
                )
                let savedFrame = SavedEditFrame(id: bundleFrame.id, name: bundleFrame.name, from: editValues, pose: pose)
                allFrames.append(savedFrame)
            }
        }
        
        // Sort by timestamp (newest first)
        frames = allFrames.sorted { $0.timestamp > $1.timestamp }
        filteredFrames = frames
        
        // Setup navigation
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closePressed))
        
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
        
        // Show green checkmark if frame is in animations.json
        let checkmark = bundleFrameIds.contains(frame.id) ? "✓" : ""
        
        cell.textLabel?.text = "\(checkmark) \(frame.name)".trimmingCharacters(in: .whitespaces)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        cell.detailTextLabel?.text = dateFormatter.string(from: frame.timestamp)
        cell.detailTextLabel?.textColor = .gray
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.textColor = bundleFrameIds.contains(frame.id) ? .systemGreen : .black
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let frame = filteredFrames[indexPath.row]
        onFrameSelected?(frame)
        dismiss(animated: true)
    }
    
    // MARK: - Context Menu (Edit, Delete, Copy)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let frame = filteredFrames[indexPath.row]
        
        return UIContextMenuConfiguration(actionProvider: { _ in
            let loadAction = UIAction(title: "Load", image: UIImage(systemName: "arrow.down.doc")) { _ in
                self.onFrameSelected?(frame)
                self.dismiss(animated: true)
            }
            
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.showRenameDialog(for: frame, at: indexPath)
            }
            
            let copyAction = UIAction(title: "Copy JSON to Clipboard", image: UIImage(systemName: "doc.on.doc")) { _ in
                self.copyFrameToClipboard(frame)
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.deleteFrame(frame, at: indexPath)
            }
            
            return UIMenu(children: [loadAction, renameAction, copyAction, deleteAction])
        })
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
        if let jsonString = SavedFramesManager.shared.exportFrameAsJSON(id: frame.id) {
            UIPasteboard.general.string = jsonString
            
            let alert = UIAlertController(title: "Copied!", message: "Frame JSON copied to clipboard. You can paste it into animations.json", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
            print("✅ Frame JSON copied: \(frame.name)")
        }
    }
    
    private func deleteFrame(_ frame: SavedEditFrame, at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Delete Frame?", message: "This cannot be undone", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            SavedFramesManager.shared.deleteFrame(id: frame.id)
            // Remove from both arrays
            if let frameIndex = self.frames.firstIndex(where: { $0.id == frame.id }) {
                self.frames.remove(at: frameIndex)
            }
            self.filterFrames()
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            
            if self.frames.isEmpty {
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
}
