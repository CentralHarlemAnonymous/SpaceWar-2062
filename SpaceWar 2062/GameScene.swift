//
//  GameScene.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 1/9/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit
import GameplayKit

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
        node.isHidden = false
    }
}

// MARK: - GameScene

final class GameScene: SKScene {

    private var lastLaidOutSize: CGSize = .zero

    // FIX #1 — safe-area insets so controls stay below the notch / above home bar
    private var safeAreaTopInset:    CGFloat = 0
    private var safeAreaBottomInset: CGFloat = 0

    private enum EdgeBehavior { case bounce, wrap }
    private var edgeBehavior: EdgeBehavior = .bounce

    private var needleScore: Int = 0
    private var dartScore: Int = 0
    private var needleScoreNode: SKNode!
    private var dartScoreNode: SKNode!

    private var optionsButton: SKShapeNode!
    private var optionsOverlay: SKNode?
    private var optionsVisible: Bool = false
    private var optionsDimmer: SKShapeNode?

    private enum OptionsTab { case game, environment, ships, about, shipSelection, network }
    private var currentOptionsTab: OptionsTab = .environment

    private var gameTabButton: SKShapeNode?
    private var optionsTabButton: SKShapeNode?
    private var shipsTabButton: SKShapeNode?
    private var aboutTabButton: SKShapeNode?
    private var shipSelectionTabButton: SKShapeNode?
    private var networkTabButton: SKShapeNode?
    private var shipSelectionContainer: SKNode?
    private var networkContainer: SKNode?
    private var aboutContainer: SKNode?

    // Needle AI
    private var needleAIEnabled: Bool = false
    // FIX #9 — 3 levels: 0=basic (current-pos), 1=predictive (quad), 2=expert (strategic)
    private var needleAIIntelligence: Int = 0
    private var aiNextThrustToggle: TimeInterval = 0
    private var aiThrustOn: Bool = false
    private var aiNextFireTime: TimeInterval = 0
    private var aiCertainFireCooldown: TimeInterval = 0

    // Wedge AI
    private var wedgeAIEnabled: Bool = false
    private var wedgeAIIntelligence: Int = 0
    private var wedgeAINextThrustToggle: TimeInterval = 0
    private var wedgeAIThrustOn: Bool = false
    private var wedgeAINextFireTime: TimeInterval = 0
    private var wedgeCertainFireCooldown: TimeInterval = 0
    private let neuralAI = NeuralAIController()

    // Observed acceleration for predictive firing
    private var dartPreviousVelocity: CGVector = .zero
    private var dartObservedAcceleration: CGVector = .zero
    private var dartSmoothedAcceleration: CGVector = .zero
    private var needlePreviousVelocity: CGVector = .zero
    private var needleObservedAcceleration: CGVector = .zero
    private var needleSmoothedAcceleration: CGVector = .zero

    // Game options
    private var aimPersistsAfterLift: Bool = true
    private var aimPersistToggleButton: SKShapeNode?

    private var activeAimTouches = Set<UITouch>()

    // Post-game-over drift AI
    private var driftNeedleThrustOn: Bool = false
    private var driftDartThrustOn: Bool = false
    private var driftNeedleNextToggle: TimeInterval = 0
    private var driftDartNextToggle: TimeInterval = 0
    private var driftNeedleTargetAngle: CGFloat = 0
    private var driftDartTargetAngle: CGFloat = 0
    private var driftNeedleNextTurn: TimeInterval = 0
    private var driftDartNextTurn: TimeInterval = 0

    // AI intelligence assigned randomly when each ship respawns during game-over mode (0–2)
    private var gameOverNeedleAILevel: Int = 0
    private var gameOverDartAILevel:   Int = 0

    // Camera switching during game-over exhibition
    private var gameOverFollowedShip: Ship?       // nil until game-over starts
    private var gameOverLastSwitchTime: TimeInterval = 0
    private var gameOverAnimationStartTime: TimeInterval = 0  // when AI/shooting begins (5s after game ends)

    private var gameOverLabelNode: SKNode?

    private var needleVisibleSince: TimeInterval = 0
    private var dartVisibleSince: TimeInterval = 0

    // FIX #8 — respawn delay: don't reappear until bullets fired before death have expired
    private var needleDestroyTime: TimeInterval = 0
    private var dartDestroyTime: TimeInterval = 0
    private var needleRespawnScheduled: Bool = false
    private var dartRespawnScheduled: Bool = false

    // Expert AI post-kill braking: record when each ship last scored a kill
    private var needleKillTime: TimeInterval = 0
    private var dartKillTime: TimeInterval = 0

    // FIX #5 — bullet limit choices: 10 / 50 / ∞  (3 positions, 2 steps)
    private var needleBulletLimitSelection: Int = 1   // default = 50
    private var dartBulletLimitSelection: Int = 1
    private let bulletSliderSteps: Int = 2
    private var needleBulletsRemaining: Int = 0
    private var dartBulletsRemaining: Int = 0
    private var needleBulletCounterNode: SKNode?
    private var dartBulletCounterNode: SKNode?

    private var bulletGravLabel: SKLabelNode?

    private var sunEnabled: Bool = true
    private var sunAffectsBullets: Bool = true
    private var sunNode: SKShapeNode?
    private let sunCollisionRadius: CGFloat = 28

    // Options UI elements
    private var edgeBounceButton: SKShapeNode?
    private var edgeWrapButton: SKShapeNode?
    private var aiToggleButton: SKShapeNode?
    private var wedgeAIToggleButton: SKShapeNode?
    private var sunToggleButton: SKShapeNode?
    private var bulletGravToggleButton: SKShapeNode?

    // Gravity slider: 10 steps, value = step × 4.0  →  0, 4, 8 … 40
    // Step 2 = 8.0 (original "strong" default)
    private var gravitySliderSelection: Int = 2
    private let gravitySliderSteps:     Int = 10
    private var gravitySliderTrack: SKShapeNode?
    private var gravitySliderKnob:  SKShapeNode?
    private var gravityValueLabel:  SKLabelNode?

    // Bullet-life slider: 10 steps, value = 1.5 + step × 0.75  →  1.5 … 9.0 s
    // Step 2 = 3.0 s (original "short" default)
    private var bulletLifeSliderSelection: Int = 2
    private let bulletLifeSliderSteps:     Int = 10
    private var bulletLifeSliderTrack: SKShapeNode?
    private var bulletLifeSliderKnob:  SKShapeNode?
    private var bulletLifeValueLabel:  SKLabelNode?

    // Computed values used throughout physics and AI
    private var gravityMultiplier: CGFloat { CGFloat(gravitySliderSelection) * 4.0 }
    private var bulletLifeSeconds: CGFloat { 1.5 + CGFloat(bulletLifeSliderSelection) * 0.75 }

    // Bullet sliders
    private var needleBulletSliderTrack: SKShapeNode?
    private var dartBulletSliderTrack: SKShapeNode?
    private var needleBulletSliderKnob: SKShapeNode?
    private var dartBulletSliderKnob: SKShapeNode?
    private let sliderTrackWidth: CGFloat = 200
    private let sliderTrackHalfWidth: CGFloat = 100

    // AI intelligence sliders — FIX #9: 3 positions (steps=2)
    private var needleAISliderTrack: SKShapeNode?
    private var needleAISliderKnob: SKShapeNode?
    private var wedgeAISliderTrack: SKShapeNode?
    private var wedgeAISliderKnob: SKShapeNode?
    private let aiIntelligenceSteps: Int = 2
    private let aiIntelligenceTrackWidth: CGFloat = 200
    private let aiIntelligenceTrackHalfWidth: CGFloat = 100

    // Slider drag touches
    private var draggingNeedleSliderTouch: UITouch?
    private var draggingDartSliderTouch: UITouch?
    private var draggingNeedleAISliderTouch: UITouch?
    private var draggingWedgeAISliderTouch: UITouch?
    private var draggingVirtualScreenSliderTouch: UITouch?
    private var draggingGravitySliderTouch: UITouch?
    private var draggingBulletLifeSliderTouch: UITouch?
    private var newMatchButtonTouch: UITouch?   // tracks press for invert-on-touch

    // Virtual screen mode
    private enum VirtualScreenMode { case off, medium }
    private var virtualScreenMode: VirtualScreenMode = .off
    private var virtualScreenSelection: Int = 0   // 0=off 1=on
    private let virtualScreenSteps: Int = 1
    private var virtualScreenSliderTrack: SKShapeNode?
    private var virtualScreenSliderKnob: SKShapeNode?
    private var savedVirtualScreenSelection: Int = 0   // player's choice, preserved across game-over
    private var virtualWorldWidth: CGFloat {
        switch virtualScreenMode {
        case .off:    return size.width
        case .medium: return max(3000, size.width)
        }
    }
    private var virtualWorldHeight: CGFloat {
        switch virtualScreenMode {
        case .off:    return size.height
        case .medium: return max(3000, size.height)
        }
    }

    // Camera (always present; fixed in non-virtual mode, follows ship in virtual mode)
    private var cameraNode = SKCameraNode()
    private var cameraCenter: CGPoint = .zero
    private var needleRespawnTarget: CGPoint = .zero
    private var dartRespawnTarget: CGPoint = .zero
    private var cameraPanToNeedleAfter: TimeInterval = 0
    private var cameraPanToDartAfter:   TimeInterval = 0

    // In virtual mode: which ship the camera follows.
    // Release build always follows dart (wedge). Debug follows needle when only needle is human.
    private var shipToFollow: Ship {
        #if DEBUG
        if !needleAIEnabled && wedgeAIEnabled { return needle }
        #endif
        return dart
    }

    // Stars + virtual boundary
    private var starNodes: [SKShapeNode] = []
    private var virtualBoundaryNode: SKShapeNode?

    // Direction arrows (shown when the other ship is off-screen in virtual mode)
    private var needleDirectionArrow: SKShapeNode?
    private var dartDirectionArrow:   SKShapeNode?
    private var sunDirectionArrow:    SKShapeNode?   // always points to virtual world centre
    private var needleDistanceLabel:  SKLabelNode?   // distance readout beside needle edge arrow
    private var dartDistanceLabel:    SKLabelNode?   // distance readout beside dart edge arrow

    // Cluster title labels
    private var rightClusterTitle: SKLabelNode?
    #if DEBUG
    private var leftClusterTitle: SKLabelNode?
    #endif

    var entities = [GKEntity]()
    var graphs = [String : GKGraph]()

    private var lastUpdateTime: TimeInterval = 0

    private var gameOver: Bool = false
    private var victorLabelNode: SKNode?
    private var enableRandomRespawn: Bool = false

    // Ships
    private var needle: Ship!
    private var dart: Ship!

    // Fire buttons
    private var fireThrustButton: SKShapeNode!
    #if DEBUG
    private var leftFireButtonRef: SKShapeNode?
    #endif

    // Aiming / rotation
    private var aimPoint: CGPoint?
    private let aimEpsilon: CGFloat = 0.01

    // Two target indicators: needle = orange, dart/wedge = blue
    private var needleTargetIndicator: SKShapeNode!
    private var dartTargetIndicator: SKShapeNode!

    private var rightThrustButton: SKShapeNode!
    #if DEBUG
    private var leftThrustButton: SKShapeNode!
    #endif
    private var isThrustingNeedle = false
    private var isThrustingDart = false

    private var activeRightThrustTouches = Set<UITouch>()
    #if DEBUG
    private var activeLeftThrustTouches = Set<UITouch>()
    #endif

    private struct FireTouchInfo {
        let ship: Ship
        let startTime: TimeInterval
        let startLocation: CGPoint
        weak var buttonNode: SKNode?
    }
    private var fireTouches: [ObjectIdentifier: FireTouchInfo] = [:]

    private func muzzleOffset(for ship: Ship) -> CGPoint {
        return CGPoint(x: 0, y: ship.profile.muzzleY)
    }

    private var missileOwner = NSMapTable<SKNode, SKShapeNode>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    private var missileSpawnTime = NSMapTable<SKNode, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private var wreckOwner = NSMapTable<SKNode, SKShapeNode>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    private var wreckPieceCount = NSMapTable<SKNode, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    // MARK: - Layout

    private func layoutForCurrentSize() {
        let s = self.size
        if s.width < 10 || s.height < 10 { return }
        if lastLaidOutSize == s { return }
        lastLaidOutSize = s

        let vw = virtualWorldWidth, vh = virtualWorldHeight
        let newNeedleSpawn = CGPoint(x: vw * 0.20, y: vh * 0.5)
        let newDartSpawn   = CGPoint(x: vw * 0.80, y: vh * 0.5)

        if needle != nil {
            let wasAtOrigin = needle.spawnPosition == .zero || needle.node.position == .zero
            needle.spawnPosition = newNeedleSpawn
            if wasAtOrigin && !needle.node.isHidden { needle.node.position = newNeedleSpawn }
        }
        if dart != nil {
            let wasAtOrigin = dart.spawnPosition == .zero || dart.node.position == .zero
            dart.spawnPosition = newDartSpawn
            if wasAtOrigin && !dart.node.isHidden { dart.node.position = newDartSpawn }
        }

        let buttonRadius: CGFloat = 40
        // FIX #1 — respect bottom safe area for on-screen buttons
        let bottomY = buttonRadius + 20 + safeAreaBottomInset
        if let fire = fireThrustButton {
            fire.position = CGPoint(x: s.width - buttonRadius - 20, y: bottomY)
            if let rightThrust = rightThrustButton {
                let rightPadding: CGFloat = 12
                rightThrust.position = CGPoint(x: fire.position.x - (buttonRadius * 2 + rightPadding), y: bottomY)
            }
            if let counter = dartBulletCounterNode {
                counter.position = CGPoint(x: fire.position.x, y: fire.position.y + buttonRadius + 20)
            }
            if let title = rightClusterTitle, let rightThrust = rightThrustButton {
                let clusterCenterX = (fire.position.x + rightThrust.position.x) / 2
                title.position = CGPoint(x: clusterCenterX, y: fire.position.y + buttonRadius + 50)
            }
        }

        #if DEBUG
        if let leftFire = leftFireButtonRef {
            let leftButtonRadius: CGFloat = 40
            leftFire.position = CGPoint(x: leftButtonRadius + 20, y: bottomY)
            if let leftThrust = leftThrustButton {
                let leftPadding: CGFloat = 12
                leftThrust.position = CGPoint(x: leftFire.position.x + (leftButtonRadius * 2 + leftPadding), y: bottomY)
            }
            if let needleCounter = needleBulletCounterNode {
                needleCounter.position = CGPoint(x: leftFire.position.x, y: leftFire.position.y + leftButtonRadius + 20)
            }
            if let leftTitle = leftClusterTitle {
                leftTitle.position = CGPoint(x: leftFire.position.x, y: leftFire.position.y + leftButtonRadius + 50)
            }
        }
        #endif

        // FIX #1 — respect top safe area for HUD
        let topY = s.height - 30 - safeAreaTopInset
        needleScoreNode?.position = CGPoint(x: 24, y: topY)
        dartScoreNode?.position = CGPoint(x: s.width - 24, y: topY)
        optionsButton?.position = CGPoint(x: s.width / 2, y: topY)
        optionsOverlay?.position = CGPoint(x: s.width / 2, y: s.height / 2)

        sunNode?.position = CGPoint(x: virtualWorldWidth / 2, y: virtualWorldHeight / 2)
    }

    // MARK: - Lifecycle

    override func sceneDidLoad() {
        self.lastUpdateTime = 0
        self.backgroundColor = .black

        // Camera – always present.  In non-virtual mode it sits at the screen centre and never moves.
        cameraCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        cameraNode.zPosition = 1000
        addChild(cameraNode)
        self.camera = cameraNode
        cameraNode.position = cameraCenter

        let needleSpawn = CGPoint(x: size.width * 0.20, y: size.height * 0.5)
        let dartSpawn   = CGPoint(x: size.width * 0.80, y: size.height * 0.5)

        needle = Ship(profile: .needle, flame: createFlameNode(), spawn: needleSpawn)
        dart   = Ship(profile: .dart,   flame: createFlameNode(), spawn: dartSpawn)

        addChild(needle.node)
        addChild(dart.node)

        let nowVisible = CACurrentMediaTime()
        needleVisibleSince = nowVisible
        dartVisibleSince = nowVisible

        // Firing direction lines
        let needleMuzzleY = needle.profile.muzzleY
        let needleFiringLinePath = CGMutablePath()
        needleFiringLinePath.move(to: CGPoint(x: 0, y: needleMuzzleY))
        needleFiringLinePath.addLine(to: CGPoint(x: 0, y: needleMuzzleY + 20))
        let needleFiringLine = SKShapeNode(path: needleFiringLinePath)
        needleFiringLine.strokeColor = .white
        needleFiringLine.lineWidth = 1
        needleFiringLine.zPosition = 2
        needle.node.addChild(needleFiringLine)

        let dartMuzzleY = dart.profile.muzzleY
        let dartFiringLinePath = CGMutablePath()
        dartFiringLinePath.move(to: CGPoint(x: 0, y: dartMuzzleY))
        dartFiringLinePath.addLine(to: CGPoint(x: 0, y: dartMuzzleY + 20))
        let dartFiringLine = SKShapeNode(path: dartFiringLinePath)
        dartFiringLine.strokeColor = .white
        dartFiringLine.lineWidth = 1
        dartFiringLine.zPosition = 2
        dart.node.addChild(dartFiringLine)

        // Fire button (right / wedge)
        let buttonRadius: CGFloat = 40
        fireThrustButton = SKShapeNode(circleOfRadius: buttonRadius)
        fireThrustButton.position = CGPoint(x: size.width - buttonRadius - 20, y: buttonRadius + 20)
        fireThrustButton.strokeColor = .white
        fireThrustButton.lineWidth = 3
        fireThrustButton.fillColor = SKColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 0.7)
        fireThrustButton.zPosition = 10
        addChild(fireThrustButton)

        let rightFireLabel = SKLabelNode(text: "FIRE")
        rightFireLabel.fontName = "AvenirNext-Bold"
        rightFireLabel.fontSize = 14
        rightFireLabel.fontColor = .white
        rightFireLabel.verticalAlignmentMode = .center
        rightFireLabel.horizontalAlignmentMode = .center
        rightFireLabel.zPosition = 11
        rightFireLabel.alpha = 0.9
        fireThrustButton.addChild(rightFireLabel)

        // Right thrust button — same radius as fire button
        let rightPadding: CGFloat = 12
        rightThrustButton = SKShapeNode(circleOfRadius: buttonRadius)
        rightThrustButton.position = CGPoint(
            x: fireThrustButton.position.x - (buttonRadius * 2 + rightPadding),
            y: fireThrustButton.position.y
        )
        rightThrustButton.strokeColor = .white
        rightThrustButton.lineWidth = 3
        rightThrustButton.fillColor = fireThrustButton.fillColor
        rightThrustButton.zPosition = fireThrustButton.zPosition + 1
        addChild(rightThrustButton)

        let rightThrustLabel = SKLabelNode(text: "THRUST")
        rightThrustLabel.fontName = "AvenirNext-Bold"
        rightThrustLabel.fontSize = 14
        rightThrustLabel.fontColor = .white
        rightThrustLabel.verticalAlignmentMode = .center
        rightThrustLabel.horizontalAlignmentMode = .center
        rightThrustLabel.zPosition = 11
        rightThrustLabel.alpha = 0.9
        rightThrustButton.addChild(rightThrustLabel)

        let rightCluster = SKLabelNode(text: "WEDGE")
        rightCluster.fontName = "AvenirNext-Bold"
        rightCluster.fontSize = 16
        rightCluster.fontColor = .white
        rightCluster.verticalAlignmentMode = .center
        rightCluster.horizontalAlignmentMode = .center
        let clusterCenterX = (fireThrustButton.position.x + rightThrustButton.position.x) / 2
        rightCluster.position = CGPoint(x: clusterCenterX, y: fireThrustButton.position.y + buttonRadius + 50)
        rightCluster.zPosition = 11
        addChild(rightCluster)
        self.rightClusterTitle = rightCluster

        // Target indicators — needle = orange, wedge/dart = blue
        needleTargetIndicator = SKShapeNode(circleOfRadius: 18)
        needleTargetIndicator.fillColor = .clear
        needleTargetIndicator.strokeColor = SKColor(red: 0.9, green: 0.45, blue: 0.15, alpha: 1.0)
        needleTargetIndicator.lineWidth = 2
        needleTargetIndicator.zPosition = 50
        needleTargetIndicator.alpha = 0
        addChild(needleTargetIndicator)

        dartTargetIndicator = SKShapeNode(circleOfRadius: 18)
        dartTargetIndicator.fillColor = .clear
        dartTargetIndicator.strokeColor = SKColor(red: 0.15, green: 0.45, blue: 0.9, alpha: 1.0)
        dartTargetIndicator.lineWidth = 2
        dartTargetIndicator.zPosition = 50
        dartTargetIndicator.alpha = 0
        addChild(dartTargetIndicator)

        // Scores
        needleScoreNode = SKNode()
        dartScoreNode = SKNode()
        needleScoreNode.position = CGPoint(x: 24, y: size.height - 30)
        dartScoreNode.position = CGPoint(x: size.width - 24, y: size.height - 30)
        addChild(needleScoreNode)
        addChild(dartScoreNode)
        updateScoreDisplays()

        // Options button
        let optRadius: CGFloat = 16
        optionsButton = SKShapeNode(circleOfRadius: optRadius)
        optionsButton.position = CGPoint(x: size.width / 2, y: size.height - 30)
        optionsButton.strokeColor = .white
        optionsButton.lineWidth = 2
        optionsButton.fillColor = SKColor(white: 0.2, alpha: 0.6)
        optionsButton.zPosition = 100
        optionsButton.name = "optionsButton"
        let optLabel = SKLabelNode(text: "⋯")
        optLabel.fontName = "AvenirNext-Bold"
        optLabel.fontSize = 18
        optLabel.fontColor = .white
        optLabel.verticalAlignmentMode = .center
        optLabel.horizontalAlignmentMode = .center
        optLabel.zPosition = 101
        optionsButton.addChild(optLabel)
        addChild(optionsButton)

        setupOptionsOverlay()
        optionsOverlay?.isHidden = true

        if optionsDimmer == nil {
            let dimmer = SKShapeNode()   // sized in setupOptionsOverlay when w/h are known
            dimmer.fillColor = SKColor(white: 0.0, alpha: 1.0)
            dimmer.strokeColor = .clear
            dimmer.zPosition = 200   // just behind bg (bg is 201)
            dimmer.isHidden = true
            dimmer.name = "options_dimmer"
            self.optionsDimmer = dimmer
            // dimmer is added as a child of optionsOverlay in setupOptionsOverlay
        }

        // Bullet counter over right fire button
        let dartCounter = SKNode()
        dartCounter.position = CGPoint(x: fireThrustButton.position.x, y: fireThrustButton.position.y + buttonRadius + 20)
        dartCounter.zPosition = 12
        addChild(dartCounter)
        self.dartBulletCounterNode = dartCounter

