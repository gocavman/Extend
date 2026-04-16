import UIKit

// MARK: - Data Structures

struct MatchGameLevel: Codable {
    let id: Int
    let name: String
    let gridWidth: Int
    let gridHeight: Int
    let items: [MatchItem]
    let colors: [String]
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
    
    // UI Components
    private let containerView = UIView()
    private let headerView = UIView()
    private let gridContainer = UIView()
    private let gridStackView = UIStackView()
    private let exitButton = UIButton()
    private let levelLabel = UILabel()
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
    private var dragStartPiece: (row: Int, col: Int)? = nil
    private var dragTargetPiece: (row: Int, col: Int)? = nil
    
    // Colors
    private let darkBg = UIColor(hex: "#2C3E50") ?? .black
    private let lightBg = UIColor(hex: "#34495E") ?? .darkGray
    private let accentColor = UIColor(hex: "#E74C3C") ?? .red
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadGameConfig()
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
        
        // Level Label
        levelLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        levelLabel.textColor = .white
        levelLabel.text = "Level 1"
        headerView.addSubview(levelLabel)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            levelLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            levelLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor)
        ])
        
        // Score Label
        scoreLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        scoreLabel.textColor = .lightGray
        scoreLabel.text = "Score: 0"
        headerView.addSubview(scoreLabel)
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 5),
            scoreLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 15)
        ])
        
        // Moves Label
        movesLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        movesLabel.textColor = .lightGray
        movesLabel.text = "Moves: 0"
        headerView.addSubview(movesLabel)
        movesLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            movesLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 5),
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
            gridContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            gridContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            gridContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            gridContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
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
            print("✅ Loaded matchgame.json with \(gameConfig?.levels.count ?? 0) levels")
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
        
        // Build grid shape map
        gridShapeMap = level.gridShape.map { row in
            row.map { $0 == "X" }
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
    }
    
    private func updateUI() {
        guard let level = currentLevel else { return }
        
        let highScore = UserDefaults.standard.integer(forKey: "matchGameHighScore")
        
        levelLabel.text = level.name
        scoreLabel.text = "Score: \(score)"
        movesLabel.text = "Moves: \(movesRemaining)"
        targetLabel.text = "Target: \(level.scoreTarget)"
        highScoreLabel.text = "High Score: \(highScore)"
    }
    
    private func renderGrid() {
        guard let level = currentLevel else { return }
        
        // Clear existing
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        gridStackView.removeFromSuperview()
        
        // Create grid stack view
        gridStackView.axis = .vertical
        gridStackView.spacing = 2
        gridStackView.distribution = .fillEqually
        gridContainer.addSubview(gridStackView)
        gridStackView.translatesAutoresizingMaskIntoConstraints = false
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
            rowStack.distribution = .fillEqually
            gridStackView.addArrangedSubview(rowStack)
            
            for col in 0..<level.gridWidth {
                let button = UIButton()
                button.tag = row * level.gridWidth + col
                button.layer.cornerRadius = 8
                button.clipsToBounds = true
                
                if gridShapeMap[row][col], let piece = gameGrid[row][col] {
                    button.backgroundColor = UIColor(hex: level.colors[piece.colorIndex]) ?? .gray
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
        movesRemaining -= 1
        
        // Swap
        let temp = gameGrid[r1][c1]
        gameGrid[r1][c1] = gameGrid[r2][c2]
        gameGrid[r2][c2] = temp
        
        // Update positions
        gameGrid[r1][c1]?.row = r1
        gameGrid[r1][c1]?.col = c1
        gameGrid[r2][c2]?.row = r2
        gameGrid[r2][c2]?.col = c2
        
        updateGridDisplay()
        
        // Check for power-up activation before checking matches
        let powerUpAtR1C1 = gameGrid[r1][c1]?.type != .normal
        let powerUpAtR2C2 = gameGrid[r2][c2]?.type != .normal
        
        if powerUpAtR1C1 || powerUpAtR2C2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.activatePowerUps(r1, c1, r2, c2)
            }
        } else {
            // Check for matches after animation delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkForMatches()
            }
        }
    }
    
    private func activatePowerUps(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) {
        guard let level = currentLevel else { return }
        
        let piece1 = gameGrid[r1][c1]
        let piece2 = gameGrid[r2][c2]
        
        // Handle two bombs merging - clear entire screen
        if piece1?.type == .bomb && piece2?.type == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Clear entire grid
            for row in 0..<level.gridHeight {
                for col in 0..<level.gridWidth {
                    if gridShapeMap[row][col] && gameGrid[row][col] != nil {
                        score += 100
                        gameGrid[row][col] = nil
                    }
                }
            }
            updateUI()
            applyGravity()
            return
        }
        
        // Handle arrow combinations
        if (piece1?.type == .verticalArrow && piece2?.type == .horizontalArrow) ||
           (piece1?.type == .horizontalArrow && piece2?.type == .verticalArrow) {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            let arrowRow = piece1?.type == .verticalArrow ? r1 : r2
            let arrowCol = piece1?.type == .horizontalArrow ? c1 : c2
            
            // Clear row and column
            for col in 0..<level.gridWidth {
                if gridShapeMap[arrowRow][col] && gameGrid[arrowRow][col] != nil {
                    score += 50
                    gameGrid[arrowRow][col] = nil
                }
            }
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][arrowCol] && gameGrid[row][arrowCol] != nil {
                    score += 50
                    gameGrid[row][arrowCol] = nil
                }
            }
            updateUI()
            applyGravity()
            return
        }
        
        // Handle individual power-ups
        if piece1?.type == .verticalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Clear column
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][c1] && gameGrid[row][c1] != nil {
                    score += 50
                    gameGrid[row][c1] = nil
                }
            }
            gameGrid[r1][c1] = nil
        }
        
        if piece2?.type == .verticalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Clear column
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][c2] && gameGrid[row][c2] != nil {
                    score += 50
                    gameGrid[row][c2] = nil
                }
            }
            gameGrid[r2][c2] = nil
        }
        
        if piece1?.type == .horizontalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Clear row
            for col in 0..<level.gridWidth {
                if gridShapeMap[r1][col] && gameGrid[r1][col] != nil {
                    score += 50
                    gameGrid[r1][col] = nil
                }
            }
            gameGrid[r1][c1] = nil
        }
        
        if piece2?.type == .horizontalArrow {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Clear row
            for col in 0..<level.gridWidth {
                if gridShapeMap[r2][col] && gameGrid[r2][col] != nil {
                    score += 50
                    gameGrid[r2][col] = nil
                }
            }
            gameGrid[r2][c2] = nil
        }
        
        if piece1?.type == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Clear 3x3 around bomb
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r1 + dr
                    let nc = c1 + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        score += 75
                        gameGrid[nr][nc] = nil
                    }
                }
            }
            gameGrid[r1][c1] = nil
        }
        
        if piece2?.type == .bomb {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Clear 3x3 around bomb
            for dr in -1...1 {
                for dc in -1...1 {
                    let nr = r2 + dr
                    let nc = c2 + dc
                    if nr >= 0 && nr < level.gridHeight && nc >= 0 && nc < level.gridWidth &&
                       gridShapeMap[nr][nc] && gameGrid[nr][nc] != nil {
                        score += 75
                        gameGrid[nr][nc] = nil
                    }
                }
            }
            gameGrid[r2][c2] = nil
        }
        
        updateUI()
        applyGravity()
    }
    
    private func checkForMatches() {
        guard let level = currentLevel else { return }
        
        var matchesToRemove: Set<String> = []
        var powerUpsToCreate: [(row: Int, col: Int, type: PieceType)] = []
        
        // Check horizontal matches (5+ first, then 4, then 3)
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
                    
                    if matchCount >= 5 {
                        // 5+ match: create horizontal arrow at middle
                        let middleCol = col + matchCount / 2
                        powerUpsToCreate.append((row: row, col: middleCol, type: .horizontalArrow))
                        
                        // Mark all pieces for removal
                        for i in col..<col + matchCount {
                            if let p = gameGrid[row][i], p.type == .normal {
                                matchesToRemove.insert("\(p.row),\(p.col)")
                            }
                        }
                    } else if matchCount >= 3 {
                        // 3-4 match: remove pieces
                        for i in col..<col + matchCount {
                            if let p = gameGrid[row][i], p.type == .normal {
                                matchesToRemove.insert("\(p.row),\(p.col)")
                            }
                        }
                    }
                    
                    col = max(col + 1, checkCol)
                } else {
                    col += 1
                }
            }
        }
        
        // Check vertical matches (5+ first, then 4, then 3)
        for col in 0..<level.gridWidth {
            var row = 0
            while row < level.gridHeight {
                if gridShapeMap[row][col], let piece = gameGrid[row][col], piece.type == .normal {
                    var matchCount = 1
                    var checkRow = row + 1
                    
                    while checkRow < level.gridHeight &&
                          gridShapeMap[checkRow][col],
                          let nextPiece = gameGrid[checkRow][col],
                          piece.matches(nextPiece) {
                        matchCount += 1
                        checkRow += 1
                    }
                    
                    if matchCount >= 5 {
                        // 5+ match: create vertical arrow at middle
                        let middleRow = row + matchCount / 2
                        powerUpsToCreate.append((row: middleRow, col: col, type: .verticalArrow))
                        
                        // Mark all pieces for removal
                        for i in row..<row + matchCount {
                            if let p = gameGrid[i][col], p.type == .normal {
                                matchesToRemove.insert("\(p.row),\(p.col)")
                            }
                        }
                    } else if matchCount >= 3 {
                        // 3-4 match: remove pieces
                        for i in row..<row + matchCount {
                            if let p = gameGrid[i][col], p.type == .normal {
                                matchesToRemove.insert("\(p.row),\(p.col)")
                            }
                        }
                    }
                    
                    row = max(row + 1, checkRow)
                } else {
                    row += 1
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
                    // Create bomb at center
                    let bombRow = row + 1
                    let bombCol = col
                    powerUpsToCreate.append((row: bombRow, col: bombCol, type: .bomb))
                    
                    // Mark all 4 pieces for removal
                    matchesToRemove.insert("\(p1.row),\(p1.col)")
                    matchesToRemove.insert("\(p2.row),\(p2.col)")
                    matchesToRemove.insert("\(p3.row),\(p3.col)")
                    matchesToRemove.insert("\(p4.row),\(p4.col)")
                }
            }
        }
        
        if !matchesToRemove.isEmpty {
            // Trigger haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            // Remove matched pieces
            for posString in matchesToRemove {
                let parts = posString.split(separator: ",").map { Int($0) ?? 0 }
                if parts.count == 2 {
                    score += 100
                    gameGrid[parts[0]][parts[1]] = nil
                }
            }
            
            // Create power-ups
            for powerUp in powerUpsToCreate {
                gameGrid[powerUp.row][powerUp.col] = GamePiece(
                    itemId: "power_up",
                    colorIndex: 0,
                    row: powerUp.row,
                    col: powerUp.col,
                    type: powerUp.type
                )
            }
            
            updateUI()
            applyGravity()
        } else {
            isAnimating = false
        }
    }
    
    private func applyGravity() {
        guard let level = currentLevel else { return }
        
        // Apply gravity
        for col in 0..<level.gridWidth {
            var writePos = level.gridHeight - 1
            
            for readPos in (0..<level.gridHeight).reversed() {
                if gridShapeMap[readPos][col], let piece = gameGrid[readPos][col] {
                    if readPos != writePos {
                        gameGrid[writePos][col] = piece
                        piece.row = writePos
                        piece.col = col
                        gameGrid[readPos][col] = nil
                    }
                    writePos -= 1
                }
            }
        }
        
        // Refill empty spaces from the top
        for col in 0..<level.gridWidth {
            for row in 0..<level.gridHeight {
                if gridShapeMap[row][col] && gameGrid[row][col] == nil {
                    let randomItemIndex = Int.random(in: 0..<level.items.count)
                    let randomColorIndex = Int.random(in: 0..<level.colors.count)
                    gameGrid[row][col] = GamePiece(
                        itemId: level.items[randomItemIndex].id,
                        colorIndex: randomColorIndex,
                        row: row,
                        col: col,
                        type: .normal
                    )
                }
            }
        }
        
        updateGridDisplay()
        
        // Check for more matches after animation delay (longer for drop animation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForMatches()
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
                        button.backgroundColor = UIColor(hex: "#FFD700") ?? .yellow // Gold
                    case .horizontalArrow:
                        displayText = "↔️"
                        button.backgroundColor = UIColor(hex: "#FFD700") ?? .yellow // Gold
                    case .bomb:
                        displayText = "💣"
                        button.backgroundColor = UIColor(hex: "#FF6B6B") ?? .red // Red
                    case .normal:
                        let itemEmoji = level.items[level.items.firstIndex(where: { $0.id == piece.itemId }) ?? 0].emoji ?? "?"
                        displayText = itemEmoji
                        button.backgroundColor = UIColor(hex: level.colors[piece.colorIndex]) ?? .gray
                    }
                    
                    button.setTitle(displayText, for: .normal)
                    
                    // Highlight selected piece
                    if selectedPiece?.row == row && selectedPiece?.col == col {
                        button.layer.borderColor = UIColor.yellow.cgColor
                        button.layer.borderWidth = 3
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
    
    @objc private func exitGame() {
        // Save high score
        let currentHighScore = UserDefaults.standard.integer(forKey: "matchGameHighScore")
        if score > currentHighScore {
            UserDefaults.standard.set(score, forKey: "matchGameHighScore")
        }
        
        dismiss(animated: true)
    }
}
