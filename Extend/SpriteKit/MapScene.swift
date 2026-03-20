import SpriteKit

// MARK: - CGVector Extension

extension CGVector {
    var normalized: CGVector {
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return CGVector.zero }
        return CGVector(dx: dx / length, dy: dy / length)
    }
}

/// SpriteKit scene for the level map - scrollable room with character and level stations
class MapScene: GameScene {
    // MARK: - Map Dimensions and Configuration
    private var MAP_WIDTH: CGFloat = 2000  // Will be set from room config
    private var MAP_HEIGHT: CGFloat = 2000  // Will be set from room config
    private let CHARACTER_SPEED: CGFloat = 400 // pixels per second
    private let PROXIMITY_THRESHOLD: CGFloat = 80 // distance to trigger level entry
    private var VISIBLE_AREA_WIDTH: CGFloat { MAP_WIDTH / 4 }  // Quarter of room width
    private var VISIBLE_AREA_HEIGHT: CGFloat { MAP_HEIGHT / 4 }  // Quarter of room height
    private let CAMERA_SCALE: CGFloat = 2.0  // Zoom level
    
    // MARK: - Nodes and State
    private var mapContainer: SKNode? // Container for all map content (moves with camera)
    private var hudContainer: SKNode? // Fixed HUD layer for level/points display
    private var characterNode: SKSpriteNode?
    private var levelStationNodes: [Int: SKShapeNode] = [:] // levelId -> node
    private var doorNodes: [String: SKShapeNode] = [:] // doorId -> node
    private var populationNodes: [String: SKLabelNode] = [:] // populationId -> node (emoji label)
    private var targetPosition: CGPoint? = nil
    private var isMoving = false
    private var currentAnimationFrame = 1
    private var currentRoomId: String = "main_map"  // Track which room we're in
    
    // MARK: - Timers
    private var movementTimer: Timer?
    private var animationTimer: Timer?
    private var proximityCheckTimer: Timer?
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        //print("🗺️ MapScene didMove - size: \(size)")
        
        // Load room dimensions from config
        if let roomConfig = getRoomConfig(currentRoomId) {
            MAP_WIDTH = CGFloat(roomConfig.width)
            MAP_HEIGHT = CGFloat(roomConfig.height)
            print("🗺️ Room '\(roomConfig.name)' dimensions: \(MAP_WIDTH) x \(MAP_HEIGHT)")
        }
        
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
        setupDoors()
        setupPopulation()
        setupCharacter()
        
        // Initialize camera
        setupCamera()
        
        // Start timers
        startMovementTimer()
        startAnimationTimer()
        startProximityCheckTimer()
        
