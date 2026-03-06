import UIKit
import SwiftUI

/// UIKit controller for customizing stick figure appearance colors and muscle development
class StickFigureAppearanceViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIColorPickerViewControllerDelegate {
    let appearance = StickFigureAppearance.shared
    let muscleSystem = MuscleSystem.shared
    var gameState: StickFigureGameState?
    var onDismiss: (() -> Void)?
    var onMusclePointsChanged: (() -> Void)?
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var expandedSections: Set<Int> = [0]  // Muscles expanded by default, Colors collapsed
    private var pendingColorCallback: ((UIColor) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        loadAppearanceFromGameState()
    }
    
    private func setupUI() {
        // Header
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        headerView.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        headerView.layer.borderWidth = 1.0
        
        let titleLabel = UILabel()
        titleLabel.text = "Customization"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .gray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        // Table view setup
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        
        view.addSubview(headerView)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadAppearanceFromGameState() {
        // Load colors from gameState if available
        if gameState != nil {
            // Colors are already in the shared instance
            // Just refresh the display
            tableView.reloadData()
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2  // Muscles and Colors
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return expandedSections.contains(0) ? ((muscleSystem.config?.muscles.count ?? 0) + 2) : 0  // Muscles section (info + muscles + buttons, no extra empty row)
        case 1: return expandedSections.contains(1) ? 6 : 0  // Colors section (6 rows: Head, Torso, Arms, Legs, Accessories, Reset)
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "MUSCLE DEVELOPMENT"
        case 1: return "COLORS"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 0 || section == 1 else { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
        
        let label = UILabel()
        label.text = self.tableView(tableView, titleForHeaderInSection: section)
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
            label.leadingAnchor.constraint(equalTo: arrow.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleSectionExpansion(_:)))
        tapGesture.delegate = self
        headerView.addGestureRecognizer(tapGesture)
        headerView.tag = section
        headerView.isUserInteractionEnabled = true
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Add extra spacing above Muscle Development section
        if section == 0 {
            return 50  // Normal header height + extra spacing
        }
        return 50  // Standard header height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        switch indexPath.section {
        case 0: return createMuscleCell(tableView, cellForRowAt: indexPath)
        case 1: return createColorCell(tableView, cellForRowAt: indexPath)
        default: return cell
        }
    }
    
    private func createColorCell(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "colorCell")
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        switch indexPath.row {
        case 0:  // Head
            let stack = createColorRow(label: "Head", color: appearance.headColor, onChange: { [weak self] color in
                self?.appearance.headColor = Color(uiColor: color)
                self?.saveAppearanceToGameState()
                self?.onMusclePointsChanged?()
            })
            cell.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 44).isActive = true
            
        case 1:  // Torso
            let stack = createColorRow(label: "Torso", color: appearance.torsoColor, onChange: { [weak self] color in
                self?.appearance.torsoColor = Color(uiColor: color)
                self?.saveAppearanceToGameState()
                self?.onMusclePointsChanged?()
            })
            cell.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 44).isActive = true
            
