//
//  GameScene.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 1/9/26.
//

import SpriteKit
import GameplayKit

// MARK: - Ship

final class Ship {
    let node: SKShapeNode
    let flame: SKShapeNode
    var velocity: CGVector = .zero
    var maxSpeed: CGFloat
    // FIX 1: spawnPosition is now `var` so it can be updated after layout.
    var spawnPosition: CGPoint
    let name: String

    init(name: String, path: CGPath, flame: SKShapeNode, spawn: CGPoint, maxSpeed: CGFloat) {
        self.node = SKShapeNode(path: path)
        self.node.strokeColor = .white
        self.node.lineWidth = 2
        self.node.glowWidth = 4
        self.node.zPosition = 1

        self.flame = flame
        self.flame.alpha = 0
        self.node.addChild(flame)

        self.spawnPosition = spawn
        self.maxSpeed = maxSpeed
        self.name = name
        self.node.name = name
        self.node.position = spawn
    }

    func clampSpeed() {
        let s = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if s > maxSpeed && s > 0 {
            let k = maxSpeed / s
            velocity.dx *= k
            velocity.dy *= k
        }
    }

    func applyThrust(accel: CGFloat, dt: CGFloat) {
        let ang = node.zRotation
        velocity.dx += -accel * sin(ang) * dt
        velocity.dy +=  accel * cos(ang) * dt
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

    // Gameplay settings and UI
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

    private enum OptionsTab { case game, environment, ships, about }
    private var currentOptionsTab: OptionsTab = .environment

    // Tab buttons
    private var gameTabButton: SKShapeNode?
    private var optionsTabButton: SKShapeNode?
    private var shipsTabButton: SKShapeNode?
    private var aboutTabButton: SKShapeNode?
    private var aboutContainer: SKNode?

    private var needleAIEnabled: Bool = false

    // Game options
    private var aimPersistsAfterLift: Bool = true
    private var aimPersistToggleButton: SKShapeNode?

    // Track which touches are "aim" touches
    private var activeAimTouches = Set<UITouch>()

    // Needle AI timers/state
    private var aiNextThrustToggle: TimeInterval = 0
    private var aiThrustOn: Bool = false
    private var aiNextFireTime: TimeInterval = 0

    // Post-game-over drift AI (both ships wander randomly, no firing)
    private var driftNeedleThrustOn: Bool = false
    private var driftDartThrustOn: Bool = false
    private var driftNeedleNextToggle: TimeInterval = 0
    private var driftDartNextToggle: TimeInterval = 0
    private var driftNeedleTargetAngle: CGFloat = 0
    private var driftDartTargetAngle: CGFloat = 0
    private var driftNeedleNextTurn: TimeInterval = 0
    private var driftDartNextTurn: TimeInterval = 0

    // Game Over label node (separate from victorLabelNode)
    private var gameOverLabelNode: SKNode?

    // Track when ships are visible (for AI gating)
    private var needleVisibleSince: TimeInterval = 0
    private var dartVisibleSince: TimeInterval = 0

    // Bullet limits and UI
    private var needleBulletLimitSelection: Int = 1 // index 1 = 5 bullets
    private var dartBulletLimitSelection: Int = 1
    private let bulletSliderSteps: Int = 5
    private var needleBulletsRemaining: Int = 0
    private var dartBulletsRemaining: Int = 0
    private var needleBulletCounterNode: SKNode?
    private var dartBulletCounterNode: SKNode?

    // Options UI label for bullet gravity
    private var bulletGravLabel: SKLabelNode?

    private var sunEnabled: Bool = true
    private var sunAffectsBullets: Bool = true

    private var sunNode: SKShapeNode?
    private let sunCollisionRadius: CGFloat = 28

    // Options UI elements
    private var edgeBounceButton: SKShapeNode?
    private var edgeWrapButton: SKShapeNode?
    private var aiToggleButton: SKShapeNode?
    private var sunToggleButton: SKShapeNode?
    private var bulletGravToggleButton: SKShapeNode?

    // Gravity strength and bullet life options
    private var gravityStrengthStrong: Bool = true
    private var bulletLifeLong: Bool = false
    private var gravityWeakButton: SKShapeNode?
    private var gravityStrongButton: SKShapeNode?
    private var gravityStrengthLabel: SKLabelNode?
    private var bulletLifeShortButton: SKShapeNode?
    private var bulletLifeLongButton: SKShapeNode?
    private var bulletLifeLabel: SKLabelNode?

    // Ships tab: bullet sliders
    // FIX 3: Store slider track nodes directly for reliable hit testing.
    private var needleBulletSliderTrack: SKShapeNode?
    private var dartBulletSliderTrack: SKShapeNode?
    private var needleBulletSliderKnob: SKShapeNode?
    private var dartBulletSliderKnob: SKShapeNode?
    private let sliderTrackWidth: CGFloat = 200
    private let sliderTrackHalfWidth: CGFloat = 100

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
    private var draggingNeedleSliderTouch: UITouch?
    private var draggingDartSliderTouch: UITouch?

    // Ships
    private var needle: Ship!
    private var dart: Ship!

    // Fire button (existing, lower-right)
    private var fireThrustButton: SKShapeNode!

    #if DEBUG
    private var leftFireButtonRef: SKShapeNode?
    #endif

    // Aiming / rotation
    private var aimPoint: CGPoint?
    private let rotationSpeed: CGFloat = .pi * 2
    private let aimEpsilon: CGFloat = 0.01

    // Target indicator
    private var targetIndicator: SKShapeNode!

    // Physics state
    private let thrustAcceleration: CGFloat = 250
    private var maxSpeedNeedle: CGFloat = 400
    private var maxSpeedDart: CGFloat = 400

    // Thrust UI and state
    private var rightThrustButton: SKShapeNode!
    #if DEBUG
    private var leftThrustButton: SKShapeNode!
    #endif
    private var isThrustingNeedle = false
    private var isThrustingDart = false

    // Active touches for thrust
    private var activeRightThrustTouches = Set<UITouch>()
    #if DEBUG
    private var activeLeftThrustTouches = Set<UITouch>()
    #endif

    private struct FireTouchInfo {
        let ship: Ship
        let startTime: TimeInterval
        // FIX 5: Also store the touch-down location so we can validate the tap
        // hasn't drifted far enough to be considered a drag, not a tap.
        let startLocation: CGPoint
        weak var buttonNode: SKNode?
    }
    private var fireTouches: [ObjectIdentifier: FireTouchInfo] = [:]

    private func muzzleOffset(for ship: Ship) -> CGPoint {
        return (ship === needle) ? CGPoint(x: 0, y: 21) : CGPoint(x: 0, y: 16)
    }

    // Missile ownership to avoid immediate self-collisions
    private var missileOwner = NSMapTable<SKNode, SKShapeNode>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    private var missileSpawnTime = NSMapTable<SKNode, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    // Wreckage ownership/piece counts for respawn timing
    private var wreckOwner = NSMapTable<SKNode, SKShapeNode>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    private var wreckPieceCount = NSMapTable<SKNode, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    // MARK: - Layout for current size

    // FIX 1 (continued): layoutForCurrentSize updates spawn positions so that
    // ships always respawn correctly even if the scene size was zero at sceneDidLoad.
    private func layoutForCurrentSize() {
        let s = self.size
        if s.width < 10 || s.height < 10 { return }
        if lastLaidOutSize == s { return }
        lastLaidOutSize = s

        let newNeedleSpawn = CGPoint(x: s.width * 0.20, y: s.height * 0.5)
        let newDartSpawn   = CGPoint(x: s.width * 0.80, y: s.height * 0.5)

        if needle != nil {
            let wasAtOrigin = needle.spawnPosition == .zero || needle.node.position == .zero
            needle.spawnPosition = newNeedleSpawn
            if wasAtOrigin && !needle.node.isHidden {
                needle.node.position = newNeedleSpawn
            }
        }
        if dart != nil {
            let wasAtOrigin = dart.spawnPosition == .zero || dart.node.position == .zero
            dart.spawnPosition = newDartSpawn
            if wasAtOrigin && !dart.node.isHidden {
                dart.node.position = newDartSpawn
            }
        }

        // Reposition HUD/UI that depends on size
        if let fire = fireThrustButton {
            let buttonRadius: CGFloat = 40
            fire.position = CGPoint(x: s.width - buttonRadius - 20, y: buttonRadius + 20)
            if let rightThrust = rightThrustButton {
                let innerRightRadius = buttonRadius * 0.6
                let rightPadding: CGFloat = 12
                rightThrust.position = CGPoint(x: fire.position.x - (buttonRadius + innerRightRadius + rightPadding), y: fire.position.y)
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
            leftFire.position = CGPoint(x: leftButtonRadius + 20, y: leftButtonRadius + 20)
            if let leftThrust = leftThrustButton {
                let innerLeftRadius = leftButtonRadius * 0.6
                let leftPadding: CGFloat = 12
                leftThrust.position = CGPoint(x: leftFire.position.x + (leftButtonRadius + innerLeftRadius + leftPadding), y: leftFire.position.y)
            }
            if let needleCounter = needleBulletCounterNode {
                needleCounter.position = CGPoint(x: leftFire.position.x, y: leftFire.position.y + leftButtonRadius + 20)
            }
            if let leftTitle = leftClusterTitle, let leftThrust = leftThrustButton {
                leftTitle.position = CGPoint(x: (leftFire.position.x + leftThrust.position.x) / 2, y: leftFire.position.y + leftButtonRadius + 50)
            }
        }
        #endif

        needleScoreNode?.position = CGPoint(x: 24, y: s.height - 30)
        dartScoreNode?.position = CGPoint(x: s.width - 24, y: s.height - 30)
        optionsButton?.position = CGPoint(x: s.width / 2, y: s.height - 30)
        optionsOverlay?.position = CGPoint(x: s.width / 2, y: s.height / 2)

        if let dimmer = optionsDimmer {
            dimmer.path = CGPath(rect: CGRect(x: -s.width/2, y: -s.height/2, width: s.width, height: s.height), transform: nil)
            dimmer.position = CGPoint(x: s.width/2, y: s.height/2)
        }

        sunNode?.position = CGPoint(x: s.width/2, y: s.height/2)
    }

    // MARK: - Lifecycle

    override func sceneDidLoad() {
        self.lastUpdateTime = 0
        self.backgroundColor = .black

        // Spawn positions may be (0,0) here if size hasn't been set yet.
        // layoutForCurrentSize() will correct them once a real size is available.
        let needleSpawn = CGPoint(x: size.width * 0.20, y: size.height * 0.5)
        let dartSpawn   = CGPoint(x: size.width * 0.80, y: size.height * 0.5)

        needle = Ship(name: "needle", path: createNeedlePath(), flame: createFlameNode(), spawn: needleSpawn, maxSpeed: maxSpeedNeedle)
        dart   = Ship(name: "dart",   path: createDartPath(),   flame: createFlameNode(), spawn: dartSpawn,   maxSpeed: maxSpeedDart)

        addChild(needle.node)
        addChild(dart.node)

        let nowVisible = CACurrentMediaTime()
        needleVisibleSince = nowVisible
        dartVisibleSince = nowVisible

        // Head dots
        let needleHeadDot = SKShapeNode(circleOfRadius: 8)
        needleHeadDot.fillColor = .white
        needleHeadDot.strokeColor = .clear
        needleHeadDot.position = CGPoint(x: 0, y: 21)
        needleHeadDot.zPosition = 3
        needle.node.addChild(needleHeadDot)

        let dartHeadDot = SKShapeNode(circleOfRadius: 8)
        dartHeadDot.fillColor = .white
        dartHeadDot.strokeColor = .clear
        dartHeadDot.position = CGPoint(x: 0, y: 16)
        dartHeadDot.zPosition = 3
        dart.node.addChild(dartHeadDot)
        dartHeadDot.isHidden = true

        // Firing direction lines
        let needleFiringLinePath = CGMutablePath()
        needleFiringLinePath.move(to: CGPoint(x: 0, y: 21))
        needleFiringLinePath.addLine(to: CGPoint(x: 0, y: 41))
        let needleFiringLine = SKShapeNode(path: needleFiringLinePath)
        needleFiringLine.strokeColor = .white
        needleFiringLine.lineWidth = 1
        needleFiringLine.zPosition = 2
        needle.node.addChild(needleFiringLine)

        let dartFiringLinePath = CGMutablePath()
        dartFiringLinePath.move(to: CGPoint(x: 0, y: 16))
        dartFiringLinePath.addLine(to: CGPoint(x: 0, y: 36))
        let dartFiringLine = SKShapeNode(path: dartFiringLinePath)
        dartFiringLine.strokeColor = .white
        dartFiringLine.lineWidth = 1
        dartFiringLine.zPosition = 2
        dart.node.addChild(dartFiringLine)

        // Fire button (right)
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

        // Right thrust button
        let innerRightRadius = buttonRadius * 0.6
        rightThrustButton = SKShapeNode(circleOfRadius: innerRightRadius)
        let rightPadding: CGFloat = 12
        rightThrustButton.position = CGPoint(
            x: fireThrustButton.position.x - (buttonRadius + innerRightRadius + rightPadding),
            y: fireThrustButton.position.y
        )
        rightThrustButton.strokeColor = .white
        rightThrustButton.lineWidth = 2
        rightThrustButton.fillColor = fireThrustButton.fillColor
        rightThrustButton.zPosition = fireThrustButton.zPosition + 1
        addChild(rightThrustButton)

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

        // Target indicator
        targetIndicator = SKShapeNode(circleOfRadius: 18)
        targetIndicator.fillColor = .clear
        targetIndicator.strokeColor = .lightGray
        targetIndicator.lineWidth = 2
        targetIndicator.zPosition = 50
        targetIndicator.alpha = 0
        addChild(targetIndicator)

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
            let dimmer = SKShapeNode(rectOf: CGSize(width: max(size.width, 1), height: max(size.height, 1)))
            dimmer.position = CGPoint(x: size.width/2, y: size.height/2)
            dimmer.fillColor = SKColor(white: 0.0, alpha: 0.8)
            dimmer.strokeColor = .clear
            dimmer.zPosition = 199
            dimmer.isHidden = true
            addChild(dimmer)
            self.optionsDimmer = dimmer
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

        let innerLeftRadius = leftButtonRadius * 0.6
        leftThrustButton = SKShapeNode(circleOfRadius: innerLeftRadius)
        let leftPadding: CGFloat = 12
        leftThrustButton.position = CGPoint(
            x: leftFireButton.position.x + (leftButtonRadius + innerLeftRadius + leftPadding),
            y: leftFireButton.position.y
        )
        leftThrustButton.strokeColor = .white
        leftThrustButton.lineWidth = 2
        leftThrustButton.fillColor = leftFireButton.fillColor
        leftThrustButton.zPosition = leftFireButton.zPosition + 1
        addChild(leftThrustButton)

        let leftCluster = SKLabelNode(text: "NEEDLE")
        leftCluster.fontName = "AvenirNext-Bold"
        leftCluster.fontSize = 16
        leftCluster.fontColor = .white
        leftCluster.verticalAlignmentMode = .center
        leftCluster.horizontalAlignmentMode = .center
        let leftClusterCenterX = (leftFireButton.position.x + leftThrustButton.position.x) / 2
        leftCluster.position = CGPoint(x: leftClusterCenterX, y: leftFireButton.position.y + leftButtonRadius + 50)
        leftCluster.zPosition = 11
        addChild(leftCluster)
        self.leftClusterTitle = leftCluster
        #endif

        updateNeedleControlsVisibility()
        resetBulletCountsFromSelections()
        refreshBulletCounters()
        endGameIfNoBullets()
        applySunState()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
        layoutForCurrentSize()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForCurrentSize()
    }

    private func updateNeedleControlsVisibility() {
        #if DEBUG
        leftThrustButton?.isHidden = needleAIEnabled
        leftFireButtonRef?.isHidden = needleAIEnabled
        leftClusterTitle?.isHidden = needleAIEnabled
        #endif
    }

    private func setOptionsVisible(_ show: Bool) {
        optionsVisible = show
        optionsOverlay?.isHidden = !show
        optionsDimmer?.isHidden = !show
    }

    // MARK: - Ship Shapes

    private func createNeedlePath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -24))
        path.addLine(to: CGPoint(x: 0, y: 18))
        path.move(to: CGPoint(x: -3, y: -16))
        path.addLine(to: CGPoint(x: 3, y: -16))
        path.move(to: CGPoint(x: -3, y: -8))
        path.addLine(to: CGPoint(x: 3, y: -8))
        path.move(to: CGPoint(x: -4, y: 0))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.move(to: CGPoint(x: -3, y: 8))
        path.addLine(to: CGPoint(x: 3, y: 8))
        return path
    }

    private func createDartPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 16))
        path.addLine(to: CGPoint(x: 14, y: -14))
        path.addLine(to: CGPoint(x: 0, y: -6))
        path.addLine(to: CGPoint(x: -14, y: -14))
        path.addLine(to: CGPoint(x: 0, y: 16))
        return path
    }

    private func createFlameNode() -> SKShapeNode {
        let path = CGMutablePath()
        let tipY: CGFloat = -18
        let baseY: CGFloat = -30
        let halfWidth: CGFloat = 7
        path.move(to: CGPoint(x: 0, y: tipY))
        path.addLine(to: CGPoint(x: -halfWidth, y: baseY))
        path.addLine(to: CGPoint(x: halfWidth, y: baseY))
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
        if angle >= .pi { angle -= twoPi }
        if angle <= -.pi { angle += twoPi }
        return angle
    }

    private func rotateShip(_ shipNode: SKShapeNode, toward worldPoint: CGPoint, dt: TimeInterval) {
        let dx = worldPoint.x - shipNode.position.x
        let dy = worldPoint.y - shipNode.position.y
        let targetAngle = atan2(dy, dx) - .pi / 2

        let currentAngle = shipNode.zRotation
        let angleDiff = shortestAngleBetween(currentAngle, targetAngle)

        if abs(angleDiff) <= aimEpsilon {
            shipNode.zRotation = targetAngle
            return
        }

        let step = rotationSpeed * CGFloat(dt)
        if abs(angleDiff) <= step {
            shipNode.zRotation = targetAngle
        } else {
            shipNode.zRotation += (angleDiff > 0 ? step : -step)
        }
    }

    // MARK: - Missiles

    private func fireMissile(from ship: Ship, muzzleOffset: CGPoint) {
        if ship.node.isHidden { return }
        if gameOver { return }

        if ship === needle {
            if needleBulletsRemaining == 0 { return }
        } else if ship === dart {
            if dartBulletsRemaining == 0 { return }
        }

        let missileSize = CGSize(width: 4, height: 4)
        let missile = SKShapeNode(rectOf: missileSize, cornerRadius: 1)
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

        let velocityMagnitude: CGFloat = 300
        let vx = -velocityMagnitude * sin(angle)
        let vy =  velocityMagnitude * cos(angle)
        missile.userData = ["vx": vx, "vy": vy, "bounced": false]

        missileOwner.setObject(ship.node, forKey: missile)
        missileSpawnTime.setObject(NSNumber(value: CACurrentMediaTime()), forKey: missile)

        let baseLife: TimeInterval = 3.0
        let life = baseLife * (bulletLifeLong ? 2.0 : 1.0)
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

        ship.node.isHidden = true
        ship.velocity = .zero

        guard let path = ship.node.path else { return }
        let pieces = explodePath(path: path, from: ship)

        let lifetime: CGFloat = 2.6
        let ownerNode = ship.node
        wreckPieceCount.setObject(NSNumber(value: pieces.count), forKey: ownerNode)

        for piece in pieces {
            piece.name = "wreckPiece"
            piece.alpha = 1.0

            let ang = CGFloat.random(in: 0..<(2 * .pi))
            let speed = CGFloat.random(in: 60...140)
            let expVX = speed * cos(ang)
            let expVY = speed * sin(ang)
            let vx = originalVelocity.dx + expVX
            let vy = originalVelocity.dy + expVY

            piece.userData = [
                "vx": vx,
                "vy": vy,
                "life": lifetime,
                "maxLife": lifetime
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
                segPath.move(to: lastPoint)
                segPath.addLine(to: end)

                let seg = SKShapeNode(path: segPath)
                seg.strokeColor = .white
                seg.lineWidth = 2
                seg.position = ship.node.position
                seg.zRotation = ship.node.zRotation
                seg.zPosition = ship.node.zPosition
                pieces.append(seg)

                lastPoint = end
            case .closeSubpath:
                break
            default:
                break
            }
        }
        return pieces
    }

    // MARK: - Match control

    private func startNewMatch() {
        needleScore = 0
        dartScore = 0
        updateScoreDisplays()

        // Clear random respawn BEFORE reset so ships go to their fixed spawn positions.
        enableRandomRespawn = false
        needle.reset()
        dart.reset()

        needleVisibleSince = CACurrentMediaTime()
        dartVisibleSince = CACurrentMediaTime()

        resetBulletCountsFromSelections()

        enumerateChildNodes(withName: "missile") { n, _ in n.removeFromParent() }
        enumerateChildNodes(withName: "wreckPiece") { n, _ in n.removeFromParent() }

        gameOver = false
        victorLabelNode?.removeFromParent()
        victorLabelNode = nil
        gameOverLabelNode?.removeFromParent()
        gameOverLabelNode = nil
        refreshOptionsUI()
    }

    // MARK: - Score rendering (vector digits)

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
            0: [0,1,2,3,4,5],
            1: [1,2],
            2: [0,1,6,4,3],
            3: [0,1,6,2,3],
            4: [5,6,1,2],
            5: [0,5,6,2,3],
            6: [0,5,6,2,3,4],
            7: [0,1,2],
            8: [0,1,2,3,4,5,6],
            9: [0,1,2,3,5,6]
        ]

        let path = CGMutablePath()
        for idx in map[digit] ?? [] {
            let (p1, p2) = segments[idx]
            path.move(to: CGPoint(x: p1.x * scale, y: p1.y * scale))
            path.addLine(to: CGPoint(x: p2.x * scale, y: p2.y * scale))
        }

        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.lineWidth = 2
        node.glowWidth = 3
        node.zPosition = 60
        return node
    }

    private func makeScoreNode(score: Int, scale: CGFloat = 1.2, spacing: CGFloat = 12) -> SKNode {
        let container = SKNode()
        let digits = Array(String(score))
        var x: CGFloat = 0

        for ch in digits {
            if let d = Int(String(ch)) {
                let digitNode = createDigitNode(d, scale: scale)
                digitNode.position = CGPoint(x: x, y: 0)
                container.addChild(digitNode)
                x += spacing * scale
            }
        }

        if digits.isEmpty {
            container.addChild(createDigitNode(0, scale: scale))
        }

        return container
    }

    private func updateScoreDisplays() {
        needleScoreNode.removeAllChildren()
        dartScoreNode.removeAllChildren()

        let left = makeScoreNode(score: needleScore)
        let right = makeScoreNode(score: dartScore)

        left.position = .zero
        right.position = CGPoint(x: -right.calculateAccumulatedFrame().width, y: 0)

        needleScoreNode.addChild(left)
        dartScoreNode.addChild(right)
    }

    // MARK: - Bullet counts

    private func bulletsForSelection(_ sel: Int) -> Int? {
        switch sel {
        case 0: return 1
        case 1: return 5
        case 2: return 20
        case 3: return 50
        case 4: return 100
        default: return nil // unlimited
        }
    }

    private func resetBulletCountsFromSelections() {
        needleBulletsRemaining = bulletsForSelection(needleBulletLimitSelection) ?? Int.max
        dartBulletsRemaining = bulletsForSelection(dartBulletLimitSelection) ?? Int.max
        refreshBulletCounters()
    }

    // FIX 4: Render ∞ as a proper figure-eight path instead of two unrelated dots.
    private func makeInfinityNode() -> SKNode {
        let path = CGMutablePath()
        // Two small ellipses side-by-side forming a recognisable ∞ symbol.
        let r: CGFloat = 4
        let gap: CGFloat = 2
        // Left lobe
        path.addEllipse(in: CGRect(x: -(r * 2 + gap), y: -r, width: r * 2, height: r * 2))
        // Right lobe
        path.addEllipse(in: CGRect(x: gap, y: -r, width: r * 2, height: r * 2))

        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.fillColor = .clear
        node.lineWidth = 1.5
        node.glowWidth = 2
        return node
    }

    private func refreshBulletCounters() {
        func setCounter(_ node: SKNode?, count: Int) {
            guard let node else { return }
            node.removeAllChildren()

            let content: SKNode
            if count == Int.max {
                // FIX 4: Use the proper ∞ path node instead of two unconnected dots.
                content = makeInfinityNode()
            } else {
                content = makeScoreNode(score: count, scale: 0.8, spacing: 10)
            }

            node.addChild(content)
        }

        setCounter(dartBulletCounterNode, count: dartBulletsRemaining)
        #if DEBUG
        setCounter(needleBulletCounterNode, count: needleBulletsRemaining)
        #endif
    }

    // FIX 2: Use && so the game ends only when BOTH ships have zero bullets,
    // not when either one runs out.
    private func endGameIfNoBullets() {
        if gameOver { return }
        // Keep playing as long as either ship still has bullets (or unlimited ammo).
        if needleBulletsRemaining == Int.max || dartBulletsRemaining == Int.max { return }
        if needleBulletsRemaining > 0 || dartBulletsRemaining > 0 { return }

        gameOver = true
        isThrustingDart = false
        isThrustingNeedle = false

        // Seed drift AI timers so both ships start wandering immediately.
        let now = CACurrentMediaTime()
        driftNeedleThrustOn = true
        driftDartThrustOn = true
        driftNeedleNextToggle = now + Double.random(in: 0.4...1.0)
        driftDartNextToggle   = now + Double.random(in: 0.4...1.0)
        driftNeedleTargetAngle = CGFloat.random(in: 0...(2 * .pi))
        driftDartTargetAngle   = CGFloat.random(in: 0...(2 * .pi))
        driftNeedleNextTurn = now + Double.random(in: 0.8...2.0)
        driftDartNextTurn   = now + Double.random(in: 0.8...2.0)

        showVictorLabel()
        showGameOverLabel()
    }

    // Returns the total rendered width of a string at the given scale and spacing,
    // using the same advance formula as makeVectorWordNode. Each glyph occupies a
    // 10pt wide cell; n characters produce (n-1) full advances plus one glyph width.
    private func vectorWordWidth(_ text: String, scale: CGFloat, spacing: CGFloat) -> CGFloat {
        let charCount = CGFloat(text.count)
        guard charCount > 0 else { return 0 }
        let advance = (12 + spacing) * scale
        return (charCount - 1) * advance + 10 * scale
    }

    private func showVictorLabel() {
        victorLabelNode?.removeFromParent()

        let word = makeVectorWordNode("VICTOR", scale: 1.0, spacing: 10)
        word.zPosition = 80

        // Place VICTOR centred horizontally beneath the winning score node,
        // in scene coordinates so z-ordering and position are unambiguous.
        let winner: SKNode = (needleScore >= dartScore) ? needleScoreNode : dartScoreNode
        let wordWidth = vectorWordWidth("VICTOR", scale: 1.0, spacing: 10)
        let sceneX = winner.position.x - wordWidth / 2
        let sceneY = winner.position.y - 36
        word.position = CGPoint(x: sceneX, y: sceneY)

        addChild(word)
        victorLabelNode = word
    }

    private func showGameOverLabel() {
        gameOverLabelNode?.removeFromParent()

        let phrase = makeVectorWordNode("GAME OVER", scale: 1.4, spacing: 12)
        phrase.zPosition = 80

        let w = vectorWordWidth("GAME OVER", scale: 1.4, spacing: 12)
        phrase.position = CGPoint(x: size.width / 2 - w / 2, y: size.height * 2 / 3)

        addChild(phrase)
        gameOverLabelNode = phrase
    }

    private func makeVectorWordNode(_ text: String, scale: CGFloat, spacing: CGFloat) -> SKNode {
        // Each letter is decomposed into individual line segments — one SKShapeNode per
        // segment. Where two segments meet, their glow halos overlap and add, making
        // endpoints and intersections visibly brighter, exactly like a vector display.
        let container = SKNode()
        var x: CGFloat = 0

        // Match the ship rendering style exactly: white stroke, lineWidth 2, glowWidth 4.
        // Because every segment is its own SKShapeNode, overlapping glows at shared
        // endpoints and corners add together, producing brighter nodes — the authentic
        // vector display look without any special-casing.
        let beamColor = SKColor.white
        let beamWidth: CGFloat = 2.0
        let beamGlow: CGFloat = 4.0

        func seg(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> SKShapeNode {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
            let s = SKShapeNode(path: p)
            s.strokeColor = beamColor
            s.lineWidth = beamWidth
            s.glowWidth = beamGlow
            s.lineCap = .round
            return s
        }

        // Segments for each letter. Coordinates on a 10×16 grid, origin bottom-left.
        let glyphs: [Character: [(CGFloat,CGFloat,CGFloat,CGFloat)]] = [
            "V": [(0,16, 5,0), (10,16, 5,0)],
            "I": [(5,0, 5,16), (2,16, 8,16), (2,0, 8,0)],
            "C": [(9,14, 6,16), (6,16, 4,16), (4,16, 1,14),
                  (1,14, 1,2),  (1,2,  4,0),  (4,0,  6,0), (6,0, 9,2)],
            "T": [(0,16, 10,16), (5,16, 5,0)],
            "O": [(1,4,  1,12), (1,12, 4,16), (4,16, 6,16), (6,16, 9,12),
                  (9,12, 9,4),  (9,4,  6,0),  (6,0,  4,0),  (4,0,  1,4)],
            "R": [(0,0, 0,16), (0,16, 7,16), (7,16, 9,14), (9,14, 9,11),
                  (9,11, 7,9), (7,9, 0,9),   (4,9, 10,0)],
            "G": [(9,14, 6,16), (6,16, 4,16), (4,16, 1,14),
                  (1,14, 1,2),  (1,2,  4,0),  (4,0,  6,0), (6,0,  9,2),
                  (9,2,  9,8),  (9,8,  6,8)],
            "A": [(0,0, 5,16), (5,16, 10,0), (2,6, 8,6)],
            "M": [(0,0, 0,16), (0,16, 5,8), (5,8, 10,16), (10,16, 10,0)],
            "E": [(9,0, 0,0), (0,0, 0,16), (0,16, 9,16), (0,8, 7,8)],
            " ": [],   // space: no segments, just advances x
        ]

        for ch in text.uppercased() {
            let holder = SKNode()
            holder.position = CGPoint(x: x, y: 0)

            if let segs = glyphs[ch] {
                for (x1,y1,x2,y2) in segs {
                    holder.addChild(seg(x1,y1,x2,y2))
                }
            }
            // Unknown characters: fall through with an empty holder (advances spacing).

            container.addChild(holder)
            x += (12 + spacing) * scale
        }

        container.setScale(scale)
        return container
    }

    // MARK: - Options Overlay

    private func setupOptionsOverlay() {
        let overlay = SKNode()
        overlay.zPosition = 200
        overlay.name = "optionsOverlay"
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)

        let w: CGFloat = min(380, size.width - 40)
        let h: CGFloat = 460

        let bgPath = CGPath(
            roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h),
            cornerWidth: 14, cornerHeight: 14,
            transform: nil
        )
        let bg = SKShapeNode(path: bgPath)
        bg.fillColor = SKColor(white: 0.1, alpha: 0.9)
        bg.strokeColor = .white
        bg.lineWidth = 2
        bg.zPosition = 201
        bg.name = "options_bg"
        overlay.addChild(bg)

        func makeLabel(_ text: String, y: CGFloat, name: String) -> SKLabelNode {
            let label = SKLabelNode(text: text)
            label.name = name
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 16
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: y)
            label.zPosition = 202
            return label
        }

        let tabWidth: CGFloat = (w - 40) / 4
        let tabHeight: CGFloat = 28
        let topPadding: CGFloat = 12
        let tabY = h/2 - topPadding - tabHeight/2

        func makeTab(_ title: String, x: CGFloat, name: String) -> SKShapeNode {
            let tab = SKShapeNode(rectOf: CGSize(width: tabWidth, height: tabHeight), cornerRadius: 6)
            tab.name = name
            tab.position = CGPoint(x: x, y: tabY)
            tab.fillColor = SKColor(white: 0.2, alpha: 0.6)
            tab.strokeColor = .white
            tab.lineWidth = 2
            tab.zPosition = 210

            let label = SKLabelNode(text: title)
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 14
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = .zero
            label.zPosition = 211
            tab.addChild(label)

            overlay.addChild(tab)
            return tab
        }

        let leftX = -w/2 + 20 + tabWidth/2
        gameTabButton    = makeTab("Gameplay",    x: leftX + 0 * tabWidth, name: "tab_game")
        optionsTabButton = makeTab("Physics",     x: leftX + 1 * tabWidth, name: "tab_environment")
        shipsTabButton   = makeTab("Controls",    x: leftX + 2 * tabWidth, name: "tab_ships")
        aboutTabButton   = makeTab("About",       x: leftX + 3 * tabWidth, name: "tab_about")

        // --- Environment content ---
        let screenEdgeLabel = makeLabel("Screen Edge:", y: h/2 - 70, name: "env_label_screen_edge")
        overlay.addChild(screenEdgeLabel)

        let bounceBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        bounceBtn.name = "opt_edge_bounce"
        bounceBtn.position = CGPoint(x: -60, y: h/2 - 105)
        bounceBtn.strokeColor = .white
        bounceBtn.lineWidth = 2
        overlay.addChild(bounceBtn)
        bounceBtn.addChild(makeTabInnerLabel("Bounce"))
        edgeBounceButton = bounceBtn

        let wrapBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        wrapBtn.name = "opt_edge_wrap"
        wrapBtn.position = CGPoint(x: 60, y: h/2 - 105)
        wrapBtn.strokeColor = .white
        wrapBtn.lineWidth = 2
        overlay.addChild(wrapBtn)
        wrapBtn.addChild(makeTabInnerLabel("Wrap"))
        edgeWrapButton = wrapBtn

        let sunLabel = makeLabel("Sun at Center:", y: h/2 - 170, name: "env_label_sun")
        overlay.addChild(sunLabel)

        let sunBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        sunBtn.name = "opt_sun_toggle"
        sunBtn.position = CGPoint(x: 0, y: h/2 - 205)
        sunBtn.strokeColor = .white
        sunBtn.lineWidth = 2
        overlay.addChild(sunBtn)
        sunToggleButton = sunBtn

        let bulletLbl = SKLabelNode(text: "Affects Bullets")
        bulletLbl.name = "env_label_affects"
        bulletLbl.fontName = "AvenirNext-Bold"
        bulletLbl.fontSize = 14
        bulletLbl.fontColor = .white
        bulletLbl.verticalAlignmentMode = .center
        bulletLbl.horizontalAlignmentMode = .center
        bulletLbl.position = CGPoint(x: 0, y: h/2 - 270)
        bulletLbl.zPosition = 203
        overlay.addChild(bulletLbl)
        bulletGravLabel = bulletLbl

        let bulletBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        bulletBtn.name = "opt_bullet_grav_toggle"
        bulletBtn.position = CGPoint(x: 0, y: h/2 - 315)
        bulletBtn.strokeColor = .white
        bulletBtn.lineWidth = 2
        overlay.addChild(bulletBtn)
        bulletGravToggleButton = bulletBtn

        let gravityHeading = makeLabel("Gravity", y: h/2 - 270, name: "env_label_gravity")
        overlay.addChild(gravityHeading)

        let gravLabel = SKLabelNode(text: "Strength")
        gravLabel.name = "env_label_strength"
        gravLabel.fontName = "AvenirNext-Bold"
        gravLabel.fontSize = 14
        gravLabel.fontColor = .white
        gravLabel.position = CGPoint(x: 0, y: h/2 - 365)
        gravLabel.zPosition = 202
        overlay.addChild(gravLabel)
        gravityStrengthLabel = gravLabel

        let gravWeak = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        gravWeak.name = "opt_grav_weak"
        gravWeak.position = CGPoint(x: -60, y: h/2 - 395)
        gravWeak.strokeColor = .white
        gravWeak.lineWidth = 2
        overlay.addChild(gravWeak)
        gravWeak.addChild(makeTabInnerLabel("Weak"))
        gravityWeakButton = gravWeak

        let gravStrong = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        gravStrong.name = "opt_grav_strong"
        gravStrong.position = CGPoint(x: 60, y: h/2 - 395)
        gravStrong.strokeColor = .white
        gravStrong.lineWidth = 2
        overlay.addChild(gravStrong)
        gravStrong.addChild(makeTabInnerLabel("Strong"))
        gravityStrongButton = gravStrong

        let gravityGroupRect = CGRect(x: -130, y: h/2 - 420, width: 260, height: 170)
        let gravityGroup = SKShapeNode(rect: gravityGroupRect, cornerRadius: 8)
        gravityGroup.name = "env_gravity_group"
        gravityGroup.strokeColor = SKColor(white: 1.0, alpha: 0.6)
        gravityGroup.lineWidth = 1
        gravityGroup.fillColor = .clear
        gravityGroup.zPosition = 201.5
        overlay.addChild(gravityGroup)

        // --- Ships/Controls content ---
        let lifeLabel = makeLabel("Bullet Life:", y: -h/2 + 80, name: "ships_label_bullet_life")
        overlay.addChild(lifeLabel)
        bulletLifeLabel = lifeLabel

        let lifeShort = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        lifeShort.name = "opt_bullet_short"
        lifeShort.position = CGPoint(x: -60, y: -h/2 + 50)
        lifeShort.strokeColor = .white
        lifeShort.lineWidth = 2
        overlay.addChild(lifeShort)
        lifeShort.addChild(makeTabInnerLabel("Short"))
        bulletLifeShortButton = lifeShort

        let lifeLong = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        lifeLong.name = "opt_bullet_long"
        lifeLong.position = CGPoint(x: 60, y: -h/2 + 50)
        lifeLong.strokeColor = .white
        lifeLong.lineWidth = 2
        overlay.addChild(lifeLong)
        lifeLong.addChild(makeTabInnerLabel("Long"))
        bulletLifeLongButton = lifeLong

        let bulletsTitle = makeLabel("Number of Bullets", y: 10, name: "ships_label_bullets")
        overlay.addChild(bulletsTitle)

        // FIX 3: Build sliders as flat nodes directly in the overlay coordinate space.
        // Store references to the track and knob nodes directly rather than relying
        // on nested container hit testing, which was unreliable.
        func makeSlider(trackY: CGFloat, namePrefix: String) {
            let track = SKShapeNode(rectOf: CGSize(width: sliderTrackWidth, height: 4), cornerRadius: 2)
            track.strokeColor = .white
            track.fillColor = .white
            track.alpha = 1.0
            track.position = CGPoint(x: 0, y: trackY)
            track.name = namePrefix + "track"
            track.zPosition = 202
            overlay.addChild(track)

            for i in 0...bulletSliderSteps {
                let x = -sliderTrackHalfWidth + CGFloat(i) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
                let tick = SKShapeNode(circleOfRadius: 3)
                tick.position = CGPoint(x: x, y: trackY)
                tick.fillColor = .white
                tick.strokeColor = .white
                tick.alpha = 0.9
                tick.name = namePrefix + "tick_\(i)"
                tick.zPosition = 203
                overlay.addChild(tick)
            }

            let knob = SKShapeNode(circleOfRadius: 8)
            knob.strokeColor = .white
            knob.fillColor = SKColor(white: 0.2, alpha: 0.8)
            knob.lineWidth = 2
            knob.position = CGPoint(x: -sliderTrackHalfWidth, y: trackY)
            knob.name = namePrefix + "knob"
            knob.zPosition = 204
            overlay.addChild(knob)

            if namePrefix.contains("needle") {
                needleBulletSliderTrack = track
                needleBulletSliderKnob = knob
            } else {
                dartBulletSliderTrack = track
                dartBulletSliderKnob = knob
            }
        }

        let bulletsY: CGFloat = -20
        makeSlider(trackY: bulletsY,      namePrefix: "opt_bullets_dart_")
        makeSlider(trackY: bulletsY - 40, namePrefix: "opt_bullets_needle_")

        // Row labels for sliders
        let wedgeSliderLabel = SKLabelNode(text: "Wedge")
        wedgeSliderLabel.fontName = "AvenirNext-Bold"
        wedgeSliderLabel.fontSize = 16
        wedgeSliderLabel.fontColor = .white
        wedgeSliderLabel.horizontalAlignmentMode = .left
        wedgeSliderLabel.verticalAlignmentMode = .center
        wedgeSliderLabel.position = CGPoint(x: -w/2 + 20, y: bulletsY)
        wedgeSliderLabel.name = "ships_label_row_wedge"
        wedgeSliderLabel.zPosition = 202
        overlay.addChild(wedgeSliderLabel)

        let needleSliderLabel = SKLabelNode(text: "Needle")
        needleSliderLabel.fontName = "AvenirNext-Bold"
        needleSliderLabel.fontSize = 16
        needleSliderLabel.fontColor = .white
        needleSliderLabel.horizontalAlignmentMode = .left
        needleSliderLabel.verticalAlignmentMode = .center
        needleSliderLabel.position = CGPoint(x: -w/2 + 20, y: bulletsY - 40)
        needleSliderLabel.name = "ships_label_row_needle"
        needleSliderLabel.zPosition = 202
        overlay.addChild(needleSliderLabel)

        // --- Game tab content ---
        let newMatchBtn = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 8)
        newMatchBtn.name = "game_new_match"
        newMatchBtn.position = CGPoint(x: 0, y: h/2 - 160)
        newMatchBtn.strokeColor = .white
        newMatchBtn.lineWidth = 2
        overlay.addChild(newMatchBtn)
        newMatchBtn.addChild(makeTabInnerLabel("New Match", fontSize: 16))

        let aimLabel = makeLabel("Aim Persists:", y: h/2 - 220, name: "game_label_aim_persist")
        overlay.addChild(aimLabel)

        let aimBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aimBtn.name = "game_aim_persist_toggle"
        aimBtn.position = CGPoint(x: 0, y: h/2 - 250)
        aimBtn.strokeColor = .white
        aimBtn.lineWidth = 2
        aimBtn.zPosition = 202
        overlay.addChild(aimBtn)
        aimPersistToggleButton = aimBtn

        let aiLabel = makeLabel("Needle AI:", y: h/2 - 300, name: "game_label_ai")
        overlay.addChild(aiLabel)

        let aiBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aiBtn.name = "game_ai_toggle"
        aiBtn.position = CGPoint(x: 0, y: h/2 - 330)
        aiBtn.strokeColor = .white
        aiBtn.lineWidth = 2
        aiBtn.zPosition = 202
        overlay.addChild(aiBtn)
        aiToggleButton = aiBtn

        // --- About tab content ---
        let about = SKNode()
        about.zPosition = 202
        about.isHidden = true

        let title = SKLabelNode(text: "SpaceWar 2062")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 22
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 40)
        about.addChild(title)

        let copy = SKLabelNode(text: "© 2026 Michael Stern")
        copy.fontName = "AvenirNext-Medium"
        copy.fontSize = 12
        copy.fontColor = .white
        copy.position = CGPoint(x: 0, y: -h/2 + 20)
        about.addChild(copy)

        overlay.addChild(about)
        aboutContainer = about

        optionsOverlay = overlay
        addChild(overlay)

        refreshOptionsUI()
        setOptionsTab(.environment)
    }

    private func makeTabInnerLabel(_ text: String, fontSize: CGFloat = 14) -> SKLabelNode {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "AvenirNext-Bold"
        lbl.fontSize = fontSize
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.position = .zero
        lbl.zPosition = 203
        return lbl
    }

    // FIX 3 (continued): sliderIndexForOverlayX converts a raw overlay-space X
    // coordinate to the nearest step index, used by both touch began and moved.
    private func sliderIndexForOverlayX(_ x: CGFloat) -> Int {
        let step = sliderTrackWidth / CGFloat(bulletSliderSteps)
        var idx = Int(round((x + sliderTrackHalfWidth) / step))
        return max(0, min(bulletSliderSteps, idx))
    }

    // FIX 3 (continued): Check whether a touch is within the interactive area of
    // a slider track (padded by 20pt vertically so it's easy to hit).
    private func touchIsOnSlider(track: SKShapeNode?, locInOverlay: CGPoint) -> Bool {
        guard let track else { return false }
        let ty = track.position.y
        let inX = locInOverlay.x >= (-sliderTrackHalfWidth - 20) && locInOverlay.x <= (sliderTrackHalfWidth + 20)
        let inY = abs(locInOverlay.y - ty) <= 20
        return inX && inY
    }

    private func refreshOptionsUI() {
        let selFill = SKColor.white
        let offFill = SKColor(white: 0.2, alpha: 0.6)
        let selText = SKColor.black
        let offText = SKColor.white

        let gamePrefixes  = ["game_"]
        let envPrefixes   = ["opt_edge_", "opt_sun_toggle", "opt_bullet_grav_toggle", "opt_grav_", "env_label_", "env_gravity_group"]
        let shipsPrefixes = ["ships_label_", "opt_bullet_short", "opt_bullet_long", "opt_bullets_"]

        optionsOverlay?.children.forEach { node in
            if node.name == "options_bg" { return }
            if node === gameTabButton || node === optionsTabButton || node === shipsTabButton || node === aboutTabButton || node === aboutContainer { return }

            let name = node.name ?? ""

            switch currentOptionsTab {
            case .environment:
                node.isHidden = !envPrefixes.contains(where: { name.hasPrefix($0) })
            case .ships:
                node.isHidden = !shipsPrefixes.contains(where: { name.hasPrefix($0) })
            case .game:
                node.isHidden = !gamePrefixes.contains(where: { name.hasPrefix($0) })
            case .about:
                node.isHidden = true
            }
        }

        aboutContainer?.isHidden = (currentOptionsTab != .about)

        func setTab(_ tabNode: SKShapeNode?, selected: Bool) {
            guard let tabNode,
                  let lbl = tabNode.children.compactMap({ $0 as? SKLabelNode }).first else { return }
            tabNode.fillColor = selected ? .white : offFill
            lbl.fontColor = selected ? .black : .white
        }

        setTab(gameTabButton,    selected: currentOptionsTab == .game)
        setTab(optionsTabButton, selected: currentOptionsTab == .environment)
        setTab(shipsTabButton,   selected: currentOptionsTab == .ships)
        setTab(aboutTabButton,   selected: currentOptionsTab == .about)

        if let bounce = edgeBounceButton {
            let selected = edgeBehavior == .bounce
            bounce.fillColor = selected ? selFill : offFill
            if let lbl = bounce.children.compactMap({ $0 as? SKLabelNode }).first { lbl.fontColor = selected ? selText : offText }
        }
        if let wrap = edgeWrapButton {
            let selected = edgeBehavior == .wrap
            wrap.fillColor = selected ? selFill : offFill
            if let lbl = wrap.children.compactMap({ $0 as? SKLabelNode }).first { lbl.fontColor = selected ? selText : offText }
        }

        aiToggleButton?.fillColor = needleAIEnabled ? selFill : offFill
        sunToggleButton?.fillColor = sunEnabled ? selFill : offFill
        bulletGravToggleButton?.fillColor = sunAffectsBullets ? selFill : offFill
        aimPersistToggleButton?.fillColor = aimPersistsAfterLift ? selFill : offFill

        let sunEnabledNow = sunEnabled
        func setEnabled(_ node: SKNode?, enabled: Bool) { node?.alpha = enabled ? 1.0 : 0.5 }
        setEnabled(bulletGravToggleButton, enabled: sunEnabledNow)
        bulletGravLabel?.alpha = sunEnabledNow ? 1.0 : 0.5
        gravityStrengthLabel?.alpha = sunEnabledNow ? 1.0 : 0.5
        setEnabled(gravityWeakButton, enabled: sunEnabledNow)
        setEnabled(gravityStrongButton, enabled: sunEnabledNow)

        if let weak = gravityWeakButton {
            let selected = !gravityStrengthStrong
            weak.fillColor = selected ? selFill : offFill
            if let lbl = weak.children.compactMap({ $0 as? SKLabelNode }).first { lbl.fontColor = selected ? selText : offText }
        }
        if let strong = gravityStrongButton {
            let selected = gravityStrengthStrong
            strong.fillColor = selected ? selFill : offFill
            if let lbl = strong.children.compactMap({ $0 as? SKLabelNode }).first { lbl.fontColor = selected ? selText : offText }
        }

        if let short = bulletLifeShortButton {
            let selected = !bulletLifeLong
            short.fillColor = selected ? selFill : offFill
            if let lbl = short.children.compactMap({ $0 as? SKLabelNode }).first { lbl.fontColor = selected ? selText : offText }
        }
        if let long = bulletLifeLongButton {
            let selected = bulletLifeLong
            long.fillColor = selected ? selFill : offFill
            if let lbl = long.children.compactMap({ $0 as? SKLabelNode }).first { lbl.fontColor = selected ? selText : offText }
        }

        // FIX 3 (continued): Position knobs directly by stored reference rather
        // than hunting through a node hierarchy with childNode(withName:).
        if let knob = needleBulletSliderKnob, let track = needleBulletSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(needleBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
        }
        if let knob = dartBulletSliderKnob, let track = dartBulletSliderTrack {
            let x = -sliderTrackHalfWidth + CGFloat(dartBulletLimitSelection) * (sliderTrackWidth / CGFloat(bulletSliderSteps))
            knob.position = CGPoint(x: x, y: track.position.y)
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
                star.strokeColor = .yellow
                star.fillColor = .clear
                star.lineWidth = 1
                star.glowWidth = 0
                star.position = CGPoint(x: size.width/2, y: size.height/2)
                star.zPosition = 5
                star.name = "sun"

                let twinkle = SKAction.repeatForever(.sequence([
                    .group([.scale(to: 1.15, duration: 0.25), .fadeAlpha(to: 0.9, duration: 0.25)]),
                    .group([.scale(to: 1.0,  duration: 0.3),  .fadeAlpha(to: 1.0, duration: 0.3)])
                ]))
                star.run(twinkle)

                addChild(star)
                sunNode = star
            }
        } else {
            sunNode?.removeFromParent()
            sunNode = nil
        }
    }

    private func safeRandomPosition(avoiding ship: Ship) -> CGPoint? {
        let attempts = 100
        let inset: CGFloat = 20
        let minX = inset, maxX = size.width - inset
        let minY = inset, maxY = size.height - inset

        let otherShip: Ship = (ship === needle) ? dart! : needle!

        for _ in 0..<attempts {
            let x = CGFloat.random(in: minX...maxX)
            let y = CGFloat.random(in: minY...maxY)
            let p = CGPoint(x: x, y: y)

            if !otherShip.node.isHidden {
                let testFrame = otherShip.node.frame.insetBy(dx: -20, dy: -20)
                if testFrame.contains(p) { continue }
            }

            var tooCloseToMissile = false
            enumerateChildNodes(withName: "missile") { node, stop in
                let dx = node.position.x - p.x
                let dy = node.position.y - p.y
                if (dx*dx + dy*dy) < (40*40) {
                    tooCloseToMissile = true
                    stop.pointee = true
                }
            }
            if tooCloseToMissile { continue }

            if let sun = sunNode {
                let dxs = sun.position.x - p.x
                let dys = sun.position.y - p.y
                let minR = sunCollisionRadius + 80
                if (dxs*dxs + dys*dys) < minR*minR { continue }
            }

            return p
        }
        return nil
    }

    private func respawnShip(_ ship: Ship) {
        let pos: CGPoint
        if enableRandomRespawn, let p = safeRandomPosition(avoiding: ship) {
            pos = p
        } else {
            pos = ship.spawnPosition
        }
        ship.node.position = pos
        ship.node.zRotation = 0
        ship.velocity = .zero
        ship.node.isHidden = false
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime

        if optionsVisible {
            targetIndicator.alpha = 0
            lastUpdateTime = currentTime
            return
        }

        for entity in entities {
            entity.update(deltaTime: dt)
        }

        if gameOver {
            // Controls are disabled; ships wander with random thrust and heading.
            let driftAccel: CGFloat = thrustAcceleration * 0.6

            if !needle.node.isHidden {
                if currentTime >= driftNeedleNextToggle {
                    driftNeedleThrustOn.toggle()
                    driftNeedleNextToggle = currentTime + Double.random(in: 0.3...1.0)
                }
                if currentTime >= driftNeedleNextTurn {
                    driftNeedleTargetAngle = CGFloat.random(in: 0...(2 * .pi))
                    driftNeedleNextTurn = currentTime + Double.random(in: 0.6...1.8)
                }
                let nx = needle.node.position.x + sin(driftNeedleTargetAngle) * 100
                let ny = needle.node.position.y + cos(driftNeedleTargetAngle) * 100
                rotateShip(needle.node, toward: CGPoint(x: nx, y: ny), dt: dt)
                if driftNeedleThrustOn {
                    needle.applyThrust(accel: driftAccel, dt: CGFloat(dt))
                    needle.flame.alpha = 1
                } else {
                    needle.flame.alpha = 0
                }
            }

            if !dart.node.isHidden {
                if currentTime >= driftDartNextToggle {
                    driftDartThrustOn.toggle()
                    driftDartNextToggle = currentTime + Double.random(in: 0.3...1.0)
                }
                if currentTime >= driftDartNextTurn {
                    driftDartTargetAngle = CGFloat.random(in: 0...(2 * .pi))
                    driftDartNextTurn = currentTime + Double.random(in: 0.6...1.8)
                }
                let dx2 = dart.node.position.x + sin(driftDartTargetAngle) * 100
                let dy2 = dart.node.position.y + cos(driftDartTargetAngle) * 100
                rotateShip(dart.node, toward: CGPoint(x: dx2, y: dy2), dt: dt)
                if driftDartThrustOn {
                    dart.applyThrust(accel: driftAccel, dt: CGFloat(dt))
                    dart.flame.alpha = 1
                } else {
                    dart.flame.alpha = 0
                }
            }
        } else {
        // Normal play: rotate toward aim, run needle AI, apply player thrust.

        var anyAim = false

        if !needle.node.isHidden {
            if needleAIEnabled {
                if let sun = sunNode {
                    let dxs = sun.position.x - needle.node.position.x
                    let dys = sun.position.y - needle.node.position.y
                    let dist2 = dxs*dxs + dys*dys

                    let vx = needle.velocity.dx
                    let vy = needle.velocity.dy
                    let vmag = sqrt(vx*vx + vy*vy)
                    if vmag > 1 {
                        let invR = 1.0 / sqrt(dist2)
                        let ux = dxs * invR
                        let uy = dys * invR
                        let dot = (vx*ux + vy*uy)
                        let cross = abs(dxs*vy - dys*vx)
                        let b = cross / vmag
                        if dot > 0 && b < (sunCollisionRadius + 60) {
                            let awayPoint = CGPoint(x: needle.node.position.x - dxs, y: needle.node.position.y - dys)
                            rotateShip(needle.node, toward: awayPoint, dt: dt)
                            anyAim = true
                        }
                    }

                    let avoidRadius2: CGFloat = 140.0 * 140.0
                    if dist2 < avoidRadius2 {
                        let awayPoint = CGPoint(x: needle.node.position.x - dxs, y: needle.node.position.y - dys)
                        rotateShip(needle.node, toward: awayPoint, dt: dt)
                        anyAim = true
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
                                y: needle.node.position.y - (nearestMissilePos.y - needle.node.position.y)
                            )
                            rotateShip(needle.node, toward: awayPoint, dt: dt)
                            anyAim = true
                        } else {
                            if !dart.node.isHidden {
                                let dxw = dart.node.position.x - needle.node.position.x
                                let dyw = dart.node.position.y - needle.node.position.y
                                let d2w = dxw*dxw + dyw*dyw
                                let avoidWedgeR: CGFloat = 90
                                if d2w < avoidWedgeR*avoidWedgeR {
                                    let awayPoint = CGPoint(x: needle.node.position.x - dxw, y: needle.node.position.y - dyw)
                                    rotateShip(needle.node, toward: awayPoint, dt: dt)
                                    anyAim = true
                                } else {
                                    rotateShip(needle.node, toward: dart.node.position, dt: dt)
                                    anyAim = true
                                }
                            } else {
                                rotateShip(needle.node, toward: dart.node.position, dt: dt)
                                anyAim = true
                            }
                        }
                    }
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
                            y: needle.node.position.y - (nearestMissilePos.y - needle.node.position.y)
                        )
                        rotateShip(needle.node, toward: awayPoint, dt: dt)
                        anyAim = true
                    } else {
                        rotateShip(needle.node, toward: dart.node.position, dt: dt)
                        anyAim = true
                    }
                }
            } else if let p = aimPoint {
                rotateShip(needle.node, toward: p, dt: dt)
                anyAim = true
            }
        }

        if !dart.node.isHidden, let p = aimPoint {
            rotateShip(dart.node, toward: p, dt: dt)
            anyAim = true
        }

        if let p = aimPoint, anyAim {
            targetIndicator.position = p
            targetIndicator.alpha = 0.7
        } else {
            targetIndicator.alpha = 0
        }

        if needleAIEnabled && !needle.node.isHidden {
            if currentTime >= aiNextThrustToggle {
                aiThrustOn.toggle()
                let interval = aiThrustOn ? Double.random(in: 0.3...0.8) : Double.random(in: 0.4...1.2)
                aiNextThrustToggle = currentTime + interval
            }
            isThrustingNeedle = aiThrustOn

            if currentTime >= aiNextFireTime && !dart.node.isHidden && (currentTime - dartVisibleSince) >= 1.0 {
                fireMissile(from: needle, muzzleOffset: muzzleOffset(for: needle))
                aiNextFireTime = currentTime + Double.random(in: 0.9...2.0)
            }
        }

        if isThrustingDart {
            dart.applyThrust(accel: thrustAcceleration, dt: CGFloat(dt))
            dart.flame.alpha = 1
        } else {
            dart.flame.alpha = 0
        }

        if isThrustingNeedle {
            needle.applyThrust(accel: thrustAcceleration, dt: CGFloat(dt))
            needle.flame.alpha = 1
        } else {
            needle.flame.alpha = 0
        }

        } // end else (normal play)

        if sunEnabled, let sun = sunNode {
            func applyGravity(to ship: Ship) {
                let dx = sun.position.x - ship.node.position.x
                let dy = sun.position.y - ship.node.position.y
                let r2 = dx*dx + dy*dy + 100
                let invR = 1.0 / sqrt(r2)
                let ux = dx * invR
                let uy = dy * invR
                let baseG: CGFloat = 18000
                let G: CGFloat = baseG * (gravityStrengthStrong ? 8.0 : 2.0)
                let a = G / r2
                ship.velocity.dx += ux * a * CGFloat(dt)
                ship.velocity.dy += uy * a * CGFloat(dt)
            }
            if !needle.node.isHidden { applyGravity(to: needle) }
            if !dart.node.isHidden { applyGravity(to: dart) }

            if sunAffectsBullets {
                enumerateChildNodes(withName: "missile") { node, _ in
                    guard let data = node.userData,
                          var vx = data["vx"] as? CGFloat,
                          var vy = data["vy"] as? CGFloat else { return }

                    let dx = sun.position.x - node.position.x
                    let dy = sun.position.y - node.position.y
                    let r2 = dx*dx + dy*dy + 100
                    let invR = 1.0 / sqrt(r2)
                    let ux = dx * invR
                    let uy = dy * invR
                    let baseG: CGFloat = 18000
                    let G: CGFloat = baseG * (self.gravityStrengthStrong ? 5.0 : 1.0)
                    let a = G / r2

                    vx += ux * a * CGFloat(dt)
                    vy += uy * a * CGFloat(dt)

                    node.userData?["vx"] = vx
                    node.userData?["vy"] = vy
                }
            }
        }

        dart.clampSpeed()
        needle.clampSpeed()
        dart.integrate(dt: CGFloat(dt))
        needle.integrate(dt: CGFloat(dt))

        func handleEdges(_ ship: Ship) {
            var pos = ship.node.position
            let minX: CGFloat = 0, maxX: CGFloat = size.width
            let minY: CGFloat = 0, maxY: CGFloat = size.height

            switch edgeBehavior {
            case .bounce:
                var bounced = false
                if pos.x < minX { pos.x = minX; ship.velocity.dx =  abs(ship.velocity.dx); bounced = true }
                if pos.x > maxX { pos.x = maxX; ship.velocity.dx = -abs(ship.velocity.dx); bounced = true }
                if pos.y < minY { pos.y = minY; ship.velocity.dy =  abs(ship.velocity.dy); bounced = true }
                if pos.y > maxY { pos.y = maxY; ship.velocity.dy = -abs(ship.velocity.dy); bounced = true }
                if bounced { ship.node.position = pos; ship.alignRotationToVelocityIfMoving() }
            case .wrap:
                if pos.x < minX { pos.x = maxX }
                if pos.x > maxX { pos.x = minX }
                if pos.y < minY { pos.y = maxY }
                if pos.y > maxY { pos.y = minY }
                ship.node.position = pos
            }
        }
        handleEdges(dart)
        handleEdges(needle)

        enumerateChildNodes(withName: "missile") { node, _ in
            guard let data = node.userData,
                  var vx = data["vx"] as? CGFloat,
                  var vy = data["vy"] as? CGFloat else { return }

            node.position.x += vx * CGFloat(dt)
            node.position.y += vy * CGFloat(dt)

            switch self.edgeBehavior {
            case .bounce:
                var bounced = false
                if node.position.x < 0 { node.position.x = 0; vx =  abs(vx); bounced = true }
                if node.position.x > self.size.width  { node.position.x = self.size.width;  vx = -abs(vx); bounced = true }
                if node.position.y < 0 { node.position.y = 0; vy =  abs(vy); bounced = true }
                if node.position.y > self.size.height { node.position.y = self.size.height; vy = -abs(vy); bounced = true }
                if bounced {
                    node.userData?["vx"] = vx
                    node.userData?["vy"] = vy
                    node.userData?["bounced"] = true
                }
            case .wrap:
                if node.position.x < 0 { node.position.x = self.size.width }
                if node.position.x > self.size.width  { node.position.x = 0 }
                if node.position.y < 0 { node.position.y = self.size.height }
                if node.position.y > self.size.height { node.position.y = 0 }
            }
        }

        enumerateChildNodes(withName: "wreckPiece") { node, _ in
            guard let data = node.userData,
                  var vx = data["vx"] as? CGFloat,
                  var vy = data["vy"] as? CGFloat,
                  var life = data["life"] as? CGFloat,
                  let maxLife = data["maxLife"] as? CGFloat else { return }

            node.position.x += vx * CGFloat(dt)
            node.position.y += vy * CGFloat(dt)

            switch self.edgeBehavior {
            case .bounce:
                var bounced = false
                if node.position.x < 0 { node.position.x = 0; vx =  abs(vx); bounced = true }
                if node.position.x > self.size.width  { node.position.x = self.size.width;  vx = -abs(vx); bounced = true }
                if node.position.y < 0 { node.position.y = 0; vy =  abs(vy); bounced = true }
                if node.position.y > self.size.height { node.position.y = self.size.height; vy = -abs(vy); bounced = true }
                if bounced { node.userData?["vx"] = vx; node.userData?["vy"] = vy }
            case .wrap:
                if node.position.x < 0 { node.position.x = self.size.width }
                if node.position.x > self.size.width  { node.position.x = 0 }
                if node.position.y < 0 { node.position.y = self.size.height }
                if node.position.y > self.size.height { node.position.y = 0 }
            }

            life -= CGFloat(dt)
            node.userData?["life"] = life
            node.alpha = max(0.0, life / maxLife)

            if life <= 0 {
                if let owner = self.wreckOwner.object(forKey: node) {
                    let current = self.wreckPieceCount.object(forKey: owner)?.intValue ?? 0
                    let newCount = max(0, current - 1)
                    self.wreckPieceCount.setObject(NSNumber(value: newCount), forKey: owner)
                    if newCount == 0 {
                        self.enableRandomRespawn = true
                        if owner === self.needle.node {
                            self.respawnShip(self.needle)
                            self.needleVisibleSince = currentTime
                        } else if owner === self.dart.node {
                            self.respawnShip(self.dart)
                            self.dartVisibleSince = currentTime
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
                if (bdx*bdx + bdy*bdy) <= self.sunCollisionRadius * self.sunCollisionRadius {
                    node.removeFromParent()
                }
            }

            if !needle.node.isHidden {
                let dx = needle.node.position.x - sun.position.x
                let dy = needle.node.position.y - sun.position.y
                if (dx*dx + dy*dy) <= sunCollisionRadius*sunCollisionRadius {
                    dartScore += 1
                    updateScoreDisplays()
                    explodeShip(ship: needle)
                }
            }
            if !dart.node.isHidden {
                let dx = dart.node.position.x - sun.position.x
                let dy = dart.node.position.y - sun.position.y
                if (dx*dx + dy*dy) <= sunCollisionRadius*sunCollisionRadius {
                    needleScore += 1
                    updateScoreDisplays()
                    explodeShip(ship: dart)
                }
            }
        }

        var needleHit = false
        var dartHit = false
        let now = CACurrentMediaTime()

        enumerateChildNodes(withName: "missile") { node, _ in
            let owner = self.missileOwner.object(forKey: node)
            let spawn = (self.missileSpawnTime.object(forKey: node) as? NSNumber)?.doubleValue ?? 0
            let bounced = (node.userData?["bounced"] as? Bool) ?? false
            let grace = (!bounced) && (now - spawn < 1.0)

            if !needleHit && !self.needle.node.isHidden && node.frame.intersects(self.needle.node.frame) && !(owner === self.needle.node && grace) {
                needleHit = true
                node.removeFromParent()
            }
            if !dartHit && !self.dart.node.isHidden && node.frame.intersects(self.dart.node.frame) && !(owner === self.dart.node && grace) {
                dartHit = true
                node.removeFromParent()
            }
        }

        if needleHit {
            dartScore += 1
            updateScoreDisplays()
            explodeShip(ship: needle)
        }
        if dartHit {
            needleScore += 1
            updateScoreDisplays()
            explodeShip(ship: dart)
        }

        if !needle.node.isHidden && !dart.node.isHidden && needle.node.frame.intersects(dart.node.frame) {
            needleScore += 1
            dartScore += 1
            updateScoreDisplays()
            explodeShip(ship: needle)
            explodeShip(ship: dart)
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
                    setOptionsVisible(false)
                    continue
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
                } else if let btn = aimPersistToggleButton, btn.contains(locInOverlay) {
                    aimPersistsAfterLift.toggle()
                    refreshOptionsUI()
                    handled = true
                }
                if handled { continue }

                if let btn = edgeBounceButton, btn.contains(locInOverlay) {
                    edgeBehavior = .bounce; refreshOptionsUI(); handled = true
                } else if let btn = edgeWrapButton, btn.contains(locInOverlay) {
                    edgeBehavior = .wrap; refreshOptionsUI(); handled = true
                } else if let btn = aiToggleButton, btn.contains(locInOverlay) {
                    needleAIEnabled.toggle()
                    aiNextThrustToggle = 0; aiNextFireTime = 0; aiThrustOn = false
                    updateNeedleControlsVisibility()
                    refreshOptionsUI()
                    handled = true
                } else if let btn = sunToggleButton, btn.contains(locInOverlay) {
                    sunEnabled.toggle(); applySunState(); refreshOptionsUI(); handled = true
                } else if let btn = bulletGravToggleButton, btn.contains(locInOverlay), sunEnabled {
                    sunAffectsBullets.toggle(); refreshOptionsUI(); handled = true
                } else if let btn = gravityWeakButton, btn.contains(locInOverlay), sunEnabled {
                    gravityStrengthStrong = false; refreshOptionsUI(); handled = true
                } else if let btn = gravityStrongButton, btn.contains(locInOverlay), sunEnabled {
                    gravityStrengthStrong = true; refreshOptionsUI(); handled = true
                } else if let btn = bulletLifeShortButton, btn.contains(locInOverlay) {
                    bulletLifeLong = false; refreshOptionsUI(); handled = true
                } else if let btn = bulletLifeLongButton, btn.contains(locInOverlay) {
                    bulletLifeLong = true; refreshOptionsUI(); handled = true
                } else if let btn = overlay.childNode(withName: "game_new_match") as? SKShapeNode, btn.contains(locInOverlay) {
                    startNewMatch(); handled = true
                }

                // FIX 3 (continued): Use touchIsOnSlider() with the stored track node
                // for reliable hit testing, rather than testing the old container node.
                if !handled && touchIsOnSlider(track: needleBulletSliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .ships {
                    let idx = sliderIndexForOverlayX(locInOverlay.x)
                    needleBulletLimitSelection = idx
                    draggingNeedleSliderTouch = touch
                    resetBulletCountsFromSelections()
                    endGameIfNoBullets()
                    refreshOptionsUI()
                    handled = true
                } else if !handled && touchIsOnSlider(track: dartBulletSliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .ships {
                    let idx = sliderIndexForOverlayX(locInOverlay.x)
                    dartBulletLimitSelection = idx
                    draggingDartSliderTouch = touch
                    resetBulletCountsFromSelections()
                    endGameIfNoBullets()
                    refreshOptionsUI()
                    handled = true
                }

                if handled { continue }
            }

            if optionsButton.contains(location) {
                setOptionsVisible(!optionsVisible)
                refreshOptionsUI()
                continue
            }

            if optionsVisible { continue }
            if gameOver { continue }

            var consumed = false

            if rightThrustButton.contains(location) {
                activeRightThrustTouches.insert(touch)
                isThrustingDart = true
                consumed = true
            }

            if fireThrustButton.contains(location) {
                let id = ObjectIdentifier(touch)
                // FIX 5: Record the starting location so we can treat large drags as non-taps.
                fireTouches[id] = FireTouchInfo(ship: dart, startTime: CACurrentMediaTime(), startLocation: location, buttonNode: fireThrustButton)
                consumed = true
            }

            #if DEBUG
            if let leftFireButton = leftFireButtonRef,
               !leftFireButton.isHidden,
               leftFireButton.contains(location) {
                let id = ObjectIdentifier(touch)
                fireTouches[id] = FireTouchInfo(ship: needle, startTime: CACurrentMediaTime(), startLocation: location, buttonNode: leftFireButton)
                consumed = true
            }
            #endif

            if !consumed {
                aimPoint = location
                activeAimTouches.insert(touch)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let overlay = optionsOverlay, !overlay.isHidden {
                let locInOverlay = touch.location(in: overlay)

                // FIX 3 (continued): Use touchIsOnSlider() here too; the old code
                // tested `slider.contains(locInOverlay)` on a container node whose
                // frame didn't reliably enclose the track, so drags often failed.
                if draggingNeedleSliderTouch == touch {
                    let idx = sliderIndexForOverlayX(locInOverlay.x)
                    if needleBulletLimitSelection != idx {
                        needleBulletLimitSelection = idx
                        resetBulletCountsFromSelections()
                        endGameIfNoBullets()
                        refreshOptionsUI()
                    }
                    continue
                }
                if draggingDartSliderTouch == touch {
                    let idx = sliderIndexForOverlayX(locInOverlay.x)
                    if dartBulletLimitSelection != idx {
                        dartBulletLimitSelection = idx
                        resetBulletCountsFromSelections()
                        endGameIfNoBullets()
                        refreshOptionsUI()
                    }
                    continue
                }
            }

            let location = touch.location(in: self)
            var onAnyButton = false

            if rightThrustButton.contains(location) {
                activeRightThrustTouches.insert(touch)
            } else {
                activeRightThrustTouches.remove(touch)
            }
            isThrustingDart = !activeRightThrustTouches.isEmpty
            onAnyButton = onAnyButton || rightThrustButton.contains(location) || fireThrustButton.contains(location)

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

            // FIX 5: If a fire touch drifts more than 12 pts from where it started,
            // cancel the fire intent rather than silently dropping the shot on touchesEnded.
            let id = ObjectIdentifier(touch)
            if let info = fireTouches[id] {
                let dx = location.x - info.startLocation.x
                let dy = location.y - info.startLocation.y
                let driftSq = dx*dx + dy*dy
                if driftSq > 12*12 {
                    // Drifted too far — remove from fire tracking so touchesEnded won't fire.
                    fireTouches.removeValue(forKey: id)
                }
            }

            if optionsVisible { continue }
            if gameOver { continue }

            if !onAnyButton {
                activeAimTouches.insert(touch)
                aimPoint = location
            } else {
                activeAimTouches.remove(touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if draggingNeedleSliderTouch == touch { draggingNeedleSliderTouch = nil }
            if draggingDartSliderTouch == touch { draggingDartSliderTouch = nil }

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
                // FIX 5: Fire only if the tap was short AND the finger ended inside
                // the button. Drift cancellation already removed most bad cases in
                // touchesMoved, but this guard covers a slow lift that didn't move far.
                let location = touch.location(in: self)
                if duration < 0.25, let button = info.buttonNode, button.contains(location) {
                    fireMissile(from: info.ship, muzzleOffset: muzzleOffset(for: info.ship))
                }
                continue
            }

            if !aimPersistsAfterLift && activeAimTouches.isEmpty {
                aimPoint = nil
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeRightThrustTouches.remove(touch)
            #if DEBUG
            activeLeftThrustTouches.remove(touch)
            #endif
            if draggingNeedleSliderTouch == touch { draggingNeedleSliderTouch = nil }
            if draggingDartSliderTouch == touch { draggingDartSliderTouch = nil }
            fireTouches.removeValue(forKey: ObjectIdentifier(touch))
            activeAimTouches.remove(touch)
        }

        if !aimPersistsAfterLift && activeAimTouches.isEmpty {
            aimPoint = nil
        }

        isThrustingDart = !activeRightThrustTouches.isEmpty
        #if DEBUG
        isThrustingNeedle = !activeLeftThrustTouches.isEmpty
        #endif
    }
}
