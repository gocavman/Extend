import SpriteKit

// MARK: - CGVector Extension

extension CGVector {
    var normalized: CGVector {
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return CGVector.zero }
        return CGVector(dx: dx / length, dy: dy / length)
    }
}

/// SpriteKit scene for the level map - 2000x2000 scrollable room with character and level stations
class MapScene: GameScene {
    // MARK: - Map Dimensions and Configuration
    private let MAP_WIDTH: CGFloat = 2000
    private let MAP_HEIGHT: CGFloat = 2000
    private let CHARACTER_SPEED: CGFloat = 400 // pixels per second
    private let PROXIMITY_THRESHOLD: CGFloat = 80 // distance to trigger level entry
    private let VISIBLE_AREA_WIDTH: CGFloat = 500  // Doubled because camera scale is 2x
    private let VISIBLE_AREA_HEIGHT: CGFloat = 500 // Doubled because camera scale is 2x
    private let CAMERA_SCALE: CGFloat = 2.0  // Zoom level
    
    // MARK: - Nodes and State
    private var mapContainer: SKNode? // Container for all map content (moves with camera)
    private var characterNode: SKSpriteNode?
    private var levelStationNodes: [Int: SKShapeNode] = [:] // levelId -> node
    private var targetPosition: CGPoint? = nil
    private var isMoving = false
    private var currentAnimationFrame = 1
    
    // MARK: - Timers
    private var movementTimer: Timer?
    private var animationTimer: Timer?
    private var proximityCheckTimer: Timer?
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        //print("🗺️ MapScene didMove - size: \(size)")
        
        // Set background
        backgroundColor = SKColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        // Create the map container node (this will be moved by the camera)
        let container = SKNode()
        container.name = "mapContainer"
        addChild(container)
        mapContainer = container
        
        // Setup map content
        setupMapBackground()
        setupLevelStations()
        setupCharacter()
        
        // Initialize camera
        setupCamera()
        
