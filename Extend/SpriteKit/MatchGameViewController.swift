import UIKit

// MARK: - Data Structures

struct MatchGameLevel: Codable {
    let id: Int
    let name: String
    let gridWidth: Int
    let gridHeight: Int
    let items: [MatchItem]
    let colors: [String?]  // Allow null for transparent background
    let gridShape: [String]
    let movesAllowed: Int
    let scoreTarget: Int
}

struct MatchItem: Codable {
    let id: String
    let emoji: String?
    let asset: String?
}

struct MatchGameConfig: Codable {
    let levels: [MatchGameLevel]
}

// MARK: - Power-Up Types

enum PieceType {
    case normal
    case verticalArrow
    case horizontalArrow
    case bomb
    case flame
    case rocket  // L-shape pattern: flies across grid clearing path
}

// MARK: - Game Piece

class GamePiece {
    let itemId: String
    let colorIndex: Int
    var row: Int
    var col: Int
    var type: PieceType = .normal
    
    init(itemId: String, colorIndex: Int, row: Int, col: Int, type: PieceType = .normal) {
        self.itemId = itemId
        self.colorIndex = colorIndex
        self.row = row
        self.col = col
        self.type = type
    }
    
    func matches(_ other: GamePiece) -> Bool {
        // Power-ups don't match regular pieces
        if self.type != .normal || other.type != .normal {
            return false
        }
        return self.itemId == other.itemId && self.colorIndex == other.colorIndex
    }
}

// MARK: - Match Game View Controller

class MatchGameViewController: UIViewController {
    
    // Delegate for dismissal
    var presentingController: UIViewController?
    var onDismissGame: (() -> Void)?  // Callback to notify SwiftUI to dismiss
    
    // UI Components
    private let containerView = UIView()
    private let headerView = UIView()
    private let gridContainer = UIView()
    private let gridStackView = UIStackView()
    private let exitButton = UIButton()
    private let levelLabel = UILabel()
    private let levelNameLabel = UILabel()  // NEW: Display level name
    private let levelSelectorButton = UIButton()  // NEW: Level selector dropdown
    private let scoreLabel = UILabel()
    private let movesLabel = UILabel()
    private let targetLabel = UILabel()
    private let highScoreLabel = UILabel()
    
    // Game State
    private var currentLevel: MatchGameLevel?
    private var lastMoveTime: Date = Date()  // Track last move time for idle detection
    private var idleTimer: Timer?  // Timer for idle hint pulsing
    private var hintingTile: (row: Int, col: Int)?  // Current tile being pulsed as hint
    private var gameConfig: MatchGameConfig?
    private var currentLevelId: Int = 1
    private var gameGrid: [[GamePiece?]] = []
    private var gridShapeMap: [[Bool]] = []
    private var score: Int = 0
    private var movesRemaining: Int = 0
    private var selectedPiece: (row: Int, col: Int)? = nil
    private var gridButtons: [[UIButton?]] = []
    private var isAnimating = false
    private var isAnimatingDrop = false  // Flag to prevent transform reset during drop animation
    private var lastSwappedPositions: ((row: Int, col: Int), (row: Int, col: Int))? = nil
    private var swappedButtons: (UIButton, UIButton)? = nil  // Store swapped buttons for transform reset
    private var currentSwapInvolvesAPowerup = false  // Track if current swap involves a powerup
    private var dragStartPiece: (row: Int, col: Int)? = nil
    private var dragTargetPiece: (row: Int, col: Int)? = nil
    private var unlockedLevels: [Int] = [1]  // NEW: Track unlocked levels
    private var movedPieces: Set<String> = []  // Track which pieces moved during gravity
    private var fallDistances: [String: Int] = [:]  // Track how far each piece fell (row distance)
    private var newPieces: Set<String> = []  // Track which pieces are NEW (from refill)
    private var levelCompletionTriggered: Bool = false  // Prevent multiple level completion triggers
    
    // MARK: - Game Logic
    private var gridAspectRatioConstraint: NSLayoutConstraint?
    private let darkBg = UIColor(hex: "#2C3E50") ?? .black
    private let lightBg = UIColor(hex: "#34495E") ?? .darkGray
    private let accentColor = UIColor(hex: "#E74C3C") ?? .red
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadGameConfig()
        
        // Load saved game state
        loadSavedState()
        
        startLevel(currentLevelId)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = darkBg
        
