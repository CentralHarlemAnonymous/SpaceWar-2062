//
//  ShipProfiles.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 3/14/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit

// MARK: - ShipProfile

/// Static description of a ship type. All per-type constants live here;
/// runtime state (position, velocity, …) stays on Ship.
struct ShipProfile {
    // Identity
    let typeName:           String

    // Appearance
    let indicatorColor:     SKColor     // border arrow, distance labels, buttons
    let shipColor:          SKColor     // stroke color of the live ship node
    let shipPath:           CGPath      // canonical, unscaled path used to draw the ship
    let muzzleY:            CGFloat     // y of the firing tip in ship-local coordinates
    let headDotRadius:      CGFloat     // radius of the nose dot; 0 = no dot
    let headDotY:           CGFloat     // y of the nose dot in ship-local coordinates

    // Border direction indicator
    let indicatorPath:      CGPath      // pre-scaled silhouette for the edge arrow
    let indicatorLineWidth: CGFloat
    let indicatorGlowWidth: CGFloat
    let indicatorHasHeadDot: Bool       // whether the edge arrow shows a nose dot

    // Physics
    let maxSpeed:           CGFloat     // points/sec
    let acceleration:       CGFloat     // points/sec²
    let turnSpeed:          CGFloat     // radians/sec
    let bulletSpeed:        CGFloat     // points/sec (must exceed maxSpeed)

    // Gameplay
    let minFireInterval:    TimeInterval // minimum seconds between shots
    let startingBullets:    Int          // default bullet inventory (overridden by UI slider)
    let armorFront:         Int          // hits to kill when struck from front (≥1)
    let armorRear:          Int          // hits to kill when struck from rear  (≥1)

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
            typeName:            "needle",
            indicatorColor:      SKColor(red: 0.9, green: 0.45, blue: 0.15, alpha: 1),
            shipColor:           .white,
            shipPath:            path,
            muzzleY:             21,
            headDotRadius:       8,
            headDotY:            21,
            indicatorPath:       ip,
            indicatorLineWidth:  1.2,
            indicatorGlowWidth:  1,
            indicatorHasHeadDot: true,
            maxSpeed:            400,
            acceleration:        250,
            turnSpeed:           .pi * 2,
            bulletSpeed:         480,
            minFireInterval:     0.15,
            startingBullets:     40,
            armorFront:          1,
            armorRear:           1
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
            typeName:            "dart",
            indicatorColor:      SKColor(red: 0.25, green: 0.6, blue: 1.0, alpha: 1),
            shipColor:           .white,
            shipPath:            path,
            muzzleY:             16,
            headDotRadius:       0,
            headDotY:            0,
            indicatorPath:       ip,
            indicatorLineWidth:  1.8,
            indicatorGlowWidth:  3,
            indicatorHasHeadDot: false,
            maxSpeed:            400,
            acceleration:        250,
            turnSpeed:           .pi * 2,
            bulletSpeed:         480,
            minFireInterval:     0.15,
            startingBullets:     40,
            armorFront:          1,
            armorRear:           1
        )
    }()
}

// MARK: - Ship

final class Ship {
    let node: SKShapeNode
    let flame: SKShapeNode
    var velocity: CGVector = .zero
    var spawnPosition: CGPoint
    let name: String
    let profile: ShipProfile

    init(profile: ShipProfile, flame: SKShapeNode, spawn: CGPoint) {
        self.profile = profile
        self.node = SKShapeNode(path: profile.shipPath)
        self.node.strokeColor = profile.shipColor
        self.node.lineWidth = 2
        self.node.glowWidth = 4
        self.node.zPosition = 1

        self.flame = flame
        self.flame.alpha = 0
        self.node.addChild(flame)

        self.spawnPosition = spawn
        self.name = profile.typeName
        self.node.name = profile.typeName
        self.node.position = spawn

        // Head dot (nose marker) — only for ships that have one
        if profile.headDotRadius > 0 {
            let dot = SKShapeNode(circleOfRadius: profile.headDotRadius)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: 0, y: profile.headDotY)
            dot.zPosition = 3
            dot.name = "needleHeadDot"
            self.node.addChild(dot)
        }
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
    }
}
