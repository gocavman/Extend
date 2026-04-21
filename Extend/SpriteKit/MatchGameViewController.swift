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
    case flame  // NEW: Clears all matching pieces when swapped
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
    private let levelSelectorButton = UIButton()  // NEW: Level selector dropdown
    private let scoreLabel = UILabel()
    private let movesLabel = UILabel()
    private let targetLabel = UILabel()
    private let highScoreLabel = UILabel()
    
    // Game State
    private var currentLevel: MatchGameLevel?
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
    
    // MARK: - Game Logic
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
            headerView.heightAnchor.constraint(equalToConstant: 100)
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
            levelSelectorButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
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
        
        // High Score Label
        highScoreLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        highScoreLabel.textColor = .lightGray
        highScoreLabel.text = "High Score: 0"
        headerView.addSubview(highScoreLabel)
        highScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            highScoreLabel.topAnchor.constraint(equalTo: movesLabel.bottomAnchor, constant: 3),
            highScoreLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15)
        ])
        
        // Grid Container
        gridContainer.backgroundColor = darkBg
        containerView.addSubview(gridContainer)
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gridContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            gridContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            gridContainer.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            gridContainer.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20),
            // Make gridContainer square - width = height
            gridContainer.widthAnchor.constraint(equalTo: gridContainer.heightAnchor, multiplier: 1.0),
            // Set max size to prevent grid from being too large
            gridContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 400)
        ])
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
        guard let config = gameConfig,
              let level = config.levels.first(where: { $0.id == levelId }) else {
            print("❌ Level \(levelId) not found")
            return
        }
        
        currentLevel = level
        score = 0
        movesRemaining = level.movesAllowed
        selectedPiece = nil
        
        // Build grid shape map from level configuration
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
        
        // Check for initial matches on level load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForMatches()
        }
    }
    
    private func updateUI() {
        guard let level = currentLevel else { return }
        
        let highScore = UserDefaults.standard.integer(forKey: "matchGameHighScore")
        
        levelLabel.text = level.name
        scoreLabel.text = "Score: \(score)"
        movesLabel.text = "Moves: \(max(0, movesRemaining))"  // Never show negative moves
        targetLabel.text = "Target: \(level.scoreTarget)"
        highScoreLabel.text = "High Score: \(highScore)"
        
        // Check if target score is reached
        if score >= level.scoreTarget && !isAnimating {
            checkLevelCompletion()
        }
        
        // Don't check for game over here - will be checked at end of checkForMatches()
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
            showGameCompleteAnimation {
                // Return to map after all levels are complete
                self.exitGame()
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
                    let itemEmoji = level.items[level.items.firstIndex(where: { $0.id == piece.itemId }) ?? 0].emoji ?? "?"
                    button.setTitle(itemEmoji, for: .normal)
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 28)
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
                // Flame shouldn't activate on tap alone
                isAnimating = false
                return
                
            case .normal:
                isAnimating = false
                return
            }
            
            // Show border highlights before clearing tiles
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
        
        // Don't decrement moves yet - wait until we validate the swap creates a match or uses a powerup
        // Remember the swap for potential revert
        lastSwappedPositions = ((r1, c1), (r2, c2))
        
        guard let button1 = gridButtons[r1][c1],
              let button2 = gridButtons[r2][c2] else {
            isAnimating = false
            lastSwappedPositions = nil
            return
        }
        
        // Get initial positions
        let pos1 = button1.convert(CGPoint.zero, to: gridContainer)
        let pos2 = button2.convert(CGPoint.zero, to: gridContainer)
        
        // Calculate the delta between positions
        let deltaX = pos2.x - pos1.x
        let deltaY = pos2.y - pos1.y
        
        // Animate the swap: button1 moves to button2's position and vice versa
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            button1.transform = CGAffineTransform(translationX: deltaX, y: deltaY)
            button2.transform = CGAffineTransform(translationX: -deltaX, y: -deltaY)
            
            // Bring button1 to front during animation
            button1.layer.zPosition = 100
        }, completion: { [weak self] _ in
            button1.layer.zPosition = 0
            // DON'T reset transforms here - keep them in swapped positions until we know if match is valid
            // Store references for potential reset later
            self?.swappedButtons = (button1, button2)
            print("🔍 [DEBUG] Stored swappedButtons in swap animation completion")
        })
        
        // Perform the actual swap in data after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            // Swap in data
            let temp = self.gameGrid[r1][c1]
            self.gameGrid[r1][c1] = self.gameGrid[r2][c2]
            self.gameGrid[r2][c2] = temp
            
            // Update positions
            self.gameGrid[r1][c1]?.row = r1
            self.gameGrid[r1][c1]?.col = c1
            self.gameGrid[r2][c2]?.row = r2
            self.gameGrid[r2][c2]?.col = c2
            
            // Check for power-up activation before checking matches
            let powerUpAtR1C1 = self.gameGrid[r1][c1]?.type != .normal
            let powerUpAtR2C2 = self.gameGrid[r2][c2]?.type != .normal
            
            // Track if this swap involves a powerup
            self.currentSwapInvolvesAPowerup = powerUpAtR1C1 || powerUpAtR2C2
            
            if powerUpAtR1C1 || powerUpAtR2C2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.activatePowerUps(r1, c1, r2, c2)
                }
            } else {
                // Check for matches after swap animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.checkForMatches()
                }
            }
        }
    }
    
    private func activatePowerUps(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) {
        guard let level = currentLevel else { return }
        
        let piece1 = gameGrid[r1][c1]
        let piece2 = gameGrid[r2][c2]
        
        // Track tiles that will be cleared AND powerups found in them
        var clearedTiles: Set<String> = []
        var cascadingPowerups: [(row: Int, col: Int, type: PieceType)] = []
        
        // Handle two bombs merging - clear 4x4 grid around midpoint
        if piece1?.type == .bomb && piece2?.type == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
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
                        if let piece = gameGrid[nr][nc], piece.type != .normal {
                            cascadingPowerups.append((row: nr, col: nc, type: piece.type))
                        }
                    }
                }
            }
            
            print("🔍 [DEBUG] Two bombs merged! Clearing 4x4 grid around (\(midRow),\(midCol)). Found \(cascadingPowerups.count) cascading powerups")
            
            // Decrement moves for this valid swap
            movesRemaining -= 1
            
            // Reset swapped button transforms FIRST so buttons are in correct positions
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            
            // Update display so buttons show correct content at correct positions
            updateGridDisplay()
            
            // NOW show borders with correct buttons
            showPowerupBorderHighlight(clearedTiles) { [weak self] in
                for posString in clearedTiles {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self?.score += 1
                        self?.gameGrid[parts[0]][parts[1]] = nil
                    }
                }
                
                self?.updateUI()
                
                if !cascadingPowerups.isEmpty {
                    self?.activateCascadingPowerups(cascadingPowerups)
                } else {
                    self?.applyGravity()
                }
            }
            return
        }
        
        // Handle two flames merging - clear entire screen
        if piece1?.type == .flame && piece2?.type == .flame {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Collect all tiles that will be cleared
            for row in 0..<level.gridHeight {
                for col in 0..<level.gridWidth {
                    if gridShapeMap[row][col] && gameGrid[row][col] != nil {
                        clearedTiles.insert("\(row),\(col)")
                        if let piece = gameGrid[row][col], piece.type != .normal {
                            cascadingPowerups.append((row: row, col: col, type: piece.type))
                        }
                    }
                }
            }
            
            print("🔍 [DEBUG] Two flames merged! Clearing entire screen. Found \(cascadingPowerups.count) cascading powerups")
            
            // Decrement moves for this valid swap
            movesRemaining -= 1
            
            // Reset swapped button transforms FIRST so buttons are in correct positions
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            
            // Update display so buttons show correct content at correct positions
            updateGridDisplay()
            
            // NOW show borders with correct buttons
            showPowerupBorderHighlight(clearedTiles) { [weak self] in
                for posString in clearedTiles {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self?.score += 1
                        self?.gameGrid[parts[0]][parts[1]] = nil
                    }
                }
                
                self?.updateUI()
                
                if !cascadingPowerups.isEmpty {
                    self?.activateCascadingPowerups(cascadingPowerups)
                } else {
                    self?.applyGravity()
                }
            }
            return
        }
        
        // Handle arrow combinations
        if (piece1?.type == .verticalArrow && piece2?.type == .horizontalArrow) ||
           (piece1?.type == .horizontalArrow && piece2?.type == .verticalArrow) {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Decrement moves for this valid swap
            movesRemaining -= 1
            
            let arrowRow = piece1?.type == .verticalArrow ? r1 : r2
            let arrowCol = piece1?.type == .horizontalArrow ? c1 : c2
            
            // Collect tiles that will be cleared
            for col in 0..<level.gridWidth {
                if gridShapeMap[arrowRow][col] && gameGrid[arrowRow][col] != nil {
                    clearedTiles.insert("\(arrowRow),\(col)")
                    if let piece = gameGrid[arrowRow][col], piece.type != .normal {
                        cascadingPowerups.append((row: arrowRow, col: col, type: piece.type))
                    }
                }
            }
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][arrowCol] && gameGrid[row][arrowCol] != nil {
                    clearedTiles.insert("\(row),\(arrowCol)")
                    if let piece = gameGrid[row][arrowCol], piece.type != .normal {
                        cascadingPowerups.append((row: row, col: arrowCol, type: piece.type))
                    }
                }
            }
            
            // Reset swapped button transforms FIRST so buttons are in correct positions
            if let (button1, button2) = swappedButtons {
                button1.transform = .identity
                button2.transform = .identity
                self.swappedButtons = nil
            }
            
            // Update display so buttons show correct content at correct positions
            updateGridDisplay()
            
            // NOW show borders with correct buttons
            showPowerupBorderHighlight(clearedTiles) { [weak self] in
                for posString in clearedTiles {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self?.score += 1
                        self?.gameGrid[parts[0]][parts[1]] = nil
                    }
                }
                
                self?.updateUI()
                
                if !cascadingPowerups.isEmpty {
                    self?.activateCascadingPowerups(cascadingPowerups)
                } else {
                    self?.applyGravity()
                }
            }
            return
        }
        
        // Handle individual power-ups
        if piece1?.type == .verticalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][c1] && gameGrid[row][c1] != nil {
                    clearedTiles.insert("\(row),\(c1)")
                    if let piece = gameGrid[row][c1], piece.type != .normal {
                        cascadingPowerups.append((row: row, col: c1, type: piece.type))
                    }
                }
            }
        }
        
        if piece2?.type == .verticalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][c2] && gameGrid[row][c2] != nil {
                    clearedTiles.insert("\(row),\(c2)")
                    if let piece = gameGrid[row][c2], piece.type != .normal {
                        cascadingPowerups.append((row: row, col: c2, type: piece.type))
                    }
                }
            }
        }
        
        if piece1?.type == .horizontalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            for col in 0..<level.gridWidth {
                if gridShapeMap[r1][col] && gameGrid[r1][col] != nil {
                    clearedTiles.insert("\(r1),\(col)")
                    if let piece = gameGrid[r1][col], piece.type != .normal {
                        cascadingPowerups.append((row: r1, col: col, type: piece.type))
                    }
                }
            }
        }
        
        if piece2?.type == .horizontalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            for col in 0..<level.gridWidth {
                if gridShapeMap[r2][col] && gameGrid[r2][col] != nil {
                    clearedTiles.insert("\(r2),\(col)")
                    if let piece = gameGrid[r2][col], piece.type != .normal {
                        cascadingPowerups.append((row: r2, col: col, type: piece.type))
                    }
                }
            }
        }
        
        if piece1?.type == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r1 + dr
                    let nc = c1 + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        clearedTiles.insert("\(nr),\(nc)")
                        if let piece = gameGrid[nr][nc], piece.type != .normal {
                            cascadingPowerups.append((row: nr, col: nc, type: piece.type))
                        }
                    }
                }
            }
        }
        
        if piece2?.type == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r2 + dr
                    let nc = c2 + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        clearedTiles.insert("\(nr),\(nc)")
                        if let piece = gameGrid[nr][nc], piece.type != .normal {
                            cascadingPowerups.append((row: nr, col: nc, type: piece.type))
                        }
                    }
                }
            }
        }
        
        // Handle flame power-ups - clears ALL matching pieces
        if piece1?.type == .flame {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Add the flame powerup itself to be cleared
            clearedTiles.insert("\(r1),\(c1)")
            
            if let swappedPiece = piece2, swappedPiece.type == .normal {
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
        }
        
        if piece2?.type == .flame {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Add the flame powerup itself to be cleared
            clearedTiles.insert("\(r2),\(c2)")
            
            if let swappedPiece = piece1, swappedPiece.type == .normal {
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
        }
        
        if piece2?.type == .flame {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            if let swappedPiece = piece1, swappedPiece.type == .normal {
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
        }
        
        // Show borders first for all cleared tiles, then clear and process (DON'T call updateGridDisplay() yet - it resets transforms!)
        // Decrement moves for this valid swap (if clearedTiles are not empty)
        if !clearedTiles.isEmpty {
            movesRemaining -= 1
        }
        
        // Reset swapped button transforms FIRST so buttons are in correct positions
        if let (button1, button2) = swappedButtons {
            button1.transform = .identity
            button2.transform = .identity
            self.swappedButtons = nil
        }
        
        // Update display so buttons show correct content at correct positions
        updateGridDisplay()
        
        // NOW show borders with correct buttons
        if !clearedTiles.isEmpty {
            showPowerupBorderHighlight(clearedTiles) { [weak self] in
                for posString in clearedTiles {
                    let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        self?.score += 1
                        self?.gameGrid[parts[0]][parts[1]] = nil
                    }
                }
                
                self?.updateUI()
                
                if !cascadingPowerups.isEmpty {
                    self?.activateCascadingPowerups(cascadingPowerups)
                } else {
                    self?.applyGravity()
                }
            }
        } else {
            // No tiles to clear, just apply gravity
            updateUI()
            applyGravity()
        }
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
        
        // Count how many powerups will create flame animations
        for (_, _, type) in powerups {
            switch type {
            case .verticalArrow, .horizontalArrow, .bomb:
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
        
        // Process each cascading powerup
        for (row, col, type) in powerups {
            switch type {
            case .verticalArrow:
                // Shoot flames vertically - fires immediately, completion handler tracks when done
                shootFlamesVertically(column: col, arrowRow: row, rows: 0..<level.gridHeight) {
                    flameAnimationsCompleted += 1
                    if flameAnimationsCompleted == flameAnimationsInProgress {
                        // All flame animations complete - now apply gravity
                        self.applyGravityAfterCascade()
                    }
                }
                
                // Clear entire column and capture cascading powerups
                var cascadingFromArrow: [(row: Int, col: Int, type: PieceType)] = []
                for r in 0..<level.gridHeight {
                    if gridShapeMap[r][col] && gameGrid[r][col] != nil {
                        // Capture any powerups in column BEFORE clearing
                        if let p = gameGrid[r][col], p.type != .normal {
                            cascadingFromArrow.append((row: r, col: col, type: p.type))
                        }
                        score += 1
                        gameGrid[r][col] = nil
                    }
                }
                print("🔥 Cascading vertical arrow cleared column \(col). Found \(cascadingFromArrow.count) cascading powerups")
                
            case .horizontalArrow:
                // Shoot flames horizontally - fires immediately, completion handler tracks when done
                shootFlamesHorizontally(row: row, columns: 0..<level.gridWidth) {
                    flameAnimationsCompleted += 1
                    if flameAnimationsCompleted == flameAnimationsInProgress {
                        // All flame animations complete - now apply gravity
                        self.applyGravityAfterCascade()
                    }
                }
                
                // Clear entire row and capture cascading powerups
                var cascadingFromArrow: [(row: Int, col: Int, type: PieceType)] = []
                for c in 0..<level.gridWidth {
                    if gridShapeMap[row][c] && gameGrid[row][c] != nil {
                        // Capture any powerups in row BEFORE clearing
                        if let p = gameGrid[row][c], p.type != .normal {
                            cascadingFromArrow.append((row: row, col: c, type: p.type))
                        }
                        score += 1
                        gameGrid[row][c] = nil
                    }
                }
                print("🔥 Cascading horizontal arrow cleared row \(row). Found \(cascadingFromArrow.count) cascading powerups")
                
            case .bomb:
                // Clear 3x3 area and capture any cascading powerups
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
                
            default:
                break
            }
        }
        
        updateGridDisplay()
        updateUI()
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
        
        // Update grid display IMMEDIATELY
        updateGridDisplay()
        
        // Hide all new pieces initially so they don't stack up visually
        for key in newPieces {
            let parts = key.split(separator: ",").compactMap { Int($0) }
            if parts.count == 2 {
                let row = parts[0]
                let col = parts[1]
                if let button = gridButtons[row][col] {
                    button.alpha = 0  // Hide new pieces - they'll appear as they animate
                }
            }
        }
        
        // Hide all new pieces initially so they don't stack up visually
        for key in newPieces {
            let parts = key.split(separator: ",").compactMap { Int($0) }
            if parts.count == 2 {
                let row = parts[0]
                let col = parts[1]
                if let button = gridButtons[row][col] {
                    button.alpha = 0  // Hide new pieces - they'll appear as they animate
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
        
        print("🔍 [DEBUG] shootFlamesVertically called: column=\(column), arrowRow=\(arrowRow)")
        print("🔍 [DEBUG] Grid geometry: gridHeight=\(gridHeight), rowHeight=\(rowHeight)")
        print("🔍 [DEBUG] Flame positions: startY=\(startY), endYUp=\(endYUp), endYDown=\(endYDown)")
        
        var animationsComplete = 0
        let totalAnimations = 20  // 10 up + 10 down
        let completeAnimation = {
            animationsComplete += 1
            if animationsComplete == totalAnimations {
                completion()
            }
        }
        
        // Create 10 flames shooting UP (distributed across column width)
        for i in 0..<10 {
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
        
        // Create 10 flames shooting DOWN (distributed across column width)
        for i in 0..<10 {
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
        let totalAnimations = 20  // 10 left + 10 right
        let completeAnimation = {
            animationsComplete += 1
            if animationsComplete == totalAnimations {
                completion()
            }
        }
        
        // Create 10 flames shooting LEFT (distributed across row height)
        for i in 0..<10 {
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
        
        // Create 10 flames shooting RIGHT (distributed across row height)
        for i in 0..<10 {
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
                        if gridShapeMap[r][r1] && gameGrid[r][r1] != nil {
                            clearedTiles.insert("\(r),\(r1)")
                            if let p = gameGrid[r][r1], p.type != .normal && p.type != .verticalArrow {
                                cascadingPowerups.append((row: r, col: r1, type: p.type))
                            }
                        }
                    }
                    
                case .horizontalArrow:
                    // Collect all tiles in row
                    for c in 0..<level.gridWidth {
                        if gridShapeMap[c1][c] && gameGrid[c1][c] != nil {
                            clearedTiles.insert("\(c1),\(c)")
                            if let p = gameGrid[c1][c], p.type != .normal && p.type != .horizontalArrow {
                                cascadingPowerups.append((row: c1, col: c, type: p.type))
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
                        if gridShapeMap[r][r2] && gameGrid[r][r2] != nil {
                            clearedTiles.insert("\(r),\(r2)")
                            if let p = gameGrid[r][r2], p.type != .normal && p.type != .verticalArrow {
                                cascadingPowerups.append((row: r, col: r2, type: p.type))
                            }
                        }
                    }
                    
                case .horizontalArrow:
                    // Collect all tiles in row
                    for c in 0..<level.gridWidth {
                        if gridShapeMap[c2][c] && gameGrid[c2][c] != nil {
                            clearedTiles.insert("\(c2),\(c)")
                            if let p = gameGrid[c2][c], p.type != .normal && p.type != .horizontalArrow {
                                cascadingPowerups.append((row: c2, col: c, type: p.type))
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
        
        if !matchesToRemove.isEmpty {
            print("🔍 [DEBUG] Total matches found: \(matchesToRemove.count) tiles to remove")
            print("🔍 [DEBUG] Matches: \(matchesToRemove.sorted())")
            print("✅ VALID MATCH DETECTED - animating removal")
            
            // Trigger haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Only decrement moves if this was a user swap (initial move), not a cascade
            if lastSwappedPositions != nil {
                movesRemaining -= 1
            }
            
            // Clear lastSwappedPositions and reset transforms
            lastSwappedPositions = nil
            
            // Reset the transforms of swapped buttons so they display correctly
            if let (button1, button2) = swappedButtons {
                print("🔍 [DEBUG] Resetting transforms for swapped buttons")
                button1.transform = .identity
                button2.transform = .identity
                swappedButtons = nil
                // Update display immediately after resetting transforms
                self.updateGridDisplay()
            } else {
                print("🔍 [DEBUG] No swappedButtons found to reset!")
            }
            
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
                
                self?.updateUI()
                self?.updateGridDisplay()
                self?.applyGravity()
            }
        } else {
            // No match found
            print("🔍 [DEBUG] No matches found in current grid")
            print("❌ INVALID MOVE - starting 3 second revert animation")
            
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
        
        // After 0.2 seconds, clear borders and proceed with completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
        
        // STEP 2: After 0.2 seconds, animate removal and clear border
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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
                    UIView.animate(withDuration: 0.2, animations: {
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
        
        // Update grid display IMMEDIATELY
        updateGridDisplay()
        
        // Hide all new pieces initially so they don't stack up visually
        for key in newPieces {
            let parts = key.split(separator: ",").compactMap { Int($0) }
            if parts.count == 2 {
                let row = parts[0]
                let col = parts[1]
                if let button = gridButtons[row][col] {
                    button.alpha = 0  // Hide new pieces - they'll appear as they animate
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
        
        // Pieces fall at consistent speed (pixels per second)
        let fallSpeedPixelsPerSecond: CGFloat = 400
        
        var completedAnimations = 0
        let totalAnimations = movedPieces.count
        
        guard totalAnimations > 0 else {
            completion()
            return
        }
        
        // For each column, calculate the delays needed so pieces fall in order (bottom to top)
        // This prevents visual overlap where it looks like pieces are passing through each other
        var allAnimations: [(button: UIButton, delay: Double, duration: Double)] = []
        
        for col in 0..<level.gridWidth {
            // Collect all pieces in this column and their distances
            var columnAnimations: [(button: UIButton, row: Int, distance: Int)] = []
            
            for row in 0..<level.gridHeight {
                let key = "\(row),\(col)"
                if movedPieces.contains(key), gridShapeMap[row][col], let button = gridButtons[row][col], gameGrid[row][col] != nil {
                    let distance = fallDistances[key] ?? 0
                    columnAnimations.append((button: button, row: row, distance: distance))
                }
            }
            
            // Sort by row DESCENDING (bottom pieces first)
            columnAnimations.sort { $0.row > $1.row }
            print("📍 Column \(col): \(columnAnimations.count) pieces to animate, order: \(columnAnimations.map { $0.row })")
            
            // Calculate delay based on time to fall one cell - this ensures proper sequencing
            // Pieces are offset by one cell-fall duration so they don't collide
            let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
            let oneRowFallTime = Double(cellHeight / fallSpeedPixelsPerSecond)
            
            // Find the longest distance in this column to use as uniform duration
            var maxDistance = 0
            for (_, _, distance) in columnAnimations {
                maxDistance = max(maxDistance, distance)
            }
            let fallDistance = cellHeight * CGFloat(maxDistance)
            let uniformDuration = Double(fallDistance / fallSpeedPixelsPerSecond)
            
            var cumulativeDelay = 0.0
            
            for (button, row, distance) in columnAnimations {
                print("📍 Column \(col): Row \(row) delay=\(String(format: "%.3f", cumulativeDelay)) duration=\(String(format: "%.3f", uniformDuration)) distance=\(distance)")
                allAnimations.append((button: button, delay: cumulativeDelay, duration: uniformDuration))
                cumulativeDelay += oneRowFallTime  // Stagger by time to fall one row
            }
        }
        
        // Now animate all pieces with calculated delays
        for (button, delay, duration) in allAnimations {
            let cellHeight = gridContainer.bounds.height / CGFloat(level.gridHeight)
            
            // Find the distance for this piece
            let startTransform: CGAffineTransform
            var pieceRow = 0
            var pieceCol = 0
            
            if let gamepiece = gameGrid[Int(button.tag / level.gridWidth)][Int(button.tag % level.gridWidth)] {
                let row = gamepiece.row
                let col = gamepiece.col
                pieceRow = row
                pieceCol = col
                let distance = fallDistances["\(row),\(col)"] ?? 0
                let fallDistance = cellHeight * CGFloat(distance)
                
                if newPieces.contains("\(row),\(col)") {
                    // NEW pieces fall from ABOVE
                    startTransform = CGAffineTransform(translationX: 0, y: -fallDistance)
                } else {
                    // EXISTING pieces fall DOWN
                    startTransform = CGAffineTransform(translationX: 0, y: fallDistance)
                }
            } else {
                continue
            }
            
            button.transform = startTransform
            
            // For new pieces, start with alpha=0 so they fade in as they fall (one at a time appearance)
            if newPieces.contains("\(pieceRow),\(pieceCol)") {
                button.alpha = 0  // Start hidden
            } else {
                button.alpha = 1.0  // Existing pieces are visible
            }
            
            // Animate with calculated delay so pieces don't visually overlap
            UIView.animate(
                withDuration: duration,
                delay: delay,
                options: .curveEaseIn,
                animations: {
                    button.transform = .identity
                    button.alpha = 1.0  // Fade in as it falls
                },
                completion: { finished in
                    completedAnimations += 1
                    if completedAnimations == totalAnimations {
                        completion()
                    }
                }
            )
        }
    }
    
    private func updateGridDisplay() {
        guard let level = currentLevel else { return }
        
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                guard let button = gridButtons[row][col] else { continue }
                
                if let piece = gameGrid[row][col] {
                    // Display power-ups with special symbols
                    let displayText: String
                    switch piece.type {
                    case .verticalArrow:
                        displayText = "↕️"
                        button.backgroundColor = .clear  // Transparent for powerups
                    case .horizontalArrow:
                        displayText = "↔️"
                        button.backgroundColor = .clear  // Transparent for powerups
                    case .bomb:
                        displayText = "💣"
                        button.backgroundColor = .clear  // Transparent for powerups
                    case .flame:
                        displayText = "🔥"
                        button.backgroundColor = .clear  // Transparent for powerups
                    case .normal:
                        let itemEmoji = level.items[level.items.firstIndex(where: { $0.id == piece.itemId }) ?? 0].emoji ?? "?"
                        displayText = itemEmoji
                        // Handle optional colors - nil means transparent background
                        if let colorHex = level.colors[piece.colorIndex] {
                            button.backgroundColor = UIColor(hex: colorHex) ?? .gray
                        } else {
                            button.backgroundColor = .clear
                        }
                    }
                    
                    button.setTitle(displayText, for: .normal)
                    
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
        guard let piece = gameGrid[row][col], piece.type == .normal else { return false }
        
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
        
        // Collect all pieces
        var pieces: [GamePiece] = []
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    pieces.append(piece)
                }
            }
        }
        
        // Shuffle the pieces array
        pieces.shuffle()
        
        // Animate all pieces shuffling
        var pieceIndex = 0
        for row in 0..<level.gridHeight {
            for col in 0..<level.gridWidth {
                if gridShapeMap[row][col] && pieceIndex < pieces.count {
                    let button = gridButtons[row][col]
                    
                    // Animate piece moving to new position
                    UIView.animate(withDuration: 0.5, delay: Double(pieceIndex) * 0.05, options: .curveEaseInOut, animations: {
                        // Scale and rotate during shuffle
                        button?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5).rotated(by: CGFloat.pi)
                    }, completion: { _ in
                        button?.transform = .identity
                    })
                    
                    // Place the piece in grid
                    gameGrid[row][col] = pieces[pieceIndex]
                    pieces[pieceIndex].row = row
                    pieces[pieceIndex].col = col
                    pieceIndex += 1
                }
            }
        }
        
        // After animation, update display and check for matches
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateGridDisplay()
            self?.checkForMatches()
        }
    }
    
    @objc private func exitGame() {
        // Save high score
        let currentHighScore = UserDefaults.standard.integer(forKey: "matchGameHighScore")
        if score > currentHighScore {
            UserDefaults.standard.set(score, forKey: "matchGameHighScore")
        }
        
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
}
