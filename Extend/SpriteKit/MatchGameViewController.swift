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
    case ball    // T-shape pattern: bouncing ball that clears tiles it hits
}

// MARK: - Game Piece

class GamePiece {
    static let ballEmojis = ["⚽", "🏀", "🏈", "🏐", "🎾", "⚾"]
    
    let itemId: String
    let colorIndex: Int
    var row: Int
    var col: Int
    var type: PieceType = .normal
    /// Fixed emoji index for ball powerups, assigned once on creation so it doesn't change when the piece moves
    var ballEmojiIndex: Int = 0
    
    init(itemId: String, colorIndex: Int, row: Int, col: Int, type: PieceType = .normal) {
        self.itemId = itemId
        self.colorIndex = colorIndex
        self.row = row
        self.col = col
        self.type = type
        if type == .ball {
            self.ballEmojiIndex = Int.random(in: 0..<GamePiece.ballEmojis.count)
        }
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
    private let armorLabel = UILabel()
    private let sessionTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()

    // MARK: - Timer State
    private var sessionTimer: Timer?
    private var sessionElapsed: TimeInterval = 0       // seconds elapsed this session
    private var totalElapsed: TimeInterval = 0         // cumulative seconds across all sessions
    private var timerSessionStart: Date?               // when the current session began
    
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
    private var pendingCascades: [(row: Int, col: Int, type: PieceType)] = []  // Cascades queued while checkForMatches runs between cascade steps
    private var cascadeDepth: Int = 0            // How many cascading powerups have fired this chain
    private let maxCascadeDepth: Int = 4         // Cap: stop cascading after this many powerup detonations in one chain
    private var armorGrid: [[Int]] = []  // Armor hits remaining per grid position (0 = no armor)
    private var armorOverlays: [[UILabel?]] = []  // Overlay labels showing armor count
    private var armorBorderViews: [[UIView?]] = []  // Static border overlays for armored cells
    private var isApplyingGravity = false  // Guard flag to prevent updateGridDisplay during gravity setup
    private var activeAnimationViews: Set<ObjectIdentifier> = []  // Views currently used by in-flight animations (ball, rocket, etc.) — excluded from gravity cleanup
    private var blankTileOverlays: [UIView] = []  // Overlay views covering blank grid positions (sit above gridStackView to hide pieces sliding through)
    private var levelCompleteCompletion: (() -> Void)?  // Stored completion for level complete modal
    private var retryCount: Int = 0  // Consecutive retries on the current level (progressive help)
    private var retryLevelId: Int = -1  // Which level the retryCount applies to
    private var levelShieldEmoji: String = "🛡️"  // Per-level shield emoji, randomised in startLevel
    private static let shieldEmojiPool: [String] = ["🛡️", "🔒", "💠"]
    
    // MARK: - Game Logic
    private var gridAspectRatioConstraint: NSLayoutConstraint?
    private let darkBg = UIColor(hex: "#2C3E50") ?? .black
    private let lightBg = UIColor(hex: "#34495E") ?? .darkGray
    private let accentColor = UIColor(hex: "#E74C3C") ?? .red
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadGameConfig()
        loadSavedState()      // loads currentLevelId, score, unlockedLevels, AND totalElapsed
        startSessionTimer()
        startLevel(currentLevelId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSessionTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseSessionTimer()
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
        
        // Armor/Shields Label (below moves, right-aligned)
        armorLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        armorLabel.textColor = .cyan
        armorLabel.text = ""
        armorLabel.isHidden = true
        headerView.addSubview(armorLabel)
        armorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            armorLabel.topAnchor.constraint(equalTo: movesLabel.bottomAnchor, constant: 3),
            armorLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15)
        ])

        // Session Time label (top-right, opposite the ✕)
        sessionTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sessionTimeLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        sessionTimeLabel.textAlignment = .right
        sessionTimeLabel.text = "Session  0:00"
        headerView.addSubview(sessionTimeLabel)
        sessionTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sessionTimeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
            sessionTimeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15)
        ])

        // Total Time label (below session time, right-aligned)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        totalTimeLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        totalTimeLabel.textAlignment = .right
        totalTimeLabel.text = "Total  0:00"
        headerView.addSubview(totalTimeLabel)
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            totalTimeLabel.topAnchor.constraint(equalTo: sessionTimeLabel.bottomAnchor, constant: 3),
            totalTimeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15)
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
        lastSwappedPositions = nil
        swappedButtons = nil
        levelCompletionTriggered = false  // Reset flag for new level
        levelShieldEmoji = MatchGameViewController.shieldEmojiPool.randomElement() ?? "🛡️"

        // ...existing code...
        gridShapeMap = Array(repeating: Array(repeating: false, count: level.gridWidth), count: level.gridHeight)
        armorGrid = Array(repeating: Array(repeating: 0, count: level.gridWidth), count: level.gridHeight)
        armorOverlays = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        armorBorderViews = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        
        // Parse grid shape strings into boolean grid + armor values
        // Format: X = active tile, _ = inactive, digits after X = armor value
        // Example: "X5XX3X" -> col0: active armor=5, col1: active armor=0, col2: active armor=3, col3: active armor=0
        for (rowIndex, rowString) in level.gridShape.enumerated() {
            if rowIndex < gridShapeMap.count {
                var col = 0
                var charIndex = rowString.startIndex
                while charIndex < rowString.endIndex && col < level.gridWidth {
                    let char = rowString[charIndex]
                    if char == "X" {
                        gridShapeMap[rowIndex][col] = true
                        // Peek ahead for digits (armor value)
                        var numberStr = ""
                        var peekIndex = rowString.index(after: charIndex)
                        while peekIndex < rowString.endIndex && rowString[peekIndex].isNumber {
                            numberStr.append(rowString[peekIndex])
                            peekIndex = rowString.index(after: peekIndex)
                        }
                        if let armorValue = Int(numberStr) {
                            armorGrid[rowIndex][col] = armorValue
                        }
                        charIndex = peekIndex  // Skip past the digits
                        col += 1
                    } else if char == "_" {
                        gridShapeMap[rowIndex][col] = false
                        charIndex = rowString.index(after: charIndex)
                        col += 1
                    } else {
                        // Skip unexpected characters
                        charIndex = rowString.index(after: charIndex)
                    }
                }
            }
        }
        
        // Initialize empty grid
        gameGrid = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        gridButtons = Array(repeating: Array(repeating: nil, count: level.gridWidth), count: level.gridHeight)
        
        // Fill grid with non-matching pieces so no matches exist at start
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] {
                    let piece = generateNonMatchingPiece(row: row, col: col, level: level, avoidMatches: true)
                    gameGrid[row][col] = piece
                }
            }
        }

        updateUI()
        renderGrid()

        // Attempt to restore a mid-level snapshot (overrides the fresh grid above)
        if restoreMidLevelState(levelId: levelId) {
            renderGrid()         // rebuild buttons at correct positions
            updateGridDisplay()  // overwrite normal emoji icons with powerup icons where needed
            updateUI()
        }
        
        // Reset idle hint timer
        lastMoveTime = Date()
        resetIdleHintTimer()
    }
    
    private var lastDisplayedScore: Int = -1
    private var lastDisplayedMoves: Int = -1

    private func updateUI() {
        guard let level = currentLevel else { return }
        
        levelLabel.text = level.name
        levelNameLabel.text = level.name

        // Score pop when it increases
        let newScore = score
        if newScore != lastDisplayedScore {
            scoreLabel.text = "Score: \(newScore)"
            if newScore > lastDisplayedScore && lastDisplayedScore >= 0 {
                UIView.animate(withDuration: 0.1, animations: {
                    self.scoreLabel.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
                    self.scoreLabel.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.15) {
                        self.scoreLabel.transform = .identity
                        self.scoreLabel.textColor = .lightGray
                    }
                })
            }
            lastDisplayedScore = newScore
        }

        // Moves label — flash red when low
        let newMoves = max(0, movesRemaining)
        movesLabel.text = "Moves: \(newMoves)"
        if newMoves != lastDisplayedMoves {
            lastDisplayedMoves = newMoves
            if newMoves <= 3 && newMoves > 0 {
                // Urgent pulse: white → red → white
                UIView.animate(withDuration: 0.12, animations: {
                    self.movesLabel.textColor = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
                    self.movesLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.18) {
                        self.movesLabel.transform = .identity
                        self.movesLabel.textColor = newMoves == 1 ? UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1) : .lightGray
                    }
                })
            } else {
                movesLabel.textColor = .lightGray
            }
        }

        targetLabel.text = "Target: \(level.scoreTarget)"
        
        // Update shields counter
        let shieldsRemaining = armorGrid.flatMap { $0 }.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
        if shieldsRemaining > 0 {
            armorLabel.text = "Shields: \(shieldsRemaining)"
            armorLabel.isHidden = false
        } else {
            // Check if this level ever had armor
            let levelHasArmor = level.gridShape.contains { $0.contains(where: { $0.isNumber }) }
            if levelHasArmor {
                armorLabel.text = "Shields: 0"
                armorLabel.isHidden = false
            } else {
                armorLabel.isHidden = true
            }
        }
        
        // Check if target score is reached AND all armor cleared (only trigger once per level)
        let allArmorCleared = !armorGrid.contains(where: { $0.contains(where: { $0 > 0 }) })
        if score >= level.scoreTarget && allArmorCleared && !levelCompletionTriggered {
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
            
            // Level beaten — reset retry count for this level
            retryCount = 0
            retryLevelId = -1
            
            // Disable interactions while animating
            isAnimating = true
            
            // Show completion animation
            showLevelCompleteAnimation {
                // After animation, load next level
                self.clearMidLevelState(levelId: level.id)  // level done — wipe snapshot
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
        
        // Remove any leftover animation sublayers (e.g. lightning CAShapeLayers)
        // but preserve named layers (e.g. "ballTrail") that belong to in-flight animations
        gridContainer.layer.sublayers?.removeAll(where: { layer in
            guard let shapeLayer = layer as? CAShapeLayer else { return false }
            return shapeLayer.name == nil || shapeLayer.name?.isEmpty == true
        })
        
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if let button = gridButtons[row][col] {
                    // Remove all in-flight animations (both UIView and CA)
                    button.layer.removeAllAnimations()
                    // Reset the view-level transform (used for gravity translation)
                    button.transform = .identity
                    // Reset alpha at both UIView and CALayer level
                    button.alpha = 1.0
                    button.layer.opacity = 1.0
                }
            }
        }
    }
    
    private func showLevelCompleteAnimation(completion: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "Level Complete!",
            message: "Score: \(score)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Next Level", style: .default) { _ in
            completion()
        })

        alert.addAction(UIAlertAction(title: "Exit", style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            self.levelCompleteCompletion = nil
            self.isAnimating = false
            // Advance to next level before saving so the player resumes there on reopen
            let completedId = self.currentLevelId
            self.clearMidLevelState(levelId: completedId)
            if let config = self.gameConfig,
               config.levels.contains(where: { $0.id == completedId + 1 }) {
                self.currentLevelId = completedId + 1
                self.score = 0
            }
            self.saveGameState()
            self.exitGame()
        })

        present(alert, animated: true)
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
        
        // Clear existing grid completely (subviews AND any leftover animation sublayers)
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        gridContainer.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
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

                    // If this piece is a powerup, show the powerup icon directly
                    let powerupFontSize = max(16, min(40, 420 / CGFloat(max(level.gridWidth, level.gridHeight))))
                    if piece.type != .normal {
                        let powerupEmoji: String
                        switch piece.type {
                        case .verticalArrow:   powerupEmoji = "↕️"
                        case .horizontalArrow: powerupEmoji = "↔️"
                        case .bomb:            powerupEmoji = "💣"
                        case .flame:           powerupEmoji = "🔥"
                        case .rocket:          powerupEmoji = "🌟"
                        case .ball:            powerupEmoji = GamePiece.ballEmojis[piece.ballEmojiIndex]
                        default:               powerupEmoji = "?"
                        }
                        button.setTitle(powerupEmoji, for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                    } else
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
        
        // Add static armor overlay views on top of the grid (in gridContainer, not on buttons)
        // These stay fixed at their grid position even when buttons transform during gravity
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard armorGrid[row][col] >= 1, let button = gridButtons[row][col] else { continue }
                
                // Create border overlay view
                let borderView = UIView()
                borderView.backgroundColor = .clear
                borderView.layer.borderColor = UIColor.cyan.withAlphaComponent(0.7).cgColor
                borderView.layer.borderWidth = 2
                borderView.layer.cornerRadius = 8
                borderView.isUserInteractionEnabled = false
                borderView.translatesAutoresizingMaskIntoConstraints = false
                gridContainer.addSubview(borderView)
                
                // Constrain to match the button's position in the grid
                NSLayoutConstraint.activate([
                    borderView.topAnchor.constraint(equalTo: button.topAnchor),
                    borderView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                    borderView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                    borderView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
                ])
                armorBorderViews[row][col] = borderView
                
                // Add number label to the border overlay view
                let armorLabel = UILabel()
                armorLabel.text = "\(armorGrid[row][col])"
                armorLabel.font = UIFont.boldSystemFont(ofSize: 12)
                armorLabel.adjustsFontSizeToFitWidth = true
                armorLabel.minimumScaleFactor = 0.5
                armorLabel.textColor = .white
                armorLabel.textAlignment = .center
                armorLabel.layer.shadowColor = UIColor.black.cgColor
                armorLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
                armorLabel.layer.shadowOpacity = 1.0
                armorLabel.layer.shadowRadius = 2
                armorLabel.translatesAutoresizingMaskIntoConstraints = false
                borderView.addSubview(armorLabel)
                NSLayoutConstraint.activate([
                    armorLabel.trailingAnchor.constraint(equalTo: borderView.trailingAnchor, constant: -2),
                    armorLabel.bottomAnchor.constraint(equalTo: borderView.bottomAnchor, constant: -1)
                ])
                armorOverlays[row][col] = armorLabel
            }
        }
        
        // Add overlay views on top of blank (inactive) grid positions so pieces
        // sliding through during gravity animations are hidden behind them
        blankTileOverlays.forEach { $0.removeFromSuperview() }
        blankTileOverlays.removeAll()
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard !gridShapeMap[row][col] else { continue }
                // Get the blank button at this position from the row stack
                let rowStack = gridStackView.arrangedSubviews[row]
                guard let stack = rowStack as? UIStackView else { continue }
                let button = stack.arrangedSubviews[col]
                
                let overlay = UIView()
                overlay.backgroundColor = darkBg
                overlay.isUserInteractionEnabled = false
                overlay.translatesAutoresizingMaskIntoConstraints = false
                gridContainer.addSubview(overlay)
                
                // Match the blank button's position, with slight expansion to cover
                // the spacing gaps between tiles
                NSLayoutConstraint.activate([
                    overlay.topAnchor.constraint(equalTo: button.topAnchor, constant: -1),
                    overlay.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 1),
                    overlay.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: -1),
                    overlay.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 1)
                ])
                blankTileOverlays.append(overlay)
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
            cascadeDepth = 0  // Reset cascade depth for direct-tap activation
            
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
                shootFlamesHorizontally(row: row, arrowCol: col, columns: 0..<level.gridWidth) {}
                
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
                
            case .ball:
                // Ball tapped directly: animate bouncing ball, handles its own clearing
                animateBouncingBall(fromRow: row, fromCol: col) { [weak self] in
                    self?.isAnimating = false
                    if self?.movesRemaining ?? 0 <= 0 {
                        self?.levelFailed()
                    }
                }
                return  // animateBouncingBall handles everything
                
            case .normal:
                isAnimating = false
                return
            }
            
            // Choose animation based on powerup type
            if piece.type == .flame {
                // Flame: shoot lines at matching tiles
                self.shootFlamesAtTiles(fromRow: row, fromCol: col, targetTiles: clearedTiles) { [weak self] in
                    self?.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                        for posString in clearedTiles {
                            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                            if parts.count == 2 {
                                self?.hitTile(row: parts[0], col: parts[1])
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
            } else if piece.type == .bomb {
                // Bomb: yellow border highlight, then pulse + screen shake, then clear
                showPowerupBorderHighlight(clearedTiles) { [weak self] in
                    guard let self = self else { return }
                    var bombButtons: [UIButton] = []
                    for posString in clearedTiles {
                        let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                        if parts.count == 2, let btn = self.gridButtons[parts[0]][parts[1]] {
                            bombButtons.append(btn)
                        }
                    }
                    self.animateBombExplosion(centerRow: row, centerCol: col, affectedButtons: bombButtons) { [weak self] in
                        for posString in clearedTiles {
                            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                            if parts.count == 2 {
                                self?.hitTile(row: parts[0], col: parts[1])
                            }
                        }
                        self?.updateUI()
                        self?.updateGridDisplay()
                        if !cascadingPowerups.isEmpty {
                            self?.activateCascadingPowerups(cascadingPowerups)
                        } else {
                            self?.applyGravity()
                        }
                        // NOTE: Do NOT set isAnimating = false here — the cascade/gravity chain
                        // is still running asynchronously. checkForMatches' no-match branch
                        // will reset isAnimating once the board fully settles.
                    }
                }
            } else {
                // Arrows and other powerups: yellow border highlight then clear
                showPowerupBorderHighlight(clearedTiles) { [weak self] in
                    for posString in clearedTiles {
                        let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                        if parts.count == 2 {
                            self?.hitTile(row: parts[0], col: parts[1])
                        }
                    }
                    self?.updateUI()
                    self?.updateGridDisplay()
                    if !cascadingPowerups.isEmpty {
                        self?.activateCascadingPowerups(cascadingPowerups)
                    } else {
                        self?.applyGravity()
                    }
                    // NOTE: Do NOT set isAnimating = false here — the cascade/gravity chain
                    // is still running asynchronously. checkForMatches' no-match branch
                    // will reset isAnimating once the board fully settles.
                }
            }
            return
        }
        
        if let selected = selectedPiece {
            // Try to swap — block if either tile is armored
            if areAdjacent(selected.row, selected.col, row, col) {
                let selectedArmored = armorGrid[selected.row][selected.col] > 0
                let targetArmored  = armorGrid[row][col] > 0
                if selectedArmored || targetArmored {
                    // Can't swap armored tiles — shake the armored one and deselect
                    let shakeRow = selectedArmored ? selected.row : row
                    let shakeCol = selectedArmored ? selected.col : col
                    if let btn = gridButtons[shakeRow][shakeCol] { shakeTile(btn) }
                    selectedPiece = nil
                    updateGridDisplay()
                } else {
                    swapPieces(selected.row, selected.col, row, col)
                    selectedPiece = nil
                }
            } else {
                // Select new piece — skip if armored
                if armorGrid[row][col] > 0 {
                    if let btn = gridButtons[row][col] { shakeTile(btn) }
                    selectedPiece = nil
                    updateGridDisplay()
                } else {
                    selectedPiece = (row, col)
                    updateGridDisplay()
                }
            }
        } else {
            // Select first piece — block armored tiles
            if armorGrid[row][col] > 0 {
                if let btn = gridButtons[row][col] { shakeTile(btn) }
            } else {
                selectedPiece = (row, col)
                updateGridDisplay()
                // Ripple from selected tile
                if let btn = gridButtons[row][col] { animateTileSelectionRipple(from: btn) }
            }
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
            if !isAnimating {
                updateGridDisplay()
            }
            
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
                    if !isAnimating {
                        updateGridDisplay()
                    }
                }
            }
            
        case .ended, .cancelled:
            if !isAnimating, let startPiece = dragStartPiece, let targetPiece = dragTargetPiece {
                if areAdjacent(startPiece.row, startPiece.col, targetPiece.row, targetPiece.col) {
                    // Block swap if either tile is armored
                    let startArmored  = armorGrid[startPiece.row][startPiece.col] > 0
                    let targetArmored = armorGrid[targetPiece.row][targetPiece.col] > 0
                    if startArmored || targetArmored {
                        let shakeRow = startArmored ? startPiece.row : targetPiece.row
                        let shakeCol = startArmored ? startPiece.col : targetPiece.col
                        if let btn = gridButtons[shakeRow][shakeCol] { shakeTile(btn) }
                    } else {
                        swapPieces(startPiece.row, startPiece.col, targetPiece.row, targetPiece.col)
                    }
                }
            }
            dragStartPiece = nil
            dragTargetPiece = nil
            selectedPiece = nil
            if !isAnimating {
                updateGridDisplay()
            }
            
        default:
            break
        }
    }
    
    private func swapPieces(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) {
        isAnimating = true
        
        // Reset idle timer on move
        lastMoveTime = Date()
        resetIdleHintTimer()
        cascadeDepth = 0  // Reset cascade depth counter for this new move
        
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
            // ALL powerup-to-powerup swaps: piece1 slides onto piece2 with spring bounce
            button1.layer.zPosition = 100  // Raise BEFORE animation so it's on top from frame 1
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8, options: [], animations: {
                button1.transform = CGAffineTransform(translationX: deltaX, y: deltaY)
            }, completion: { [weak self] _ in
                button1.layer.zPosition = 0
                self?.swappedButtons = (button1, button2)
            })
        } else {
            // Normal swap: both buttons swap positions with spring bounce
            button1.layer.zPosition = 100  // Raise BEFORE animation so it's on top from frame 1
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8, options: [], animations: {
                button1.transform = CGAffineTransform(translationX: deltaX, y: deltaY)
                button2.transform = CGAffineTransform(translationX: -deltaX, y: -deltaY)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.activatePowerUps(r1, c1, r2, c2, type1: originalType1, type2: originalType2)
                }
            } else {
                // Check for matches after swap animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
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

            // --- Ball + arrow ---
            case (.ball, .horizontalArrow), (.horizontalArrow, .ball):
                handleBallArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2, isHorizontal: true)
            case (.ball, .verticalArrow), (.verticalArrow, .ball):
                handleBallArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2, isHorizontal: false)

            // --- Ball + bomb: Cannonball — bounces with 3x3 explosions ---
            case (.ball, .bomb), (.bomb, .ball):
                handleBallBombCombo(r1: r1, c1: c1, r2: r2, c2: c2)

            // --- Ball + ball: Super-ball — double bounces, hits every row ---
            case (.ball, .ball):
                handleBallBallCombo(r1: r1, c1: c1, r2: r2, c2: c2)

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
        flameSource: (row: Int, col: Int)? = nil,
        bombShake: Bool = false
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

        // Bomb screen shake
        if bombShake {
            let shakeAnim = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shakeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shakeAnim.duration = 0.35
            shakeAnim.values = [-6, 6, -5, 5, -3, 3, 0]
            gridContainer.layer.add(shakeAnim, forKey: "bombShake")
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

    /// Attempts to clear a tile. If armored, decrements armor instead.
    /// Returns true if the tile was actually removed, false if armor absorbed the hit.
    /// - Normal tile on armor: armor decrements by 1, tile stays (armor absorbs the hit).
    /// - Powerup tile on armor: powerup is removed, armor decrements by 1 (powerups don't get protected).
    /// - Any tile, no armor: tile is removed.
    @discardableResult
    private func hitTile(row: Int, col: Int) -> Bool {
        guard let piece = gameGrid[row][col] else { return false }

        if armorGrid[row][col] > 0 {
            if piece.type == .normal {
                // Armor absorbs the hit — tile survives, armor decrements
                armorGrid[row][col] -= 1
                score += 1
                if let button = gridButtons[row][col] {
                    shakeTile(button)
                }
                animateShieldChip(row: row, col: col)
                updateArmorOverlay(row: row, col: col)
                return false  // Tile survives
            } else {
                // Powerup on armored cell — remove the powerup, decrement armor by 1
                armorGrid[row][col] -= 1
                animateShieldChip(row: row, col: col)
                updateArmorOverlay(row: row, col: col)
                score += 1
                gameGrid[row][col] = nil
                return true
            }
        }

        score += 1
        gameGrid[row][col] = nil
        return true
    }

    /// Brief horizontal shake animation for armor hit feedback.
    private func shakeTile(_ button: UIButton) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.3
        animation.values = [-4, 4, -3, 3, -2, 2, 0]
        button.layer.add(animation, forKey: "shake")
    }
    
    /// Checks if the normal tile at (row, col) participates in a match pattern that would create a powerup.
    /// Returns the powerup type if so, nil otherwise. Uses the same logic as checkForMatches.
    private func detectPowerupAtPosition(row: Int, col: Int) -> PieceType? {
        guard let level = currentLevel else { return nil }
        guard row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth else { return nil }
        guard gridShapeMap[row][col], let piece = gameGrid[row][col], piece.type == .normal else { return nil }
        
        // Count horizontal run containing this position
        var hLeft = col
        while hLeft > 0 && gridShapeMap[row][hLeft - 1],
              let p = gameGrid[row][hLeft - 1], p.type == .normal, piece.matches(p) {
            hLeft -= 1
        }
        var hRight = col
        while hRight < level.gridWidth - 1 && gridShapeMap[row][hRight + 1],
              let p = gameGrid[row][hRight + 1], p.type == .normal, piece.matches(p) {
            hRight += 1
        }
        let hCount = hRight - hLeft + 1
        
        // Count vertical run containing this position
        var vTop = row
        while vTop > 0 && gridShapeMap[vTop - 1][col],
              let p = gameGrid[vTop - 1][col], p.type == .normal, piece.matches(p) {
            vTop -= 1
        }
        var vBottom = row
        while vBottom < level.gridHeight - 1 && gridShapeMap[vBottom + 1][col],
              let p = gameGrid[vBottom + 1][col], p.type == .normal, piece.matches(p) {
            vBottom += 1
        }
        let vCount = vBottom - vTop + 1
        
        // 5+ in a line → flame
        if hCount >= 5 || vCount >= 5 {
            return .flame
        }
        
        // T-shape vs L-shape: both require 3+ in one direction AND 2+ perpendicular.
        // T-shape: intersection is in the MIDDLE of the longer run (not at an end)
        // L-shape: intersection is at the END/corner of a run
        if hCount >= 3 && vCount >= 3 {
            let hIsMiddle = (col > hLeft && col < hRight)  // not at either end of horizontal run
            let vIsMiddle = (row > vTop && row < vBottom)   // not at either end of vertical run
            if hIsMiddle || vIsMiddle {
                return .ball  // T-shape
            }
            return .rocket  // L-shape (corner intersection)
        }
        
        // T-shape can also be: 3+ in one direction, 2 perpendicular from middle
        if hCount >= 3 && vCount >= 2 {
            let hIsMiddle = (col > hLeft && col < hRight)
            if hIsMiddle {
                return .ball
            }
        }
        if vCount >= 3 && hCount >= 2 {
            let vIsMiddle = (row > vTop && row < vBottom)
            if vIsMiddle {
                return .ball
            }
        }
        
        // 4 in a line → arrow
        if hCount >= 4 {
            return .horizontalArrow
        }
        if vCount >= 4 {
            return .verticalArrow
        }
        
        // Check 2x2 bomb: see if this position is part of a 2x2 of matching tiles
        for dr in 0...1 {
            for dc in 0...1 {
                let topRow = row - dr
                let leftCol = col - dc
                guard topRow >= 0 && topRow + 1 < level.gridHeight &&
                      leftCol >= 0 && leftCol + 1 < level.gridWidth else { continue }
                guard gridShapeMap[topRow][leftCol] && gridShapeMap[topRow][leftCol + 1] &&
                      gridShapeMap[topRow + 1][leftCol] && gridShapeMap[topRow + 1][leftCol + 1] else { continue }
                
                var allMatch = true
                for r in topRow...topRow + 1 {
                    for c in leftCol...leftCol + 1 {
                        if r == row && c == col { continue }
                        guard let p = gameGrid[r][c], p.type == .normal, piece.matches(p) else {
                            allMatch = false
                            break
                        }
                    }
                    if !allMatch { break }
                }
                if allMatch { return .bomb }
            }
        }
        
        return nil
    }
    
    /// Bomb explosion visual: pulses affected tiles outward then clears them, with a brief screen shake.
    private func animateBombExplosion(centerRow: Int, centerCol: Int, affectedButtons: [UIButton], completion: @escaping () -> Void) {
        guard currentLevel != nil else { completion(); return }
        
        // Screen shake on gridContainer
        let shakeAnim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shakeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shakeAnim.duration = 0.35
        shakeAnim.values = [-6, 6, -5, 5, -3, 3, 0]
        gridContainer.layer.add(shakeAnim, forKey: "bombShake")
        
        // Pulse each affected button using CAAnimations (not UIView.animate with transform)
        // so that scale effects don't conflict with gravity's use of button.transform
        let totalDuration: TimeInterval = 0.27  // 0.12 pop + 0.15 shrink
        for button in affectedButtons {
            // Pop-then-shrink scale animation
            let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnim.values = [1.0, 1.3, 0.1]
            scaleAnim.keyTimes = [0, 0.44, 1.0]  // 0.12/0.27 ≈ 0.44
            scaleAnim.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn)
            ]
            scaleAnim.duration = totalDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            button.layer.add(scaleAnim, forKey: "bombPop")
            
            // Fade out
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 1.0
            fadeAnim.toValue = 0.0
            fadeAnim.beginTime = CACurrentMediaTime() + 0.12
            fadeAnim.duration = 0.15
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            button.layer.add(fadeAnim, forKey: "bombFade")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.03) {
            // Clean up CA animations and restore visual state
            for button in affectedButtons {
                button.layer.removeAnimation(forKey: "bombPop")
                button.layer.removeAnimation(forKey: "bombFade")
                button.layer.opacity = 1.0
            }
            completion()
        }
    }
    
    /// Returns the center point of a grid cell in gridContainer coordinates.
    private func gridCellCenter(row: Int, col: Int) -> CGPoint {
        guard let level = currentLevel else { return .zero }
        let cellWidth = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        return CGPoint(
            x: CGFloat(col) * cellWidth + cellWidth / 2,
            y: CGFloat(row) * cellHeight + cellHeight / 2
        )
    }

    /// Updates the armor overlay label and border for a specific cell.
    private func updateArmorOverlay(row: Int, col: Int) {
        guard row < armorOverlays.count && col < armorOverlays[row].count else { return }
        guard row < armorBorderViews.count && col < armorBorderViews[row].count else { return }

        if armorGrid[row][col] >= 1 {
            // Show/update the label and border
            if let label = armorOverlays[row][col] {
                label.text = "\(armorGrid[row][col])"
                label.isHidden = false
            }
            armorBorderViews[row][col]?.isHidden = false
        } else {
            // Armor cleared — hide border overlay and label
            armorOverlays[row][col]?.isHidden = true
            armorBorderViews[row][col]?.isHidden = true
        }
    }

    /// Fires ice/crystal chip particles off a shielded tile when it takes a hit.
    private func animateShieldChip(row: Int, col: Int) {
        guard let button = gridButtons[row][col] else { return }
        // Convert button center to self.view coordinates so chips render above all grid content
        // and are never swept by grid rebuilds or gravity passes
        let originInView = view.convert(button.center, from: button.superview)

        // Colour palette varies by shield type for visual consistency
        let colors: [UIColor]
        switch levelShieldEmoji {
        case "🔒":
            colors = [.systemYellow, .systemOrange, UIColor(white: 0.9, alpha: 1), .systemBrown]
        case "💠":
            colors = [.cyan, .systemTeal, UIColor(white: 0.95, alpha: 1), .systemBlue]
        default: // 🛡️
            colors = [.systemBlue, .cyan, UIColor(white: 0.85, alpha: 1), .systemIndigo]
        }

        let particleCount = Int.random(in: 5...9)
        for i in 0..<particleCount {
            let size = CGFloat.random(in: 2...5)
            let chip = UIView(frame: CGRect(x: originInView.x - size/2, y: originInView.y - size/2,
                                           width: size, height: size))
            chip.backgroundColor = colors.randomElement()!
            chip.layer.cornerRadius = i % 2 == 0 ? 1 : size / 2
            chip.alpha = 1.0
            chip.isUserInteractionEnabled = false
            view.addSubview(chip)

            // Parabolic arc: shoot out at an angle, gravity pulls down
            // Each chip gets a random horizontal spread and upward launch velocity
            let dx     = CGFloat.random(in: -50...50)
            let launchY = CGFloat.random(in: -60 ... -25)   // upward initial kick
            let landY   = CGFloat.random(in: 120...220)     // final resting point below origin
            let peakX   = originInView.x + dx * 0.4         // peak is partway through horizontal travel
            let peakY   = originInView.y + launchY          // peak is at max upward height
            let endX    = originInView.x + dx
            let endY    = originInView.y + landY

            // Build quadratic Bezier path: start → peak → end
            let path = CGMutablePath()
            path.move(to: originInView)
            path.addQuadCurve(to: CGPoint(x: endX, y: endY),
                              control: CGPoint(x: peakX, y: peakY))

            let posAnim = CAKeyframeAnimation(keyPath: "position")
            posAnim.path = path
            posAnim.duration = Double.random(in: 1.1...1.6)
            posAnim.beginTime = CACurrentMediaTime() + Double.random(in: 0...0.07)
            posAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)

            // Fade — hold full opacity until near the end, then fade
            let fadeAnim = CAKeyframeAnimation(keyPath: "opacity")
            fadeAnim.values   = [1.0, 1.0, 0.0]
            fadeAnim.keyTimes = [0.0, 0.65, 1.0]
            fadeAnim.duration  = posAnim.duration
            fadeAnim.beginTime = posAnim.beginTime
            fadeAnim.fillMode  = .forwards
            fadeAnim.isRemovedOnCompletion = false

            // Spin as it flies
            let spinAnim = CABasicAnimation(keyPath: "transform.rotation.z")
            spinAnim.byValue  = CGFloat.random(in: -.pi*3 ... .pi*3)
            spinAnim.duration = posAnim.duration
            spinAnim.beginTime = posAnim.beginTime
            spinAnim.fillMode  = .forwards
            spinAnim.isRemovedOnCompletion = false

            chip.layer.add(posAnim, forKey: "chipPos")
            chip.layer.add(fadeAnim, forKey: "chipFade")
            chip.layer.add(spinAnim, forKey: "chipSpin")

            DispatchQueue.main.asyncAfter(deadline: .now() + posAnim.beginTime - CACurrentMediaTime() + posAnim.duration + 0.05) {
                chip.removeFromSuperview()
            }
        }
    }

    /// Generates a random piece for the given cell that avoids creating an immediate match.
    /// Checks left-2 and above-2 neighbors. If the grid already lacks valid moves,
    /// skips the anti-match logic so new matches can break the deadlock.
    private func generateNonMatchingPiece(row: Int, col: Int, level: MatchGameLevel, avoidMatches: Bool) -> GamePiece {
        let maxAttempts = avoidMatches ? 10 : 1
        
        for attempt in 0..<maxAttempts {
            let randomItemIndex = Int.random(in: 0..<level.items.count)
            let randomColorIndex = Int.random(in: 0..<level.colors.count)
            let itemId = level.items[randomItemIndex].id
            
            // On last attempt, accept whatever we got
            if !avoidMatches || attempt == maxAttempts - 1 {
                return GamePiece(itemId: itemId, colorIndex: randomColorIndex, row: row, col: col, type: .normal)
            }
            
            var wouldMatch = false
            
            // Check horizontal match (2 to the left)
            if col >= 2,
               gridShapeMap[row][col - 1], gridShapeMap[row][col - 2],
               let p1 = gameGrid[row][col - 1], p1.type == .normal,
               let p2 = gameGrid[row][col - 2], p2.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            // Check vertical match (2 above)
            if row >= 2,
               gridShapeMap[row - 1][col], gridShapeMap[row - 2][col],
               let p1 = gameGrid[row - 1][col], p1.type == .normal,
               let p2 = gameGrid[row - 2][col], p2.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            // Check vertical match (2 below - pieces already placed below during gravity)
            if row + 2 < level.gridHeight,
               gridShapeMap[row + 1][col], gridShapeMap[row + 2][col],
               let p1 = gameGrid[row + 1][col], p1.type == .normal,
               let p2 = gameGrid[row + 2][col], p2.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            // Check vertical match (1 above + 1 below - sandwiched)
            if row >= 1 && row + 1 < level.gridHeight,
               gridShapeMap[row - 1][col], gridShapeMap[row + 1][col],
               let p1 = gameGrid[row - 1][col], p1.type == .normal,
               let p2 = gameGrid[row + 1][col], p2.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            // Check horizontal match (2 to the right)
            if col + 2 < level.gridWidth,
               gridShapeMap[row][col + 1], gridShapeMap[row][col + 2],
               let p1 = gameGrid[row][col + 1], p1.type == .normal,
               let p2 = gameGrid[row][col + 2], p2.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            // Check horizontal match (1 left + 1 right - sandwiched)
            if col >= 1 && col + 1 < level.gridWidth,
               gridShapeMap[row][col - 1], gridShapeMap[row][col + 1],
               let p1 = gameGrid[row][col - 1], p1.type == .normal,
               let p2 = gameGrid[row][col + 1], p2.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            // Check 2x2 bomb pattern: (row,col) is the bottom-right corner.
            // At fill time, only cells above and to the left exist, so this is the
            // only 2x2 we can pre-empt.
            if row >= 1 && col >= 1,
               gridShapeMap[row - 1][col - 1], gridShapeMap[row - 1][col], gridShapeMap[row][col - 1],
               let p1 = gameGrid[row - 1][col - 1], p1.type == .normal,
               let p2 = gameGrid[row - 1][col],     p2.type == .normal,
               let p3 = gameGrid[row][col - 1],     p3.type == .normal,
               p1.itemId == itemId && p1.colorIndex == randomColorIndex &&
               p2.itemId == itemId && p2.colorIndex == randomColorIndex &&
               p3.itemId == itemId && p3.colorIndex == randomColorIndex {
                wouldMatch = true
            }
            
            if !wouldMatch {
                return GamePiece(itemId: itemId, colorIndex: randomColorIndex, row: row, col: col, type: .normal)
            }
        }
        
        // Fallback (shouldn't reach here due to last-attempt acceptance above)
        let randomItemIndex = Int.random(in: 0..<level.items.count)
        let randomColorIndex = Int.random(in: 0..<level.colors.count)
        return GamePiece(itemId: level.items[randomItemIndex].id, colorIndex: randomColorIndex, row: row, col: col, type: .normal)
    }

    /// Clears tiles from the grid, awards score, then activates cascading powerups or applies gravity.
    private func clearTilesAndCascade(_ clearedTiles: Set<String>, cascadingPowerups: [(row: Int, col: Int, type: PieceType)]) {
        for posString in clearedTiles {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                hitTile(row: parts[0], col: parts[1])
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

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true,
            bombShake: true
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

        // Fire flame animations for both rows and both columns
        shootFlamesHorizontally(row: r1, arrowCol: c1, columns: 0..<level.gridWidth) {}
        shootFlamesHorizontally(row: r2, arrowCol: c2, columns: 0..<level.gridWidth) {}
        shootFlamesVertically(column: c1, arrowRow: r1, rows: 0..<level.gridHeight) {}
        shootFlamesVertically(column: c2, arrowRow: r2, rows: 0..<level.gridHeight) {}

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

        //let direction = isHorizontal ? "horizontal" : "vertical"

        // Fire flame animations for the 3 rows or 3 columns
        if isHorizontal {
            for dr in -1...1 {
                let targetRow = r2 + dr
                if targetRow >= 0 && targetRow < level.gridHeight {
                    shootFlamesHorizontally(row: targetRow, arrowCol: c2, columns: 0..<level.gridWidth) {}
                }
            }
        } else {
            for dc in -1...1 {
                let targetCol = c2 + dc
                if targetCol >= 0 && targetCol < level.gridWidth {
                    shootFlamesVertically(column: targetCol, arrowRow: r2, rows: 0..<level.gridHeight) {}
                }
            }
        }

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true,
            bombShake: true
        )
    }

    /// Two horizontal arrows: Clear an "X" (both diagonals) from the swap point (r2, c2).
    private func handleTwoHorizontalArrows(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Clear all 4 diagonals from (r2, c2)
        let maxSteps = max(level.gridHeight, level.gridWidth)
        let diagonalDeltas = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        for (dr, dc) in diagonalDeltas {
            for step in 1...maxSteps {
                let nr = r2 + dr * step
                let nc = c2 + dc * step
                guard nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth else { break }
                if gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                    clearedTiles.insert("\(nr),\(nc)")
                }
            }
        }
        // Also clear the center tile itself
        if gridShapeMap[r2][c2] && gameGrid[r2][c2] != nil {
            clearedTiles.insert("\(r2),\(c2)")
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        // Fire diagonal beam animations
        shootFlamesDiagonally(centerRow: r2, centerCol: c2) {}

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Two vertical arrows: Clear an "X" (both diagonals) from the swap point (r2, c2).
    private func handleTwoVerticalArrows(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        var clearedTiles: Set<String> = []

        // Clear all 4 diagonals from (r2, c2)
        let maxSteps = max(level.gridHeight, level.gridWidth)
        let diagonalDeltas = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        for (dr, dc) in diagonalDeltas {
            for step in 1...maxSteps {
                let nr = r2 + dr * step
                let nc = c2 + dc * step
                guard nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth else { break }
                if gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                    clearedTiles.insert("\(nr),\(nc)")
                }
            }
        }
        // Also clear the center tile itself
        if gridShapeMap[r2][c2] && gameGrid[r2][c2] != nil {
            clearedTiles.insert("\(r2),\(c2)")
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        // Fire diagonal beam animations
        shootFlamesDiagonally(centerRow: r2, centerCol: c2) {}

        finalizePowerupCombo(
            clearedTiles: clearedTiles,
            cascadingPowerups: cascadingPowerups,
            decrementMoves: true
        )
    }

    /// Ball + Arrow combo: Fire the arrow first (clear row or column), then animate the bouncing ball.
    /// Both effects originate from r2,c2 (the combined swap position in a powerup+powerup swap).
    private func handleBallArrowCombo(r1: Int, c1: Int, r2: Int, c2: Int, isHorizontal: Bool) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Reset swapped button transforms
        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }

        // Collect arrow tiles to clear (the entire row or column at r2,c2, excluding r2,c2 itself so ball stays)
        var arrowClearedTiles: Set<String> = []
        if isHorizontal {
            for col in 0..<level.gridWidth {
                guard !(col == c2) else { continue }
                if gridShapeMap[r2][col] && gameGrid[r2][col] != nil {
                    arrowClearedTiles.insert("\(r2),\(col)")
                }
            }
            shootFlamesHorizontally(row: r2, arrowCol: c2, columns: 0..<level.gridWidth) {}
        } else {
            for row in 0..<level.gridHeight {
                guard !(row == r2) else { continue }
                if gridShapeMap[row][c2] && gameGrid[row][c2] != nil {
                    arrowClearedTiles.insert("\(row),\(c2)")
                }
            }
            shootFlamesVertically(column: c2, arrowRow: r2, rows: 0..<level.gridHeight) {}
        }

        // Collect cascading powerups from the arrow's cleared tiles (not the ball position)
        let arrowCascades = collectCascadingPowerups(
            in: arrowClearedTiles,
            excludePositions: [(row: r2, col: c2)]
        )

        // Clear arrow tiles from the grid immediately so ball doesn't bounce on them
        for tileKey in arrowClearedTiles {
            let parts = tileKey.split(separator: ",").map { Int($0) ?? 0 }
            if parts.count == 2 {
                let _ = hitTile(row: parts[0], col: parts[1])
            }
        }

        updateGridDisplay()
        movesRemaining -= 1
        updateUI()

        // Now animate the bouncing ball from r2,c2, merging any arrow cascades at the end
        animateBouncingBall(fromRow: r2, fromCol: c2, extraCascades: arrowCascades) { [weak self] in
            self?.isAnimating = false
            if self?.movesRemaining ?? 0 <= 0 {
                self?.levelFailed()
            }
        }
    }

    /// Ball + Bomb combo: "Cannonball" — the ball bounces through the grid, triggering a 3x3 bomb
    /// explosion at every landing tile.
    private func handleBallBombCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }
        updateGridDisplay()
        movesRemaining -= 1
        updateUI()

        animateBouncingBall(fromRow: r2, fromCol: c2, bombExplosionRadius: 1) { [weak self] in
            self?.isAnimating = false
            if self?.movesRemaining ?? 0 <= 0 {
                self?.levelFailed()
            }
        }
    }

    /// Ball + Ball combo: "Super Ball" — two balls merge into one giant ball that hits TWO tiles in
    /// every row as it bounces down, covering the whole grid.
    private func handleBallBallCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
        guard let level = currentLevel else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }

        // Collect every tile on the board as a target (super ball clears entire board)
        var allTiles: Set<String> = []
        var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    allTiles.insert("\(row),\(col)")
                    if piece.type != .normal {
                        cascadingPowerups.append((row: row, col: col, type: piece.type))
                    }
                }
            }
        }

        updateGridDisplay()
        movesRemaining -= 1
        updateUI()

        // Show a big border highlight then animate two balls bouncing simultaneously
        showPowerupBorderHighlight(allTiles) { [weak self] in
            guard let self = self else { return }

            // Clear all tiles from data
            for key in allTiles {
                let parts = key.split(separator: ",").map { Int($0) ?? 0 }
                if parts.count == 2 { let _ = self.hitTile(row: parts[0], col: parts[1]) }
            }
            self.updateGridDisplay()

            // Animate two balls from the two swap positions
            var done = 0
            let finish: () -> Void = { [weak self] in
                done += 1
                guard done == 2, let self = self else { return }
                self.isAnimating = false
                if !cascadingPowerups.isEmpty {
                    self.activateCascadingPowerups(cascadingPowerups)
                } else {
                    self.applyGravity()
                }
                if self.movesRemaining <= 0 { self.levelFailed() }
            }

            self.animateBouncingBall(fromRow: r1, fromCol: c1, managedExternally: false, completion: { finish() })
            self.animateBouncingBall(fromRow: r2, fromCol: c2, managedExternally: false, completion: { finish() })
        }
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
        let spawnCount = min(Int.random(in: 3...5), normalTilePositions.count)
        let shuffled = normalTilePositions.shuffled()
        let spawnPositions = Array(shuffled.prefix(spawnCount))

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
                    if otherType == .ball {
                        piece.ballEmojiIndex = Int.random(in: 0..<GamePiece.ballEmojis.count)
                    }
                    cascadingPowerups.append((row: pos.row, col: pos.col, type: otherType))
                }
            }

            // Clear the source combo tiles
            for posString in clearedTiles {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                if parts.count == 2 {
                    self.hitTile(row: parts[0], col: parts[1])
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

    /// Rocket + another powerup type: dispatches to Lightning Surge (arrow) or Lightning Storm (bomb).
    private func handleRocketPowerupCombo(r1: Int, c1: Int, r2: Int, c2: Int, otherType: PieceType) {
        switch otherType {
        case .horizontalArrow:
            handleRocketArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2, isHorizontal: true)
        case .verticalArrow:
            handleRocketArrowCombo(r1: r1, c1: c1, r2: r2, c2: c2, isHorizontal: false)
        case .bomb:
            handleRocketBombCombo(r1: r1, c1: c1, r2: r2, c2: c2)
        default:
            // Fallback for rocket+flame or other — use flame combo path
            handleFlamePowerupCombo(r1: r1, c1: c1, r2: r2, c2: c2, otherType: otherType)
        }
    }
    
    /// Rocket + Arrow: "Lightning Surge" — lightning traces the arrow's row/col,
    /// then forks perpendicularly at every cell, clearing everything in the cross pattern.
    private func handleRocketArrowCombo(r1: Int, c1: Int, r2: Int, c2: Int, isHorizontal: Bool) {
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

        // Collect ALL tiles on the board (lightning surge clears everything)
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

        // Animate the lightning surge, then clear
        animateLightningSurge(row: r2, col: c2, isHorizontal: isHorizontal) { [weak self] in
            guard let self = self else { return }

            self.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
            }
        }
    }
    
    /// Rocket + Bomb: "Lightning Storm" — lightning bolts strike down from the top
    /// to 4-5 random positions, each creating a 3x3 bomb explosion.
    private func handleRocketBombCombo(r1: Int, c1: Int, r2: Int, c2: Int) {
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

        // Pick 4-5 random strike positions
        var candidatePositions: [(row: Int, col: Int)] = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] && gameGrid[row][col] != nil &&
                   !(row == r1 && col == c1) && !(row == r2 && col == c2) {
                    candidatePositions.append((row: row, col: col))
                }
            }
        }
        
        let strikeCount = min(Int.random(in: 4...5), candidatePositions.count)
        let strikePositions = Array(candidatePositions.shuffled().prefix(strikeCount))

        // Collect all tiles in 3x3 zones around each strike, plus the combo source tiles
        var clearedTiles: Set<String> = ["\(r2),\(c2)"]
        if gameGrid[r1][c1] != nil {
            clearedTiles.insert("\(r1),\(c1)")
        }
        
        for pos in strikePositions {
            for dr in -1...1 {
                for dc in -1...1 {
                    let r = pos.row + dr
                    let c = pos.col + dc
                    if r >= 0 && r < level.gridHeight && c >= 0 && c < level.gridWidth &&
                       gridShapeMap[r][c] && gameGrid[r][c] != nil {
                        clearedTiles.insert("\(r),\(c)")
                    }
                }
            }
        }

        let cascadingPowerups = collectCascadingPowerups(
            in: clearedTiles,
            excludePositions: [(row: r1, col: c1), (row: r2, col: c2)]
        )

        // Animate lightning storm, then clear
        animateLightningStorm(fromRow: r2, fromCol: c2, strikePositions: strikePositions) { [weak self] in
            guard let self = self else { return }

            self.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
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

        // Launch three independent rocket animations, then clear
        var completionCount = 0
        let totalAnimations = 3

        let onAnimationComplete: () -> Void = { [weak self] in
            completionCount += 1
            if completionCount >= totalAnimations {
                // All rockets done, show border highlight and clear
                self?.showPowerupBorderHighlight(clearedTiles) { [weak self] in
                    self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
                }
            }
        }

        animateRocketPath(fromRow: r2, fromCol: c2, completion: onAnimationComplete)
        animateRocketPath(fromRow: r2, fromCol: c2, completion: onAnimationComplete)
        animateRocketPath(fromRow: r2, fromCol: c2, completion: onAnimationComplete)
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
            shootFlamesHorizontally(row: r2, arrowCol: c2, columns: 0..<level.gridWidth) {}
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
        } else if type1 == .ball {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            // Ball handles its own clearing via animateBouncingBall — bypass finalizePowerupCombo
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            updateGridDisplay()
            movesRemaining -= 1
            updateUI()
            animateBouncingBall(fromRow: r2, fromCol: c2) { [weak self] in
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
            shootFlamesHorizontally(row: r1, arrowCol: c1, columns: 0..<level.gridWidth) {}
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
        } else if type2 == .ball {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            // Ball handles its own clearing via animateBouncingBall — bypass finalizePowerupCombo
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            updateGridDisplay()
            movesRemaining -= 1
            updateUI()
            animateBouncingBall(fromRow: r1, fromCol: c1) { [weak self] in
                self?.isAnimating = false
                if self?.movesRemaining ?? 0 <= 0 {
                    self?.levelFailed()
                }
            }
            return
        }

        // Before clearing, check if the swapped normal tile's new position forms a powerup-worthy match.
        // If so, convert it to a powerup and exclude it from clearedTiles so it survives the blast.
        var mutableCleared = clearedTiles
        var mutableCascading = cascadingPowerups
        
        // Determine which position has the normal tile (if any)
        let normalPositions: [(row: Int, col: Int)] = [
            type1 == .normal ? (row: r2, col: c2) : (row: -1, col: -1),
            type2 == .normal ? (row: r1, col: c1) : (row: -1, col: -1)
        ].filter { $0.row >= 0 }
        
        for pos in normalPositions {
            let key = "\(pos.row),\(pos.col)"
            if mutableCleared.contains(key), let powerupType = detectPowerupAtPosition(row: pos.row, col: pos.col) {
                // Convert this tile to a powerup — it survives the blast
                if let piece = gameGrid[pos.row][pos.col] {
                    piece.type = powerupType
                    if powerupType == .ball {
                        piece.ballEmojiIndex = Int.random(in: 0..<GamePiece.ballEmojis.count)
                    }
                    mutableCleared.remove(key)
                    mutableCascading.append((row: pos.row, col: pos.col, type: powerupType))
                }
            }
        }
        
        finalizePowerupCombo(
            clearedTiles: mutableCleared,
            cascadingPowerups: mutableCascading,
            decrementMoves: !mutableCleared.isEmpty || !clearedTiles.isEmpty,
            flameSource: flameSource,
            bombShake: type1 == .bomb || type2 == .bomb
        )
    }
    
    private func activateCascadingPowerups(_ powerups: [(row: Int, col: Int, type: PieceType)]) {
        guard let level = currentLevel else { return }

        if powerups.isEmpty {
            // No more cascading powerups - apply gravity and check for new matches
            applyGravityAfterCascade()
            return
        }

        // Enforce cascade depth cap — stop the chain if too many powerups have already fired
        if cascadeDepth >= maxCascadeDepth {
            print("🛑 Cascade depth cap (\(maxCascadeDepth)) reached — stopping chain with \(powerups.count) powerup(s) remaining.")
            pendingCascades = []
            applyGravityAfterCascade()
            return
        }
        cascadeDepth += 1
        print("⚡ Cascade depth \(cascadeDepth)/\(maxCascadeDepth)")

        // Reset stale transforms before each new powerup fires
        resetAllButtonTransforms()
        updateUI()

        // Pull the first powerup off the queue
        var remaining = powerups
        let current = remaining.removeFirst()
        let (row, col, type) = (current.row, current.col, current.type)

        // Collect sub-cascades discovered while clearing this powerup's tiles
        var subCascades: [(row: Int, col: Int, type: PieceType)] = []

        // --- PASS 1: Clear grid data for this single powerup ---
        var bombButtons: [UIButton] = []
        var flameTargets: Set<String> = []

        switch type {
        case .verticalArrow:
            for r in 0..<level.gridHeight {
                if gridShapeMap[r][col] && gameGrid[r][col] != nil {
                    if r != row, let p = gameGrid[r][col], p.type != .normal {
                        subCascades.append((row: r, col: col, type: p.type))
                    }
                    hitTile(row: r, col: col)
                }
            }
            print("🔥 Cascading vertical arrow cleared column \(col)")

        case .horizontalArrow:
            for c in 0..<level.gridWidth {
                if gridShapeMap[row][c] && gameGrid[row][c] != nil {
                    if c != col, let p = gameGrid[row][c], p.type != .normal {
                        subCascades.append((row: row, col: c, type: p.type))
                    }
                    hitTile(row: row, col: c)
                }
            }
            print("🔥 Cascading horizontal arrow cleared row \(row)")

        case .bomb:
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = row + dr; let nc = col + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        if let p = gameGrid[nr][nc], p.type != .normal {
                            subCascades.append((row: nr, col: nc, type: p.type))
                        }
                        if let btn = gridButtons[nr][nc] { bombButtons.append(btn) }
                        hitTile(row: nr, col: nc)
                    }
                }
            }
            print("🔥 Cascading bomb cleared 3x3 area around (\(row), \(col))")

        case .flame:
            // Clear the flame tile itself from the board if it's still present
            // (it may already be nil if cleared by the parent cascade, but if not, remove it now)
            let _ = hitTile(row: row, col: col)

            let adjacentPositions = [(row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)]
            var validAdjacentTiles: [(row: Int, col: Int, itemId: String, colorIndex: Int)] = []
            for (adjRow, adjCol) in adjacentPositions {
                if adjRow >= 0 && adjRow < level.gridHeight && adjCol >= 0 && adjCol < level.gridWidth &&
                   gridShapeMap[adjRow][adjCol], let piece = gameGrid[adjRow][adjCol], piece.type == .normal {
                    validAdjacentTiles.append((row: adjRow, col: adjCol, itemId: piece.itemId, colorIndex: piece.colorIndex))
                }
            }
            if let randomTile = validAdjacentTiles.randomElement() {
                for r in 0..<level.gridHeight {
                    for c in 0..<level.gridWidth {
                        if gridShapeMap[r][c], let piece = gameGrid[r][c],
                           piece.type == .normal && piece.itemId == randomTile.itemId && piece.colorIndex == randomTile.colorIndex {
                            flameTargets.insert("\(r),\(c)")
                        }
                    }
                }
                for posString in flameTargets {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        if let p = gameGrid[parts[0]][parts[1]], p.type != .normal {
                            subCascades.append((row: parts[0], col: parts[1], type: p.type))
                        }
                        let _ = hitTile(row: parts[0], col: parts[1])
                    }
                }
                print("🔥 Cascading flame cleared \(flameTargets.count) matching \(randomTile.itemId)")
            }

        case .rocket, .ball:
            // These animations handle their own tile clearing internally
            break

        default:
            break
        }

        // --- PASS 2: Fire visual animation, then gravity, then match-check, then next powerup ---
        let onAnimationComplete: () -> Void = { [weak self] in
            guard let self = self else { return }
            let next = remaining + subCascades
            // Store remaining cascades so checkForMatches can resume them after clearing any
            // matches that formed during this gravity step (e.g. 4-in-a-row from dropped tiles).
            self.pendingCascades = next
            self.applyGravityAfterCascade(then: {
                // Always run checkForMatches after gravity — it will detect new matches AND
                // resume pendingCascades (via the no-match branch) when the board is stable.
                self.checkForMatches()
            })
        }

        switch type {
        case .verticalArrow:
            shootFlamesVertically(column: col, arrowRow: row, rows: 0..<level.gridHeight) {
                onAnimationComplete()
            }
        case .horizontalArrow:
            shootFlamesHorizontally(row: row, arrowCol: col, columns: 0..<level.gridWidth) {
                onAnimationComplete()
            }
        case .bomb:
            animateBombExplosion(centerRow: row, centerCol: col, affectedButtons: bombButtons) {
                onAnimationComplete()
            }
        case .flame:
            if flameTargets.isEmpty {
                onAnimationComplete()
            } else {
                shootFlamesAtTiles(fromRow: row, fromCol: col, targetTiles: flameTargets) {
                    onAnimationComplete()
                }
            }
        case .rocket:
            animateRocketPath(fromRow: row, fromCol: col, managedExternally: true, subCascadeCallback: { subs in
                subCascades.append(contentsOf: subs)
            }) {
                onAnimationComplete()
            }
        case .ball:
            animateBouncingBall(fromRow: row, fromCol: col, managedExternally: true, subCascadeCallback: { subs in
                subCascades.append(contentsOf: subs)
            }) {
                onAnimationComplete()
            }
        default:
            onAnimationComplete()
        }

        print("🔥 Sequential cascade: processing \(type) at (\(row),\(col)), \(remaining.count) remaining in queue")
    }
    
    /// Immediately drops tiles in the given columns to fill gaps left by the ball,
    /// without blocking the ball animation or triggering checkForMatches.
    private func applyGravityForColumns(_ cols: Set<Int>) {
        guard let level = currentLevel, !cols.isEmpty else { return }

        var localMoved: Set<String> = []
        var localDist  = [String: Int]()
        var localNew:   Set<String> = []

        let gridHasValidMoves = hasValidMoves()

        for col in cols {
            guard col >= 0 && col < level.gridWidth else { continue }

            // --- existing pieces fall ---
            var pieces: [(row: Int, piece: GamePiece)] = []
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    pieces.append((row: row, piece: piece))
                    gameGrid[row][col] = nil
                }
            }
            var targetRow = level.gridHeight - 1
            for (originalRow, piece) in pieces.reversed() {
                while targetRow >= 0 && (!gridShapeMap[targetRow][col] || gameGrid[targetRow][col] != nil) {
                    targetRow -= 1
                }
                if targetRow >= 0 {
                    let distance = originalRow - targetRow
                    gameGrid[targetRow][col] = piece
                    piece.row = targetRow; piece.col = col
                    if distance != 0 {
                        localMoved.insert("\(targetRow),\(col)")
                        localDist["\(targetRow),\(col)"] = distance
                    }
                    targetRow -= 1
                }
            }

            // --- refill new pieces from above ---
            var emptyRows: [Int] = []
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col] && gameGrid[row][col] == nil { emptyRows.append(row) }
            }
            let n = emptyRows.count
            for (idx, row) in emptyRows.enumerated() {
                let newPiece = generateNonMatchingPiece(row: row, col: col, level: level, avoidMatches: gridHasValidMoves)
                gameGrid[row][col] = newPiece
                localMoved.insert("\(row),\(col)")
                let slotFromBottom = n - 1 - idx
                localDist["\(row),\(col)"] = row + slotFromBottom + 1
                localNew.insert("\(row),\(col)")
            }
        }

        guard !localMoved.isEmpty else { return }

        // Set button content then animate — reuse animatePiecesDrop machinery
        updateGridDisplay()
        isApplyingGravity = true

        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let cellWidth  = gridContainer.bounds.width  / CGFloat(level.gridWidth)

        for key in localMoved {
            let parts = key.split(separator: ",")
            guard parts.count == 2,
                  let row = Int(parts[0]), let col = Int(parts[1]),
                  let button = gridButtons[row][col] else { continue }
            let dist = localDist[key] ?? 0
            if localNew.contains(key) {
                let fallPx = cellHeight * CGFloat(dist)
                button.transform = CGAffineTransform(translationX: 0, y: -fallPx)
            } else if dist > 0 {
                let fallPx = cellHeight * CGFloat(dist)
                button.transform = CGAffineTransform(translationX: 0, y: -fallPx)
            }
            _ = cellWidth  // suppress unused warning
        }

        isApplyingGravity = false

        // Build piece array for animatePiecesDrop
        struct ColPiece { let row: Int; let col: Int; let distance: Int; let isNew: Bool }
        var toAnimate: [ColPiece] = []
        for key in localMoved {
            let parts = key.split(separator: ",")
            guard parts.count == 2, let row = Int(parts[0]), let col = Int(parts[1]) else { continue }
            let dist = localDist[key] ?? 0
            toAnimate.append(ColPiece(row: row, col: col, distance: dist, isNew: localNew.contains(key)))
        }

        // Animate — no completion handler needed; ball manages final state
        let fallSpeed: CGFloat = 800
        var maxEnd: Double = 0
        // Sort within each column: bottom rows first (largest row index first)
        let sorted = toAnimate.sorted { $0.row > $1.row }
        for piece in sorted {
            guard let button = gridButtons[piece.row][piece.col] else { continue }
            let dist = max(piece.distance, 1)
            let duration = max(0.08, min(0.45, Double(cellHeight * CGFloat(dist)) / Double(fallSpeed)))
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn]) {
                button.transform = .identity
            } completion: { _ in
                guard button.transform == .identity else { return }
                UIView.animate(withDuration: 0.07) {
                    button.transform = CGAffineTransform(scaleX: 1.18, y: 0.65)
                } completion: { _ in
                    UIView.animate(withDuration: 0.09) { button.transform = .identity }
                }
            }
            maxEnd = max(maxEnd, duration)
        }
    }

    private func applyGravityAfterCascade(then completion: (() -> Void)? = nil) {
        guard let level = currentLevel else { return }
        
        // Reset all button transforms before gravity to clear any leftover scale/rotation from animations
        resetAllButtonTransforms()
        
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
                    
                    // Track pieces that actually moved (distance is negative for downward falls)
                    if distance != 0 {
                        movedPieces.insert("\(targetRow),\(col)")
                        fallDistances["\(targetRow),\(col)"] = distance
                    }
                    
                    targetRow -= 1
                }
            }
        }
        
        // STEP 2: Refill empty spaces with NEW pieces using stacked start positions.
        // All new pieces in a column share the same fall distance so they land simultaneously.
        let gridHasValidMoves = hasValidMoves()
        for col in 0..<level.gridWidth {
            var emptyRows: [Int] = []
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col] && gameGrid[row][col] == nil {
                    emptyRows.append(row)
                }
            }
            let n = emptyRows.count
            for (idx, row) in emptyRows.enumerated() {
                let newPiece = generateNonMatchingPiece(row: row, col: col, level: level, avoidMatches: gridHasValidMoves)
                gameGrid[row][col] = newPiece
                if !movedPieces.contains("\(row),\(col)") {
                    movedPieces.insert("\(row),\(col)")
                    let slotFromBottom = n - 1 - idx  // 0 = bottommost empty row
                    fallDistances["\(row),\(col)"] = row + slotFromBottom + 1
                    newPieces.insert("\(row),\(col)")
                }
            }
        }

        // Update grid display to set correct content on buttons BEFORE setting start transforms
        updateGridDisplay()
        
        // Block updateGridDisplay from resetting transforms while we set start positions
        isApplyingGravity = true
        
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
                    // EXISTING pieces: distance is negative (fell down), so fallDistance is negative,
                    // placing button ABOVE its final position. Animation to .identity drops it down.
                    let fallDistance = cellHeight * CGFloat(distance)
                    button.transform = CGAffineTransform(translationX: 0, y: fallDistance)
                    button.alpha = 1.0
                }
            }
        }
        
        isApplyingGravity = false
        
        // Animate pieces falling, then check for matches when complete
        animatePiecesDrop() { [weak self] in
            if let completion = completion {
                completion()
            } else {
                self?.checkForMatches()
            }
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
        
        let cellWidth = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let centerX = CGFloat(column) * cellWidth + cellWidth / 2
        let arrowCenterY = CGFloat(arrowRow) * cellHeight + cellHeight / 2
        let beamWidth: CGFloat = cellWidth * 0.6
        
        // Create a glowing beam that expands upward and downward from the arrow
        let beamUp = UIView()
        beamUp.backgroundColor = UIColor.orange
        beamUp.layer.cornerRadius = beamWidth / 2
        beamUp.alpha = 0.9
        // Start as zero-height at arrow center
        beamUp.frame = CGRect(x: centerX - beamWidth / 2, y: arrowCenterY, width: beamWidth, height: 0)
        gridContainer.addSubview(beamUp)
        
        // Add inner glow
        let glowUp = UIView()
        glowUp.backgroundColor = UIColor.yellow.withAlphaComponent(0.7)
        glowUp.layer.cornerRadius = beamWidth * 0.3 / 2
        glowUp.frame = CGRect(x: (beamWidth - beamWidth * 0.3) / 2, y: 0, width: beamWidth * 0.3, height: 0)
        glowUp.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        beamUp.addSubview(glowUp)
        
        let beamDown = UIView()
        beamDown.backgroundColor = UIColor.orange
        beamDown.layer.cornerRadius = beamWidth / 2
        beamDown.alpha = 0.9
        beamDown.frame = CGRect(x: centerX - beamWidth / 2, y: arrowCenterY, width: beamWidth, height: 0)
        gridContainer.addSubview(beamDown)
        
        let glowDown = UIView()
        glowDown.backgroundColor = UIColor.yellow.withAlphaComponent(0.7)
        glowDown.layer.cornerRadius = beamWidth * 0.3 / 2
        glowDown.frame = CGRect(x: (beamWidth - beamWidth * 0.3) / 2, y: 0, width: beamWidth * 0.3, height: 0)
        glowDown.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        beamDown.addSubview(glowDown)
        
        let topEdge: CGFloat = -20
        let bottomEdge = gridContainer.bounds.height + 20
        
        var animationsComplete = 0
        let checkDone = {
            animationsComplete += 1
            if animationsComplete == 2 {
                completion()
            }
        }
        
        // Expand beams outward
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            // Beam going up: top edge to arrow center
            beamUp.frame = CGRect(x: centerX - beamWidth / 2, y: topEdge, width: beamWidth, height: arrowCenterY - topEdge)
            glowUp.frame = CGRect(x: (beamWidth - beamWidth * 0.3) / 2, y: 0, width: beamWidth * 0.3, height: arrowCenterY - topEdge)
        }, completion: { _ in
            // Fade out
            UIView.animate(withDuration: 0.2, animations: {
                beamUp.alpha = 0
            }, completion: { _ in
                beamUp.removeFromSuperview()
                checkDone()
            })
        })
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            // Beam going down: arrow center to bottom edge
            beamDown.frame = CGRect(x: centerX - beamWidth / 2, y: arrowCenterY, width: beamWidth, height: bottomEdge - arrowCenterY)
            glowDown.frame = CGRect(x: (beamWidth - beamWidth * 0.3) / 2, y: 0, width: beamWidth * 0.3, height: bottomEdge - arrowCenterY)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                beamDown.alpha = 0
            }, completion: { _ in
                beamDown.removeFromSuperview()
                checkDone()
            })
        })
    }
    
    /// Shoots four diagonal beams from (centerRow, centerCol), forming an "X" pattern.
    /// Uses CAShapeLayer strokeEnd animation — same visual language as the row/column beams.
    private func shootFlamesDiagonally(centerRow: Int, centerCol: Int, completion: @escaping () -> Void) {
        guard let level = currentLevel else { completion(); return }

        let cellWidth  = gridContainer.bounds.width  / CGFloat(level.gridWidth)
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let ox = CGFloat(centerCol) * cellWidth  + cellWidth  / 2
        let oy = CGFloat(centerRow) * cellHeight + cellHeight / 2

        // Diagonal end-points: go far enough to exit the grid in each diagonal direction
        let farDist: CGFloat = max(gridContainer.bounds.width, gridContainer.bounds.height) * 1.5
        let directions: [(dx: CGFloat, dy: CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]

        let beamWidth: CGFloat = cellWidth * 0.18
        let animDuration: CFTimeInterval = 0.3
        var doneCount = 0

        for dir in directions {
            let endX = ox + dir.dx * farDist / sqrt(2)
            let endY = oy + dir.dy * farDist / sqrt(2)

            // Outer beam (orange)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: ox, y: oy))
            path.addLine(to: CGPoint(x: endX, y: endY))

            let beamLayer = CAShapeLayer()
            beamLayer.path = path.cgPath
            beamLayer.strokeColor = UIColor.orange.cgColor
            beamLayer.lineWidth = beamWidth
            beamLayer.lineCap = .round
            beamLayer.strokeEnd = 0
            gridContainer.layer.addSublayer(beamLayer)

            // Inner glow (yellow, thinner)
            let glowLayer = CAShapeLayer()
            glowLayer.path = path.cgPath
            glowLayer.strokeColor = UIColor.yellow.withAlphaComponent(0.8).cgColor
            glowLayer.lineWidth = beamWidth * 0.4
            glowLayer.lineCap = .round
            glowLayer.strokeEnd = 0
            gridContainer.layer.addSublayer(glowLayer)

            // Animate strokeEnd 0 → 1
            let grow = CABasicAnimation(keyPath: "strokeEnd")
            grow.fromValue = 0
            grow.toValue = 1
            grow.duration = animDuration
            grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            grow.fillMode = .forwards
            grow.isRemovedOnCompletion = false
            beamLayer.add(grow, forKey: "grow")
            glowLayer.add(grow, forKey: "grow")

            // Fade out after beam fully extends
            DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {
                UIView.animate(withDuration: 0.2, animations: {
                    beamLayer.opacity = 0
                    glowLayer.opacity = 0
                }, completion: { _ in
                    beamLayer.removeFromSuperlayer()
                    glowLayer.removeFromSuperlayer()
                    doneCount += 1
                    if doneCount == directions.count {
                        completion()
                    }
                })
            }
        }
    }

    private func shootFlamesHorizontally(row: Int, arrowCol: Int? = nil, columns: Range<Int>, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        guard row < gridButtons.count else {
            completion()
            return
        }
        
        let cellWidth = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let centerY = CGFloat(row) * cellHeight + cellHeight / 2
        let arrowCenterX: CGFloat
        if let col = arrowCol {
            arrowCenterX = CGFloat(col) * cellWidth + cellWidth / 2
        } else {
            arrowCenterX = gridContainer.bounds.width / 2
        }
        let beamHeight: CGFloat = cellHeight * 0.6
        
        // Create beams shooting left and right
        let beamLeft = UIView()
        beamLeft.backgroundColor = UIColor.orange
        beamLeft.layer.cornerRadius = beamHeight / 2
        beamLeft.alpha = 0.9
        beamLeft.frame = CGRect(x: arrowCenterX, y: centerY - beamHeight / 2, width: 0, height: beamHeight)
        gridContainer.addSubview(beamLeft)
        
        let glowLeft = UIView()
        glowLeft.backgroundColor = UIColor.yellow.withAlphaComponent(0.7)
        glowLeft.layer.cornerRadius = beamHeight * 0.3 / 2
        glowLeft.frame = CGRect(x: 0, y: (beamHeight - beamHeight * 0.3) / 2, width: 0, height: beamHeight * 0.3)
        glowLeft.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        beamLeft.addSubview(glowLeft)
        
        let beamRight = UIView()
        beamRight.backgroundColor = UIColor.orange
        beamRight.layer.cornerRadius = beamHeight / 2
        beamRight.alpha = 0.9
        beamRight.frame = CGRect(x: arrowCenterX, y: centerY - beamHeight / 2, width: 0, height: beamHeight)
        gridContainer.addSubview(beamRight)
        
        let glowRight = UIView()
        glowRight.backgroundColor = UIColor.yellow.withAlphaComponent(0.7)
        glowRight.layer.cornerRadius = beamHeight * 0.3 / 2
        glowRight.frame = CGRect(x: 0, y: (beamHeight - beamHeight * 0.3) / 2, width: 0, height: beamHeight * 0.3)
        glowRight.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        beamRight.addSubview(glowRight)
        
        let leftEdge: CGFloat = -20
        let rightEdge = gridContainer.bounds.width + 20
        
        var animationsComplete = 0
        let checkDone = {
            animationsComplete += 1
            if animationsComplete == 2 {
                completion()
            }
        }
        
        // Expand beams outward
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            beamLeft.frame = CGRect(x: leftEdge, y: centerY - beamHeight / 2, width: arrowCenterX - leftEdge, height: beamHeight)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                beamLeft.alpha = 0
            }, completion: { _ in
                beamLeft.removeFromSuperview()
                checkDone()
            })
        })
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            beamRight.frame = CGRect(x: arrowCenterX, y: centerY - beamHeight / 2, width: rightEdge - arrowCenterX, height: beamHeight)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, animations: {
                beamRight.alpha = 0
            }, completion: { _ in
                beamRight.removeFromSuperview()
                checkDone()
            })
        })
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
        case .ball: emoji = "⚽"
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
    
    /// Animates a bouncing ball powerup. The ball flies up above the grid, then falls with gravity,
    /// bouncing one column left/right and one row down each time, leaving a dotted trail,
    /// before doing a final bounce off the bottom of the screen.
    private func animateBouncingBall(fromRow: Int, fromCol: Int, extraCascades: [(row: Int, col: Int, type: PieceType)] = [], managedExternally: Bool = false, bombExplosionRadius: Int = 0, subCascadeCallback: @escaping ([(row: Int, col: Int, type: PieceType)]) -> Void = { _ in }, completion: @escaping () -> Void) {
        guard let level = currentLevel else {
            completion()
            return
        }
        
        // Grab the emoji from the piece before removing it
        let ballEmoji: String
        if let piece = gameGrid[fromRow][fromCol] {
            ballEmoji = GamePiece.ballEmojis[piece.ballEmojiIndex]
        } else {
            ballEmoji = "⚽"
        }
        
        // Capture cascading powerups from bounce targets BEFORE clearing
        var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
        
        // Remove the ball piece from the grid and clear the button immediately
        gameGrid[fromRow][fromCol] = nil
        score += 1
        if let button = gridButtons[fromRow][fromCol] {
            button.setTitle("", for: .normal)
            button.setImage(nil, for: .normal)
            button.backgroundColor = .clear
        }
        
        // Grid geometry
        let gridHeight = gridContainer.bounds.height
        let gridWidth = gridContainer.bounds.width
        let rowHeight = gridHeight / CGFloat(level.gridHeight)
        let colWidth = gridWidth / CGFloat(level.gridWidth)
        
        // Starting position (center of the ball's tile)
        let startX = CGFloat(fromCol) * colWidth + colWidth / 2
        let startY = CGFloat(fromRow) * rowHeight + rowHeight / 2
        
        // Create the ball label using the piece's fixed emoji
        let ballSize = min(colWidth, rowHeight) * 0.9
        let ballLabel = UILabel()
        ballLabel.text = ballEmoji
        ballLabel.font = UIFont.systemFont(ofSize: ballSize)
        ballLabel.textAlignment = .center
        ballLabel.frame = CGRect(x: startX - ballSize / 2, y: startY - ballSize / 2, width: ballSize, height: ballSize)
        gridContainer.addSubview(ballLabel)
        
        // Protect ball label from gravity's stray-subview cleanup
        activeAnimationViews.insert(ObjectIdentifier(ballLabel))
        
        // Create dotted trail layer — trail starts AFTER fly-up, not during
        let trailLayer = CAShapeLayer()
        trailLayer.name = "ballTrail"
        trailLayer.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
        trailLayer.fillColor = nil
        trailLayer.lineWidth = 2.0
        trailLayer.lineDashPattern = [4, 6]
        trailLayer.lineCap = .round
        gridContainer.layer.addSublayer(trailLayer)
        let trailPath = UIBezierPath()
        
        // Phase 1: Ball flies up above the grid center
        let topY: CGFloat = -ballSize
        let centerX = gridWidth / 2
        
        // Build bounce targets: step one row down and one column left/right each time.
        // Start from row 0 (top of grid) after the fly-up.
        var bounceTiles: [(row: Int, col: Int)] = []
        var currentCol = Int.random(in: 0..<level.gridWidth)  // Random starting column
        var bounceDir = Bool.random() ? 1 : -1  // Initial direction: +1 right, -1 left
        
        for r in 0..<level.gridHeight {
            // Look for an occupied tile in this row near currentCol
            // Always prefer bouncing left or right first, only go straight down as last resort
            let candidates = [currentCol + bounceDir, currentCol - bounceDir, currentCol]
            var found = false
            for c in candidates {
                if c >= 0 && c < level.gridWidth && gridShapeMap[r][c] && gameGrid[r][c] != nil {
                    bounceTiles.append((row: r, col: c))
                    // Bounce direction: move toward the column we landed on, then alternate
                    if c != currentCol {
                        bounceDir = (c > currentCol) ? 1 : -1
                    } else {
                        bounceDir = -bounceDir  // Alternate if staying in same column
                    }
                    currentCol = c
                    found = true
                    break
                }
            }
            // If nothing found in this row, skip it (ball falls past)
            if !found { continue }
            if bounceTiles.count >= 8 { break }
        }
        
        // Pre-capture powerups in bounce targets before any clearing happens
        for tile in bounceTiles {
            if let piece = gameGrid[tile.row][tile.col], piece.type != .normal {
                cascadingPowerups.append((row: tile.row, col: tile.col, type: piece.type))
            }
        }
        
        // Phase 1: Animate ball flying up (no trail during this phase)
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
            ballLabel.center = CGPoint(x: centerX, y: topY)
            ballLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { [weak self] _ in
            guard let self = self else {
                trailLayer.removeFromSuperlayer()
                ballLabel.removeFromSuperview()
                completion()
                return
            }
            // Keep ballLabel in activeAnimationViews — it's still active through Phase 2 & 3.
            // Removal happens in Phase 3 completion when the ball truly exits the screen.
            
            // Start the trail from the top position
            trailPath.move(to: CGPoint(x: centerX, y: topY))
            trailLayer.path = trailPath.cgPath
            
            // Phase 2: Ball drops and bounces across tiles (downward only)
            self.animateBallBounces(ballLabel: ballLabel, bounces: bounceTiles, index: 0,
                                    level: level, rowHeight: rowHeight, colWidth: colWidth,
                                    gridWidth: gridWidth, gridHeight: gridHeight,
                                    bombExplosionRadius: bombExplosionRadius,
                                    trailPath: trailPath, trailLayer: trailLayer) {
                // Phase 3: Final bounce off the bottom of the screen
                let lastPos = ballLabel.center
                let exitDir: CGFloat = Bool.random() ? 1 : -1
                let exitX = lastPos.x + exitDir * colWidth * 1.5
                let exitY = gridHeight + ballSize * 2
                let arcPeakY = lastPos.y - rowHeight * 0.8
                let arcPeakX = lastPos.x + exitDir * colWidth * 0.4
                
                // Exit trail segment will be added after the ball exits (in completion)
                
                UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: [], animations: {
                    // Bounce up (slow rise)
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.30) {
                        ballLabel.center = CGPoint(x: arcPeakX, y: arcPeakY)
                        ballLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05).rotated(by: CGFloat.pi * 1.5)
                    }
                    // Fall off bottom (fast drop)
                    UIView.addKeyframe(withRelativeStartTime: 0.30, relativeDuration: 0.70) {
                        ballLabel.center = CGPoint(x: exitX, y: exitY)
                        ballLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8).rotated(by: CGFloat.pi * 3)
                    }
                }) { [weak self] _ in
                    guard let self = self else {
                        ballLabel.removeFromSuperview()
                        trailLayer.removeFromSuperlayer()
                        completion()
                        return
                    }
                    self.activeAnimationViews.remove(ObjectIdentifier(ballLabel))
                    ballLabel.removeFromSuperview()
                    
                    // Draw the exit trail segment now that the ball has exited
                    trailPath.addQuadCurve(to: CGPoint(x: exitX, y: exitY),
                                           controlPoint: CGPoint(x: arcPeakX, y: arcPeakY))
                    trailLayer.path = trailPath.cgPath
                    trailLayer.strokeEnd = 1.0
                    
                    // Fade out the trail
                    let fadeOut = CABasicAnimation(keyPath: "opacity")
                    fadeOut.fromValue = 0.7
                    fadeOut.toValue = 0.0
                    fadeOut.duration = 0.4
                    fadeOut.fillMode = .forwards
                    fadeOut.isRemovedOnCompletion = false
                    trailLayer.add(fadeOut, forKey: "trailFade")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        guard let self = self else {
                            trailLayer.removeFromSuperlayer()
                            completion()
                            return
                        }
                        trailLayer.removeFromSuperlayer()
                        self.updateGridDisplay()
                        self.updateUI()
                        
                        // Handle cascading powerups or apply gravity (same pattern as rocket)
                        // Merge any extra cascades (e.g. from a ball+arrow combo's arrow tiles)
                        let allCascades = cascadingPowerups + extraCascades
                        if managedExternally {
                            // Cascade system is managing gravity — report sub-cascades and return
                            subCascadeCallback(allCascades)
                            completion()
                        } else {
                            if !allCascades.isEmpty {
                                self.activateCascadingPowerups(allCascades)
                            } else {
                                self.applyGravity()
                            }
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    /// Recursively animates ball bouncing downward to each target tile, clearing it on impact.
    /// Uses parabolic arcs with curved dotted trail. Rise is slow, fall is fast (gravity feel).
    private func animateBallBounces(ballLabel: UILabel, bounces: [(row: Int, col: Int)], index: Int,
                                     level: MatchGameLevel, rowHeight: CGFloat, colWidth: CGFloat,
                                     gridWidth: CGFloat, gridHeight: CGFloat,
                                     bombExplosionRadius: Int = 0,
                                     trailPath: UIBezierPath, trailLayer: CAShapeLayer,
                                     completion: @escaping () -> Void) {
        guard index < bounces.count else {
            completion()
            return
        }
        
        let target = bounces[index]
        let targetX = CGFloat(target.col) * colWidth + colWidth / 2
        let targetY = CGFloat(target.row) * rowHeight + rowHeight / 2
        
        let currentPos = ballLabel.center
        
        // Arc peak: rises above the current position proportional to horizontal distance
        let horizontalDist = abs(targetX - currentPos.x)
        let arcRise = max(rowHeight * 1.2, horizontalDist * 0.4 + rowHeight * 0.8)
        let arcPeakY = currentPos.y - arcRise
        // The arc peak drifts slightly toward the target horizontally
        let arcPeakX = currentPos.x + (targetX - currentPos.x) * 0.3
        
        // Duration based on vertical drop distance — longer drops take more time
        let verticalDrop = targetY - arcPeakY
        let duration: TimeInterval = max(0.3, min(0.7, Double(verticalDrop / (rowHeight * 6)) * 0.4))
        
        // Trail segment will be added AFTER the ball lands (in completion), not before
        // This way the trail appears behind the ball showing where it's been
        
        // Rotation amount — spin more on longer bounces
        let spinAmount = CGFloat.pi * (0.8 + horizontalDist / gridWidth)
        let currentRotation = CGFloat(index) * CGFloat.pi * 0.8
        
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: [], animations: {
            // Rise phase: slow (decelerating upward) — 30% of time
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.70) {
                ballLabel.center = CGPoint(x: arcPeakX, y: arcPeakY)
                ballLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                    .rotated(by: currentRotation + spinAmount * 0.3)
            }
            // Fall phase: fast (accelerating downward) — 70% of time
            UIView.addKeyframe(withRelativeStartTime: 0.70, relativeDuration: 0.70) {
                ballLabel.center = CGPoint(x: targetX, y: targetY)
                ballLabel.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                    .rotated(by: currentRotation + spinAmount)
            }
        }) { [weak self] _ in
            guard let self = self else { completion(); return }
            
            // Draw the trail segment now that the ball has landed
            trailPath.addQuadCurve(to: CGPoint(x: targetX, y: targetY),
                                   controlPoint: CGPoint(x: arcPeakX, y: arcPeakY))
            trailLayer.path = trailPath.cgPath
            trailLayer.strokeEnd = 1.0
            
            // Impact: clear the tile (or 3x3 area for bomb combos)
            if bombExplosionRadius > 0 {
                // Cannonball: explode a (2r+1)x(2r+1) area on each bounce
                var explosionButtons: [UIButton] = []
                for dr in -bombExplosionRadius...bombExplosionRadius {
                    for dc in -bombExplosionRadius...bombExplosionRadius {
                        let er = target.row + dr
                        let ec = target.col + dc
                        guard er >= 0 && er < level.gridHeight && ec >= 0 && ec < level.gridWidth else { continue }
                        guard gridShapeMap[er][ec] else { continue }
                        if self.gameGrid[er][ec] != nil {
                            let _ = self.hitTile(row: er, col: ec)
                            if let btn = self.gridButtons[er][ec] {
                                explosionButtons.append(btn)
                            }
                        }
                    }
                }
                // Mini bomb flash at the impact center
                let flashView = UIView()
                flashView.backgroundColor = UIColor.orange.withAlphaComponent(0.85)
                flashView.layer.cornerRadius = min(colWidth, rowHeight) * 0.5 * CGFloat(bombExplosionRadius * 2 + 1)
                let flashSize = min(colWidth, rowHeight) * CGFloat(bombExplosionRadius * 2 + 1) * 1.1
                flashView.frame = CGRect(x: targetX - flashSize / 2, y: targetY - flashSize / 2, width: flashSize, height: flashSize)
                self.gridContainer.addSubview(flashView)
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                    flashView.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
                    flashView.alpha = 0
                }) { _ in flashView.removeFromSuperview() }

                // Pop-then-shrink the affected buttons
                let totalDur: TimeInterval = 0.22
                for btn in explosionButtons {
                    let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                    scaleAnim.values = [1.0, 1.25, 0.1]
                    scaleAnim.keyTimes = [0, 0.4, 1.0]
                    scaleAnim.duration = totalDur
                    scaleAnim.fillMode = .forwards
                    scaleAnim.isRemovedOnCompletion = false
                    btn.layer.add(scaleAnim, forKey: "cannonPop")
                    let fadeAnim = CABasicAnimation(keyPath: "opacity")
                    fadeAnim.fromValue = 1.0; fadeAnim.toValue = 0.0
                    fadeAnim.beginTime = CACurrentMediaTime() + 0.09
                    fadeAnim.duration = 0.13
                    fadeAnim.fillMode = .forwards
                    fadeAnim.isRemovedOnCompletion = false
                    btn.layer.add(fadeAnim, forKey: "cannonFade")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDur + 0.02) {
                    for btn in explosionButtons {
                        btn.layer.removeAnimation(forKey: "cannonPop")
                        btn.layer.removeAnimation(forKey: "cannonFade")
                        btn.layer.opacity = 1.0
                        btn.setTitle("", for: .normal)
                        btn.setImage(nil, for: .normal)
                        btn.backgroundColor = .clear
                    }
                }
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
            } else if self.gameGrid[target.row][target.col] != nil {
                let _ = self.hitTile(row: target.row, col: target.col)

                // Clear the button display on impact
                if let button = self.gridButtons[target.row][target.col] {
                    button.setTitle("", for: .normal)
                    button.setImage(nil, for: .normal)
                    button.backgroundColor = .clear
                }
                
                // Small orange impact flash on the single tile
                let flashSize = min(colWidth, rowHeight) * 0.85
                let flashView = UIView()
                flashView.backgroundColor = UIColor.orange.withAlphaComponent(0.75)
                flashView.layer.cornerRadius = flashSize / 2
                flashView.frame = CGRect(x: targetX - flashSize / 2, y: targetY - flashSize / 2,
                                         width: flashSize, height: flashSize)
                self.gridContainer.addSubview(flashView)
                UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseOut, animations: {
                    flashView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                    flashView.alpha = 0
                }) { _ in flashView.removeFromSuperview() }
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
            
            // Brief pause then bounce to next target
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                self.animateBallBounces(ballLabel: ballLabel, bounces: bounces, index: index + 1,
                                        level: level, rowHeight: rowHeight, colWidth: colWidth,
                                        gridWidth: gridWidth, gridHeight: gridHeight,
                                        bombExplosionRadius: bombExplosionRadius,
                                        trailPath: trailPath, trailLayer: trailLayer,
                                        completion: completion)
            }
        }
    }
    
    /// Animates a rocket flying a looping path across the grid, clearing all tiles it crosses.
    /// The rocket visits 8-12 random waypoints, highlights crossed tiles with yellow borders, then clears them.
    private func animateRocketPath(fromRow: Int, fromCol: Int, managedExternally: Bool = false, subCascadeCallback: @escaping ([(row: Int, col: Int, type: PieceType)]) -> Void = { _ in }, completion: @escaping () -> Void) {
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
        
        // Build a jagged lightning path along the rocket's route
        let lightningPath = UIBezierPath()
        let totalLength = approximatePathLength(waypoints: waypoints)
        let jagSegmentLength: CGFloat = 8  // length between jag points
        let jagAmount: CGFloat = 4  // max perpendicular offset
        let numSegments = max(Int(totalLength / jagSegmentLength), 2)
        
        for s in 0...numSegments {
            let fraction = CGFloat(s) / CGFloat(numSegments)
            let targetLen = totalLength * fraction
            var accumulated: CGFloat = 0
            var point = waypoints[0]
            var segDx: CGFloat = 1
            var segDy: CGFloat = 0
            
            for i in 0..<(waypoints.count - 1) {
                let segLen = hypot(waypoints[i + 1].x - waypoints[i].x, waypoints[i + 1].y - waypoints[i].y)
                if accumulated + segLen >= targetLen {
                    let segFraction = (targetLen - accumulated) / max(segLen, 1)
                    point = CGPoint(
                        x: waypoints[i].x + (waypoints[i + 1].x - waypoints[i].x) * segFraction,
                        y: waypoints[i].y + (waypoints[i + 1].y - waypoints[i].y) * segFraction
                    )
                    segDx = waypoints[i + 1].x - waypoints[i].x
                    segDy = waypoints[i + 1].y - waypoints[i].y
                    let segMag = max(hypot(segDx, segDy), 1)
                    segDx /= segMag
                    segDy /= segMag
                    break
                }
                accumulated += segLen
            }
            
            // Add perpendicular jag (not on first or last point)
            if s > 0 && s < numSegments {
                let perpX = -segDy
                let perpY = segDx
                let jag = CGFloat.random(in: -jagAmount...jagAmount)
                point.x += perpX * jag
                point.y += perpY * jag
            }
            
            if s == 0 {
                lightningPath.move(to: point)
            } else {
                lightningPath.addLine(to: point)
            }
        }
        
        // Create the lightning shape layer
        let lightningLayer = CAShapeLayer()
        lightningLayer.path = lightningPath.cgPath
        lightningLayer.strokeColor = UIColor.white.cgColor
        lightningLayer.lineWidth = 2.0
        lightningLayer.fillColor = nil
        lightningLayer.lineCap = .round
        lightningLayer.lineJoin = .round
        lightningLayer.shadowColor = UIColor.cyan.cgColor
        lightningLayer.shadowRadius = 4
        lightningLayer.shadowOpacity = 0.8
        lightningLayer.shadowOffset = .zero
        gridContainer.layer.addSublayer(lightningLayer)
        
        // Animate the lightning drawing progressively (stroke follows the rocket)
        let animationDuration = Double(waypoints.count) * 0.12
        lightningLayer.strokeEnd = 0
        let strokeAnim = CABasicAnimation(keyPath: "strokeEnd")
        strokeAnim.fromValue = 0
        strokeAnim.toValue = 1
        strokeAnim.duration = animationDuration
        strokeAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        strokeAnim.fillMode = .forwards
        strokeAnim.isRemovedOnCompletion = false
        lightningLayer.add(strokeAnim, forKey: "drawLightning")
        
        // Track animation completion
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            rocketLabel.removeFromSuperview()
            
            // Fade out the lightning trail
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 1.0
            fadeAnim.toValue = 0.0
            fadeAnim.duration = 0.2
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                lightningLayer.removeFromSuperlayer()
            }
            lightningLayer.add(fadeAnim, forKey: "fadeLightning")
            CATransaction.commit()
            
            guard let self = self else {
                completion()
                return
            }
            
            // Show smoke poof on crossed tiles, then clear
            self.showPowerupBorderHighlight(crossedTileSet) { [weak self] in
                guard let self = self else {
                    completion()
                    return
                }
                
                // Clear all crossed tiles
                for posString in crossedTileSet {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self.hitTile(row: parts[0], col: parts[1])
                    }
                }
                
                self.updateGridDisplay()
                self.updateUI()
                
                // Activate cascading powerups or apply gravity
                if managedExternally {
                    // Cascade system is managing gravity — report sub-cascades and return
                    subCascadeCallback(cascadingPowerups)
                    completion()
                } else if !cascadingPowerups.isEmpty {
                    self.activateCascadingPowerups(cascadingPowerups)
                    completion()
                } else {
                    self.applyGravity()
                    completion()
                }
            }
        }
        
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
    
    /// Builds a jagged lightning bolt CAShapeLayer between two points.
    private func buildLightningBolt(from start: CGPoint, to end: CGPoint, jagSegmentLength: CGFloat = 8, jagAmount: CGFloat = 4, lineWidth: CGFloat = 2.0, color: UIColor = .cyan) -> CAShapeLayer {
        let path = UIBezierPath()
        let totalLength = hypot(end.x - start.x, end.y - start.y)
        let numSegments = max(Int(totalLength / jagSegmentLength), 2)
        let dx = (end.x - start.x) / max(totalLength, 1)
        let dy = (end.y - start.y) / max(totalLength, 1)
        
        for s in 0...numSegments {
            let fraction = CGFloat(s) / CGFloat(numSegments)
            var point = CGPoint(
                x: start.x + (end.x - start.x) * fraction,
                y: start.y + (end.y - start.y) * fraction
            )
            
            if s > 0 && s < numSegments {
                let perpX = -dy
                let perpY = dx
                let jag = CGFloat.random(in: -jagAmount...jagAmount)
                point.x += perpX * jag
                point.y += perpY * jag
            }
            
            if s == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = lineWidth
        layer.fillColor = nil
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.shadowColor = color.cgColor
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.8
        layer.shadowOffset = .zero
        return layer
    }
    
    /// Lightning Surge: A main bolt traces the arrow's row/col, then forks perpendicularly at each cell.
    private func animateLightningSurge(row: Int, col: Int, isHorizontal: Bool, completion: @escaping () -> Void) {
        guard let level = currentLevel else { completion(); return }
        
        let cellWidth = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let originX = CGFloat(col) * cellWidth + cellWidth / 2
        let originY = CGFloat(row) * cellHeight + cellHeight / 2
        
        // Main bolt along the arrow's direction (full row or full column)
        let mainStart: CGPoint
        let mainEnd: CGPoint
        if isHorizontal {
            mainStart = CGPoint(x: -10, y: originY)
            mainEnd = CGPoint(x: gridContainer.bounds.width + 10, y: originY)
        } else {
            mainStart = CGPoint(x: originX, y: -10)
            mainEnd = CGPoint(x: originX, y: gridContainer.bounds.height + 10)
        }
        
        let mainBolt = buildLightningBolt(from: mainStart, to: mainEnd, lineWidth: 2.5, color: .cyan)
        gridContainer.layer.addSublayer(mainBolt)
        
        // Animate main bolt drawing
        mainBolt.strokeEnd = 0
        let mainStroke = CABasicAnimation(keyPath: "strokeEnd")
        mainStroke.fromValue = 0
        mainStroke.toValue = 1
        mainStroke.duration = 0.25
        mainStroke.timingFunction = CAMediaTimingFunction(name: .easeOut)
        mainStroke.fillMode = .forwards
        mainStroke.isRemovedOnCompletion = false
        mainBolt.add(mainStroke, forKey: "drawMain")
        
        // Fork bolts perpendicular at each cell along the main line
        var forkBolts: [CAShapeLayer] = []
        let forkDelay: TimeInterval = 0.15  // start forks slightly after main begins
        
        DispatchQueue.main.asyncAfter(deadline: .now() + forkDelay) { [weak self] in
            guard let self = self else { return }
            
            if isHorizontal {
                // Main goes along the row; fork vertically at each column
                for c in 0..<level.gridWidth {
                    let forkX = CGFloat(c) * cellWidth + cellWidth / 2
                    let forkStart = CGPoint(x: forkX, y: originY)
                    let forkEndTop = CGPoint(x: forkX, y: -10)
                    let forkEndBottom = CGPoint(x: forkX, y: self.gridContainer.bounds.height + 10)
                    
                    let boltUp = self.buildLightningBolt(from: forkStart, to: forkEndTop, jagSegmentLength: 6, jagAmount: 3, lineWidth: 1.5, color: .cyan)
                    let boltDown = self.buildLightningBolt(from: forkStart, to: forkEndBottom, jagSegmentLength: 6, jagAmount: 3, lineWidth: 1.5, color: .cyan)
                    
                    self.gridContainer.layer.addSublayer(boltUp)
                    self.gridContainer.layer.addSublayer(boltDown)
                    forkBolts.append(contentsOf: [boltUp, boltDown])
                    
                    // Stagger each fork slightly
                    let stagger = Double(c) * 0.02
                    for bolt in [boltUp, boltDown] {
                        bolt.strokeEnd = 0
                        let stroke = CABasicAnimation(keyPath: "strokeEnd")
                        stroke.fromValue = 0
                        stroke.toValue = 1
                        stroke.duration = 0.2
                        stroke.beginTime = CACurrentMediaTime() + stagger
                        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        stroke.fillMode = .forwards
                        stroke.isRemovedOnCompletion = false
                        bolt.add(stroke, forKey: "drawFork")
                    }
                }
            } else {
                // Main goes along the column; fork horizontally at each row
                for r in 0..<level.gridHeight {
                    let forkY = CGFloat(r) * cellHeight + cellHeight / 2
                    let forkStart = CGPoint(x: originX, y: forkY)
                    let forkEndLeft = CGPoint(x: -10, y: forkY)
                    let forkEndRight = CGPoint(x: self.gridContainer.bounds.width + 10, y: forkY)
                    
                    let boltLeft = self.buildLightningBolt(from: forkStart, to: forkEndLeft, jagSegmentLength: 6, jagAmount: 3, lineWidth: 1.5, color: .cyan)
                    let boltRight = self.buildLightningBolt(from: forkStart, to: forkEndRight, jagSegmentLength: 6, jagAmount: 3, lineWidth: 1.5, color: .cyan)
                    
                    self.gridContainer.layer.addSublayer(boltLeft)
                    self.gridContainer.layer.addSublayer(boltRight)
                    forkBolts.append(contentsOf: [boltLeft, boltRight])
                    
                    let stagger = Double(r) * 0.02
                    for bolt in [boltLeft, boltRight] {
                        bolt.strokeEnd = 0
                        let stroke = CABasicAnimation(keyPath: "strokeEnd")
                        stroke.fromValue = 0
                        stroke.toValue = 1
                        stroke.duration = 0.2
                        stroke.beginTime = CACurrentMediaTime() + stagger
                        stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        stroke.fillMode = .forwards
                        stroke.isRemovedOnCompletion = false
                        bolt.add(stroke, forKey: "drawFork")
                    }
                }
            }
        }
        
        // Fade everything out and clean up
        let totalVisibleTime: TimeInterval = 0.55
        DispatchQueue.main.asyncAfter(deadline: .now() + totalVisibleTime) { [weak self] in
            let fadeDuration: TimeInterval = 0.2
            
            let fadeMain = CABasicAnimation(keyPath: "opacity")
            fadeMain.fromValue = 1.0
            fadeMain.toValue = 0.0
            fadeMain.duration = fadeDuration
            fadeMain.fillMode = .forwards
            fadeMain.isRemovedOnCompletion = false
            mainBolt.add(fadeMain, forKey: "fade")
            
            for bolt in forkBolts {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 1.0
                fade.toValue = 0.0
                fade.duration = fadeDuration
                fade.fillMode = .forwards
                fade.isRemovedOnCompletion = false
                bolt.add(fade, forKey: "fade")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration + 0.02) {
                mainBolt.removeFromSuperlayer()
                for bolt in forkBolts {
                    bolt.removeFromSuperlayer()
                }
                
                // Screen shake for dramatic effect
                let shakeAnim = CAKeyframeAnimation(keyPath: "transform.translation.x")
                shakeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                shakeAnim.duration = 0.35
                shakeAnim.values = [-6, 6, -5, 5, -3, 3, 0]
                self?.gridContainer.layer.add(shakeAnim, forKey: "surgeShake")
                
                completion()
            }
        }
    }
    
    /// Lightning Storm: Lightning bolts strike down from the top edge to random positions, each causing a 3x3 explosion.
    private func animateLightningStorm(fromRow: Int, fromCol: Int, strikePositions: [(row: Int, col: Int)], completion: @escaping () -> Void) {
        guard let level = currentLevel else { completion(); return }
        
        let cellWidth = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        
        var allBolts: [CAShapeLayer] = []
        var completedStrikes = 0
        let totalStrikes = strikePositions.count
        
        guard totalStrikes > 0 else { completion(); return }
        
        // Screen shake
        let shakeAnim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shakeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shakeAnim.duration = 0.5
        shakeAnim.values = [-8, 8, -6, 6, -4, 4, -2, 2, 0]
        gridContainer.layer.add(shakeAnim, forKey: "stormShake")
        
        for (index, pos) in strikePositions.enumerated() {
            let targetX = CGFloat(pos.col) * cellWidth + cellWidth / 2
            let targetY = CGFloat(pos.row) * cellHeight + cellHeight / 2
            
            // Lightning starts from a random x along the top edge
            let startX = targetX + CGFloat.random(in: -30...30)
            let start = CGPoint(x: startX, y: -10)
            let end = CGPoint(x: targetX, y: targetY)
            
            let bolt = buildLightningBolt(from: start, to: end, jagSegmentLength: 10, jagAmount: 6, lineWidth: 2.5, color: .cyan)
            gridContainer.layer.addSublayer(bolt)
            allBolts.append(bolt)
            
            // Stagger each strike
            let stagger = Double(index) * 0.08
            
            bolt.strokeEnd = 0
            let strokeAnim = CABasicAnimation(keyPath: "strokeEnd")
            strokeAnim.fromValue = 0
            strokeAnim.toValue = 1
            strokeAnim.duration = 0.15
            strokeAnim.beginTime = CACurrentMediaTime() + stagger
            strokeAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
            strokeAnim.fillMode = .forwards
            strokeAnim.isRemovedOnCompletion = false
            bolt.add(strokeAnim, forKey: "drawStrike")
            
            // Flash at impact point
            DispatchQueue.main.asyncAfter(deadline: .now() + stagger + 0.15) { [weak self] in
                guard let self = self else { return }
                
                // Brief white flash circle at impact
                let flash = UIView()
                let flashSize: CGFloat = max(cellWidth, cellHeight) * 2.5
                flash.frame = CGRect(x: targetX - flashSize / 2, y: targetY - flashSize / 2, width: flashSize, height: flashSize)
                flash.backgroundColor = UIColor.white.withAlphaComponent(0.5)
                flash.layer.cornerRadius = flashSize / 2
                self.gridContainer.addSubview(flash)
                
                UIView.animate(withDuration: 0.2, animations: {
                    flash.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                    flash.alpha = 0
                }, completion: { _ in
                    flash.removeFromSuperview()
                })
                
                // Haptic for each strike
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
                
                completedStrikes += 1
                if completedStrikes >= totalStrikes {
                    // All strikes landed — fade out bolts then complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        for bolt in allBolts {
                            let fade = CABasicAnimation(keyPath: "opacity")
                            fade.fromValue = 1.0
                            fade.toValue = 0.0
                            fade.duration = 0.2
                            fade.fillMode = .forwards
                            fade.isRemovedOnCompletion = false
                            bolt.add(fade, forKey: "fade")
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            for bolt in allBolts {
                                bolt.removeFromSuperlayer()
                            }
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    private func checkForMatches() {
        guard let level = currentLevel else { return }
        guard !levelCompletionTriggered else {
            // Level is completing — don't process matches but DO reset animation state
            isAnimating = false
            return
        }
        
        // First, check if there are any valid moves available
        if !hasValidMoves() {
            print("🔄 No valid moves available - triggering shuffle")
            shuffleGrid()
            return
        }
        
        // Check if a power-up was involved in the swap - if so, activate it immediately
        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
            // Bounds check - grid may have been resized by level transition
            guard r1 >= 0 && r1 < level.gridHeight && c1 >= 0 && c1 < level.gridWidth &&
                  r2 >= 0 && r2 < level.gridHeight && c2 >= 0 && c2 < level.gridWidth else {
                lastSwappedPositions = nil
                return
            }
            if let piece = gameGrid[r1][c1], piece.type != .normal {
                print("🎮 Swapped power-up detected at (\(r1),\(c1)): \(piece.type)")
                // Power-up was swapped - activate it
                lastSwappedPositions = nil
                isAnimating = true
                
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
                    
                case .ball:
                    // Ball activated via swap: animate bouncing ball
                    animateBouncingBall(fromRow: r1, fromCol: c1) { [weak self] in
                        self?.isAnimating = false
                    }
                    return
                    
                case .flame, .normal:
                    // Flame powerup at swap position (e.g. newly created by a match): don't
                    // auto-activate here — let the user trigger it manually. But we must
                    // release isAnimating so the game doesn't hang.
                    isAnimating = false
                    break
                }
                
                if !clearedTiles.isEmpty {
                    // Reset transforms and update display before highlight
                    if let (button1, button2) = swappedButtons {
                        button1.transform = .identity
                        button2.transform = .identity
                        self.swappedButtons = nil
                    }
                    movesRemaining -= 1
                    updateGridDisplay()
                    
                    // Show yellow border highlight, then clear
                    showPowerupBorderHighlight(clearedTiles) { [weak self] in
                        self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
                    }
                } else {
                    // Nothing was collected (flame/normal case) — fall through to match detection
                    // by letting execution continue past this block instead of returning early.
                    // Re-enter checkForMatches to scan for normal matches now that isAnimating is false.
                }
                
                if piece.type == .flame || piece.type == .normal {
                    // Fall through: continue to normal match detection below
                } else {
                    return
                }
            } else if let piece = gameGrid[r2][c2], piece.type != .normal {
                print("🎮 Swapped power-up detected at (\(r2),\(c2)): \(piece.type)")
                // Power-up was swapped - activate it
                lastSwappedPositions = nil
                isAnimating = true
                
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
                    
                case .ball:
                    // Ball activated via match-created powerup in swap
                    animateBouncingBall(fromRow: r2, fromCol: c2) { [weak self] in
                        self?.isAnimating = false
                    }
                    return
                    
                case .flame, .normal:
                    // Flame powerup at swap position (e.g. newly created by a match): don't
                    // auto-activate here — let the user trigger it manually. But we must
                    // release isAnimating so the game doesn't hang.
                    isAnimating = false
                    break
                }
                
                if !clearedTiles.isEmpty {
                    // Reset transforms and update display before highlight
                    if let (button1, button2) = swappedButtons {
                        button1.transform = .identity
                        button2.transform = .identity
                        self.swappedButtons = nil
                    }
                    movesRemaining -= 1
                    updateGridDisplay()
                    
                    // Show yellow border highlight, then clear
                    showPowerupBorderHighlight(clearedTiles) { [weak self] in
                        self?.clearTilesAndCascade(clearedTiles, cascadingPowerups: cascadingPowerups)
                    }
                }
                
                if piece.type == .flame || piece.type == .normal {
                    // Fall through to normal match detection below
                } else {
                    return
                }
            }
        }
        
        var matchesToRemove: Set<String> = []
        var powerUpsToCreate: [(row: Int, col: Int, type: PieceType)] = []
        
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
                    
                    // Mark all 5 tiles for removal
                    for tile in lTiles {
                        matchesToRemove.insert("\(tile.0),\(tile.1)")
                    }
                }
            }
        }
        
        // Check for T-shape patterns → ball powerup
        // A T-shape is 3 tiles in a line, with 2 perpendicular tiles extending from the CENTER tile (5 unique tiles)
        // Check all orientations: horizontal bar with stem up, down; vertical bar with stem left, right
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard gridShapeMap[row][col],
                      let centerPiece = gameGrid[row][col],
                      centerPiece.type == .normal else { continue }
                
                // T-shape with horizontal bar (3 horizontal) + vertical stem (2 tiles up or down from center)
                // Center of horizontal bar is at (row, col)
                let hLeft = col - 1
                let hRight = col + 1
                if hLeft >= 0 && hRight < level.gridWidth &&
                   gridShapeMap[row][hLeft] && gridShapeMap[row][hRight],
                   let pL = gameGrid[row][hLeft], pL.type == .normal, centerPiece.matches(pL),
                   let pR = gameGrid[row][hRight], pR.type == .normal, centerPiece.matches(pR) {
                    // Stem going down
                    let s1 = row + 1, s2 = row + 2
                    if s2 < level.gridHeight &&
                       gridShapeMap[s1][col] && gridShapeMap[s2][col],
                       let pS1 = gameGrid[s1][col], pS1.type == .normal, centerPiece.matches(pS1),
                       let pS2 = gameGrid[s2][col], pS2.type == .normal, centerPiece.matches(pS2) {
                        let tTiles = [(row, hLeft), (row, col), (row, hRight), (s1, col), (s2, col)]
                        var ballRow = row; var ballCol = col
                        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                            if tTiles.contains(where: { $0.0 == r1 && $0.1 == c1 }) { ballRow = r1; ballCol = c1 }
                            else if tTiles.contains(where: { $0.0 == r2 && $0.1 == c2 }) { ballRow = r2; ballCol = c2 }
                        }
                        powerUpsToCreate.append((row: ballRow, col: ballCol, type: .ball))
                        for tile in tTiles { matchesToRemove.insert("\(tile.0),\(tile.1)") }
                    }
                    // Stem going up
                    let u1 = row - 1, u2 = row - 2
                    if u2 >= 0 &&
                       gridShapeMap[u1][col] && gridShapeMap[u2][col],
                       let pU1 = gameGrid[u1][col], pU1.type == .normal, centerPiece.matches(pU1),
                       let pU2 = gameGrid[u2][col], pU2.type == .normal, centerPiece.matches(pU2) {
                        let tTiles = [(row, hLeft), (row, col), (row, hRight), (u1, col), (u2, col)]
                        var ballRow = row; var ballCol = col
                        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                            if tTiles.contains(where: { $0.0 == r1 && $0.1 == c1 }) { ballRow = r1; ballCol = c1 }
                            else if tTiles.contains(where: { $0.0 == r2 && $0.1 == c2 }) { ballRow = r2; ballCol = c2 }
                        }
                        powerUpsToCreate.append((row: ballRow, col: ballCol, type: .ball))
                        for tile in tTiles { matchesToRemove.insert("\(tile.0),\(tile.1)") }
                    }
                }
                
                // T-shape with vertical bar (3 vertical) + horizontal stem (2 tiles left or right from center)
                // Center of vertical bar is at (row, col)
                let vTop = row - 1
                let vBottom = row + 1
                if vTop >= 0 && vBottom < level.gridHeight &&
                   gridShapeMap[vTop][col] && gridShapeMap[vBottom][col],
                   let pT = gameGrid[vTop][col], pT.type == .normal, centerPiece.matches(pT),
                   let pB = gameGrid[vBottom][col], pB.type == .normal, centerPiece.matches(pB) {
                    // Stem going right
                    let r1c = col + 1, r2c = col + 2
                    if r2c < level.gridWidth &&
                       gridShapeMap[row][r1c] && gridShapeMap[row][r2c],
                       let pR1 = gameGrid[row][r1c], pR1.type == .normal, centerPiece.matches(pR1),
                       let pR2 = gameGrid[row][r2c], pR2.type == .normal, centerPiece.matches(pR2) {
                        let tTiles = [(vTop, col), (row, col), (vBottom, col), (row, r1c), (row, r2c)]
                        var ballRow = row; var ballCol = col
                        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                            if tTiles.contains(where: { $0.0 == r1 && $0.1 == c1 }) { ballRow = r1; ballCol = c1 }
                            else if tTiles.contains(where: { $0.0 == r2 && $0.1 == c2 }) { ballRow = r2; ballCol = c2 }
                        }
                        powerUpsToCreate.append((row: ballRow, col: ballCol, type: .ball))
                        for tile in tTiles { matchesToRemove.insert("\(tile.0),\(tile.1)") }
                    }
                    // Stem going left
                    let l1c = col - 1, l2c = col - 2
                    if l2c >= 0 &&
                       gridShapeMap[row][l1c] && gridShapeMap[row][l2c],
                       let pL1 = gameGrid[row][l1c], pL1.type == .normal, centerPiece.matches(pL1),
                       let pL2 = gameGrid[row][l2c], pL2.type == .normal, centerPiece.matches(pL2) {
                        let tTiles = [(vTop, col), (row, col), (vBottom, col), (row, l1c), (row, l2c)]
                        var ballRow = row; var ballCol = col
                        if let ((r1, c1), (r2, c2)) = lastSwappedPositions {
                            if tTiles.contains(where: { $0.0 == r1 && $0.1 == c1 }) { ballRow = r1; ballCol = c1 }
                            else if tTiles.contains(where: { $0.0 == r2 && $0.1 == c2 }) { ballRow = r2; ballCol = c2 }
                        }
                        powerUpsToCreate.append((row: ballRow, col: ballCol, type: .ball))
                        for tile in tTiles { matchesToRemove.insert("\(tile.0),\(tile.1)") }
                    }
                }
            }
        }
        
        if !matchesToRemove.isEmpty {
            // Keep isAnimating = true for the entire match→cascade→gravity chain so user
            // taps cannot accidentally activate (and silently destroy) powerup tiles while
            // the board is mid-animation.  Only set false again in the no-match branch.
            isAnimating = true
            
            // PRIORITIZE POWERUPS: ball > flame > rocket > arrow > bomb
            // If multiple powerups target the same location, keep only the highest priority
            var prioritizedPowerups: [(row: Int, col: Int, type: PieceType)] = []
            var powerupLocations: [String: PieceType] = [:]  // Track (row,col) -> highest priority type
            
            for powerup in powerUpsToCreate {
                let key = "\(powerup.row),\(powerup.col)"
                let existingType = powerupLocations[key]
                
                // Determine priority: ball (5) > flame (4) > rocket (3) > arrow (2) > bomb (1) > nil (0)
                func typePriority(_ t: PieceType) -> Int {
                    switch t {
                    case .ball: return 5
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
            // Save pending cascades instead of discarding — powerups that were already removed
            // from the grid during a prior cascade step must still fire.  Merge them with any
            // powerups caught in this match so they all activate in sequence.
            let savedPendingCascades = pendingCascades
            pendingCascades = []
            
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
                guard let self = self else { return }
                
                // Collect any existing powerups caught in the match BEFORE clearing them
                // These should cascade (activate) rather than being silently destroyed
                var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
                let powerUpPositions = Set(powerUpsToCreate.map { "\($0.row),\($0.col)" })
                for posString in matchesToRemove {
                    // Skip positions where we're about to place a new powerup
                    if powerUpPositions.contains(posString) { continue }
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2, let piece = self.gameGrid[parts[0]][parts[1]], piece.type != .normal {
                        cascadingPowerups.append((row: parts[0], col: parts[1], type: piece.type))
                    }
                }
                
                // Now that animation is complete, remove the pieces from grid
                for posString in matchesToRemove {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self.hitTile(row: parts[0], col: parts[1])
                    }
                }
                
                // Create power-ups
                for powerUp in powerUpsToCreate {
                    self.gameGrid[powerUp.row][powerUp.col] = GamePiece(
                        itemId: "power_up",
                        colorIndex: 0,
                        row: powerUp.row,
                        col: powerUp.col,
                        type: powerUp.type
                    )
                    // Sparkle burst to celebrate the new powerup
                    self.animatePowerupCreationSparkle(row: powerUp.row, col: powerUp.col)
                }
                
                // Do NOT reset isAnimating here — the cascade/gravity chain must complete
                // before user input is accepted again (prevents accidental powerup activation).
                // isAnimating will be set to false in the "no match found" branch once the
                // board has fully settled.

                // Update score/moves display and check for level completion now that tiles
                // have been scored.  (activateCascadingPowerups calls updateUI internally,
                // but the gravity-only path doesn't, so call it here for both paths.)
                self.updateUI()

                // If powerups were caught in the match OR were queued from a prior cascade
                // step, activate them all in sequence.
                let allCascades = cascadingPowerups + savedPendingCascades
                if !allCascades.isEmpty {
                    self.activateCascadingPowerups(allCascades)
                } else {
                    // applyGravity() calls updateGridDisplay() internally — no need to call it here
                    self.applyGravity()
                }
            }
        } else {
            // No match found

            // If there are pending cascades queued (from sequential powerup cascade steps),
            // process them now that the board has settled with no new matches.
            if !pendingCascades.isEmpty {
                let toProcess = pendingCascades
                pendingCascades = []
                activateCascadingPowerups(toProcess)
                return
            }

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
        guard let level = currentLevel else {
            completion()
            return
        }
        
        let poofDuration: TimeInterval = 0.18
        
        for posString in affectedTiles {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            guard parts.count == 2 else { continue }
            let row = parts[0]
            let col = parts[1]
            guard row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth else { continue }
            guard let button = gridButtons[row][col] else { continue }
            
            // Convert button center to gridContainer coordinate space
            let centerInContainer = button.superview?.convert(button.center, to: gridContainer) ?? button.center
            let particleCount = 5
            let particleSize: CGFloat = CGFloat.random(in: 6...10)
            
            for i in 0..<particleCount {
                let particle = UIView()
                particle.bounds = CGRect(x: 0, y: 0, width: particleSize, height: particleSize)
                particle.center = centerInContainer
                particle.layer.cornerRadius = particleSize / 2
                particle.backgroundColor = UIColor.white.withAlphaComponent(0.8)
                particle.alpha = 0.9
                gridContainer.addSubview(particle)
                
                // Each particle drifts in a different direction
                let angle = (CGFloat.pi * 2 / CGFloat(particleCount)) * CGFloat(i) + CGFloat.random(in: -0.3...0.3)
                let distance: CGFloat = CGFloat.random(in: 10...18)
                let dx = cos(angle) * distance
                let dy = sin(angle) * distance
                
                UIView.animate(withDuration: poofDuration, delay: 0, options: .curveEaseOut) {
                    particle.center = CGPoint(x: centerInContainer.x + dx, y: centerInContainer.y + dy)
                    particle.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
                    particle.alpha = 0
                } completion: { _ in
                    particle.removeFromSuperview()
                }
            }
        }
        
        // Call completion after the poof finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + poofDuration + 0.02) {
            completion()
        }
    }
    
    private func animateMatchedPieces(_ matchesToRemove: Set<String>, completion: @escaping () -> Void) {
        guard !matchesToRemove.isEmpty, let level = currentLevel else {
            completion()
            return
        }
        
        let allButtons = matchesToRemove.compactMap { posString -> UIButton? in
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            guard parts.count == 2 else { return nil }
            let row = parts[0]
            let col = parts[1]
            guard row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth else { return nil }
            return gridButtons[row][col]
        }
        
        guard !allButtons.isEmpty else {
            completion()
            return
        }
        
        // Launch smoke poof and scale/fade simultaneously — no stacked asyncAfter delays
        let totalDuration: TimeInterval = 0.22
        
        for posString in matchesToRemove {
            let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
            guard parts.count == 2 else { continue }
            let row = parts[0]
            let col = parts[1]
            guard row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth else { continue }
            guard let button = gridButtons[row][col] else { continue }
            
            // Convert button center to gridContainer coordinate space
            let centerInContainer = button.superview?.convert(button.center, to: gridContainer) ?? button.center
            
            // Smoke poof particles (fire and forget)
            let particleCount = 5
            let particleSize: CGFloat = CGFloat.random(in: 6...10)
            for i in 0..<particleCount {
                let particle = UIView()
                particle.bounds = CGRect(x: 0, y: 0, width: particleSize, height: particleSize)
                particle.center = centerInContainer
                particle.layer.cornerRadius = particleSize / 2
                particle.backgroundColor = UIColor.white.withAlphaComponent(0.8)
                particle.alpha = 0.9
                gridContainer.addSubview(particle)
                
                let angle = (CGFloat.pi * 2 / CGFloat(particleCount)) * CGFloat(i) + CGFloat.random(in: -0.3...0.3)
                let distance: CGFloat = CGFloat.random(in: 10...18)
                let dx = cos(angle) * distance
                let dy = sin(angle) * distance
                
                UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
                    particle.center = CGPoint(x: centerInContainer.x + dx, y: centerInContainer.y + dy)
                    particle.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
                    particle.alpha = 0
                } completion: { _ in
                    particle.removeFromSuperview()
                }
            }
            
            // Pop-then-shrink scale animation (starts immediately, concurrent with poof)
            let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnim.values = [1.0, 1.12, 0.01]
            scaleAnim.keyTimes = [0, 0.3, 1.0]
            scaleAnim.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn)
            ]
            scaleAnim.duration = totalDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            button.layer.add(scaleAnim, forKey: "matchPop")
            
            // Fade out starts slightly after scale begins
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 1.0
            fadeAnim.toValue = 0.0
            fadeAnim.beginTime = CACurrentMediaTime() + 0.06
            fadeAnim.duration = 0.14
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            button.layer.add(fadeAnim, forKey: "matchFade")
        }
        
        // Single timer — no nested asyncAfter
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            // Clean up: remove CA animations and reset visual state
            for posString in matchesToRemove {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                guard parts.count == 2 else { continue }
                let row = parts[0]
                let col = parts[1]
                guard row >= 0 && row < level.gridHeight && col >= 0 && col < level.gridWidth else { continue }
                if let button = self.gridButtons[row][col] {
                    button.layer.removeAnimation(forKey: "matchPop")
                    button.layer.removeAnimation(forKey: "matchFade")
                    button.layer.opacity = 1.0
                }
            }
            completion()
        }
    }
    
    private func applyGravity() {
        guard let level = currentLevel else { return }
        
        // Sweep any stray animation subviews (poof particles, flame labels, beam views)
        // that should have been removed by animation completions but may have leaked
        var keepViews: Set<ObjectIdentifier> = [ObjectIdentifier(gridStackView)]
        let armorViews = Set(armorBorderViews.flatMap { $0 }.compactMap { $0.map { ObjectIdentifier($0) } })
        let blankViews = Set(blankTileOverlays.map { ObjectIdentifier($0) })
        keepViews.formUnion(armorViews)
        keepViews.formUnion(blankViews)
        keepViews.formUnion(activeAnimationViews)
        for subview in gridContainer.subviews {
            if !keepViews.contains(ObjectIdentifier(subview)) {
                subview.removeFromSuperview()
            }
        }
        
        // Reset all button transforms before gravity to clear any leftover scale/rotation from animations
        resetAllButtonTransforms()
        
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

                    if distance != 0 {
                        movedPieces.insert("\(targetRow),\(col)")
                        fallDistances["\(targetRow),\(col)"] = distance
                    }

                    targetRow -= 1
                }
            }
        }
        
        // STEP 2: Refill empty spaces with NEW pieces using stacked start positions.
        // All new pieces in a column share the same fall distance so they land simultaneously.
        let gridHasValidMoves = hasValidMoves()
        for col in 0..<level.gridWidth {
            var emptyRows: [Int] = []
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col] && gameGrid[row][col] == nil {
                    emptyRows.append(row)
                }
            }
            let n = emptyRows.count
            for (idx, row) in emptyRows.enumerated() {
                let newPiece = generateNonMatchingPiece(row: row, col: col, level: level, avoidMatches: gridHasValidMoves)
                gameGrid[row][col] = newPiece
                if !movedPieces.contains("\(row),\(col)") {
                    movedPieces.insert("\(row),\(col)")
                    let slotFromBottom = n - 1 - idx  // 0 = bottommost empty row
                    fallDistances["\(row),\(col)"] = row + slotFromBottom + 1
                    newPieces.insert("\(row),\(col)")
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
                    // EXISTING pieces: distance is negative (fell down), so fallDistance is negative,
                    // placing button ABOVE its final position. Animation to .identity drops it down.
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

        let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let fallSpeed: CGFloat = 600   // pixels per second
        let minDuration: TimeInterval = 0.25
        let maxDuration: TimeInterval = 0.45

        var maxEndTime: TimeInterval = 0

        for col in 0..<level.gridWidth {
            for row in 0..<level.gridHeight {
                let key = "\(row),\(col)"
                guard movedPieces.contains(key),
                      gridShapeMap[row][col],
                      let button = gridButtons[row][col],
                      gameGrid[row][col] != nil else { continue }

                let distance = fallDistances[key] ?? 0
                let fallPixels = cellHeight * CGFloat(distance)
                let duration = min(max(Double(fallPixels / fallSpeed), minDuration), maxDuration)
                if duration > maxEndTime { maxEndTime = duration }

                UIView.animate(
                    withDuration: duration,
                    delay: 0,
                    options: [.curveEaseIn],
                    animations: {
                        button.transform = .identity
                        button.alpha = 1.0
                    },
                    completion: { _ in
                        guard distance > 0 else { return }
                        // Squash-on-land: briefly squish flat then snap back
                        UIView.animate(withDuration: 0.07, delay: 0, options: [.curveEaseOut]) {
                            button.transform = CGAffineTransform(scaleX: 1.18, y: 0.65)
                        } completion: { _ in
                            UIView.animate(withDuration: 0.09, delay: 0, options: [.curveEaseInOut]) {
                                button.transform = .identity
                            }
                        }
                    }
                )
            }
        }

        // Wait for fall + squash to finish before triggering next action
        let completionDelay = max(maxEndTime + 0.22, 0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
            completion()
        }
    }
    
    private func updateGridDisplay() {
        guard let level = currentLevel else { return }
        // Skip display updates while gravity is setting up start transforms
        guard !isApplyingGravity else { return }
        
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
                        // Vertical arrow pulse up-down
                        if button.layer.animation(forKey: "arrowPulse") == nil {
                            let nudge = CAKeyframeAnimation(keyPath: "transform.translation.y")
                            nudge.values = [0, -2, 0, 2, 0]
                            nudge.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
                            nudge.duration = 0.9
                            nudge.repeatCount = .infinity
                            nudge.beginTime = CACurrentMediaTime() + Double(row) * 0.1
                            button.layer.add(nudge, forKey: "arrowPulse")
                        }
                    case .horizontalArrow:
                        button.setTitle("↔️", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                        // Horizontal arrow pulse left-right
                        if button.layer.animation(forKey: "arrowPulse") == nil {
                            let nudge = CAKeyframeAnimation(keyPath: "transform.translation.x")
                            nudge.values = [0, -2, 0, 2, 0]
                            nudge.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
                            nudge.duration = 0.9
                            nudge.repeatCount = .infinity
                            nudge.beginTime = CACurrentMediaTime() + Double(col) * 0.1
                            button.layer.add(nudge, forKey: "arrowPulse")
                        }
                    case .bomb:
                        button.setTitle("💣", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                        // Bomb tick-wobble animation
                        if button.layer.animation(forKey: "bombWobble") == nil {
                            let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                            wobble.values = [0, 0.12, -0.10, 0.07, -0.05, 0]
                            wobble.keyTimes = [0, 0.2, 0.45, 0.65, 0.82, 1.0]
                            wobble.duration = 1.6
                            wobble.repeatCount = .infinity
                            wobble.beginTime = CACurrentMediaTime() + Double(row * 3 + col) * 0.18
                            button.layer.add(wobble, forKey: "bombWobble")
                        }
                    case .flame:
                        button.setTitle("🔥", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                        // Flame flicker animation
                        if button.layer.animation(forKey: "flameFlicker") == nil {
                            let flicker = CAKeyframeAnimation(keyPath: "transform")
                            flicker.values = [
                                NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
                                NSValue(caTransform3D: CATransform3DConcat(
                                    CATransform3DMakeScale(1.08, 0.94, 1.0),
                                    CATransform3DMakeRotation(0.06, 0, 0, 1))),
                                NSValue(caTransform3D: CATransform3DConcat(
                                    CATransform3DMakeScale(0.95, 1.06, 1.0),
                                    CATransform3DMakeRotation(-0.04, 0, 0, 1))),
                                NSValue(caTransform3D: CATransform3DConcat(
                                    CATransform3DMakeScale(1.05, 0.97, 1.0),
                                    CATransform3DMakeRotation(0.03, 0, 0, 1))),
                                NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0))
                            ]
                            flicker.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
                            flicker.duration = 0.4
                            flicker.repeatCount = .infinity
                            flicker.autoreverses = false
                            button.layer.add(flicker, forKey: "flameFlicker")
                        }
                    case .rocket:
                        button.setTitle("🌟", for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                        // Rocket idle spin
                        if button.layer.animation(forKey: "rocketSpin") == nil {
                            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                            spin.fromValue = 0
                            spin.toValue = CGFloat.pi * 2
                            spin.duration = 2.4
                            spin.repeatCount = .infinity
                            spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                            spin.beginTime = CACurrentMediaTime() + Double(col) * 0.3
                            button.layer.add(spin, forKey: "rocketSpin")
                        }
                    case .ball:
                        // Use the piece's fixed emoji index so it doesn't change when the piece moves
                        button.setTitle(GamePiece.ballEmojis[piece.ballEmojiIndex], for: .normal)
                        button.setImage(nil, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: powerupFontSize)
                        button.backgroundColor = .clear
                        // Ball bounce animation
                        if button.layer.animation(forKey: "ballBounce") == nil {
                            let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
                            bounce.values = [0, -3, 0, -1.5, 0]
                            bounce.keyTimes = [0, 0.3, 0.5, 0.75, 1.0]
                            bounce.duration = 0.8
                            bounce.repeatCount = .infinity
                            button.layer.add(bounce, forKey: "ballBounce")
                        }
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
                        button.layer.borderWidth = 2
                    } else {
                        button.layer.borderWidth = 0
                    }
                    
                    // If armored (shielded), show the level's shield emoji — hides actual content for mystery/strategy
                    if armorGrid[row][col] >= 1 {
                        button.setImage(nil, for: .normal)
                        let shieldSize = max(14, min(32, 360 / CGFloat(max(level.gridWidth, level.gridHeight))))
                        button.setTitle(levelShieldEmoji, for: .normal)
                        button.titleLabel?.font = UIFont.systemFont(ofSize: shieldSize)
                        button.titleLabel?.adjustsFontSizeToFitWidth = false
                        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.28)
                    }

                    // Update armor overlay visibility (static overlays in gridContainer)
                    if row < armorBorderViews.count && col < armorBorderViews[row].count {
                        if armorGrid[row][col] >= 1 {
                            armorBorderViews[row][col]?.isHidden = false
                            // Always show hit count numerically — even 1 so player knows exactly how many hits remain
                            armorOverlays[row][col]?.isHidden = false
                            armorOverlays[row][col]?.text = "\(armorGrid[row][col])"
                        } else {
                            armorBorderViews[row][col]?.isHidden = true
                            armorOverlays[row][col]?.isHidden = true
                        }
                    }
                } else {
                    button.backgroundColor = darkBg
                    button.setTitle("", for: .normal)
                    button.setImage(nil, for: .normal)
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
        pauseSessionTimer()   // flush session seconds into totalElapsed
        saveGameState()       // persists mid-level grid + totalElapsed
        print("🎮 Exiting match game - returning to dashboard")
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
        
        // Clear old grid (subviews AND any leftover animation sublayers)
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        gridContainer.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
        gridStackView.removeFromSuperview()
        gridStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Start new level
        startLevel(levelId)
        
        // Update button text
        levelSelectorButton.setTitle("Level \(levelId) ▼", for: .normal)
    }
    
    private func saveGameState() {
        // Flush current session elapsed into totalElapsed before saving
        if let start = timerSessionStart {
            totalElapsed += Date().timeIntervalSince(start)
            timerSessionStart = Date()   // reset reference so we don't double-count
        }
        UserDefaults.standard.set(currentLevelId, forKey: "matchGameCurrentLevel")
        UserDefaults.standard.set(score, forKey: "matchGameScore_\(currentLevelId)")
        UserDefaults.standard.set(unlockedLevels, forKey: "matchGameUnlockedLevels")
        UserDefaults.standard.set(totalElapsed, forKey: "matchGameTotalTime")
        // Save mid-level grid state
        saveMidLevelState()
        print("💾 Game state saved: Level \(currentLevelId), Score \(score), TotalTime \(Int(totalElapsed))s")
    }
    
    private func loadSavedState() {
        let savedLevel = UserDefaults.standard.integer(forKey: "matchGameCurrentLevel")
        if savedLevel > 0 {
            currentLevelId = savedLevel
            levelSelectorButton.setTitle("Level \(savedLevel) ▼", for: .normal)
        }
        let savedScore = UserDefaults.standard.integer(forKey: "matchGameScore_\(currentLevelId)")
        if savedScore > 0 { score = savedScore }
        if let saved = UserDefaults.standard.array(forKey: "matchGameUnlockedLevels") as? [Int] {
            unlockedLevels = saved
        }
        // Restore total elapsed time
        totalElapsed = UserDefaults.standard.double(forKey: "matchGameTotalTime")
    }
    
    // MARK: - Session / Total Timer

    private func startSessionTimer() {
        guard sessionTimer == nil else { return }
        sessionElapsed = 0
        timerSessionStart = Date()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
    }

    private func pauseSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        if let start = timerSessionStart {
            totalElapsed += Date().timeIntervalSince(start)
            timerSessionStart = nil
        }
        UserDefaults.standard.set(totalElapsed, forKey: "matchGameTotalTime")
    }

    private func tickTimer() {
        if let start = timerSessionStart {
            sessionElapsed = Date().timeIntervalSince(start)
        }
        totalElapsed = (UserDefaults.standard.double(forKey: "matchGameTotalTime"))
            + sessionElapsed
        updateTimerLabels()
    }

    private func updateTimerLabels() {
        sessionTimeLabel.text = "Session  \(formatTime(sessionElapsed))"
        let saved = UserDefaults.standard.double(forKey: "matchGameTotalTime")
        totalTimeLabel.text  = "Total  \(formatTime(saved + sessionElapsed))"
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Mid-Level State Persistence

    /// Saves the current board so the player can resume exactly where they left off.
    private func saveMidLevelState() {
        // Never save a failed/terminal state — if moves are exhausted there's nothing to restore
        guard movesRemaining > 0 else { return }
        let key = "matchGameMidLevel_\(currentLevelId)"
        // Encode each cell as "itemId|typeRaw|colorIndex|ballEmojiIndex", empty string for nil
        var flat: [String] = []
        for row in gameGrid {
            for piece in row {
                if let p = piece {
                    flat.append("\(p.itemId)|\(pieceTypeRaw(p.type))|\(p.colorIndex)|\(p.ballEmojiIndex)")
                } else {
                    flat.append("")
                }
            }
        }
        // JSON-encode the flat string array — avoids plist cast ambiguity on read-back
        if let data = try? JSONEncoder().encode(flat) {
            UserDefaults.standard.set(data, forKey: key)
        }
        // Armor, moves, score stored as primitives (plist-safe)
        UserDefaults.standard.set(armorGrid.flatMap { $0 }, forKey: "\(key)_armor")
        UserDefaults.standard.set(movesRemaining, forKey: "\(key)_moves")
        UserDefaults.standard.set(score, forKey: "\(key)_score")
        UserDefaults.standard.set(gameGrid.count, forKey: "\(key)_rows")
        UserDefaults.standard.set(gameGrid.first?.count ?? 0, forKey: "\(key)_cols")
        print("💾 Mid-level grid saved: level \(currentLevelId), \(flat.filter { !$0.isEmpty }.count) pieces")
    }

    private func restoreMidLevelState(levelId: Int) -> Bool {
        let key = "matchGameMidLevel_\(levelId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let flat = try? JSONDecoder().decode([String].self, from: data),
              let level = currentLevel else {
            print("📥 No saved mid-level data for level \(levelId)")
            return false
        }
        let savedRows = UserDefaults.standard.integer(forKey: "\(key)_rows")
        let savedCols = UserDefaults.standard.integer(forKey: "\(key)_cols")
        guard savedRows == level.gridHeight,
              savedCols == level.gridWidth,
              flat.count == level.gridHeight * level.gridWidth else {
            print("⚠️ Saved grid size \(savedRows)x\(savedCols) doesn't match level \(level.gridHeight)x\(level.gridWidth) — discarding")
            clearMidLevelState(levelId: levelId)
            return false
        }
        let armorRaw = UserDefaults.standard.array(forKey: "\(key)_armor") as? [Int] ?? []
        let savedMoves = UserDefaults.standard.integer(forKey: "\(key)_moves")
        let savedScore = UserDefaults.standard.integer(forKey: "\(key)_score")

        var powerupCount = 0
        for r in 0..<level.gridHeight {
            for c in 0..<level.gridWidth {
                let idx = r * level.gridWidth + c
                // Always restore armor value for every cell, regardless of whether tile is present
                if idx < armorRaw.count {
                    armorGrid[r][c] = armorRaw[idx]
                }
                let cell = flat[idx]
                if cell.isEmpty {
                    gameGrid[r][c] = nil
                } else {
                    let parts = cell.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                    guard parts.count == 4,
                          let typeRaw   = Int(parts[1]),
                          let colorIdx  = Int(parts[2]),
                          let ballIdx   = Int(parts[3]) else { continue }
                    let itemId = parts[0]
                    let piece = GamePiece(itemId: itemId, colorIndex: colorIdx, row: r, col: c)
                    piece.type = pieceTypeFromRaw(typeRaw)
                    piece.ballEmojiIndex = ballIdx
                    gameGrid[r][c] = piece
                    if piece.type != .normal { powerupCount += 1 }
                }
            }
        }
        movesRemaining = savedMoves > 0 ? savedMoves : level.movesAllowed
        score = savedScore
        print("📥 Restored level \(levelId): \(powerupCount) powerups, moves=\(movesRemaining), score=\(score)")
        return true
    }

    /// Clears the saved mid-level state (call on level completion or when starting fresh).
    private func clearMidLevelState(levelId: Int) {
        let key = "matchGameMidLevel_\(levelId)"
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: "\(key)_armor")
        UserDefaults.standard.removeObject(forKey: "\(key)_moves")
        UserDefaults.standard.removeObject(forKey: "\(key)_score")
    }

    private func pieceTypeRaw(_ t: PieceType) -> Int {
        switch t {
        case .normal: return 0
        case .horizontalArrow: return 1
        case .verticalArrow: return 2
        case .bomb: return 3
        case .flame: return 4
        case .rocket: return 5
        case .ball: return 6
        }
    }

    private func pieceTypeFromRaw(_ r: Int) -> PieceType {
        switch r {
        case 1: return .horizontalArrow
        case 2: return .verticalArrow
        case 3: return .bomb
        case 4: return .flame
        case 5: return .rocket
        case 6: return .ball
        default: return .normal
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
            // Build failure message
            let shieldsRemaining = self.armorGrid.flatMap { $0 }.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
            let scoreMet = self.score >= level.scoreTarget
            let hasShieldsLeft = shieldsRemaining > 0
            
            var message: String
            if !scoreMet && hasShieldsLeft {
                message = "You needed \(level.scoreTarget - self.score) more points and had \(shieldsRemaining) shield\(shieldsRemaining == 1 ? "" : "s") remaining."
            } else if !scoreMet {
                message = "You needed \(level.scoreTarget - self.score) more points to reach the target score of \(level.scoreTarget)."
            } else if hasShieldsLeft {
                message = "You reached the target score, but \(shieldsRemaining) shield\(shieldsRemaining == 1 ? " was" : "s were") still standing."
            } else {
                message = "You ran out of moves before completing the level."
            }
            
            // Show restart alert
            let alert = UIAlertController(title: "Out of Moves!", message: message, preferredStyle: .alert)
            
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

                // Clear any saved mid-level snapshot so we start truly fresh
                self.clearMidLevelState(levelId: level.id)

                // Track retry count for progressive help
                if self.retryLevelId != level.id {
                    self.retryLevelId = level.id
                    self.retryCount = 0
                }
                self.retryCount += 1

                // Restart the level, then drop in progressive bonus help
                self.score = 0
                self.startLevel(level.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.dropInProgressiveHelp()
                }
            })
            
            alert.addAction(UIAlertAction(title: "Exit", style: .cancel) { _ in
                // Wipe the failed board snapshot so reopening starts the level fresh
                self.clearMidLevelState(levelId: level.id)
                self.exitGame()
            })
            
            self.present(alert, animated: true)
        }
    }
    
    /// Progressive help system: each consecutive retry on the same level adds more powerups and bonus moves.
    /// Retry 1 → 2 flames | Retry 2 → 2 flames + bomb + 1 move | Retry 3 → 3 flames + bomb + rocket + 3 moves
    /// Retry 4 → 3 flames + 2 bombs + rocket + ball + 5 moves | Retry 5+ → 4 flames + 2 bombs + rocket + ball + 8 moves
    private func dropInProgressiveHelp() {
        guard let level = currentLevel else { return }

        // Determine tier from retry count
        let tier = min(retryCount, 5)

        struct HelpTier {
            let powerups: [PieceType]
            let bonusMoves: Int
            let bannerText: String
        }

        let tiers: [Int: HelpTier] = [
            1: HelpTier(powerups: [.flame, .flame],
                        bonusMoves: 5,
                        bannerText: "🔥 Bonus Powerups! +5 Moves"),
            2: HelpTier(powerups: [.flame, .flame, .bomb],
                        bonusMoves: 10,
                        bannerText: "💣 Extra Help! +10 Moves"),
            3: HelpTier(powerups: [.flame, .flame, .flame, .bomb, .rocket],
                        bonusMoves: 15,
                        bannerText: "🚀 Power Surge! +15 Moves"),
            4: HelpTier(powerups: [.flame, .flame, .flame, .bomb, .bomb, .rocket, .ball],
                        bonusMoves: 20,
                        bannerText: "⚡ Mega Boost! +20 Moves"),
            5: HelpTier(powerups: [.flame, .flame, .flame, .flame, .bomb, .bomb, .rocket, .ball],
                        bonusMoves: 25,
                        bannerText: "🌟 Maximum Power! +25 Moves"),
            6: HelpTier(powerups: [.flame, .verticalArrow, .horizontalArrow, .flame, .bomb, .rocket, .rocket, .ball],
                        bonusMoves: 50,
                        bannerText: "🌟 Extra Maximum Power! +50 Moves"),
            7: HelpTier(powerups: [.flame, .verticalArrow, .horizontalArrow, .flame, .flame, .bomb, .rocket, .ball],
                        bonusMoves: 100,
                        bannerText: "🌟 Super Extra Maximum Power! +100 Moves"),
        ]

        guard let help = tiers[tier] else { return }

        // Apply bonus moves immediately
        if help.bonusMoves > 0 {
            movesRemaining += help.bonusMoves
            updateUI()
        }

        // Show a brief animated banner describing what's been added
        showRetryHelpBanner(help.bannerText)

        // Gather all valid normal tiles, shuffle them, pick first N
        var candidates: [(row: Int, col: Int)] = []
        for r in 0..<level.gridHeight {
            for c in 0..<level.gridWidth {
                if gridShapeMap[r][c], let piece = gameGrid[r][c], piece.type == .normal {
                    candidates.append((r, c))
                }
            }
        }
        candidates.shuffle()

        let dropCount = min(help.powerups.count, candidates.count)
        let chosenPositions = Array(candidates.prefix(dropCount))

        let gridH = gridContainer.bounds.height
        let gridW = gridContainer.bounds.width
        let rowH = gridH / CGFloat(level.gridHeight)
        let colW = gridW / CGFloat(level.gridWidth)

        for (idx, pos) in chosenPositions.enumerated() {
            let powerupType = help.powerups[idx]
            let (r, c) = (pos.row, pos.col)
            let landX = CGFloat(c) * colW + colW / 2
            let landY = CGFloat(r) * rowH + rowH / 2

            let emoji = emojiForPowerupType(powerupType)
            let dropLabel = UILabel()
            dropLabel.text = emoji
            let sz = min(colW, rowH) * 1.15
            dropLabel.font = UIFont.systemFont(ofSize: sz)
            dropLabel.textAlignment = .center
            // Start above the grid, slightly staggered horizontally
            let offsetX = CGFloat(idx % 3 - 1) * colW * 0.25
            dropLabel.frame = CGRect(x: landX - sz / 2 + offsetX, y: -sz * 2.5, width: sz, height: sz)
            gridContainer.addSubview(dropLabel)
            activeAnimationViews.insert(ObjectIdentifier(dropLabel))

            let delay = Double(idx) * 0.14
            UIView.animate(withDuration: 0.55, delay: delay,
                           usingSpringWithDamping: 0.55, initialSpringVelocity: 0.9,
                           options: [], animations: {
                dropLabel.center = CGPoint(x: landX, y: landY)
            }, completion: { [weak self] _ in
                guard let self = self else { return }
                // Plant the powerup in the grid
                if let piece = self.gameGrid[r][c] {
                    piece.type = powerupType
                    if powerupType == .ball {
                        piece.ballEmojiIndex = Int.random(in: 0..<GamePiece.ballEmojis.count)
                    }
                    self.updateGridDisplay()
                }
                dropLabel.removeFromSuperview()
                self.activeAnimationViews.remove(ObjectIdentifier(dropLabel))
                // Pulse the button to highlight the new powerup
                if let btn = self.gridButtons[r][c] {
                    UIView.animate(withDuration: 0.12, animations: {
                        btn.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
                    }, completion: { _ in
                        UIView.animate(withDuration: 0.12) { btn.transform = .identity }
                    })
                }
            })
        }
    }

    /// Returns the display emoji for a powerup type, used in drop animation labels.
    private func emojiForPowerupType(_ type: PieceType) -> String {
        switch type {
        case .flame:          return "🔥"
        case .bomb:           return "💣"
        case .horizontalArrow: return "➡️"
        case .verticalArrow:  return "⬆️"
        case .rocket:         return "🚀"
        case .ball:           return GamePiece.ballEmojis[Int.random(in: 0..<GamePiece.ballEmojis.count)]
        default:              return "⭐"
        }
    }

    /// Shows a brief animated banner at the top of the grid describing the retry help tier.
    private func showRetryHelpBanner(_ text: String) {
        // Container provides rounded background + padding
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.88)
        container.layer.cornerRadius = 10
        container.layer.masksToBounds = true
        container.alpha = 0
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
        ])

        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.topAnchor.constraint(equalTo: gridContainer.topAnchor, constant: 8),
            container.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
        ])
        // Force layout so constraints are resolved
        view.layoutIfNeeded()

        UIView.animate(withDuration: 0.3, animations: {
            container.alpha = 1
            container.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15, animations: {
                container.transform = .identity
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIView.animate(withDuration: 0.4, animations: { container.alpha = 0 }) { _ in
                    container.removeFromSuperview()
                }
            }
        })
    }

    /// After a failed retry, two rocket powerups fly in from off-screen and land on random adjacent tiles.
    /// Kept for backward compatibility — now superseded by dropInProgressiveHelp().
    private func dropInBonusRockets() {
        guard let level = currentLevel else { return }

        // Pick two adjacent occupied normal tiles (prefer middle rows so the animation is visible)
        var candidates: [(row: Int, col: Int)] = []
        let midRow = level.gridHeight / 2
        for r in stride(from: midRow, through: 0, by: -1) {
            for c in 0..<(level.gridWidth - 1) {
                if gridShapeMap[r][c] && gridShapeMap[r][c+1],
                   let p1 = gameGrid[r][c], p1.type == .normal,
                   let p2 = gameGrid[r][c+1], p2.type == .normal {
                    candidates.append((r, c))
                }
            }
            if !candidates.isEmpty { break }
        }
        // Fallback: any two valid adjacent cells
        if candidates.isEmpty {
            for r in 0..<level.gridHeight {
                for c in 0..<(level.gridWidth - 1) {
                    if gridShapeMap[r][c] && gridShapeMap[r][c+1] {
                        candidates.append((r, c))
                    }
                }
            }
        }
        guard let chosen = candidates.randomElement() else { return }
        let positions = [(chosen.row, chosen.col), (chosen.row, chosen.col + 1)]

        let gridH = gridContainer.bounds.height
        let gridW = gridContainer.bounds.width
        let rowH = gridH / CGFloat(level.gridHeight)
        let colW = gridW / CGFloat(level.gridWidth)

        for (idx, (r, c)) in positions.enumerated() {
            let landX = CGFloat(c) * colW + colW / 2
            let landY = CGFloat(r) * rowH + rowH / 2

            // Create a flying rocket label
            let rocketLabel = UILabel()
            rocketLabel.text = "🔥"
            let sz = min(colW, rowH) * 1.1
            rocketLabel.font = UIFont.systemFont(ofSize: sz)
            rocketLabel.textAlignment = .center
            rocketLabel.frame = CGRect(x: landX - sz/2, y: -sz * 2, width: sz, height: sz)
            // Stagger the two slightly
            rocketLabel.frame.origin.x += CGFloat(idx == 0 ? -sz * 0.3 : sz * 0.3)
            gridContainer.addSubview(rocketLabel)
            activeAnimationViews.insert(ObjectIdentifier(rocketLabel))

            let delay = Double(idx) * 0.18
            UIView.animate(withDuration: 0.55, delay: delay,
                           usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
                           options: [], animations: {
                rocketLabel.center = CGPoint(x: landX, y: landY)
            }, completion: { [weak self] _ in
                guard let self = self else { return }
                // Plant the rocket in the grid
                if let piece = self.gameGrid[r][c] {
                    piece.type = .flame
                    self.updateGridDisplay()
                }
                rocketLabel.removeFromSuperview()
                self.activeAnimationViews.remove(ObjectIdentifier(rocketLabel))
                // Flash the button to highlight the new powerup
                if let btn = self.gridButtons[r][c] {
                    UIView.animate(withDuration: 0.15, animations: { btn.transform = CGAffineTransform(scaleX: 1.35, y: 1.35) },
                                   completion: { _ in UIView.animate(withDuration: 0.15) { btn.transform = .identity } })
                }
            })
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
        guard let level = currentLevel else { return }
        
        // If animations are still running, restart the timer so the hint
        // shows after animations finish + the full idle interval
        if isAnimating {
            resetIdleHintTimer()
            return
        }
        
        // Don't show a new hint if one is already showing
        if hintingTile != nil {
            return
        }
        
        // IMPORTANT: Don't show hints if there are cascading matches currently on the board
        // This prevents pulsing while new matches are being processed
        if hasCascadingMatches() {
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

    /// Expanding ring ripple that radiates from the center of a tapped tile.
    private func animateTileSelectionRipple(from button: UIButton) {
        guard let level = currentLevel else { return }
        let cellW = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellH = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let size = min(cellW, cellH) * 0.85
        let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: gridContainer)

        let ring = UIView()
        ring.frame = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        ring.layer.cornerRadius = size / 2
        ring.layer.borderWidth = 2.5
        ring.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        ring.backgroundColor = .clear
        ring.isUserInteractionEnabled = false
        gridContainer.addSubview(ring)

        UIView.animate(withDuration: 0.38, delay: 0, options: .curveEaseOut, animations: {
            ring.transform = CGAffineTransform(scaleX: 1.9, y: 1.9)
            ring.alpha = 0
        }) { _ in ring.removeFromSuperview() }
    }

    /// Starburst sparkle emitted when a match creates a new powerup tile.
    private func animatePowerupCreationSparkle(row: Int, col: Int) {
        guard let level = currentLevel else { return }
        let cellW = gridContainer.bounds.width / CGFloat(level.gridWidth)
        let cellH = gridContainer.bounds.height / CGFloat(level.gridHeight)
        let centerX = CGFloat(col) * cellW + cellW / 2
        let centerY = CGFloat(row) * cellH + cellH / 2

        let colors: [UIColor] = [.yellow, .orange, UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), .white, .cyan]
        let particleCount = 10
        for i in 0..<particleCount {
            let angle = (CGFloat(i) / CGFloat(particleCount)) * CGFloat.pi * 2
            let distance = CGFloat.random(in: cellW * 0.5 ... cellW * 1.1)
            let particle = UIView()
            let sz = CGFloat.random(in: 4...8)
            particle.frame = CGRect(x: centerX - sz / 2, y: centerY - sz / 2, width: sz, height: sz)
            particle.layer.cornerRadius = sz / 2
            particle.backgroundColor = colors[i % colors.count]
            particle.alpha = 1
            gridContainer.addSubview(particle)

            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let delay = Double.random(in: 0...0.05)
            UIView.animate(withDuration: 0.45, delay: delay, options: .curveEaseOut, animations: {
                particle.center = CGPoint(x: centerX + dx, y: centerY + dy)
                particle.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
                particle.alpha = 0
            }) { _ in particle.removeFromSuperview() }
        }

        // Brief white flash at the cell
        let flash = UIView()
        flash.frame = CGRect(x: centerX - cellW * 0.45, y: centerY - cellH * 0.45,
                             width: cellW * 0.9, height: cellH * 0.9)
        flash.layer.cornerRadius = 6
        flash.backgroundColor = UIColor.white.withAlphaComponent(0.55)
        flash.isUserInteractionEnabled = false
        gridContainer.addSubview(flash)
        UIView.animate(withDuration: 0.25, animations: { flash.alpha = 0 }) { _ in flash.removeFromSuperview() }
    }
}

