//
//  ShipProfiles.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 3/14/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit

// MARK: - Ship Stat Enums

enum InventorySize {
    case small   // 0.5x multiplier
    case medium  // 1.0x multiplier
    case large   // 2.0x multiplier
    
    var multiplier: CGFloat {
        switch self {
        case .small:  return 0.5
        case .medium: return 1.0
        case .large:  return 2.0
        }
    }
    
    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }
}

enum FireRate {
    case slow    // 2.0x interval (slower)
    case medium  // 1.0x interval
    case fast    // 0.5x interval (faster)
    
    var multiplier: CGFloat {
        switch self {
        case .slow:   return 2.0
        case .medium: return 1.0
        case .fast:   return 0.5
        }
    }
    
    var label: String {
        switch self {
        case .slow:   return "Slow"
        case .medium: return "Medium"
        case .fast:   return "Fast"
        }
    }
}

enum FlightSpeed {
    case slow    // 0.8x max speed, acceleration, and turn speed
    case medium  // 1.0x max speed, acceleration, and turn speed
    case fast    // 1.25x max speed, acceleration, and turn speed
    
    var multiplier: CGFloat {
        switch self {
        case .slow:   return 0.8
        case .medium: return 1.0
        case .fast:   return 1.25
        }
    }
    
    var label: String {
        switch self {
        case .slow:   return "Slow"
        case .medium: return "Medium"
        case .fast:   return "Fast"
        }
    }
}

enum HitPoints {
    case low     // 0.5x
    case medium  // 1.0x
    case high    // 1.5x
    
    var multiplier: CGFloat {
        switch self {
        case .low:    return 0.5
        case .medium: return 1.0
        case .high:   return 1.5
        }
    }
    
    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}

enum BulletPower {
    case low     // 0.5 damage
    case medium  // 1.0 damage
    case high    // 1.5 damage
    
    var damage: CGFloat {
        switch self {
        case .low:    return 0.5
        case .medium: return 1.0
        case .high:   return 1.5
        }
    }
    
    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}

enum ShieldType {
    case none  // All hits treated equally
    case back  // 75% HP in rear, 25% HP in front
    
    var label: String {
        switch self {
        case .none: return "None"
        case .back: return "Rear"
        }
    }
}

enum TurnRate {
    case slow    // 0.7x turn speed
    case medium  // 1.0x turn speed
    case fast    // 1.3x turn speed
    
    var multiplier: CGFloat {
        switch self {
        case .slow:   return 0.7
        case .medium: return 1.0
        case .fast:   return 1.3
        }
    }
    
    var label: String {
        switch self {
        case .slow:   return "Slow"
        case .medium: return "Medium"
        case .fast:   return "Fast"
        }
    }
}

// MARK: - ShipProfile

/// Static description of a ship type. All per-type constants live here;
/// runtime state (position, velocity, …) stays on Ship.
struct ShipProfile {
    // Identity
    let typeName:           String
    let notes:              String      // Description shown in ship selection UI

    // Appearance
    let indicatorColor:     SKColor     // border arrow, distance labels, buttons
    let shipColor:          SKColor     // stroke color of the live ship node
    let shipLineWidth:      CGFloat     // line width of the ship's path
    let shipGlowWidth:      CGFloat     // glow width of the ship's path
    let shipPath:           CGPath      // canonical, unscaled path used to draw the ship
    let muzzleY:            CGFloat     // y of the firing tip in ship-local coordinates
    let headDotRadius:      CGFloat     // radius of the nose dot; 0 = no dot
    let headDotY:           CGFloat     // y of the nose dot in ship-local coordinates

    // Border direction indicator
    let indicatorPath:      CGPath      // pre-scaled silhouette for the edge arrow
    let indicatorLineWidth: CGFloat
    let indicatorGlowWidth: CGFloat
    let indicatorHasHeadDot: Bool       // whether the edge arrow shows a nose dot

    // Base physics values (modified by stat multipliers)
    let baseMaxSpeed:       CGFloat     // points/sec (modified by flightSpeed)
    let baseAcceleration:   CGFloat     // points/sec²
    let baseTurnSpeed:      CGFloat     // radians/sec (modified by turnRate)
    let baseBulletSpeed:    CGFloat     // points/sec (must exceed maxSpeed after modifiers)
    let baseFireInterval:   TimeInterval // base seconds between shots (modified by fireRate)
    let baseStartingBullets: Int        // base bullet inventory (modified by inventory)
    let baseHitPoints:      CGFloat     // base hit points (modified by hitPoints)

