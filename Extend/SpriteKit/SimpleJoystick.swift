import SpriteKit

/// Simple virtual joystick for SpriteKit
/// Uses SpriteKit's center-origin coordinate system consistently
class SimpleJoystick: SKNode {
    
    // Visual components
    private let outerCircle: SKShapeNode
    private let innerThumb: SKShapeNode
    
    // Configuration
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let basePosition: CGPoint
    
    // State
    private(set) var isActive: Bool = false
    private(set) var direction: CGPoint = .zero  // Normalized vector (-1 to 1 in both axes)
    private(set) var magnitude: CGFloat = 0      // 0 to 1
    private(set) var currentTouch: UITouch?      // Current touch being tracked
    
    init(position: CGPoint, outerRadius: CGFloat = 80, innerRadius: CGFloat = 30) {
        self.basePosition = position
        self.outerRadius = outerRadius
        self.innerRadius = innerRadius
        
        // Create outer circle (stationary background)
        self.outerCircle = SKShapeNode(circleOfRadius: outerRadius)
        self.outerCircle.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5)
        self.outerCircle.strokeColor = .darkGray
        self.outerCircle.lineWidth = 2
        self.outerCircle.zPosition = 999
        
        // Create inner thumb (will move with touch)
        self.innerThumb = SKShapeNode(circleOfRadius: innerRadius)
        self.innerThumb.fillColor = SKColor(red: 0.5, green: 0.5, blue: 0.8, alpha: 0.8)
        self.innerThumb.strokeColor = .blue
        self.innerThumb.lineWidth = 2
        self.innerThumb.zPosition = 1000
        
        super.init()
        
        self.position = position
        self.zPosition = 999
        
        addChild(outerCircle)
        addChild(innerThumb)
        
        resetThumb()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Check if a touch point is within the joystick area
    /// This checks the ACTUAL node position, not the base position (which may have moved)
    func containsTouch(_ point: CGPoint) -> Bool {
        let distanceFromNode = hypot(point.x - position.x, point.y - position.y)
        return distanceFromNode < outerRadius + 20  // Add some tolerance
    }
    
    /// Handle touch began
    func touchBegan(at point: CGPoint, touch: UITouch) {
        guard containsTouch(point) else { return }
        
        isActive = true
        currentTouch = touch
        updateThumbPosition(for: point)
    }
    
    /// Handle touch moved
    func touchMoved(to point: CGPoint, touch: UITouch) {
        guard touch == currentTouch else { return }
        
        updateThumbPosition(for: point)
    }
    
    /// Handle touch ended
    func touchEnded(touch: UITouch) {
        guard touch == currentTouch else { return }
        
        isActive = false
        currentTouch = nil
        direction = .zero
        magnitude = 0
        resetThumb()
    }
    
    /// Update thumb position and calculate direction vector
    private func updateThumbPosition(for touchPoint: CGPoint) {
        // Get touch point relative to this node's position
        // Since this node is a child of uiLayer which is positioned at (camera.x - ..., camera.y - ...),
        // we need to calculate the offset from this node's center
        let dx = touchPoint.x - position.x
        let dy = touchPoint.y - position.y
        let distance = hypot(dx, dy)
        
        if distance == 0 {
            magnitude = 0
            direction = .zero
            resetThumb()
            return
        }
        
        // Normalize the direction
        let normalizedX = dx / distance
        let normalizedY = dy / distance
        
        // Clamp magnitude to 0-1
        magnitude = min(distance / outerRadius, 1.0)
        
        // Store normalized direction (already normalized above)
        direction = CGPoint(x: normalizedX, y: normalizedY)
        
        // Move thumb: either at touch point (if inside) or at edge (if outside)
        let thumbDistance = min(distance, outerRadius)
        let thumbX = normalizedX * thumbDistance
        let thumbY = normalizedY * thumbDistance
        
        innerThumb.position = CGPoint(x: thumbX, y: thumbY)
    }
    
    /// Reset thumb to center
    private func resetThumb() {
        innerThumb.position = .zero  // Center of this node
    }
}
