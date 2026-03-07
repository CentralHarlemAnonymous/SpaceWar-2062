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

    private enum OptionsTab { case game, environment, ships, about }
    private var currentOptionsTab: OptionsTab = .environment

    private var gameTabButton: SKShapeNode?
    private var optionsTabButton: SKShapeNode?
    private var shipsTabButton: SKShapeNode?
    private var aboutTabButton: SKShapeNode?
    private var aboutContainer: SKNode?

    // Needle AI
    private var needleAIEnabled: Bool = false
    // FIX #9 — 3 levels: 0=basic (current-pos), 1=predictive (quad), 2=expert (strategic)
    private var needleAIIntelligence: Int = 0
    private var aiNextThrustToggle: TimeInterval = 0
    private var aiThrustOn: Bool = false
    private var aiNextFireTime: TimeInterval = 0

    // Wedge AI
    private var wedgeAIEnabled: Bool = false
    private var wedgeAIIntelligence: Int = 0
    private var wedgeAINextThrustToggle: TimeInterval = 0
    private var wedgeAIThrustOn: Bool = false
    private var wedgeAINextFireTime: TimeInterval = 0

    // Observed acceleration for predictive firing
    private var dartPreviousVelocity: CGVector = .zero
    private var dartObservedAcceleration: CGVector = .zero
    private var needlePreviousVelocity: CGVector = .zero
    private var needleObservedAcceleration: CGVector = .zero

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

    private var gravityStrengthStrong: Bool = true
    private var bulletLifeLong: Bool = false
    private var gravityWeakButton: SKShapeNode?
    private var gravityStrongButton: SKShapeNode?
    private var gravityStrengthLabel: SKLabelNode?
    private var bulletLifeShortButton: SKShapeNode?
    private var bulletLifeLongButton: SKShapeNode?
    private var bulletLifeLabel: SKLabelNode?

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
    private let rotationSpeed: CGFloat = .pi * 2
    private let aimEpsilon: CGFloat = 0.01

    // Two target indicators: needle = orange, dart/wedge = blue
    private var needleTargetIndicator: SKShapeNode!
    private var dartTargetIndicator: SKShapeNode!

    // Physics
    private let thrustAcceleration: CGFloat = 250
    private var maxSpeedNeedle: CGFloat = 400
    private var maxSpeedDart: CGFloat = 400

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
        return (ship === needle) ? CGPoint(x: 0, y: 21) : CGPoint(x: 0, y: 16)
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

        let newNeedleSpawn = CGPoint(x: s.width * 0.20, y: s.height * 0.5)
        let newDartSpawn   = CGPoint(x: s.width * 0.80, y: s.height * 0.5)

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
                let innerRightRadius = buttonRadius * 0.6
                let rightPadding: CGFloat = 12
                rightThrust.position = CGPoint(x: fire.position.x - (buttonRadius + innerRightRadius + rightPadding), y: bottomY)
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
                let innerLeftRadius = leftButtonRadius * 0.6
                let leftPadding: CGFloat = 12
                leftThrust.position = CGPoint(x: leftFire.position.x + (leftButtonRadius + innerLeftRadius + leftPadding), y: bottomY)
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

    private func createNeedlePath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -24))
        path.addLine(to: CGPoint(x: 0, y: 18))
        path.move(to: CGPoint(x: -3, y: -16)); path.addLine(to: CGPoint(x: 3, y: -16))
        path.move(to: CGPoint(x: -3, y: -8));  path.addLine(to: CGPoint(x: 3, y: -8))
        path.move(to: CGPoint(x: -4, y: 0));   path.addLine(to: CGPoint(x: 4, y: 0))
        path.move(to: CGPoint(x: -3, y: 8));   path.addLine(to: CGPoint(x: 3, y: 8))
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

    private func rotateShip(_ shipNode: SKShapeNode, toward worldPoint: CGPoint, dt: TimeInterval) {
        let dx = worldPoint.x - shipNode.position.x
        let dy = worldPoint.y - shipNode.position.y
        let targetAngle = atan2(dy, dx) - .pi / 2
        let currentAngle = shipNode.zRotation
        let angleDiff = shortestAngleBetween(currentAngle, targetAngle)
        if abs(angleDiff) <= aimEpsilon { shipNode.zRotation = targetAngle; return }
        let step = rotationSpeed * CGFloat(dt)
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
        let bulletSpeed: CGFloat = 300
        let targetPos = target.node.position
        let targetVel = target.velocity
        let acc = (target === dart) ? dartObservedAcceleration : needleObservedAcceleration

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
        let baseG: CGFloat = 18000 * (gravityStrengthStrong ? 8.0 : 2.0)
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
    private func simulateBulletHitsSun(from ship: Ship) -> Bool {
        guard let sun = sunNode else { return false }
        let angle = ship.node.zRotation
        let bulletSpeed: CGFloat = 300
        var bx = ship.node.position.x, by = ship.node.position.y
        var bvx = -bulletSpeed * sin(angle), bvy = bulletSpeed * cos(angle)
        let simStep: CGFloat = 0.05
        let simSteps = Int((bulletLifeLong ? 6.0 : 3.0) / simStep)
        let sx = sun.position.x, sy = sun.position.y
        let sunR = sunCollisionRadius
        let baseG: CGFloat = 18000 * (gravityStrengthStrong ? 5.0 : 1.0)
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
        var best = targetPos
        var bestD2 = CGFloat.greatestFiniteMagnitude
        for ix in [-1, 0, 1] as [CGFloat] {
            for iy in [-1, 0, 1] as [CGFloat] {
                let candidate = CGPoint(x: targetPos.x + ix * size.width,
                                        y: targetPos.y + iy * size.height)
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
        let bulletSpeed: CGFloat = 300
        let origin = shooter.node.position
        var targetPos = target.node.position
        if edgeBehavior == .wrap {
            targetPos = nearestVirtualPosition(of: targetPos, from: origin)
        }
        let targetVel = target.velocity
        let acc = (target === dart) ? dartObservedAcceleration : needleObservedAcceleration
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
            return CGPoint(x: max(0, min(size.width,  predicted.x)),
                           y: max(0, min(size.height, predicted.y)))
        }
        return predicted
    }

    /// Simulates all missiles forward and checks whether any will pass within
    /// the danger radius.  FIX #10 — larger radius (200), longer look-ahead (2s).
    /// Also checks opponent ship proximity as a collision-avoidance threat.
    private func edgeAwareBulletDanger(for ship: Ship,
                                        opponent: Ship? = nil,
                                        lookAhead: CGFloat = 2.0) -> (danger: Bool, awayPoint: CGPoint) {
        let dangerRadius: CGFloat = 200
        var nearestD2  = CGFloat.greatestFiniteMagnitude
        var nearestPos = CGPoint.zero

        enumerateChildNodes(withName: "missile") { node, _ in
            guard let data = node.userData,
                  let vx = data["vx"] as? CGFloat,
                  let vy = data["vy"] as? CGFloat else { return }

            var bx = node.position.x, by = node.position.y
            var bvx = vx, bvy = vy
            let steps = 15
            let simDt = lookAhead / CGFloat(steps)

            for _ in 0..<steps {
                bx += bvx * simDt
                by += bvy * simDt

                switch self.edgeBehavior {
                case .bounce:
                    if bx < 0                { bx = 0;                bvx =  abs(bvx) }
                    if bx > self.size.width  { bx = self.size.width;  bvx = -abs(bvx) }
                    if by < 0                { by = 0;                bvy =  abs(bvy) }
                    if by > self.size.height { by = self.size.height; bvy = -abs(bvy) }
                case .wrap:
                    if bx < 0                { bx += self.size.width  }
                    if bx > self.size.width  { bx -= self.size.width  }
                    if by < 0                { by += self.size.height }
                    if by > self.size.height { by -= self.size.height }
                }

                let ddx = bx - ship.node.position.x
                let ddy = by - ship.node.position.y
                let d2  = ddx*ddx + ddy*ddy
                if d2 < nearestD2 { nearestD2 = d2; nearestPos = CGPoint(x: bx, y: by) }
            }
        }

        // FIX #10 — also treat a close opponent ship as a danger to avoid
        if let opp = opponent, !opp.node.isHidden {
            let oppPos = (edgeBehavior == .wrap)
                ? nearestVirtualPosition(of: opp.node.position, from: ship.node.position)
                : opp.node.position
            let odx = oppPos.x - ship.node.position.x
            let ody = oppPos.y - ship.node.position.y
            let od2 = odx*odx + ody*ody
            let shipDangerRadius: CGFloat = 110
            if od2 < shipDangerRadius * shipDangerRadius && od2 < nearestD2 {
                nearestD2  = od2
                nearestPos = oppPos
            }
        }

        if nearestD2 < dangerRadius * dangerRadius {
            let away = CGPoint(
                x: ship.node.position.x - (nearestPos.x - ship.node.position.x),
                y: ship.node.position.y - (nearestPos.y - ship.node.position.y))
            return (true, away)
        }
        return (false, .zero)
    }

    /// Returns a strategic position target for `ship` fighting `opponent`.
    private func strategicPositionTarget(for ship: Ship, opponent: Ship) -> CGPoint {
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

        if abs(dist - idealRange) < 70 {
            return level3AimPoint(shooter: ship, target: opponent)
        }

        let oppSpeed = hypot(opponent.velocity.dx, opponent.velocity.dy)
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
            return CGPoint(x: max(m, min(size.width  - m, p.x)),
                           y: max(m, min(size.height - m, p.y)))
        }

        return score(c1) <= score(c2) ? clamp(c1) : clamp(c2)
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

        // FIX #8 — record destroy time so we can delay respawn until bullets expire
        let now = CACurrentMediaTime()
        if ship === needle { needleDestroyTime = now }
        else               { dartDestroyTime   = now }

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

    private func startNewMatch() {
        needleScore = 0; dartScore = 0
        updateScoreDisplays()
        enableRandomRespawn = false
        needle.reset(); dart.reset()
        needleVisibleSince = CACurrentMediaTime()
        dartVisibleSince = CACurrentMediaTime()
        // FIX #8 — clear pending respawn state
        needleDestroyTime = 0; dartDestroyTime = 0
        needleRespawnScheduled = false; dartRespawnScheduled = false
        resetBulletCountsFromSelections()
        aiNextThrustToggle = 0; aiNextFireTime = 0; aiThrustOn = false
        wedgeAINextThrustToggle = 0; wedgeAINextFireTime = 0; wedgeAIThrustOn = false
        enumerateChildNodes(withName: "missile") { n, _ in n.removeFromParent() }
        enumerateChildNodes(withName: "wreckPiece") { n, _ in n.removeFromParent() }
        gameOver = false
        victorLabelNode?.removeFromParent(); victorLabelNode = nil
        gameOverLabelNode?.removeFromParent(); gameOverLabelNode = nil
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

    /// FIX #5 — bullet choices: 10 / 50 / ∞
    private func bulletsForSelection(_ sel: Int) -> Int? {
        switch sel {
        case 0: return 10
        case 1: return 50
        default: return nil   // infinite
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

    private func makeInfinityNode() -> SKNode {
        let path = CGMutablePath()
        let r: CGFloat = 4, gap: CGFloat = 2
        path.addEllipse(in: CGRect(x: -(r*2+gap), y: -r, width: r*2, height: r*2))
        path.addEllipse(in: CGRect(x: gap, y: -r, width: r*2, height: r*2))
        let node = SKShapeNode(path: path)
        node.strokeColor = .white; node.fillColor = .clear
        node.lineWidth = 1.5; node.glowWidth = 2
        return node
    }

    private func refreshBulletCounters() {
        func setCounter(_ node: SKNode?, count: Int) {
            guard let node else { return }
            node.removeAllChildren()
            let content: SKNode = (count == Int.max) ? makeInfinityNode() : makeScoreNode(score: count, scale: 0.8, spacing: 10)
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

        let now = CACurrentMediaTime()
        driftNeedleThrustOn = true; driftDartThrustOn = true
        driftNeedleNextToggle = now + Double.random(in: 0.4...1.0)
        driftDartNextToggle   = now + Double.random(in: 0.4...1.0)
        driftNeedleTargetAngle = CGFloat.random(in: 0...(2 * .pi))
        driftDartTargetAngle   = CGFloat.random(in: 0...(2 * .pi))
        driftNeedleNextTurn = now + Double.random(in: 0.8...2.0)
        driftDartNextTurn   = now + Double.random(in: 0.8...2.0)

        showVictorLabel(); showGameOverLabel()
    }

    private func vectorWordWidth(_ text: String, scale: CGFloat, spacing: CGFloat) -> CGFloat {
        let n = CGFloat(text.count)
        guard n > 0 else { return 0 }
        return ((n - 1) * (8 + spacing) + 8) * scale
    }

    private func showVictorLabel() {
        victorLabelNode?.removeFromParent()
        let needleCX = size.width * 0.20, dartCX = size.width * 0.80
        let labelY = size.height - 70
        let container = SKNode(); container.zPosition = 80; addChild(container); victorLabelNode = container
        if needleScore == dartScore {
            for (text, cx) in [("TIE", needleCX), ("TIE", dartCX)] {
                let w = vectorWordWidth(text, scale: 1.0, spacing: 4)
                let node = makeVectorWordNode(text, scale: 1.0, spacing: 4, bright: true)
                node.position = CGPoint(x: cx - w/2, y: labelY); container.addChild(node)
            }
        } else {
            let cx = needleScore > dartScore ? needleCX : dartCX
            let w = vectorWordWidth("WINNER", scale: 1.0, spacing: 4)
            let word = makeVectorWordNode("WINNER", scale: 1.0, spacing: 4, bright: true)
            word.position = CGPoint(x: cx - w/2, y: labelY); container.addChild(word)
        }
    }

    private func showGameOverLabel() {
        gameOverLabelNode?.removeFromParent()
        let text = "GAME OVER", scale: CGFloat = 2.4, spacing: CGFloat = 5
        let phrase = makeVectorWordNode(text, scale: scale, spacing: spacing)
        phrase.zPosition = 80
        let w = vectorWordWidth(text, scale: scale, spacing: spacing)
        phrase.position = CGPoint(x: size.width/2 - w/2, y: size.height * 2/3)
        addChild(phrase); gameOverLabelNode = phrase
    }

    private func makeVectorWordNode(_ text: String, scale: CGFloat, spacing: CGFloat, bright: Bool = false) -> SKNode {
        let container = SKNode()
        var cursorX: CGFloat = 0
        let sw: CGFloat = bright ? 1.0 : 0.5
        let segAlpha: CGFloat = bright ? 1.0 : 0.4
        let dotAlpha: CGFloat = bright ? 1.0 : 0.7
        let segGlow: CGFloat  = bright ? 4.0 : 0.0
        let glyphs: [Character: [(CGFloat,CGFloat,CGFloat,CGFloat)]] = [
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

    // MARK: - Options Overlay

    private func setupOptionsOverlay() {
        let overlay = SKNode()
        overlay.zPosition = 200
        overlay.name = "optionsOverlay"
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)

        let w: CGFloat = min(380, size.width - 40)
        let h: CGFloat = 460

        let bgPath = CGPath(roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h),
                            cornerWidth: 14, cornerHeight: 14, transform: nil)
        let bg = SKShapeNode(path: bgPath)
        bg.fillColor = SKColor(white: 0.1, alpha: 0.9)
        bg.strokeColor = .white; bg.lineWidth = 2; bg.zPosition = 201; bg.name = "options_bg"
        overlay.addChild(bg)

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

        // MARK: Environment tab content
        let screenEdgeLabel = makeLabel("Screen Edge:", y: h/2 - 90, name: "env_label_screen_edge")
        overlay.addChild(screenEdgeLabel)

        let bounceBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        bounceBtn.name = "opt_edge_bounce"; bounceBtn.position = CGPoint(x: -60, y: h/2 - 115)
        bounceBtn.strokeColor = .white; bounceBtn.lineWidth = 2; bounceBtn.zPosition = 202; overlay.addChild(bounceBtn)
        bounceBtn.addChild(makeTabInnerLabel("Bounce")); edgeBounceButton = bounceBtn

        let wrapBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        wrapBtn.name = "opt_edge_wrap"; wrapBtn.position = CGPoint(x: 60, y: h/2 - 115)
        wrapBtn.strokeColor = .white; wrapBtn.lineWidth = 2; wrapBtn.zPosition = 202; overlay.addChild(wrapBtn)
        wrapBtn.addChild(makeTabInnerLabel("Wrap")); edgeWrapButton = wrapBtn

        // Sun at Center — label + ON/OFF button on the SAME ROW so hit area matches visual
        let sunRowLabel = SKLabelNode(text: "Sun at Center:")
        sunRowLabel.name = "env_label_sun"
        sunRowLabel.fontName = "AvenirNext-Bold"; sunRowLabel.fontSize = 16
        sunRowLabel.fontColor = .white; sunRowLabel.verticalAlignmentMode = .center
        sunRowLabel.horizontalAlignmentMode = .left
        sunRowLabel.position = CGPoint(x: -w/2 + 20, y: h/2 - 190); sunRowLabel.zPosition = 202
        overlay.addChild(sunRowLabel)

        let sunBtn = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 6)
        sunBtn.name = "opt_sun_toggle"; sunBtn.position = CGPoint(x: w/2 - 50, y: h/2 - 190)
        sunBtn.strokeColor = .white; sunBtn.lineWidth = 2; sunBtn.zPosition = 202
        overlay.addChild(sunBtn); sunToggleButton = sunBtn
        sunBtn.addChild(makeTabInnerLabel("ON"))

        // Affects Bullets — label + button, pinned inside the gravity group box (x: -130…130)
        let bulletLbl = SKLabelNode(text: "Affects Bullets:")
        bulletLbl.name = "env_label_affects"; bulletLbl.fontName = "AvenirNext-Bold"; bulletLbl.fontSize = 14
        bulletLbl.fontColor = .white; bulletLbl.verticalAlignmentMode = .center
        bulletLbl.horizontalAlignmentMode = .left
        bulletLbl.position = CGPoint(x: -118, y: h/2 - 307); bulletLbl.zPosition = 203
        overlay.addChild(bulletLbl); bulletGravLabel = bulletLbl

        let bulletBtn = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 6)
        bulletBtn.name = "opt_bullet_grav_toggle"; bulletBtn.position = CGPoint(x: 88, y: h/2 - 307)
        bulletBtn.strokeColor = .white; bulletBtn.lineWidth = 2; bulletBtn.zPosition = 202
        overlay.addChild(bulletBtn); bulletGravToggleButton = bulletBtn
        bulletBtn.addChild(makeTabInnerLabel("ON"))

        let gravityHeading = makeLabel("Gravity", y: h/2 - 270, name: "env_label_gravity")
        overlay.addChild(gravityHeading)

        let gravLabel = SKLabelNode(text: "Strength")
        gravLabel.name = "env_label_strength"; gravLabel.fontName = "AvenirNext-Bold"; gravLabel.fontSize = 14
        gravLabel.fontColor = .white; gravLabel.position = CGPoint(x: 0, y: h/2 - 370); gravLabel.zPosition = 202
        overlay.addChild(gravLabel); gravityStrengthLabel = gravLabel

        let gravWeak = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        gravWeak.name = "opt_grav_weak"; gravWeak.position = CGPoint(x: -60, y: h/2 - 395)
        gravWeak.strokeColor = .white; gravWeak.lineWidth = 2; gravWeak.zPosition = 202; overlay.addChild(gravWeak)
        gravWeak.addChild(makeTabInnerLabel("Weak")); gravityWeakButton = gravWeak

        let gravStrong = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        gravStrong.name = "opt_grav_strong"; gravStrong.position = CGPoint(x: 60, y: h/2 - 395)
        gravStrong.strokeColor = .white; gravStrong.lineWidth = 2; gravStrong.zPosition = 202; overlay.addChild(gravStrong)
        gravStrong.addChild(makeTabInnerLabel("Strong")); gravityStrongButton = gravStrong

        let gravityGroupRect = CGRect(x: -130, y: h/2 - 420, width: 260, height: 170)
        let gravityGroup = SKShapeNode(rect: gravityGroupRect, cornerRadius: 8)
        gravityGroup.name = "env_gravity_group"; gravityGroup.strokeColor = SKColor(white: 1.0, alpha: 0.6)
        gravityGroup.lineWidth = 1; gravityGroup.fillColor = .clear; gravityGroup.zPosition = 201.5
        overlay.addChild(gravityGroup)

        // MARK: Ships/Controls tab content
        let aiSectionHeaderY: CGFloat = 155
        let needleAITrackY:   CGFloat = 130
        let wedgeAITrackY:    CGFloat = 90
        let bulletsSectionY:  CGFloat = 55
        let bulletsY:         CGFloat = 28
        let bulletLifeY:      CGFloat = -60
        let bulletButtonsY:   CGFloat = -90

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

        let lifeLabel = makeLabel("Bullet Life:", y: bulletLifeY, name: "ships_label_bullet_life")
        overlay.addChild(lifeLabel); bulletLifeLabel = lifeLabel

        let lifeShort = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        lifeShort.name = "opt_bullet_short"; lifeShort.position = CGPoint(x: -60, y: bulletButtonsY)
        lifeShort.strokeColor = .white; lifeShort.lineWidth = 2; lifeShort.zPosition = 202; overlay.addChild(lifeShort)
        lifeShort.addChild(makeTabInnerLabel("Short")); bulletLifeShortButton = lifeShort

        let lifeLong = SKShapeNode(rectOf: CGSize(width: 90, height: 28), cornerRadius: 6)
        lifeLong.name = "opt_bullet_long"; lifeLong.position = CGPoint(x: 60, y: bulletButtonsY)
        lifeLong.strokeColor = .white; lifeLong.lineWidth = 2; lifeLong.zPosition = 202; overlay.addChild(lifeLong)
        lifeLong.addChild(makeTabInnerLabel("Long")); bulletLifeLongButton = lifeLong

        // MARK: Gameplay tab content
        let newMatchBtn = SKShapeNode(rectOf: CGSize(width: 140, height: 36), cornerRadius: 8)
        newMatchBtn.name = "game_new_match"; newMatchBtn.position = CGPoint(x: 0, y: h/2 - 120)
        newMatchBtn.fillColor = .clear; newMatchBtn.strokeColor = .white; newMatchBtn.lineWidth = 2
        newMatchBtn.zPosition = 202; overlay.addChild(newMatchBtn)
        newMatchBtn.addChild(makeTabInnerLabel("New Match", fontSize: 16))

        let aimLabel = makeLabel("Aim Persists:", y: h/2 - 185, name: "game_label_aim_persist")
        overlay.addChild(aimLabel)

        let aimBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aimBtn.name = "game_aim_persist_toggle"; aimBtn.position = CGPoint(x: 0, y: h/2 - 215)
        aimBtn.strokeColor = .white; aimBtn.lineWidth = 2; aimBtn.zPosition = 202
        overlay.addChild(aimBtn); aimPersistToggleButton = aimBtn

        let aiLabel = makeLabel("Needle AI:", y: h/2 - 265, name: "game_label_needle_ai")
        overlay.addChild(aiLabel)

        let aiBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        aiBtn.name = "game_ai_toggle"; aiBtn.position = CGPoint(x: 0, y: h/2 - 295)
        aiBtn.strokeColor = .white; aiBtn.lineWidth = 2; aiBtn.zPosition = 202
        overlay.addChild(aiBtn); aiToggleButton = aiBtn

        let wedgeAILabel = makeLabel("Wedge AI:", y: h/2 - 345, name: "game_label_wedge_ai")
        overlay.addChild(wedgeAILabel)

        let wedgeAIBtn = SKShapeNode(rectOf: CGSize(width: 40, height: 24), cornerRadius: 5)
        wedgeAIBtn.name = "game_wedge_ai_toggle"; wedgeAIBtn.position = CGPoint(x: 0, y: h/2 - 375)
        wedgeAIBtn.strokeColor = .white; wedgeAIBtn.lineWidth = 2; wedgeAIBtn.zPosition = 202
        overlay.addChild(wedgeAIBtn); wedgeAIToggleButton = wedgeAIBtn

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

    // FIX #7 — helper computes which notch the touch is on, for snap-drag
    private func sliderIndexForOverlayX(_ x: CGFloat) -> Int {
        let step = sliderTrackWidth / CGFloat(bulletSliderSteps)
        let idx = Int(round((x + sliderTrackHalfWidth) / step))
        return max(0, min(bulletSliderSteps, idx))
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
        // Black background: selected = solid white fill + black text (maximum contrast)
        //                   unselected = clear fill + white stroke + white text
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
        let envPrefixes   = ["opt_edge_", "opt_sun_toggle", "opt_bullet_grav_toggle",
                             "opt_grav_", "env_label_", "env_gravity_group"]
        let shipsPrefixes = ["ships_label_", "opt_bullet_short", "opt_bullet_long",
                             "opt_bullets_", "count_label_", "opt_needle_ai_", "opt_wedge_ai_"]

        optionsOverlay?.children.forEach { node in
            if node.name == "options_bg" { return }
            if node === gameTabButton || node === optionsTabButton ||
               node === shipsTabButton || node === aboutTabButton || node === aboutContainer { return }
            let name = node.name ?? ""
            switch currentOptionsTab {
            case .environment: node.isHidden = !envPrefixes.contains(where: { name.hasPrefix($0) })
            case .ships:       node.isHidden = !shipsPrefixes.contains(where: { name.hasPrefix($0) })
            case .game:        node.isHidden = !gamePrefixes.contains(where: { name.hasPrefix($0) })
            case .about:       node.isHidden = true
            }
        }

        aboutContainer?.isHidden = (currentOptionsTab != .about)

        func setTab(_ tabNode: SKShapeNode?, selected: Bool) {
            guard let tabNode, let lbl = tabNode.children.compactMap({ $0 as? SKLabelNode }).first else { return }
            tabNode.fillColor   = selected ? selFill : offFill
            tabNode.strokeColor = SKColor.white
            tabNode.lineWidth   = 2
            tabNode.glowWidth   = 0
            lbl.fontColor       = selected ? selText : offText
        }
        setTab(gameTabButton,    selected: currentOptionsTab == .game)
        setTab(optionsTabButton, selected: currentOptionsTab == .environment)
        setTab(shipsTabButton,   selected: currentOptionsTab == .ships)
        setTab(aboutTabButton,   selected: currentOptionsTab == .about)

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
        gravityStrengthLabel?.alpha = sunEnabled ? 1.0 : 0.5
        setEnabled(gravityWeakButton,   enabled: sunEnabled)
        setEnabled(gravityStrongButton, enabled: sunEnabled)

        styleBtn(gravityWeakButton,      selected: !gravityStrengthStrong)
        styleBtn(gravityStrongButton,    selected:  gravityStrengthStrong)
        styleBtn(bulletLifeShortButton,  selected: !bulletLifeLong)
        styleBtn(bulletLifeLongButton,   selected:  bulletLifeLong)

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

        // FIX #9 — 3-level label names
        let aiLevelNames = ["basic", "smart", "expert"]

        // Needle AI intelligence slider
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

        // Wedge AI intelligence slider
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
        let otherShip: Ship = (ship === needle) ? dart! : needle!
        for _ in 0..<100 {
            let p = CGPoint(x: CGFloat.random(in: inset...(size.width-inset)),
                            y: CGFloat.random(in: inset...(size.height-inset)))
            if !otherShip.node.isHidden && otherShip.node.frame.insetBy(dx: -20, dy: -20).contains(p) { continue }
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
        let pos: CGPoint
        if enableRandomRespawn, let p = safeRandomPosition(avoiding: ship) { pos = p }
        else { pos = ship.spawnPosition }
        ship.node.position = pos; ship.node.zRotation = 0
        ship.velocity = .zero; ship.node.isHidden = false
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime

        if optionsVisible {
            needleTargetIndicator.alpha = 0
            dartTargetIndicator.alpha = 0
            lastUpdateTime = currentTime
            return
        }

        for entity in entities { entity.update(deltaTime: dt) }

        // FIX #8 — check for deferred respawns (wait until bullet life elapsed since death)
        let bulletLifeSeconds = 3.0 * (bulletLifeLong ? 2.0 : 1.0)
        if needleRespawnScheduled && needle.node.isHidden {
            if currentTime - needleDestroyTime >= bulletLifeSeconds {
                needleRespawnScheduled = false
                respawnShip(needle)
                needleVisibleSince = currentTime
            }
        }
        if dartRespawnScheduled && dart.node.isHidden {
            if currentTime - dartDestroyTime >= bulletLifeSeconds {
                dartRespawnScheduled = false
                respawnShip(dart)
                dartVisibleSince = currentTime
            }
        }

        if gameOver {
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
                needle.flame.alpha = driftNeedleThrustOn ? 1 : 0
                if driftNeedleThrustOn { needle.applyThrust(accel: driftAccel, dt: CGFloat(dt)) }
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
                dart.flame.alpha = driftDartThrustOn ? 1 : 0
                if driftDartThrustOn { dart.applyThrust(accel: driftAccel, dt: CGFloat(dt)) }
            }

        } else {
            // Normal play
            var needleAimTarget: CGPoint? = nil
            var dartAimTarget: CGPoint? = nil
            var needleEvasion = false
            var wedgeEvasion = false

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

                        // FIX #10 — expert AI uses larger avoidance radius
                        let avoidRadius: CGFloat = (needleAIIntelligence >= 2) ? 180 : 140
                        let tooClose = dist2 < avoidRadius * avoidRadius
                        // FIX #9 — remapped: level >= 1 uses shipWillHitSun (was >= 2)
                        let shouldAvoidSun = (needleAIIntelligence >= 1)
                            ? (shipWillHitSun(needle, in: 3.5) || tooClose)
                            : (tooClose || onCollisionCourse)

                        if shouldAvoidSun {
                            let awayPoint = CGPoint(x: needle.node.position.x - dxs, y: needle.node.position.y - dys)
                            rotateShip(needle.node, toward: awayPoint, dt: dt)
                            needleAimTarget = awayPoint
                            needleEvasion = true
                        } else {
                            // FIX #9 — remapped: level >= 2 uses strategic AI (was >= 3)
                            if needleAIIntelligence >= 2 {
                                let (inDanger, awayPoint) = edgeAwareBulletDanger(for: needle, opponent: dart)
                                let aimTarget = inDanger ? awayPoint
                                                         : strategicPositionTarget(for: needle, opponent: dart)
                                rotateShip(needle.node, toward: aimTarget, dt: dt)
                                needleAimTarget = aimTarget
                                if inDanger { needleEvasion = true }
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
                                    rotateShip(needle.node, toward: awayPoint, dt: dt)
                                    needleAimTarget = awayPoint
                                } else if !dart.node.isHidden {
                                    let dxw = dart.node.position.x - needle.node.position.x
                                    let dyw = dart.node.position.y - needle.node.position.y
                                    let d2w = dxw*dxw + dyw*dyw
                                    if d2w < 90*90 {
                                        let awayPoint = CGPoint(x: needle.node.position.x - dxw, y: needle.node.position.y - dyw)
                                        rotateShip(needle.node, toward: awayPoint, dt: dt)
                                        needleAimTarget = awayPoint
                                    } else {
                                        let t = predictedAimPoint(shooter: needle, target: dart, intelligence: needleAIIntelligence)
                                        rotateShip(needle.node, toward: t, dt: dt)
                                        needleAimTarget = t
                                    }
                                } else {
                                    let t = predictedAimPoint(shooter: needle, target: dart, intelligence: needleAIIntelligence)
                                    rotateShip(needle.node, toward: t, dt: dt)
                                    needleAimTarget = t
                                }
                            }
                        }
                    } else {
                        // No sun — needle
                        if needleAIIntelligence >= 2 {
                            let (inDanger, awayPoint) = edgeAwareBulletDanger(for: needle, opponent: dart)
                            let aimTarget = inDanger ? awayPoint
                                                     : strategicPositionTarget(for: needle, opponent: dart)
                            rotateShip(needle.node, toward: aimTarget, dt: dt)
                            needleAimTarget = aimTarget
                            if inDanger { needleEvasion = true }
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
                                rotateShip(needle.node, toward: awayPoint, dt: dt)
                                needleAimTarget = awayPoint
                            } else {
                                let t = predictedAimPoint(shooter: needle, target: dart, intelligence: needleAIIntelligence)
                                rotateShip(needle.node, toward: t, dt: dt)
                                needleAimTarget = t
                            }
                        }
                    }
                } else if let p = aimPoint {
                    rotateShip(needle.node, toward: p, dt: dt)
                    needleAimTarget = p
                }
            }

            // MARK: Wedge/Dart rotation / AI
            if !dart.node.isHidden {
                if wedgeAIEnabled {
                    if let sun = sunNode {
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

                        if shouldAvoidSun {
                            let awayPoint = CGPoint(x: dart.node.position.x - dxs, y: dart.node.position.y - dys)
                            rotateShip(dart.node, toward: awayPoint, dt: dt)
                            dartAimTarget = awayPoint
                            wedgeEvasion = true
                        } else {
                            if wedgeAIIntelligence >= 2 {
                                let (inDanger, awayPoint) = edgeAwareBulletDanger(for: dart, opponent: needle)
                                let aimTarget = inDanger ? awayPoint
                                                         : strategicPositionTarget(for: dart, opponent: needle)
                                rotateShip(dart.node, toward: aimTarget, dt: dt)
                                dartAimTarget = aimTarget
                                if inDanger { wedgeEvasion = true }
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
                                    rotateShip(dart.node, toward: awayPoint, dt: dt)
                                    dartAimTarget = awayPoint
                                } else if !needle.node.isHidden {
                                    let dxn = needle.node.position.x - dart.node.position.x
                                    let dyn = needle.node.position.y - dart.node.position.y
                                    let d2n = dxn*dxn + dyn*dyn
                                    if d2n < 90*90 {
                                        let awayPoint = CGPoint(x: dart.node.position.x - dxn, y: dart.node.position.y - dyn)
                                        rotateShip(dart.node, toward: awayPoint, dt: dt)
                                        dartAimTarget = awayPoint
                                    } else {
                                        let t = predictedAimPoint(shooter: dart, target: needle, intelligence: wedgeAIIntelligence)
                                        rotateShip(dart.node, toward: t, dt: dt)
                                        dartAimTarget = t
                                    }
                                } else {
                                    let t = predictedAimPoint(shooter: dart, target: needle, intelligence: wedgeAIIntelligence)
                                    rotateShip(dart.node, toward: t, dt: dt)
                                    dartAimTarget = t
                                }
                            }
                        }
                    } else {
                        // No sun — wedge
                        if wedgeAIIntelligence >= 2 {
                            let (inDanger, awayPoint) = edgeAwareBulletDanger(for: dart, opponent: needle)
                            let aimTarget = inDanger ? awayPoint
                                                     : strategicPositionTarget(for: dart, opponent: needle)
                            rotateShip(dart.node, toward: aimTarget, dt: dt)
                            dartAimTarget = aimTarget
                            if inDanger { wedgeEvasion = true }
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
                                rotateShip(dart.node, toward: awayPoint, dt: dt)
                                dartAimTarget = awayPoint
                            } else {
                                let t = predictedAimPoint(shooter: dart, target: needle, intelligence: wedgeAIIntelligence)
                                rotateShip(dart.node, toward: t, dt: dt)
                                dartAimTarget = t
                            }
                        }
                    }
                } else if let p = aimPoint {
                    rotateShip(dart.node, toward: p, dt: dt)
                    dartAimTarget = p
                }
            }

            // Update target indicators
            if let t = needleAimTarget {
                needleTargetIndicator.position = t; needleTargetIndicator.alpha = 0.7
            } else { needleTargetIndicator.alpha = 0 }

            if let t = dartAimTarget {
                dartTargetIndicator.position = t; dartTargetIndicator.alpha = 0.7
            } else { dartTargetIndicator.alpha = 0 }

            // MARK: Needle AI thrust + fire
            if needleAIEnabled && !needle.node.isHidden {
                if needleAIIntelligence >= 2 {
                    let speed = hypot(needle.velocity.dx, needle.velocity.dy)
                    let opponentDown = dart.node.isHidden
                    let recentKill = (currentTime - dartKillTime) < 4.0
                    let shouldBrake = opponentDown && recentKill && speed > 80 && !needleEvasion
                    if shouldBrake {
                        // Point retrograde and thrust to bleed off speed safely
                        let retrograde = CGPoint(
                            x: needle.node.position.x - needle.velocity.dx,
                            y: needle.node.position.y - needle.velocity.dy)
                        rotateShip(needle.node, toward: retrograde, dt: dt)
                        needleAimTarget = retrograde
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

                if currentTime >= aiNextFireTime && !dart.node.isHidden && (currentTime - dartVisibleSince) >= 1.0 {
                    var shouldFire = true
                    // FIX #9 — remapped: level >= 1 checks bullet sun path (was >= 2)
                    if needleAIIntelligence >= 1, sunNode != nil {
                        shouldFire = !simulateBulletHitsSun(from: needle)
                    }
                    if shouldFire && needleAIIntelligence >= 2 {
                        let oppDist = hypot(dart.node.position.x - needle.node.position.x,
                                            dart.node.position.y - needle.node.position.y)
                        if oppDist > 320 {
                            shouldFire = false
                        } else {
                            let aim = level3AimPoint(shooter: needle, target: dart)
                            let aimAngle = atan2(aim.y - needle.node.position.y,
                                                 aim.x - needle.node.position.x) - .pi/2
                            let diff = abs(shortestAngleBetween(needle.node.zRotation, aimAngle))
                            if diff > .pi / 10 { shouldFire = false }
                        }
                    }
                    if shouldFire {
                        fireMissile(from: needle, muzzleOffset: muzzleOffset(for: needle))
                        aiNextFireTime = currentTime + Double.random(in: 0.9...2.0)
                    } else {
                        aiNextFireTime = currentTime + 0.15
                    }
                }
            }

            // MARK: Wedge AI thrust + fire
            if wedgeAIEnabled && !dart.node.isHidden {
                if wedgeAIIntelligence >= 2 {
                    let speed = hypot(dart.velocity.dx, dart.velocity.dy)
                    let opponentDown = needle.node.isHidden
                    let recentKill = (currentTime - needleKillTime) < 4.0
                    let shouldBrake = opponentDown && recentKill && speed > 80 && !wedgeEvasion
                    if shouldBrake {
                        let retrograde = CGPoint(
                            x: dart.node.position.x - dart.velocity.dx,
                            y: dart.node.position.y - dart.velocity.dy)
                        rotateShip(dart.node, toward: retrograde, dt: dt)
                        dartAimTarget = retrograde
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

                if currentTime >= wedgeAINextFireTime && !needle.node.isHidden && (currentTime - needleVisibleSince) >= 1.0 {
                    var shouldFire = true
                    if wedgeAIIntelligence >= 1, sunNode != nil {
                        shouldFire = !simulateBulletHitsSun(from: dart)
                    }
                    if shouldFire && wedgeAIIntelligence >= 2 {
                        let oppDist = hypot(needle.node.position.x - dart.node.position.x,
                                            needle.node.position.y - dart.node.position.y)
                        if oppDist > 320 {
                            shouldFire = false
                        } else {
                            let aim = level3AimPoint(shooter: dart, target: needle)
                            let aimAngle = atan2(aim.y - dart.node.position.y,
                                                 aim.x - dart.node.position.x) - .pi/2
                            let diff = abs(shortestAngleBetween(dart.node.zRotation, aimAngle))
                            if diff > .pi / 10 { shouldFire = false }
                        }
                    }
                    if shouldFire {
                        fireMissile(from: dart, muzzleOffset: muzzleOffset(for: dart))
                        wedgeAINextFireTime = currentTime + Double.random(in: 0.9...2.0)
                    } else {
                        wedgeAINextFireTime = currentTime + 0.15
                    }
                }
            }

            if isThrustingDart {
                dart.applyThrust(accel: thrustAcceleration, dt: CGFloat(dt)); dart.flame.alpha = 1
            } else { dart.flame.alpha = 0 }

            if isThrustingNeedle {
                needle.applyThrust(accel: thrustAcceleration, dt: CGFloat(dt)); needle.flame.alpha = 1
            } else { needle.flame.alpha = 0 }

        } // end else (normal play)

        // Gravity
        if sunEnabled, let sun = sunNode {
            func applyGravity(to ship: Ship) {
                let dx = sun.position.x - ship.node.position.x
                let dy = sun.position.y - ship.node.position.y
                let r2 = dx*dx + dy*dy + 100
                let invR = 1.0 / sqrt(r2)
                let G: CGFloat = 18000 * (gravityStrengthStrong ? 8.0 : 2.0)
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
                    let G: CGFloat = 18000 * (self.gravityStrengthStrong ? 5.0 : 1.0)
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
        }
        dartPreviousVelocity   = dart.velocity
        needlePreviousVelocity = needle.velocity

        func handleEdges(_ ship: Ship) {
            var pos = ship.node.position
            switch edgeBehavior {
            case .bounce:
                var bounced = false
                if pos.x < 0            { pos.x = 0;          ship.velocity.dx =  abs(ship.velocity.dx); bounced = true }
                if pos.x > size.width   { pos.x = size.width;  ship.velocity.dx = -abs(ship.velocity.dx); bounced = true }
                if pos.y < 0            { pos.y = 0;          ship.velocity.dy =  abs(ship.velocity.dy); bounced = true }
                if pos.y > size.height  { pos.y = size.height; ship.velocity.dy = -abs(ship.velocity.dy); bounced = true }
                if bounced { ship.node.position = pos; ship.alignRotationToVelocityIfMoving() }
            case .wrap:
                if pos.x < 0           { pos.x = size.width }
                if pos.x > size.width  { pos.x = 0 }
                if pos.y < 0           { pos.y = size.height }
                if pos.y > size.height { pos.y = 0 }
                ship.node.position = pos
            }
        }
        handleEdges(dart); handleEdges(needle)

        enumerateChildNodes(withName: "missile") { node, _ in
            guard let data = node.userData,
                  var vx = data["vx"] as? CGFloat,
                  var vy = data["vy"] as? CGFloat else { return }
            node.position.x += vx * CGFloat(dt); node.position.y += vy * CGFloat(dt)
            switch self.edgeBehavior {
            case .bounce:
                var bounced = false
                if node.position.x < 0              { node.position.x = 0;               vx =  abs(vx); bounced = true }
                if node.position.x > self.size.width  { node.position.x = self.size.width;  vx = -abs(vx); bounced = true }
                if node.position.y < 0              { node.position.y = 0;               vy =  abs(vy); bounced = true }
                if node.position.y > self.size.height { node.position.y = self.size.height; vy = -abs(vy); bounced = true }
                if bounced { node.userData?["vx"] = vx; node.userData?["vy"] = vy; node.userData?["bounced"] = true }
            case .wrap:
                if node.position.x < 0              { node.position.x = self.size.width }
                if node.position.x > self.size.width  { node.position.x = 0 }
                if node.position.y < 0              { node.position.y = self.size.height }
                if node.position.y > self.size.height { node.position.y = 0 }
            }
        }

        enumerateChildNodes(withName: "wreckPiece") { node, _ in
            guard let data = node.userData,
                  var vx = data["vx"] as? CGFloat,
                  var vy = data["vy"] as? CGFloat,
                  var life = data["life"] as? CGFloat,
                  let maxLife = data["maxLife"] as? CGFloat else { return }
            node.position.x += vx * CGFloat(dt); node.position.y += vy * CGFloat(dt)
            switch self.edgeBehavior {
            case .bounce:
                var bounced = false
                if node.position.x < 0              { node.position.x = 0;               vx =  abs(vx); bounced = true }
                if node.position.x > self.size.width  { node.position.x = self.size.width;  vx = -abs(vx); bounced = true }
                if node.position.y < 0              { node.position.y = 0;               vy =  abs(vy); bounced = true }
                if node.position.y > self.size.height { node.position.y = self.size.height; vy = -abs(vy); bounced = true }
                if bounced { node.userData?["vx"] = vx; node.userData?["vy"] = vy }
            case .wrap:
                if node.position.x < 0              { node.position.x = self.size.width }
                if node.position.x > self.size.width  { node.position.x = 0 }
                if node.position.y < 0              { node.position.y = self.size.height }
                if node.position.y > self.size.height { node.position.y = 0 }
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
                        // FIX #8 — only respawn if enough time has passed for pre-death
                        //          bullets to have expired; otherwise schedule for later.
                        let bulletLife = 3.0 * (self.bulletLifeLong ? 2.0 : 1.0)
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
                    dartScore += 1; updateScoreDisplays(); explodeShip(ship: needle)
                }
            }
            if !dart.node.isHidden {
                let dx = dart.node.position.x - sun.position.x
                let dy = dart.node.position.y - sun.position.y
                if dx*dx + dy*dy <= sunCollisionRadius*sunCollisionRadius {
                    needleScore += 1; updateScoreDisplays(); explodeShip(ship: dart)
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
        if needleHit { dartScore += 1; updateScoreDisplays(); dartKillTime = currentTime; explodeShip(ship: needle) }
        if dartHit   { needleScore += 1; updateScoreDisplays(); needleKillTime = currentTime; explodeShip(ship: dart) }
        if !needle.node.isHidden && !dart.node.isHidden && needle.node.frame.intersects(dart.node.frame) {
            needleScore += 1; dartScore += 1; updateScoreDisplays()
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

                // FIX #7 — slider taps move one notch in the direction of the tap
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

            // FIX #2 — needle thrust was missing from touchesBegan (only handled in Moved)
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
