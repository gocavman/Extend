import UIKit
import SpriteKit

// MARK: - StickFigureGameplayEditorViewController
/// Full-screen editor for stick figure customization in gameplay
class StickFigureGameplayEditorViewController: UIViewController, UIColorPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Properties
    private var skView: SKView?
    private var editorScene: StickFigureEditorScene?
    
    private let topContainer = UIView()
    private let bottomContainer = UIView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private var figureScale: CGFloat = 1.0  // Multiplier for display size (1.0 = normal size)
    private var strokeThicknessMultiplier: CGFloat = 1.0
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
    
    // Angle properties for joint positioning
    var neckRotation: CGFloat = 0
    var torsoRotation: CGFloat = 0
    var leftShoulderAngle: CGFloat = 0
    var leftElbowAngle: CGFloat = 0
    var rightShoulderAngle: CGFloat = 0
    var rightElbowAngle: CGFloat = 0
    var leftHipAngle: CGFloat = 0
    var leftKneeAngle: CGFloat = 0
    var rightHipAngle: CGFloat = 0
    var rightKneeAngle: CGFloat = 0
    
    var showInteractiveJoints: Bool = true
    
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
        
        // Bottom container - 50% of screen (scrollable)
        bottomContainer.backgroundColor = .white
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)
        
        // ScrollView in bottom container
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(scrollView)
        
        // Stack view for controls
        stackView.axis = .vertical
        stackView.spacing = 16  // Increased spacing for better visual separation
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Top container - starts after safe area
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.5),
            
            // Bottom container
            bottomContainer.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
            bottomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: bottomContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -24)
        ])
        
        // Add header
        addHeader()
        
        // Add controls
        addControls()
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
        
        // Refresh button
        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("↻", for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        refreshButton.tintColor = .white
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.addTarget(self, action: #selector(refreshPressed), for: .touchUpInside)
        headerView.addSubview(refreshButton)
        
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
            headerView.heightAnchor.constraint(equalToConstant: 30),  // Reduced from 50
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            refreshButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),
            refreshButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupEditor() {
        // Create SpriteKit scene for stick figure display
        let sceneSize = CGSize(width: view.bounds.width, height: view.bounds.height * 0.5)
        editorScene = StickFigureEditorScene(size: sceneSize)
        editorScene?.gameState = gameState
        editorScene?.viewController = self  // Set the view controller reference for joint dragging
        
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
    
    private func addControls() {
        // Interactive Joints Toggle - MOVED TO TOP
        let jointsContainer = UIView()
        jointsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let jointsToggle = UISwitch()
        jointsToggle.isOn = showInteractiveJoints
        jointsToggle.translatesAutoresizingMaskIntoConstraints = false
        jointsToggle.addTarget(self, action: #selector(toggleJoints(_:)), for: .valueChanged)
        jointsContainer.addSubview(jointsToggle)
        
        let jointsLabel = UILabel()
        jointsLabel.text = "Show Interactive Joints"
        jointsLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        jointsLabel.translatesAutoresizingMaskIntoConstraints = false
        jointsContainer.addSubview(jointsLabel)
        
        NSLayoutConstraint.activate([
            jointsLabel.leadingAnchor.constraint(equalTo: jointsContainer.leadingAnchor),
            jointsLabel.centerYAnchor.constraint(equalTo: jointsContainer.centerYAnchor),
            
            jointsToggle.trailingAnchor.constraint(equalTo: jointsContainer.trailingAnchor),
            jointsToggle.centerYAnchor.constraint(equalTo: jointsContainer.centerYAnchor),
            
            jointsContainer.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        stackView.addArrangedSubview(jointsContainer)
        
        // MARK: - Position Buttons (X/Y Movement) with Label
        let positionContainer = UIStackView()
        positionContainer.axis = .horizontal
        positionContainer.spacing = 8
        positionContainer.distribution = .fill
        positionContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Position label
        let positionLabel = UILabel()
        positionLabel.text = "Position: X: 0, Y: 0"
        positionLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        positionLabel.textColor = .darkGray
        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        positionContainer.addArrangedSubview(positionLabel)
        
        // X Position buttons
        let xLeftButton = createPositionButton(title: "← X", action: { [weak self] in
            self?.figureOffsetX -= 5
            self?.updatePositionLabel(positionLabel)
            self?.updateFigure()
        })
        let xRightButton = createPositionButton(title: "X →", action: { [weak self] in
            self?.figureOffsetX += 5
            self?.updatePositionLabel(positionLabel)
            self?.updateFigure()
        })
        
        // Y Position buttons
        let yUpButton = createPositionButton(title: "↑ Y", action: { [weak self] in
            self?.figureOffsetY += 5
            self?.updatePositionLabel(positionLabel)
            self?.updateFigure()
        })
        let yDownButton = createPositionButton(title: "Y ↓", action: { [weak self] in
            self?.figureOffsetY -= 5
            self?.updatePositionLabel(positionLabel)
            self?.updateFigure()
        })
        
        positionContainer.addArrangedSubview(xLeftButton)
        positionContainer.addArrangedSubview(xRightButton)
        positionContainer.addArrangedSubview(yUpButton)
        positionContainer.addArrangedSubview(yDownButton)
        
        stackView.addArrangedSubview(positionContainer)
        
        // Figure Scale & Thickness Section (collapsible)
        let scaleSection = createCollapsibleSection(title: "FIGURE SCALE & THICKNESS", isExpanded: false)
        scaleSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Figure Scale",
            initialValue: figureScale,
            min: 0.5,
            max: 2.0,
            step: 0.1,
            onValueChanged: { [weak self] newValue in
                self?.figureScale = newValue
                self?.updateFigure()
            }
        ))
        scaleSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Stroke Thickness",
            initialValue: strokeThicknessMultiplier,
            min: 0.5,
            max: 2.0,
            step: 0.1,
            onValueChanged: { [weak self] newValue in
                self?.strokeThicknessMultiplier = newValue
                self?.updateFigure()
            }
        ))
        stackView.addArrangedSubview(scaleSection.container)
        
        // Fusiform Section (collapsible)
        let fusiformSection = createCollapsibleSection(title: "FUSIFORM TAPERING", isExpanded: false)
        fusiformSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Upper Torso",
            initialValue: fusiformUpperTorso,
            min: 0,
            max: 10,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.fusiformUpperTorso = newValue
                self?.updateFigure()
            }
        ))
        fusiformSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Lower Torso",
            initialValue: fusiformLowerTorso,
            min: 0,
            max: 10,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.fusiformLowerTorso = newValue
                self?.updateFigure()
            }
        ))
        fusiformSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Upper Arms",
            initialValue: fusiformUpperArms,
            min: 0,
            max: 10,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.fusiformUpperArms = newValue
                self?.updateFigure()
            }
        ))
        fusiformSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Lower Arms",
            initialValue: fusiformLowerArms,
            min: 0,
            max: 10,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.fusiformLowerArms = newValue
                self?.updateFigure()
            }
        ))
        fusiformSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Upper Legs",
            initialValue: fusiformUpperLegs,
            min: 0,
            max: 10,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.fusiformUpperLegs = newValue
                self?.updateFigure()
            }
        ))
        fusiformSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Lower Legs",
            initialValue: fusiformLowerLegs,
            min: 0,
            max: 10,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.fusiformLowerLegs = newValue
                self?.updateFigure()
            }
        ))
        stackView.addArrangedSubview(fusiformSection.container)
        
        let anglesSection = createCollapsibleSection(title: "JOINT ANGLES", isExpanded: false)
        
        // Torso angles
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Neck Rotation",
            initialValue: neckRotation,
            min: -45,
            max: 45,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.neckRotation = newValue
                self?.updateFigure()
            }
        ))
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "Torso Rotation",
            initialValue: torsoRotation,
            min: -45,
            max: 45,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.torsoRotation = newValue
                self?.updateFigure()
            }
        ))
        
        // Left arm angles - removed label, updated slider text
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "L Shoulder",
            initialValue: leftShoulderAngle,
            min: -180,
            max: 180,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.leftShoulderAngle = newValue
                self?.updateFigure()
            }
        ))
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "L Elbow",
            initialValue: leftElbowAngle,
            min: -180,
            max: 180,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.leftElbowAngle = newValue
                self?.updateFigure()
            }
        ))
        
        // Right arm angles - removed label, updated slider text
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "R Shoulder",
            initialValue: rightShoulderAngle,
            min: -180,
            max: 180,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.rightShoulderAngle = newValue
                self?.updateFigure()
            }
        ))
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "R Elbow",
            initialValue: rightElbowAngle,
            min: -180,
            max: 180,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.rightElbowAngle = newValue
                self?.updateFigure()
            }
        ))

        // Left leg angles - removed label, updated slider text
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "L Knee",
            initialValue: leftKneeAngle,
            min: -180,
            max: 180,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.leftKneeAngle = newValue
                self?.updateFigure()
            }
        ))
        
        // Right leg angles - removed label, updated slider text
        anglesSection.contentStackView.addArrangedSubview(createCompactSliderControl(
            label: "R Knee",
            initialValue: rightKneeAngle,
            min: -180,
            max: 180,
            step: 1,
            onValueChanged: { [weak self] newValue in
                self?.rightKneeAngle = newValue
                self?.updateFigure()
            }
        ))
        
        stackView.addArrangedSubview(anglesSection.container)
        
        // Colors Section (collapsible) - AFTER JOINT ANGLES
        let colorsSection = createCollapsibleSection(title: "COLORS", isExpanded: false)
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "Head", colorKey: "head"))
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "Torso", colorKey: "torso"))
        
        // Left arm colors - removed label, updated slider text
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "L Upper Arm", colorKey: "leftUpperArm"))
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "L Lower Arm", colorKey: "leftLowerArm"))
        
        // Right arm colors - removed label, updated slider text
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "R Upper Arm", colorKey: "rightUpperArm"))
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "R Lower Arm", colorKey: "rightLowerArm"))
        
        // Left leg colors - removed label, updated slider text
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "L Upper Leg", colorKey: "leftUpperLeg"))
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "L Lower Leg", colorKey: "leftLowerLeg"))
        
        // Right leg colors - removed label, updated slider text
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "R Upper Leg", colorKey: "rightUpperLeg"))
        colorsSection.contentStackView.addArrangedSubview(createColorPickerRow(label: "R Lower Leg", colorKey: "rightLowerLeg"))
        
        stackView.addArrangedSubview(colorsSection.container)
        
        // Add spacer to push buttons to bottom
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
        
        // Add Object button
        let addObjectButton = UIButton(type: .system)
        addObjectButton.setTitle("+ ADD OBJECT", for: .normal)
        addObjectButton.backgroundColor = UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1.0)
        addObjectButton.setTitleColor(.white, for: .normal)
        addObjectButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        addObjectButton.layer.cornerRadius = 4
        addObjectButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        addObjectButton.addTarget(self, action: #selector(addObjectPressed), for: .touchUpInside)
        stackView.addArrangedSubview(addObjectButton)
        
        // Save/Load buttons
        let buttonContainer = UIStackView()
        buttonContainer.axis = .horizontal
        buttonContainer.spacing = 8
        buttonContainer.distribution = .fillEqually
        
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("SAVE FRAME", for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        saveButton.layer.cornerRadius = 4
        saveButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        saveButton.addTarget(self, action: #selector(savePressed), for: .touchUpInside)
        buttonContainer.addArrangedSubview(saveButton)
        
        let loadButton = UIButton(type: .system)
        loadButton.setTitle("LOAD FRAME", for: .normal)
        loadButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)
        loadButton.setTitleColor(.white, for: .normal)
        loadButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        loadButton.layer.cornerRadius = 4
        loadButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        loadButton.addTarget(self, action: #selector(loadPressed), for: .touchUpInside)
        buttonContainer.addArrangedSubview(loadButton)
        
        stackView.addArrangedSubview(buttonContainer)
    }
    
    // MARK: - Collapsible Section Helper
    private func createCollapsibleSection(title: String, isExpanded: Bool) -> (container: UIView, contentStackView: UIStackView) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let headerButton = UIButton(type: .system)
        headerButton.setTitle("\(isExpanded ? "▼" : "▶") \(title)", for: .normal)
        headerButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        headerButton.contentHorizontalAlignment = .left
        headerButton.setTitleColor(.darkGray, for: .normal)
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        headerButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        container.addSubview(headerButton)
        
        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.spacing = 8
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Only add contentStackView if initially expanded
        if isExpanded {
            container.addSubview(contentStackView)
            // Set up constraints for expanded state
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 4),
                contentStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                contentStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        
        // Simple class to hold mutable state with weak reference to self
        class StateHolder {
            var isExpanded: Bool
            weak var scrollView: UIScrollView?
            init(_ initialState: Bool) {
                self.isExpanded = initialState
            }
        }
        
        let state = StateHolder(isExpanded)
        state.scrollView = scrollView
        
        headerButton.addAction(UIAction { [state, weak contentStackView, weak headerButton, weak container] _ in
            guard let headerButton = headerButton, let container = container, let contentStackView = contentStackView else { return }
            
            state.isExpanded.toggle()
            let newState = state.isExpanded
            
            print("🎮 Section toggle: \(title) -> \(newState ? "expanded" : "collapsed")")
            
            if newState {
                // Expanding - add contentStackView back to container
                if contentStackView.superview == nil {
                    container.addSubview(contentStackView)
                    contentStackView.translatesAutoresizingMaskIntoConstraints = false
                    
                    // Add constraints for expanded state
                    NSLayoutConstraint.activate([
                        contentStackView.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 4),
                        contentStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                        contentStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                        contentStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                    ])
                }
                
                contentStackView.alpha = 0.0
                UIView.animate(withDuration: 0.2) {
                    contentStackView.alpha = 1.0
                    container.layoutIfNeeded()
                    state.scrollView?.layoutIfNeeded()
                }
            } else {
                // Collapsing - remove contentStackView completely
                UIView.animate(withDuration: 0.2, animations: {
                    contentStackView.alpha = 0.0
                }) { _ in
                    contentStackView.removeFromSuperview()
                    container.layoutIfNeeded()
                    state.scrollView?.layoutIfNeeded()
                }
            }
            
            headerButton.setTitle("\(newState ? "▼" : "▶") \(title)", for: .normal)
        }, for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            headerButton.topAnchor.constraint(equalTo: container.topAnchor),
            headerButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerButton.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return (container, contentStackView)
    }
    
    private func createSubSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createPositionButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1.0)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    
    private func updatePositionLabel(_ label: UILabel) {
        label.text = "Position: X: \(Int(figureOffsetX)), Y: \(Int(figureOffsetY))"
    }
    
    private func createColorPickerRow(
        label: String,
        colorKey: String
    ) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelView)
        
        let colorButton = UIButton(type: .system)
        colorButton.backgroundColor = bodyPartColors[colorKey] ?? .black
        colorButton.layer.cornerRadius = 6
        colorButton.layer.borderWidth = 1
        colorButton.layer.borderColor = UIColor.gray.cgColor
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        colorButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        colorButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        container.addSubview(colorButton)
        
        colorButton.addAction(UIAction { [weak self, weak colorButton] _ in
            let vc = UIColorPickerViewController()
            vc.selectedColor = self?.bodyPartColors[colorKey] ?? .black
            vc.delegate = self
            // Store the update closure with colorKey
            self?.pendingColorKey = colorKey
            self?.pendingColorButton = colorButton
            self?.present(vc, animated: true)
        }, for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            colorButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            colorButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return container
    }
    
    // Store pending color update
    private var pendingColorKey: String?
    private weak var pendingColorButton: UIButton?
    
    // MARK: - Collapsible Section Helper
    private func createCompactSliderControl(
        label: String,
        initialValue: CGFloat,
        min minValue: CGFloat,
        max maxValue: CGFloat,
        step: CGFloat,
        onValueChanged: @escaping (CGFloat) -> Void
    ) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(greaterThanOrEqualToConstant: 70).isActive = true
        container.addSubview(labelView)
        
        let minusButton = UIButton(type: .system)
        minusButton.setTitle("−", for: .normal)
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        minusButton.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        minusButton.layer.cornerRadius = 3
        minusButton.translatesAutoresizingMaskIntoConstraints = false
        minusButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        minusButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        container.addSubview(minusButton)
        
        let slider = UISlider()
        slider.minimumValue = Float(minValue)
        slider.maximumValue = Float(maxValue)
        slider.value = Float(initialValue)
        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(slider)
        
        let valueLabel = UILabel()
        valueLabel.text = String(format: step < 1 ? "%.1f" : "%.0f", initialValue)
        valueLabel.font = UIFont.systemFont(ofSize: 11)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true
        container.addSubview(valueLabel)
        
        let plusButton = UIButton(type: .system)
        plusButton.setTitle("+", for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        plusButton.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        plusButton.layer.cornerRadius = 3
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        plusButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        container.addSubview(plusButton)
        
        // Update value label when slider changes
        slider.addAction(UIAction { [weak valueLabel, weak slider] _ in
            if let sliderValue = slider?.value {
                let newValue = CGFloat(sliderValue)
                valueLabel?.text = String(format: step < 1 ? "%.1f" : "%.0f", newValue)
                onValueChanged(newValue)
            }
        }, for: .valueChanged)
        
        // Minus button decreases value
        minusButton.addAction(UIAction { [weak slider] _ in
            if let sliderValue = slider?.value {
                let newValue = Swift.max(Float(minValue), sliderValue - Float(step))
                slider?.value = newValue
                slider?.sendActions(for: .valueChanged)
            }
        }, for: .touchUpInside)
        
        // Plus button increases value
        plusButton.addAction(UIAction { [weak slider] _ in
            if let sliderValue = slider?.value {
                let newValue = Swift.min(Float(maxValue), sliderValue + Float(step))
                slider?.value = newValue
                slider?.sendActions(for: .valueChanged)
            }
        }, for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            minusButton.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 8),
            minusButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            slider.leadingAnchor.constraint(equalTo: minusButton.trailingAnchor, constant: 6),
            slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -6),
            slider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: plusButton.leadingAnchor, constant: -6),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            plusButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            plusButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return container
    }
    
    // MARK: - Actions
    @objc private func toggleJoints(_ sender: UISwitch) {
        showInteractiveJoints = sender.isOn
        updateFigure()
    }
    
    func updateFigure() {
        editorScene?.updateWithValues(
            figureScale: figureScale,
            strokeThicknessMultiplier: strokeThicknessMultiplier,
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
            leftHipAngle: leftHipAngle,
            leftKneeAngle: leftKneeAngle,
            rightHipAngle: rightHipAngle,
            rightKneeAngle: rightKneeAngle,
            showInteractiveJoints: showInteractiveJoints
        )
    }
    
    @objc private func savePressed() {
        print("Save frame pressed")
        
        let alert = UIAlertController(title: "Save Frame", message: "Enter a name for this frame", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Frame name (e.g., 'Pose 1')"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let frameName = alert.textFields?.first?.text, !frameName.isEmpty {
                print("Saving frame: \(frameName)")
                // TODO: Implement actual save logic
                // Store the current figure state with this name
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
    }
    
    @objc private func loadPressed() {
        print("Load frame pressed")
        
        let alert = UIAlertController(title: "Load Frame", message: "Select a saved frame to load", preferredStyle: .actionSheet)
        
        // TODO: Load actual saved frames from storage
        alert.addAction(UIAlertAction(title: "Pose 1", style: .default) { _ in
            print("Loading: Pose 1")
        })
        
        alert.addAction(UIAlertAction(title: "Pose 2", style: .default) { _ in
            print("Loading: Pose 2")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
    }
    
    @objc private func addObjectPressed() {
        print("Add object pressed")
        
        let alert = UIAlertController(title: "Add Object", message: "Select an object to add to the scene", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Image", style: .default) { _ in
            self.showImagePicker()
        })
        
        alert.addAction(UIAlertAction(title: "Shape - Circle", style: .default) { _ in
            print("Add circle shape")
        })
        
        alert.addAction(UIAlertAction(title: "Shape - Rectangle", style: .default) { _ in
            print("Add rectangle shape")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
    }
    
    private func showImagePicker() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true)
    }
    
    @objc private func refreshPressed() {
        print("🎮 Refreshing stick figure to default Stand frame")
        loadStandFrameValues()
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
            
            // DO NOT load the scale from standFrame - keep it at gameplay's 0.1
            // figureScale stays at 0.1 to match gameplay appearance
            
            strokeThicknessMultiplier = CGFloat(standFrame.strokeThickness) / 3.0  // Default appears to be 3
            
            // Fusiforms - these are NEW properties only in Stand frame
            fusiformUpperTorso = CGFloat(standFrame.fusiformUpperTorso)
            fusiformLowerTorso = CGFloat(standFrame.fusiformLowerTorso)
            fusiformUpperArms = CGFloat(standFrame.fusiformUpperArms)
            fusiformLowerArms = CGFloat(standFrame.fusiformLowerArms)
            fusiformUpperLegs = CGFloat(standFrame.fusiformUpperLegs)
            fusiformLowerLegs = CGFloat(standFrame.fusiformLowerLegs)
            
            // Reset angles to exact Stand frame values
            neckRotation = CGFloat(standFrame.headAngle)
            torsoRotation = CGFloat(standFrame.midTorsoAngle)
            leftShoulderAngle = CGFloat(standFrame.leftShoulderAngle)
            leftElbowAngle = CGFloat(standFrame.leftElbowAngle)
            rightShoulderAngle = CGFloat(standFrame.rightShoulderAngle)
            rightElbowAngle = CGFloat(standFrame.rightElbowAngle)
            leftKneeAngle = CGFloat(standFrame.leftKneeAngle)
            rightKneeAngle = CGFloat(standFrame.rightKneeAngle)
            
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
    private var dragOffset: CGPoint = .zero
    private var draggedJointName: String?
    private var lastDragPosition: CGPoint = .zero
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
        
        // Check if a joint was tapped
        if let tappedNode = atPoint(location) as? SKShapeNode,
           tappedNode.name?.hasPrefix("joint_") == true {
            draggedJoint = tappedNode
            draggedJointName = tappedNode.name
            dragOffset = CGPoint(x: location.x - tappedNode.position.x,
                                y: location.y - tappedNode.position.y)
            lastDragPosition = location
            print("🎮 Started dragging joint: \(tappedNode.name ?? "unknown")")
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let draggedJoint = draggedJoint else { return }
        let location = touch.location(in: self)
        
        // Update joint position with offset
        let newPos = CGPoint(x: location.x - dragOffset.x,
                            y: location.y - dragOffset.y)
        draggedJoint.position = newPos
        
        // Calculate angle delta from movement
        if let jointName = draggedJointName {
            let dx = location.x - lastDragPosition.x
            let dy = location.y - lastDragPosition.y
            
            // Convert movement to angle change
            // More horizontal movement = more angle change
            let angleDelta = atan2(dy, dx) * 180 / .pi
            
            updateAngleByDelta(jointName: jointName, angleDelta: angleDelta)
            lastDragPosition = location
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggedJoint = nil
        draggedJointName = nil
        print("🎮 Finished dragging joint")
    }
    
    private func updateAngleByDelta(jointName: String, angleDelta: CGFloat) {
        // Get current angle and apply delta
        let currentAngle: CGFloat
        
        switch jointName {
        case "joint_leftShoulder":
            currentAngle = viewController?.leftShoulderAngle ?? 0
            viewController?.leftShoulderAngle = currentAngle + angleDelta
        case "joint_leftElbow":
            currentAngle = viewController?.leftElbowAngle ?? 0
            viewController?.leftElbowAngle = currentAngle + angleDelta
        case "joint_rightShoulder":
            currentAngle = viewController?.rightShoulderAngle ?? 0
            viewController?.rightShoulderAngle = currentAngle + angleDelta
        case "joint_rightElbow":
            currentAngle = viewController?.rightElbowAngle ?? 0
            viewController?.rightElbowAngle = currentAngle + angleDelta
        case "joint_leftKnee":
            currentAngle = viewController?.leftKneeAngle ?? 0
            viewController?.leftKneeAngle = currentAngle + angleDelta
        case "joint_rightKnee":
            currentAngle = viewController?.rightKneeAngle ?? 0
            viewController?.rightKneeAngle = currentAngle + angleDelta
        case "joint_neck":
            currentAngle = viewController?.neckRotation ?? 0
            viewController?.neckRotation = currentAngle + angleDelta
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
        leftHipAngle: CGFloat = 0,
        leftKneeAngle: CGFloat = 0,
        rightHipAngle: CGFloat = 0,
        rightKneeAngle: CGFloat = 0,
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
        // Note: Hip angles don't exist in StickFigure2D, only knee/foot angles
        updatedFrame.leftKneeAngle = leftKneeAngle
        updatedFrame.rightKneeAngle = rightKneeAngle
        
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
        // Position joints at anatomical layout positions
        // Using placeholder positions since StickFigure2D doesn't expose computed position properties yet
        let jointRadius: CGFloat = 8
        let jointColor = SKColor.blue
        
        // Relative positions from center - will be scaled and positioned
        // These are approximate anatomical positions
        let jointPositions: [(CGPoint, String)] = [
            (CGPoint(x: 0, y: 100), "neck"),           // Neck joint
            (CGPoint(x: 0, y: 0), "waist"),             // Waist joint
            (CGPoint(x: -50, y: 70), "leftShoulder"),   // Left shoulder
            (CGPoint(x: 50, y: 70), "rightShoulder"),   // Right shoulder
            (CGPoint(x: -50, y: 20), "leftElbow"),      // Left elbow
            (CGPoint(x: 50, y: 20), "rightElbow"),      // Right elbow
            (CGPoint(x: -40, y: -80), "leftKnee"),      // Left knee
            (CGPoint(x: 40, y: -80), "rightKnee")       // Right knee
        ]
        
        for (pos, name) in jointPositions {
            let joint = SKShapeNode(circleOfRadius: jointRadius)
            joint.fillColor = jointColor
            joint.strokeColor = SKColor.blue.withAlphaComponent(0.7)
            joint.lineWidth = 1
            joint.position = CGPoint(x: pos.x * scale / 2.4, y: pos.y * scale / 2.4)
            joint.name = "joint_\(name)"
            joint.zPosition = 11
            container.addChild(joint)
        }
    }
}