        case 2:  // Arms Grid
            let grid = createColorGrid([
                ("L Upper", appearance.leftUpperArmColor, { [weak self] color in
                    self?.appearance.leftUpperArmColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("R Upper", appearance.rightUpperArmColor, { [weak self] color in
                    self?.appearance.rightUpperArmColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("L Lower", appearance.leftLowerArmColor, { [weak self] color in
                    self?.appearance.leftLowerArmColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("R Lower", appearance.rightLowerArmColor, { [weak self] color in
                    self?.appearance.rightLowerArmColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                })
            ])
            cell.contentView.addSubview(grid)
            NSLayoutConstraint.activate([
                grid.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                grid.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                grid.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                grid.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 76).isActive = true
            
        case 3:  // Legs Grid
            let grid = createColorGrid([
                ("L Upper", appearance.leftUpperLegColor, { [weak self] color in
                    self?.appearance.leftUpperLegColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("R Upper", appearance.rightUpperLegColor, { [weak self] color in
                    self?.appearance.rightUpperLegColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("L Lower", appearance.leftLowerLegColor, { [weak self] color in
                    self?.appearance.leftLowerLegColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("R Lower", appearance.rightLowerLegColor, { [weak self] color in
                    self?.appearance.rightLowerLegColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                })
            ])
            cell.contentView.addSubview(grid)
            NSLayoutConstraint.activate([
                grid.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                grid.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                grid.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                grid.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 76).isActive = true
            
        case 4:  // Accessories Grid
            let grid = createColorGrid([
                ("Hands", appearance.handColor, { [weak self] color in
                    self?.appearance.handColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("Feet", appearance.footColor, { [weak self] color in
                    self?.appearance.footColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                }),
                ("Joints", appearance.jointColor, { [weak self] color in
                    self?.appearance.jointColor = Color(uiColor: color)
                    self?.saveAppearanceToGameState()
                    self?.onMusclePointsChanged?()
                })
            ])
            cell.contentView.addSubview(grid)
            NSLayoutConstraint.activate([
                grid.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                grid.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                grid.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                grid.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 76).isActive = true
            
        case 5:  // Reset button
            let button = UIButton(type: .system)
            button.setTitle("Reset Colors", for: .normal)
            button.backgroundColor = UIColor.red.withAlphaComponent(0.7)
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 6
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(resetColorsTapped), for: .touchUpInside)
            cell.contentView.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                button.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                button.heightAnchor.constraint(equalToConstant: 36)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 52).isActive = true
            
        default:
            break
        }
        
        return cell
    }
    
    private func createMuscleCell(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "muscleCell")
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        guard let muscles = muscleSystem.config?.muscles else { return cell }
        
        if indexPath.row < 1 {  // Info label
            let label = UILabel()
            label.text = "(0 = Extra Small, 25 = Small, 50 = Stand, 75 = Large, 100 = Extra Large)"
            label.font = UIFont.systemFont(ofSize: 10)
            label.textColor = .gray
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            
        } else if indexPath.row <= muscles.count {  // Muscle rows
            let muscle = muscles[indexPath.row - 1]
            let row = createMuscleControlRow(muscle: muscle)
            cell.contentView.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                row.heightAnchor.constraint(equalToConstant: 32)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 48).isActive = true
            
        } else if indexPath.row == muscles.count + 1 {  // Buttons row (only row after muscles)
            let mainStack = UIStackView()
            mainStack.axis = .vertical
            mainStack.spacing = 8
            mainStack.distribution = .fill
            mainStack.translatesAutoresizingMaskIntoConstraints = false
            
            // First row: Reset All and Max All buttons
            let buttonsStack = UIStackView()
            buttonsStack.axis = .horizontal
            buttonsStack.spacing = 8
            buttonsStack.distribution = .fillEqually
            
            let resetButton = UIButton(type: .system)
            resetButton.setTitle("Reset All", for: .normal)
            resetButton.backgroundColor = UIColor.orange.withAlphaComponent(0.7)
            resetButton.setTitleColor(.white, for: .normal)
            resetButton.layer.cornerRadius = 4
            resetButton.addTarget(self, action: #selector(resetAllMusclesTapped), for: .touchUpInside)
            
            let maxButton = UIButton(type: .system)
            maxButton.setTitle("Max All", for: .normal)
            maxButton.backgroundColor = UIColor.green.withAlphaComponent(0.7)
            maxButton.setTitleColor(.white, for: .normal)
            maxButton.layer.cornerRadius = 4
            maxButton.addTarget(self, action: #selector(maxAllMusclesTapped), for: .touchUpInside)
            
            buttonsStack.addArrangedSubview(resetButton)
            buttonsStack.addArrangedSubview(maxButton)
            buttonsStack.heightAnchor.constraint(equalToConstant: 32).isActive = true
            
            // Second row: Set to custom value
            let customStack = UIStackView()
            customStack.axis = .horizontal
            customStack.spacing = 8
            customStack.alignment = .center
            customStack.distribution = .fill
            
            let customLabel = UILabel()
            customLabel.text = "Set All To:"
            customLabel.font = UIFont.systemFont(ofSize: 12)
            customLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            let customTextField = UITextField()
            customTextField.placeholder = "0-100"
            customTextField.keyboardType = .numberPad
            customTextField.borderStyle = .roundedRect
            customTextField.textAlignment = .center
            customTextField.font = UIFont.systemFont(ofSize: 12)
            customTextField.tag = 999  // Tag to identify this field later
            
            let customButton = UIButton(type: .system)
            customButton.setTitle("Apply", for: .normal)
            customButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
            customButton.setTitleColor(.white, for: .normal)
            customButton.layer.cornerRadius = 4
            customButton.addTarget(self, action: #selector(customValueButtonTapped(_:)), for: .touchUpInside)
            customButton.tag = 999  // Same tag to pair with text field
            
            customStack.addArrangedSubview(customLabel)
            customStack.addArrangedSubview(customTextField)
            customStack.addArrangedSubview(customButton)
            customTextField.widthAnchor.constraint(equalToConstant: 60).isActive = true
            customButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
            customStack.heightAnchor.constraint(equalToConstant: 32).isActive = true
            
            mainStack.addArrangedSubview(buttonsStack)
            mainStack.addArrangedSubview(customStack)
            
            cell.contentView.addSubview(mainStack)
            NSLayoutConstraint.activate([
                mainStack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                mainStack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                mainStack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                mainStack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            cell.contentView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        }
        
        return cell
    }
    
    @objc private func toggleSectionExpansion(_ gesture: UITapGestureRecognizer) {
        guard let headerView = gesture.view else { return }
        let section = headerView.tag
        
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
        
        tableView.reloadSections([section], with: .fade)
    }
    
    private func createColorRow(label: String, color: Color, onChange: @escaping (UIColor) -> Void) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 14)
        labelView.setContentCompressionResistancePriority(.required, for: .horizontal)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        
        let colorButton = UIButton(type: .system)
        colorButton.backgroundColor = UIColor(color)
        colorButton.layer.cornerRadius = 6
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        colorButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        colorButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        colorButton.addAction(UIAction { [weak colorButton] _ in
            self.presentColorPicker(initialColor: UIColor(color)) { selectedColor in
                colorButton?.backgroundColor = selectedColor
                onChange(selectedColor)
            }
        }, for: .touchUpInside)
        
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(UIView())  // Spacer
        row.addArrangedSubview(colorButton)
        
        return row
    }
    
    private func createColorGrid(_ colors: [(String, Color, (UIColor) -> Void)]) -> UIStackView {
        let grid = UIStackView()
        grid.axis = .horizontal
        grid.spacing = 8
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        for (label, color, onChange) in colors {
            let column = UIStackView()
            column.axis = .vertical
            column.spacing = 6
            column.alignment = .center
            
            let labelView = UILabel()
            labelView.text = label
            labelView.font = UIFont.systemFont(ofSize: 10)
            labelView.textColor = .gray
            
            let colorButton = UIButton(type: .system)
            colorButton.backgroundColor = UIColor(color)
            colorButton.layer.cornerRadius = 6
            colorButton.translatesAutoresizingMaskIntoConstraints = false
            colorButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
            colorButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
            
            colorButton.addAction(UIAction { [weak colorButton] _ in
                self.presentColorPicker(initialColor: UIColor(color)) { selectedColor in
                    colorButton?.backgroundColor = selectedColor
                    onChange(selectedColor)
                }
            }, for: .touchUpInside)
            
            column.addArrangedSubview(labelView)
            column.addArrangedSubview(colorButton)
            grid.addArrangedSubview(column)
        }
        
        return grid
    }
    
    private func createMuscleControlRow(muscle: MuscleDefinition) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        let nameLabel = UILabel()
        nameLabel.text = muscle.name
        nameLabel.font = UIFont.systemFont(ofSize: 13)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let minus5 = createSmallButton(title: "-5", color: .systemRed) { [weak self] in
            self?.adjustMusclePoints(muscleId: muscle.id, delta: -5)
            self?.tableView.reloadData()
        }
        
        let minus1 = createIconButton(systemName: "minus.circle.fill", color: .systemRed) { [weak self] in
            self?.adjustMusclePoints(muscleId: muscle.id, delta: -1)
            self?.tableView.reloadData()
        }
        
        let pointsLabel = UILabel()
        pointsLabel.text = "\(Int(gameState?.muscleState.getPoints(for: muscle.id) ?? 0))"
        pointsLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        pointsLabel.textAlignment = .center
        pointsLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsLabel.widthAnchor.constraint(equalToConstant: 35).isActive = true
        pointsLabel.tag = muscle.id.hashValue  // Tag for easy updates
        
        let plus1 = createIconButton(systemName: "plus.circle.fill", color: .systemGreen) { [weak self] in
            self?.adjustMusclePoints(muscleId: muscle.id, delta: 1)
            self?.tableView.reloadData()
        }
        
        let plus5 = createSmallButton(title: "+5", color: .systemGreen) { [weak self] in
            self?.adjustMusclePoints(muscleId: muscle.id, delta: 5)
            self?.tableView.reloadData()
        }
        
        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(UIView())  // Spacer
        row.addArrangedSubview(minus5)
        row.addArrangedSubview(minus1)
        row.addArrangedSubview(pointsLabel)
        row.addArrangedSubview(plus1)
        row.addArrangedSubview(plus5)
        
        return row
    }
    
    private func createSmallButton(title: String, color: UIColor, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.7)
        button.layer.cornerRadius = 4
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    
    private func createIconButton(systemName: String, color: UIColor, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = color
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    
    private func adjustMusclePoints(muscleId: String, delta: Int) {
        guard let gameState = gameState else { return }
        gameState.muscleState.addPoints(Double(delta), to: muscleId)
        gameState.saveMuscleState()
        onMusclePointsChanged?()
    }
    
    private func saveAppearanceToGameState() {
        // Save appearance colors to game state
        if gameState != nil {
            // The colors are already in the shared StickFigureAppearance instance
            // Just ensure they're also saved to game state if needed
        }
    }
    
    @objc private func closeTapped() {
        saveAppearanceToGameState()
        onDismiss?()
        dismiss(animated: true)
    }
    
    @objc private func resetColorsTapped() {
        appearance.resetToDefaults()
        saveAppearanceToGameState()
        tableView.reloadSections([1], with: .fade)
        onMusclePointsChanged?()
    }
    
    private func presentColorPicker(initialColor: UIColor, completion: @escaping (UIColor) -> Void) {
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = initialColor
        colorPicker.delegate = self
        colorPicker.supportsAlpha = false
        pendingColorCallback = completion
        present(colorPicker, animated: true)
    }
    
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let selectedColor = viewController.selectedColor
        pendingColorCallback?(selectedColor)
        pendingColorCallback = nil
        saveAppearanceToGameState()
        onMusclePointsChanged?()
    }
    
    @objc private func resetAllMusclesTapped() {
        guard let gameState = gameState else {
            print("❌ No gameState available for resetAllMuscles")
            return
        }
        guard let muscles = muscleSystem.config?.muscles else { return }
        for muscle in muscles {
            gameState.muscleState.setPoints(0, for: muscle.id)
        }
        gameState.saveMuscleState()
        tableView.reloadSections([0], with: .fade)
        onMusclePointsChanged?()
        print("✓ Reset all muscles to 0")
    }
    
    @objc private func maxAllMusclesTapped() {
        guard let gameState = gameState else {
            print("❌ No gameState available for maxAllMuscles")
            return
        }
        guard let muscles = muscleSystem.config?.muscles else { return }
        for muscle in muscles {
            gameState.muscleState.setPoints(100, for: muscle.id)
        }
        gameState.saveMuscleState()
        tableView.reloadSections([0], with: .fade)
        onMusclePointsChanged?()
        print("✓ Maxed all muscles to 100")
    }
    
    @objc private func customValueButtonTapped(_ sender: UIButton) {
        // Find the text field with tag 999
        guard let textField = tableView.viewWithTag(999) as? UITextField,
              let valueText = textField.text, !valueText.isEmpty,
              let value = Double(valueText),
              value >= 0 && value <= 100,
              let gameState = gameState,
              let muscles = muscleSystem.config?.muscles else {
            print("❌ Invalid input or missing gameState for custom value")
            return
        }
        
        for muscle in muscles {
            gameState.muscleState.setPoints(value, for: muscle.id)
        }
        gameState.saveMuscleState()
        textField.text = ""
        tableView.reloadSections([0], with: .fade)
        onMusclePointsChanged?()
        print("✓ Set all muscles to \(value)")
    }
}

extension StickFigureAppearanceViewController: UIGestureRecognizerDelegate {
    // Gesture recognizer delegate if needed
}