        // Start timers
        startMovementTimer()
        startAnimationTimer()
        startProximityCheckTimer()
    }
    
    // MARK: - Setup Methods
    
    private func setupMapBackground() {
        guard let container = mapContainer else { return }
        
        // Create a visible background grid area
        let background = SKShapeNode(rectOf: CGSize(width: MAP_WIDTH, height: MAP_HEIGHT))
        background.position = CGPoint(x: MAP_WIDTH / 2, y: MAP_HEIGHT / 2)
        background.fillColor = SKColor(red: 0.9, green: 0.95, blue: 0.9, alpha: 1.0)
        background.strokeColor = SKColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.5)
        background.lineWidth = 2
        background.zPosition = 0
        container.addChild(background)
    }
    
    private func setupLevelStations() {
        guard let container = mapContainer else { return }
        guard let gameState = gameState else {
            print("⚠️ MapScene: gameState is nil!")
            return
        }
        
        //print("🗺️ Creating level stations from LEVEL_CONFIGS")
        
        // Create level station boxes from LEVEL_CONFIGS
        for levelConfig in LEVEL_CONFIGS {
            let isCompleted = levelConfig.id < gameState.currentLevel
            let isAvailable = levelConfig.id <= gameState.currentLevel
            
            // Determine color: green if completed, white if available, gray if locked
            let color: SKColor = isCompleted ? .green : (isAvailable ? .white : .gray)
            
            // Create level station as a square
            let station = SKShapeNode(rectOf: CGSize(width: levelConfig.width, height: levelConfig.height))
            station.position = CGPoint(x: levelConfig.mapX, y: levelConfig.mapY)
            station.fillColor = color
            station.strokeColor = .black
            station.lineWidth = 2
            station.name = "level_\(levelConfig.id)"
            station.zPosition = 10
            container.addChild(station)
            
            // Add label with level number
            let label = SKLabelNode(fontNamed: "Arial")
            label.text = "L\(levelConfig.id)"
            label.fontSize = 16
            label.fontColor = isCompleted || isAvailable ? .black : .white
            label.position = CGPoint(x: levelConfig.mapX, y: levelConfig.mapY)
            label.zPosition = 11
            container.addChild(label)
            
            levelStationNodes[levelConfig.id] = station
        }
    }
    
    private func setupCharacter() {
        guard let container = mapContainer else { return }
        guard let mapState = mapState else { return }
        
        // Create character sprite using topview1 asset
        let character = SKSpriteNode(imageNamed: "topview1")
        character.position = CGPoint(x: mapState.characterX, y: mapState.characterY)
        character.setScale(1.0)
        character.name = "character"
        character.zPosition = 20
        container.addChild(character)
        
        characterNode = character
    }
    
    private func setupCamera() {
        guard let mapState = mapState else { return }
        
        // Create camera
        let camera = SKCameraNode()
        camera.position = CGPoint(x: mapState.characterX, y: mapState.characterY)
        camera.setScale(CAMERA_SCALE)  // Zoom out 2x
        addChild(camera)
        self.camera = camera
        
        // Clamp camera to visible area bounds
        clampCameraPosition()
    }
    
    // MARK: - Camera Management
    
    private func clampCameraPosition() {
        guard let camera = camera else { return }
        
        let minX = VISIBLE_AREA_WIDTH / 2
        let maxX = MAP_WIDTH - VISIBLE_AREA_WIDTH / 2
        let minY = VISIBLE_AREA_HEIGHT / 2
        let maxY = MAP_HEIGHT - VISIBLE_AREA_HEIGHT / 2
        
        let clampedX = max(minX, min(camera.position.x, maxX))
        let clampedY = max(minY, min(camera.position.y, maxY))
        
        camera.position = CGPoint(x: clampedX, y: clampedY)
    }
    
    private func updateCamera() {
        guard let camera = camera else { return }
        guard let characterNode = characterNode else { return }
        
        // Character should ALWAYS be centered on screen
        // Simply move camera to character position
        camera.position = characterNode.position
    }
    
    // MARK: - Character Movement
    
    private func startMovementTimer() {
        movementTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateCharacterMovement()
        }
    }
    
    private func updateCharacterMovement() {
        guard let mapState = mapState else { return }
        guard let characterNode = characterNode else { return }
        guard let targetPos = targetPosition else { return }
        
        let currentPos = characterNode.position
        let distance = hypot(targetPos.x - currentPos.x, targetPos.y - currentPos.y)
        
        // If reached target, stop moving
        if distance < 5 {
            isMoving = false
            self.targetPosition = nil
            mapState.isMoving = false
            return
        }
        
        // Move towards target
        let direction = CGVector(dx: targetPos.x - currentPos.x, dy: targetPos.y - currentPos.y).normalized
        let moveDistance = CHARACTER_SPEED * 0.016 // dt = 0.016 (60fps)
        let newPos = CGPoint(x: currentPos.x + direction.dx * moveDistance, y: currentPos.y + direction.dy * moveDistance)
        
        // Clamp to map bounds
        let clampedX = max(0, min(newPos.x, MAP_WIDTH))
        let clampedY = max(0, min(newPos.y, MAP_HEIGHT))
        characterNode.position = CGPoint(x: clampedX, y: clampedY)
        
        // Update map state
        mapState.characterX = characterNode.position.x
        mapState.characterY = characterNode.position.y
        
        // Update camera
        updateCamera()
    }
    
    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCharacterAnimation()
        }
    }
    
    private func updateCharacterAnimation() {
        guard let characterNode = characterNode else { return }
        
        if isMoving {
            // Only cycle through topview2 and topview3 when moving
            let frames = ["topview2", "topview3"]
            let frame = frames[currentAnimationFrame % frames.count]
            characterNode.texture = SKTexture(imageNamed: frame)
            currentAnimationFrame += 1
        } else {
            // Show topview1 (standing) when idle
            characterNode.texture = SKTexture(imageNamed: "topview1")
            currentAnimationFrame = 0
        }
    }
    
    private func startProximityCheckTimer() {
        proximityCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkProximityToLevelStations()
        }
    }
    
    private func checkProximityToLevelStations() {
        guard let characterNode = characterNode else { return }
        guard let gameState = gameState else { return }
        
        let charPos = characterNode.position
        
        // Check each level station
        for levelConfig in LEVEL_CONFIGS {
            let stationPos = CGPoint(x: levelConfig.mapX, y: levelConfig.mapY)
            let distance = hypot(charPos.x - stationPos.x, charPos.y - stationPos.y)
            
            // If character is close and level is available, enter it
            if distance < PROXIMITY_THRESHOLD && !isMoving && levelConfig.id <= gameState.currentLevel {
                //print("🗺️ ✓ Character near level \(levelConfig.id) - entering gameplay")
                enterLevel(levelConfig.id)
                return
            }
        }
    }
    
    private func enterLevel(_ levelId: Int) {
        guard let gameState = gameState else { return }
        guard let levelConfig = LEVEL_CONFIGS.first(where: { $0.id == levelId }) else { return }
        
        // Set the current level
        gameState.currentLevel = levelId
        
        // Get the next unlocked action (first action not yet completed)
        // For now, just use the first available action
        if let firstAction = levelConfig.availableActions.first {
            gameState.selectedAction = firstAction
            //print("🗺️ Auto-selected action: \(firstAction) for level \(levelId)")
        }
        
        // Start gameplay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.gameViewController?.startGameplay()
        }
    }
    
    // MARK: - Touch Handling
    
    override func handleTouchBegan(at point: CGPoint) {
        // Convert screen touch to map coordinates
        guard let camera = camera else { return }
        
        let _ = CGPoint(
            x: point.x - size.width / 2 + camera.position.x,
            y: point.y - size.height / 2 + camera.position.y
        )
        
        //print("🗺️ Touch began at screen: \(point), world: \(worldPoint)")
    }
    
    override func handleTouchEnded(at point: CGPoint) {
        print("\n🎯 TOUCH ENDED")
        print("   Scene size: \(size)")
        print("   Touch point (scene): \(point)")
        print("   Camera pos: \(camera?.position ?? .zero)")
        // Touch point is already in SCENE coordinates (0 to size.width, 0 to size.height)
        // We need to convert to WORLD coordinates
        guard let camera = camera else {
            print("   ❌ No camera!")
            return
        }
        
        print("   → Handling as character movement")
        
        // Convert SCENE coordinates to WORLD coordinates
        // Scene: 0,0 at bottom-left, size = (402, 874)
        // World: arbitrary large space (2000x2000)
        // Camera: positioned at world coordinate, with 2.0 zoom scale
        
        // Scene coordinate relative to scene center
        let sceneCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let pointFromCenter = CGPoint(x: point.x - sceneCenter.x, y: point.y - sceneCenter.y)
        
        print("   SceneCenter: \(sceneCenter)")
        print("   PointFromCenter: \(pointFromCenter)")
        
        // With camera scale 2.0, each scene pixel = 2 world pixels
        // Camera shows (size.width * scale) x (size.height * scale) of world
        let worldOffsetFromCamera = CGPoint(
            x: pointFromCenter.x * CAMERA_SCALE,
            y: pointFromCenter.y * CAMERA_SCALE
        )
        
        print("   WorldOffset: \(worldOffsetFromCamera)")
        
        // World position = camera position + world offset
        let worldPoint = CGPoint(
            x: camera.position.x + worldOffsetFromCamera.x,
            y: camera.position.y + worldOffsetFromCamera.y
        )
        
        // Clamp to map bounds
        let clampedPoint = CGPoint(
            x: max(0, min(worldPoint.x, MAP_WIDTH)),
            y: max(0, min(worldPoint.y, MAP_HEIGHT))
        )
        
        let charPos = characterNode?.position ?? .zero
        print("   TargetWorld: \(worldPoint) → clamped: \(clampedPoint)")
        print("   CharacterPos: \(charPos)")
        print("   Distance: \(hypot(clampedPoint.x - charPos.x, clampedPoint.y - charPos.y))")
        
        // Set target position for character to move to
        targetPosition = clampedPoint
        isMoving = true
        mapState?.isMoving = true
        
        // Update character rotation to face the target
        updateCharacterRotation(toward: clampedPoint)
    }
    
    private func updateCharacterRotation(toward targetPos: CGPoint) {
        guard let characterNode = characterNode else { return }
        
        let currentPos = characterNode.position
        let dx = targetPos.x - currentPos.x
        let dy = targetPos.y - currentPos.y
        
        // Calculate angle in radians (0 = right, π/2 = up)
        let angle = atan2(dy, dx)
        
        // Convert to degrees (0 = right, 90 = up)
        let degrees = angle * 180 / .pi
        
        // Adjust for topview sprites (which point UP by default)
        // We want: up = 0°, right = 90°, down = 180°, left = -90° (or 270°)
        // atan2 gives us: right = 0°, up = 90°, left = 180°, down = -90°
        // So we need to rotate by -90° to flip left/right
        let adjustedRotation = (degrees - 90) * .pi / 180
        
        characterNode.zRotation = adjustedRotation
    }
    
    @MainActor
    deinit {
        //print("🗺️ MapScene deinit - cleaning up")
        movementTimer?.invalidate()
        animationTimer?.invalidate()
        proximityCheckTimer?.invalidate()
        removeAllChildren()
        removeAllActions()
    }
}