    // Ship stats (affect gameplay)
    let inventory:          InventorySize
    let fireRate:           FireRate
    let flightSpeed:        FlightSpeed
    let hitPoints:          HitPoints
    let bulletPower:        BulletPower
    let shield:             ShieldType
    let turnRate:           TurnRate
    
    // Gameplay control
    let playableByHuman:    Bool        // if false, ship is AI-only and hidden from ship selector
    
    // MARK: - Computed Properties (Apply Multipliers)
    
    var maxSpeed: CGFloat {
        return baseMaxSpeed * flightSpeed.multiplier
    }
    
    var acceleration: CGFloat {
        return baseAcceleration * flightSpeed.multiplier
    }
    
    var turnSpeed: CGFloat {
        return baseTurnSpeed * turnRate.multiplier * flightSpeed.multiplier
    }
    
    var bulletSpeed: CGFloat {
        // Ensure bullet speed always exceeds ship max speed
        let baseSpeed = baseBulletSpeed
        let shipMax = maxSpeed
        return max(baseSpeed, shipMax * 1.2)
    }
    
    var minFireInterval: TimeInterval {
        return baseFireInterval * TimeInterval(fireRate.multiplier)
    }
    
    var startingBullets: Int {
        return baseStartingBullets
    }
    
    var maxHitPoints: CGFloat {
        return baseHitPoints * hitPoints.multiplier
    }

    // MARK: Built-in profiles