        // Container
        containerView.backgroundColor = darkBg
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Header View
        headerView.backgroundColor = lightBg
        containerView.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 130)
        ])
        
        // Exit Button
        exitButton.setTitle("✕", for: .normal)
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.addTarget(self, action: #selector(exitGame), for: .touchUpInside)
        headerView.addSubview(exitButton)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            exitButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            exitButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 15),
            exitButton.widthAnchor.constraint(equalToConstant: 40),
            exitButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Level Name Label (centered, above level selector)
        levelNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        levelNameLabel.textColor = .white
        levelNameLabel.text = "Level 1 - Fruit Challenge"
        levelNameLabel.textAlignment = .center
        headerView.addSubview(levelNameLabel)
        levelNameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            levelNameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            levelNameLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            levelNameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerView.leadingAnchor, constant: 60),
            levelNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -60)
        ])
        
        // Level Selector Button (dropdown)
        levelSelectorButton.setTitle("Level 1 ▼", for: .normal)
        levelSelectorButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        levelSelectorButton.setTitleColor(.white, for: .normal)
        levelSelectorButton.backgroundColor = UIColor(hex: "#E74C3C")?.withAlphaComponent(0.8) ?? .red.withAlphaComponent(0.8)
        levelSelectorButton.layer.cornerRadius = 6
        levelSelectorButton.addTarget(self, action: #selector(showLevelSelector), for: .touchUpInside)
        headerView.addSubview(levelSelectorButton)
        levelSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            levelSelectorButton.topAnchor.constraint(equalTo: levelNameLabel.bottomAnchor, constant: 8),
            levelSelectorButton.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            levelSelectorButton.widthAnchor.constraint(equalToConstant: 100),
            levelSelectorButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Keep the old levelLabel hidden for now (still in setup but not visible)
        levelLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        levelLabel.textColor = .white
        levelLabel.text = "Level 1"
        levelLabel.isHidden = true
        
        // Score Label
        scoreLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        scoreLabel.textColor = .lightGray
        scoreLabel.text = "Score: 0"
        headerView.addSubview(scoreLabel)
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: levelSelectorButton.bottomAnchor, constant: 5),
            scoreLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 15)
        ])
        
        // Moves Label
        movesLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        movesLabel.textColor = .lightGray
        movesLabel.text = "Moves: 0"
        headerView.addSubview(movesLabel)
        movesLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            movesLabel.topAnchor.constraint(equalTo: levelSelectorButton.bottomAnchor, constant: 5),
            movesLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15)
        ])
        
        // Target Label
        targetLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        targetLabel.textColor = .lightGray
        targetLabel.text = "Target: 1000"
        headerView.addSubview(targetLabel)
        targetLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            targetLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 3),
            targetLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 15)
        ])
        
        // Grid Container
        gridContainer.backgroundColor = darkBg
        containerView.addSubview(gridContainer)
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        // Create a layout guide for the area below the header
        let gridAreaGuide = UILayoutGuide()
        containerView.addLayoutGuide(gridAreaGuide)
        NSLayoutConstraint.activate([
            gridAreaGuide.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            gridAreaGuide.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            gridAreaGuide.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gridAreaGuide.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        NSLayoutConstraint.activate([
            gridContainer.centerXAnchor.constraint(equalTo: gridAreaGuide.centerXAnchor),
            gridContainer.centerYAnchor.constraint(equalTo: gridAreaGuide.centerYAnchor),
            gridContainer.topAnchor.constraint(greaterThanOrEqualTo: gridAreaGuide.topAnchor, constant: 5),
            gridContainer.bottomAnchor.constraint(lessThanOrEqualTo: gridAreaGuide.bottomAnchor, constant: -5),
            gridContainer.leadingAnchor.constraint(greaterThanOrEqualTo: gridAreaGuide.leadingAnchor, constant: 5),
            gridContainer.trailingAnchor.constraint(lessThanOrEqualTo: gridAreaGuide.trailingAnchor, constant: -5)
        ])
        // Aspect ratio constraint is set dynamically in renderGrid() based on level dimensions
    }
    
    private func loadGameConfig() {
        guard let url = Bundle.main.url(forResource: "matchgame", withExtension: "json") else {
            print("❌ Could not find matchgame.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            gameConfig = try JSONDecoder().decode(MatchGameConfig.self, from: data)
            //print("✅ Loaded matchgame.json with \(gameConfig?.levels.count ?? 0) levels")
        } catch {
            print("❌ Error loading matchgame.json: \(error)")
        }
    }
    
    // MARK: - Game Logic
    
    private func startLevel(_ levelId: Int) {
        print("🎮 [STARTLEVEL] Starting level \(levelId)")
        guard let config = gameConfig,
              let level = config.levels.first(where: { $0.id == levelId }) else {
            print("❌ Level \(levelId) not found")
            return
        }
        
        print("🎮 [STARTLEVEL] Level \(levelId) loaded: gridWidth=\(level.gridWidth), gridHeight=\(level.gridHeight), items=\(level.items.count)")
        
        currentLevel = level
        score = 0
        movesRemaining = level.movesAllowed
        selectedPiece = nil
        levelCompletionTriggered = false  // Reset flag for new level
        
        // ...existing code...
        gridShapeMap = Array(repeating: Array(repeating: false, count: level.gridWidth), count: level.gridHeight)
        
        // Parse grid shape strings into boolean grid
        for (rowIndex, rowString) in level.gridShape.enumerated() {
            if rowIndex < gridShapeMap.count {
                for (colIndex, char) in rowString.enumerated() {
                    if colIndex < gridShapeMap[rowIndex].count {
                        gridShapeMap[rowIndex][colIndex] = (char == "X")
                    }
                }
            }
        }
        
        // Initialize empty grid
        gameGrid = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        gridButtons = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        
        // Fill grid with random pieces
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] {
                    let randomItemIndex = Int.random(in: 0..<level.items.count)
                    let randomColorIndex = Int.random(in: 0..<level.colors.count)
                    gameGrid[row][col] = GamePiece(
                        itemId: level.items[randomItemIndex].id,
                        colorIndex: randomColorIndex,
                        row: row,
                        col: col
                    )
                }
            }
        }
        
        updateUI()
        renderGrid()
        
        // Reset idle hint timer
        lastMoveTime = Date()
        resetIdleHintTimer()
        
        // Check for initial matches on level load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForMatches()
        }
    }
    
    private func updateUI() {
        guard let level = currentLevel else { return }
        
        levelLabel.text = level.name
        levelNameLabel.text = level.name  // Update level name label
        scoreLabel.text = "Score: \(score)"
        movesLabel.text = "Moves: \(max(0, movesRemaining))"  // Never show negative moves
        targetLabel.text = "Target: \(level.scoreTarget)"
        
        // Check if target score is reached (only trigger once per level)
        if score >= level.scoreTarget && !levelCompletionTriggered {
            levelCompletionTriggered = true
            checkLevelCompletion()
        }
    }
    
    private func checkLevelCompletion() {
        guard let level = currentLevel, let config = gameConfig else { return }
        
        // Find next level
        let nextLevelId = level.id + 1
        if config.levels.contains(where: { $0.id == nextLevelId }) {
            // Level complete! Show animation and progress to next level
            print("🎉 LEVEL \(level.id) COMPLETE! Score: \(score) >= Target: \(level.scoreTarget)")
            
            // Unlock next level
            if !unlockedLevels.contains(nextLevelId) {
                unlockedLevels.append(nextLevelId)
                unlockedLevels.sort()
                print("🔓 Unlocked level \(nextLevelId)")
            }
            
            // Reset all button transforms before showing completion animation
            resetAllButtonTransforms()
            
            // Disable interactions while animating
            isAnimating = true
            
            // Show completion animation
            showLevelCompleteAnimation {
                // After animation, load next level
                self.currentLevelId = nextLevelId
                self.levelSelectorButton.setTitle("Level \(nextLevelId) ▼", for: .normal)
                self.score = 0
                self.saveGameState()  // Save the new level and unlocked status
                self.startLevel(nextLevelId)
                self.isAnimating = false
            }
        } else {
            // All levels complete!
            print("🎉 ALL LEVELS COMPLETE! Final Score: \(score)")
            
            // Reset all button transforms before showing completion animation
            resetAllButtonTransforms()
            
            showGameCompleteAnimation {
                // Return to map after all levels are complete
                self.exitGame()
            }
        }
    }
    
    private func resetAllButtonTransforms() {
        guard let level = currentLevel else { return }
        
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if let button = gridButtons[row][col] {
                    button.transform = .identity
                    button.alpha = 1.0
                }
            }
        }
    }
    
    private func showLevelCompleteAnimation(completion: @escaping () -> Void) {
        // Create overlay with "Level Complete!" text
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let label = UILabel()
        label.text = "LEVEL COMPLETE!"
        label.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        label.textColor = .yellow
        label.textAlignment = .center
        overlay.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        
        // Animate scale
        label.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            label.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseInOut, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.removeFromSuperview()
                completion()
            })
        })
    }
    
    private func showGameCompleteAnimation(completion: @escaping () -> Void) {
        // Create overlay with "Game Complete!" text
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let label = UILabel()
        label.text = "GAME COMPLETE!"
        label.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        label.textColor = .green
        label.textAlignment = .center
        overlay.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        
        // Animate scale
        label.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            label.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, options: .curveEaseInOut, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.removeFromSuperview()
                completion()
            })
        })
    }
    
    private func renderGrid() {
        guard let level = currentLevel else { return }
        
        print("🎨 [RENDERGRID] Rendering grid: \(level.gridWidth)x\(level.gridHeight)")
        
        // Update grid container aspect ratio to match level dimensions
        // This ensures tiles remain square for any grid size (e.g. 10x11, 10x15)
        if let existing = gridAspectRatioConstraint {
            existing.isActive = false
        }
        let gridSpacing: CGFloat = 2
        // For square tiles: containerW / containerH = (cols*tile + (cols-1)*sp) / (rows*tile + (rows-1)*sp)
        // We approximate with a reasonable tile size; the constraint will adapt.
        // Using the exact formula with tile size factored out:
        // ratio = (cols + (cols-1)*sp/tile) / (rows + (rows-1)*sp/tile)
        // For sp/tile ≈ 2/35 ≈ 0.057, this is very close to cols/rows
        let cols = CGFloat(level.gridWidth)
        let rows = CGFloat(level.gridHeight)
        let approxTile: CGFloat = 40
        let aspectRatio = (cols * approxTile + (cols - 1) * gridSpacing) / (rows * approxTile + (rows - 1) * gridSpacing)
        gridAspectRatioConstraint = gridContainer.widthAnchor.constraint(equalTo: gridContainer.heightAnchor, multiplier: aspectRatio)
        gridAspectRatioConstraint?.priority = UILayoutPriority(rawValue: 999)
        gridAspectRatioConstraint?.isActive = true
        
        // Clear existing grid completely
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        gridStackView.removeFromSuperview()
        
        // Remove all arranged subviews from the stack view
        gridStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Setup grid stack view - make it fill equally vertically
        gridStackView.axis = .vertical
        gridStackView.spacing = 2
        gridStackView.distribution = .fillEqually  // Each row gets equal height
        gridContainer.addSubview(gridStackView)
        gridStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Make grid fill container
        NSLayoutConstraint.activate([
            gridStackView.topAnchor.constraint(equalTo: gridContainer.topAnchor),
            gridStackView.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor),
            gridStackView.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor),
            gridStackView.bottomAnchor.constraint(equalTo: gridContainer.bottomAnchor)
        ])
        
        // Render rows
        for row in 0..<level.gridHeight {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 2
            rowStack.distribution = .fillEqually  // Each button gets equal width
            gridStackView.addArrangedSubview(rowStack)
            
            for col in 0..<level.gridWidth {
                let button = UIButton()
                button.tag = row * level.gridWidth + col
                button.layer.cornerRadius = 8
                button.clipsToBounds = true
                
                // Remove all internal padding so content fills the button edge-to-edge
                //button.contentEdgeInsets = .zero
                //button.imageEdgeInsets = .zero
                //button.titleEdgeInsets = .zero
                
                // Make buttons square by constraining them to a fixed aspect ratio
                // Since each row divides available width equally, we just need height = width
                button.translatesAutoresizingMaskIntoConstraints = false
                let aspectRatio = NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: button, attribute: .height, multiplier: 1.0, constant: 0)
                button.addConstraint(aspectRatio)
                aspectRatio.priority = UILayoutPriority(rawValue: 999)
                
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    // Handle optional colors - nil means transparent background
                    if let colorHex = level.colors[piece.colorIndex] {
                        button.backgroundColor = UIColor(hex: colorHex) ?? .gray
                    } else {
                        button.backgroundColor = .clear
                    }
                    
                    let itemIndex = level.items.firstIndex(where: { $0.id == piece.itemId }) ?? 0
                    let item = level.items[itemIndex]
                    
                    // Try to use asset image first, fall back to emoji
                    if let assetName = item.asset, !assetName.isEmpty {
                        // Use asset image - pin imageView to fill the button
                        let image = UIImage(named: assetName)
                        
                        button.setImage(image, for: .normal)
                        button.setTitle("", for: .normal)
                        button.imageView?.contentMode = .scaleAspectFit
                        button.imageView?.clipsToBounds = true
                        if let imageView = button.imageView {
                            imageView.translatesAutoresizingMaskIntoConstraints = false
                            NSLayoutConstraint.activate([
                                imageView.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
                                imageView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2),
                                imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
                                imageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2)
                            ])
                        }
                    } else {
                        // Fall back to emoji - scale font to nearly fill the tile
                        let itemEmoji = item.emoji ?? "?"
                        let emojiFontSize = max(16, min(40, 420 / CGFloat(max(level.gridWidth, level.gridHeight))))
                        button.setTitle(itemEmoji, for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: emojiFontSize)
                        button.titleLabel?.adjustsFontSizeToFitWidth = true
                        button.titleLabel?.minimumScaleFactor = 0.7
                    }
                    
                    button.addTarget(self, action: #selector(gridButtonTapped(_:)), for: .touchUpInside)
                    
                    // Add pan gesture for drag-to-swap
                    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
                    button.addGestureRecognizer(panGesture)
                    
                    gridButtons[row][col] = button
                } else {
                    button.backgroundColor = darkBg
                    button.isUserInteractionEnabled = false
                }
                
                rowStack.addArrangedSubview(button)
            }
        }
    }
    
    @objc private func gridButtonTapped(_ sender: UIButton) {
        guard let level = currentLevel, !isAnimating else { return }
        
        let index = sender.tag
        let row = index / level.gridWidth
        let col = index % level.gridWidth
        
        // Check if tapped piece is a powerup - if so, activate it
        if let piece = gameGrid[row][col], piece.type != .normal {
            // Powerup activation when tapped directly
            isAnimating = true
            movesRemaining -= 1  // Decrease moves when powerup is used
            
            var clearedTiles: Set<String> = []
            var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
            
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // NOTE: Don't check if out of moves here - let powerup activate first
            // Move check will happen after powerup animation completes
            
            switch piece.type {
            case .verticalArrow:
                // Collect all tiles in column
                for r in 0..<level.gridHeight {
                    if gridShapeMap[r][col] && gameGrid[r][col] != nil {
                        clearedTiles.insert("\(r),\(col)")
                        if let p = gameGrid[r][col], p.type != .normal && p.type != .verticalArrow {
                            cascadingPowerups.append((row: r, col: col, type: p.type))
                        }
                    }
                }
                // Show flames animation
                shootFlamesVertically(column: col, arrowRow: row, rows: 0..<level.gridHeight) {}
                
            case .horizontalArrow:
                // Collect all tiles in row
                for c in 0..<level.gridWidth {
                    if gridShapeMap[row][c] && gameGrid[row][c] != nil {
                        clearedTiles.insert("\(row),\(c)")
                        if let p = gameGrid[row][c], p.type != .normal && p.type != .horizontalArrow {
                            cascadingPowerups.append((row: row, col: c, type: p.type))
                        }
                    }
                }
                // Show flames animation
                shootFlamesHorizontally(row: row, columns: 0..<level.gridWidth) {}
                
            case .bomb:
                // Collect 3x3 area
                for dr in -1...1 {
                    for dc in -1...1 {
                        let nr = row + dr
                        let nc = col + dc
                        if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                           gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                            clearedTiles.insert("\(nr),\(nc)")
                            if let p = gameGrid[nr][nc], p.type != .normal && p.type != .bomb {
                                cascadingPowerups.append((row: nr, col: nc, type: p.type))
                            }
                        }
                    }
                }
                
            case .flame:
                // Flame clears all matching pieces - pick random adjacent tile
                let adjacentPositions = [
                    (row - 1, col),      // up
                    (row + 1, col),      // down
                    (row, col - 1),      // left
                    (row, col + 1)       // right
                ]
                
                var validAdjacentTiles: [(row: Int, col: Int, itemId: String, colorIndex: Int)] = []
                for (adjRow, adjCol) in adjacentPositions {
                    if adjRow >= 0 && adjRow < level.gridHeight &&
                       adjCol >= 0 && adjCol < level.gridWidth &&
                       gridShapeMap[adjRow][adjCol],
                       let adjacentPiece = gameGrid[adjRow][adjCol],
                       adjacentPiece.type == .normal {
                        validAdjacentTiles.append((row: adjRow, col: adjCol, itemId: adjacentPiece.itemId, colorIndex: adjacentPiece.colorIndex))
                    }
                }
                
                if let randomTile = validAdjacentTiles.randomElement() {
                    // Collect all matching pieces
                    clearedTiles.insert("\(row),\(col)")  // Include the flame itself
                    for r in 0..<level.gridHeight {
                        for c in 0..<level.gridWidth {
                            if gridShapeMap[r][c], let flamePiece = gameGrid[r][c],
                               flamePiece.type == .normal &&
                               flamePiece.itemId == randomTile.itemId &&
                               flamePiece.colorIndex == randomTile.colorIndex {
                                clearedTiles.insert("\(r),\(c)")
                                if flamePiece.type != .normal {
                                    cascadingPowerups.append((row: r, col: c, type: flamePiece.type))
                                }
                            }
                        }
                    }
                } else {
                    // No adjacent normal tiles - clear all normal pieces
                    clearedTiles.insert("\(row),\(col)")  // Include the flame itself
                    for r in 0..<level.gridHeight {
                        for c in 0..<level.gridWidth {
                            if gridShapeMap[r][c], let flamePiece = gameGrid[r][c],
                               flamePiece.type == .normal {
                                clearedTiles.insert("\(r),\(c)")
                                if flamePiece.type != .normal {
                                    cascadingPowerups.append((row: r, col: c, type: flamePiece.type))
                                }
                            }
                        }
                    }
                }
                
            case .rocket:
                // Rocket tapped directly: animate rocket path, handles its own clearing
                animateRocketPath(fromRow: row, fromCol: col) { [weak self] in
                    self?.isAnimating = false
                    if self?.movesRemaining ?? 0 <= 0 {
                        self?.levelFailed()
                    }
                }
                return  // animateRocketPath handles everything
                
            case .normal:
                isAnimating = false
                return
            }
            
            // For flame powerups tapped directly, use target lines animation
            if piece.type == .flame {
                self.shootFlamesAtTiles(fromRow: row, fromCol: col, targetTiles: clearedTiles) { [weak self] in
                    // Show border highlights
                    self?.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                        // Clear all collected tiles
                        for posString in clearedTiles {
                            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                            if parts.count == 2 {
                                self?.score += 1
                                self?.gameGrid[parts[0]][parts[1]] = nil
                            }
                        }
                        
                        self?.updateUI()
                        self?.updateGridDisplay()
                        
                        // Activate cascading powerups if any were captured
                        if !cascadingPowerups.isEmpty {
                            self?.activateCascadingPowerups(cascadingPowerups)
                        } else {
                            self?.applyGravity()
                        }
                    }
                }
            } else {
                // Regular border highlight for other powerups
                showPowerupBorderHighlight(clearedTiles) { [weak self] in
                    // Clear all collected tiles
                    for posString in clearedTiles {
                        let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                        if parts.count == 2 {
                            self?.score += 1
                            self?.gameGrid[parts[0]][parts[1]] = nil
                        }
                    }
                    
                    self?.updateUI()
                    self?.updateGridDisplay()
                    
                    // Activate cascading powerups if any were captured
                    if !cascadingPowerups.isEmpty {
                        self?.activateCascadingPowerups(cascadingPowerups)
                    } else {
                        // No cascading powerups, apply gravity immediately
                        self?.applyGravity()
                    }
                    self?.isAnimating = false
                    
                    // NOW check if out of moves after powerup animation completes
                    if self?.movesRemaining ?? 0 <= 0 {
                        self?.levelFailed()
                    }
                }
            }
            return
        }
        
        if let selected = selectedPiece {
            // Try to swap
            if areAdjacent(selected.row, selected.col, row, col) {
                swapPieces(selected.row, selected.col, row, col)
                selectedPiece = nil
            } else {
                // Select new piece
                selectedPiece = (row, col)
                updateGridDisplay()
            }
        } else {
            // Select first piece
            selectedPiece = (row, col)
            updateGridDisplay()
        }
    }
    
    private func areAdjacent(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) -> Bool {
        let rowDiff = abs(r1 - r2)
        let colDiff = abs(c1 - c2)
        return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1)
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let level = currentLevel, !isAnimating, let button = gesture.view as? UIButton else { return }
        
        let translation = gesture.translation(in: gridContainer)
        let index = button.tag
        let startRow = index / level.gridWidth
        let startCol = index % level.gridWidth
        
        switch gesture.state {
        case .began:
            dragStartPiece = (row: startRow, col: startCol)
            selectedPiece = (row: startRow, col: startCol)
            updateGridDisplay()
            
        case .changed:
            // Determine which piece we're dragging towards
            let distance = sqrt(translation.x * translation.x + translation.y * translation.y)
            
            if distance > 30 { // Minimum drag distance
                var targetRow = startRow
                var targetCol = startCol
                
                // Determine direction based on translation
                if abs(translation.x) > abs(translation.y) {
                    // Horizontal drag
                    if translation.x > 30 && startCol < level.gridWidth - 1 {
                        targetCol = startCol + 1
                    } else if translation.x < -30 && startCol > 0 {
                        targetCol = startCol - 1
                    }
                } else {
                    // Vertical drag
                    if translation.y > 30 && startRow < level.gridHeight - 1 {
                        targetRow = startRow + 1
                    } else if translation.y < -30 && startRow > 0 {
                        targetRow = startRow - 1
                    }
                }
                
                if gridShapeMap[targetRow][targetCol] {
                    dragTargetPiece = (row: targetRow, col: targetCol)
                    selectedPiece = (row: targetRow, col: targetCol)
                    updateGridDisplay()
                }
            }
            
        case .ended, .cancelled:
            if let startPiece = dragStartPiece, let targetPiece = dragTargetPiece {
                if areAdjacent(startPiece.row, startPiece.col, targetPiece.row, targetPiece.col) {
                    swapPieces(startPiece.row, startPiece.col, targetPiece.row, targetPiece.col)
                }
            }
            dragStartPiece = nil
            dragTargetPiece = nil
            selectedPiece = nil
            updateGridDisplay()
            
        default:
            break
        }
    }
    
    private func swapPieces(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) {
        isAnimating = true
        
        // Reset idle timer on move
        lastMoveTime = Date()
        resetIdleHintTimer()
        
        // Don't decrement moves yet - wait until we validate the swap creates a match or uses a powerup
        // Remember the swap for potential revert
        lastSwappedPositions = ((r1, c1), (r2, c2))
        
        guard let button1 = gridButtons[r1][c1],
              let button2 = gridButtons[r2][c2] else {
            isAnimating = false
            lastSwappedPositions = nil
            return
        }
        
        // Check if this is a powerup-to-powerup swap
        let piece1 = gameGrid[r1][c1]
        let piece2 = gameGrid[r2][c2]
        
        let bothArePowerups = piece1?.type != .normal && piece1?.type != nil &&
                              piece2?.type != .normal && piece2?.type != nil
        
        // Get initial positions
        let pos1 = button1.convert(CGPoint.zero, to: gridContainer)
        let pos2 = button2.convert(CGPoint.zero, to: gridContainer)
        
        // Calculate the delta between positions
        let deltaX = pos2.x - pos1.x
        let deltaY = pos2.y - pos1.y
        
        if bothArePowerups {
            // ALL powerup-to-powerup swaps: piece1 slides onto piece2, piece2 stays
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                button1.transform = CGAffineTransform(translationX: deltaX, y: deltaY)
                button1.layer.zPosition = 100
            }, completion: { [weak self] _ in
                button1.layer.zPosition = 0
                self?.swappedButtons = (button1, button2)
            })
        } else {
            // Normal swap: both buttons swap positions
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                button1.transform = CGAffineTransform(translationX: deltaX, y: deltaY)
                button2.transform = CGAffineTransform(translationX: -deltaX, y: -deltaY)
                button1.layer.zPosition = 100
            }, completion: { [weak self] _ in
                button1.layer.zPosition = 0
                self?.swappedButtons = (button1, button2)
            })
        }
        
        // Perform the actual swap in data after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            let piece1 = self.gameGrid[r1][c1]
            let piece2 = self.gameGrid[r2][c2]

            // Capture original types BEFORE the data swap for activatePowerUps
            let originalType1 = piece1?.type ?? .normal
            let originalType2 = piece2?.type ?? .normal

            let bothArePowerups = piece1?.type != .normal && piece1?.type != nil &&
                                  piece2?.type != .normal && piece2?.type != nil

            if bothArePowerups {
                // ALL powerup-to-powerup: piece1 moves on top of piece2, original space emptied
                self.gameGrid[r2][c2] = piece1
                self.gameGrid[r1][c1] = nil
                piece1?.row = r2
                piece1?.col = c2
            } else {
                // Normal swap: swap in data
                let temp = self.gameGrid[r1][c1]
                self.gameGrid[r1][c1] = self.gameGrid[r2][c2]
                self.gameGrid[r2][c2] = temp

                self.gameGrid[r1][c1]?.row = r1
                self.gameGrid[r1][c1]?.col = c1
                self.gameGrid[r2][c2]?.row = r2
                self.gameGrid[r2][c2]?.col = c2
            }

            // Check for power-up activation before checking matches
            let powerUpAtR1C1 = self.gameGrid[r1][c1]?.type != .normal
            let powerUpAtR2C2 = self.gameGrid[r2][c2]?.type != .normal

            // Track if this swap involves a powerup
            self.currentSwapInvolvesAPowerup = powerUpAtR1C1 || powerUpAtR2C2

            if powerUpAtR1C1 || powerUpAtR2C2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.activatePowerUps(r1, c1, r2, c2, type1: originalType1, type2: originalType2)
                }
            } else {
                // Check for matches after swap animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.checkForMatches()
                }
            }
        }
    }
    
    // MARK: - Power-Up Activation (Dispatcher)

    /// Main entry point for power-up activation after a swap.
    /// `type1` and `type2` are the ORIGINAL piece types before the data swap occurred.
    /// For powerup+powerup swaps: piece1 overlapped onto piece2 at (r2,c2), and (r1,c1) is nil.
    /// For normal swaps: pieces exchanged positions normally.
    private func activatePowerUps(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int, type1: PieceType, type2: PieceType) {
        guard currentLevel != nil else { return }

        let bothArePowerups = type1 != .normal && type2 != .normal

        if bothArePowerups {
            // Classify the powerup+powerup combo and dispatch to the appropriate handler.
            // The pieces overlapped at (r2, c2), and (r1, c1) is nil.
            switch (type1, type2) {
            // --- Two identical special types ---
            case (.bomb, .bomb):
                handleBombBombCombo(r1: r1, c1: c1, r2: r2, c2: c2)
            case (.flame, .flame):
                handleFlameFlameCombo(r1: r1, c1: c1, r2: r2, c2: c2)
            case (.rocket, .rocket):
                handleRocketRocketCombo(r1: r1, c1: c1, r2: r2, c2: c2)

            // --- Cross arrows (horizontal + vertical) ---
            case (.horizontalArrow, .verticalArrow), (.verticalArrow, .horizontalArrow):
                handleCrossArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2)

            // --- Bomb + arrow ---
            case (.bomb, .horizontalArrow), (.horizontalArrow, .bomb):
                handleBombArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2, isHorizontal: true)
            case (.bomb, .verticalArrow), (.verticalArrow, .bomb):
                handleBombArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2, isHorizontal: false)

            // --- Two same-direction arrows ---
            case (.horizontalArrow, .horizontalArrow):
                handleTwoHorizontalArrows(r1: r1, c1: c1, r2: r2, c2: c2)
            case (.verticalArrow, .verticalArrow):
                handleTwoVerticalArrows(r1: r1, c1: c1, r2: r2, c2: c2)

            // --- Flame + any other powerup ---
            case (.flame, _):
                handleFlamePowerupCombo(r1: r1, c1: c1, r2: r2, c2: c2, otherType: type2)
            case (_, .flame):
                handleFlamePowerupCombo(r1: r1, c1: c1, r2: r2, c2: c2, otherType: type1)

            // --- Rocket + any other powerup ---
            case (.rocket, _):
                handleRocketPowerupCombo(r1: r1, c1: c1, r2: r2, c2: c2, otherType: type2)
            case (_, .rocket):
                handleRocketPowerupCombo(r1: r1, c1: c1, r2: r2, c2: c2, otherType: type1)

            default:
                // Fallback: activate both individually at their positions
                handleIndividualPowerupActivation(r1: r1, c1: c1, r2: r2, c2: c2, type1: type1, type2: type2)
            }
        } else {
            // One normal + one powerup (standard swap positions)
            handleIndividualPowerupActivation(r1: r1, c1: c1, r2: r2, c2: c2, type1: type1, type2: type2)
        }
    }

    // MARK: - Finalize Helpers

    /// Eliminates the repeated pattern across all combo handlers:
    /// reset transforms -> updateGridDisplay -> (optional flame animation) -> showBorderHighlight -> clear tiles -> cascade or gravity.
    private func finalizePowerupCombo(
        clearedTiles: Set<String>,
        cascadingPowerups: [(row: Int, col: Int, type: PieceType)],
        decrementMoves: Bool = true,
        flameSource: (row: Int, col: Int)? = nil
    ) {
        // Reset swapped button transforms so buttons are in correct positions
        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }

        // Update display so buttons show correct content at correct positions
        updateGridDisplay()

        if decrementMoves {
            movesRemaining -= 1
        }

        if !clearedTiles.isEmpty {
            if let source = flameSource {
                // Flame powerup: shoot lines to targets first, then border highlight, then clear
                shootFlamesAtTiles(fromRow: source.row, fromCol: source.col, targetTiles: clearedTiles) { [weak self] in
                    self?.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                        self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
                    }
                }
            } else {
                // Non-flame powerups: border highlight then clear
                showPowerupBorderHighlight(clearedTiles) { [weak self] in
                    self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
                }
            }
        } else {
            // No tiles to clear, just apply gravity
            updateUI()
            applyGravity()
        }
    }

    /// Clears tiles from the grid, awards score, then activates cascading powerups or applies gravity.
    private func clearTilesAndCascade(_ clearedTiles: Set<String>, cascadingPowerups: [(row: Int, col: Int, type: PieceType)]) {
        for posString in clearedTiles {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                score += 1
                gameGrid[parts[0]][parts[1]] = nil
            }
        }

        updateUI()

        if !cascadingPowerups.isEmpty {
            activateCascadingPowerups(cascadingPowerups)
        } else {
            applyGravity()
        }
    }

    // MARK: - Combo Handlers

    /// Collects cascading powerups from a set of cleared tiles, excluding the source positions.
    private func collectCascadingPowerups(
        in clearedTiles: Set<String>,
        excludePositions: [(row: Int, col: Int)]
    ) -> [(row: Int, col: Int, type: PieceType)] {
        var cascading: [(row: Int, col: Int, type: PieceType)] = []
        let excludeSet = Set(excludePositions.map { "\($0.row),\($0.col)" })

        for posString in clearedTiles {
            if excludeSet.contains(posString) { continue }
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                if let piece = gameGrid[parts[0]][parts[1]], piece.type != .normal {
                    cascading.append((row: parts[0], col: parts[1], type: piece.type))
                }
            }
        }
        return cascading
    }

    /// Bomb + Bomb: 4x4 clear at midpoint between the two bombs.
    private func handleBombBombCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Calculate the midpoint between the two bombs
        let midRow = (r1 + r2) / 2
        let midCol = (c1 + c2) / 2

        // Clear a 4x4 grid centered on midpoint (2 in each direction)
        for dr in -2...1 {
            for dc in -2...1 {
                let nr = midRow + dr
                let nc = midCol + dc
                if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                   gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                    clearedTiles.insert("\(nr),\(nc)")
                }
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        print("🔍 [DEBUG] Two bombs merged! Clearing 4x4 grid around (\(midRow),\(midCol)). Found \(cascadingPowerups.count) cascading powerups")

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Flame + Flame: Clear the entire screen.
    private func handleFlameFlameCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Collect ALL tiles on the board
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] && gameGrid[row][col] != nil {
                    clearedTiles.insert("\(row),\(col)")
                }
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        print("🔍 [DEBUG] Two flames merged! Clearing entire screen. Found \(cascadingPowerups.count) cascading powerups")

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true,
            flameSource: (row: r2, col: c2)
        )
    }

    /// Cross arrows (horizontal + vertical): Clear 2 rows + 2 columns forming a cross pattern.
    /// Clears row at r1 AND row at r2, plus column at c1 AND column at c2.
    private func handleCrossArrowCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Clear both rows (r1 and r2)
        for col in 0..<level.gridWidth {
            if gridShapeMap[r1][col] && gameGrid[r1][col] != nil {
                clearedTiles.insert("\(r1),\(col)")
            }
            if gridShapeMap[r2][col] && gameGrid[r2][col] != nil {
                clearedTiles.insert("\(r2),\(col)")
            }
        }

        // Clear both columns (c1 and c2)
        for row in 0..<level.gridHeight {
            if gridShapeMap[row][c1] && gameGrid[row][c1] != nil {
                clearedTiles.insert("\(row),\(c1)")
            }
            if gridShapeMap[row][c2] && gameGrid[row][c2] != nil {
                clearedTiles.insert("\(row),\(c2)")
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        print("🔍 [DEBUG] Cross arrows! Clearing rows \(r1),\(r2) and cols \(c1),\(c2). Tiles: \(clearedTiles.count), cascading: \(cascadingPowerups.count)")

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Bomb + Arrow: Clear 3 full rows (if horizontal) or 3 full columns (if vertical) centered on the bomb location.
    private func handleBombArrowCombo(r1: Int, c1: Int, r2: Int, c2: Int, isHorizontal: Bool) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        if isHorizontal {
            // Clear 3 full rows centered on r2 (the overlap location)
            for dr in -1...1 {
                let targetRow = r2 + dr
                if targetRow >= 0 && targetRow < level.gridHeight {
                    for col in 0..<level.gridWidth {
                        if gridShapeMap[targetRow][col] && gameGrid[targetRow][col] != nil {
                            clearedTiles.insert("\(targetRow),\(col)")
                        }
                    }
                }
            }
        } else {
            // Clear 3 full columns centered on c2 (the overlap location)
            for dc in -1...1 {
                let targetCol = c2 + dc
                if targetCol >= 0 && targetCol < level.gridWidth {
                    for row in 0..<level.gridHeight {
                        if gridShapeMap[row][targetCol] && gameGrid[row][targetCol] != nil {
                            clearedTiles.insert("\(row),\(targetCol)")
                        }
                    }
                }
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        let direction = isHorizontal ? "horizontal" : "vertical"
        print("🔍 [DEBUG] Bomb + \(direction) arrow! Clearing 3 \(isHorizontal ? "rows" : "columns") centered on (\(r2),\(c2)). Tiles: \(clearedTiles.count), cascading: \(cascadingPowerups.count)")

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Two horizontal arrows: Clear both rows (r1 and r2).
    private func handleTwoHorizontalArrows(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Clear row r1 and row r2
        for col in 0..<level.gridWidth {
            if gridShapeMap[r1][col] && gameGrid[r1][col] != nil {
                clearedTiles.insert("\(r1),\(col)")
            }
            if gridShapeMap[r2][col] && gameGrid[r2][col] != nil {
                clearedTiles.insert("\(r2),\(col)")
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        print("🔍 [DEBUG] Two horizontal arrows! Clearing rows \(r1) and \(r2). Tiles: \(clearedTiles.count), cascading: \(cascadingPowerups.count)")

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Two vertical arrows: Clear both columns (c1 and c2).
    private func handleTwoVerticalArrows(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Clear column c1 and column c2
        for row in 0..<level.gridHeight {
            if gridShapeMap[row][c1] && gameGrid[row][c1] != nil {
                clearedTiles.insert("\(row),\(c1)")
            }
            if gridShapeMap[row][c2] && gameGrid[row][c2] != nil {
                clearedTiles.insert("\(row),\(c2)")
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        print("🔍 [DEBUG] Two vertical arrows! Clearing cols \(c1) and \(c2). Tiles: \(clearedTiles.count), cascading: \(cascadingPowerups.count)")

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Flame + another powerup type: Spawn 5-8 copies of the other powerup at random normal tiles,
    /// animate flames shooting to each, then activate all spawned powerups as cascading.
    private func handleFlamePowerupCombo(r1: Int, c1: Int, r2: Int, c2: Int, otherType: PieceType) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Reset transforms and update display first
        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }
        updateGridDisplay()
        movesRemaining -= 1

        // Find all normal tiles that can be converted
        var normalTilePositions: [(row: Int, col: Int)] = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col],
                   let piece = gameGrid[row][col],
                   piece.type == .normal,
                   !(row == r1 && col == c1),
                   !(row == r2 && col == c2) {
                    normalTilePositions.append((row: row, col: col))
                }
            }
        }

        // Pick 5-8 random positions
        let spawnCount = min(Int.random(in: 5...8), normalTilePositions.count)
        let shuffled = normalTilePositions.shuffled()
        let spawnPositions = Array(shuffled.prefix(spawnCount))

        print("🔍 [DEBUG] Flame + \(otherType) combo! Spawning \(spawnPositions.count) copies of \(otherType)")

        // Build target tile set for flame animation
        var targetTiles: Set<String> = []
        for pos in spawnPositions {
            targetTiles.insert("\(pos.row),\(pos.col)")
        }

        // Also clear the combo tile itself at r2,c2
        var clearedTiles: Set<String> = ["\(r2),\(c2)"]
        if gameGrid[r1][c1] != nil {
            clearedTiles.insert("\(r1),\(c1)")
        }

        // Animate powerup copies flying from the overlap point to each target
        shootPowerupCopiesToTiles(fromRow: r2, fromCol: c2, powerupType: otherType, targetTiles: targetTiles) { [weak self] in
            guard let self = self else { return }

            // Convert the random tiles to the other powerup type
            var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
            for pos in spawnPositions {
                if let piece = self.gameGrid[pos.row][pos.col] {
                    piece.type = otherType
                    cascadingPowerups.append((row: pos.row, col: pos.col, type: otherType))
                }
            }

            // Clear the source combo tiles
            for posString in clearedTiles {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                if parts.count == 2 {
                    self.score += 1
                    self.gameGrid[parts[0]][parts[1]] = nil
                }
            }

            self.updateGridDisplay()
            self.updateUI()

            // Activate all spawned powerups as cascading
            if !cascadingPowerups.isEmpty {
                self.activateCascadingPowerups(cascadingPowerups)
            } else {
                self.applyGravity()
            }
        }
    }

    /// Rocket + another powerup type: Spawn copies of the other powerup at random normal tiles,
    /// animate the rocket flying to each, then activate all spawned powerups as cascading.
    private func handleRocketPowerupCombo(r1: Int, c1: Int, r2: Int, c2: Int, otherType: PieceType) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Reset transforms and update display first
        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }
        updateGridDisplay()
        movesRemaining -= 1

        // Find all normal tiles that can be converted
        var normalTilePositions: [(row: Int, col: Int)] = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col],
                   let piece = gameGrid[row][col],
                   piece.type == .normal,
                   !(row == r1 && col == c1),
                   !(row == r2 && col == c2) {
                    normalTilePositions.append((row: row, col: col))
                }
            }
        }

        // Pick 5-8 random positions
        let spawnCount = min(Int.random(in: 5...8), normalTilePositions.count)
        let shuffled = normalTilePositions.shuffled()
        let spawnPositions = Array(shuffled.prefix(spawnCount))

        print("🔍 [DEBUG] Rocket + \(otherType) combo! Spawning \(spawnPositions.count) copies of \(otherType)")

        // Build target tile set for animation
        var targetTiles: Set<String> = []
        for pos in spawnPositions {
            targetTiles.insert("\(pos.row),\(pos.col)")
        }

        // Also clear the combo tile itself at r2,c2
        var clearedTiles: Set<String> = ["\(r2),\(c2)"]
        if gameGrid[r1][c1] != nil {
            clearedTiles.insert("\(r1),\(c1)")
        }

        // Animate powerup copies flying from the rocket to each target
        shootPowerupCopiesToTiles(fromRow: r2, fromCol: c2, powerupType: otherType, targetTiles: targetTiles) { [weak self] in
            guard let self = self else { return }

            // Convert the random tiles to the other powerup type
            var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
            for pos in spawnPositions {
                if let piece = self.gameGrid[pos.row][pos.col] {
                    piece.type = otherType
                    cascadingPowerups.append((row: pos.row, col: pos.col, type: otherType))
                }
            }

            // Clear the source combo tiles
            for posString in clearedTiles {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                if parts.count == 2 {
                    self.score += 1
                    self.gameGrid[parts[0]][parts[1]] = nil
                }
            }

            self.updateGridDisplay()
            self.updateUI()

            // Activate all spawned powerups as cascading
            if !cascadingPowerups.isEmpty {
                self.activateCascadingPowerups(cascadingPowerups)
            } else {
                self.applyGravity()
            }
        }
    }

    /// Rocket + Rocket: Two rockets fly independent paths, clearing everything they cross.
    private func handleRocketRocketCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Reset transforms and update display first
        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }
        updateGridDisplay()
        movesRemaining -= 1

        print("🔍 [DEBUG] Two rockets merged! Launching dual rocket paths from (\(r2),\(c2))")

        // Collect all tiles on the board (rockets clear everything they cross)
        var clearedTiles: Set<String> = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] && gameGrid[row][col] != nil {
                    clearedTiles.insert("\(row),\(col)")
                }
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        // Launch two independent rocket animations, then clear
        var completionCount = 0
        let totalAnimations = 2

        let onAnimationComplete: () -> Void = { [weak self] in
            completionCount += 1
            if completionCount >= totalAnimations {
                // Both rockets done, show border highlight and clear
                self?.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                    self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
                }
            }
        }

        animateRocketPath(fromRow: r2, fromCol: c2, completion: onAnimationComplete)
        //animateRocketPath(fromRow: r2, fromCol: c2, completion: onAnimationComplete)
    }

    // MARK: - Individual Power-Up Activation

    /// Handles one-normal + one-powerup swaps, or fallback for unrecognized powerup+powerup combos.
    /// After a normal swap: original piece from (r1,c1) with type1 is now at (r2,c2),
    /// and original piece from (r2,c2) with type2 is now at (r1,c1).
    /// For powerup+powerup fallback: piece is at (r2,c2), (r1,c1) is nil.
    private func handleIndividualPowerupActivation(r1: Int, c1: Int, r2: Int, c2: Int, type1: PieceType, type2: PieceType) {
        guard let level = currentLevel else { return }

        var clearedTiles: Set<String> = []
        var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
        var flameSource: (row: Int, col: Int)? = nil

        // type1 was originally at (r1,c1), now at (r2,c2) after swap
        // type2 was originally at (r2,c2), now at (r1,c1) after swap
        // For powerup+powerup fallback: type1 is at (r2,c2), (r1,c1) is nil

        // --- Activate type1 at its current position (r2, c2) ---
        if type1 == .verticalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][c2] && gameGrid[row][c2] != nil {
                    clearedTiles.insert("\(row),\(c2)")
                    // Don't add the arrow itself to cascading (it's at r2,c2)
                    if row != r2, let piece = gameGrid[row][c2], piece.type != .normal {
                        cascadingPowerups.append((row: row, col: c2, type: piece.type))
                    }
                }
            }
            // Fire-and-forget flame animation for visual effect
            shootFlamesVertically(column: c2, arrowRow: r2, rows: 0..<level.gridHeight) {}
        } else if type1 == .horizontalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            for col in 0..<level.gridWidth {
                if gridShapeMap[r2][col] && gameGrid[r2][col] != nil {
                    clearedTiles.insert("\(r2),\(col)")
                    // Don't add the arrow itself to cascading (it's at r2,c2)
                    if col != c2, let piece = gameGrid[r2][col], piece.type != .normal {
                        cascadingPowerups.append((row: r2, col: col, type: piece.type))
                    }
                }
            }
            // Fire-and-forget flame animation for visual effect
            shootFlamesHorizontally(row: r2, columns: 0..<level.gridWidth) {}
        } else if type1 == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r2 + dr
                    let nc = c2 + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        clearedTiles.insert("\(nr),\(nc)")
                        // Don't add the bomb itself to cascading (it's at r2,c2)
                        if !(nr == r2 && nc == c2), let piece = gameGrid[nr][nc], piece.type != .normal {
                            cascadingPowerups.append((row: nr, col: nc, type: piece.type))
                        }
                    }
                }
            }
        } else if type1 == .flame {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            // Add the flame powerup itself to be cleared
            clearedTiles.insert("\(r2),\(c2)")
            flameSource = (row: r2, col: c2)
            // Clear all pieces matching the color of the piece that was swapped with the flame
            // The swapped piece (type2) is now at (r1,c1)
            if let swappedPiece = gameGrid[r1][c1], swappedPiece.type == .normal {
                for row in 0..<level.gridHeight {
                    for col in 0..<level.gridWidth {
                        if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                            if piece.itemId == swappedPiece.itemId && piece.colorIndex == swappedPiece.colorIndex {
                                clearedTiles.insert("\(row),\(col)")
                                if piece.type != .normal {
                                    cascadingPowerups.append((row: row, col: col, type: piece.type))
                                }
                            }
                        }
                    }
                }
            }
        } else if type1 == .rocket {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            // Rocket handles its own clearing via animateRocketPath — bypass finalizePowerupCombo
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            updateGridDisplay()
            movesRemaining -= 1
            updateUI()
            animateRocketPath(fromRow: r2, fromCol: c2) { [weak self] in
                self?.isAnimating = false
                if self?.movesRemaining ?? 0 <= 0 {
                    self?.levelFailed()
                }
            }
            return
        }

        // --- Activate type2 at its current position (r1, c1) ---
        if type2 == .verticalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][c1] && gameGrid[row][c1] != nil {
                    clearedTiles.insert("\(row),\(c1)")
                    // Don't add the arrow itself to cascading (it's at r1,c1)
                    if row != r1, let piece = gameGrid[row][c1], piece.type != .normal {
                        cascadingPowerups.append((row: row, col: c1, type: piece.type))
                    }
                }
            }
            // Fire-and-forget flame animation for visual effect
            shootFlamesVertically(column: c1, arrowRow: r1, rows: 0..<level.gridHeight) {}
        } else if type2 == .horizontalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            for col in 0..<level.gridWidth {
                if gridShapeMap[r1][col] && gameGrid[r1][col] != nil {
                    clearedTiles.insert("\(r1),\(col)")
                    // Don't add the arrow itself to cascading (it's at r1,c1)
                    if col != c1, let piece = gameGrid[r1][col], piece.type != .normal {
                        cascadingPowerups.append((row: r1, col: col, type: piece.type))
                    }
                }
            }
            // Fire-and-forget flame animation for visual effect
            shootFlamesHorizontally(row: r1, columns: 0..<level.gridWidth) {}
        } else if type2 == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r1 + dr
                    let nc = c1 + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        clearedTiles.insert("\(nr),\(nc)")
                        // Don't add the bomb itself to cascading (it's at r1,c1)
                        if !(nr == r1 && nc == c1), let piece = gameGrid[nr][nc], piece.type != .normal {
                            cascadingPowerups.append((row: nr, col: nc, type: piece.type))
                        }
                    }
                }
            }
        } else if type2 == .flame {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            // Add the flame powerup itself to be cleared
            clearedTiles.insert("\(r1),\(c1)")
            flameSource = (row: r1, col: c1)
            // Clear all pieces matching the color of the piece that was swapped with the flame
            // The swapped piece (type1) is now at (r2,c2)
            if let swappedPiece = gameGrid[r2][c2], swappedPiece.type == .normal {
                for row in 0..<level.gridHeight {
                    for col in 0..<level.gridWidth {
                        if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                            if piece.itemId == swappedPiece.itemId && piece.colorIndex == swappedPiece.colorIndex {
                                clearedTiles.insert("\(row),\(col)")
                                if piece.type != .normal {
                                    cascadingPowerups.append((row: row, col: col, type: piece.type))
                                }
                            }
                        }
                    }
                }
            }
        } else if type2 == .rocket {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            // Rocket handles its own clearing via animateRocketPath — bypass finalizePowerupCombo
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            updateGridDisplay()
            movesRemaining -= 1
            updateUI()
            animateRocketPath(fromRow: r1, fromCol: c1) { [weak self] in
                self?.isAnimating = false
                if self?.movesRemaining ?? 0 <= 0 {
                    self?.levelFailed()
                }
            }
            return
        }

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: !clearedTiles.isEmpty,
            flameSource: flameSource
        )
    }
    
    private func activateCascadingPowerups(_ powerups: [(row: Int, col: Int, type: PieceType)]) {
        guard let level = currentLevel else { return }
        
        if powerups.isEmpty {
            // No more cascading powerups - apply gravity and check for new matches
            applyGravity()
            return
        }
        
        // Track all animations to know when they're complete
        var flameAnimationsInProgress = 0
        var flameAnimationsCompleted = 0
        
        // Count how many powerups will create animations
        for (_, _, type) in powerups {
            switch type {
            case .verticalArrow, .horizontalArrow, .bomb:
                flameAnimationsInProgress += 1
            case .flame:
                flameAnimationsInProgress += 1
            case .rocket:
                flameAnimationsInProgress += 1
            default:
                break
            }
        }
        
        // If no flame animations, just process and move on
        guard flameAnimationsInProgress > 0 else {
            updateGridDisplay()
            updateUI()
            applyGravityAfterCascade()
            return
        }
        
        // Update display before launching animations so buttons show correct state
        updateGridDisplay()
        updateUI()
        
        // Process each cascading powerup
        for (row, col, type) in powerups {
            switch type {
            case .verticalArrow:
                // Clear entire column and capture cascading powerups BEFORE animation
                var cascadingFromVertArrow: [(row: Int, col: Int, type: PieceType)] = []
                for r in 0..<level.gridHeight {
                    if gridShapeMap[r][col] && gameGrid[r][col] != nil {
                        // Capture any powerups in column BEFORE clearing (exclude the arrow itself)
                        if r != row, let p = gameGrid[r][col], p.type != .normal {
                            cascadingFromVertArrow.append((row: r, col: col, type: p.type))
                        }
                        score += 1
                        gameGrid[r][col] = nil
                    }
                }
                print("🔥 Cascading vertical arrow cleared column \(col). Found \(cascadingFromVertArrow.count) cascading powerups")
                
                // Shoot flames vertically - completion triggers next cascade or gravity
                let vertCascading = cascadingFromVertArrow
                shootFlamesVertically(column: col, arrowRow: row, rows: 0..<level.gridHeight) {
                    flameAnimationsCompleted += 1
                    if flameAnimationsCompleted == flameAnimationsInProgress {
                        if !vertCascading.isEmpty {
                            self.updateGridDisplay()
                            self.updateUI()
                            self.activateCascadingPowerups(vertCascading)
                        } else {
                            self.applyGravityAfterCascade()
                        }
                    }
                }
                
            case .horizontalArrow:
                // Clear entire row and capture cascading powerups BEFORE animation
                var cascadingFromHorizArrow: [(row: Int, col: Int, type: PieceType)] = []
                for c in 0..<level.gridWidth {
                    if gridShapeMap[row][c] && gameGrid[row][c] != nil {
                        // Capture any powerups in row BEFORE clearing (exclude the arrow itself)
                        if c != col, let p = gameGrid[row][c], p.type != .normal {
                            cascadingFromHorizArrow.append((row: row, col: c, type: p.type))
                        }
                        score += 1
                        gameGrid[row][c] = nil
                    }
                }
                print("🔥 Cascading horizontal arrow cleared row \(row). Found \(cascadingFromHorizArrow.count) cascading powerups")
                
                // Shoot flames horizontally - completion triggers next cascade or gravity
                let horizCascading = cascadingFromHorizArrow
                shootFlamesHorizontally(row: row, columns: 0..<level.gridWidth) {
                    flameAnimationsCompleted += 1
                    if flameAnimationsCompleted == flameAnimationsInProgress {
                        if !horizCascading.isEmpty {
                            self.updateGridDisplay()
                            self.updateUI()
                            self.activateCascadingPowerups(horizCascading)
                        } else {
                            self.applyGravityAfterCascade()
                        }
                    }
                }
                
            case .bomb:
                // Clear 3x3 area and capture cascading powerups
                var cascadingFromBomb: [(row: Int, col: Int, type: PieceType)] = []
                for dr in -1...1 {
                    for dc in -1...1 {
                        let nr = row + dr
                        let nc = col + dc
                        if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                           gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                            // Capture any powerups in the 3x3 area BEFORE clearing
                            if let p = gameGrid[nr][nc], p.type != .normal {
                                cascadingFromBomb.append((row: nr, col: nc, type: p.type))
                            }
                            score += 1
                            gameGrid[nr][nc] = nil
                        }
                    }
                }
                print("🔥 Cascading bomb cleared 3x3 area around (\(row), \(col)). Found \(cascadingFromBomb.count) cascading powerups")
                
                // For bombs, don't wait for animation - just decrement and check if complete
                flameAnimationsCompleted += 1
                if flameAnimationsCompleted == flameAnimationsInProgress {
                    // If this bomb found cascading powerups, process them
                    if !cascadingFromBomb.isEmpty {
                        self.updateGridDisplay()
                        self.updateUI()
                        self.activateCascadingPowerups(cascadingFromBomb)
                    } else {
                        self.applyGravityAfterCascade()
                    }
                }
                
            case .flame:
                // Flame powerup cascades: pick random adjacent tile and clear all matching pieces
                var cascadingFromFlame: [(row: Int, col: Int, type: PieceType)] = []
                var tilesToClear: Set<String> = []
                
                // Find all adjacent tiles
                let adjacentPositions = [
                    (row - 1, col),      // up
                    (row + 1, col),      // down
                    (row, col - 1),      // left
                    (row, col + 1)       // right
                ]
                
                var validAdjacentTiles: [(row: Int, col: Int, itemId: String, colorIndex: Int)] = []
                for (adjRow, adjCol) in adjacentPositions {
                    if adjRow >= 0 && adjRow < level.gridHeight &&
                       adjCol >= 0 && adjCol < level.gridWidth &&
                       gridShapeMap[adjRow][adjCol],
                       let piece = gameGrid[adjRow][adjCol],
                       piece.type == .normal {
                        validAdjacentTiles.append((row: adjRow, col: adjCol, itemId: piece.itemId, colorIndex: piece.colorIndex))
                    }
                }
                
                if let randomTile = validAdjacentTiles.randomElement() {
                    // Collect all matching pieces first
                    for r in 0..<level.gridHeight {
                        for c in 0..<level.gridWidth {
                            if gridShapeMap[r][c], let piece = gameGrid[r][c],
                               piece.type == .normal &&
                               piece.itemId == randomTile.itemId &&
                               piece.colorIndex == randomTile.colorIndex {
                                tilesToClear.insert("\(r),\(c)")
                                // Capture powerups found
                                if piece.type != .normal {
                                    cascadingFromFlame.append((row: r, col: c, type: piece.type))
                                }
                            }
                        }
                    }
                    
                    print("🔥 Cascading flame will clear \(tilesToClear.count) matching \(randomTile.itemId). Found \(cascadingFromFlame.count) cascading powerups")
                    
                    // Animate flames shooting to each tile, then clear them
                    self.shootFlamesAtTiles(fromRow: row, fromCol: col, targetTiles: tilesToClear) {
                        // Clear the tiles
                        for posString in tilesToClear {
                            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                            if parts.count == 2 {
                                self.score += 1
                                self.gameGrid[parts[0]][parts[1]] = nil
                            }
                        }
                        
                        // Continue with cascading
                        if !cascadingFromFlame.isEmpty {
                            self.updateGridDisplay()
                            self.updateUI()
                            self.activateCascadingPowerups(cascadingFromFlame)
                        } else {
                            self.applyGravityAfterCascade()
                        }
                    }
                    return
                } else {
                    // No adjacent normal tiles - clear all normal pieces on board
                    print("🔥 Cascading flame: no adjacent normal tiles, clearing all normal pieces")
                    for r in 0..<level.gridHeight {
                        for c in 0..<level.gridWidth {
                            if gridShapeMap[r][c], let piece = gameGrid[r][c],
                               piece.type == .normal {
                                // Capture powerups
                                if piece.type != .normal {
                                    cascadingFromFlame.append((row: r, col: c, type: piece.type))
                                }
                                score += 1
                                gameGrid[r][c] = nil
                            }
                        }
                    }
                    print("🔥 Cascading flame cleared all normal pieces on board. Found \(cascadingFromFlame.count) cascading powerups")
                }
                
                // For flames, decrement and check if complete
                flameAnimationsCompleted += 1
                if flameAnimationsCompleted == flameAnimationsInProgress {
                    if !cascadingFromFlame.isEmpty {
                        self.updateGridDisplay()
                        self.updateUI()
                        self.activateCascadingPowerups(cascadingFromFlame)
                    } else {
                        self.applyGravityAfterCascade()
                    }
                }
                
            case .rocket:
                // Rocket cascading: animate rocket path, completion tracks when done
                print("🚀 Cascading rocket at (\(row), \(col))")
                animateRocketPath(fromRow: row, fromCol: col) {
                    flameAnimationsCompleted += 1
                    if flameAnimationsCompleted == flameAnimationsInProgress {
                        self.applyGravityAfterCascade()
                    }
                }
                
            default:
                break
            }
        }
    }
    
    private func applyGravityAfterCascade() {
        guard let level = currentLevel else { return }
        
        // Clear tracking - we track ALL pieces that move (existing + new)
        movedPieces.removeAll()
        fallDistances.removeAll()
        newPieces.removeAll()
        
        // STEP 1: Apply gravity - track existing pieces that fall
        for col in 0..<level.gridWidth {
            // Collect all non-empty positions
            var pieces: [(row: Int, piece: GamePiece)] = []
            
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    pieces.append((row: row, piece: piece))
                    gameGrid[row][col] = nil  // Clear current position
                }
            }
            
            // Place pieces from bottom up, tracking how far each fell
            var targetRow = level.gridHeight - 1
            for (originalRow, piece) in pieces.reversed() {
                while targetRow >= 0 && (!gridShapeMap[targetRow][col] || gameGrid[targetRow][col] != nil) {
                    targetRow -= 1
                }
                
                if targetRow >= 0 {
                    let distance = originalRow - targetRow  // Distance fallen
                    gameGrid[targetRow][col] = piece
                    piece.row = targetRow
                    piece.col = col
                    
                    // Only track pieces that actually moved
                    if distance > 0 {
                        movedPieces.insert("\(targetRow),\(col)")
                        fallDistances["\(targetRow),\(col)"] = distance
                    }
                    
                    targetRow -= 1
                }
            }
        }
        
        // STEP 2: Refill empty spaces with NEW pieces - track with larger distance
        for col in 0..<level.gridWidth {
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col] && gameGrid[row][col] == nil {
                    let randomItemIndex = Int.random(in: 0..<level.items.count)
                    let randomColorIndex = Int.random(in: 0..<level.colors.count)
                    let newPiece = GamePiece(
                        itemId: level.items[randomItemIndex].id,
                        colorIndex: randomColorIndex,
                        row: row,
                        col: col,
                        type: .normal
                    )
                    gameGrid[row][col] = newPiece
                    
                    // NEW pieces get larger fall distance (from above grid)
                    // Only mark as moved if not already tracked as existing piece
                    if !movedPieces.contains("\(row),\(col)") {
                        movedPieces.insert("\(row),\(col)")
                        // Distance for new pieces: from top of screen (larger distance)
                        fallDistances["\(row),\(col)"] = row + 2
                        // Mark this as a NEW piece
                        newPieces.insert("\(row),\(col)")
                    }
                }
            }
        }
        
        // Update grid display to set correct content on buttons BEFORE animation
        updateGridDisplay()
        
        // Now set all buttons to their START positions before animation
        // This is critical: buttons must be visually where the piece currently is, not where it's going
        for col in 0..<level.gridWidth {
            for row in 0..<level.gridHeight {
                let key = "\(row),\(col)"
                guard movedPieces.contains(key), let button = gridButtons[row][col] else { continue }
                
                let distance = fallDistances[key] ?? 0
                let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
                
                // Set button to START position (before gravity)
                if newPieces.contains(key) {
                    // NEW pieces start OFF-SCREEN (above)
                    let fallDistance = cellHeight * CGFloat(distance)
                    button.transform = CGAffineTransform(translationX: 0, y: -fallDistance)
                    button.alpha = 0  // Start hidden
                } else {
                    // EXISTING pieces start DOWN from where they'll end (they fell down, so we move them up visually)
                    let fallDistance = cellHeight * CGFloat(distance)
                    button.transform = CGAffineTransform(translationX: 0, y: fallDistance)
                    button.alpha = 1.0
                }
            }
        }
        
        // Animate pieces falling, then check for matches when complete
        animatePiecesDrop() { [weak self] in
            self?.checkForMatches()
        }
    }
    
    private func shootFlamesVertically(column: Int, arrowRow: Int, rows: Range<Int>, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        guard column < gridButtons[0].count else {
            completion()
            return
        }
        
        // Calculate flame positions based on grid geometry
        let gridHeight = gridContainer.bounds.height
        let gridWidth = gridContainer.bounds.width
        let rowHeight = gridHeight / CGFloat(level.gridHeight)
        let colWidth = gridWidth / CGFloat(level.gridWidth)
        
        // Start Y position based on arrow's row
        let startY = CGFloat(arrowRow) * rowHeight + rowHeight / 2
        
        // End positions based on grid bounds
        let endYUp = CGFloat(rows.lowerBound) * rowHeight - 50
        let endYDown = CGFloat(rows.upperBound) * rowHeight + 50
        
        var animationsComplete = 0
        let totalAnimations = 10  // 5 up + 5 down
        let completeAnimation = {
            animationsComplete += 1
            if animationsComplete == totalAnimations {
                completion()
            }
        }
        
        // Create 5 flames shooting UP (distributed across column width)
        for i in 0..<5 {
            let flameLabelUp = UILabel()
            flameLabelUp.text = "🔥"
            flameLabelUp.font = UIFont.systemFont(ofSize: 40)
            flameLabelUp.sizeToFit()
            
            // Distribute flames across the column width
            let offsetX = (CGFloat(i) / 10.0) * 40 - 20
            let centerX = CGFloat(column) * colWidth + colWidth / 2
            flameLabelUp.frame = CGRect(x: centerX + offsetX - flameLabelUp.bounds.width/2,
                                         y: startY - flameLabelUp.bounds.height/2,
                                         width: flameLabelUp.bounds.width,
                                         height: flameLabelUp.bounds.height)
            
            gridContainer.addSubview(flameLabelUp)
            
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
                flameLabelUp.frame.origin.y = endYUp
                flameLabelUp.alpha = 0
            }, completion: { _ in
                flameLabelUp.removeFromSuperview()
                completeAnimation()
            })
        }
        
        // Create 5 flames shooting DOWN (distributed across column width)
        for i in 0..<5 {
            let flameLabelDown = UILabel()
            flameLabelDown.text = "🔥"
            flameLabelDown.font = UIFont.systemFont(ofSize: 40)
            flameLabelDown.sizeToFit()
            
            // Flip the transform for downward flames
            flameLabelDown.transform = CGAffineTransform(scaleX: 1, y: -1)
            
            // Distribute flames across the column width
            let offsetX = (CGFloat(i) / 10.0) * 40 - 20
            let centerX = CGFloat(column) * colWidth + colWidth / 2
            flameLabelDown.frame = CGRect(x: centerX + offsetX - flameLabelDown.bounds.width/2,
                                           y: startY - flameLabelDown.bounds.height/2,
                                           width: flameLabelDown.bounds.width,
                                           height: flameLabelDown.bounds.height)
            
            gridContainer.addSubview(flameLabelDown)
            
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
                flameLabelDown.frame.origin.y = endYDown
                flameLabelDown.alpha = 0
            }, completion: { _ in
                flameLabelDown.removeFromSuperview()
                completeAnimation()
            })
        }
    }
    
    private func shootFlamesHorizontally(row: Int, columns: Range<Int>, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        guard row < gridButtons.count else {
            completion()
            return
        }
        guard !gridButtons[row].isEmpty else {
            completion()
            return
        }
        
        // Calculate flame positions based on grid geometry
        let gridHeight = gridContainer.bounds.height
        let gridWidth = gridContainer.bounds.width
        let rowHeight = gridHeight / CGFloat(level.gridHeight)
        let colWidth = gridWidth / CGFloat(level.gridWidth)
        
        // Start X position based on middle column
        let startX = CGFloat(columns.lowerBound + columns.upperBound) / 2 * colWidth + colWidth / 2
        
        // End positions based on grid bounds - extend 50 pixels beyond edges like vertical flames
        let endXLeft = CGFloat(columns.lowerBound) * colWidth - 50
        let endXRight = CGFloat(columns.upperBound) * colWidth + 50
        
        // Center Y based on row
        let centerY = CGFloat(row) * rowHeight + rowHeight / 2
        
        print("🔍 [DEBUG] shootFlamesHorizontally called: row=\(row)")
        print("🔍 [DEBUG] Grid geometry: gridWidth=\(gridWidth), colWidth=\(colWidth)")
        print("🔍 [DEBUG] Flame positions: startX=\(startX), endXLeft=\(endXLeft), endXRight=\(endXRight)")
        
        var animationsComplete = 0
        let totalAnimations = 10  // 5 left + 5 right
        let completeAnimation = {
            animationsComplete += 1
            if animationsComplete == totalAnimations {
                completion()
            }
        }
        
        // Create 5 flames shooting LEFT (distributed across row height)
        for i in 0..<5 {
            let flameLabelLeft = UILabel()
            flameLabelLeft.text = "🔥"
            flameLabelLeft.font = UIFont.systemFont(ofSize: 40)
            flameLabelLeft.sizeToFit()
            
            // Rotate 90 degrees counterclockwise (pointing left)
            flameLabelLeft.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            
            // Distribute flames across the row height
            let offsetY = (CGFloat(i) / 10.0) * 40 - 20
            flameLabelLeft.frame = CGRect(x: startX - flameLabelLeft.bounds.width/2,
                                          y: centerY + offsetY - flameLabelLeft.bounds.height/2,
                                          width: flameLabelLeft.bounds.width,
                                          height: flameLabelLeft.bounds.height)
            
            gridContainer.addSubview(flameLabelLeft)
            
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
                flameLabelLeft.frame.origin.x = endXLeft
                flameLabelLeft.alpha = 0
            }, completion: { _ in
                flameLabelLeft.removeFromSuperview()
                completeAnimation()
            })
        }
        
        // Create 5 flames shooting RIGHT (distributed across row height)
        for i in 0..<5 {
            let flameLabelRight = UILabel()
            flameLabelRight.text = "🔥"
            flameLabelRight.font = UIFont.systemFont(ofSize: 40)
            flameLabelRight.sizeToFit()
            
            // Rotate 90 degrees clockwise (pointing right)
            flameLabelRight.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
            
            // Distribute flames across the row height
            let offsetY = (CGFloat(i) / 10.0) * 40 - 20
            flameLabelRight.frame = CGRect(x: startX - flameLabelRight.bounds.width/2,
                                           y: centerY + offsetY - flameLabelRight.bounds.height/2,
                                           width: flameLabelRight.bounds.width,
                                           height: flameLabelRight.bounds.height)
            
            gridContainer.addSubview(flameLabelRight)
            
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
                flameLabelRight.frame.origin.x = endXRight
                flameLabelRight.alpha = 0
            }, completion: { _ in
                flameLabelRight.removeFromSuperview()
                completeAnimation()
            })
        }
    }
    
    private func shootFlamesAtTiles(fromRow: Int, fromCol: Int, targetTiles: Set<String>, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        
        // Calculate grid geometry
        let gridHeight = gridContainer.bounds.height
        let gridWidth = gridContainer.bounds.width
        let rowHeight = gridHeight / CGFloat(level.gridHeight)
        let colWidth = gridWidth / CGFloat(level.gridWidth)
        
        // Starting position (flame powerup location)
        let startX = CGFloat(fromCol) * colWidth + colWidth / 2
        let startY = CGFloat(fromRow) * rowHeight + rowHeight / 2
        
        // Parse target tile positions
        var targetPositions: [(x: CGFloat, y: CGFloat)] = []
        for posString in targetTiles {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                let tRow = parts[0]
                let tCol = parts[1]
                let targetX = CGFloat(tCol) * colWidth + colWidth / 2
                let targetY = CGFloat(tRow) * rowHeight + rowHeight / 2
                targetPositions.append((x: targetX, y: targetY))
            }
        }
        
        guard !targetPositions.isEmpty else {
            completion()
            return
        }
        
        var flamesComplete = 0
        let completeFlame = {
            flamesComplete += 1
            if flamesComplete == targetPositions.count {
                completion()
            }
        }
        
        // Shoot a flame line at each target tile
        for (targetX, targetY) in targetPositions {
            let flameLabel = UILabel()
            flameLabel.text = "🔥"
            flameLabel.font = UIFont.systemFont(ofSize: 24)
            flameLabel.sizeToFit()
            flameLabel.frame = CGRect(x: startX - flameLabel.bounds.width/2,
                                      y: startY - flameLabel.bounds.height/2,
                                      width: flameLabel.bounds.width,
                                      height: flameLabel.bounds.height)
            
            gridContainer.addSubview(flameLabel)
            
            // Animate flame moving toward target
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveLinear, animations: {
                flameLabel.frame.origin.x = targetX - flameLabel.bounds.width/2
                flameLabel.frame.origin.y = targetY - flameLabel.bounds.height/2
                flameLabel.alpha = 0.5
            }, completion: { _ in
                flameLabel.removeFromSuperview()
                completeFlame()
            })
        }
    }
    
    /// Shoots copies of a powerup emoji from a source position to target tile positions.
    /// Used for flame+powerup and rocket+powerup combos to show powerup copies flying to targets.
    private func shootPowerupCopiesToTiles(fromRow: Int, fromCol: Int, powerupType: PieceType, targetTiles: Set<String>, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        
        // Determine the emoji for this powerup type
        let emoji: String
        switch powerupType {
        case .verticalArrow: emoji = "↕️"
        case .horizontalArrow: emoji = "↔️"
        case .bomb: emoji = "💣"
        case .flame: emoji = "🔥"
        case .rocket: emoji = "🌟"
        case .normal: emoji = "❓"
        }
        
        // Calculate grid geometry
        let gridHeight = gridContainer.bounds.height
        let gridWidth = gridContainer.bounds.width
        let rowHeight = gridHeight / CGFloat(level.gridHeight)
        let colWidth = gridWidth / CGFloat(level.gridWidth)
        
        // Starting position
        let startX = CGFloat(fromCol) * colWidth + colWidth / 2
        let startY = CGFloat(fromRow) * rowHeight + rowHeight / 2
        
        // Parse target tile positions
        var targetPositions: [(x: CGFloat, y: CGFloat)] = []
        for posString in targetTiles {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                let tRow = parts[0]
                let tCol = parts[1]
                let targetX = CGFloat(tCol) * colWidth + colWidth / 2
                let targetY = CGFloat(tRow) * rowHeight + rowHeight / 2
                targetPositions.append((x: targetX, y: targetY))
            }
        }
        
        guard !targetPositions.isEmpty else {
            completion()
            return
        }
        
        var copiesComplete = 0
        let completeCopy = {
            copiesComplete += 1
            if copiesComplete == targetPositions.count {
                completion()
            }
        }
        
        // Shoot a copy of the powerup emoji at each target tile
        for (targetX, targetY) in targetPositions {
            let copyLabel = UILabel()
            copyLabel.text = emoji
            copyLabel.font = UIFont.systemFont(ofSize: 28)
            copyLabel.sizeToFit()
            copyLabel.frame = CGRect(x: startX - copyLabel.bounds.width/2,
                                      y: startY - copyLabel.bounds.height/2,
                                      width: copyLabel.bounds.width,
                                      height: copyLabel.bounds.height)
            
            gridContainer.addSubview(copyLabel)
            
            // Animate copy moving toward target with a slight arc
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
                copyLabel.frame.origin.x = targetX - copyLabel.bounds.width/2
                copyLabel.frame.origin.y = targetY - copyLabel.bounds.height/2
            }, completion: { _ in
                // Brief flash at landing position
                UIView.animate(withDuration: 0.1, animations: {
                    copyLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                    copyLabel.alpha = 0.7
                }, completion: { _ in
                    copyLabel.removeFromSuperview()
                    completeCopy()
                })
            })
        }
    }
    
    /// Animates a rocket flying a looping path across the grid, clearing all tiles it crosses.
    /// The rocket visits 8-12 random waypoints, highlights crossed tiles with yellow borders, then clears them.
    private func animateRocketPath(fromRow: Int, fromCol: Int, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        
        // Calculate grid geometry
        let gridHeight = gridContainer.bounds.height
        let gridWidth = gridContainer.bounds.width
        let rowHeight = gridHeight / CGFloat(level.gridHeight)
        let colWidth = gridWidth / CGFloat(level.gridWidth)
        
        // Starting position (rocket location)
        let startX = CGFloat(fromCol) * colWidth + colWidth / 2
        let startY = CGFloat(fromRow) * rowHeight + rowHeight / 2
        
        // Generate 8-12 random waypoints across the grid
        let waypointCount = Int.random(in: 1...3)
        var waypoints: [CGPoint] = [CGPoint(x: startX, y: startY)]
        
        for _ in 0..<waypointCount {
            let randCol = Int.random(in: 0..<level.gridWidth)
            let randRow = Int.random(in: 0..<level.gridHeight)
            let wpX = CGFloat(randCol) * colWidth + colWidth / 2
            let wpY = CGFloat(randRow) * rowHeight + rowHeight / 2
            waypoints.append(CGPoint(x: wpX, y: wpY))
        }
        
        // End point: fly off the top-right of the grid
        waypoints.append(CGPoint(x: gridWidth + 50, y: -50))
        
        // Determine which grid cells the path crosses by sampling points along each segment
        var crossedTileSet: Set<String> = []
        
        for i in 0..<(waypoints.count - 1) {
            let from = waypoints[i]
            let to = waypoints[i + 1]
            let distance = hypot(to.x - from.x, to.y - from.y)
            let steps = max(Int(distance / 4), 5) // sample every ~4 points
            
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let sampleX = from.x + (to.x - from.x) * t
                let sampleY = from.y + (to.y - from.y) * t
                
                let col = Int(sampleX / colWidth)
                let row = Int(sampleY / rowHeight)
                
                if row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth &&
                   gridShapeMap[row][col] && gameGrid[row][col] != nil {
                    crossedTileSet.insert("\(row),\(col)")
                }
            }
        }
        
        // Also include the starting tile
        if gridShapeMap[fromRow][fromCol] && gameGrid[fromRow][fromCol] != nil {
            crossedTileSet.insert("\(fromRow),\(fromCol)")
        }
        
        // Collect cascading powerups from crossed tiles (exclude the rocket itself)
        var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
        for posString in crossedTileSet {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                let r = parts[0], c = parts[1]
                if !(r == fromRow && c == fromCol) {
                    if let piece = gameGrid[r][c], piece.type != .normal {
                        cascadingPowerups.append((row: r, col: c, type: piece.type))
                    }
                }
            }
        }
        
        print("🚀 [DEBUG] Rocket path from (\(fromRow),\(fromCol)) crossing \(crossedTileSet.count) tiles, \(cascadingPowerups.count) cascading powerups")
        
        // Build the bezier path through all waypoints with curves
        let path = UIBezierPath()
        path.move(to: waypoints[0])
        
        for i in 1..<waypoints.count {
            let prev = waypoints[i - 1]
            let curr = waypoints[i]
            // Add a curve with control points offset perpendicular to the line
            let midX = (prev.x + curr.x) / 2
            let midY = (prev.y + curr.y) / 2
            let dx = curr.x - prev.x
            let dy = curr.y - prev.y
            // Alternate curve direction for a looping effect
            let curveOffset: CGFloat = (i % 2 == 0) ? 30 : -30
            let controlX = midX + dy * curveOffset / max(hypot(dx, dy), 1)
            let controlY = midY - dx * curveOffset / max(hypot(dx, dy), 1)
            path.addQuadCurve(to: curr, controlPoint: CGPoint(x: controlX, y: controlY))
        }
        
        // Create the rocket emoji label
        let rocketLabel = UILabel()
        rocketLabel.text = "🌟"
        rocketLabel.font = UIFont.systemFont(ofSize: 28)
        rocketLabel.sizeToFit()
        rocketLabel.frame = CGRect(
            x: startX - rocketLabel.bounds.width / 2,
            y: startY - rocketLabel.bounds.height / 2,
            width: rocketLabel.bounds.width,
            height: rocketLabel.bounds.height
        )
        gridContainer.addSubview(rocketLabel)
        
        // Use CAKeyframeAnimation to animate along the path
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.path = path.cgPath
        animation.duration = Double(waypoints.count) * 0.12 // ~0.12s per segment
        animation.rotationMode = .rotateAuto
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Track animation completion
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            rocketLabel.removeFromSuperview()
            
            guard let self = self else {
                completion()
                return
            }
            
            // Show yellow borders on crossed tiles, then clear
            self.showPowerupBorderHighlight(crossedTileSet) { [weak self] in
                guard let self = self else {
                    completion()
                    return
                }
                
                // Clear all crossed tiles
                for posString in crossedTileSet {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self.score += 1
                        self.gameGrid[parts[0]][parts[1]] = nil
                    }
                }
                
                self.updateGridDisplay()
                self.updateUI()
                
                // Activate cascading powerups or apply gravity
                if !cascadingPowerups.isEmpty {
                    self.activateCascadingPowerups(cascadingPowerups)
                } else {
                    self.applyGravity()
                }
                
                completion()
            }
        }
        
        // Progressively highlight tiles as the rocket passes them
        // Use a timer that samples the rocket's position during animation
        let animationDuration = Double(waypoints.count) * 0.12
        let highlightInterval = 0.05
        var highlightedTiles: Set<String> = []
        var elapsed: Double = 0
        
        let displayLink = Timer.scheduledTimer(withTimeInterval: highlightInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            elapsed += highlightInterval
            if elapsed >= animationDuration {
                timer.invalidate()
                return
            }
            
            // Sample position along the path at the current time fraction
            let fraction = CGFloat(elapsed / animationDuration)
            let totalLength = self.approximatePathLength(waypoints: waypoints)
            let targetLength = totalLength * fraction
            var accumulated: CGFloat = 0
            var samplePoint = waypoints[0]
            
            for i in 0..<(waypoints.count - 1) {
                let segLen = hypot(waypoints[i + 1].x - waypoints[i].x, waypoints[i + 1].y - waypoints[i].y)
                if accumulated + segLen >= targetLength {
                    let segFraction = (targetLength - accumulated) / max(segLen, 1)
                    samplePoint = CGPoint(
                        x: waypoints[i].x + (waypoints[i + 1].x - waypoints[i].x) * segFraction,
                        y: waypoints[i].y + (waypoints[i + 1].y - waypoints[i].y) * segFraction
                    )
                    break
                }
                accumulated += segLen
            }
            
            let col = Int(samplePoint.x / colWidth)
            let row = Int(samplePoint.y / rowHeight)
            let key = "\(row),\(col)"
            
            if row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth &&
               crossedTileSet.contains(key) && !highlightedTiles.contains(key) {
                highlightedTiles.insert(key)
                // Show yellow border on this tile
                if let button = self.gridButtons[row][col] {
                    button.layer.borderColor = UIColor.yellow.cgColor
                    button.layer.borderWidth = 3
                }
            }
        }
        // Keep timer reference alive via the animation duration
        _ = displayLink
        
        rocketLabel.layer.add(animation, forKey: "rocketPath")
        CATransaction.commit()
    }
    
    /// Approximates total length of a polyline through waypoints.
    private func approximatePathLength(waypoints: [CGPoint]) -> CGFloat {
        var total: CGFloat = 0
        for i in 0..<(waypoints.count - 1) {
            total += hypot(waypoints[i + 1].x - waypoints[i].x, waypoints[i + 1].y - waypoints[i].y)
        }
        return total
    }
    
    private func checkForMatches() {
        guard let level = currentLevel else { return }
        
        // First, check if there are any valid moves available
        if !hasValidMoves() {
            print("🔄 No valid moves available - triggering shuffle")
            shuffleGrid()
            return
        }
        
        // Check if a power-up was involved in the swap - if so, activate it immediately
        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
            if let piece = gameGrid[r1][c1], piece.type != .normal {
                print("🎮 Swapped power-up detected at (\(r1),\(c1)): \(piece.type)")
                // Power-up was swapped - activate it
                lastSwappedPositions = nil
                isAnimating = true
                // Don't decrement here - activatePowerUps() handles it
                
                var clearedTiles: Set<String> = []
                var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
                
                switch piece.type {
                case .verticalArrow:
                    // Collect all tiles in column
                    for r in 0..<level.gridHeight {
                        if gridShapeMap[r][c1] && gameGrid[r][c1] != nil {
                            clearedTiles.insert("\(r),\(c1)")
                            if let p = gameGrid[r][c1], p.type != .normal && p.type != .verticalArrow {
                                cascadingPowerups.append((row: r, col: c1, type: p.type))
                            }
                        }
                    }
                    
                case .horizontalArrow:
                    // Collect all tiles in row
                    for c in 0..<level.gridWidth {
                        if gridShapeMap[r1][c] && gameGrid[r1][c] != nil {
                            clearedTiles.insert("\(r1),\(c)")
                            if let p = gameGrid[r1][c], p.type != .normal && p.type != .horizontalArrow {
                                cascadingPowerups.append((row: r1, col: c, type: p.type))
                            }
                        }
                    }
                    
                case .bomb:
                    // Collect 3x3 area
                    for r in max(0, r1-1)...min(level.gridHeight-1, r1+1) {
                        for c in max(0, c1-1)...min(level.gridWidth-1, c1+1) {
                            if gridShapeMap[r][c] && gameGrid[r][c] != nil {
                                clearedTiles.insert("\(r),\(c)")
                                if let p = gameGrid[r][c], p.type != .normal && p.type != .bomb {
                                    cascadingPowerups.append((row: r, col: c, type: p.type))
                                }
                            }
                        }
                    }
                    
                case .rocket:
                    // Rocket activated via swap: animate path
                    animateRocketPath(fromRow: r1, fromCol: c1) { [weak self] in
                        self?.isAnimating = false
                    }
                    return
                    
                case .flame, .normal:
                    break
                }
                
                if !clearedTiles.isEmpty {
                    // Show animation with borders, then clear
                    animateMatchedPieces(clearedTiles) { [weak self] in
                        for posString in clearedTiles {
                            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                            if parts.count == 2 {
                                self?.gameGrid[parts[0]][parts[1]] = nil
                            }
                        }
                        
                        self?.updateUI()
                        self?.updateGridDisplay()
                        
                        if !cascadingPowerups.isEmpty {
                            self?.activateCascadingPowerups(cascadingPowerups)
                        } else {
                            self?.applyGravity()
                        }
                    }
                }
                
                return
            } else if let piece = gameGrid[r2][c2], piece.type != .normal {
                print("🎮 Swapped power-up detected at (\(r2),\(c2)): \(piece.type)")
                // Power-up was swapped - activate it
                lastSwappedPositions = nil
                isAnimating = true
                // Don't decrement here - activatePowerUps() handles it
                
                var clearedTiles: Set<String> = []
                var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
                
                switch piece.type {
                case .verticalArrow:
                    // Collect all tiles in column
                    for r in 0..<level.gridHeight {
                        if gridShapeMap[r][c2] && gameGrid[r][c2] != nil {
                            clearedTiles.insert("\(r),\(c2)")
                            if let p = gameGrid[r][c2], p.type != .normal && p.type != .verticalArrow {
                                cascadingPowerups.append((row: r, col: c2, type: p.type))
                            }
                        }
                    }
                    
                case .horizontalArrow:
                    // Collect all tiles in row
                    for c in 0..<level.gridWidth {
                        if gridShapeMap[r2][c] && gameGrid[r2][c] != nil {
                            clearedTiles.insert("\(r2),\(c)")
                            if let p = gameGrid[r2][c], p.type != .normal && p.type != .horizontalArrow {
                                cascadingPowerups.append((row: r2, col: c, type: p.type))
                            }
                        }
                    }
                    
                case .bomb:
                    // Collect 3x3 area
                    for r in max(0, r2-1)...min(level.gridHeight-1, r2+1) {
                        for c in max(0, c2-1)...min(level.gridWidth-1, c2+1) {
                            if gridShapeMap[r][c] && gameGrid[r][c] != nil {
                                clearedTiles.insert("\(r),\(c)")
                                if let p = gameGrid[r][c], p.type != .normal && p.type != .bomb {
                                    cascadingPowerups.append((row: r, col: c, type: p.type))
                                }
                            }
                        }
                    }
                    
                case .rocket:
                    // Rocket activated via match-created powerup in swap
                    animateRocketPath(fromRow: r2, fromCol: c2) { [weak self] in
                        self?.isAnimating = false
                    }
                    return
                    
                case .flame, .normal:
                    break
                }
                
                if !clearedTiles.isEmpty {
                    // Show animation with borders, then clear
                    animateMatchedPieces(clearedTiles) { [weak self] in
                        for posString in clearedTiles {
                            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                            if parts.count == 2 {
                                self?.gameGrid[parts[0]][parts[1]] = nil
                            }
                        }
                        
                        self?.updateUI()
                        self?.updateGridDisplay()
                        
                        if !cascadingPowerups.isEmpty {
                            self?.activateCascadingPowerups(cascadingPowerups)
                        } else {
                            self?.applyGravity()
                        }
                    }
                }
                
                return
            }
        }
        
        var matchesToRemove: Set<String> = []
        var powerUpsToCreate: [(row: Int, col: Int, type: PieceType)] = []
        
        print("🔍 [DEBUG] Starting match detection scan...")
        
        // Check horizontal matches (5+ first, then 4, then 3)
        // SCAN FROM BOTTOM-LEFT: start at row (gridHeight-1) going UP, col 0 going RIGHT
        for row in (0..<level.gridHeight).reversed() {
            var col = 0
            while col < level.gridWidth {
                if gridShapeMap[row][col], let piece = gameGrid[row][col], piece.type == .normal {
                    var matchCount = 1
                    var checkCol = col + 1
                    
                    while checkCol < level.gridWidth &&
                          gridShapeMap[row][checkCol],
                          let nextPiece = gameGrid[row][checkCol],
                          piece.matches(nextPiece) {
                        matchCount += 1
                        checkCol += 1
                    }
                    
                    if matchCount >= 3 {
                        print("🔍 [DEBUG] Found horizontal match at row=\(row), col=\(col): count=\(matchCount) item=\(piece.itemId) color=\(piece.colorIndex)")
                    }
                    
                    if matchCount >= 5 {
                        // 5+ match: create flame power-up at middle
                        let middleCol = col + matchCount / 2
                        powerUpsToCreate.append((row: row, col: middleCol, type: .flame))
                        
                        // Mark all pieces for removal using loop indices, not piece positions
                        for i in col..<col + matchCount {
                            matchesToRemove.insert("\(row),\(i)")
                        }
                    } else if matchCount >= 4 {
                        // 4+ match: create horizontal arrow
                        // Try to place at swapped position if it's in the match
                        var arrowCol = col + matchCount / 2  // Default: middle
                        
                        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                            // Check if swapped tile is in this horizontal match
                            if r1 == row && c1 >= col && c1 < col + matchCount {
                                arrowCol = c1
                            } else if r2 == row && c2 >= col && c2 < col + matchCount {
                                arrowCol = c2
                            }
                        }
                        
                        powerUpsToCreate.append((row: row, col: arrowCol, type: .horizontalArrow))
                        print("🔍 [DEBUG] Found 4+ horizontal match at row=\(row), cols \(col) to \(col + matchCount - 1). Arrow placed at (\(row),\(arrowCol))")
                        
                        // Mark all pieces for removal using loop indices, not piece positions
                        for i in col..<col + matchCount {
                            matchesToRemove.insert("\(row),\(i)")
                        }
                    } else if matchCount >= 3 {
                        // 3 match: remove pieces using loop indices
                        for i in col..<col + matchCount {
                            matchesToRemove.insert("\(row),\(i)")
                        }
                    }
                    
                    col = max(col + 1, checkCol)
                } else {
                    col += 1
                }
            }
        }
        
        // Check vertical matches (5+ first, then 4, then 3)
        // SCAN FROM BOTTOM-LEFT: col 0 going RIGHT, start at row (gridHeight-1) going UP
        for col in 0..<level.gridWidth {
            var row = level.gridHeight - 1
            while row >= 0 {
                if gridShapeMap[row][col], let piece = gameGrid[row][col], piece.type == .normal {
                    var matchCount = 1
                    var checkRow = row - 1
                    
                    while checkRow >= 0 &&
                          gridShapeMap[checkRow][col],
                          let nextPiece = gameGrid[checkRow][col],
                          piece.matches(nextPiece) {
                        matchCount += 1
                        checkRow -= 1
                    }
                    
                    if matchCount >= 3 {
                        print("🔍 [DEBUG] Found vertical match at row=\(row), col=\(col): count=\(matchCount) item=\(piece.itemId) color=\(piece.colorIndex)")
                    }
                    
                    if matchCount >= 5 {
                        // 5+ match: create flame power-up at middle
                        let middleRow = row - matchCount / 2
                        powerUpsToCreate.append((row: middleRow, col: col, type: .flame))
                        
                        // Mark all pieces for removal using loop indices
                        for i in (row - matchCount + 1)...row {
                            matchesToRemove.insert("\(i),\(col)")
                        }
                    } else if matchCount >= 4 {
                        // 4+ match: create vertical arrow
                        // Try to place at swapped position if it's in the match
                        var arrowRow = row - matchCount / 2  // Default: middle
                        
                        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                            // Check if swapped tile is in this vertical match
                            if c1 == col && r1 <= row && r1 > row - matchCount {
                                arrowRow = r1
                            } else if c2 == col && r2 <= row && r2 > row - matchCount {
                                arrowRow = r2
                            }
                        }
                        
                        powerUpsToCreate.append((row: arrowRow, col: col, type: .verticalArrow))
                        print("🔍 [DEBUG] Found 4+ vertical match at col=\(col), rows \(row - matchCount + 1) to \(row). Arrow placed at (\(arrowRow),\(col))")
                        
                        // Mark all pieces for removal using loop indices
                        for i in (row - matchCount + 1)...row {
                            matchesToRemove.insert("\(i),\(col)")
                        }
                    } else if matchCount >= 3 {
                        // 3 match: remove pieces using loop indices
                        for i in (row - matchCount + 1)...row {
                            matchesToRemove.insert("\(i),\(col)")
                        }
                    }
                    
                    row = min(row - 1, checkRow)
                } else {
                    row -= 1
                }
            }
        }
        
        // Check for 2x2 bomb patterns
        for row in 0..<level.gridHeight - 1 {
            for col in 0..<level.gridWidth - 1 {
                if gridShapeMap[row][col] && gridShapeMap[row][col + 1] &&
                   gridShapeMap[row + 1][col] && gridShapeMap[row + 1][col + 1],
                   let p1 = gameGrid[row][col], p1.type == .normal,
                   let p2 = gameGrid[row][col + 1], p2.type == .normal,
                   let p3 = gameGrid[row + 1][col], p3.type == .normal,
                   let p4 = gameGrid[row + 1][col + 1], p4.type == .normal,
                   p1.matches(p2) && p2.matches(p3) && p3.matches(p4) {
                    // Determine bomb position: place it where the swap happened
                    var bombRow = row + 1
                    var bombCol = col + 1
                    
                    // Check if a swap created this 2x2 match
                    if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                        // If one of the swapped positions is in the 2x2, put bomb there
                        if (r1 == row && c1 == col) || (r1 == row && c1 == col + 1) ||
                           (r1 == row + 1 && c1 == col) || (r1 == row + 1 && c1 == col + 1) {
                            // First swapped piece is in the 2x2 - use its position
                            bombRow = r1
                            bombCol = c1
                        } else if (r2 == row && c2 == col) || (r2 == row && c2 == col + 1) ||
                                  (r2 == row + 1 && c2 == col) || (r2 == row + 1 && c2 == col + 1) {
                            // Second swapped piece is in the 2x2 - use its position
                            bombRow = r2
                            bombCol = c2
                        }
                    }
                    
                    powerUpsToCreate.append((row: bombRow, col: bombCol, type: .bomb))
                    print("🔍 [DEBUG] Found 2x2 bomb pattern at 2x2 square (\(row),\(col)) to (\(row+1),\(col+1)). Bomb placed at (\(bombRow),\(bombCol))")
                    
                    // Mark all 4 pieces for removal using grid indices
                    matchesToRemove.insert("\(row),\(col)")
                    matchesToRemove.insert("\(row),\(col + 1)")
                    matchesToRemove.insert("\(row + 1),\(col)")
                    matchesToRemove.insert("\(row + 1),\(col + 1)")
                }
            }
        }
        
        // Check for L-shape patterns → rocket powerup
        // An L-shape is 3 tiles horizontal + 3 tiles vertical sharing a corner (5 unique tiles)
        // Check all 4 rotations: right+down, left+down, right+up, left+up
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard gridShapeMap[row][col],
                      let cornerPiece = gameGrid[row][col],
                      cornerPiece.type == .normal else { continue }
                
                // Check each of the 4 L-shape orientations
                let orientations: [(hDir: Int, vDir: Int)] = [
                    (1, 1),   // right + down
                    (-1, 1),  // left + down
                    (1, -1),  // right + up
                    (-1, -1)  // left + up
                ]
                
                for (hDir, vDir) in orientations {
                    // Horizontal arm: (row, col), (row, col+hDir), (row, col+2*hDir)
                    let h1 = (row, col + hDir)
                    let h2 = (row, col + 2 * hDir)
                    // Vertical arm: (row, col), (row+vDir, col), (row+2*vDir, col)
                    let v1 = (row + vDir, col)
                    let v2 = (row + 2 * vDir, col)
                    
                    // Bounds check
                    guard h1.1 >= 0 && h1.1 < level.gridWidth &&
                          h2.1 >= 0 && h2.1 < level.gridWidth &&
                          v1.0 >= 0 && v1.0 < level.gridHeight &&
                          v2.0 >= 0 && v2.0 < level.gridHeight else { continue }
                    
                    // Shape check
                    guard gridShapeMap[h1.0][h1.1] && gridShapeMap[h2.0][h2.1] &&
                          gridShapeMap[v1.0][v1.1] && gridShapeMap[v2.0][v2.1] else { continue }
                    
                    // Piece check - all must be normal and matching
                    guard let pH1 = gameGrid[h1.0][h1.1], pH1.type == .normal, cornerPiece.matches(pH1),
                          let pH2 = gameGrid[h2.0][h2.1], pH2.type == .normal, cornerPiece.matches(pH2),
                          let pV1 = gameGrid[v1.0][v1.1], pV1.type == .normal, cornerPiece.matches(pV1),
                          let pV2 = gameGrid[v2.0][v2.1], pV2.type == .normal, cornerPiece.matches(pV2) else { continue }
                    
                    // Found an L-shape! Place rocket at the corner tile
                    // Determine rocket position: prefer the swap position if it's in the L
                    var rocketRow = row
                    var rocketCol = col
                    
                    let lTiles = [(row, col), h1, h2, v1, v2]
                    if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                        if lTiles.contains(where: { $0.0 == r1 && $0.1 == c1 }) {
                            rocketRow = r1
                            rocketCol = c1
                        } else if lTiles.contains(where: { $0.0 == r2 && $0.1 == c2 }) {
                            rocketRow = r2
                            rocketCol = c2
                        }
                    }
                    
                    powerUpsToCreate.append((row: rocketRow, col: rocketCol, type: .rocket))
                    print("🔍 [DEBUG] Found L-shape pattern at corner (\(row),\(col)) orientation h:\(hDir) v:\(vDir). Rocket at (\(rocketRow),\(rocketCol))")
                    
                    // Mark all 5 tiles for removal
                    for tile in lTiles {
                        matchesToRemove.insert("\(tile.0),\(tile.1)")
                    }
                }
            }
        }
        
        if !matchesToRemove.isEmpty {
            print("🔍 [DEBUG] Total matches found: \(matchesToRemove.count) tiles to remove")
            print("🔍 [DEBUG] Matches: \(matchesToRemove.sorted())")
            print("🔍 [DEBUG] Initial powerups to create: \(powerUpsToCreate.count)")
            
            // PRIORITIZE POWERUPS: flame > rocket > arrow > bomb
            // If multiple powerups target the same location, keep only the highest priority
            var prioritizedPowerups: [(row: Int, col: Int, type: PieceType)] = []
            var powerupLocations: [String: PieceType] = [:]  // Track (row,col) -> highest priority type
            
            for powerup in powerUpsToCreate {
                let key = "\(powerup.row),\(powerup.col)"
                let existingType = powerupLocations[key]
                
                // Determine priority: flame (4) > rocket (3) > arrow (2) > bomb (1) > nil (0)
                func typePriority(_ t: PieceType) -> Int {
                    switch t {
                    case .flame: return 4
                    case .rocket: return 3
                    case .verticalArrow, .horizontalArrow: return 2
                    case .bomb: return 1
                    default: return 0
                    }
                }
                let newPriority = typePriority(powerup.type)
                let existingPriority = existingType.map { typePriority($0) } ?? 0
                
                // Add powerup if no existing one or if new one has higher priority
                if existingPriority == 0 || newPriority > existingPriority {
                    powerupLocations[key] = powerup.type
                }
            }
            
            // Convert back to array
            for (key, type) in powerupLocations {
                let parts = key.split(separator: ",").map { Int($0) ?? 0 }
                if parts.count == 2 {
                    prioritizedPowerups.append((row: parts[0], col: parts[1], type: type))
                }
            }
            
            print("✅ VALID MATCH DETECTED - animating removal")
            print("🔍 [DEBUG] Prioritized powerups to create: \(prioritizedPowerups.count)")
            
            // Use prioritized powerups instead
            powerUpsToCreate = prioritizedPowerups
            
            // Trigger haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Only decrement moves if this was a user swap (initial move), not a cascade
            if lastSwappedPositions != nil {
                movesRemaining -= 1
            }
            
            // Clear lastSwappedPositions and reset transforms
            lastSwappedPositions = nil
            
            // Reset the transforms of swapped buttons and update display so buttons
            // show the correct post-swap content before the match animation starts
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                swappedButtons = nil
            }
            updateGridDisplay()
            
            // Animate matched pieces, then proceed when animation completes
            animateMatchedPieces(matchesToRemove) { [weak self] in
                // Now that animation is complete, remove the pieces from grid
                for posString in matchesToRemove {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self?.score += 1
                        self?.gameGrid[parts[0]][parts[1]] = nil
                    }
                }
                
                // Create power-ups
                for powerUp in powerUpsToCreate {
                    self?.gameGrid[powerUp.row][powerUp.col] = GamePiece(
                        itemId: "power_up",
                        colorIndex: 0,
                        row: powerUp.row,
                        col: powerUp.col,
                        type: powerUp.type
                    )
                }
                
                // Mark animation complete BEFORE updateUI() so level completion check works
                self?.isAnimating = false
                // applyGravity() calls updateGridDisplay() internally — no need to call it here
                self?.applyGravity()
            }
        } else {
            // No match found
            print("🔍 [DEBUG] No matches found in current grid")
            
            // Revert the swap if one was made
            if let ((r1, c1), (r2, c2)) = lastSwappedPositions, let (button1, button2) = swappedButtons {
                print("⚠️ Invalid move - reverting swap from (\(r1),\(c1)) and (\(r2),\(c2))")
                lastSwappedPositions = nil
                swappedButtons = nil
                
                // Animate revert - pieces slide back with 0.5 second animation
                UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
                    button1.transform = .identity
                    button2.transform = .identity
                }, completion: { _ in
                    // Revert the swap in data
                    let temp = self.gameGrid[r1][c1]
                    self.gameGrid[r1][c1] = self.gameGrid[r2][c2]
                    self.gameGrid[r2][c2] = temp
                    
                    // Update positions
                    self.gameGrid[r1][c1]?.row = r1
                    self.gameGrid[r1][c1]?.col = c1
                    self.gameGrid[r2][c2]?.row = r2
                    self.gameGrid[r2][c2]?.col = c2
                    
                    // No move refund needed - we never decremented for invalid moves
                    self.currentSwapInvolvesAPowerup = false
                    
                    self.updateGridDisplay()
                    self.updateUI()
                    self.isAnimating = false
                    self.checkGameOver()  // Check for game over after revert completes
                })
            } else {
                isAnimating = false
                // Check for game over after invalid move revert completes
                checkGameOver()
            }
        }
    }
    
    private func showPowerupBorderHighlight(_ affectedTiles: Set<String>, then completion: @escaping () -> Void) {
        guard !affectedTiles.isEmpty else {
            completion()
            return
        }
        
        // Show yellow border around all affected tiles
        for posString in affectedTiles {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            guard parts.count == 2 else { continue }
            let row = parts[0]
            let col = parts[1]
            
            if let button = gridButtons[row][col] {
                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.yellow.cgColor
            }
        }
        
        // After brief highlight, clear borders and proceed with completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            for posString in affectedTiles {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                guard parts.count == 2 else { continue }
                let row = parts[0]
                let col = parts[1]
                
                if let button = self.gridButtons[row][col] {
                    button.layer.borderWidth = 0
                }
            }
            
            completion()
        }
    }
    
    private func animateMatchedPieces(_ matchesToRemove: Set<String>, completion: @escaping () -> Void) {
        guard !matchesToRemove.isEmpty else {
            completion()
            return
        }
        
        let allButtons = matchesToRemove.compactMap { posString -> UIButton? in
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            guard parts.count == 2 else { return nil }
            let row = parts[0]
            let col = parts[1]
            return gridButtons[row][col]
        }
        
        guard !allButtons.isEmpty else {
            completion()
            return
        }
        
        // STEP 1: Show yellow border highlight around matched tiles (0.2 seconds)
        for button in allButtons {
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.yellow.cgColor
        }
        
        // STEP 2: After brief highlight, animate removal and clear border
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            var animationCount = 0
            var completedCount = 0
            
            for posString in matchesToRemove {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                guard parts.count == 2 else { continue }
                let row = parts[0]
                let col = parts[1]
                
                if let button = self?.gridButtons[row][col] {
                    animationCount += 1
                    
                    // Animate: scale down + fade + rotate
                    UIView.animate(withDuration: 0.15, animations: {
                        button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: CGFloat.pi)
                        button.alpha = 0.0
                    }, completion: { _ in
                        // Reset transform after animation so new piece displays correctly
                        button.transform = .identity
                        button.alpha = 1.0
                        button.layer.borderWidth = 0  // Clear border
                        
                        completedCount += 1
                        // When all animations complete, call the completion handler
                        if completedCount == animationCount {
                            completion()
                        }
                    })
                }
            }
        }
    }
    
    private func applyGravity() {
        guard let level = currentLevel else { return }
        
        // Clear tracking - we track ALL pieces that move (existing + new)
        movedPieces.removeAll()
        fallDistances.removeAll()
        newPieces.removeAll()  // Clear the new pieces tracker
        
        // STEP 1: Apply gravity - track existing pieces that fall
        for col in 0..<level.gridWidth {
            // Collect all non-empty positions
            var pieces: [(row: Int, piece: GamePiece)] = []
            
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    pieces.append((row: row, piece: piece))
                    gameGrid[row][col] = nil  // Clear current position
                }
            }
            
            // Place pieces from bottom up, tracking how far each fell
            var targetRow = level.gridHeight - 1
            for (originalRow, piece) in pieces.reversed() {
                while targetRow >= 0 && (!gridShapeMap[targetRow][col] || gameGrid[targetRow][col] != nil) {
                    targetRow -= 1
                }
                
                if targetRow >= 0 {
                    let distance = originalRow - targetRow  // Distance fallen
                    gameGrid[targetRow][col] = piece
                    piece.row = targetRow
                    piece.col = col
                    
                    movedPieces.insert("\(targetRow),\(col)")
                    fallDistances["\(targetRow),\(col)"] = distance
                    
                    targetRow -= 1
                }
            }
        }
        
        // STEP 2: Refill empty spaces with NEW pieces - track with larger distance
        for col in 0..<level.gridWidth {
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col] && gameGrid[row][col] == nil {
                    let randomItemIndex = Int.random(in: 0..<level.items.count)
                    let randomColorIndex = Int.random(in: 0..<level.colors.count)
                    let newPiece = GamePiece(
                        itemId: level.items[randomItemIndex].id,
                        colorIndex: randomColorIndex,
                        row: row,
                        col: col,
                        type: .normal
                    )
                    gameGrid[row][col] = newPiece
                    
                    // NEW pieces get larger fall distance (from above grid)
                    // Only mark as moved if not already tracked as existing piece
                    if !movedPieces.contains("\(row),\(col)") {
                        movedPieces.insert("\(row),\(col)")
                        // Distance for new pieces: from top of screen (larger distance)
                        fallDistances["\(row),\(col)"] = row + 2
                        // Mark this as a NEW piece
                        newPieces.insert("\(row),\(col)")
                    }
                }
            }
        }
        
        // Update grid display to set correct content on buttons BEFORE animation
        updateGridDisplay()
        
        // Now set all buttons to their START positions before animation
        // This is critical: buttons must be visually where the piece currently is, not where it's going
        for col in 0..<level.gridWidth {
            for row in 0..<level.gridHeight {
                let key = "\(row),\(col)"
                guard movedPieces.contains(key), let button = gridButtons[row][col] else { continue }
                
                let distance = fallDistances[key] ?? 0
                let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
                
                // Set button to START position (before gravity)
                if newPieces.contains(key) {
                    // NEW pieces start OFF-SCREEN (above)
                    let fallDistance = cellHeight * CGFloat(distance)
                    button.transform = CGAffineTransform(translationX: 0, y: -fallDistance)
                    button.alpha = 0  // Start hidden
                } else {
                    // EXISTING pieces start DOWN from where they'll end (they fell down, so we move them up visually)
                    let fallDistance = cellHeight * CGFloat(distance)
                    button.transform = CGAffineTransform(translationX: 0, y: fallDistance)
                    button.alpha = 1.0
                }
            }
        }
        
        // Animate pieces falling, then check for matches when complete
        animatePiecesDrop() { [weak self] in
            self?.checkForMatches()
        }
    }
    
    // Helper function to check if game should end
    private func checkGameOver() {
        if movesRemaining <= 0 && !isAnimating {
            levelFailed()
        }
    }
    
    private func animatePiecesDrop(completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        
        // Scale fall speed with grid size so larger grids don't feel sluggish
        let baseFallSpeed: CGFloat = 400
        let gridScale = CGFloat(max(level.gridHeight, 10)) / 10.0
        let fallSpeedPixelsPerSecond: CGFloat = baseFallSpeed * gridScale
        
        // Build list of pieces to animate per column, sorted bottom to top
        var columnPieces: [[AnimatingPiece]] = Array(repeating: [], count: level.gridWidth)
        
        for col in 0..<level.gridWidth {
            var pieces: [AnimatingPiece] = []
            
            for row in 0..<level.gridHeight {
                let key = "\(row),\(col)"
                if movedPieces.contains(key), gridShapeMap[row][col], let button = gridButtons[row][col], gameGrid[row][col] != nil {
                    let distance = fallDistances[key] ?? 0
                    let isNewPiece = newPieces.contains(key)
                    pieces.append(AnimatingPiece(button: button, row: row, distance: distance, isNew: isNewPiece))
                }
            }
            
            // Sort by row DESCENDING (bottom first) - pieces will animate sequentially
            pieces.sort { $0.row > $1.row }
            columnPieces[col] = pieces
        }
        
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        
        // Animate each column sequentially: animate bottom piece, when done animate next, etc.
        var completedColumns = 0
        let totalColumns = columnPieces.count
        
        for col in 0..<level.gridWidth {
            let pieces = columnPieces[col]
            
            guard !pieces.isEmpty else {
                completedColumns += 1
                if completedColumns == totalColumns {
                    completion()
                }
                continue
            }
            
            // Animate pieces in this column sequentially using chained completion handlers
            animateColumnPiecesSequentially(pieces: pieces, index: 0, cellHeight: cellHeight, fallSpeed: fallSpeedPixelsPerSecond, col: col) {
                completedColumns += 1
                if completedColumns == totalColumns {
                    completion()
                }
            }
        }
    }
    
    // Helper struct for animation tracking
    private struct AnimatingPiece {
        let button: UIButton
        let row: Int
        let distance: Int
        let isNew: Bool
    }
    
    // Recursively animate pieces in a column one by one
    private func animateColumnPiecesSequentially(
        pieces: [AnimatingPiece],
        index: Int,
        cellHeight: CGFloat,
        fallSpeed: CGFloat,
        col: Int,
        completion: @escaping () -> Void
    ) {
        guard index < pieces.count else {
            completion()
            return
        }
        
        let piece = pieces[index]
        let fallDistance = cellHeight * CGFloat(piece.distance)
        let duration = min(Double(fallDistance / fallSpeed), 0.45) // Cap at 0.45s so long falls stay snappy
        
        // Set starting position
        if piece.isNew {
            piece.button.transform = CGAffineTransform(translationX: 0, y: -fallDistance)
            piece.button.alpha = 0
        } else {
            piece.button.transform = CGAffineTransform(translationX: 0, y: fallDistance)
            piece.button.alpha = 1.0
        }
        
        // Calculate when to start next piece — tighter overlap on bigger grids
        let percentToWait = 0.3  // 30% overlap: next piece starts when current is 30% done
        let delayForNextPiece = max(duration * percentToWait, 0.04) // Minimum 40ms gap to stay ordered
        
        // Start next piece animation after percentage completion of current piece
        if index + 1 < pieces.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayForNextPiece) { [weak self] in
                self?.animateColumnPiecesSequentially(
                    pieces: pieces,
                    index: index + 1,
                    cellHeight: cellHeight,
                    fallSpeed: fallSpeed,
                    col: col,
                    completion: completion
                )
            }
        }
        
        // Animate this piece
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                piece.button.transform = .identity
                piece.button.alpha = 1.0
            },
            completion: { _ in
                // Only call completion if this is the last piece
                if index == pieces.count - 1 {
                    completion()
                }
            }
        )
    }
    
    private func updateGridDisplay() {
        guard let level = currentLevel else { return }
        
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard let button = gridButtons[row][col] else { continue }
                
                if let piece = gameGrid[row][col] {
                    // Display power-ups with special symbols
                    let powerupFontSize = max(16, min(40, 420 / CGFloat(max(level.gridWidth, level.gridHeight))))
                    switch piece.type {
                    case .verticalArrow:
                        button.setTitle("↕️", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                    case .horizontalArrow:
                        button.setTitle("↔️", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                    case .bomb:
                        button.setTitle("💣", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                    case .flame:
                        button.setTitle("🔥", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                    case .rocket:
                        button.setTitle("🌟", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                    case .normal:
                        let itemIndex = level.items.firstIndex(where: { $0.id == piece.itemId }) ?? 0
                        let item = level.items[itemIndex]
                        
                        // Try to use asset image first, fall back to emoji
                        if let assetName = item.asset, !assetName.isEmpty {
                            // Use asset image - pin imageView to fill the button
                            let image = UIImage(named: assetName)
                            
                            // Configure button for image display
                            button.setImage(image, for: .normal)
                            button.setTitle("", for: .normal)
                            button.imageView?.contentMode = .scaleAspectFit
                            button.imageView?.clipsToBounds = true
                            // Pin imageView to fill button (matching renderGrid setup)
                            if let imageView = button.imageView {
                                imageView.translatesAutoresizingMaskIntoConstraints = false
                                // Only add pinning constraints if not already present
                                // Check by looking for a constraint with the imageView pinned to button top
                                let alreadyPinned = button.constraints.contains { constraint in
                                    (constraint.firstItem === imageView && constraint.secondItem === button &&
                                     constraint.firstAttribute == .top) ||
                                    (constraint.secondItem === imageView && constraint.firstItem === button &&
                                     constraint.secondAttribute == .top)
                                }
                                if !alreadyPinned {
                                    NSLayoutConstraint.activate([
                                        imageView.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
                                        imageView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2),
                                        imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
                                        imageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2)
                                    ])
                                }
                            }
                        } else {
                            // Fall back to emoji - scale font to nearly fill the tile
                            let itemEmoji = item.emoji ?? "?"
                            let emojiFontSize = max(16, min(40, 420 / CGFloat(max(level.gridWidth, level.gridHeight))))
                            button.setTitle(itemEmoji, for: .normal)
                            button.setImage(nil, for: .normal)
                            button.titleLabel?.font = UIFont.systemFont(ofSize: emojiFontSize)
                            button.titleLabel?.adjustsFontSizeToFitWidth = true
                            button.titleLabel?.minimumScaleFactor = 0.7
                        }
                        
                        // Handle optional colors - nil means transparent background
                        if let colorHex = level.colors[piece.colorIndex] {
                            button.backgroundColor = UIColor(hex: colorHex) ?? .gray
                        } else {
                            button.backgroundColor = .clear
                        }
                    }
                    
                    // Highlight selected piece
                    if selectedPiece?.row == row && selectedPiece?.col == col {
                        button.layer.borderColor = UIColor.yellow.cgColor
                        button.layer.borderWidth = 1
                    } else {
                        button.layer.borderWidth = 0
                    }
                } else {
                    button.backgroundColor = darkBg
                    button.setTitle("", for: .normal)
                }
            }
        }
        
        updateUI()
    }
    
    private func hasValidMoves() -> Bool {
        guard let level = currentLevel else { return false }
        
        // Try each piece and see if swapping with adjacent pieces creates a match
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col], gameGrid[row][col] != nil {
                    // Try swapping with right neighbor
                    if col + 1 < level.gridWidth && gridShapeMap[row][col + 1] && gameGrid[row][col + 1] != nil {
                        if wouldCreateMatch(swappingRow1: row, col1: col, row2: row, col2: col + 1) {
                            return true
                        }
                    }
                    
                    // Try swapping with bottom neighbor
                    if row + 1 < level.gridHeight && gridShapeMap[row + 1][col] && gameGrid[row + 1][col] != nil {
                        if wouldCreateMatch(swappingRow1: row, col1: col, row2: row + 1, col2: col) {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    private func wouldCreateMatch(swappingRow1 r1: Int, col1 c1: Int, row2 r2: Int, col2 c2: Int) -> Bool {
        // Temporarily swap
        let temp = gameGrid[r1][c1]
        gameGrid[r1][c1] = gameGrid[r2][c2]
        gameGrid[r2][c2] = temp
        
        // Check for matches
        var hasMatch = false
        
        // Check horizontal matches around r1, c1
        if hasMatchesAtPosition(r1, c1) {
            hasMatch = true
        }
        
        // Check vertical matches around r1, c1
        if !hasMatch && hasMatchesAtPosition(r1, c1) {
            hasMatch = true
        }
        
        // Check horizontal matches around r2, c2
        if !hasMatch && hasMatchesAtPosition(r2, c2) {
            hasMatch = true
        }
        
        // Check vertical matches around r2, c2
        if !hasMatch && hasMatchesAtPosition(r2, c2) {
            hasMatch = true
        }
        
        // Swap back
        let temp2 = gameGrid[r1][c1]
        gameGrid[r1][c1] = gameGrid[r2][c2]
        gameGrid[r2][c2] = temp2
        
        return hasMatch
    }
    
    private func hasMatchesAtPosition(_ row: Int, _ col: Int) -> Bool {
        guard let level = currentLevel else { return false }
        guard let piece = gameGrid[row][col] else { return false }
        
        // Check horizontal
        var matchCount = 1
        var checkCol = col - 1
        while checkCol >= 0 && gridShapeMap[row][checkCol],
              let nextPiece = gameGrid[row][checkCol],
              piece.matches(nextPiece) {
            matchCount += 1
            checkCol -= 1
        }
        checkCol = col + 1
        while checkCol < level.gridWidth && gridShapeMap[row][checkCol],
              let nextPiece = gameGrid[row][checkCol],
              piece.matches(nextPiece) {
            matchCount += 1
            checkCol += 1
        }
        if matchCount >= 3 {
            return true
        }
        
        // Check vertical
        matchCount = 1
        var checkRow = row - 1
        while checkRow >= 0 && gridShapeMap[checkRow][col],
              let nextPiece = gameGrid[checkRow][col],
              piece.matches(nextPiece) {
            matchCount += 1
            checkRow -= 1
        }
        checkRow = row + 1
        while checkRow < level.gridHeight && gridShapeMap[checkRow][col],
              let nextPiece = gameGrid[checkRow][col],
              piece.matches(nextPiece) {
            matchCount += 1
            checkRow += 1
        }
        if matchCount >= 3 {
            return true
        }
        
        return false
    }
    private func shuffleGrid() {
        guard let level = currentLevel else { return }
        
        isAnimating = true
        
        // Collect all pieces to shuffle
        var pieces: [GamePiece] = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    pieces.append(piece)
                }
            }
        }
        pieces.shuffle()
        
        // Create grid data with shuffled pieces
        var newGridData: [[GamePiece?]] = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        
        var pieceIndex = 0
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] && pieceIndex < pieces.count {
                    newGridData[row][col] = pieces[pieceIndex]
                    pieces[pieceIndex].row = row
                    pieces[pieceIndex].col = col
                    pieceIndex += 1
                }
            }
        }
        
        // Now animate each button to fly out, then update content, then fly back
        var animationCount = 0
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col], let button = gridButtons[row][col] {
                    animationCount += 1
                    let delay = Double(row * level.gridWidth + col) * 0.02
                    
                    // Generate random offset
                    let randomX = CGFloat.random(in: -100...100)
                    let randomY = CGFloat.random(in: -100...100)
                    
                    // Phase 1: Fly out
                    UIView.animate(withDuration: 0.2, delay: delay, options: .curveEaseIn, animations: {
                        button.transform = CGAffineTransform(translationX: randomX, y: randomY)
                        button.alpha = 0.3
                    }, completion: { _ in
                        // Phase 2: Update the grid display while button is off-screen
                        // Put the NEW shuffled piece in the grid
                        if row < newGridData.count && col < newGridData[row].count {
                            self.gameGrid[row][col] = newGridData[row][col]
                        }
                        self.updateGridDisplay()
                        
                        // Phase 3: Fly back
                        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut, animations: {
                            button.transform = .identity
                            button.alpha = 1.0
                        }, completion: { _ in
                            animationCount -= 1
                            if animationCount == 0 {
                                self.checkForMatches()
                            }
                        })
                    })
                }
            }
        }
    }
    
    @objc private func exitGame() {
        // Save game state before exiting
        saveGameState()
        
        print("🎮 Exiting match game - returning to dashboard")
        
        // Call the callback to navigate back via ModuleState
        DispatchQueue.main.async {
            print("   ✅ Calling onDismissGame callback")
            self.onDismissGame?()
        }
    }
    
    // MARK: - Level Selector and State Persistence
    
    @objc private func showLevelSelector() {
        let alert = UIAlertController(title: "Select Level", message: "Choose a level to play", preferredStyle: .actionSheet)
        
        // Add each unlocked level
        if let config = gameConfig {
            for level in config.levels {
                if unlockedLevels.contains(level.id) {
                    let title = level.id == currentLevelId ? "✓ Level \(level.id)" : "Level \(level.id)"
                    alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                        self?.selectLevel(level.id)
                    })
                }
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func selectLevel(_ levelId: Int) {
        // Save current level state
        saveGameState()
        
        // Change level
        currentLevelId = levelId
        score = 0
        
        // Clear old grid
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        gridStackView.removeFromSuperview()
        gridStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Start new level
        startLevel(levelId)
        
        // Update button text
        levelSelectorButton.setTitle("Level \(levelId) ▼", for: .normal)
    }
    
    private func saveGameState() {
        // Save current score and level
        UserDefaults.standard.set(currentLevelId, forKey: "matchGameCurrentLevel")
        UserDefaults.standard.set(score, forKey: "matchGameScore_\(currentLevelId)")
        UserDefaults.standard.set(unlockedLevels, forKey: "matchGameUnlockedLevels")
        print("💾 Game state saved: Level \(currentLevelId), Score \(score)")
    }
    
    private func loadSavedState() {
        // Load saved level and score
        let savedLevel = UserDefaults.standard.integer(forKey: "matchGameCurrentLevel")
        if savedLevel > 0 {
            currentLevelId = savedLevel
            levelSelectorButton.setTitle("Level \(savedLevel) ▼", for: .normal)
        }
        
        // Load saved score for this level
        let savedScore = UserDefaults.standard.integer(forKey: "matchGameScore_\(currentLevelId)")
        if savedScore > 0 {
            score = savedScore
            //print("📥 Restored: Level \(currentLevelId), Score \(score)")
        }
        
        // Load unlocked levels
        if let saved = UserDefaults.standard.array(forKey: "matchGameUnlockedLevels") as? [Int] {
            unlockedLevels = saved
        }
    }
    
    // MARK: - Handle Level Failure
    
    private func levelFailed() {
        guard let level = currentLevel else { return }
        
        print("❌ LEVEL \(level.id) FAILED! Out of moves. Score: \(score) < Target: \(level.scoreTarget)")
        
        // Disable interactions
        isAnimating = true
        
        // Show failure message and restart option
        showLevelFailedAnimation {
            // Show restart alert
            let alert = UIAlertController(title: "Out of Moves!", message: "You ran out of moves before reaching the target score of \(level.scoreTarget).", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
                // Completely reset level for full refresh
                self.isAnimating = false
                self.lastSwappedPositions = nil
                self.swappedButtons = nil
                self.selectedPiece = nil
                self.dragStartPiece = nil
                self.dragTargetPiece = nil
                self.movedPieces.removeAll()
                self.fallDistances.removeAll()
                self.newPieces.removeAll()
                
                // Now restart the level
                self.score = 0
                self.startLevel(level.id)
            })
            
            alert.addAction(UIAlertAction(title: "Exit", style: .cancel) { _ in
                // Return to level selection
                self.exitGame()
            })
            
            self.present(alert, animated: true)
        }
    }
    
    private func showLevelFailedAnimation(completion: @escaping () -> Void) {
        // Create overlay with "Out of Moves!" text
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.frame = view.bounds
        view.addSubview(overlay)
        
        let label = UILabel()
        label.text = "Out of Moves!"
        label.font = UIFont.boldSystemFont(ofSize: 48)
        label.textColor = .white
        label.textAlignment = .center
        label.center = view.center
        label.alpha = 0
        view.addSubview(label)
        
        UIView.animate(withDuration: 0.5, animations: {
            label.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, animations: {
                overlay.alpha = 0
                label.alpha = 0
            }, completion: { _ in
                overlay.removeFromSuperview()
                label.removeFromSuperview()
                completion()
            })
        })
    }
    
    // MARK: - Idle Hint System
    
    private func resetIdleHintTimer() {
        // Cancel existing timer
        idleTimer?.invalidate()
        idleTimer = nil
        
        // Stop current hint animation if any
        if let (hRow, hCol) = hintingTile,
           let button = gridButtons[hRow][hCol] {
            button.layer.removeAllAnimations()
            button.alpha = 1.0
        }
        hintingTile = nil
        
        // Start new timer - show hint after 10 seconds of inactivity
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.showIdleHint()
        }
    }
    
    private func showIdleHint() {
        guard let level = currentLevel, !isAnimating else { return }
        
        // Don't show a new hint if one is already showing
        if hintingTile != nil {
            return
        }
        
        // IMPORTANT: Don't show hints if there are cascading matches currently on the board
        // This prevents pulsing while new matches are being processed
        if hasCascadingMatches() {
            print("🔍 [DEBUG] Skipping hint - cascading matches detected on board")
            // Reschedule hint check after cascades settle
            resetIdleHintTimer()
            return
        }
        
        // Find a valid swap that would create a match (hint to the player)
        // We want to pulse the tile that will be part of the match after swap
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard gridShapeMap[row][col], gridButtons[row][col] != nil else { continue }
                
                // Try swapping with adjacent tiles
                let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
                for (dRow, dCol) in directions {
                    let adjRow = row + dRow
                    let adjCol = col + dCol
                    
                    if adjRow >= 0 && adjRow < level.gridHeight &&
                       adjCol >= 0 && adjCol < level.gridWidth &&
                       gridShapeMap[adjRow][adjCol] {
                        
                        // Simulate swap to check if it creates a match
                        if let piece1 = gameGrid[row][col], let piece2 = gameGrid[adjRow][adjCol] {
                            // Only check regular pieces (powerups can't form matches this way)
                            guard piece1.type == .normal && piece2.type == .normal else { continue }
                            
                            // Swap in data (temporarily)
                            gameGrid[row][col] = piece2
                            gameGrid[adjRow][adjCol] = piece1
                            piece1.row = adjRow
                            piece1.col = col
                            piece2.row = row
                            piece2.col = adjCol
                            
                            // Check which tile creates a match
                            let matchAtAdjacent = checkTileForMatches(adjRow, adjCol)
                            let matchAtOriginal = checkTileForMatches(row, col)
                            
                            // Swap back
                            gameGrid[row][col] = piece1
                            gameGrid[adjRow][adjCol] = piece2
                            piece1.row = row
                            piece1.col = col
                            piece2.row = adjRow
                            piece2.col = adjCol
                            
                            // Pulse the tile that will create the match after swap
                            // matchAtAdjacent means piece1 (currently at row,col) will create match at adjRow,adjCol
                            // matchAtOriginal means piece2 (currently at adjRow,adjCol) will create match at row,col
                            if matchAtAdjacent {
                                // piece1 is currently at (row, col), will move to (adjRow, adjCol) and match there
                                hintingTile = (row, col)
                                pulseButton(gridButtons[row][col]!)
                                return
                            } else if matchAtOriginal {
                                // piece2 is currently at (adjRow, adjCol), will move to (row, col) and match there
                                hintingTile = (adjRow, adjCol)
                                pulseButton(gridButtons[adjRow][adjCol]!)
                                return
                            }
                        }
                    }
                }
            }
        }
        
        // If no match-creating swap found, just pulse a random tile
        let validTiles = (0..<level.gridHeight).flatMap { row in
            (0..<level.gridWidth).compactMap { col -> (Int, Int)? in
                gridShapeMap[row][col] && gridButtons[row][col] != nil ? (row, col) : nil
            }
        }
        
        if let randomTile = validTiles.randomElement() {
            hintingTile = randomTile
            pulseButton(gridButtons[randomTile.0][randomTile.1]!)
        }
    }
    
    private func hasCascadingMatches() -> Bool {
        guard let level = currentLevel else { return false }
        
        // Check if there are any 3+ matches currently on the board
        // This helps prevent showing hints while cascading matches are being processed
        
        // Check horizontal matches
        for row in 0..<level.gridHeight {
            var col = 0
            while col < level.gridWidth {
                if gridShapeMap[row][col], let piece = gameGrid[row][col], piece.type == .normal {
                    var matchCount = 1
                    var checkCol = col + 1
                    
                    while checkCol < level.gridWidth &&
                          gridShapeMap[row][checkCol],
                          let nextPiece = gameGrid[row][checkCol],
                          piece.matches(nextPiece) {
                        matchCount += 1
                        checkCol += 1
                    }
                    
                    if matchCount >= 3 {
                        return true
                    }
                    col = max(col + 1, checkCol)
                } else {
                    col += 1
                }
            }
        }
        
        // Check vertical matches
        for col in 0..<level.gridWidth {
            var row = level.gridHeight - 1
            while row >= 0 {
                if gridShapeMap[row][col], let piece = gameGrid[row][col], piece.type == .normal {
                    var matchCount = 1
                    var checkRow = row - 1
                    
                    while checkRow >= 0 &&
                          gridShapeMap[checkRow][col],
                          let nextPiece = gameGrid[checkRow][col],
                          piece.matches(nextPiece) {
                        matchCount += 1
                        checkRow -= 1
                    }
                    
                    if matchCount >= 3 {
                        return true
                    }
                    row = min(row - 1, checkRow)
                } else {
                    row -= 1
                }
            }
        }
        
        return false
    }
    
    private func checkTileForMatches(_ row: Int, _ col: Int) -> Bool {
        guard let level = currentLevel, let piece = gameGrid[row][col] else { return false }
        
        // Check horizontal match
        var count = 1
        // Check left
        var c = col - 1
        while c >= 0 && gridShapeMap[row][c] && gameGrid[row][c]?.matches(piece) ?? false {
            count += 1
            c -= 1
        }
        // Check right
        c = col + 1
        while c < level.gridWidth && gridShapeMap[row][c] && gameGrid[row][c]?.matches(piece) ?? false {
            count += 1
            c += 1
        }
        if count >= 3 { return true }
        
        // Check vertical match
        count = 1
        // Check up
        var r = row - 1
        while r >= 0 && gridShapeMap[r][col] && gameGrid[r][col]?.matches(piece) ?? false {
            count += 1
            r -= 1
        }
        // Check down
        r = row + 1
        while r < level.gridHeight && gridShapeMap[r][col] && gameGrid[r][col]?.matches(piece) ?? false {
            count += 1
            r += 1
        }
        
        return count >= 3
    }
    
    private func pulseButton(_ button: UIButton) {
        // Create a pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.4
        pulseAnimation.duration = 0.6
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        
        button.layer.add(pulseAnimation, forKey: "pulse")
    }
}