        // Set up callback for level up notification
        if let gameState = gameState {
            gameState.onLevelUp = { [weak self] newLevel in
                // Update HUD through gameViewController
                let roomName = self?.currentRoomId ?? "main_map"
                if let roomConfig = getRoomConfig(roomName) {
                    self?.gameViewController?.updateHUDInfo(roomName: roomConfig.name, level: newLevel, points: gameState.currentPoints)
                }
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupMapBackground() {
        guard let container = mapContainer else { return }
        
        // Create a visible background grid area
        let background = SKShapeNode(rectOf: CGSize(width: MAP_WIDTH, height: MAP_HEIGHT))
        background.position = CGPoint(x: MAP_WIDTH / 2, y: MAP_HEIGHT / 2)
        
        // Get background color from room config
        var backgroundColor = SKColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1.0)  // Default gray
        if let roomConfig = getRoomConfig(currentRoomId) {
            // Use backgroundColor if defined
            if let hexColor = roomConfig.backgroundColor {
                backgroundColor = hexToColor(hexColor)
            }
        }
        
        background.fillColor = backgroundColor
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
        
        // Get only the level IDs for this room
        let levelsInRoom = getLevelsInRoom(currentRoomId)
        
        // Create level station boxes - filtered by room
        for levelConfig in LEVEL_CONFIGS {
            // Only show levels that are in this room
            guard levelsInRoom.contains(levelConfig.id) else { continue }
            
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
    
    private func setupDoors() {
        guard let container = mapContainer else { return }
        
        // Get all doors for the current room
        let doorsInRoom = getDoorsInRoom(currentRoomId)
        
        print("🚪 Setting up \(doorsInRoom.count) doors for room: \(currentRoomId)")
        
        for doorConfig in doorsInRoom {
            // Create door as a rectangle
            let doorSize = CGSize(width: doorConfig.width, height: doorConfig.height)
            let door = SKShapeNode(rectOf: doorSize)
            door.position = CGPoint(x: doorConfig.mapX, y: doorConfig.mapY)
            door.fillColor = hexToColor("#6F4E37")
            door.strokeColor = hexToColor("#5C4033")  // Bright purple border
            door.lineWidth = 3
            door.name = "door_\(doorConfig.id)"
            door.zPosition = 15
            container.addChild(door)
            
            // Add label with door name (or destination room ID as fallback)
            let label = SKLabelNode(fontNamed: "Arial")
            label.text = doorConfig.name ?? doorConfig.destinationRoomId
            label.fontSize = 20
            label.fontColor = .white
            label.position = CGPoint(x: doorConfig.mapX, y: doorConfig.mapY)
            label.zPosition = 16
            container.addChild(label)
            
            doorNodes[doorConfig.id] = door
        }
    }
    
    private func setupPopulation() {
        guard let container = mapContainer else { return }
        guard let roomConfig = getRoomConfig(currentRoomId) else { return }
        
        // Check if room has population config
        guard let populationConfig = roomConfig.population,
              !populationConfig.items.isEmpty,
              populationConfig.count > 0 else {
            return
        }
        
        print("🌟 Spawning \(populationConfig.count) population items in room: \(currentRoomId)")
        
        let roomPadding: CGFloat = 100  // Keep items away from edges
        let spawnableWidth = MAP_WIDTH - (roomPadding * 2)
        let spawnableHeight = MAP_HEIGHT - (roomPadding * 2)
        let fontSize = populationConfig.size ?? 40  // Default to 40 if not specified
        
        // Spawn population items at random positions
        for i in 0..<populationConfig.count {
            let randomX = CGFloat.random(in: roomPadding..<(roomPadding + spawnableWidth))
            let randomY = CGFloat.random(in: roomPadding..<(roomPadding + spawnableHeight))
            
            // Pick random emoji from items array
            let emoji = populationConfig.items.randomElement() ?? "⭐"
            
            // Create emoji as label node
            let populationNode = SKLabelNode(fontNamed: "Arial")
            populationNode.text = emoji
            populationNode.fontSize = fontSize
            populationNode.position = CGPoint(x: randomX, y: randomY)
            populationNode.name = "population_\(currentRoomId)_\(i)"
            populationNode.zPosition = 12
            container.addChild(populationNode)
            
            populationNodes[populationNode.name ?? ""] = populationNode
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
        
        // Check doors first
        let doorsInRoom = getDoorsInRoom(currentRoomId)
        for doorConfig in doorsInRoom {
            let doorPos = CGPoint(x: doorConfig.mapX, y: doorConfig.mapY)
            let distance = hypot(charPos.x - doorPos.x, charPos.y - doorPos.y)
            
            // If character touches a door, change rooms
            if distance < doorConfig.width / 2 && !isMoving {
                print("🚪 Character touched door: \(doorConfig.id) - entering room: \(doorConfig.destinationRoomId)")
                enterRoom(doorConfig.destinationRoomId, fromDoorId: doorConfig.returnDoorId)
                return
            }
        }
        
        // Check population items for collision
        let populationCollisionDistance: CGFloat = 50
        for (populationId, populationNode) in populationNodes {
            let distance = hypot(charPos.x - populationNode.position.x, charPos.y - populationNode.position.y)
            
            if distance < populationCollisionDistance {
                // Character collided with population item
                collectPopulation(populationId: populationId, populationNode: populationNode)
                return
            }
        }
        
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
        
        // IMPORTANT: Do NOT modify gameState.currentLevel here!
        // currentLevel represents the HIGHEST UNLOCKED level and should only increase
        // We'll pass the levelId to gameplay through a separate mechanism if needed
        
        // Auto-select the newest/last unlocked action (most recently added to availableActions)
        // For Level 1: ["rest"] → select rest
        // For Level 2: ["rest", "run"] → select run
        // For Level 3: ["rest", "run", "jump"] → select jump
        if let lastAction = levelConfig.availableActions.last {
            gameState.selectedAction = lastAction
            print("🗺️ Auto-selected action: \(lastAction) for level \(levelId)")
        }
        
        // Start gameplay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.gameViewController?.startGameplay()
        }
    }
    
    private func enterRoom(_ roomId: String, fromDoorId: String) {
        guard let mapState = mapState else { return }
        guard let returnDoor = getDoorConfig(fromDoorId) else {
            print("⚠️ Could not find return door: \(fromDoorId)")
            return
        }
        
        // Update current room
        currentRoomId = roomId
        
        // IMPORTANT: Load the new room's dimensions from config
        if let roomConfig = getRoomConfig(currentRoomId) {
            MAP_WIDTH = CGFloat(roomConfig.width)
            MAP_HEIGHT = CGFloat(roomConfig.height)
            print("🗺️ Entered room '\(roomConfig.name)' - dimensions: \(MAP_WIDTH) x \(MAP_HEIGHT)")
        }
        
        // Position character at the return door location, but offset away from the door
        // to prevent immediate re-collision and door looping
        let doorX = returnDoor.mapX
        let doorY = returnDoor.mapY
        
        // Offset character away from door by a safe distance (100 units)
        let offsetDistance: CGFloat = 100
        mapState.characterX = doorX + offsetDistance
        mapState.characterY = doorY
        
        // Clear and rebuild map content for new room
        mapContainer?.removeAllChildren()
        doorNodes.removeAll()
        levelStationNodes.removeAll()
        populationNodes.removeAll()
        
        // Rebuild the map for the new room
        setupMapBackground()
        setupLevelStations()
        setupDoors()
        setupPopulation()
        setupCharacter()
        
        // Update HUD with room info
        if let roomConfig = getRoomConfig(currentRoomId) {
            gameViewController?.updateHUDInfo(roomName: roomConfig.name, level: gameState?.currentLevel ?? 1, points: gameState?.currentPoints ?? 0)
        }
        
        // Update camera
        if let characterNode = characterNode {
            camera?.position = characterNode.position
        }
        
        print("🚪 Successfully entered room: \(roomId)")
    }
    
    private func collectPopulation(populationId: String, populationNode: SKLabelNode) {
        guard let container = mapContainer else { return }
        guard let roomConfig = getRoomConfig(currentRoomId) else { return }
        guard let populationConfig = roomConfig.population else { return }
        guard let gameState = gameState else { return }
        guard let view = view else { return }
        guard let camera = camera else { return }
        
        let pointsAwarded = populationConfig.points
        let pointsBeforeCollection = gameState.currentPoints
        
        print("🌟 Collected population item '\(populationNode.text ?? "?")' - \(pointsAwarded) points awarded")
        
        // Award points (but don't update HUD yet - wait until float animation completes)
        gameState.addPoints(pointsAwarded, action: "collect")
        
        // Create floating text showing points
        let pointsText = "+\(pointsAwarded)"
        let floatingTextNode = SKLabelNode(fontNamed: "Arial")
        floatingTextNode.text = pointsText
        floatingTextNode.fontSize = 32
        floatingTextNode.fontColor = hexToColor("#023020")  // Dark green color
        floatingTextNode.position = populationNode.position
        floatingTextNode.zPosition = 20
        container.addChild(floatingTextNode)
        
        // Calculate target position in HUD (points label is on right side of screen)
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        
        // Target the points VALUE position in the HUD, to the RIGHT of the number
        // The points value label is nested in a stack, positioned to the right
        // We want to target further right, past the value number
        let hudScreenX = screenWidth / 2 + 140  // Further right, past the points value
        let hudScreenY = screenHeight - 90  // Points label Y position
        
        // Convert screen coordinates to world coordinates
        let screenCenterX = screenWidth / 2
        let screenCenterY = screenHeight / 2
        
        // Offset from screen center
        let screenOffsetX = hudScreenX - screenCenterX
        let screenOffsetY = screenCenterY - hudScreenY
        
        // Convert to world coordinates
        let hudWorldX = camera.position.x + (screenOffsetX * CAMERA_SCALE)
        let hudWorldY = camera.position.y - (screenOffsetY * CAMERA_SCALE)
        
        print("🌟 Points float target:")
        print("   Screen HUD pos: (\(hudScreenX), \(hudScreenY))")
        print("   Screen center: (\(screenCenterX), \(screenCenterY))")
        print("   Camera pos: \(camera.position)")
        print("   World target: (\(hudWorldX), \(hudWorldY))")
        
        // Animate floating text to HUD position
        let moveToHUD = SKAction.move(to: CGPoint(x: hudWorldX, y: hudWorldY), duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveToHUD, fadeOut])
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([group, remove])
        floatingTextNode.run(sequence)
        
        // Create a collection animation for the population item
        let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
        let itemFadeOut = SKAction.fadeOut(withDuration: 0.2)
        let itemGroup = SKAction.group([scaleDown, itemFadeOut])
        let itemRemove = SKAction.removeFromParent()
        let itemSequence = SKAction.sequence([itemGroup, itemRemove])
        
        populationNode.run(itemSequence)
        
        // Remove from tracking dictionary IMMEDIATELY to prevent double collection
        // This prevents the proximity check timer from detecting the same collision again
        populationNodes.removeValue(forKey: populationId)
        
        // IMPORTANT: Delay the points increment animation until the floating text reaches the HUD
        // The float animation takes 0.8 seconds, so start the count animation then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let newTotal = gameState.currentPoints
            self.gameViewController?.animatePointsIncrease(from: pointsBeforeCollection, to: newTotal)
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