    static let needle: ShipProfile = {
        // Ship body
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -24))
        path.addLine(to: CGPoint(x: 0, y: 18))
        path.move(to: CGPoint(x: -3, y: -16)); path.addLine(to: CGPoint(x:  3, y: -16))
        path.move(to: CGPoint(x: -3, y:  -8)); path.addLine(to: CGPoint(x:  3, y:  -8))
        path.move(to: CGPoint(x: -4, y:   0)); path.addLine(to: CGPoint(x:  4, y:   0))
        path.move(to: CGPoint(x: -3, y:   8)); path.addLine(to: CGPoint(x:  3, y:   8))

        // Indicator silhouette at 50 % scale
        let s: CGFloat = 0.50
        let ip = CGMutablePath()
        ip.move(to: CGPoint(x: 0,     y: -24*s)); ip.addLine(to: CGPoint(x:    0, y: 18*s))
        ip.move(to: CGPoint(x: -3*s,  y: -16*s)); ip.addLine(to: CGPoint(x:  3*s, y: -16*s))
        ip.move(to: CGPoint(x: -3*s,  y:  -8*s)); ip.addLine(to: CGPoint(x:  3*s, y:  -8*s))
        ip.move(to: CGPoint(x: -4*s,  y:   0   )); ip.addLine(to: CGPoint(x:  4*s, y:   0))
        ip.move(to: CGPoint(x: -3*s,  y:   8*s)); ip.addLine(to: CGPoint(x:  3*s, y:   8*s))

        return ShipProfile(
            typeName:            "Needle",
            notes:               "Classic balanced fighter.",
            indicatorColor:      SKColor(red: 0.9, green: 0.45, blue: 0.15, alpha: 1),
            shipColor:           .white,
            shipLineWidth:       2,
            shipGlowWidth:       4,
            shipPath:            path,
            muzzleY:             21,
            headDotRadius:       8,
            headDotY:            21,
            indicatorPath:       ip,
            indicatorLineWidth:  1.2,
            indicatorGlowWidth:  1,
            indicatorHasHeadDot: true,
            baseMaxSpeed:        400,
            baseAcceleration:    250,
            baseTurnSpeed:       .pi * 2,
            baseBulletSpeed:     480,
            baseFireInterval:    0.15,
            baseStartingBullets: 40,
            baseHitPoints:       1.0,
            inventory:           .medium,
            fireRate:            .medium,
            flightSpeed:         .medium,
            hitPoints:           .medium,
            bulletPower:         .medium,
            shield:              .none,
            turnRate:            .medium,
            playableByHuman:     true
        )
    }()

    static let dart: ShipProfile = {
        // Ship body
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 16))
        path.addLine(to: CGPoint(x:  14, y: -14))
        path.addLine(to: CGPoint(x: 0,   y:  -6))
        path.addLine(to: CGPoint(x: -14, y: -14))
        path.addLine(to: CGPoint(x: 0,   y:  16))

        // Indicator silhouette at 85 % scale
        let s: CGFloat = 0.85
        let ip = CGMutablePath()
        ip.move(to: CGPoint(x: 0,      y:  16*s))
        ip.addLine(to: CGPoint(x:  14*s, y: -14*s))
        ip.addLine(to: CGPoint(x: 0,     y:  -6*s))
        ip.addLine(to: CGPoint(x: -14*s, y: -14*s))
        ip.addLine(to: CGPoint(x: 0,     y:  16*s))

        return ShipProfile(
            typeName:            "Wedge",
            notes:               "Classic balanced fighter.",
            indicatorColor:      SKColor(red: 0.25, green: 0.6, blue: 1.0, alpha: 1),
            shipColor:           .white,
            shipLineWidth:       2,
            shipGlowWidth:       4,
            shipPath:            path,
            muzzleY:             16,
            headDotRadius:       0,
            headDotY:            0,
            indicatorPath:       ip,
            indicatorLineWidth:  1.8,
            indicatorGlowWidth:  3,
            indicatorHasHeadDot: false,
            baseMaxSpeed:        400,
            baseAcceleration:    250,
            baseTurnSpeed:       .pi * 2,
            baseBulletSpeed:     480,
            baseFireInterval:    0.15,
            baseStartingBullets: 40,
            baseHitPoints:       1.0,
            inventory:           .medium,
            fireRate:            .medium,
            flightSpeed:         .medium,
            hitPoints:           .medium,
            bulletPower:         .medium,
            shield:              .none,
            turnRate:            .medium,
            playableByHuman:     true
        )
    }()
    
    static let maagaa: ShipProfile = {
        // Baseball cap shape - corrected based on your clarification
        let path = CGMutablePath()
        
        // Crown (large main circle) - complete
        let crownRadius: CGFloat = 16
        let crownCenterY: CGFloat = 0
        
        path.addArc(center: CGPoint(x: 0, y: crownCenterY),
                    radius: crownRadius,
                    startAngle: 0,
                    endAngle: .pi * 2,
                    clockwise: false)
        
        // Brim at top - PARTIAL ELLIPSE (outer arc only, protruding from crown)
        // Wider, flatter brim that connects at the top of the crown
        let brimWidth: CGFloat = 28  // Wide brim
        let brimHeight: CGFloat = 26  // Tall enough to be prominent
        let brimCenterY: CGFloat = crownRadius  // Start at top of crown (y=16)
        
        let brimLeftX = -brimWidth / 2
        let brimRightX = brimWidth / 2
        let brimTopY = brimCenterY + brimHeight  // Top of brim at y=42
        
        // Calculate where the brim endpoints should connect to the crown
        // Use same x-coordinate for both crown and brim to create vertical lines
        let crownConnectionX: CGFloat = brimWidth / 2  // Where brim meets crown on each side (x = ±14)
        let crownConnectionY = sqrt(crownRadius * crownRadius - crownConnectionX * crownConnectionX)
        
        // Draw left connecting line from crown to brim (vertical)
        path.move(to: CGPoint(x: -crownConnectionX, y: crownConnectionY))
        path.addLine(to: CGPoint(x: -crownConnectionX, y: brimCenterY))
        
        // Draw brim arc
        path.addQuadCurve(
            to: CGPoint(x: brimRightX, y: brimCenterY),
            control: CGPoint(x: 0, y: brimTopY)
        )
        
        // Draw right connecting line from brim to crown (vertical)
        path.addLine(to: CGPoint(x: crownConnectionX, y: crownConnectionY))
        
        // Bottom ellipse - COMPLETE ellipse inset in the crown
        let ellipseWidth: CGFloat = 10
        let ellipseHeight: CGFloat = 5
        let ellipseCenterY: CGFloat = -13
        
        // Draw complete ellipse
        path.addEllipse(in: CGRect(
            x: -ellipseWidth / 2,
            y: ellipseCenterY - ellipseHeight / 2,
            width: ellipseWidth,
            height: ellipseHeight
        ))
        
        let muzzleY: CGFloat = brimTopY
        
        // Indicator silhouette at 65% scale
        let s: CGFloat = 0.65
        let ip = CGMutablePath()
        
        ip.addArc(center: CGPoint(x: 0, y: crownCenterY * s),
                  radius: crownRadius * s,
                  startAngle: 0,
                  endAngle: .pi * 2,
                  clockwise: false)
        
        // Simplified brim for indicator
        ip.move(to: CGPoint(x: brimLeftX * s, y: brimCenterY * s))
        ip.addQuadCurve(
            to: CGPoint(x: brimRightX * s, y: brimCenterY * s),
            control: CGPoint(x: 0, y: brimTopY * s)
        )
        
        return ShipProfile(
            typeName:            "Maa'gaa",
            notes:               "Slow but strong, best attacked head-on.",
            indicatorColor:      SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),  // Red
            shipColor:           .white,
            shipLineWidth:       1.0,
            shipGlowWidth:       2.75,
            shipPath:            path,
            muzzleY:             muzzleY,
            headDotRadius:       0,
            headDotY:            0,
            indicatorPath:       ip,
            indicatorLineWidth:  1.0,
            indicatorGlowWidth:  2,
            indicatorHasHeadDot: false,
            baseMaxSpeed:        400,
            baseAcceleration:    250,
            baseTurnSpeed:       .pi * 2,
            baseBulletSpeed:     480,
            baseFireInterval:    0.15,
            baseStartingBullets: 40,
            baseHitPoints:       1.0,
            inventory:           .large,
            fireRate:            .fast,
            flightSpeed:         .slow,
            hitPoints:           .high,
            bulletPower:         .low,
            shield:              .back,
            turnRate:            .slow,
            playableByHuman:     true
        )
    }()
    
    static let mysteryShip: ShipProfile = {
        // Simple UFO design - Option 1: Simple Geometric
        // 40px wide × 25px tall
        let path = CGMutablePath()
        
        // Small dome on top (semicircle)
        let domeRadius: CGFloat = 8
        let domeY: CGFloat = 8
        path.addArc(center: CGPoint(x: 0, y: domeY),
                    radius: domeRadius,
                    startAngle: 0,
                    endAngle: .pi,
                    clockwise: false)
        
        // Main oval body (ellipse)
        let bodyWidth: CGFloat = 40
        let bodyHeight: CGFloat = 12
        let bodyRect = CGRect(x: -bodyWidth/2, y: -bodyHeight/2,
                              width: bodyWidth, height: bodyHeight)
        path.addEllipse(in: bodyRect)
        
        // Three landing gear dots at bottom
        let gearRadius: CGFloat = 2
        let gearY: CGFloat = -10
        let gearSpacing: CGFloat = 14
        
        // Left gear
        path.addArc(center: CGPoint(x: -gearSpacing, y: gearY),
                    radius: gearRadius,
                    startAngle: 0,
                    endAngle: .pi * 2,
                    clockwise: false)
        // Center gear
        path.addArc(center: CGPoint(x: 0, y: gearY),
                    radius: gearRadius,
                    startAngle: 0,
                    endAngle: .pi * 2,
                    clockwise: false)
        // Right gear
        path.addArc(center: CGPoint(x: gearSpacing, y: gearY),
                    radius: gearRadius,
                    startAngle: 0,
                    endAngle: .pi * 2,
                    clockwise: false)
        
        // Indicator silhouette at 70% scale for off-screen arrow
        let s: CGFloat = 0.70
        let ip = CGMutablePath()
        
        // Dome
        ip.addArc(center: CGPoint(x: 0, y: domeY * s),
                  radius: domeRadius * s,
                  startAngle: 0,
                  endAngle: .pi,
                  clockwise: false)
        
        // Body
        let iBodyRect = CGRect(x: -bodyWidth * s / 2, y: -bodyHeight * s / 2,
                               width: bodyWidth * s, height: bodyHeight * s)
        ip.addEllipse(in: iBodyRect)
        
        // Landing gear (smaller for indicator)
        let iGearRadius = gearRadius * s
        let iGearY = gearY * s
        let iGearSpacing = gearSpacing * s
        
        ip.addArc(center: CGPoint(x: -iGearSpacing, y: iGearY),
                  radius: iGearRadius,
                  startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ip.addArc(center: CGPoint(x: 0, y: iGearY),
                  radius: iGearRadius,
                  startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ip.addArc(center: CGPoint(x: iGearSpacing, y: iGearY),
                  radius: iGearRadius,
                  startAngle: 0, endAngle: .pi * 2, clockwise: false)
        
        return ShipProfile(
            typeName:            "Mystery Ship",
            notes:               "A rare visitor from beyond...",
            indicatorColor:      SKColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1),  // Bright green
            shipColor:           SKColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1),  // Slightly lighter green
            shipLineWidth:       1.0,   // Thinner lines
            shipGlowWidth:       1.5,   // Less glow
            shipPath:            path,
            muzzleY:             0,  // Fires from center
            headDotRadius:       0,
            headDotY:            0,
            indicatorPath:       ip,
            indicatorLineWidth:  1.0,   // Thinner indicator lines
            indicatorGlowWidth:  1.5,   // Less indicator glow
            indicatorHasHeadDot: false,
            baseMaxSpeed:        400,
            baseAcceleration:    250,
            baseTurnSpeed:       .pi * 2,
            baseBulletSpeed:     480,
            baseFireInterval:    0.15,
            baseStartingBullets: 40,
            baseHitPoints:       1.0,
            inventory:           .small,    // Low
            fireRate:            .fast,     // High (fast = low interval)
            flightSpeed:         .medium,   // Changed from .fast to .medium (normal speed)
            hitPoints:           .low,      // Low
            bulletPower:         .low,      // Low
            shield:              .none,     // No shield
            turnRate:            .slow,     // Slow
            playableByHuman:     false      // AI-only
        )
    }()
    
    // MARK: - All Available Ships
    
    /// Array of all ship profiles available for selection
    static let allShips: [ShipProfile] = [needle, dart, maagaa, mysteryShip]
    
    // MARK: - Factory Methods
    
    /// Creates a flame node for thrust visualization.
    /// This is ship-design data and belongs in the profile system.
    func createFlameNode() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -18))
        path.addLine(to: CGPoint(x: -7, y: -30))
        path.addLine(to: CGPoint(x: 7, y: -30))
        path.closeSubpath()
        let flame = SKShapeNode(path: path)
        flame.fillColor = .orange
        flame.strokeColor = .yellow
        flame.lineWidth = 1.5
        flame.glowWidth = 3
        flame.zPosition = 3
        return flame
    }
}