        #if DEBUG
        let leftButtonRadius: CGFloat = 40
        let leftFireButton = SKShapeNode(circleOfRadius: leftButtonRadius)
        self.leftFireButtonRef = leftFireButton
        leftFireButton.position = CGPoint(x: leftButtonRadius + 20, y: leftButtonRadius + 20)
        leftFireButton.strokeColor = .white
        leftFireButton.lineWidth = 3
        leftFireButton.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 0.7)
        leftFireButton.zPosition = 10
        addChild(leftFireButton)

        let leftFireLabel = SKLabelNode(text: "FIRE")
        leftFireLabel.fontName = "AvenirNext-Bold"
        leftFireLabel.fontSize = 14
        leftFireLabel.fontColor = .white
        leftFireLabel.verticalAlignmentMode = .center
        leftFireLabel.horizontalAlignmentMode = .center
        leftFireLabel.zPosition = 11
        leftFireLabel.alpha = 0.9
        leftFireButton.addChild(leftFireLabel)

        let needleCounter = SKNode()
        needleCounter.position = CGPoint(x: leftFireButton.position.x, y: leftFireButton.position.y + leftButtonRadius + 20)
        needleCounter.zPosition = 12
        addChild(needleCounter)
        self.needleBulletCounterNode = needleCounter

        let leftPadding: CGFloat = 12
        leftThrustButton = SKShapeNode(circleOfRadius: leftButtonRadius)
        leftThrustButton.position = CGPoint(
            x: leftFireButton.position.x + (leftButtonRadius * 2 + leftPadding),
            y: leftFireButton.position.y
        )
        leftThrustButton.strokeColor = .white
        leftThrustButton.lineWidth = 3
        leftThrustButton.fillColor = leftFireButton.fillColor
        leftThrustButton.zPosition = leftFireButton.zPosition + 1
        addChild(leftThrustButton)

        let leftThrustLabel = SKLabelNode(text: "THRUST")
        leftThrustLabel.fontName = "AvenirNext-Bold"
        leftThrustLabel.fontSize = 14
        leftThrustLabel.fontColor = .white
        leftThrustLabel.verticalAlignmentMode = .center
        leftThrustLabel.horizontalAlignmentMode = .center
        leftThrustLabel.zPosition = 11
        leftThrustLabel.alpha = 0.9
        leftThrustButton.addChild(leftThrustLabel)

        let leftCluster = SKLabelNode(text: "NEEDLE")
        leftCluster.fontName = "AvenirNext-Bold"
        leftCluster.fontSize = 16
        leftCluster.fontColor = .white
        leftCluster.verticalAlignmentMode = .center
        leftCluster.horizontalAlignmentMode = .center
        // Position directly above the fire button (same x as bullet counter), not midpoint of cluster
        leftCluster.position = CGPoint(x: leftFireButton.position.x, y: leftFireButton.position.y + leftButtonRadius + 50)
        leftCluster.zPosition = 11
        addChild(leftCluster)
        self.leftClusterTitle = leftCluster
        #endif

        updateNeedleControlsVisibility()
        updateWedgeControlsVisibility()
        resetBulletCountsFromSelections()
        refreshBulletCounters()
        endGameIfNoBullets()
        applySunState()

        setupStars()
        setupVirtualBoundary()
        setupDirectionArrows()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
        // FIX #1 — read safe area insets so HUD avoids notch / home indicator.
        // IMPORTANT: reset lastLaidOutSize so layoutForCurrentSize() actually runs
        // again with the correct insets (sceneDidLoad already ran it, but without
        // safe-area knowledge, so the early-return guard would otherwise skip us).
        if #available(iOS 11.0, *) {
            safeAreaTopInset    = view.safeAreaInsets.top
            safeAreaBottomInset = view.safeAreaInsets.bottom
        }
        lastLaidOutSize = .zero
        layoutForCurrentSize()
        setupStars()  // size is now valid; sceneDidLoad called this with size==.zero
        // UIKit often hasn't propagated safe-area insets to SKView yet on the first call
        // (especially on iPhone with notch/Dynamic Island). A deferred pass picks up the real values.
        DispatchQueue.main.async { [weak self] in
            guard let self, let v = self.view else { return }
            if #available(iOS 11.0, *) {
                self.safeAreaTopInset    = v.safeAreaInsets.top
                self.safeAreaBottomInset = v.safeAreaInsets.bottom
            }
            self.lastLaidOutSize = .zero
            self.layoutForCurrentSize()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        lastLaidOutSize = .zero   // force re-layout; safe area insets already stored
        layoutForCurrentSize()
        setupStars()  // re-spread stars across the new screen size
    }

    private func updateNeedleControlsVisibility() {
        #if DEBUG
        leftThrustButton?.isHidden = needleAIEnabled
        leftFireButtonRef?.isHidden = needleAIEnabled
        // leftClusterTitle stays visible: it labels the bullet counter which is always shown
        #endif
    }

    private func updateWedgeControlsVisibility() {
        fireThrustButton?.isHidden = wedgeAIEnabled
        rightThrustButton?.isHidden = wedgeAIEnabled
    }

    private func setOptionsVisible(_ show: Bool) {
        optionsVisible = show
        optionsOverlay?.isHidden = !show
        optionsDimmer?.isHidden = !show
    }

    // MARK: - Ship Shapes

    private func createFlameNode() -> SKShapeNode {
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

    // MARK: - Rotation helpers

    private func shortestAngleBetween(_ angle1: CGFloat, _ angle2: CGFloat) -> CGFloat {
        let twoPi = CGFloat.pi * 2
        var angle = (angle2 - angle1).truncatingRemainder(dividingBy: twoPi)
        if angle >= .pi  { angle -= twoPi }
        if angle <= -.pi { angle += twoPi }
        return angle
    }

    private func rotateShip(_ ship: Ship, toward worldPoint: CGPoint, dt: TimeInterval) {
        let shipNode = ship.node
        let dx = worldPoint.x - shipNode.position.x
        let dy = worldPoint.y - shipNode.position.y
        let targetAngle = atan2(dy, dx) - .pi / 2
        let currentAngle = shipNode.zRotation
        let angleDiff = shortestAngleBetween(currentAngle, targetAngle)
        if abs(angleDiff) <= aimEpsilon { shipNode.zRotation = targetAngle; return }
        let step = ship.profile.turnSpeed * CGFloat(dt)
        if abs(angleDiff) <= step {
            shipNode.zRotation = targetAngle
        } else {
            shipNode.zRotation += (angleDiff > 0 ? step : -step)
        }
    }

    // MARK: - AI Helpers

    /// Predict where `target` will be when a bullet fired from `shooter` arrives.
    /// FIX #9 — only two modes: intelligence 0 = current pos, 1+ = quadratic (vel+acc)
    private func predictedAimPoint(shooter: Ship, target: Ship, intelligence: Int) -> CGPoint {
        guard intelligence >= 1 else { return target.node.position }

        let origin    = shooter.node.position
        let bulletSpeed = shooter.profile.bulletSpeed
        let targetPos = target.node.position
        let targetVel = target.velocity
        let acc = (target === dart) ? dartSmoothedAcceleration : needleSmoothedAcceleration

        var t = hypot(targetPos.x - origin.x, targetPos.y - origin.y) / bulletSpeed
        for _ in 0..<10 {
            let predicted = CGPoint(
                x: targetPos.x + targetVel.dx * t + 0.5 * acc.dx * t * t,
                y: targetPos.y + targetVel.dy * t + 0.5 * acc.dy * t * t)
            t = hypot(predicted.x - origin.x, predicted.y - origin.y) / bulletSpeed
        }
        return CGPoint(
            x: targetPos.x + targetVel.dx * t + 0.5 * acc.dx * t * t,
            y: targetPos.y + targetVel.dy * t + 0.5 * acc.dy * t * t)
    }

    /// Simulate `ship`'s trajectory under gravity and return true if it will
    /// hit the sun within `seconds` seconds.
    private func shipWillHitSun(_ ship: Ship, in seconds: CGFloat, steps: Int = 20) -> Bool {
        guard let sun = sunNode else { return false }
        let simStep = seconds / CGFloat(steps)
        var px = ship.node.position.x, py = ship.node.position.y
        var vx = ship.velocity.dx,     vy = ship.velocity.dy
        let sx = sun.position.x, sy = sun.position.y
        let sunR = sunCollisionRadius + 10
        let baseG: CGFloat = 18000 * gravityMultiplier
        for _ in 0..<steps {
            let dx = sx - px, dy = sy - py
            let r2 = dx*dx + dy*dy + 100
            let invR = 1.0 / sqrt(r2)
            let a = baseG / r2
            vx += dx * invR * a * simStep
            vy += dy * invR * a * simStep
            px += vx * simStep
            py += vy * simStep
            if (px-sx)*(px-sx) + (py-sy)*(py-sy) <= sunR*sunR { return true }
        }
        return false
    }

    /// Simulate a bullet fired from `ship` at its current rotation and return
    /// true if it will hit the sun before expiring.
    private func simulateBulletHitsSun(from ship: Ship, target: Ship? = nil) -> Bool {
        guard let sun = sunNode else { return false }
        let angle = ship.node.zRotation
        let bulletSpeed = ship.profile.bulletSpeed
        var bx = ship.node.position.x, by = ship.node.position.y
        var bvx = -bulletSpeed * sin(angle), bvy = bulletSpeed * cos(angle)
        let simStep: CGFloat = 0.05
        let fullLife: CGFloat = bulletLifeSeconds
        let simLife: CGFloat
        if let t = target {
            let toDist = hypot(t.node.position.x - bx, t.node.position.y - by)
            let travelTime = toDist / bulletSpeed
            simLife = min(fullLife, travelTime + 0.5)
        } else {
            simLife = fullLife
        }
        let simSteps = Int(simLife / simStep)
        let sx = sun.position.x, sy = sun.position.y
        let sunR = sunCollisionRadius
        let baseG: CGFloat = 18000 * gravityMultiplier * (5.0 / 8.0)
        for _ in 0..<simSteps {
            if sunAffectsBullets {
                let dx = sx - bx, dy = sy - by
                let r2 = dx*dx + dy*dy + 100
                let invR = 1.0 / sqrt(r2)
                let a = baseG / r2
                bvx += dx * invR * a * simStep
                bvy += dy * invR * a * simStep
            }
            bx += bvx * simStep
            by += bvy * simStep
            if (bx-sx)*(bx-sx) + (by-sy)*(by-sy) <= sunR*sunR { return true }
        }
        return false
    }

    // MARK: - Level-2 AI (Strategic + Edge-Aware)

    /// In wrap mode, returns the nearest torus-copy of `targetPos` to `origin`.
    private func nearestVirtualPosition(of targetPos: CGPoint, from origin: CGPoint) -> CGPoint {
        guard edgeBehavior == .wrap else { return targetPos }
        let W = virtualWorldWidth, H = virtualWorldHeight
        var best = targetPos
        var bestD2 = CGFloat.greatestFiniteMagnitude
        for ix in [-1, 0, 1] as [CGFloat] {
            for iy in [-1, 0, 1] as [CGFloat] {
                let candidate = CGPoint(x: targetPos.x + ix * W,
                                        y: targetPos.y + iy * H)
                let d2 = (candidate.x - origin.x) * (candidate.x - origin.x)
                       + (candidate.y - origin.y) * (candidate.y - origin.y)
                if d2 < bestD2 { bestD2 = d2; best = candidate }
            }
        }
        return best
    }

    /// Level-2 firing solution: quadratic prediction aimed at the nearest virtual
    /// copy of the target, with 15 iterations for accuracy.
    private func level3AimPoint(shooter: Ship, target: Ship) -> CGPoint {
        let bulletSpeed = shooter.profile.bulletSpeed
        let origin = shooter.node.position
        var targetPos = target.node.position
        if edgeBehavior == .wrap {
            targetPos = nearestVirtualPosition(of: targetPos, from: origin)
        }
        let targetVel = target.velocity
        let acc = (target === dart) ? dartSmoothedAcceleration : needleSmoothedAcceleration
        var t = hypot(targetPos.x - origin.x, targetPos.y - origin.y) / bulletSpeed
        for _ in 0..<15 {
            let px = targetPos.x + targetVel.dx * t + 0.5 * acc.dx * t * t
            let py = targetPos.y + targetVel.dy * t + 0.5 * acc.dy * t * t
            t = hypot(px - origin.x, py - origin.y) / bulletSpeed
        }
        let predicted = CGPoint(
            x: targetPos.x + targetVel.dx * t + 0.5 * acc.dx * t * t,
            y: targetPos.y + targetVel.dy * t + 0.5 * acc.dy * t * t)
        if edgeBehavior == .bounce {
            return CGPoint(x: max(0, min(virtualWorldWidth,  predicted.x)),
                           y: max(0, min(virtualWorldHeight, predicted.y)))
        }
        return predicted
    }

    private func collisionDecision(ship: Ship, opponent: Ship,
                                   killTime: TimeInterval, currentTime: TimeInterval) -> Bool {
        let speed = hypot(ship.velocity.dx, ship.velocity.dy)
        let opponentDown = opponent.node.isHidden
        let recentKill = (currentTime - killTime) < 4.0
        if opponentDown && recentKill && speed > 80 { return true }
        guard !opponent.node.isHidden else { return false }

        let odx = opponent.node.position.x - ship.node.position.x
        let ody = opponent.node.position.y - ship.node.position.y
        let dist = hypot(odx, ody)
        guard dist < 400 && dist > 1 else { return false }

        let rvx = ship.velocity.dx - opponent.velocity.dx
        let rvy = ship.velocity.dy - opponent.velocity.dy
        let rvMag = hypot(rvx, rvy)
        let approachSpeed = (rvx * odx + rvy * ody) / dist
        guard approachSpeed > 15 else { return false }
        let minSep: CGFloat = rvMag > 1 ? abs(odx * rvy - ody * rvx) / rvMag : dist
        let ttca = dist / max(approachSpeed, 1)
        return ttca < 3.0 && minSep < 90
    }

    private func huntAimPoint(shooter: Ship, target: Ship) -> CGPoint {
        let myPos = shooter.node.position
        let oppPos = (edgeBehavior == .wrap)
            ? nearestVirtualPosition(of: target.node.position, from: myPos)
            : target.node.position
        let dist = hypot(oppPos.x - myPos.x, oppPos.y - myPos.y)
        let closeThreshold: CGFloat = 60
        let farThreshold:   CGFloat = 120
        if dist <= closeThreshold { return oppPos }
        let intercept = level3AimPoint(shooter: shooter, target: target)
        if dist >= farThreshold   { return intercept }
        let t = (dist - closeThreshold) / (farThreshold - closeThreshold)
        return CGPoint(x: oppPos.x + t * (intercept.x - oppPos.x),
                       y: oppPos.y + t * (intercept.y - oppPos.y))
    }

    private func collisionAvoidancePoint(for ship: Ship, opponent: Ship) -> CGPoint {
        let myPos = ship.node.position
        let myVel = ship.velocity
        let oppVel = opponent.velocity
        let oppSpeed = hypot(oppVel.dx, oppVel.dy)

        let retrograde = CGPoint(x: myPos.x - myVel.dx, y: myPos.y - myVel.dy)
        guard oppSpeed > 20 else { return retrograde }

        let invSpd = 1.0 / oppSpeed
        let perpX = -oppVel.dy * invSpd
        let perpY =  oppVel.dx * invSpd
        let perp1 = CGPoint(x: myPos.x + perpX * 200, y: myPos.y + perpY * 200)
        let perp2 = CGPoint(x: myPos.x - perpX * 200, y: myPos.y - perpY * 200)

        let cur = ship.node.zRotation
        func angleTo(_ p: CGPoint) -> CGFloat { atan2(p.y - myPos.y, p.x - myPos.x) - .pi / 2 }
        let dRetro = abs(shortestAngleBetween(cur, angleTo(retrograde)))
        let dPerp1 = abs(shortestAngleBetween(cur, angleTo(perp1)))
        let dPerp2 = abs(shortestAngleBetween(cur, angleTo(perp2)))

        if dPerp1 <= dRetro && dPerp1 <= dPerp2 { return perp1 }
        if dPerp2 <= dRetro                      { return perp2 }
        return retrograde
    }

    private func ownBulletWillHit(shooter: Ship, target: Ship, hitRadius: CGFloat = 18) -> Bool {
        var found = false
        enumerateChildNodes(withName: "missile") { node, _ in
            guard !found,
                  let owner = self.missileOwner.object(forKey: node),
                  owner === shooter.node,
                  let data = node.userData,
                  let vx = data["vx"] as? CGFloat,
                  let vy = data["vy"] as? CGFloat else { return }
            var bx = node.position.x, by = node.position.y
            var bvx = vx, bvy = vy
            var tx = target.node.position.x, ty = target.node.position.y
            let tvx = target.velocity.dx,    tvy = target.velocity.dy
            let simStep: CGFloat = 0.05
            let simLife: CGFloat = self.bulletLifeSeconds
            let simSteps = Int(simLife / simStep)
            let baseG: CGFloat = 18000 * self.gravityMultiplier * (5.0 / 8.0)
            for _ in 0..<simSteps {
                if let sun = self.sunNode {
                    if self.sunAffectsBullets {
                        let sdx = sun.position.x - bx, sdy = sun.position.y - by
                        let r2 = sdx*sdx + sdy*sdy + 100
                        let a  = baseG / r2
                        let invR = 1.0 / sqrt(r2)
                        bvx += sdx * invR * a * simStep
                        bvy += sdy * invR * a * simStep
                    }
                    let sdx = sun.position.x - bx, sdy = sun.position.y - by
                    if sdx*sdx + sdy*sdy <= self.sunCollisionRadius * self.sunCollisionRadius { return }
                }
                bx += bvx * simStep; by += bvy * simStep
                tx += tvx * simStep; ty += tvy * simStep
                let ddx = bx - tx, ddy = by - ty
                if ddx*ddx + ddy*ddy <= hitRadius * hitRadius { found = true; return }
            }
        }
        return found
    }

    private func bulletWillHit(shooter: Ship, target: Ship, hitRadius: CGFloat = 18) -> Bool {
        let angle = shooter.node.zRotation
        let bulletSpeed = shooter.profile.bulletSpeed
        var bx = shooter.node.position.x, by = shooter.node.position.y
        var bvx = -bulletSpeed * sin(angle), bvy = bulletSpeed * cos(angle)
        let simStep: CGFloat = 0.05
        let simLife: CGFloat = bulletLifeSeconds
        let simSteps = Int(simLife / simStep)
        var tx = target.node.position.x, ty = target.node.position.y
        let tvx = target.velocity.dx,    tvy = target.velocity.dy
        let baseG: CGFloat = 18000 * gravityMultiplier * (5.0 / 8.0)

        for _ in 0..<simSteps {
            if let sun = sunNode {
                if sunAffectsBullets {
                    let sdx = sun.position.x - bx, sdy = sun.position.y - by
                    let r2  = sdx*sdx + sdy*sdy + 100
                    let a   = baseG / r2
                    let invR = 1.0 / sqrt(r2)
                    bvx += sdx * invR * a * simStep
                    bvy += sdy * invR * a * simStep
                }
                let sdx = sun.position.x - bx, sdy = sun.position.y - by
                if sdx*sdx + sdy*sdy <= sunCollisionRadius * sunCollisionRadius { return false }
            }
            bx += bvx * simStep; by += bvy * simStep
            tx += tvx * simStep; ty += tvy * simStep
            let ddx = bx - tx, ddy = by - ty
            if ddx*ddx + ddy*ddy <= hitRadius * hitRadius { return true }
        }
        return false
    }

    private func bulletHitUnavoidable(for ship: Ship, horizon: CGFloat = 1.2) -> Bool {
        var found = false
        enumerateChildNodes(withName: "missile") { node, _ in
            guard !found,
                  let data = node.userData,
                  let vx = data["vx"] as? CGFloat,
                  let vy = data["vy"] as? CGFloat else { return }
            let rdx = node.position.x - ship.node.position.x
            let rdy = node.position.y - ship.node.position.y
            let rvx = vx - ship.velocity.dx
            let rvy = vy - ship.velocity.dy
            let rvMag = hypot(rvx, rvy)
            guard rvMag > 1 else { return }
            let ttca = max(0, -(rdx * rvx + rdy * rvy) / (rvMag * rvMag))
            guard ttca < horizon else { return }
            let minSep = abs(rdx * rvy - rdy * rvx) / rvMag
            if minSep < 15 { found = true }
        }
        return found
    }

    private func edgeAwareBulletDanger(for ship: Ship,
                                        opponent: Ship? = nil,
                                        lookAhead: CGFloat = 2.5) -> (danger: Bool, awayPoint: CGPoint) {
        let dangerMinSep: CGFloat = 80
        var worstMinSep = CGFloat.greatestFiniteMagnitude
        var worstClosestPos = CGPoint.zero

        enumerateChildNodes(withName: "missile") { node, _ in
            guard let data = node.userData,
                  let vx = data["vx"] as? CGFloat,
                  let vy = data["vy"] as? CGFloat else { return }

            let rdx = node.position.x - ship.node.position.x
            let rdy = node.position.y - ship.node.position.y
            let rvx = vx - ship.velocity.dx
            let rvy = vy - ship.velocity.dy
            let rvMag = hypot(rvx, rvy)
            guard rvMag > 1 else { return }

            let ttca = max(0, min(lookAhead, -(rdx * rvx + rdy * rvy) / (rvMag * rvMag)))
            let minSep = abs(rdx * rvy - rdy * rvx) / rvMag
            let closestPos = CGPoint(x: node.position.x + vx * ttca,
                                     y: node.position.y + vy * ttca)

            if minSep < dangerMinSep && ttca < lookAhead {
                if minSep < worstMinSep { worstMinSep = minSep; worstClosestPos = closestPos }
            }
        }

        if let opp = opponent, !opp.node.isHidden {
            let oppPos = (edgeBehavior == .wrap)
                ? nearestVirtualPosition(of: opp.node.position, from: ship.node.position)
                : opp.node.position
            let odx = oppPos.x - ship.node.position.x
            let ody = oppPos.y - ship.node.position.y
            let dist = hypot(odx, ody)
            let shipDangerRadius: CGFloat = 110
            if dist < shipDangerRadius {
                if dist < worstMinSep { worstMinSep = dist; worstClosestPos = oppPos }
            }
        }

        if worstMinSep < dangerMinSep {
            let away = CGPoint(
                x: ship.node.position.x - (worstClosestPos.x - ship.node.position.x),
                y: ship.node.position.y - (worstClosestPos.y - ship.node.position.y))
            return (true, away)
        }
        return (false, .zero)
    }

    private func strategicPositionTarget(for ship: Ship, opponent: Ship,
                                         pursueBehind: Bool = false) -> CGPoint {
        guard !opponent.node.isHidden else {
            return level3AimPoint(shooter: ship, target: opponent)
        }

        let myPos  = ship.node.position
        let oppPos = (edgeBehavior == .wrap)
            ? nearestVirtualPosition(of: opponent.node.position, from: myPos)
            : opponent.node.position

        let dx   = myPos.x - oppPos.x
        let dy   = myPos.y - oppPos.y
        let dist = hypot(dx, dy)
        let idealRange: CGFloat = 260

        if abs(dist - idealRange) < 240 {
            return level3AimPoint(shooter: ship, target: opponent)
        }

        let oppSpeed = hypot(opponent.velocity.dx, opponent.velocity.dy)

        if pursueBehind && oppSpeed > 10 {
            let invSpd = 1.0 / oppSpeed
            let behindX = oppPos.x - opponent.velocity.dx * invSpd * 280
            let behindY = oppPos.y - opponent.velocity.dy * invSpd * 280
            let m: CGFloat = 50
            return CGPoint(x: max(m, min(virtualWorldWidth  - m, behindX)),
                           y: max(m, min(virtualWorldHeight - m, behindY)))
        }

        let perpX: CGFloat
        let perpY: CGFloat
        if oppSpeed > 10 {
            perpX = -opponent.velocity.dy / oppSpeed
            perpY =  opponent.velocity.dx / oppSpeed
        } else {
            let safe = dist > 1 ? dist : 1
            perpX = -dy / safe
            perpY =  dx / safe
        }

        let c1 = CGPoint(x: oppPos.x + perpX * idealRange, y: oppPos.y + perpY * idealRange)
        let c2 = CGPoint(x: oppPos.x - perpX * idealRange, y: oppPos.y - perpY * idealRange)

        func score(_ p: CGPoint) -> CGFloat {
            var s: CGFloat = 0
            if let sun = sunNode {
                let sdx = p.x - sun.position.x, sdy = p.y - sun.position.y
                s += 60_000 / max(sdx*sdx + sdy*sdy, 1)
            }
            if edgeBehavior == .bounce {
                let margin: CGFloat = 90
                let ex = min(p.x, size.width  - p.x)
                let ey = min(p.y, size.height - p.y)
                if ex < margin { s += (margin - ex) * 4 }
                if ey < margin { s += (margin - ey) * 4 }
            }
            let tdx = p.x - myPos.x, tdy = p.y - myPos.y
            s += hypot(tdx, tdy) * 0.08
            return s
        }

        func clamp(_ p: CGPoint) -> CGPoint {
            let m: CGFloat = 50
            return CGPoint(x: max(m, min(virtualWorldWidth  - m, p.x)),
                           y: max(m, min(virtualWorldHeight - m, p.y)))
        }

        return score(c1) <= score(c2) ? clamp(c1) : clamp(c2)
    }

    // MARK: - Missiles

    private func fireMissile(from ship: Ship, muzzleOffset: CGPoint) {
        if ship.node.isHidden { return }

        if ship === needle {
            if needleBulletsRemaining == 0 { return }
        } else if ship === dart {
            if dartBulletsRemaining == 0 { return }
        }

        let missile = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
        missile.name = "missile"
        missile.fillColor = .white
        missile.strokeColor = .white
        missile.glowWidth = 4
        missile.zPosition = 20

        let angle = ship.node.zRotation
        let dx = muzzleOffset.x * cos(angle) - muzzleOffset.y * sin(angle)
        let dy = muzzleOffset.x * sin(angle) + muzzleOffset.y * cos(angle)
        missile.position = CGPoint(x: ship.node.position.x + dx, y: ship.node.position.y + dy)
        addChild(missile)

        let velocityMagnitude = ship.profile.bulletSpeed
        let vx = -velocityMagnitude * sin(angle)
        let vy =  velocityMagnitude * cos(angle)
        missile.userData = ["vx": vx, "vy": vy, "bounced": false]

        missileOwner.setObject(ship.node, forKey: missile)
        missileSpawnTime.setObject(NSNumber(value: CACurrentMediaTime()), forKey: missile)

        let life = TimeInterval(bulletLifeSeconds)
        missile.run(.sequence([.wait(forDuration: life), .removeFromParent()]))

        if ship === needle {
            if needleBulletsRemaining != Int.max { needleBulletsRemaining = max(0, needleBulletsRemaining - 1) }
        } else if ship === dart {
            if dartBulletsRemaining != Int.max { dartBulletsRemaining = max(0, dartBulletsRemaining - 1) }
        }

        refreshBulletCounters()
        endGameIfNoBullets()
    }

    // MARK: - Explosions / Wreckage

    private func explodeShip(ship: Ship) {
        guard !ship.node.isHidden else { return }
        enableRandomRespawn = true
        let originalVelocity = ship.velocity

        // FIX #8 — record destroy time so we can delay respawn until bullets expire
        let now = CACurrentMediaTime()
        if ship === needle { needleDestroyTime = now }
        else               { dartDestroyTime   = now }

        let respawnPos = (enableRandomRespawn ? safeRandomPosition(avoiding: ship) : nil)
                         ?? ship.spawnPosition
        let panDelay: TimeInterval = virtualScreenMode != .off ? 2.0 : 1.0
        if ship === needle {
            needleRespawnTarget    = respawnPos
            cameraPanToNeedleAfter = now + panDelay
        } else {
            dartRespawnTarget      = respawnPos
            cameraPanToDartAfter   = now + panDelay
        }

        ship.node.isHidden = true
        ship.velocity = .zero

        // Dim the needle's head dot the instant it explodes so it doesn't pop
        if ship === needle {
            needle.node.childNode(withName: "needleHeadDot")?.alpha = 0
        }

        // In game-over mode each respawn gets a fresh random AI level (0=basic, 1=predictive, 2=expert)
        if gameOver {
            if ship === needle { gameOverNeedleAILevel = Int.random(in: 0...2) }
            else               { gameOverDartAILevel   = Int.random(in: 0...2) }

            // Switch camera to the surviving ship, unless both exploded within 2 seconds
            let survivor = (ship === needle) ? dart : needle
            if now - gameOverLastSwitchTime > 2.0 {
                gameOverFollowedShip = survivor
                gameOverLastSwitchTime = now
            }
        }

        guard let path = ship.node.path else { return }

        // Build wreck pieces from the ship's stroke path
        var pieces = explodePath(path: path, from: ship)

        // PATCH 2 — The needle's head dot (white ball at the tip) flies off as debris
        if ship === needle {
            let ang = ship.node.zRotation
            let offsetY: CGFloat = 21          // matches needleHeadDot y position
            let ballPiece = SKShapeNode(circleOfRadius: 8)
            ballPiece.fillColor = .white; ballPiece.strokeColor = .clear
            ballPiece.position = CGPoint(
                x: ship.node.position.x - offsetY * sin(ang),
                y: ship.node.position.y + offsetY * cos(ang))
            ballPiece.zPosition = ship.node.zPosition
            pieces.append(ballPiece)
        }

        let lifetime: CGFloat = 2.6
        let ownerNode = ship.node
        wreckPieceCount.setObject(NSNumber(value: pieces.count), forKey: ownerNode)
        for piece in pieces {
            piece.name = "wreckPiece"
            piece.alpha = 1.0
            let ang = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 60...140)
            piece.userData = [
                "vx": originalVelocity.dx + speed * cos(ang),
                "vy": originalVelocity.dy + speed * sin(ang),
                "life": lifetime, "maxLife": lifetime
            ]
            wreckOwner.setObject(ownerNode, forKey: piece)
            addChild(piece)
        }
    }

    private func explodePath(path: CGPath, from ship: Ship) -> [SKShapeNode] {
        var pieces: [SKShapeNode] = []
        var lastPoint: CGPoint = .zero
        path.applyWithBlock { elementPtr in
            let e = elementPtr.pointee
            switch e.type {
            case .moveToPoint:
                lastPoint = e.points[0]
            case .addLineToPoint:
                let end = e.points[0]
                let segPath = CGMutablePath()
                segPath.move(to: lastPoint); segPath.addLine(to: end)
                let seg = SKShapeNode(path: segPath)
                seg.strokeColor = .white; seg.lineWidth = 2
                seg.position = ship.node.position; seg.zRotation = ship.node.zRotation
                seg.zPosition = ship.node.zPosition
                pieces.append(seg)
                lastPoint = end
            default: break
            }
        }
        return pieces
    }

    // MARK: - Match control

    private func restoreNewMatchButton() {
        guard let overlay = optionsOverlay,
              let btn = overlay.childNode(withName: "game_new_match") as? SKShapeNode else { return }
        btn.fillColor = .clear; btn.strokeColor = .white
        btn.children.compactMap { $0 as? SKLabelNode }.forEach { $0.fontColor = .white }
    }

    private func startNewMatch() {
        // Preserve the current virtual screen setting before anything is reset
        savedVirtualScreenSelection = virtualScreenSelection
        needleScore = 0; dartScore = 0
        updateScoreDisplays()
        enableRandomRespawn = false
        needle.reset(); dart.reset()
        needleVisibleSince = CACurrentMediaTime()
        dartVisibleSince = CACurrentMediaTime()
        needleDestroyTime = 0; dartDestroyTime = 0
        needleRespawnScheduled = false; dartRespawnScheduled = false
        needleRespawnTarget = .zero; dartRespawnTarget = .zero
        cameraPanToNeedleAfter = 0; cameraPanToDartAfter = 0
        needleKillTime = 0; dartKillTime = 0
        resetBulletCountsFromSelections()
        aiNextThrustToggle = 0; aiNextFireTime = 0; aiThrustOn = false; aiCertainFireCooldown = 0
        wedgeAINextThrustToggle = 0; wedgeAINextFireTime = 0; wedgeAIThrustOn = false; wedgeCertainFireCooldown = 0
        dartSmoothedAcceleration = .zero; needleSmoothedAcceleration = .zero
        enumerateChildNodes(withName: "missile") { n, _ in n.removeFromParent() }
        enumerateChildNodes(withName: "wreckPiece") { n, _ in n.removeFromParent() }
        gameOver = false
        gameOverFollowedShip = nil
        gameOverLastSwitchTime = 0
        gameOverAnimationStartTime = 0
        victorLabelNode?.removeFromParent(); victorLabelNode = nil
        gameOverLabelNode?.removeFromParent(); gameOverLabelNode = nil
        // Restore the player's virtual screen preference that was saved at game-over time
        if virtualScreenSelection != savedVirtualScreenSelection {
            virtualScreenSelection = savedVirtualScreenSelection
            virtualScreenMode = virtualScreenSelection == 0 ? .off : .medium
            applyVirtualScreenMode()
        }
        updateNeedleControlsVisibility()
        updateWedgeControlsVisibility()
        if virtualScreenMode != .off {
            let follow = shipToFollow
            cameraCenter = follow.node.isHidden ? follow.spawnPosition : follow.node.position
            cameraNode.position = cameraCenter
        }
        refreshOptionsUI()
    }

    // MARK: - Score rendering

    private func createDigitNode(_ digit: Int, scale: CGFloat = 1.0) -> SKShapeNode {
        let A = (CGPoint(x: 1, y: 15), CGPoint(x: 9, y: 15))
        let B = (CGPoint(x: 9, y: 15), CGPoint(x: 9, y: 8))
        let C = (CGPoint(x: 9, y: 8),  CGPoint(x: 9, y: 1))
        let D = (CGPoint(x: 1, y: 1),  CGPoint(x: 9, y: 1))
        let E = (CGPoint(x: 1, y: 8),  CGPoint(x: 1, y: 1))
        let F = (CGPoint(x: 1, y: 15), CGPoint(x: 1, y: 8))
        let G = (CGPoint(x: 1, y: 8),  CGPoint(x: 9, y: 8))
        let segments = [A, B, C, D, E, F, G]
        let map: [Int: [Int]] = [
            0:[0,1,2,3,4,5], 1:[1,2], 2:[0,1,6,4,3], 3:[0,1,6,2,3],
            4:[5,6,1,2], 5:[0,5,6,2,3], 6:[0,5,6,2,3,4],
            7:[0,1,2], 8:[0,1,2,3,4,5,6], 9:[0,1,2,3,5,6]
        ]
        let path = CGMutablePath()
        for idx in map[digit] ?? [] {
            let (p1, p2) = segments[idx]
            path.move(to: CGPoint(x: p1.x * scale, y: p1.y * scale))
            path.addLine(to: CGPoint(x: p2.x * scale, y: p2.y * scale))
        }
        let node = SKShapeNode(path: path)
        node.strokeColor = .white; node.lineWidth = 2; node.glowWidth = 3; node.zPosition = 60
        return node
    }

    private func makeScoreNode(score: Int, scale: CGFloat = 1.2, spacing: CGFloat = 12) -> SKNode {
        let container = SKNode()
        let digits = Array(String(score))
        var x: CGFloat = 0
        for ch in digits {
            if let d = Int(String(ch)) {
                let dn = createDigitNode(d, scale: scale)
                dn.position = CGPoint(x: x, y: 0)
                container.addChild(dn)
                x += spacing * scale
            }
        }
        if digits.isEmpty { container.addChild(createDigitNode(0, scale: scale)) }
        return container
    }

    private func updateScoreDisplays() {
        needleScoreNode.removeAllChildren(); dartScoreNode.removeAllChildren()
        let left = makeScoreNode(score: needleScore)
        let right = makeScoreNode(score: dartScore)
        left.position = .zero
        right.position = CGPoint(x: -right.calculateAccumulatedFrame().width, y: 0)
        needleScoreNode.addChild(left); dartScoreNode.addChild(right)
    }

    // MARK: - Bullet counts

    private func bulletsForSelection(_ sel: Int) -> Int? {
        switch sel {
        case 0: return 10
        case 1: return 50
        default: return nil
        }
    }

    private func bulletLabelText(_ selection: Int) -> String {
        if let n = bulletsForSelection(selection) { return "\(n)" }
        return "∞"
    }

    private func resetBulletCountsFromSelections() {
        needleBulletsRemaining = bulletsForSelection(needleBulletLimitSelection) ?? Int.max
        dartBulletsRemaining   = bulletsForSelection(dartBulletLimitSelection)   ?? Int.max
        refreshBulletCounters()
    }

    private func makeVectorInfinityNode(scale: CGFloat) -> SKNode {
        // Lemniscate drawn in a 20×10 native space — much larger than the 8×12 glyph cell
        // so it stays legible at small scales. Crosses at centre (10,5); right lobe clockwise,
        // left lobe counter-clockwise so the path genuinely intersects at the midpoint.
        let cx: CGFloat = 10, cy: CGFloat = 5
        let hw: CGFloat = 8.0, hh: CGFloat = 3.5
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx, y: cy))
        path.addCurve(to: CGPoint(x: cx + hw, y: cy),
                      control1: CGPoint(x: cx + hw * 0.45, y: cy + hh),
                      control2: CGPoint(x: cx + hw,        y: cy + hh))
        path.addCurve(to: CGPoint(x: cx, y: cy),
                      control1: CGPoint(x: cx + hw,        y: cy - hh),
                      control2: CGPoint(x: cx + hw * 0.45, y: cy - hh))
        path.addCurve(to: CGPoint(x: cx - hw, y: cy),
                      control1: CGPoint(x: cx - hw * 0.45, y: cy - hh),
                      control2: CGPoint(x: cx - hw,        y: cy - hh))
        path.addCurve(to: CGPoint(x: cx, y: cy),
                      control1: CGPoint(x: cx - hw,        y: cy + hh),
                      control2: CGPoint(x: cx - hw * 0.45, y: cy + hh))
        let node = SKShapeNode(path: path)
        node.strokeColor = .white; node.fillColor = .clear
        node.lineWidth = 1.0; node.glowWidth = 4.0; node.alpha = 1.0
        node.lineCap = .round
        node.setScale(scale)
        return node
    }

    private func makeInfinityNode() -> SKNode { makeVectorInfinityNode(scale: 0.85) }

    private func refreshBulletCounters() {
        let bulletScale: CGFloat = 0.85
        let bulletSpacing: CGFloat = 3
        func setCounter(_ node: SKNode?, count: Int) {
            guard let node else { return }
            node.removeAllChildren()
            let content: SKNode
            if count == Int.max {
                content = makeVectorInfinityNode(scale: bulletScale)
                // Centre: native space is 20×10, so offset by half at scale
                content.position = CGPoint(x: -10 * bulletScale, y: -5 * bulletScale)
            } else {
                content = makeVectorWordNode("\(count)", scale: bulletScale, spacing: bulletSpacing, bright: true)
                let w = vectorWordWidth("\(count)", scale: bulletScale, spacing: bulletSpacing)
                content.position = CGPoint(x: -w / 2, y: -6 * bulletScale)
            }
            node.addChild(content)
        }
        setCounter(dartBulletCounterNode, count: dartBulletsRemaining)
        #if DEBUG
        setCounter(needleBulletCounterNode, count: needleBulletsRemaining)
        #endif
    }

    private func endGameIfNoBullets() {
        if gameOver { return }
        if needleBulletsRemaining == Int.max || dartBulletsRemaining == Int.max { return }
        if needleBulletsRemaining > 0 || dartBulletsRemaining > 0 { return }

        gameOver = true
        isThrustingDart = false; isThrustingNeedle = false

        // Assign initial random AI levels for the game-over exhibition mode
        gameOverNeedleAILevel = Int.random(in: 0...2)
        gameOverDartAILevel   = Int.random(in: 0...2)

        // Start the camera on whichever ship is alive; default to dart
        gameOverFollowedShip = (!dart.node.isHidden) ? dart : needle
        gameOverLastSwitchTime = 0

        // Give both ships unlimited ammo so they keep firing indefinitely
        needleBulletsRemaining = Int.max
        dartBulletsRemaining   = Int.max
        refreshBulletCounters()

        // Save the player's virtual screen preference; the 3000×3000 switch is deferred to animation start
        savedVirtualScreenSelection = virtualScreenSelection

        let now = CACurrentMediaTime()
        gameOverAnimationStartTime = now + 5.0

        driftNeedleThrustOn = true; driftDartThrustOn = true
        driftNeedleNextToggle = now + Double.random(in: 0.4...1.0)
        driftDartNextToggle   = now + Double.random(in: 0.4...1.0)
        driftNeedleTargetAngle = CGFloat.random(in: 0...(2 * .pi))
        driftDartTargetAngle   = CGFloat.random(in: 0...(2 * .pi))
        driftNeedleNextTurn = now + Double.random(in: 0.8...2.0)
        driftDartNextTurn   = now + Double.random(in: 0.8...2.0)

        showVictorLabel(); showGameOverLabel()
        fireThrustButton?.isHidden  = true
        rightThrustButton?.isHidden = true
        #if DEBUG
        leftFireButtonRef?.isHidden = true
        leftThrustButton?.isHidden  = true
        #endif
    }

    private func vectorWordWidth(_ text: String, scale: CGFloat, spacing: CGFloat) -> CGFloat {
        let n = CGFloat(text.count)
        guard n > 0 else { return 0 }
        return ((n - 1) * (8 + spacing) + 8) * scale
    }

    private func showVictorLabel() {
        victorLabelNode?.removeFromParent()
        let sh = size.height, sw = size.width
        let safeTop = safeAreaTopInset
        let labelY = sh/2 - 30 - safeTop - 42
        let needleCX = -sw/2 + 24
        let dartCX   =  sw/2 - 24
        let container = SKNode(); container.zPosition = 80
        cameraNode.addChild(container); victorLabelNode = container
        // Use the same dim, no-glow vector style as GAME OVER — bright:false keeps strokes
        // thin and unlit, which is what makes the vector font look authentically retro.
        let scale: CGFloat = 1.2; let spacing: CGFloat = 5
        if needleScore == dartScore {
            for (text, cx) in [("TIE", needleCX), ("TIE", dartCX)] {
                let w = vectorWordWidth(text, scale: scale, spacing: spacing)
                let node = makeVectorWordNode(text, scale: scale, spacing: spacing)
                node.position = CGPoint(x: cx - w/2, y: labelY); container.addChild(node)
            }
        } else {
            let w = vectorWordWidth("WINNER", scale: scale, spacing: spacing)
            let word = makeVectorWordNode("WINNER", scale: scale, spacing: spacing)
            let edgeInset: CGFloat = 12
            let startX: CGFloat = needleScore > dartScore
                ? -sw/2 + edgeInset
                : sw/2 - edgeInset - w
            word.position = CGPoint(x: startX, y: labelY); container.addChild(word)
        }
    }

    private func showGameOverLabel() {
        gameOverLabelNode?.removeFromParent()
        let text = "GAME OVER", scale: CGFloat = 2.4, spacing: CGFloat = 5
        let phrase = makeVectorWordNode(text, scale: scale, spacing: spacing)
        phrase.zPosition = 80
        let w = vectorWordWidth(text, scale: scale, spacing: spacing)
        phrase.position = CGPoint(x: -w/2, y: size.height / 6)
        cameraNode.addChild(phrase); gameOverLabelNode = phrase
    }

    private func makeVectorWordNode(_ text: String, scale: CGFloat, spacing: CGFloat, bright: Bool = false) -> SKNode {
        let container = SKNode()
        var cursorX: CGFloat = 0
        let sw: CGFloat = bright ? 1.0 : 0.5
        let segAlpha: CGFloat = bright ? 1.0 : 0.4
        let dotAlpha: CGFloat = bright ? 1.0 : 0.7
        let segGlow: CGFloat  = bright ? 4.0 : 0.0
        let glyphs: [Character: [(CGFloat,CGFloat,CGFloat,CGFloat)]] = [
            "0": [(0,2,0,10),(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2)],
            "1": [(2,10,4,12),(4,12,4,0),(0,0,8,0)],
            "2": [(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,0,0),(0,0,8,0)],
            "3": [(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,6,6),(2,6,6,6),(6,6,8,5),(8,5,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2)],
            "4": [(0,12,0,6),(0,6,8,6),(6,12,6,0)],
            "5": [(8,12,0,12),(0,12,0,7),(0,7,6,7),(6,7,8,5),(8,5,8,2),(8,2,6,0),(6,0,0,0)],
            "6": [(8,10,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,2),(0,2,2,0),(2,0,6,0),(6,0,8,2),(8,2,8,5),(8,5,0,5)],
            "7": [(0,12,8,12),(8,12,4,0)],
            "8": [(2,6,0,8),(0,8,0,10),(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,8),(8,8,6,6),(6,6,2,6),(2,6,0,4),(0,4,0,2),(0,2,2,0),(2,0,6,0),(6,0,8,2),(8,2,8,4),(8,4,6,6)],
            "9": [(8,2,6,0),(6,0,2,0),(2,0,0,2),(0,2,0,5),(0,5,8,5),(8,5,8,10),(8,10,6,12),(6,12,2,12),(2,12,0,10)],
            "A": [(0,0,2,6),(2,6,4,12),(8,0,6,6),(6,6,4,12),(2,6,6,6)],
            "B": [(0,0,0,12),(0,12,5,12),(5,12,7,10),(7,10,7,7),(7,7,5,6),(5,6,0,6),
                  (0,6,5,6),(5,6,7,4),(7,4,7,1),(7,1,5,0),(5,0,0,0)],
            "C": [(7,11,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,2),(0,2,2,0),(2,0,6,0),(6,0,7,1)],
            "D": [(0,0,0,12),(0,12,5,12),(5,12,8,9),(8,9,8,3),(8,3,5,0),(5,0,0,0)],
            "E": [(0,12,0,6),(0,6,0,0),(0,12,8,12),(0,6,6,6),(0,0,8,0)],
            "F": [(0,12,0,6),(0,6,0,0),(0,12,8,12),(0,6,6,6)],
            "G": [(7,11,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,2),(0,2,2,0),(2,0,6,0),
                  (6,0,8,2),(8,2,8,6),(8,6,4,6)],
            "H": [(0,0,0,6),(0,6,0,12),(8,0,8,6),(8,6,8,12),(0,6,8,6)],
            "I": [(2,12,4,12),(4,12,6,12),(4,12,4,0),(2,0,4,0),(4,0,6,0)],
            "J": [(2,12,6,12),(6,12,8,12),(6,12,6,2),(6,2,4,0),(4,0,0,0)],
            "K": [(0,0,0,6),(0,6,0,12),(0,6,8,12),(0,6,8,0)],
            "L": [(0,12,0,0),(0,0,8,0)],
            "M": [(0,0,0,12),(0,12,4,6),(4,6,8,12),(8,12,8,0)],
            "N": [(0,0,0,12),(0,12,8,0),(8,0,8,12)],
            "O": [(2,12,6,12),(6,12,8,10),(8,10,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2),(0,2,0,10),(0,10,2,12)],
            "P": [(0,0,0,12),(0,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,6,6),(6,6,0,6)],
            "Q": [(2,12,6,12),(6,12,8,10),(8,10,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2),
                  (0,2,0,10),(0,10,2,12),(5,3,9,0)],
            "R": [(0,0,0,12),(0,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,6,6),(6,6,0,6),(4,6,8,0)],
            "S": [(7,11,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,7),(0,7,2,6),(2,6,6,6),
                  (6,6,8,4),(8,4,8,1),(8,1,6,0),(6,0,2,0),(2,0,0,2)],
            "T": [(0,12,4,12),(4,12,8,12),(4,12,4,0)],
            "U": [(0,12,0,2),(0,2,2,0),(2,0,6,0),(6,0,8,2),(8,2,8,12)],
            "V": [(0,12,4,0),(4,0,8,12)],
            "W": [(0,12,0,0),(0,0,4,6),(4,6,8,0),(8,0,8,12)],
            "X": [(0,12,4,6),(4,6,8,0),(0,0,4,6),(4,6,8,12)],
            "Y": [(0,12,4,6),(8,12,4,6),(4,6,4,0)],
            "Z": [(0,12,8,12),(8,12,0,0),(0,0,8,0)],
            " ": [],
        ]
        for ch in text.uppercased() {
            let segs = glyphs[ch] ?? []
            let holder = SKNode(); holder.position = CGPoint(x: cursorX, y: 0)
            for (x1,y1,x2,y2) in segs {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2))
                let s = SKShapeNode(path: p)
                s.strokeColor = .white; s.lineWidth = sw; s.glowWidth = segGlow
                s.lineCap = .butt; s.alpha = segAlpha; holder.addChild(s)
            }
            var tally: [String: (CGFloat, CGFloat, Int)] = [:]
            for (x1,y1,x2,y2) in segs {
                for (px,py) in [(x1,y1),(x2,y2)] {
                    let key = "\(px),\(py)"
                    tally[key] = (px, py, (tally[key]?.2 ?? 0) + 1)
                }
            }
            let hs = sw * 0.5
            for (_, entry) in tally where entry.2 >= 2 {
                let rect = CGRect(x: entry.0 - hs, y: entry.1 - hs, width: sw, height: sw)
                let dot = SKShapeNode(rect: rect)
                dot.fillColor = .white; dot.strokeColor = .clear
                dot.glowWidth = sw * 1.5; dot.alpha = dotAlpha; dot.zPosition = 1
                holder.addChild(dot)
            }
            container.addChild(holder); cursorX += (8 + spacing)
        }
        container.setScale(scale)
        return container
    }

    // MARK: - Stars, boundary, camera, arrows

    /// Bright naked-eye stars visible from New York City (lat 41°N).
    /// Tuples: (RA in decimal hours, Dec in degrees, apparent magnitude)
    private static let nycStarData: [(Float, Float, Float)] = [
        // Orion
        (5.92, 7.41, 0.42),  (5.24,-8.20, 0.13),  (5.42, 6.35, 1.64),
        (5.53,-0.30, 2.23),  (5.60,-1.20, 1.70),  (5.68,-1.94, 1.74),
        (5.80,-9.67, 2.06),  (6.07,14.77, 2.77),  (5.59, 9.93, 3.19),
        (5.33,-6.84, 3.39),  (4.83, 6.96, 3.36),  (5.91, 3.56, 3.35),
        (5.20, 2.86, 3.73),  (5.62, 5.60, 3.60),  (5.18,-8.75, 3.79),
        // Taurus
        (4.60,16.51, 0.87),  (5.44,28.61, 1.65),  (3.79,24.11, 2.87),
        (4.33,15.63, 2.97),  (4.01,12.49, 3.00),  (4.70,22.96, 3.41),
        (3.45, 9.73, 3.33),  (4.48,19.18, 3.27),  (4.28,15.87, 3.76),
        (3.53, 0.40, 3.63),  (5.62,21.14, 3.65),  (4.11,22.29, 3.76),
        // Canis Major
        (6.75,-16.72,-1.46), (7.14,-26.39, 1.50), (6.94,-28.97, 2.45),
        (7.40,-29.30, 1.84), (7.03,-27.93, 3.02), (6.38,-17.96, 3.02),
        (6.90,-12.04, 3.95), (7.08,-23.83, 3.02), (6.64,-19.26, 3.83),
        // Canis Minor
        (7.65, 5.22, 0.38),  (7.45, 8.29, 2.89),
        // Gemini
        (7.75,28.03, 1.14),  (7.58,31.88, 1.58),  (7.07,20.57, 3.18),
        (6.63,25.13, 3.36),  (6.38,22.51, 3.00),  (6.73,16.40, 3.26),
        (7.34,21.98, 3.36),  (7.18,30.24, 3.53),  (7.30,16.54, 3.78),
        (6.90,13.18, 3.60),
        // Auriga
        (5.28,46.00, 0.08),  (5.99,44.95, 1.90),  (5.11,41.23, 2.69),
        (5.04,43.82, 3.18),  (4.95,33.17, 3.18),  (5.57,40.10, 3.68),
        (5.19,34.98, 3.71),
        // Perseus
        (3.41,49.86, 1.79),  (3.08,40.96, 2.12),  (3.96,40.01, 2.90),
        (3.72,32.29, 2.91),  (3.17,44.86, 3.03),  (3.54,47.79, 3.77),
        (4.11,47.71, 2.84),  (3.08,53.51, 3.76),  (3.96,35.79, 3.83),
        (2.73,49.23, 3.84),  (4.24,48.40, 3.80),
        // Cassiopeia
        (0.15,59.15, 2.28),  (0.68,56.54, 2.23),  (0.95,60.72, 2.47),
        (1.43,60.24, 2.68),  (1.91,63.67, 2.73),  (2.85,55.90, 2.85),
        (0.45,48.29, 3.38),  (0.28,59.18, 3.46),  (1.04,54.52, 3.67),
        (1.67,72.42, 3.34),
        // Ursa Major
        (11.06,61.75, 1.79), (11.03,56.38, 2.37), (11.90,53.69, 2.44),
        (12.90,55.96, 1.76), (13.40,54.93, 2.04), (13.79,49.31, 1.86),
        (12.26,57.03, 3.31), (10.37,41.50, 3.45), (9.87,59.04, 3.01),
        (9.52,51.68, 3.17),  (8.49,60.71, 3.67),  (9.06,47.16, 3.68),
        (10.28,55.96, 3.71), (11.76,47.78, 3.65), (12.52,41.50, 3.45),
        // Ursa Minor
        (2.53,89.26, 1.97),  (14.85,74.16, 2.08), (15.73,77.79, 3.05),
        (16.29,75.75, 4.25), (17.54,86.59, 4.23), (16.77,82.04, 4.32),
        // Boötes
        (14.26,19.18,-0.05), (13.91,18.40, 2.68), (14.75,27.07, 2.35),
        (15.03,40.39, 3.58), (14.53,30.37, 3.49), (15.25,33.31, 3.46),
        (13.82,15.80, 3.47), (14.35,46.09, 3.49), (13.67,17.46, 3.58),
        (14.06,13.73, 3.65),
        // Leo
        (10.14,11.97, 1.36), (11.82,14.57, 2.14), (10.33,19.84, 2.97),
        (11.24,15.43, 3.34), (11.19,20.52, 3.88), (10.12,16.76, 3.52),
        (9.76,23.77, 3.44),  (9.52,26.01, 4.31),  (10.89,34.21, 3.32),
        (9.68,9.89, 3.61),   (10.12,11.50, 4.08),
        // Virgo
        (13.42,-11.16, 1.04),(13.58,-0.60, 2.75), (12.69,-1.45, 2.83),
        (13.17, 3.40, 2.75), (12.33, 3.40, 3.61), (12.90,-3.40, 3.38),
        (13.57,10.96, 3.61), (14.72, 1.89, 3.87),
        // Hercules
        (17.24,14.39, 2.78), (16.50,21.49, 2.77), (17.39,24.84, 3.15),
        (17.25,36.81, 3.47), (16.97,31.60, 3.16), (17.94,37.25, 3.80),
        (17.00,30.92, 3.87), (16.36,19.15, 3.14), (17.66,46.01, 3.14),
        (16.69,38.92, 3.87), (17.08,33.56, 4.16),
        // Ophiuchus
        (17.17,-15.72, 2.43),(17.59,12.56, 2.08), (16.62,-10.57, 2.56),
        (17.43,-29.87, 2.60),(16.24,-3.69, 2.77), (17.72,-9.77, 3.20),
        (17.98,-9.77, 3.27), (18.01,-8.18, 3.34), (17.36,-24.99, 3.62),
        // Corona Borealis
        (15.58,26.71, 2.22), (15.70,26.30, 3.84), (15.96,29.11, 3.83),
        (16.00,33.86, 4.14), (15.46,29.11, 4.15), (15.55,31.36, 4.62),
        // Lyra
        (18.62,38.78, 0.03), (18.74,39.67, 3.52), (18.83,33.36, 3.24),
        (18.90,36.90, 4.36), (18.91,43.95, 4.60),
        // Cygnus
        (20.69,45.28, 1.25), (20.37,40.26, 2.23), (19.51,27.96, 3.09),
        (19.74,45.13, 2.46), (21.22,30.23, 2.48), (19.94,35.08, 2.87),
        (20.19,40.44, 3.20), (19.61,50.22, 3.21), (21.29,36.64, 3.72),
        (20.77,33.97, 3.79), (21.71,38.75, 3.80), (20.54,47.72, 3.80),
        (20.92,43.93, 3.93),
        // Aquila
        (19.85, 8.87, 0.77), (19.77,10.61, 3.23), (19.10,13.86, 2.72),
        (20.01,-0.82, 3.36), (19.43,-0.82, 3.44), (19.92, 6.40, 3.37),
        (19.09, 3.12, 3.71),
        // Draco
        (17.94,51.49, 2.23), (14.07,64.37, 3.67), (16.40,61.51, 2.79),
        (17.15,65.71, 3.29), (19.80,70.27, 3.65), (11.52,69.33, 3.84),
        (17.51,52.30, 3.07), (18.35,72.73, 3.07), (17.89,56.87, 3.17),
        (16.03,58.57, 3.73), (15.41,58.97, 3.84),
        // Cepheus
        (21.31,62.59, 2.45), (22.83,66.20, 3.21), (23.66,77.63, 3.52),
        (22.49,58.42, 3.35), (21.31,70.56, 3.43), (20.75,77.71, 3.23),
        (22.19,57.04, 3.51),
        // Pegasus
        (22.69,10.83, 2.38), (23.08,28.08, 2.42), (23.07,15.21, 2.49),
        (21.74, 9.87, 2.49), (22.17, 6.20, 3.40), (22.72,30.22, 3.40),
        (22.02,19.80, 3.47), (21.37,19.48, 3.51), (22.83,24.60, 3.60),
        // Andromeda
        (0.14,29.09, 2.07),  (2.12,23.46, 2.01),  (1.91,20.81, 2.64),
        (0.08,29.09, 2.07),  (2.07,42.33, 2.07),  (1.89,20.81, 2.10),
        (2.16,39.24, 3.27),  (2.83,27.26, 3.61),  (0.61,30.86, 4.09),
        (0.43,33.72, 4.01),
        // Aries
        (2.12,23.46, 2.01),  (1.89,23.46, 3.17),  (2.83,27.26, 3.61),
        (2.56,21.34, 4.35),  (1.73,19.29, 3.86),
        // Piscis Austrinus
        (22.96,-29.62, 1.16),(21.79,-32.53, 4.20),(22.52,-32.35, 4.29),
        // Cetus
        (2.72, 3.24, 2.04),  (3.04, 4.09, 2.54),  (1.73,-15.94, 3.47),
        (0.73,-17.99, 2.04), (0.44,-75.20, 3.99), (2.46,-0.33, 3.47),
        (2.33,-2.98, 3.56),  (1.14,-10.18, 3.73), (2.99,-8.90, 4.07),
        // Aquarius
        (22.09,-0.32, 2.91), (22.36,-1.39, 3.27), (21.53,-16.66, 3.57),
        (21.63,-22.41, 3.08),(22.48,-0.02, 3.78), (22.88,-15.82, 3.84),
        (22.83,-13.59, 3.97),
        // Pisces
        (2.04, 2.76, 3.62),  (1.56,15.35, 4.01),  (1.03,21.03, 3.82),
        (1.76, 9.16, 3.70),  (23.67, 5.63, 3.62),
        // Capricornus
        (20.79,-26.92, 3.07),(21.53,-16.66, 3.57),(21.63,-22.41, 3.08),
        (20.30,-12.54, 3.68),(21.10,-25.27, 3.58),
        // Sagittarius (barely visible from NYC)
        (18.29,-29.83, 1.85),(18.40,-34.38, 2.05),(18.92,-26.30, 2.60),
        (19.04,-29.88, 2.98),(18.35,-29.83, 3.11),
        // Scorpius (low but visible from NYC in summer)
        (16.49,-26.43, 1.09),(16.00,-22.62, 2.32),(17.62,-43.00, 1.86),
        (17.71,-39.03, 2.70),(17.83,-37.10, 2.41),
        // Cancer
        (8.74,18.15, 3.52),  (8.97,11.86, 3.94),  (8.28,9.19, 3.94),
        (8.72,21.47, 3.53),
        // Hydra
        (9.46,-8.66, 1.98),  (10.18,-12.35, 3.11),(8.92, 5.95, 3.83),
        (9.66,-1.14, 3.54),  (10.43,-16.84, 3.25),
        // Centaurus (partial, decl > -50 only)
        (14.06,-60.37, -0.29),(14.66,-60.84, 0.61),
        // Crater / Corvus
        (11.40,-22.83, 4.08),(12.17,-22.62, 2.59),(12.08,-24.73, 3.02),
        (12.14,-17.54, 3.11),(12.50,-16.52, 3.88),
    ]

    private func setupStars() {
        for s in starNodes { s.removeFromParent() }
        starNodes.removeAll()
        let vw = virtualWorldWidth, vh = virtualWorldHeight
        let refW: CGFloat = 3000, refH: CGFloat = 3000
        for (ra, dec, mag) in GameScene.nycStarData {
            // PATCH 1 — Map RA 0–24h → x across refW.
            // The dataset spans ≈ −75° … +89° dec; map the full −80°…+90° window
            // (170°) so stars are distributed across the entire 3000×3000 field.
            let x = CGFloat(ra / 24.0) * refW
            let y = CGFloat((CGFloat(dec) + 80.0) / 170.0) * refH
            guard x <= vw && y <= vh else { continue }
            let radius = max(0.8, CGFloat(2.8 - mag * 0.38))
            let alpha  = max(0.40, CGFloat(0.95 - mag * 0.12))
            let star = SKShapeNode(circleOfRadius: radius)
            star.fillColor = .white; star.strokeColor = .clear
            if mag < 2.0 { star.glowWidth = 1.5 }
            star.alpha = alpha; star.zPosition = 2
            star.position = CGPoint(x: x, y: y)
            star.name = "star"
            addChild(star); starNodes.append(star)
        }
    }

    private func setupVirtualBoundary() {
        virtualBoundaryNode?.removeFromParent()
        guard virtualScreenMode != .off else { virtualBoundaryNode = nil; return }
        let vw = virtualWorldWidth, vh = virtualWorldHeight
        let boundary = SKShapeNode(rect: CGRect(x: 0, y: 0, width: vw, height: vh))
        boundary.fillColor = .clear
        boundary.strokeColor = SKColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 0.85)
        boundary.lineWidth = 3; boundary.glowWidth = 10
        boundary.zPosition = 4; boundary.name = "virtualBoundary"
        addChild(boundary); virtualBoundaryNode = boundary
    }

    private func setupDirectionArrows() {
        // Remove any existing pointers
        needleDirectionArrow?.removeFromParent()
        dartDirectionArrow?.removeFromParent()
        sunDirectionArrow?.removeFromParent()
        needleDistanceLabel?.removeFromParent()
        dartDistanceLabel?.removeFromParent()

        // Build the edge arrow for each ship from its profile
        func makeShipArrow(for ship: Ship, distLabel: inout SKLabelNode?) -> SKShapeNode {
            let p = ship.profile
            let ptr = SKShapeNode(path: p.indicatorPath)
            ptr.strokeColor = p.indicatorColor; ptr.fillColor = .clear
            ptr.lineWidth = p.indicatorLineWidth
            ptr.glowWidth = p.indicatorGlowWidth
            ptr.alpha = 0; ptr.zPosition = 90; ptr.name = "dirArrow"
            addChild(ptr)

            if p.indicatorHasHeadDot && p.headDotRadius > 0 {
                // The indicator path is at the same scale as the indicator itself,
                // so we scale the dot radius and position to match (profile uses 0.50 for needle)
                // The path already encodes the scale, so read the dot Y from the indicator scale.
                // For the needle, indicatorPath is at 0.50 × ship, so dot Y = headDotY × 0.50.
                // We derive that scale factor as headDotY-in-indicator / headDotY-in-ship.
                // Since both are baked into the profile, use the ratio of indicatorPath extent.
                // Simplest: hardcode the indicator scale factor in the profile —
                // but we don't store it. Use the existing needle headDotY and known ns=0.50.
                let indicatorScale: CGFloat = 0.50   // matches the ns used in needle's indicatorPath
                let dot = SKShapeNode(circleOfRadius: p.headDotRadius * indicatorScale)
                dot.fillColor = p.indicatorColor; dot.strokeColor = .clear
                dot.position = CGPoint(x: 0, y: p.headDotY * indicatorScale)
                dot.zPosition = 1
                ptr.addChild(dot)
            }

            let lbl = SKLabelNode(text: "")
            lbl.fontName = "AvenirNext-Bold"; lbl.fontSize = 12
            lbl.fontColor = p.indicatorColor
            lbl.horizontalAlignmentMode = .left; lbl.verticalAlignmentMode = .center
            lbl.zPosition = 91; lbl.alpha = 0
            addChild(lbl)
            distLabel = lbl
            return ptr
        }

        needleDirectionArrow = makeShipArrow(for: needle, distLabel: &needleDistanceLabel)
        needleDistanceLabel?.name = "needleDistLabel"
        dartDirectionArrow   = makeShipArrow(for: dart,   distLabel: &dartDistanceLabel)
        dartDistanceLabel?.name   = "dartDistLabel"

        // Sun pointer: starburst symbol (unchanged)
        let sunColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        let sunPtr = SKShapeNode(circleOfRadius: 5)
        sunPtr.fillColor = .clear; sunPtr.strokeColor = sunColor
        sunPtr.lineWidth = 1.5; sunPtr.glowWidth = 3
        sunPtr.zPosition = 90; sunPtr.alpha = 0; sunPtr.name = "dirArrow"
        for spoke in 0..<8 {
            let angle = CGFloat(spoke) * .pi / 4
            let spokePath = CGMutablePath()
            spokePath.move(to: CGPoint(x: cos(angle)*6.5, y: sin(angle)*6.5))
            spokePath.addLine(to: CGPoint(x: cos(angle)*10, y: sin(angle)*10))
            let sn = SKShapeNode(path: spokePath)
            sn.strokeColor = sunColor; sn.lineWidth = 1.5; sn.glowWidth = 1
            sunPtr.addChild(sn)
        }
        let tip = CGMutablePath()
        tip.move(to: CGPoint(x: 0, y: 16))
        tip.addLine(to: CGPoint(x: -5, y: 8))
        tip.addLine(to: CGPoint(x: 5, y: 8))
        tip.closeSubpath()
        let tipNode = SKShapeNode(path: tip)
        tipNode.fillColor = .clear; tipNode.strokeColor = sunColor; tipNode.lineWidth = 1.5
        sunPtr.addChild(tipNode)
        addChild(sunPtr)
        sunDirectionArrow = sunPtr
    }

    /// Called whenever virtualScreenMode changes.
    private func applyVirtualScreenMode() {
        setupStars()
        setupVirtualBoundary()
        lastLaidOutSize = .zero
        layoutForCurrentSize()
        sunNode?.position = CGPoint(x: virtualWorldWidth / 2, y: virtualWorldHeight / 2)
        if virtualScreenMode == .off {
            cameraCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        } else {
            let follow = shipToFollow
            cameraCenter = follow.node.isHidden ? CGPoint(x: virtualWorldWidth/2, y: virtualWorldHeight/2)
                                                : follow.node.position
        }
        cameraNode.position = cameraCenter
    }

    // MARK: - Camera update (called every frame from update())

    private func updateCamera(currentTime: TimeInterval, dt: TimeInterval) {
        guard virtualScreenMode != .off else {
            cameraCenter = CGPoint(x: size.width / 2, y: size.height / 2)
            cameraNode.position = cameraCenter
            updateDirectionArrows()
            return
        }

        #if DEBUG
        let followed: Ship = gameOver ? (gameOverFollowedShip ?? dart)
                           : (!needleAIEnabled && wedgeAIEnabled) ? needle : dart
        #else
        let followed: Ship = gameOver ? (gameOverFollowedShip ?? dart) : dart
        #endif

        let target: CGPoint
        if !followed.node.isHidden {
            target = followed.node.position
        } else {
            let respawnPt  = (followed === needle) ? needleRespawnTarget : dartRespawnTarget
            let panAfter   = (followed === needle) ? cameraPanToNeedleAfter : cameraPanToDartAfter
            target = (currentTime >= panAfter && panAfter > 0) ? respawnPt : cameraCenter
        }

        let t = min(CGFloat(dt) * 5.0, 1.0)
        cameraCenter.x += (target.x - cameraCenter.x) * t
        cameraCenter.y += (target.y - cameraCenter.y) * t
        cameraNode.position = cameraCenter

        updateHUDPositions()
        updateDirectionArrows()
    }

    private func updateHUDPositions() {
        let cx = cameraCenter.x, cy = cameraCenter.y
        let sw = size.width,     sh = size.height
        let topY    = cy + sh/2 - 30 - safeAreaTopInset
        let bottomY = cy - sh/2 + safeAreaBottomInset
        let br: CGFloat = 40
        let padding: CGFloat = 12

        needleScoreNode?.position  = CGPoint(x: cx - sw/2 + 24, y: topY)
        dartScoreNode?.position    = CGPoint(x: cx + sw/2 - 24, y: topY)
        optionsButton?.position    = CGPoint(x: cx, y: topY)
        optionsOverlay?.position   = CGPoint(x: cx, y: cy)

        let fireX = cx + sw/2 - br - 20
        let fireY = bottomY + br + 20
        fireThrustButton?.position  = CGPoint(x: fireX, y: fireY)
        rightThrustButton?.position = CGPoint(x: fireX - (br * 2 + padding), y: fireY)

        let firePos = CGPoint(x: fireX, y: fireY)
        dartBulletCounterNode?.position  = CGPoint(x: fireX, y: fireY + br + 20)
        rightClusterTitle?.position      = CGPoint(x: fireX - (br + padding / 2),
                                                    y: fireY + br + 50)

        #if DEBUG
        let leftFireX = cx - sw/2 + br + 20
        let leftFireY = fireY
        leftFireButtonRef?.position  = CGPoint(x: leftFireX, y: leftFireY)
        leftThrustButton?.position   = CGPoint(x: leftFireX + (br * 2 + padding), y: leftFireY)
        needleBulletCounterNode?.position = CGPoint(x: leftFireX, y: leftFireY + br + 20)
        leftClusterTitle?.position        = CGPoint(x: leftFireX, y: leftFireY + br + 50)
        _ = firePos
        #endif
    }

    @discardableResult
    private func positionPointer(_ ptr: SKShapeNode?,
                                  towardPoint worldPt: CGPoint) -> Bool {
        guard let ptr else { return false }
        guard virtualScreenMode != .off else { ptr.alpha = 0; return false }
        let dx = worldPt.x - cameraCenter.x
        let dy = worldPt.y - cameraCenter.y
        let hw = size.width  / 2 - 22
        let hh = size.height / 2 - 22
        guard abs(dx) > hw || abs(dy) > hh else { ptr.alpha = 0; return false }
        let absDx = abs(dx), absDy = abs(dy)
        let tx = absDx > 0 ? hw / absDx : CGFloat.infinity
        let ty = absDy > 0 ? hh / absDy : CGFloat.infinity
        let t  = min(tx, ty) * 0.87
        ptr.position = CGPoint(x: cameraCenter.x + dx * t, y: cameraCenter.y + dy * t)
        return true
    }

    private func updateDirectionArrows() {
        // PATCH 5a — non-virtual mode: hide everything including distance label
        guard virtualScreenMode != .off else {
            needleDirectionArrow?.alpha = 0
            dartDirectionArrow?.alpha   = 0
            sunDirectionArrow?.alpha    = 0
            needleDistanceLabel?.alpha  = 0
            dartDistanceLabel?.alpha    = 0
            return
        }

        // PATCH 5b — Needle pointer + distance label
        if needle.node.isHidden {
            needleDirectionArrow?.alpha = 0
            needleDistanceLabel?.alpha  = 0
        } else if positionPointer(needleDirectionArrow, towardPoint: needle.node.position) {
            // Arrow rotates to mirror the live ship's heading
            needleDirectionArrow?.zRotation = needle.node.zRotation
            needleDirectionArrow?.alpha = 0.45   // faint — it's a HUD indicator, not a ship
            // Distance readout offset from the arrow, stays upright (label is a sibling node)
            if let arrowPos = needleDirectionArrow?.position {
                let dist = hypot(needle.node.position.x - dart.node.position.x,
                                  needle.node.position.y - dart.node.position.y)
                needleDistanceLabel?.text = "\(Int(dist.rounded()))"
                needleDistanceLabel?.position = CGPoint(x: arrowPos.x + 24, y: arrowPos.y + 16)
                needleDistanceLabel?.alpha = 0.45
            }
        } else {
            // Needle is on-screen — hide the label
            needleDistanceLabel?.alpha = 0
        }

        // --- Dart pointer + distance label (shown when needle is human-controlled) ---
        if dart.node.isHidden {
            dartDirectionArrow?.alpha = 0
            dartDistanceLabel?.alpha  = 0
        } else if positionPointer(dartDirectionArrow, towardPoint: dart.node.position) {
            dartDirectionArrow?.zRotation = dart.node.zRotation
            dartDirectionArrow?.alpha = 0.85
            // Show distance readout only when needle is played manually (not when both are AI)
            if !needleAIEnabled, let arrowPos = dartDirectionArrow?.position {
                let dist = hypot(dart.node.position.x - needle.node.position.x,
                                  dart.node.position.y - needle.node.position.y)
                dartDistanceLabel?.text = "\(Int(dist.rounded()))"
                dartDistanceLabel?.position = CGPoint(x: arrowPos.x + 24, y: arrowPos.y + 16)
                dartDistanceLabel?.alpha = 0.85
            } else {
                dartDistanceLabel?.alpha = 0
            }
        } else {
            dartDistanceLabel?.alpha = 0
        }

        // --- Sun pointer: only when sun is off-screen ---
        let sunPos = sunNode?.position ?? CGPoint(x: virtualWorldWidth/2, y: virtualWorldHeight/2)
        if positionPointer(sunDirectionArrow, towardPoint: sunPos) {
            let dx = sunPos.x - cameraCenter.x
            let dy = sunPos.y - cameraCenter.y
            sunDirectionArrow?.zRotation = atan2(dy, dx) - .pi / 2
            sunDirectionArrow?.alpha = 0.8
        }
    }

    // MARK: - Options Overlay

    private func setupOptionsOverlay() {
        let overlay = SKNode()
        overlay.zPosition = 200
        overlay.name = "optionsOverlay"
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)

        let w: CGFloat = min(380, size.width - 40)
        let h: CGFloat = 492   // +32 to accommodate second tab row

        let bgPath = CGPath(roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h),
                            cornerWidth: 14, cornerHeight: 14, transform: nil)
        let bg = SKShapeNode(path: bgPath)
        bg.fillColor = SKColor(white: 0.08, alpha: 1.0)
        bg.strokeColor = .white; bg.lineWidth = 2; bg.zPosition = 201; bg.name = "options_bg"
        overlay.addChild(bg)

        // Dimmer sits directly behind the panel — same rect, lower zPosition
        if let dimmer = optionsDimmer {
            dimmer.path = bgPath
            dimmer.position = .zero
            dimmer.zPosition = 200
            if dimmer.parent == nil { overlay.addChild(dimmer) }
        }

        func makeLabel(_ text: String, y: CGFloat, name: String) -> SKLabelNode {
            let label = SKLabelNode(text: text)
            label.name = name; label.fontName = "AvenirNext-Bold"; label.fontSize = 16
            label.fontColor = .white; label.position = CGPoint(x: 0, y: y); label.zPosition = 202
            return label
        }

        let tabWidth: CGFloat = (w - 40) / 4
        let tabHeight: CGFloat = 28
        let topPadding: CGFloat = 12
        let tabY = h/2 - topPadding - tabHeight/2

        func makeTab(_ title: String, x: CGFloat, name: String) -> SKShapeNode {
            let tab = SKShapeNode(rectOf: CGSize(width: tabWidth, height: tabHeight), cornerRadius: 6)
            tab.name = name; tab.position = CGPoint(x: x, y: tabY)
            tab.fillColor = SKColor(white: 0.2, alpha: 0.6); tab.strokeColor = .white
            tab.lineWidth = 2; tab.zPosition = 210
            let label = SKLabelNode(text: title)
            label.fontName = "AvenirNext-Bold"; label.fontSize = 14
            label.verticalAlignmentMode = .center; label.horizontalAlignmentMode = .center
            label.position = .zero; label.zPosition = 211; tab.addChild(label)
            overlay.addChild(tab); return tab
        }

        let leftX = -w/2 + 20 + tabWidth/2
        gameTabButton    = makeTab("Gameplay",    x: leftX + 0 * tabWidth, name: "tab_game")
        optionsTabButton = makeTab("Physics",     x: leftX + 1 * tabWidth, name: "tab_environment")
        shipsTabButton   = makeTab("Controls",    x: leftX + 2 * tabWidth, name: "tab_ships")
        aboutTabButton   = makeTab("About",       x: leftX + 3 * tabWidth, name: "tab_about")

        // Row 2 — two expansion tabs centred under the four-tab row
        let tabRow2Y = tabY - tabHeight - 4
        shipSelectionTabButton = makeTab("Ships",    x: -tabWidth / 2, name: "tab_ship_selection")
        networkTabButton       = makeTab("Network",  x:  tabWidth / 2, name: "tab_network")
        // Override y to the second row (makeTab uses tabY by default)
        shipSelectionTabButton?.position.y = tabRow2Y
        networkTabButton?.position.y       = tabRow2Y

        // "Coming Soon" placeholder for Ship Selection tab
        let shipSelContainer = SKNode(); shipSelContainer.zPosition = 202; shipSelContainer.isHidden = true
        let shipSelLabel = SKLabelNode(text: "Coming Soon")
        shipSelLabel.fontName = "AvenirNext-Bold"; shipSelLabel.fontSize = 22
        shipSelLabel.fontColor = SKColor(white: 1.0, alpha: 0.4)
        shipSelLabel.verticalAlignmentMode = .center; shipSelLabel.horizontalAlignmentMode = .center
        shipSelLabel.position = .zero
        shipSelContainer.addChild(shipSelLabel)
        overlay.addChild(shipSelContainer); shipSelectionContainer = shipSelContainer

        // "Coming Soon" placeholder for Network tab
        let netContainer = SKNode(); netContainer.zPosition = 202; netContainer.isHidden = true
        let netLabel = SKLabelNode(text: "Coming Soon")
        netLabel.fontName = "AvenirNext-Bold"; netLabel.fontSize = 22
        netLabel.fontColor = SKColor(white: 1.0, alpha: 0.4)
        netLabel.verticalAlignmentMode = .center; netLabel.horizontalAlignmentMode = .center
        netLabel.position = .zero
        netContainer.addChild(netLabel)
        overlay.addChild(netContainer); networkContainer = netContainer

        // MARK: Environment tab content
        let screenEdgeLabel = makeLabel("Screen Edge:", y: h/2 - 122, name: "env_label_screen_edge")
        overlay.addChild(screenEdgeLabel)

        let bounceBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        bounceBtn.name = "opt_edge_bounce"; bounceBtn.position = CGPoint(x: -60, y: h/2 - 147)
        bounceBtn.strokeColor = .white; bounceBtn.lineWidth = 2; bounceBtn.zPosition = 202; overlay.addChild(bounceBtn)
        bounceBtn.addChild(makeTabInnerLabel("Bounce")); edgeBounceButton = bounceBtn

        let wrapBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        wrapBtn.name = "opt_edge_wrap"; wrapBtn.position = CGPoint(x: 60, y: h/2 - 147)
        wrapBtn.strokeColor = .white; wrapBtn.lineWidth = 2; wrapBtn.zPosition = 202; overlay.addChild(wrapBtn)
        wrapBtn.addChild(makeTabInnerLabel("Wrap")); edgeWrapButton = wrapBtn

        let sunRowLabel = SKLabelNode(text: "Sun at Center:")
        sunRowLabel.name = "env_label_sun"
        sunRowLabel.fontName = "AvenirNext-Bold"; sunRowLabel.fontSize = 16
        sunRowLabel.fontColor = .white; sunRowLabel.verticalAlignmentMode = .center
        sunRowLabel.horizontalAlignmentMode = .right
        sunRowLabel.position = CGPoint(x: -8, y: h/2 - 222); sunRowLabel.zPosition = 202
        overlay.addChild(sunRowLabel)

        let sunBtn = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 6)
        sunBtn.name = "opt_sun_toggle"; sunBtn.position = CGPoint(x: 46, y: h/2 - 222)
        sunBtn.strokeColor = .white; sunBtn.lineWidth = 2; sunBtn.zPosition = 202
        overlay.addChild(sunBtn); sunToggleButton = sunBtn
        sunBtn.addChild(makeTabInnerLabel("ON"))

        let bulletLbl = SKLabelNode(text: "Affects Bullets:")
        bulletLbl.name = "env_label_affects"; bulletLbl.fontName = "AvenirNext-Bold"; bulletLbl.fontSize = 14
        bulletLbl.fontColor = .white; bulletLbl.verticalAlignmentMode = .center
        bulletLbl.horizontalAlignmentMode = .left
        bulletLbl.position = CGPoint(x: -118, y: h/2 - 339); bulletLbl.zPosition = 203
        overlay.addChild(bulletLbl); bulletGravLabel = bulletLbl

        let bulletBtn = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 6)
        bulletBtn.name = "opt_bullet_grav_toggle"; bulletBtn.position = CGPoint(x: 88, y: h/2 - 339)
        bulletBtn.strokeColor = .white; bulletBtn.lineWidth = 2; bulletBtn.zPosition = 202
        overlay.addChild(bulletBtn); bulletGravToggleButton = bulletBtn
        bulletBtn.addChild(makeTabInnerLabel("ON"))

        let gravityHeading = makeLabel("Gravity", y: h/2 - 302, name: "env_label_gravity")
        overlay.addChild(gravityHeading)

        let gravTrackY: CGFloat = h/2 - 392
        let gravTrack = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
        gravTrack.strokeColor = .white; gravTrack.fillColor = .white
        gravTrack.position = CGPoint(x: 0, y: gravTrackY)
        gravTrack.name = "opt_grav_track"; gravTrack.zPosition = 202; overlay.addChild(gravTrack)
        gravitySliderTrack = gravTrack

        let gravTickLabels = ["0×", "2.5×", "5×"]
        for (i, tickLabel) in gravTickLabels.enumerated() {
            let frac = CGFloat(i) / CGFloat(gravTickLabels.count - 1)
            let tx = -sliderTrackHalfWidth + frac * sliderTrackWidth
            let tick = SKShapeNode(rectOf: CGSize(width: 2, height: 8))
            tick.fillColor = .white; tick.strokeColor = .clear
            tick.position = CGPoint(x: tx, y: gravTrackY)
            tick.name = "opt_grav_tick_\(i)"; tick.zPosition = 203; overlay.addChild(tick)
            let tl = SKLabelNode(text: tickLabel)
            tl.fontName = "AvenirNext-Medium"; tl.fontSize = 11; tl.fontColor = .white
            tl.verticalAlignmentMode = .top; tl.horizontalAlignmentMode = .center
            tl.position = CGPoint(x: tx, y: gravTrackY - 7); tl.zPosition = 203
            tl.name = "opt_grav_ticklabel_\(i)"; overlay.addChild(tl)
        }

        let gravKnob = SKShapeNode(circleOfRadius: 8)
        gravKnob.fillColor = .white; gravKnob.strokeColor = .white; gravKnob.lineWidth = 2
        let gravKnobX = -sliderTrackHalfWidth + CGFloat(gravitySliderSelection) * (sliderTrackWidth / CGFloat(gravitySliderSteps))
        gravKnob.position = CGPoint(x: gravKnobX, y: gravTrackY)
        gravKnob.name = "opt_grav_knob"; gravKnob.zPosition = 204; overlay.addChild(gravKnob)
        gravitySliderKnob = gravKnob

        let gravValLbl = SKLabelNode(text: gravityLabelText())
        gravValLbl.fontName = "AvenirNext-Medium"; gravValLbl.fontSize = 12; gravValLbl.fontColor = .white
        gravValLbl.verticalAlignmentMode = .bottom; gravValLbl.horizontalAlignmentMode = .center
        gravValLbl.position = CGPoint(x: 0, y: gravTrackY + 12); gravValLbl.zPosition = 203
        gravValLbl.name = "opt_grav_vallabel"; overlay.addChild(gravValLbl)
        gravityValueLabel = gravValLbl

        let gravityGroupRect = CGRect(x: -130, y: h/2 - 452, width: 260, height: 170)
        let gravityGroup = SKShapeNode(rect: gravityGroupRect, cornerRadius: 8)
        gravityGroup.name = "env_gravity_group"; gravityGroup.strokeColor = SKColor(white: 1.0, alpha: 0.6)
        gravityGroup.lineWidth = 1; gravityGroup.fillColor = .clear; gravityGroup.zPosition = 201.5
        overlay.addChild(gravityGroup)

        // MARK: Ships/Controls tab content
        // AI on/off toggles (moved from Gameplay tab)
        let aiToggleHeaderY: CGFloat = 110
        let needleAIToggleY: CGFloat = 83
        let wedgeAIToggleY:  CGFloat = 53

        let aiToggleHeader = makeLabel("AI On/Off", y: aiToggleHeaderY, name: "ships_label_ai_toggle_title")
        overlay.addChild(aiToggleHeader)

        let needleAIToggleLabel = SKLabelNode(text: "Needle")
        needleAIToggleLabel.fontName = "AvenirNext-Bold"; needleAIToggleLabel.fontSize = 16
        needleAIToggleLabel.fontColor = .white; needleAIToggleLabel.horizontalAlignmentMode = .left
        needleAIToggleLabel.verticalAlignmentMode = .center
        needleAIToggleLabel.position = CGPoint(x: -w/2 + 20, y: needleAIToggleY)
        needleAIToggleLabel.name = "ships_label_ai_toggle_needle"; needleAIToggleLabel.zPosition = 202
        overlay.addChild(needleAIToggleLabel)

        let aiBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aiBtn.name = "game_ai_toggle"; aiBtn.position = CGPoint(x: 0, y: needleAIToggleY)
        aiBtn.strokeColor = .white; aiBtn.lineWidth = 2; aiBtn.zPosition = 202
        overlay.addChild(aiBtn); aiToggleButton = aiBtn

        let wedgeAIToggleLabel = SKLabelNode(text: "Wedge")
        wedgeAIToggleLabel.fontName = "AvenirNext-Bold"; wedgeAIToggleLabel.fontSize = 16
        wedgeAIToggleLabel.fontColor = .white; wedgeAIToggleLabel.horizontalAlignmentMode = .left
        wedgeAIToggleLabel.verticalAlignmentMode = .center
        wedgeAIToggleLabel.position = CGPoint(x: -w/2 + 20, y: wedgeAIToggleY)
        wedgeAIToggleLabel.name = "ships_label_ai_toggle_wedge"; wedgeAIToggleLabel.zPosition = 202
        overlay.addChild(wedgeAIToggleLabel)

        let wedgeAIBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        wedgeAIBtn.name = "game_wedge_ai_toggle"; wedgeAIBtn.position = CGPoint(x: 0, y: wedgeAIToggleY)
        wedgeAIBtn.strokeColor = .white; wedgeAIBtn.lineWidth = 2; wedgeAIBtn.zPosition = 202
        overlay.addChild(wedgeAIBtn); wedgeAIToggleButton = wedgeAIBtn

        let aiSectionHeaderY: CGFloat = -10 // started at 20
        let needleAITrackY:   CGFloat = -35
        let wedgeAITrackY:    CGFloat = -75
        let bulletsSectionY:  CGFloat = -130
        let bulletsY:         CGFloat = -155
        //let bulletLifeY:      CGFloat = -172
        //let bulletButtonsY:   CGFloat = -202

        let aiSectionTitle = makeLabel("AI Intelligence", y: aiSectionHeaderY, name: "ships_label_ai_intelligence_title")
        overlay.addChild(aiSectionTitle)

        func makeAISlider(trackY: CGFloat, namePrefix: String, isNeedle: Bool) {
            let track = SKShapeNode(rectOf: CGSize(width: aiIntelligenceTrackWidth, height: 4), cornerRadius: 2)
            track.strokeColor = .white; track.fillColor = .white; track.alpha = 1.0
            track.position = CGPoint(x: 0, y: trackY)
            track.name = namePrefix + "track"; track.zPosition = 202
            overlay.addChild(track)

            for i in 0...aiIntelligenceSteps {
                let x = -aiIntelligenceTrackHalfWidth + CGFloat(i) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
                let tick = SKShapeNode(circleOfRadius: 3)
                tick.position = CGPoint(x: x, y: trackY)
                tick.fillColor = .white; tick.strokeColor = .white; tick.alpha = 0.9
                tick.name = namePrefix + "tick_\(i)"; tick.zPosition = 203
                overlay.addChild(tick)
            }

            let knob = SKShapeNode(circleOfRadius: 8)
            knob.strokeColor = .white; knob.fillColor = SKColor(white: 0.2, alpha: 0.8)
            knob.lineWidth = 2; knob.position = CGPoint(x: -aiIntelligenceTrackHalfWidth, y: trackY)
            knob.name = namePrefix + "knob"; knob.zPosition = 204
            overlay.addChild(knob)

            if isNeedle { needleAISliderTrack = track; needleAISliderKnob = knob }
            else        { wedgeAISliderTrack  = track; wedgeAISliderKnob  = knob }
        }

        let needleAIRowLabel = SKLabelNode(text: "Needle")
        needleAIRowLabel.fontName = "AvenirNext-Bold"; needleAIRowLabel.fontSize = 16
        needleAIRowLabel.fontColor = .white; needleAIRowLabel.horizontalAlignmentMode = .left
        needleAIRowLabel.verticalAlignmentMode = .center
        needleAIRowLabel.position = CGPoint(x: -w/2 + 20, y: needleAITrackY)
        needleAIRowLabel.name = "ships_label_ai_row_needle"; needleAIRowLabel.zPosition = 202
        overlay.addChild(needleAIRowLabel)

        makeAISlider(trackY: needleAITrackY, namePrefix: "opt_needle_ai_", isNeedle: true)

        let needleAICountLabel = SKLabelNode(text: "basic")
        needleAICountLabel.fontName = "AvenirNext-Bold"; needleAICountLabel.fontSize = 16
        needleAICountLabel.fontColor = .white; needleAICountLabel.horizontalAlignmentMode = .left
        needleAICountLabel.verticalAlignmentMode = .center
        needleAICountLabel.position = CGPoint(x: aiIntelligenceTrackHalfWidth + 20, y: needleAITrackY)
        needleAICountLabel.name = "count_label_needle_ai"; needleAICountLabel.zPosition = 202
        overlay.addChild(needleAICountLabel)

        let wedgeAIRowLabel = SKLabelNode(text: "Wedge")
        wedgeAIRowLabel.fontName = "AvenirNext-Bold"; wedgeAIRowLabel.fontSize = 16
        wedgeAIRowLabel.fontColor = .white; wedgeAIRowLabel.horizontalAlignmentMode = .left
        wedgeAIRowLabel.verticalAlignmentMode = .center
        wedgeAIRowLabel.position = CGPoint(x: -w/2 + 20, y: wedgeAITrackY)
        wedgeAIRowLabel.name = "ships_label_ai_row_wedge"; wedgeAIRowLabel.zPosition = 202
        overlay.addChild(wedgeAIRowLabel)

        makeAISlider(trackY: wedgeAITrackY, namePrefix: "opt_wedge_ai_", isNeedle: false)

        let wedgeAICountLabel = SKLabelNode(text: "basic")
        wedgeAICountLabel.fontName = "AvenirNext-Bold"; wedgeAICountLabel.fontSize = 16
        wedgeAICountLabel.fontColor = .white; wedgeAICountLabel.horizontalAlignmentMode = .left
        wedgeAICountLabel.verticalAlignmentMode = .center
        wedgeAICountLabel.position = CGPoint(x: aiIntelligenceTrackHalfWidth + 20, y: wedgeAITrackY)
        wedgeAICountLabel.name = "count_label_wedge_ai"; wedgeAICountLabel.zPosition = 202
        overlay.addChild(wedgeAICountLabel)

        let bulletsTitle = makeLabel("Number of Bullets", y: bulletsSectionY, name: "ships_label_bullets")
        overlay.addChild(bulletsTitle)

        func makeSlider(trackY: CGFloat, namePrefix: String) {
            let track = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
            track.strokeColor = .white; track.fillColor = .white; track.alpha = 1.0
            track.position = CGPoint(x: 0, y: trackY)
            track.name = namePrefix + "track"; track.zPosition = 202
            overlay.addChild(track)

            for i in 0...bulletSliderSteps {
                let x = -sliderTrackHalfWidth + CGFloat(i) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
                let tick = SKShapeNode(circleOfRadius: 3)
                tick.position = CGPoint(x: x, y: trackY)
                tick.fillColor = .white; tick.strokeColor = .white; tick.alpha = 0.9
                tick.name = namePrefix + "tick_\(i)"; tick.zPosition = 203
                overlay.addChild(tick)
            }

            let knob = SKShapeNode(circleOfRadius: 8)
            knob.strokeColor = .white; knob.fillColor = SKColor(white: 0.2, alpha: 0.8)
            knob.lineWidth = 2; knob.position = CGPoint(x: -sliderTrackHalfWidth, y: trackY)
            knob.name = namePrefix + "knob"; knob.zPosition = 204
            overlay.addChild(knob)

            if namePrefix.contains("needle") { needleBulletSliderTrack = track; needleBulletSliderKnob = knob }
            else                             { dartBulletSliderTrack   = track; dartBulletSliderKnob   = knob }
        }

        makeSlider(trackY: bulletsY,      namePrefix: "opt_bullets_dart_")
        makeSlider(trackY: bulletsY - 40, namePrefix: "opt_bullets_needle_")

        let wedgeSliderLabel = SKLabelNode(text: "Wedge")
        wedgeSliderLabel.fontName = "AvenirNext-Bold"; wedgeSliderLabel.fontSize = 16
        wedgeSliderLabel.fontColor = .white; wedgeSliderLabel.horizontalAlignmentMode = .left
        wedgeSliderLabel.verticalAlignmentMode = .center
        wedgeSliderLabel.position = CGPoint(x: -w/2 + 20, y: bulletsY)
        wedgeSliderLabel.name = "ships_label_row_wedge"; wedgeSliderLabel.zPosition = 202
        overlay.addChild(wedgeSliderLabel)

        let wedgeCountLabel = SKLabelNode(text: "")
        wedgeCountLabel.fontName = "AvenirNext-Bold"; wedgeCountLabel.fontSize = 16
        wedgeCountLabel.fontColor = .white; wedgeCountLabel.horizontalAlignmentMode = .left
        wedgeCountLabel.verticalAlignmentMode = .center
        wedgeCountLabel.position = CGPoint(x: sliderTrackHalfWidth + 20, y: bulletsY)
        wedgeCountLabel.name = "count_label_row_wedge"
        wedgeCountLabel.text = bulletLabelText(dartBulletLimitSelection)
        wedgeCountLabel.zPosition = 202; overlay.addChild(wedgeCountLabel)

        let needleSliderLabel = SKLabelNode(text: "Needle")
        needleSliderLabel.fontName = "AvenirNext-Bold"; needleSliderLabel.fontSize = 16
        needleSliderLabel.fontColor = .white; needleSliderLabel.horizontalAlignmentMode = .left
        needleSliderLabel.verticalAlignmentMode = .center
        needleSliderLabel.position = CGPoint(x: -w/2 + 20, y: bulletsY - 40)
        needleSliderLabel.name = "ships_label_row_needle"; needleSliderLabel.zPosition = 202
        overlay.addChild(needleSliderLabel)

        let needleCountLabel = SKLabelNode(text: "")
        needleCountLabel.fontName = "AvenirNext-Bold"; needleCountLabel.fontSize = 16
        needleCountLabel.fontColor = .white; needleCountLabel.horizontalAlignmentMode = .left
        needleCountLabel.verticalAlignmentMode = .center
        needleCountLabel.position = CGPoint(x: sliderTrackHalfWidth + 20, y: bulletsY - 40)
        needleCountLabel.name = "count_label_row_needle"
        needleCountLabel.text = bulletLabelText(needleBulletLimitSelection)
        needleCountLabel.zPosition = 202; overlay.addChild(needleCountLabel)

        // MARK: Gameplay tab content
        let newMatchBtn = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 8)
        newMatchBtn.name = "game_new_match"; newMatchBtn.position = CGPoint(x: 0, y: h/2 - 162) // more negative means farther down
        newMatchBtn.fillColor = .clear; newMatchBtn.strokeColor = .white; newMatchBtn.lineWidth = 2
        newMatchBtn.zPosition = 202; overlay.addChild(newMatchBtn)
        newMatchBtn.addChild(makeTabInnerLabel("New Match", fontSize: 16))

        let aimLabel = makeLabel("Aim Persists:", y: h/2 - 235, name: "game_label_aim_persist")
        overlay.addChild(aimLabel)

        let aimBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aimBtn.name = "game_aim_persist_toggle"; aimBtn.position = CGPoint(x: 0, y: h/2 - 260)
        aimBtn.strokeColor = .white; aimBtn.lineWidth = 2; aimBtn.zPosition = 202
        overlay.addChild(aimBtn); aimPersistToggleButton = aimBtn

        let vsLabel = makeLabel("Virtual Screen:", y: h/2 - 320, name: "game_label_virtual_screen")
        overlay.addChild(vsLabel)

        let vsTrackY: CGFloat = h/2 - 342
        let vsTrack = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
        vsTrack.strokeColor = .white; vsTrack.fillColor = .white; vsTrack.alpha = 1.0
        vsTrack.position = CGPoint(x: 0, y: vsTrackY)
        vsTrack.name = "game_vs_track"; vsTrack.zPosition = 202; overlay.addChild(vsTrack)
        virtualScreenSliderTrack = vsTrack

        let vsLabels = ["off", "3000"]
        for i in 0...virtualScreenSteps {
            let x = -sliderTrackHalfWidth + CGFloat(i) * (sliderTrackWidth / CGFloat(virtualScreenSteps))
            let tick = SKShapeNode(circleOfRadius: 3)
            tick.position = CGPoint(x: x, y: vsTrackY)
            tick.fillColor = .white; tick.strokeColor = .white
            tick.name = "game_vs_tick_\(i)"; tick.zPosition = 203; overlay.addChild(tick)
            let tl = SKLabelNode(text: vsLabels[i])
            tl.fontName = "AvenirNext-Bold"; tl.fontSize = 11; tl.fontColor = .white
            tl.verticalAlignmentMode = .top; tl.horizontalAlignmentMode = .center
            tl.position = CGPoint(x: x, y: vsTrackY - 8); tl.zPosition = 203
            tl.name = "game_vs_ticklabel_\(i)"; overlay.addChild(tl)
        }
        let vsKnob = SKShapeNode(circleOfRadius: 8)
        vsKnob.fillColor = .white; vsKnob.strokeColor = .white; vsKnob.lineWidth = 2
        vsKnob.position = CGPoint(x: -sliderTrackHalfWidth, y: vsTrackY)
        vsKnob.name = "game_vs_knob"; vsKnob.zPosition = 204; overlay.addChild(vsKnob)
        virtualScreenSliderKnob = vsKnob

        // MARK: About tab content
        let about = SKNode(); about.zPosition = 202; about.isHidden = true

        let title = SKLabelNode(text: "SpaceWar 2062")
        title.fontName = "AvenirNext-Bold"; title.fontSize = 22; title.fontColor = .white
        title.position = CGPoint(x: 0, y: 40); about.addChild(title)

        let copy = SKLabelNode(text: "© 2026 Michael Stern")
        copy.fontName = "AvenirNext-Medium"; copy.fontSize = 12; copy.fontColor = .white
        copy.position = CGPoint(x: 0, y: -h/2 + 20); about.addChild(copy)

        overlay.addChild(about); aboutContainer = about
        optionsOverlay = overlay; addChild(overlay)

        refreshOptionsUI()
        setOptionsTab(.environment)
    }

    private func makeTabInnerLabel(_ text: String, fontSize: CGFloat = 14) -> SKLabelNode {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "AvenirNext-Bold"; lbl.fontSize = fontSize; lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center; lbl.horizontalAlignmentMode = .center
        lbl.position = .zero; lbl.zPosition = 203
        return lbl
    }

    private func sliderIndexForOverlayX(_ x: CGFloat) -> Int {
        let step = sliderTrackWidth / CGFloat(bulletSliderSteps)
        let idx = Int(round((x + sliderTrackHalfWidth) / step))
        return max(0, min(bulletSliderSteps, idx))
    }

    private func gravityLabelText() -> String {
        if gravitySliderSelection == 0 { return "Off" }
        let val = gravityMultiplier / 8.0
        return String(format: "%.1f×", val)
    }

    private func bulletLifeLabelText() -> String {
        return String(format: "%.1f s", bulletLifeSeconds)
    }

    private func aiSliderIndexForOverlayX(_ x: CGFloat) -> Int {
        let step = aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps)
        let idx = Int(round((x + aiIntelligenceTrackHalfWidth) / step))
        return max(0, min(aiIntelligenceSteps, idx))
    }

    private func touchIsOnSlider(track: SKShapeNode?, locInOverlay: CGPoint) -> Bool {
        guard let track else { return false }
        let ty = track.position.y
        let inX = locInOverlay.x >= (-sliderTrackHalfWidth - 20) && locInOverlay.x <= (sliderTrackHalfWidth + 20)
        let inY = abs(locInOverlay.y - ty) <= 20
        return inX && inY
    }

    private func refreshOptionsUI() {
        let selFill = SKColor.white
        let offFill = SKColor.clear
        let selText = SKColor.black
        let offText = SKColor.white

        func styleBtn(_ b: SKShapeNode?, selected: Bool) {
            guard let b else { return }
            b.fillColor   = selected ? selFill : offFill
            b.strokeColor = SKColor.white
            b.lineWidth   = 2
            b.glowWidth   = 0
            if let lbl = b.children.compactMap({ $0 as? SKLabelNode }).first {
                lbl.fontColor = selected ? selText : offText
            }
        }

        let gamePrefixes  = ["game_"]
        // AI toggle buttons live in Controls tab despite having game_ prefix
        let gameExclusions = ["game_ai_toggle", "game_wedge_ai_toggle"]
        let envPrefixes   = ["opt_edge_", "opt_sun_toggle", "opt_bullet_grav_toggle",
                             "opt_grav_", "env_label_", "env_gravity_group"]
        let shipsPrefixes = ["ships_label_",
                             "opt_bullets_", "count_label_", "opt_needle_ai_", "opt_wedge_ai_",
                             "game_ai_toggle", "game_wedge_ai_toggle"]

        optionsOverlay?.children.forEach { node in
            if node.name == "options_bg" { return }
            if node === gameTabButton || node === optionsTabButton ||
               node === shipsTabButton || node === aboutTabButton ||
               node === shipSelectionTabButton || node === networkTabButton ||
               node === aboutContainer || node === shipSelectionContainer || node === networkContainer { return }
            let name = node.name ?? ""
            switch currentOptionsTab {
            case .environment:   node.isHidden = !envPrefixes.contains(where: { name.hasPrefix($0) })
            case .ships:         node.isHidden = !shipsPrefixes.contains(where: { name.hasPrefix($0) })
            case .game:          node.isHidden = gameExclusions.contains(name) || !gamePrefixes.contains(where: { name.hasPrefix($0) })
            case .about, .shipSelection, .network: node.isHidden = true
            }
        }

        aboutContainer?.isHidden          = (currentOptionsTab != .about)
        shipSelectionContainer?.isHidden   = (currentOptionsTab != .shipSelection)
        networkContainer?.isHidden         = (currentOptionsTab != .network)

        func setTab(_ tabNode: SKShapeNode?, selected: Bool) {
            guard let tabNode, let lbl = tabNode.children.compactMap({ $0 as? SKLabelNode }).first else { return }
            tabNode.fillColor   = selected ? selFill : offFill
            tabNode.strokeColor = SKColor.white
            tabNode.lineWidth   = 2
            tabNode.glowWidth   = 0
            lbl.fontColor       = selected ? selText : offText
        }
        setTab(gameTabButton,          selected: currentOptionsTab == .game)
        setTab(optionsTabButton,       selected: currentOptionsTab == .environment)
        setTab(shipsTabButton,         selected: currentOptionsTab == .ships)
        setTab(aboutTabButton,         selected: currentOptionsTab == .about)
        setTab(shipSelectionTabButton, selected: currentOptionsTab == .shipSelection)
        setTab(networkTabButton,       selected: currentOptionsTab == .network)

        styleBtn(edgeBounceButton,   selected: edgeBehavior == .bounce)
        styleBtn(edgeWrapButton,     selected: edgeBehavior == .wrap)

        aiToggleButton?.fillColor      = needleAIEnabled ? selFill : offFill
        wedgeAIToggleButton?.fillColor = wedgeAIEnabled  ? selFill : offFill
        aimPersistToggleButton?.fillColor = aimPersistsAfterLift ? selFill : offFill

        if let b = sunToggleButton {
            styleBtn(b, selected: sunEnabled)
            if let lbl = b.children.compactMap({ $0 as? SKLabelNode }).first {
                lbl.text = sunEnabled ? "ON" : "OFF"
            }
        }
        if let b = bulletGravToggleButton {
            styleBtn(b, selected: sunAffectsBullets)
            if let lbl = b.children.compactMap({ $0 as? SKLabelNode }).first {
                lbl.text = sunAffectsBullets ? "ON" : "OFF"
            }
        }

        func setEnabled(_ node: SKNode?, enabled: Bool) { node?.alpha = enabled ? 1.0 : 0.5 }
        setEnabled(bulletGravToggleButton, enabled: sunEnabled)
        bulletGravLabel?.alpha = sunEnabled ? 1.0 : 0.5

        let gravAlpha: CGFloat = sunEnabled ? 1.0 : 0.5
        gravitySliderTrack?.alpha = gravAlpha
        gravitySliderKnob?.alpha  = gravAlpha
        gravityValueLabel?.alpha  = gravAlpha
        optionsOverlay?.enumerateChildNodes(withName: "opt_grav_tick_*")    { $0.alpha = gravAlpha; _ = $1 }
        optionsOverlay?.enumerateChildNodes(withName: "opt_grav_ticklabel_*") { $0.alpha = gravAlpha; _ = $1 }
        if let knob = gravitySliderKnob, let track = gravitySliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(gravitySliderSelection) * (sliderTrackWidth / CGFloat(gravitySliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        gravityValueLabel?.text = gravityLabelText()

        if let knob = virtualScreenSliderKnob, let track = virtualScreenSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(virtualScreenSelection) * (sliderTrackWidth / CGFloat(virtualScreenSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let knob = needleBulletSliderKnob, let track = needleBulletSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(needleBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let knob = dartBulletSliderKnob, let track = dartBulletSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(dartBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }

        if let label = optionsOverlay?.childNode(withName: "count_label_row_wedge") as? SKLabelNode {
            label.text = bulletLabelText(dartBulletLimitSelection)
        }
        if let label = optionsOverlay?.childNode(withName: "count_label_row_needle") as? SKLabelNode {
            label.text = bulletLabelText(needleBulletLimitSelection)
        }

        let aiLevelNames = ["basic", "smart", "expert"]

        let needleAIOn = needleAIEnabled
        needleAISliderTrack?.alpha = needleAIOn ? 1.0 : 0.4
        if let knob = needleAISliderKnob, let track = needleAISliderTrack {
            knob.alpha = needleAIOn ? 1.0 : 0.4
            let x = -aiIntelligenceTrackHalfWidth + CGFloat(needleAIIntelligence) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let label = optionsOverlay?.childNode(withName: "count_label_needle_ai") as? SKLabelNode {
            label.alpha = needleAIOn ? 1.0 : 0.4
            label.text = aiLevelNames[min(needleAIIntelligence, aiLevelNames.count - 1)]
        }
        optionsOverlay?.enumerateChildNodes(withName: "opt_needle_ai_tick_*") { node, _ in
            node.alpha = needleAIOn ? 0.9 : 0.4
        }
        if let label = optionsOverlay?.childNode(withName: "ships_label_ai_row_needle") {
            label.alpha = needleAIOn ? 1.0 : 0.4
        }

        let wedgeAIOn = wedgeAIEnabled
        wedgeAISliderTrack?.alpha = wedgeAIOn ? 1.0 : 0.4
        if let knob = wedgeAISliderKnob, let track = wedgeAISliderTrack {
            knob.alpha = wedgeAIOn ? 1.0 : 0.4
            let x = -aiIntelligenceTrackHalfWidth + CGFloat(wedgeAIIntelligence) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let label = optionsOverlay?.childNode(withName: "count_label_wedge_ai") as? SKLabelNode {
            label.alpha = wedgeAIOn ? 1.0 : 0.4
            label.text = aiLevelNames[min(wedgeAIIntelligence, aiLevelNames.count - 1)]
        }
        optionsOverlay?.enumerateChildNodes(withName: "opt_wedge_ai_tick_*") { node, _ in
            node.alpha = wedgeAIOn ? 0.9 : 0.4
        }
        if let label = optionsOverlay?.childNode(withName: "ships_label_ai_row_wedge") {
            label.alpha = wedgeAIOn ? 1.0 : 0.4
        }
    }

    private func setOptionsTab(_ tab: OptionsTab) {
        currentOptionsTab = tab
        refreshOptionsUI()
    }

    // MARK: - Sun

    private func applySunState() {
        if sunEnabled {
            if sunNode == nil {
                let r: CGFloat = 32
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -r, y: 0)); path.addLine(to: CGPoint(x: r, y: 0))
                path.move(to: CGPoint(x: 0, y: -r)); path.addLine(to: CGPoint(x: 0, y: r))
                let d = r / sqrt(2)
                path.move(to: CGPoint(x: -d, y: -d)); path.addLine(to: CGPoint(x: d, y: d))
                path.move(to: CGPoint(x: -d, y: d));  path.addLine(to: CGPoint(x: d, y: -d))
                let star = SKShapeNode(path: path)
                star.strokeColor = .yellow; star.fillColor = .clear
                star.lineWidth = 1; star.glowWidth = 0
                star.position = CGPoint(x: size.width/2, y: size.height/2)
                star.zPosition = 5; star.name = "sun"
                let twinkle = SKAction.repeatForever(.sequence([
                    .group([.scale(to: 1.15, duration: 0.25), .fadeAlpha(to: 0.9, duration: 0.25)]),
                    .group([.scale(to: 1.0,  duration: 0.3),  .fadeAlpha(to: 1.0, duration: 0.3)])
                ]))
                star.run(twinkle); addChild(star); sunNode = star
            }
        } else {
            sunNode?.removeFromParent(); sunNode = nil
        }
    }

    private func safeRandomPosition(avoiding ship: Ship) -> CGPoint? {
        let inset: CGFloat = 20
        let vw = virtualWorldWidth, vh = virtualWorldHeight
        let otherShip: Ship = (ship === needle) ? dart! : needle!
        // Minimum safe separation from the opponent ship (pixels)
        let minShipSeparation: CGFloat = 200
        for _ in 0..<100 {
            let p = CGPoint(x: CGFloat.random(in: inset...(vw-inset)),
                            y: CGFloat.random(in: inset...(vh-inset)))
            // Reject if too close to the other ship
            if !otherShip.node.isHidden {
                let dx = otherShip.node.position.x - p.x
                let dy = otherShip.node.position.y - p.y
                if dx*dx + dy*dy < minShipSeparation * minShipSeparation { continue }
            }
            var tooClose = false
            enumerateChildNodes(withName: "missile") { node, stop in
                let dx = node.position.x - p.x, dy = node.position.y - p.y
                if dx*dx + dy*dy < 40*40 { tooClose = true; stop.pointee = true }
            }
            if tooClose { continue }
            if let sun = sunNode {
                let dx = sun.position.x - p.x, dy = sun.position.y - p.y
                let minR = sunCollisionRadius + 80
                if dx*dx + dy*dy < minR*minR { continue }
            }
            return p
        }
        return nil
    }

    private func respawnShip(_ ship: Ship) {
        let precomputed = (ship === needle) ? needleRespawnTarget : dartRespawnTarget
        let pos: CGPoint
        if precomputed != .zero { pos = precomputed }
        else if enableRandomRespawn, let p = safeRandomPosition(avoiding: ship) { pos = p }
        else { pos = ship.spawnPosition }
        ship.node.position = pos; ship.node.zRotation = 0
        ship.velocity = .zero; ship.node.isHidden = false
        if ship === needle { needle.node.childNode(withName: "needleHeadDot")?.alpha = 1 }
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime

        updateCamera(currentTime: currentTime, dt: dt)

        if optionsVisible {
            needleTargetIndicator.alpha = 0
            dartTargetIndicator.alpha = 0
            lastUpdateTime = currentTime
            return
        }

        for entity in entities { entity.update(deltaTime: dt) }

        // FIX #8 — check for deferred respawns
        let respawnBulletLife = bulletLifeSeconds
        if needleRespawnScheduled && needle.node.isHidden {
            if currentTime - needleDestroyTime >= respawnBulletLife {
                needleRespawnScheduled = false
                respawnShip(needle)
                needleVisibleSince = currentTime
            }
        }
        if dartRespawnScheduled && dart.node.isHidden {
            if currentTime - dartDestroyTime >= respawnBulletLife {
                dartRespawnScheduled = false
                respawnShip(dart)
                dartVisibleSince = currentTime
            }
        }

        if !gameOver || currentTime >= gameOverAnimationStartTime {

        if gameOver && virtualScreenMode != .medium {
            // Switch to 3000×3000 now that the 5-second grace period is up
            virtualScreenSelection = 1
            virtualScreenMode = .medium
            applyVirtualScreenMode()
        }

        if gameOver {
            // In game-over mode, override AI settings from the randomly-assigned levels
            // so ships use the real AI path below rather than the old random drift steering.
            needleAIEnabled       = true
            needleAIIntelligence  = gameOverNeedleAILevel
            wedgeAIEnabled        = true
            wedgeAIIntelligence   = gameOverDartAILevel
            // Restore infinite ammo each frame in case it was changed by respawn logic
            if needleBulletsRemaining < Int.max / 2 { needleBulletsRemaining = Int.max }
            if dartBulletsRemaining   < Int.max / 2 { dartBulletsRemaining   = Int.max }
        }

        do {
            // Normal play (and game-over exhibition — same AI path, different settings)
            var needleAimTarget: CGPoint? = nil
            var dartAimTarget: CGPoint? = nil
            var needleEvasion = false
            var wedgeEvasion = false
            var needleCollisionBrake = false
            var wedgeCollisionBrake = false
            let needleHuntingUnarmed = needleAIEnabled && needleAIIntelligence >= 2
                && !needle.node.isHidden && !dart.node.isHidden
                && dartBulletsRemaining == 0
            let wedgeHuntingUnarmed = wedgeAIEnabled && wedgeAIIntelligence >= 2
                && !dart.node.isHidden && !needle.node.isHidden
                && needleBulletsRemaining == 0

            // MARK: Needle rotation / AI
            if !needle.node.isHidden {
                if needleAIEnabled {
                    if let sun = sunNode {
                        let dxs = sun.position.x - needle.node.position.x
                        let dys = sun.position.y - needle.node.position.y
                        let dist2 = dxs*dxs + dys*dys
                        let vx = needle.velocity.dx, vy = needle.velocity.dy
                        let vmag = sqrt(vx*vx + vy*vy)

                        let onCollisionCourse: Bool = {
                            if vmag > 1 {
                                let invR = 1.0 / sqrt(dist2)
                                let dot = (vx * dxs * invR + vy * dys * invR)
                                let cross = abs(dxs*vy - dys*vx)
                                let b = cross / vmag
                                return dot > 0 && b < (sunCollisionRadius + 60)
                            }
                            return false
                        }()

                        let avoidRadius: CGFloat = (needleAIIntelligence >= 2) ? 180 : 140
                        let tooClose = dist2 < avoidRadius * avoidRadius
                        let shouldAvoidSun = (needleAIIntelligence >= 1)
                            ? (shipWillHitSun(needle, in: 3.5) || tooClose)
                            : (tooClose || onCollisionCourse)

                        if needleAIIntelligence >= 2 && !shouldAvoidSun {
                            needleCollisionBrake = collisionDecision(ship: needle, opponent: dart,
                                                                      killTime: dartKillTime, currentTime: currentTime)
                        }

                        if shouldAvoidSun {
                            let awayPoint = CGPoint(x: needle.node.position.x - dxs, y: needle.node.position.y - dys)
                            rotateShip(needle, toward: awayPoint, dt: dt)
                            needleAimTarget = awayPoint
                            needleEvasion = true
                        } else if needleHuntingUnarmed {
                            let aimPt = huntAimPoint(shooter: needle, target: dart)
                            rotateShip(needle, toward: aimPt, dt: dt)
                            needleAimTarget = aimPt
                        } else if needleCollisionBrake {
                            let avoidPt = collisionAvoidancePoint(for: needle, opponent: dart)
                            rotateShip(needle, toward: avoidPt, dt: dt)
                            needleAimTarget = avoidPt
                        } else {
                            if needleAIIntelligence >= 2 {
                                let aimTarget: CGPoint
                                if bulletHitUnavoidable(for: needle) {
                                    aimTarget = level3AimPoint(shooter: needle, target: dart)
                                } else {
                                    let (inDanger, awayPoint) = edgeAwareBulletDanger(for: needle, opponent: dart)
                                    if inDanger { needleEvasion = true }
                                    aimTarget = inDanger ? awayPoint
                                                         : strategicPositionTarget(for: needle, opponent: dart, pursueBehind: dartBulletsRemaining > 0)
                                }
                                rotateShip(needle, toward: aimTarget, dt: dt)
                                needleAimTarget = aimTarget
                            } else {
                                var nearestMissilePos = CGPoint.zero
                                var nearestMissileD2 = CGFloat.greatestFiniteMagnitude
                                enumerateChildNodes(withName: "missile") { node, _ in
                                    let dxm = node.position.x - self.needle.node.position.x
                                    let dym = node.position.y - self.needle.node.position.y
                                    let d2m = dxm*dxm + dym*dym
                                    if d2m < nearestMissileD2 { nearestMissileD2 = d2m; nearestMissilePos = node.position }
                                }
                                let avoidBulletR: CGFloat = 120
                                if nearestMissileD2 < avoidBulletR*avoidBulletR {
                                    let awayPoint = CGPoint(
                                        x: needle.node.position.x - (nearestMissilePos.x - needle.node.position.x),
                                        y: needle.node.position.y - (nearestMissilePos.y - needle.node.position.y))
                                    rotateShip(needle, toward: awayPoint, dt: dt)
                                    needleAimTarget = awayPoint
                                } else if !dart.node.isHidden {
                                    let dxw = dart.node.position.x - needle.node.position.x
                                    let dyw = dart.node.position.y - needle.node.position.y
                                    let d2w = dxw*dxw + dyw*dyw
                                    if d2w < 90*90 {
                                        let awayPoint = CGPoint(x: needle.node.position.x - dxw, y: needle.node.position.y - dyw)
                                        rotateShip(needle, toward: awayPoint, dt: dt)
                                        needleAimTarget = awayPoint
                                    } else {
                                        let t = predictedAimPoint(shooter: needle, target: dart, intelligence: needleAIIntelligence)
                                        rotateShip(needle, toward: t, dt: dt)
                                        needleAimTarget = t
                                    }
                                } else {
                                    let t = predictedAimPoint(shooter: needle, target: dart, intelligence: needleAIIntelligence)
                                    rotateShip(needle, toward: t, dt: dt)
                                    needleAimTarget = t
                                }
                            }
                        }
                    } else {
                        // No sun — needle
                        if needleAIIntelligence >= 2 {
                            needleCollisionBrake = collisionDecision(ship: needle, opponent: dart,
                                                                      killTime: dartKillTime, currentTime: currentTime)
                        }

                        if needleHuntingUnarmed {
                            let aimPt = huntAimPoint(shooter: needle, target: dart)
                            rotateShip(needle, toward: aimPt, dt: dt)
                            needleAimTarget = aimPt
                        } else if needleCollisionBrake {
                            let avoidPt = collisionAvoidancePoint(for: needle, opponent: dart)
                            rotateShip(needle, toward: avoidPt, dt: dt)
                            needleAimTarget = avoidPt
                        } else if needleAIIntelligence >= 2 {
                            let aimTarget: CGPoint
                            if bulletHitUnavoidable(for: needle) {
                                aimTarget = level3AimPoint(shooter: needle, target: dart)
                            } else {
                                let (inDanger, awayPoint) = edgeAwareBulletDanger(for: needle, opponent: dart)
                                if inDanger { needleEvasion = true }
                                aimTarget = inDanger ? awayPoint
                                                     : strategicPositionTarget(for: needle, opponent: dart, pursueBehind: dartBulletsRemaining > 0)
                            }
                            rotateShip(needle, toward: aimTarget, dt: dt)
                            needleAimTarget = aimTarget
                        } else {
                            var nearestMissilePos = CGPoint.zero
                            var nearestMissileD2 = CGFloat.greatestFiniteMagnitude
                            enumerateChildNodes(withName: "missile") { node, _ in
                                let dxm = node.position.x - self.needle.node.position.x
                                let dym = node.position.y - self.needle.node.position.y
                                let d2m = dxm*dxm + dym*dym
                                if d2m < nearestMissileD2 { nearestMissileD2 = d2m; nearestMissilePos = node.position }
                            }
                            let avoidBulletR: CGFloat = 120
                            if nearestMissileD2 < avoidBulletR*avoidBulletR {
                                let awayPoint = CGPoint(
                                    x: needle.node.position.x - (nearestMissilePos.x - needle.node.position.x),
                                    y: needle.node.position.y - (nearestMissilePos.y - needle.node.position.y))
                                rotateShip(needle, toward: awayPoint, dt: dt)
                                needleAimTarget = awayPoint
                            } else {
                                let t = predictedAimPoint(shooter: needle, target: dart, intelligence: needleAIIntelligence)
                                rotateShip(needle, toward: t, dt: dt)
                                needleAimTarget = t
                            }
                        }
                    }
                } else if let p = aimPoint {
                    rotateShip(needle, toward: p, dt: dt)
                    needleAimTarget = p
                }
            }

            // MARK: Wedge/Dart rotation / AI
            if !dart.node.isHidden {
                if wedgeAIEnabled {
                    if wedgeAIIntelligence == 3 {
                        var enemyBullets: [(pos: CGPoint, vel: CGVector)] = []
                        enumerateChildNodes(withName: "missile") { node, _ in
                            guard let owner = self.missileOwner.object(forKey: node),
                                  owner === self.needle.node,
                                  let data = node.userData,
                                  let vx = data["vx"] as? CGFloat,
                                  let vy = data["vy"] as? CGFloat else { return }
                            enemyBullets.append((pos: node.position, vel: CGVector(dx: vx, dy: vy)))
                        }

                        let sunPos = sunNode?.position ?? CGPoint(x: 1500, y: 1500)
                        let edgeMode: NeuralAIController.EdgeBehavior =
                            (edgeBehavior == .wrap) ? .wrap : .bounce
                        let action = neuralAI.predict(
                            ship: dart.node,
                            shipVel: dart.velocity,
                            shipAngle: dart.node.zRotation,
                            opponent: needle.node,
                            opponentVel: needle.velocity,
                            opponentAngle: needle.node.zRotation,
                            enemyBullets: enemyBullets,
                            sunPosition: sunPos,
                            edgeBehavior: edgeMode,
                            gravityMultiplier: gravityMultiplier,
                            bulletLife: bulletLifeSeconds,
                            opponentBulletsRemaining: needleBulletsRemaining
                        )

                        if action.rotate != 0 {
                            dart.node.zRotation += CGFloat(action.rotate) * dart.profile.turnSpeed * CGFloat(dt)
                        }
                        isThrustingDart = action.thrust
                        if action.fire && currentTime >= wedgeAINextFireTime {
                            fireMissile(from: dart, muzzleOffset: muzzleOffset(for: dart))
                            wedgeAINextFireTime = currentTime + 0.1
                        }
                    } else if let sun = sunNode {
                        let dxs = sun.position.x - dart.node.position.x
                        let dys = sun.position.y - dart.node.position.y
                        let dist2 = dxs*dxs + dys*dys
                        let vx = dart.velocity.dx, vy = dart.velocity.dy
                        let vmag = sqrt(vx*vx + vy*vy)

                        let onCollisionCourse: Bool = {
                            if vmag > 1 {
                                let invR = 1.0 / sqrt(dist2)
                                let dot = (vx * dxs * invR + vy * dys * invR)
                                let cross = abs(dxs*vy - dys*vx)
                                let b = cross / vmag
                                return dot > 0 && b < (sunCollisionRadius + 60)
                            }
                            return false
                        }()

                        let avoidRadius: CGFloat = (wedgeAIIntelligence >= 2) ? 180 : 140
                        let tooClose = dist2 < avoidRadius * avoidRadius
                        let shouldAvoidSun = (wedgeAIIntelligence >= 1)
                            ? (shipWillHitSun(dart, in: 3.5) || tooClose)
                            : (tooClose || onCollisionCourse)

                        if wedgeAIIntelligence >= 2 && !shouldAvoidSun {
                            wedgeCollisionBrake = collisionDecision(ship: dart, opponent: needle,
                                                                     killTime: needleKillTime, currentTime: currentTime)
                        }

                        if shouldAvoidSun {
                            let awayPoint = CGPoint(x: dart.node.position.x - dxs, y: dart.node.position.y - dys)
                            rotateShip(dart, toward: awayPoint, dt: dt)
                            dartAimTarget = awayPoint
                            wedgeEvasion = true
                        } else if wedgeHuntingUnarmed {
                            let aimPt = huntAimPoint(shooter: dart, target: needle)
                            rotateShip(dart, toward: aimPt, dt: dt)
                            dartAimTarget = aimPt
                        } else if wedgeCollisionBrake {
                            let avoidPt = collisionAvoidancePoint(for: dart, opponent: needle)
                            rotateShip(dart, toward: avoidPt, dt: dt)
                            dartAimTarget = avoidPt
                        } else {
                            if wedgeAIIntelligence >= 2 {
                                let aimTarget: CGPoint
                                if bulletHitUnavoidable(for: dart) {
                                    aimTarget = level3AimPoint(shooter: dart, target: needle)
                                } else {
                                    let (inDanger, awayPoint) = edgeAwareBulletDanger(for: dart, opponent: needle)
                                    if inDanger { wedgeEvasion = true }
                                    aimTarget = inDanger ? awayPoint
                                                         : strategicPositionTarget(for: dart, opponent: needle, pursueBehind: needleBulletsRemaining > 0)
                                }
                                rotateShip(dart, toward: aimTarget, dt: dt)
                                dartAimTarget = aimTarget
                            } else {
                                var nearestMissilePos = CGPoint.zero
                                var nearestMissileD2 = CGFloat.greatestFiniteMagnitude
                                enumerateChildNodes(withName: "missile") { node, _ in
                                    let dxm = node.position.x - self.dart.node.position.x
                                    let dym = node.position.y - self.dart.node.position.y
                                    let d2m = dxm*dxm + dym*dym
                                    if d2m < nearestMissileD2 { nearestMissileD2 = d2m; nearestMissilePos = node.position }
                                }
                                let avoidBulletR: CGFloat = 120
                                if nearestMissileD2 < avoidBulletR*avoidBulletR {
                                    let awayPoint = CGPoint(
                                        x: dart.node.position.x - (nearestMissilePos.x - dart.node.position.x),
                                        y: dart.node.position.y - (nearestMissilePos.y - dart.node.position.y))
                                    rotateShip(dart, toward: awayPoint, dt: dt)
                                    dartAimTarget = awayPoint
                                } else if !needle.node.isHidden {
                                    let dxn = needle.node.position.x - dart.node.position.x
                                    let dyn = needle.node.position.y - dart.node.position.y
                                    let d2n = dxn*dxn + dyn*dyn
                                    if d2n < 90*90 {
                                        let awayPoint = CGPoint(x: dart.node.position.x - dxn, y: dart.node.position.y - dyn)
                                        rotateShip(dart, toward: awayPoint, dt: dt)
                                        dartAimTarget = awayPoint
                                    } else {
                                        let t = predictedAimPoint(shooter: dart, target: needle, intelligence: wedgeAIIntelligence)
                                        rotateShip(dart, toward: t, dt: dt)
                                        dartAimTarget = t
                                    }
                                } else {
                                    let t = predictedAimPoint(shooter: dart, target: needle, intelligence: wedgeAIIntelligence)
                                    rotateShip(dart, toward: t, dt: dt)
                                    dartAimTarget = t
                                }
                            }
                        }
                    } else {
                        // No sun — wedge
                        if wedgeAIIntelligence >= 2 {
                            wedgeCollisionBrake = collisionDecision(ship: dart, opponent: needle,
                                                                     killTime: needleKillTime, currentTime: currentTime)
                        }

                        if wedgeHuntingUnarmed {
                            let aimPt = huntAimPoint(shooter: dart, target: needle)
                            rotateShip(dart, toward: aimPt, dt: dt)
                            dartAimTarget = aimPt
                        } else if wedgeCollisionBrake {
                            let avoidPt = collisionAvoidancePoint(for: dart, opponent: needle)
                            rotateShip(dart, toward: avoidPt, dt: dt)
                            dartAimTarget = avoidPt
                        } else if wedgeAIIntelligence >= 2 {
                            let aimTarget: CGPoint
                            if bulletHitUnavoidable(for: dart) {
                                aimTarget = level3AimPoint(shooter: dart, target: needle)
                            } else {
                                let (inDanger, awayPoint) = edgeAwareBulletDanger(for: dart, opponent: needle)
                                if inDanger { wedgeEvasion = true }
                                aimTarget = inDanger ? awayPoint
                                                     : strategicPositionTarget(for: dart, opponent: needle, pursueBehind: needleBulletsRemaining > 0)
                            }
                            rotateShip(dart, toward: aimTarget, dt: dt)
                            dartAimTarget = aimTarget
                        } else {
                            var nearestMissilePos = CGPoint.zero
                            var nearestMissileD2 = CGFloat.greatestFiniteMagnitude
                            enumerateChildNodes(withName: "missile") { node, _ in
                                let dxm = node.position.x - self.dart.node.position.x
                                let dym = node.position.y - self.dart.node.position.y
                                let d2m = dxm*dxm + dym*dym
                                if d2m < nearestMissileD2 { nearestMissileD2 = d2m; nearestMissilePos = node.position }
                            }
                            let avoidBulletR: CGFloat = 120
                            if nearestMissileD2 < avoidBulletR*avoidBulletR {
                                let awayPoint = CGPoint(
                                    x: dart.node.position.x - (nearestMissilePos.x - dart.node.position.x),
                                    y: dart.node.position.y - (nearestMissilePos.y - dart.node.position.y))
                                rotateShip(dart, toward: awayPoint, dt: dt)
                                dartAimTarget = awayPoint
                            } else {
                                let t = predictedAimPoint(shooter: dart, target: needle, intelligence: wedgeAIIntelligence)
                                rotateShip(dart, toward: t, dt: dt)
                                dartAimTarget = t
                            }
                        }
                    }
                } else if let p = aimPoint {
                    rotateShip(dart, toward: p, dt: dt)
                    dartAimTarget = p
                }
            }

            // Target indicators — commented out; uncomment to re-enable aim visualisation
            // if let t = needleAimTarget {
            //     needleTargetIndicator.position = t; needleTargetIndicator.alpha = 0.7
            // } else { needleTargetIndicator.alpha = 0 }
            //
            // if let t = dartAimTarget {
            //     dartTargetIndicator.position = t; dartTargetIndicator.alpha = 0.7
            // } else { dartTargetIndicator.alpha = 0 }

            // MARK: Needle AI thrust + fire
            if needleAIEnabled && !needle.node.isHidden {
                if needleAIIntelligence >= 2 {
                    if needleHuntingUnarmed {
                        isThrustingNeedle = !needleCollisionBrake
                        aiThrustOn = isThrustingNeedle
                        aiNextThrustToggle = currentTime + 0.1
                    } else if needleCollisionBrake {
                        isThrustingNeedle = true
                        aiThrustOn = true
                        aiNextThrustToggle = currentTime + 0.1
                    } else {
                        if needleEvasion {
                            aiThrustOn = true
                            aiNextThrustToggle = currentTime + Double.random(in: 0.5...1.0)
                        } else if currentTime >= aiNextThrustToggle {
                            aiThrustOn.toggle()
                            let oppDist = hypot(dart.node.position.x - needle.node.position.x,
                                                dart.node.position.y - needle.node.position.y)
                            let outOfPosition = abs(oppDist - 260) > 80
                            aiNextThrustToggle = currentTime + Double.random(
                                in: aiThrustOn ? (outOfPosition ? 0.6...1.1 : 0.2...0.5)
                                               : (outOfPosition ? 0.1...0.2 : 0.2...0.5))
                        }
                        isThrustingNeedle = aiThrustOn
                    }
                } else {
                    if currentTime >= aiNextThrustToggle {
                        aiThrustOn.toggle()
                        aiNextThrustToggle = currentTime + Double.random(in: aiThrustOn ? 0.3...0.8 : 0.4...1.2)
                    }
                    isThrustingNeedle = aiThrustOn
                }

                if needleAIIntelligence >= 2 && !needleCollisionBrake && !needleEvasion
                    && !dart.node.isHidden && (currentTime - dartVisibleSince) >= 1.0
                    && currentTime >= aiCertainFireCooldown
                    && !ownBulletWillHit(shooter: needle, target: dart) {
                    let aim = level3AimPoint(shooter: needle, target: dart)
                    let aimAngle = atan2(aim.y - needle.node.position.y,
                                         aim.x - needle.node.position.x) - .pi/2
                    if abs(shortestAngleBetween(needle.node.zRotation, aimAngle)) < .pi / 7
                        && bulletWillHit(shooter: needle, target: dart) {
                        fireMissile(from: needle, muzzleOffset: muzzleOffset(for: needle))
                        aiCertainFireCooldown = currentTime + 0.2
                        aiNextFireTime = currentTime + 0.25
                    }
                }

                if currentTime >= aiNextFireTime && !dart.node.isHidden && (currentTime - dartVisibleSince) >= 1.0
                    && !ownBulletWillHit(shooter: needle, target: dart) {
                    var shouldFire = true
                    if needleAIIntelligence < 2 {
                        let oppDist = hypot(dart.node.position.x - needle.node.position.x,
                                            dart.node.position.y - needle.node.position.y)
                        if oppDist > 1000 { shouldFire = false }
                    }
                    if shouldFire, needleAIIntelligence >= 1, sunNode != nil {
                        shouldFire = !simulateBulletHitsSun(from: needle, target: dart)
                    }
                    if shouldFire && needleAIIntelligence >= 2 {
                        if needleCollisionBrake {
                            shouldFire = false
                        } else if needleHuntingUnarmed {
                            let oppPos = (edgeBehavior == .wrap)
                                ? nearestVirtualPosition(of: dart.node.position, from: needle.node.position)
                                : dart.node.position
                            let ddx = oppPos.x - needle.node.position.x
                            let ddy = oppPos.y - needle.node.position.y
                            let oppDist = hypot(ddx, ddy)
                            if oppDist > 600 {
                                shouldFire = false
                            } else {
                                let toOppX = ddx / max(oppDist, 1), toOppY = ddy / max(oppDist, 1)
                                let netSpeed: CGFloat = 480 + needle.velocity.dx * toOppX + needle.velocity.dy * toOppY
                                if netSpeed < 80 { shouldFire = false }
                                else {
                                    let aimPt = huntAimPoint(shooter: needle, target: dart)
                                    let aimAngle = atan2(aimPt.y - needle.node.position.y,
                                                         aimPt.x - needle.node.position.x) - .pi/2
                                    if abs(shortestAngleBetween(needle.node.zRotation, aimAngle)) > .pi / 9 {
                                        shouldFire = false
                                    }
                                }
                            }
                        } else {
                            let oppDist = hypot(dart.node.position.x - needle.node.position.x,
                                                dart.node.position.y - needle.node.position.y)
                            if oppDist > 600 {
                                shouldFire = false
                            } else {
                                let aim = level3AimPoint(shooter: needle, target: dart)
                                let aimAngle = atan2(aim.y - needle.node.position.y,
                                                     aim.x - needle.node.position.x) - .pi/2
                                if abs(shortestAngleBetween(needle.node.zRotation, aimAngle)) > .pi / 12 {
                                    shouldFire = false
                                }
                            }
                        }
                    }
                    if shouldFire {
                        fireMissile(from: needle, muzzleOffset: muzzleOffset(for: needle))
                        aiNextFireTime = currentTime + Double.random(in: 0.35...0.7)
                    } else {
                        aiNextFireTime = currentTime + 0.1
                    }
                }
            }

            // MARK: Wedge AI thrust + fire
            if wedgeAIEnabled && !dart.node.isHidden {
                if wedgeAIIntelligence == 3 {
                    wedgeAIThrustOn = isThrustingDart
                    wedgeAINextThrustToggle = currentTime + 0.1
                } else if wedgeAIIntelligence >= 2 {
                    if wedgeHuntingUnarmed {
                        isThrustingDart = !wedgeCollisionBrake
                        wedgeAIThrustOn = isThrustingDart
                        wedgeAINextThrustToggle = currentTime + 0.1
                    } else if wedgeCollisionBrake {
                        isThrustingDart = true
                        wedgeAIThrustOn = true
                        wedgeAINextThrustToggle = currentTime + 0.1
                    } else {
                        if wedgeEvasion {
                            wedgeAIThrustOn = true
                            wedgeAINextThrustToggle = currentTime + Double.random(in: 0.5...1.0)
                        } else if currentTime >= wedgeAINextThrustToggle {
                            wedgeAIThrustOn.toggle()
                            let oppDist = hypot(needle.node.position.x - dart.node.position.x,
                                                needle.node.position.y - dart.node.position.y)
                            let outOfPosition = abs(oppDist - 260) > 80
                            wedgeAINextThrustToggle = currentTime + Double.random(
                                in: wedgeAIThrustOn ? (outOfPosition ? 0.6...1.1 : 0.2...0.5)
                                                    : (outOfPosition ? 0.1...0.2 : 0.2...0.5))
                        }
                        isThrustingDart = wedgeAIThrustOn
                    }
                } else {
                    if currentTime >= wedgeAINextThrustToggle {
                        wedgeAIThrustOn.toggle()
                        wedgeAINextThrustToggle = currentTime + Double.random(in: wedgeAIThrustOn ? 0.3...0.8 : 0.4...1.2)
                    }
                    isThrustingDart = wedgeAIThrustOn
                }

                if wedgeAIIntelligence >= 2 && wedgeAIIntelligence < 3 && !wedgeCollisionBrake && !wedgeEvasion
                    && !needle.node.isHidden && (currentTime - needleVisibleSince) >= 1.0
                    && currentTime >= wedgeCertainFireCooldown
                    && !ownBulletWillHit(shooter: dart, target: needle) {
                    let aim = level3AimPoint(shooter: dart, target: needle)
                    let aimAngle = atan2(aim.y - dart.node.position.y,
                                         aim.x - dart.node.position.x) - .pi/2
                    if abs(shortestAngleBetween(dart.node.zRotation, aimAngle)) < .pi / 7
                        && bulletWillHit(shooter: dart, target: needle) {
                        fireMissile(from: dart, muzzleOffset: muzzleOffset(for: dart))
                        wedgeCertainFireCooldown = currentTime + 0.2
                        wedgeAINextFireTime = currentTime + 0.25
                    }
                }

                if wedgeAIIntelligence < 3 && currentTime >= wedgeAINextFireTime && !needle.node.isHidden && (currentTime - needleVisibleSince) >= 1.0
                    && !ownBulletWillHit(shooter: dart, target: needle) {
                    var shouldFire = true
                    if wedgeAIIntelligence < 2 {
                        let oppDist = hypot(needle.node.position.x - dart.node.position.x,
                                            needle.node.position.y - dart.node.position.y)
                        if oppDist > 1000 { shouldFire = false }
                    }
                    if shouldFire, wedgeAIIntelligence >= 1, sunNode != nil {
                        shouldFire = !simulateBulletHitsSun(from: dart, target: needle)
                    }
                    if shouldFire && wedgeAIIntelligence >= 2 {
                        if wedgeCollisionBrake {
                            shouldFire = false
                        } else if wedgeHuntingUnarmed {
                            let oppPos = (edgeBehavior == .wrap)
                                ? nearestVirtualPosition(of: needle.node.position, from: dart.node.position)
                                : needle.node.position
                            let ddx = oppPos.x - dart.node.position.x
                            let ddy = oppPos.y - dart.node.position.y
                            let oppDist = hypot(ddx, ddy)
                            if oppDist > 600 {
                                shouldFire = false
                            } else {
                                let toOppX = ddx / max(oppDist, 1), toOppY = ddy / max(oppDist, 1)
                                let netSpeed: CGFloat = 480 + dart.velocity.dx * toOppX + dart.velocity.dy * toOppY
                                if netSpeed < 80 { shouldFire = false }
                                else {
                                    let aimPt = huntAimPoint(shooter: dart, target: needle)
                                    let aimAngle = atan2(aimPt.y - dart.node.position.y,
                                                         aimPt.x - dart.node.position.x) - .pi/2
                                    if abs(shortestAngleBetween(dart.node.zRotation, aimAngle)) > .pi / 9 {
                                        shouldFire = false
                                    }
                                }
                            }
                        } else {
                            let oppDist = hypot(needle.node.position.x - dart.node.position.x,
                                                needle.node.position.y - dart.node.position.y)
                            if oppDist > 600 {
                                shouldFire = false
                            } else {
                                let aim = level3AimPoint(shooter: dart, target: needle)
                                let aimAngle = atan2(aim.y - dart.node.position.y,
                                                     aim.x - dart.node.position.x) - .pi/2
                                if abs(shortestAngleBetween(dart.node.zRotation, aimAngle)) > .pi / 12 {
                                    shouldFire = false
                                }
                            }
                        }
                    }
                    if shouldFire {
                        fireMissile(from: dart, muzzleOffset: muzzleOffset(for: dart))
                        wedgeAINextFireTime = currentTime + Double.random(in: 0.35...0.7)
                    } else {
                        wedgeAINextFireTime = currentTime + 0.1
                    }
                }
            }

            if isThrustingDart {
                dart.applyThrust(dt: CGFloat(dt)); dart.flame.alpha = 1
            } else { dart.flame.alpha = 0 }

            if isThrustingNeedle {
                needle.applyThrust(dt: CGFloat(dt)); needle.flame.alpha = 1
            } else { needle.flame.alpha = 0 }

        } // end do (normal play + game-over exhibition)

        } // end delay guard (!gameOver || past animation start)

        // Gravity
        if sunEnabled, let sun = sunNode {
            func applyGravity(to ship: Ship) {
                let dx = sun.position.x - ship.node.position.x
                let dy = sun.position.y - ship.node.position.y
                let r2 = dx*dx + dy*dy + 100
                let invR = 1.0 / sqrt(r2)
                let G: CGFloat = 18000 * gravityMultiplier
                let a = G / r2
                ship.velocity.dx += dx * invR * a * CGFloat(dt)
                ship.velocity.dy += dy * invR * a * CGFloat(dt)
            }
            if !needle.node.isHidden { applyGravity(to: needle) }
            if !dart.node.isHidden   { applyGravity(to: dart) }

            if sunAffectsBullets {
                enumerateChildNodes(withName: "missile") { node, _ in
                    guard let data = node.userData,
                          var vx = data["vx"] as? CGFloat,
                          var vy = data["vy"] as? CGFloat else { return }
                    let dx = sun.position.x - node.position.x
                    let dy = sun.position.y - node.position.y
                    let r2 = dx*dx + dy*dy + 100
                    let invR = 1.0 / sqrt(r2)
                    let G: CGFloat = 18000 * self.gravityMultiplier * (5.0 / 8.0)
                    let a = G / r2
                    vx += dx * invR * a * CGFloat(dt); vy += dy * invR * a * CGFloat(dt)
                    node.userData?["vx"] = vx; node.userData?["vy"] = vy
                }
            }
        }

        dart.clampSpeed();   needle.clampSpeed()
        dart.integrate(dt: CGFloat(dt)); needle.integrate(dt: CGFloat(dt))

        if dt > 0 {
            dartObservedAcceleration = CGVector(
                dx: (dart.velocity.dx - dartPreviousVelocity.dx) / CGFloat(dt),
                dy: (dart.velocity.dy - dartPreviousVelocity.dy) / CGFloat(dt))
            needleObservedAcceleration = CGVector(
                dx: (needle.velocity.dx - needlePreviousVelocity.dx) / CGFloat(dt),
                dy: (needle.velocity.dy - needlePreviousVelocity.dy) / CGFloat(dt))
            let α: CGFloat = 0.08
            dartSmoothedAcceleration = CGVector(
                dx: dartSmoothedAcceleration.dx + α * (dartObservedAcceleration.dx - dartSmoothedAcceleration.dx),
                dy: dartSmoothedAcceleration.dy + α * (dartObservedAcceleration.dy - dartSmoothedAcceleration.dy))
            needleSmoothedAcceleration = CGVector(
                dx: needleSmoothedAcceleration.dx + α * (needleObservedAcceleration.dx - needleSmoothedAcceleration.dx),
                dy: needleSmoothedAcceleration.dy + α * (needleObservedAcceleration.dy - needleSmoothedAcceleration.dy))
        }
        dartPreviousVelocity   = dart.velocity
        needlePreviousVelocity = needle.velocity

        func handleEdges(_ ship: Ship) {
            var pos = ship.node.position
            let W = virtualWorldWidth, H = virtualWorldHeight
            switch edgeBehavior {
            case .bounce:
                var bounced = false
                if pos.x < 0  { pos.x = 0;  ship.velocity.dx =  abs(ship.velocity.dx); bounced = true }
                if pos.x > W  { pos.x = W;  ship.velocity.dx = -abs(ship.velocity.dx); bounced = true }
                if pos.y < 0  { pos.y = 0;  ship.velocity.dy =  abs(ship.velocity.dy); bounced = true }
                if pos.y > H  { pos.y = H;  ship.velocity.dy = -abs(ship.velocity.dy); bounced = true }
                if bounced { ship.node.position = pos; ship.alignRotationToVelocityIfMoving() }
            case .wrap:
                if pos.x < 0  { pos.x = W }
                if pos.x > W  { pos.x = 0 }
                if pos.y < 0  { pos.y = H }
                if pos.y > H  { pos.y = 0 }
                ship.node.position = pos
            }
        }
        handleEdges(dart); handleEdges(needle)

        enumerateChildNodes(withName: "missile") { node, _ in
            guard let data = node.userData,
                  var vx = data["vx"] as? CGFloat,
                  var vy = data["vy"] as? CGFloat else { return }
            node.position.x += vx * CGFloat(dt); node.position.y += vy * CGFloat(dt)
            let mW = self.virtualWorldWidth, mH = self.virtualWorldHeight
            switch self.edgeBehavior {
            case .bounce:
                var bounced = false
                if node.position.x < 0    { node.position.x = 0;   vx =  abs(vx); bounced = true }
                if node.position.x > mW   { node.position.x = mW;  vx = -abs(vx); bounced = true }
                if node.position.y < 0    { node.position.y = 0;   vy =  abs(vy); bounced = true }
                if node.position.y > mH   { node.position.y = mH;  vy = -abs(vy); bounced = true }
                if bounced { node.userData?["vx"] = vx; node.userData?["vy"] = vy; node.userData?["bounced"] = true }
            case .wrap:
                if node.position.x < 0    { node.position.x = mW }
                if node.position.x > mW   { node.position.x = 0 }
                if node.position.y < 0    { node.position.y = mH }
                if node.position.y > mH   { node.position.y = 0 }
            }
        }

        enumerateChildNodes(withName: "wreckPiece") { node, _ in
            guard let data = node.userData,
                  var vx = data["vx"] as? CGFloat,
                  var vy = data["vy"] as? CGFloat,
                  var life = data["life"] as? CGFloat,
                  let maxLife = data["maxLife"] as? CGFloat else { return }
            node.position.x += vx * CGFloat(dt); node.position.y += vy * CGFloat(dt)
            let wW = self.virtualWorldWidth, wH = self.virtualWorldHeight
            switch self.edgeBehavior {
            case .bounce:
                var bounced = false
                if node.position.x < 0   { node.position.x = 0;   vx =  abs(vx); bounced = true }
                if node.position.x > wW  { node.position.x = wW;  vx = -abs(vx); bounced = true }
                if node.position.y < 0   { node.position.y = 0;   vy =  abs(vy); bounced = true }
                if node.position.y > wH  { node.position.y = wH;  vy = -abs(vy); bounced = true }
                if bounced { node.userData?["vx"] = vx; node.userData?["vy"] = vy }
            case .wrap:
                if node.position.x < 0   { node.position.x = wW }
                if node.position.x > wW  { node.position.x = 0 }
                if node.position.y < 0   { node.position.y = wH }
                if node.position.y > wH  { node.position.y = 0 }
            }
            life -= CGFloat(dt); node.userData?["life"] = life
            node.alpha = max(0.0, life / maxLife)
            if life <= 0 {
                if let owner = self.wreckOwner.object(forKey: node) {
                    let current = self.wreckPieceCount.object(forKey: owner)?.intValue ?? 0
                    let newCount = max(0, current - 1)
                    self.wreckPieceCount.setObject(NSNumber(value: newCount), forKey: owner)
                    if newCount == 0 {
                        self.enableRandomRespawn = true
                        let bulletLife = self.bulletLifeSeconds
                        let destroyTime = (owner === self.needle.node)
                            ? self.needleDestroyTime : self.dartDestroyTime
                        let elapsed = currentTime - destroyTime
                        let readyToRespawn = elapsed >= bulletLife

                        if owner === self.needle.node {
                            if readyToRespawn {
                                self.respawnShip(self.needle)
                                self.needleVisibleSince = currentTime
                            } else {
                                self.needleRespawnScheduled = true
                            }
                        } else if owner === self.dart.node {
                            if readyToRespawn {
                                self.respawnShip(self.dart)
                                self.dartVisibleSince = currentTime
                            } else {
                                self.dartRespawnScheduled = true
                            }
                        }
                    }
                }
                node.removeFromParent()
            }
        }

        if sunEnabled, let sun = sunNode {
            enumerateChildNodes(withName: "missile") { node, _ in
                let bdx = node.position.x - sun.position.x
                let bdy = node.position.y - sun.position.y
                if bdx*bdx + bdy*bdy <= self.sunCollisionRadius * self.sunCollisionRadius {
                    node.removeFromParent()
                }
            }
            if !needle.node.isHidden {
                let dx = needle.node.position.x - sun.position.x
                let dy = needle.node.position.y - sun.position.y
                if dx*dx + dy*dy <= sunCollisionRadius*sunCollisionRadius {
                    if !gameOver { dartScore += 1; updateScoreDisplays() }
                    explodeShip(ship: needle)
                }
            }
            if !dart.node.isHidden {
                let dx = dart.node.position.x - sun.position.x
                let dy = dart.node.position.y - sun.position.y
                if dx*dx + dy*dy <= sunCollisionRadius*sunCollisionRadius {
                    if !gameOver { needleScore += 1; updateScoreDisplays() }
                    explodeShip(ship: dart)
                }
            }
        }

        var needleHit = false, dartHit = false
        let now = CACurrentMediaTime()
        enumerateChildNodes(withName: "missile") { node, _ in
            let owner = self.missileOwner.object(forKey: node)
            let spawn = self.missileSpawnTime.object(forKey: node)?.doubleValue ?? 0
            let bounced = (node.userData?["bounced"] as? Bool) ?? false
            let grace = (!bounced) && (now - spawn < 1.0)
            if !needleHit && !self.needle.node.isHidden && node.frame.intersects(self.needle.node.frame) && !(owner === self.needle.node && grace) {
                needleHit = true; node.removeFromParent()
            }
            if !dartHit && !self.dart.node.isHidden && node.frame.intersects(self.dart.node.frame) && !(owner === self.dart.node && grace) {
                dartHit = true; node.removeFromParent()
            }
        }
        if needleHit { if !gameOver { dartScore += 1; updateScoreDisplays() }; dartKillTime = currentTime; explodeShip(ship: needle) }
        if dartHit   { if !gameOver { needleScore += 1; updateScoreDisplays() }; needleKillTime = currentTime; explodeShip(ship: dart) }
        if !needle.node.isHidden && !dart.node.isHidden && needle.node.frame.intersects(dart.node.frame) {
            if !gameOver { needleScore += 1; dartScore += 1; updateScoreDisplays() }
            explodeShip(ship: needle); explodeShip(ship: dart)
        }

        lastUpdateTime = currentTime
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)

            if let overlay = optionsOverlay, !overlay.isHidden {
                let locInOverlay = touch.location(in: overlay)

                if let bg = overlay.childNode(withName: "options_bg") as? SKShapeNode, !bg.contains(locInOverlay) {
                    setOptionsVisible(false); continue
                }

                var handled = false

                if let tab = gameTabButton, tab.contains(locInOverlay) {
                    setOptionsTab(.game); handled = true
                } else if let tab = optionsTabButton, tab.contains(locInOverlay) {
                    setOptionsTab(.environment); handled = true
                } else if let tab = shipsTabButton, tab.contains(locInOverlay) {
                    setOptionsTab(.ships); handled = true
                } else if let tab = aboutTabButton, tab.contains(locInOverlay) {
                    setOptionsTab(.about); handled = true
                } else if let tab = shipSelectionTabButton, tab.contains(locInOverlay) {
                    setOptionsTab(.shipSelection); handled = true
                } else if let tab = networkTabButton, tab.contains(locInOverlay) {
                    setOptionsTab(.network); handled = true
                } else if let btn = aimPersistToggleButton, btn.contains(locInOverlay) {
                    aimPersistsAfterLift.toggle(); refreshOptionsUI(); handled = true
                }
                if handled { continue }

                if let btn = edgeBounceButton, btn.contains(locInOverlay) {
                    edgeBehavior = .bounce; refreshOptionsUI(); handled = true
                } else if let btn = edgeWrapButton, btn.contains(locInOverlay) {
                    edgeBehavior = .wrap; refreshOptionsUI(); handled = true
                } else if let btn = aiToggleButton, btn.contains(locInOverlay) {
                    needleAIEnabled.toggle()
                    aiNextThrustToggle = 0; aiNextFireTime = 0; aiThrustOn = false
                    updateNeedleControlsVisibility(); refreshOptionsUI(); handled = true
                } else if let btn = wedgeAIToggleButton, btn.contains(locInOverlay) {
                    wedgeAIEnabled.toggle()
                    wedgeAINextThrustToggle = 0; wedgeAINextFireTime = 0; wedgeAIThrustOn = false
                    updateWedgeControlsVisibility(); refreshOptionsUI(); handled = true
                } else if let btn = sunToggleButton, btn.contains(locInOverlay) {
                    sunEnabled.toggle(); applySunState(); refreshOptionsUI(); handled = true
                } else if let btn = bulletGravToggleButton, btn.contains(locInOverlay), sunEnabled {
                    sunAffectsBullets.toggle(); refreshOptionsUI(); handled = true
                } else if let btn = overlay.childNode(withName: "game_new_match") as? SKShapeNode, btn.contains(locInOverlay) {
                    btn.fillColor = .white; btn.strokeColor = .white
                    btn.children.compactMap { $0 as? SKLabelNode }.forEach { $0.fontColor = .black }
                    newMatchButtonTouch = touch
                    handled = true
                }

                if !handled && touchIsOnSlider(track: needleBulletSliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .ships {
                    let kx = -sliderTrackHalfWidth + CGFloat(needleBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
                    if locInOverlay.x < kx - 5 {
                        needleBulletLimitSelection = max(0, needleBulletLimitSelection - 1)
                    } else if locInOverlay.x > kx + 5 {
                        needleBulletLimitSelection = min(bulletSliderSteps, needleBulletLimitSelection + 1)
                    }
                    draggingNeedleSliderTouch = touch
                    resetBulletCountsFromSelections(); endGameIfNoBullets(); refreshOptionsUI(); handled = true
                } else if !handled && touchIsOnSlider(track: dartBulletSliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .ships {
                    let kx = -sliderTrackHalfWidth + CGFloat(dartBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
                    if locInOverlay.x < kx - 5 {
                        dartBulletLimitSelection = max(0, dartBulletLimitSelection - 1)
                    } else if locInOverlay.x > kx + 5 {
                        dartBulletLimitSelection = min(bulletSliderSteps, dartBulletLimitSelection + 1)
                    }
                    draggingDartSliderTouch = touch
                    resetBulletCountsFromSelections(); endGameIfNoBullets(); refreshOptionsUI(); handled = true
                } else if !handled && touchIsOnSlider(track: needleAISliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .ships && needleAIEnabled {
                    let kx = -aiIntelligenceTrackHalfWidth + CGFloat(needleAIIntelligence) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
                    if locInOverlay.x < kx - 5 {
                        needleAIIntelligence = max(0, needleAIIntelligence - 1)
                    } else if locInOverlay.x > kx + 5 {
                        needleAIIntelligence = min(aiIntelligenceSteps, needleAIIntelligence + 1)
                    }
                    draggingNeedleAISliderTouch = touch; refreshOptionsUI(); handled = true
                } else if !handled && touchIsOnSlider(track: wedgeAISliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .ships && wedgeAIEnabled {
                    let kx = -aiIntelligenceTrackHalfWidth + CGFloat(wedgeAIIntelligence) * (aiIntelligenceTrackWidth / CGFloat(aiIntelligenceSteps))
                    if locInOverlay.x < kx - 5 {
                        wedgeAIIntelligence = max(0, wedgeAIIntelligence - 1)
                    } else if locInOverlay.x > kx + 5 {
                        wedgeAIIntelligence = min(aiIntelligenceSteps, wedgeAIIntelligence + 1)
                    }
                    draggingWedgeAISliderTouch = touch; refreshOptionsUI(); handled = true
                } else if !handled && touchIsOnSlider(track: virtualScreenSliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .game {
                    let kx = -sliderTrackHalfWidth + CGFloat(virtualScreenSelection) * (sliderTrackWidth / CGFloat(virtualScreenSteps))
                    if locInOverlay.x < kx - 5 {
                        virtualScreenSelection = max(0, virtualScreenSelection - 1)
                    } else if locInOverlay.x > kx + 5 {
                        virtualScreenSelection = min(virtualScreenSteps, virtualScreenSelection + 1)
                    }
                    virtualScreenMode = [.off, .medium][virtualScreenSelection]
                    draggingVirtualScreenSliderTouch = touch
                    applyVirtualScreenMode(); refreshOptionsUI(); handled = true
                } else if !handled && touchIsOnSlider(track: gravitySliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .environment && sunEnabled {
                    let kx = -sliderTrackHalfWidth + CGFloat(gravitySliderSelection) * (sliderTrackWidth / CGFloat(gravitySliderSteps))
                    if locInOverlay.x < kx - 5 {
                        gravitySliderSelection = max(0, gravitySliderSelection - 1)
                    } else if locInOverlay.x > kx + 5 {
                        gravitySliderSelection = min(gravitySliderSteps, gravitySliderSelection + 1)
                    }
                    draggingGravitySliderTouch = touch; refreshOptionsUI(); handled = true
                }

                if handled { continue }
            }

            if optionsButton.contains(location) {
                setOptionsVisible(!optionsVisible); refreshOptionsUI(); continue
            }

            if optionsVisible { continue }
            if gameOver { continue }

            var consumed = false

            if !wedgeAIEnabled && rightThrustButton.contains(location) {
                activeRightThrustTouches.insert(touch); isThrustingDart = true; consumed = true
            }

            if !wedgeAIEnabled && fireThrustButton.contains(location) {
                fireTouches[ObjectIdentifier(touch)] = FireTouchInfo(
                    ship: dart, startTime: CACurrentMediaTime(),
                    startLocation: location, buttonNode: fireThrustButton)
                consumed = true
            }

            #if DEBUG
            if !needleAIEnabled, let leftThrust = leftThrustButton, !leftThrust.isHidden,
               leftThrust.contains(location) {
                activeLeftThrustTouches.insert(touch)
                isThrustingNeedle = true
                consumed = true
            }

            if let leftFireButton = leftFireButtonRef, !leftFireButton.isHidden, leftFireButton.contains(location) {
                fireTouches[ObjectIdentifier(touch)] = FireTouchInfo(
                    ship: needle, startTime: CACurrentMediaTime(),
                    startLocation: location, buttonNode: leftFireButton)
                consumed = true
            }
            #endif

            if !consumed {
                aimPoint = location; activeAimTouches.insert(touch)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let overlay = optionsOverlay, !overlay.isHidden {
                let locInOverlay = touch.location(in: overlay)

                if draggingNeedleSliderTouch == touch {
                    let idx = sliderIndexForOverlayX(locInOverlay.x)
                    if needleBulletLimitSelection != idx {
                        needleBulletLimitSelection = idx
                        resetBulletCountsFromSelections(); endGameIfNoBullets(); refreshOptionsUI()
                    }
                    continue
                }
                if draggingDartSliderTouch == touch {
                    let idx = sliderIndexForOverlayX(locInOverlay.x)
                    if dartBulletLimitSelection != idx {
                        dartBulletLimitSelection = idx
                        resetBulletCountsFromSelections(); endGameIfNoBullets(); refreshOptionsUI()
                    }
                    continue
                }
                if draggingNeedleAISliderTouch == touch {
                    let idx = aiSliderIndexForOverlayX(locInOverlay.x)
                    if needleAIIntelligence != idx { needleAIIntelligence = idx; refreshOptionsUI() }
                    continue
                }
                if draggingWedgeAISliderTouch == touch {
                    let idx = aiSliderIndexForOverlayX(locInOverlay.x)
                    if wedgeAIIntelligence != idx { wedgeAIIntelligence = idx; refreshOptionsUI() }
                    continue
                }
                if draggingVirtualScreenSliderTouch == touch {
                    let step = sliderTrackWidth / CGFloat(virtualScreenSteps)
                    let idx = max(0, min(virtualScreenSteps, Int(round((locInOverlay.x + sliderTrackHalfWidth) / step))))
                    if virtualScreenSelection != idx {
                        virtualScreenSelection = idx
                        virtualScreenMode = [.off, .medium][idx]
                        applyVirtualScreenMode(); refreshOptionsUI()
                    }
                    continue
                }
                if draggingGravitySliderTouch == touch {
                    let step = sliderTrackWidth / CGFloat(gravitySliderSteps)
                    let idx = max(0, min(gravitySliderSteps, Int(round((locInOverlay.x + sliderTrackHalfWidth) / step))))
                    if gravitySliderSelection != idx { gravitySliderSelection = idx; refreshOptionsUI() }
                    continue
                }
            }

            let location = touch.location(in: self)
            var onAnyButton = false

            if !wedgeAIEnabled {
                if rightThrustButton.contains(location) {
                    activeRightThrustTouches.insert(touch)
                } else {
                    activeRightThrustTouches.remove(touch)
                }
                isThrustingDart = !activeRightThrustTouches.isEmpty
                onAnyButton = onAnyButton || rightThrustButton.contains(location) || fireThrustButton.contains(location)
            }

            #if DEBUG
            if let leftThrustButton, !leftThrustButton.isHidden {
                if leftThrustButton.contains(location) {
                    activeLeftThrustTouches.insert(touch)
                } else {
                    activeLeftThrustTouches.remove(touch)
                }
                isThrustingNeedle = !activeLeftThrustTouches.isEmpty
                onAnyButton = onAnyButton || leftThrustButton.contains(location)
            }
            if let leftFireButton = leftFireButtonRef, !leftFireButton.isHidden {
                onAnyButton = onAnyButton || leftFireButton.contains(location)
            }
            #endif

            let id = ObjectIdentifier(touch)
            if let info = fireTouches[id] {
                let dx = location.x - info.startLocation.x
                let dy = location.y - info.startLocation.y
                if dx*dx + dy*dy > 12*12 { fireTouches.removeValue(forKey: id) }
            }

            if optionsVisible { continue }
            if gameOver { continue }

            if !onAnyButton {
                activeAimTouches.insert(touch); aimPoint = location
            } else {
                activeAimTouches.remove(touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if draggingNeedleSliderTouch   == touch { draggingNeedleSliderTouch   = nil }
            if draggingDartSliderTouch     == touch { draggingDartSliderTouch     = nil }
            if draggingNeedleAISliderTouch == touch { draggingNeedleAISliderTouch = nil }
            if draggingWedgeAISliderTouch  == touch { draggingWedgeAISliderTouch  = nil }
            if draggingVirtualScreenSliderTouch == touch { draggingVirtualScreenSliderTouch = nil }
            if draggingGravitySliderTouch   == touch { draggingGravitySliderTouch   = nil }
            if newMatchButtonTouch == touch {
                newMatchButtonTouch = nil
                restoreNewMatchButton()
                startNewMatch()
                continue
            }

            activeAimTouches.remove(touch)
            activeRightThrustTouches.remove(touch)
            #if DEBUG
            activeLeftThrustTouches.remove(touch)
            #endif
            isThrustingDart = !activeRightThrustTouches.isEmpty
            #if DEBUG
            isThrustingNeedle = !activeLeftThrustTouches.isEmpty
            #endif

            if optionsVisible { continue }
            if gameOver { continue }

            let id = ObjectIdentifier(touch)
            if let info = fireTouches.removeValue(forKey: id) {
                let duration = CACurrentMediaTime() - info.startTime
                let location = touch.location(in: self)
                if duration < 0.25, let button = info.buttonNode, button.contains(location) {
                    fireMissile(from: info.ship, muzzleOffset: muzzleOffset(for: info.ship))
                }
                continue
            }

            if !aimPersistsAfterLift && activeAimTouches.isEmpty { aimPoint = nil }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeRightThrustTouches.remove(touch)
            #if DEBUG
            activeLeftThrustTouches.remove(touch)
            #endif
            if draggingNeedleSliderTouch   == touch { draggingNeedleSliderTouch   = nil }
            if draggingDartSliderTouch     == touch { draggingDartSliderTouch     = nil }
            if draggingNeedleAISliderTouch == touch { draggingNeedleAISliderTouch = nil }
            if draggingWedgeAISliderTouch  == touch { draggingWedgeAISliderTouch  = nil }
            if draggingVirtualScreenSliderTouch == touch { draggingVirtualScreenSliderTouch = nil }
            if draggingGravitySliderTouch   == touch { draggingGravitySliderTouch   = nil }
            if newMatchButtonTouch == touch { newMatchButtonTouch = nil; restoreNewMatchButton() }
            fireTouches.removeValue(forKey: ObjectIdentifier(touch))
            activeAimTouches.remove(touch)
        }

        if !aimPersistsAfterLift && activeAimTouches.isEmpty { aimPoint = nil }
        isThrustingDart = !activeRightThrustTouches.isEmpty
        #if DEBUG
        isThrustingNeedle = !activeLeftThrustTouches.isEmpty
        #endif
    }
}