// MARK: - Ship

final class Ship {
    let node: SKShapeNode
    let flame: SKShapeNode
    var velocity: CGVector = .zero
    var spawnPosition: CGPoint
    let name: String
    let profile: ShipProfile
    var score: Int = 0
    var scoreNode: SKNode?
    
    // Hit point tracking
    var currentHitPoints: CGFloat
    var frontHitPoints: CGFloat  // Only used if shield == .back
    var rearHitPoints: CGFloat   // Only used if shield == .back

    init(profile: ShipProfile, flame: SKShapeNode, spawn: CGPoint) {
        self.profile = profile
        self.node = SKShapeNode(path: profile.shipPath)
        self.node.strokeColor = profile.shipColor
        self.node.lineWidth = profile.shipLineWidth
        self.node.glowWidth = profile.shipGlowWidth
        self.node.zPosition = 1

        self.flame = flame
        self.flame.alpha = 0
        self.node.addChild(flame)

        self.spawnPosition = spawn
        self.name = profile.typeName
        self.node.name = profile.typeName
        self.node.position = spawn
        
        // Initialize hit points based on shield type
        let maxHP = profile.maxHitPoints
        print("🏥 Initializing HP for \(profile.typeName):")
        print("   baseHitPoints: \(profile.baseHitPoints)")
        print("   hitPoints multiplier: \(profile.hitPoints.multiplier)")
        print("   maxHitPoints: \(maxHP)")
        print("   shield type: \(profile.shield)")
        
        if profile.shield == .back {
            self.frontHitPoints = maxHP * 0.25
            self.rearHitPoints = maxHP * 0.75
            self.currentHitPoints = maxHP
        } else {
            self.currentHitPoints = maxHP
            self.frontHitPoints = 0
            self.rearHitPoints = 0
        }
        print("🆕 \(profile.typeName) initialized with \(currentHitPoints) HP (front: \(self.frontHitPoints), rear: \(self.rearHitPoints))")

        // Head dot (nose marker) — only for ships that have one
        if profile.headDotRadius > 0 {
            let dot = SKShapeNode(circleOfRadius: profile.headDotRadius)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: 0, y: profile.headDotY)
            dot.zPosition = 3
            dot.name = "headDot"
            self.node.addChild(dot)
        }
    }
    
    // MARK: - Hit Point Management
    
    /// Apply damage to the ship. Returns true if ship is destroyed.
    func takeDamage(_ damage: CGFloat, fromRear: Bool) -> Bool {
        print("💥 \(profile.typeName) taking \(damage) damage from \(fromRear ? "REAR" : "FRONT")")
        if profile.shield == .back {
            print("   Shield: .back | Front HP: \(frontHitPoints) | Rear HP: \(rearHitPoints)")
            // Shield system: separate front/rear HP pools
            if fromRear {
                rearHitPoints -= damage
                print("   → Rear HP after hit: \(rearHitPoints)")
                if rearHitPoints <= 0 {
                    currentHitPoints = 0
                    print("   ☠️ DESTROYED (rear shield depleted)")
                    return true
                }
            } else {
                frontHitPoints -= damage
                print("   → Front HP after hit: \(frontHitPoints)")
                if frontHitPoints <= 0 {
                    currentHitPoints = 0
                    print("   ☠️ DESTROYED (front shield depleted)")
                    return true
                }
            }
            currentHitPoints = frontHitPoints + rearHitPoints
            print("   ✓ Survived | Total HP: \(currentHitPoints)")
        } else {
            print("   No shield | HP: \(currentHitPoints)")
            // No shield: single HP pool
            currentHitPoints -= damage
            print("   → HP after hit: \(currentHitPoints)")
            if currentHitPoints <= 0 {
                print("   ☠️ DESTROYED")
                return true
            }
            print("   ✓ Survived")
        }
        return false
    }
    
    /// Reset hit points to maximum (called on respawn)
    func resetHitPoints() {
        let maxHP = profile.maxHitPoints
        if profile.shield == .back {
            frontHitPoints = maxHP * 0.25
            rearHitPoints = maxHP * 0.75
            currentHitPoints = maxHP
        } else {
            currentHitPoints = maxHP
            frontHitPoints = 0
            rearHitPoints = 0
        }
        print("♻️ \(profile.typeName) HP reset to \(currentHitPoints) (front: \(frontHitPoints), rear: \(rearHitPoints))")
    }

    func clampSpeed() {
        let spd = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if spd > profile.maxSpeed && spd > 0 {
            let k = profile.maxSpeed / spd
            velocity.dx *= k
            velocity.dy *= k
        }
    }

    func applyThrust(dt: CGFloat) {
        let ang = node.zRotation
        velocity.dx += -profile.acceleration * sin(ang) * dt
        velocity.dy +=  profile.acceleration * cos(ang) * dt
    }

    func integrate(dt: CGFloat) {
        node.position.x += velocity.dx * dt
        node.position.y += velocity.dy * dt
    }

    func alignRotationToVelocityIfMoving() {
        if abs(velocity.dx) + abs(velocity.dy) > 0.001 {
            node.zRotation = atan2(velocity.dy, velocity.dx) - .pi/2
        }
    }

    func reset() {
        node.position = spawnPosition
        node.zRotation = 0
        velocity = .zero
        node.isHidden = false
        resetHitPoints()
        // Restore head dot if present (important when resetting after game over)
        if profile.headDotRadius > 0 {
            node.childNode(withName: "headDot")?.alpha = 1
        }
    }
    
    // MARK: - Visibility
    
    var isVisible: Bool {
        return !node.isHidden
    }
    
    func hide() {
        print("🙈 \(profile.typeName).hide() called - HP: \(currentHitPoints)")
        node.isHidden = true
        velocity = .zero
        // Dim head dot if present
        if profile.headDotRadius > 0 {
            node.childNode(withName: "headDot")?.alpha = 0
        }
    }
    
    func show() {
        print("👁️ \(profile.typeName).show() called - HP before reset: \(currentHitPoints)")
        node.isHidden = false
        // Reset hit points when respawning
        resetHitPoints()
        print("👁️ \(profile.typeName).show() complete - HP after reset: \(currentHitPoints)")
        // Restore head dot if present
        if profile.headDotRadius > 0 {
            node.childNode(withName: "headDot")?.alpha = 1
        }
    }
    
    // MARK: - Combat
    
    func muzzleOffset() -> CGPoint {
        return CGPoint(x: 0, y: profile.muzzleY)
    }
    
    func createDebrisPieces() -> [SKShapeNode] {
        guard let path = node.path else { return [] }
        var pieces: [SKShapeNode] = []
        var lastPoint: CGPoint = .zero
        var firstPoint: CGPoint = .zero
        var isFirstMove = true
        
        path.applyWithBlock { elementPtr in
            let e = elementPtr.pointee
            switch e.type {
            case .moveToPoint:
                // Record the start point for this subpath
                lastPoint = e.points[0]
                if isFirstMove {
                    firstPoint = lastPoint
                    isFirstMove = false
                }
                
            case .addLineToPoint:
                // Create individual line segment
                let end = e.points[0]
                let segPath = CGMutablePath()
                segPath.move(to: lastPoint)
                segPath.addLine(to: end)
                
                let seg = SKShapeNode(path: segPath)
                seg.strokeColor = .white
                seg.lineWidth = profile.shipLineWidth
                seg.position = node.position
                seg.zRotation = node.zRotation
                seg.zPosition = node.zPosition
                pieces.append(seg)
                
                lastPoint = end
                
            case .addQuadCurveToPoint:
                // Create individual curve segment
                let end = e.points[1]
                let control = e.points[0]
                let segPath = CGMutablePath()
                segPath.move(to: lastPoint)
                segPath.addQuadCurve(to: end, control: control)
                
                let seg = SKShapeNode(path: segPath)
                seg.strokeColor = .white
                seg.lineWidth = profile.shipLineWidth
                seg.position = node.position
                seg.zRotation = node.zRotation
                seg.zPosition = node.zPosition
                pieces.append(seg)
                
                lastPoint = end
                
            case .addCurveToPoint:
                // Create individual curve segment
                let end = e.points[2]
                let control1 = e.points[0]
                let control2 = e.points[1]
                let segPath = CGMutablePath()
                segPath.move(to: lastPoint)
                segPath.addCurve(to: end, control1: control1, control2: control2)
                
                let seg = SKShapeNode(path: segPath)
                seg.strokeColor = .white
                seg.lineWidth = profile.shipLineWidth
                seg.position = node.position
                seg.zRotation = node.zRotation
                seg.zPosition = node.zPosition
                pieces.append(seg)
                
                lastPoint = end
                
            case .closeSubpath:
                // Create the closing line segment back to first point
                if lastPoint != firstPoint {
                    let segPath = CGMutablePath()
                    segPath.move(to: lastPoint)
                    segPath.addLine(to: firstPoint)
                    
                    let seg = SKShapeNode(path: segPath)
                    seg.strokeColor = .white
                    seg.lineWidth = 2
                    seg.position = node.position
                    seg.zRotation = node.zRotation
                    seg.zPosition = node.zPosition
                    pieces.append(seg)
                }
                
            @unknown default:
                break
            }
        }
        
        // For Maa'gaa, add the complete circle and ellipse as separate debris pieces
        if profile.typeName == "Maa'gaa" {
            // Crown circle
            let crownRadius: CGFloat = 16
            let crown = SKShapeNode(circleOfRadius: crownRadius)
            crown.strokeColor = .white
            crown.fillColor = .clear
            crown.lineWidth = profile.shipLineWidth
            crown.position = node.position
            crown.zRotation = node.zRotation
            crown.zPosition = node.zPosition
            pieces.append(crown)
            
            // Bottom ellipse (need to rotate it with the ship)
            let ellipseWidth: CGFloat = 10
            let ellipseHeight: CGFloat = 5
            let ellipseCenterY: CGFloat = -13
            let ellipsePath = CGMutablePath()
            ellipsePath.addEllipse(in: CGRect(
                x: -ellipseWidth / 2,
                y: ellipseCenterY - ellipseHeight / 2,
                width: ellipseWidth,
                height: ellipseHeight
            ))
            let ellipse = SKShapeNode(path: ellipsePath)
            ellipse.strokeColor = .white
            ellipse.fillColor = .clear
            ellipse.lineWidth = profile.shipLineWidth
            ellipse.position = node.position
            ellipse.zRotation = node.zRotation
            ellipse.zPosition = node.zPosition
            pieces.append(ellipse)
        }
        
        // Add head dot debris for ships that have one (e.g., needle)
        if profile.headDotRadius > 0 {
            let offsetY = profile.headDotY
            let ang = node.zRotation
            let ballPiece = SKShapeNode(circleOfRadius: profile.headDotRadius)
            ballPiece.fillColor = .white
            ballPiece.strokeColor = .clear
            ballPiece.position = CGPoint(
                x: node.position.x - offsetY * sin(ang),
                y: node.position.y + offsetY * cos(ang))
            ballPiece.zPosition = node.zPosition
            pieces.append(ballPiece)
        }
        
        return pieces
    }
}
