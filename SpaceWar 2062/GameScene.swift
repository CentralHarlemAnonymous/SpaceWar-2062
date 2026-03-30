//
//  GameScene.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 1/9/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit
import GameplayKit

// MARK: - ShipState

/// Runtime state for each ship (AI, controls, tracking)
final class ShipState {
    // AI
    var aiEnabled: Bool = false
    var aiIntelligence: Int = 0
    var aiNextThrustToggle: TimeInterval = 0
    var aiThrustOn: Bool = false
    var aiNextFireTime: TimeInterval = 0
    var aiCertainFireCooldown: TimeInterval = 0
    
    // Tracking
    var visibleSince: TimeInterval = 0
    var destroyTime: TimeInterval = 0
    var respawnScheduled: Bool = false
    var respawnTarget: CGPoint = .zero
    var cameraPanAfter: TimeInterval = 0
    
    // Velocity tracking for prediction
    var previousVelocity: CGVector = .zero
    var observedAcceleration: CGVector = .zero
    var smoothedAcceleration: CGVector = .zero
    
    // Bullets
    var bulletLimitSelection: Int = 1
    var bulletsRemaining: Int = 0
    var bulletCounterNode: SKNode?
    
    // Controls (if player-controlled)
    var fireButton: SKShapeNode?
    var thrustButton: SKShapeNode?
    var clusterTitleLabel: SKLabelNode?
    var isThrustingByPlayer: Bool = false
    var activeThrustTouches = Set<UITouch>()
    
    // UI
    var scoreNode: SKNode?
    var directionArrow: SKShapeNode?
    var distanceLabel: SKLabelNode?
    var targetIndicator: SKShapeNode?
    var bulletSliderTrack: SKShapeNode?
    var bulletSliderKnob: SKShapeNode?
    var aiSliderTrack: SKShapeNode?
    var aiSliderKnob: SKShapeNode?
}

// MARK: - GameScene

final class GameScene: SKScene {

    var lastLaidOutSize: CGSize = .zero

    var safeAreaTopInset:    CGFloat = 0
    var safeAreaBottomInset: CGFloat = 0

    enum EdgeBehavior { case bounce, wrap }
    var edgeBehavior: EdgeBehavior = .bounce

    var shipScores: [ObjectIdentifier: Int] = [:]
    var shipKillTimes: [ObjectIdentifier: TimeInterval] = [:]
    var shipStates: [ObjectIdentifier: ShipState] = [:]

    var optionsButton: SKShapeNode!
    var optionsOverlay: SKNode?
    var optionsVisible: Bool = false
    var optionsDimmer: SKShapeNode?

    enum OptionsTab { case game, environment, ships, about, shipSelection, network }
    var currentOptionsTab: OptionsTab = .environment

    var gameTabButton: SKShapeNode?
    var optionsTabButton: SKShapeNode?
    var shipsTabButton: SKShapeNode?
    var aboutTabButton: SKShapeNode?
    var shipSelectionTabButton: SKShapeNode?
    var networkTabButton: SKShapeNode?
    var shipSelectionContainer: SKNode?
    var networkContainer: SKNode?
    var aboutContainer: SKNode?

    let neuralAI = NeuralAIController()

    // Game options
    var aimPersistsAfterLift: Bool = true
    var aimPersistToggleButton: SKShapeNode?
    
    // Mystery Ship
    var mysteryShipEnabled: Bool = true
    var mysteryShipToggleButton: SKShapeNode?
    var mysteryShip: Ship?
    var mysteryShipSpawnTimer: TimeInterval = 0
    var mysteryShipLastRetargetTime: TimeInterval = 0
    let mysteryShipSpawnDelay: TimeInterval = 60.0
    let mysteryShipRetargetInterval: TimeInterval = 30.0

    var activeAimTouches = Set<UITouch>()

    var gameOverNeedleAILevel: Int = 0
    var gameOverDartAILevel:   Int = 0

    var gameOverFollowedShip: Ship?
    var gameOverLastSwitchTime: TimeInterval = 0
    var gameOverAnimationStartTime: TimeInterval = 0

    var gameOverLabelNode: SKNode?

    var sunEnabled: Bool = true
    var sunNode: SKShapeNode?
    let sunCollisionRadius: CGFloat = 28

    // Options UI elements
    var edgeBounceButton: SKShapeNode?
    var edgeWrapButton: SKShapeNode?
    var aiToggleButton: SKShapeNode?
    var wedgeAIToggleButton: SKShapeNode?

    var gravitySliderSelection: Int = 5
    let gravitySliderSteps:     Int = 10
    var gravitySliderTrack: SKShapeNode?
    var gravitySliderKnob:  SKShapeNode?
    var gravityValueLabel:  SKLabelNode?

    var bulletLifeSliderSelection: Int = 2
    let bulletLifeSliderSteps:     Int = 10
    var bulletLifeSliderTrack: SKShapeNode?
    var bulletLifeSliderKnob:  SKShapeNode?
    var bulletLifeValueLabel:  SKLabelNode?

    var gravityMultiplier: CGFloat { CGFloat(gravitySliderSelection) * 4.0 }
    var bulletLifeSeconds: CGFloat { 1.5 + CGFloat(bulletLifeSliderSelection) * 0.75 }

    // Bullet sliders
    var needleBulletSliderTrack: SKShapeNode?
    var dartBulletSliderTrack: SKShapeNode?
    var needleBulletSliderKnob: SKShapeNode?
    var dartBulletSliderKnob: SKShapeNode?
    let sliderTrackWidth: CGFloat = 200
    let sliderTrackHalfWidth: CGFloat = 100

    // AI intelligence sliders — FIX #9: 3 positions (steps=2)
    var needleAISliderTrack: SKShapeNode?
    var needleAISliderKnob: SKShapeNode?
    var wedgeAISliderTrack: SKShapeNode?
    var wedgeAISliderKnob: SKShapeNode?
    let aiIntelligenceSteps: Int = 2
    let aiIntelligenceTrackWidth: CGFloat = 200
    let aiIntelligenceTrackHalfWidth: CGFloat = 100

    // Slider drag touches
    var draggingNeedleSliderTouch: UITouch?
    var draggingDartSliderTouch: UITouch?
    var draggingNeedleAISliderTouch: UITouch?
    var draggingWedgeAISliderTouch: UITouch?
    var draggingVirtualScreenSliderTouch: UITouch?
    var draggingGravitySliderTouch: UITouch?
    var draggingBulletLifeSliderTouch: UITouch?
    var newMatchButtonTouch: UITouch?   // tracks press for invert-on-touch

    // Virtual screen mode
    enum VirtualScreenMode { case off, medium }
    var virtualScreenMode: VirtualScreenMode = .off
    var virtualScreenSelection: Int = 0   // 0=off 1=on
    let virtualScreenSteps: Int = 1
    var virtualScreenSliderTrack: SKShapeNode?
    var virtualScreenSliderKnob: SKShapeNode?
    var savedVirtualScreenSelection: Int = 0   // player's choice, preserved across game-over
    var virtualWorldWidth: CGFloat {
        switch virtualScreenMode {
        case .off:    return size.width
        case .medium: return max(3000, size.width)
        }
    }
    var virtualWorldHeight: CGFloat {
        switch virtualScreenMode {
        case .off:    return size.height
        case .medium: return max(3000, size.height)
        }
    }

    // Camera (always present; fixed in non-virtual mode, follows ship in virtual mode)
    var cameraNode = SKCameraNode()
    var cameraCenter: CGPoint = .zero
    var needleRespawnTarget: CGPoint = .zero
    var dartRespawnTarget: CGPoint = .zero
    var cameraPanToNeedleAfter: TimeInterval = 0
    var cameraPanToDartAfter:   TimeInterval = 0

    // In virtual mode: which ship the camera follows.
    // Release build always follows dart (wedge). Debug follows needle when only needle is human.
    var shipToFollow: Ship {
        #if DEBUG
        if !needleAIEnabled && wedgeAIEnabled { return needle }
        #endif
        return dart
    }

    // Stars + virtual boundary
    var starNodes: [SKShapeNode] = []
    var virtualBoundaryNode: SKShapeNode?

    // Direction arrows (shown when the other ship is off-screen in virtual mode)
    var needleDirectionArrow: SKShapeNode?
    var dartDirectionArrow:   SKShapeNode?
    var sunDirectionArrow:    SKShapeNode?   // always points to virtual world centre
    var mysteryShipDirectionArrow: SKShapeNode?  // points to Mystery Ship when off-screen
    var needleDistanceLabel:  SKLabelNode?   // distance readout beside needle edge arrow
    var dartDistanceLabel:    SKLabelNode?   // distance readout beside dart edge arrow

    // Cluster title labels
    var rightClusterTitle: SKLabelNode?
    #if DEBUG
    var leftClusterTitle: SKLabelNode?
    #endif

    var entities = [GKEntity]()
    var graphs = [String : GKGraph]()

    var lastUpdateTime: TimeInterval = 0

    var gameOver: Bool = false
    var victorLabelNode: SKNode?
    var enableRandomRespawn: Bool = false
    
    // Countdown timer
    var countdownActive: Bool = false
    var countdownStartTime: TimeInterval = 0
    var countdownContainerNode: SKNode?
    var lastDisplayedCountdownNumber: Int = -1
    
    // Ships
    var needle: Ship!
    var dart: Ship!
    
    // Generalized ship array for multi-ship support
    var ships: [Ship] = []

    // Fire buttons
    var fireThrustButton: SKShapeNode!
    #if DEBUG
    var leftFireButtonRef: SKShapeNode?
    #endif

    // Aiming / rotation
    var aimPoint: CGPoint?
    let aimEpsilon: CGFloat = 0.01

    // Two target indicators: needle = orange, dart/wedge = blue
    var needleTargetIndicator: SKShapeNode!
    var dartTargetIndicator: SKShapeNode!

    var rightThrustButton: SKShapeNode!
    #if DEBUG
    var leftThrustButton: SKShapeNode!
    #endif
    var isThrustingNeedle = false
    var isThrustingDart = false

    var activeRightThrustTouches = Set<UITouch>()
    #if DEBUG
    var activeLeftThrustTouches = Set<UITouch>()
    #endif

    struct FireTouchInfo {
        let ship: Ship
        let startTime: TimeInterval
        let startLocation: CGPoint
        weak var buttonNode: SKNode?
    }
    var fireTouches: [ObjectIdentifier: FireTouchInfo] = [:]

    var missileOwner = NSMapTable<SKNode, SKShapeNode>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    var missileSpawnTime = NSMapTable<SKNode, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    var wreckOwner = NSMapTable<SKNode, SKShapeNode>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    var wreckPieceCount = NSMapTable<SKNode, NSNumber>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    // MARK: - Layout

    func layoutForCurrentSize() {
        let s = self.size
        if s.width < 10 || s.height < 10 { return }
        if lastLaidOutSize == s { return }
        
        // Guard against layout being called before ships are initialized
        guard needle != nil, dart != nil else { return }
        
        lastLaidOutSize = s

        let vw = virtualWorldWidth, vh = virtualWorldHeight
        let newNeedleSpawn = CGPoint(x: vw * 0.20, y: vh * 0.5)
        let newDartSpawn   = CGPoint(x: vw * 0.80, y: vh * 0.5)

        let wasAtOrigin = needle.spawnPosition == .zero || needle.node.position == .zero
        needle.spawnPosition = newNeedleSpawn
        if wasAtOrigin && !needle.node.isHidden { needle.node.position = newNeedleSpawn }
        
        let dartWasAtOrigin = dart.spawnPosition == .zero || dart.node.position == .zero
        dart.spawnPosition = newDartSpawn
        if dartWasAtOrigin && !dart.node.isHidden { dart.node.position = newDartSpawn }

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
        // Scores are camera children, so they need to be positioned in camera space
        // This is handled by updateHUDPositions, not here
        optionsButton?.position = CGPoint(x: s.width / 2, y: topY)
        optionsOverlay?.position = CGPoint(x: s.width / 2, y: s.height / 2)

        sunNode?.position = CGPoint(x: virtualWorldWidth / 2, y: virtualWorldHeight / 2)
    }

    // MARK: - Lifecycle

    override func sceneDidLoad() {
        self.lastUpdateTime = 0
        self.backgroundColor = .black

        cameraCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        cameraNode.zPosition = 1000
        addChild(cameraNode)
        self.camera = cameraNode
        cameraNode.position = cameraCenter

        let needleSpawn = CGPoint(x: size.width * 0.20, y: size.height * 0.5)
        let dartSpawn   = CGPoint(x: size.width * 0.80, y: size.height * 0.5)

        needle = Ship(profile: .needle, flame: ShipProfile.needle.createFlameNode(), spawn: needleSpawn)
        dart   = Ship(profile: .dart,   flame: ShipProfile.dart.createFlameNode(), spawn: dartSpawn)
        
        ships = [needle, dart]
        
        let nowVisible = CACurrentMediaTime()
        let needleState = state(for: needle)
        needleState.visibleSince = nowVisible
        needleState.bulletLimitSelection = 1
        
        let dartState = state(for: dart)
        dartState.visibleSince = nowVisible
        dartState.bulletLimitSelection = 1

        addChild(needle.node)
        addChild(dart.node)

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

        // Scores - add to camera so they stay on screen
        let needleScoreNode = SKNode()
        let dartScoreNode = SKNode()
        // Position relative to camera (will be updated with safe area in didMove)
        needleScoreNode.position = CGPoint(x: -size.width/2 + 24, y: size.height/2 - 30 - safeAreaTopInset)
        needleScoreNode.zPosition = 80
        dartScoreNode.position = CGPoint(x: size.width/2 - 24, y: size.height/2 - 30 - safeAreaTopInset)
        dartScoreNode.zPosition = 80
        cameraNode.addChild(needleScoreNode)
        cameraNode.addChild(dartScoreNode)
        needle.scoreNode = needleScoreNode
        dart.scoreNode = dartScoreNode
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
        
        // Start countdown timer when game first loads
        startCountdown()
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

    func updateNeedleControlsVisibility() {
        #if DEBUG
        leftThrustButton?.isHidden = needleAIEnabled
        leftFireButtonRef?.isHidden = needleAIEnabled
        // leftClusterTitle stays visible: it labels the bullet counter which is always shown
        #endif
    }

    func updateWedgeControlsVisibility() {
        fireThrustButton?.isHidden = wedgeAIEnabled
        rightThrustButton?.isHidden = wedgeAIEnabled
    }

    func setOptionsVisible(_ show: Bool) {
        optionsVisible = show
        optionsOverlay?.isHidden = !show
        optionsDimmer?.isHidden = !show
    }



    // MARK: - Generalized Ship Management
    
    /// Gets or creates the state object for a ship.
    /// Internal (not private) so it's accessible from GameScene+AI extension.
    func state(for ship: Ship) -> ShipState {
        let key = ObjectIdentifier(ship.node)
        if let existing = shipStates[key] {
            return existing
        }
        let newState = ShipState()
        shipStates[key] = newState
        return newState
    }
    
    /// Legacy accessor for needle state (backward compatibility)
    var needleState: ShipState { state(for: needle) }
    
    /// Legacy accessor for dart state (backward compatibility)
    var dartState: ShipState { state(for: dart) }
    
    // Legacy accessors for needle AI
    var needleAIEnabled: Bool {
        get { needleState.aiEnabled }
        set { needleState.aiEnabled = newValue }
    }
    
    var needleAIIntelligence: Int {
        get { needleState.aiIntelligence }
        set { needleState.aiIntelligence = newValue }
    }
    
    // Legacy accessors for dart/wedge AI
    var wedgeAIEnabled: Bool {
        get { dartState.aiEnabled }
        set { dartState.aiEnabled = newValue }
    }
    
    var wedgeAIIntelligence: Int {
        get { dartState.aiIntelligence }
        set { dartState.aiIntelligence = newValue }
    }
    
    // Bullet limit accessors
    var needleBulletLimitSelection: Int {
        get { needleState.bulletLimitSelection }
        set { needleState.bulletLimitSelection = newValue }
    }
    
    var dartBulletLimitSelection: Int {
        get { dartState.bulletLimitSelection }
        set { dartState.bulletLimitSelection = newValue }
    }
    
    let bulletSliderSteps: Int = 2
    
    var needleBulletsRemaining: Int {
        get { needleState.bulletsRemaining }
        set { needleState.bulletsRemaining = newValue }
    }
    
    var dartBulletsRemaining: Int {
        get { dartState.bulletsRemaining }
        set { dartState.bulletsRemaining = newValue }
    }
    
    var needleBulletCounterNode: SKNode? {
        get { needleState.bulletCounterNode }
        set { needleState.bulletCounterNode = newValue }
    }
    
    var dartBulletCounterNode: SKNode? {
        get { dartState.bulletCounterNode }
        set { dartState.bulletCounterNode = newValue }
    }
    
    private func incrementScore(for ship: Ship) {
        ship.score += 1
        updateScoreDisplays()
    }
    
    private func recordKillTime(for ship: Ship, at time: TimeInterval) {
        let key = ObjectIdentifier(ship.node)
        shipKillTimes[key] = time
    }
    
    func getKillTime(for ship: Ship) -> TimeInterval {
        let key = ObjectIdentifier(ship.node)
        return shipKillTimes[key] ?? 0
    }

    // MARK: - Missiles

    func fireMissile(from ship: Ship, muzzleOffset: CGPoint) {
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
        guard ship.isVisible else { return }
        
        enableRandomRespawn = true
        let originalVelocity = ship.velocity

        let now = CACurrentMediaTime()
        let st = state(for: ship)
        st.destroyTime = now

        let respawnPos = (enableRandomRespawn ? safeRandomPosition(avoiding: ship) : nil) ?? ship.spawnPosition
        let panDelay: TimeInterval = virtualScreenMode != .off ? 2.0 : 1.0
        
        st.respawnTarget = respawnPos
        st.cameraPanAfter = now + panDelay

        ship.hide()
        
        // Reset mystery ship spawn timer on ANY explosion of needle or dart
        // (regardless of who killed them)
        if ship === needle || ship === dart {
            mysteryShipSpawnTimer = 0
        }

        if gameOver {
            if ship === needle { gameOverNeedleAILevel = Int.random(in: 0...2) }
            else               { gameOverDartAILevel   = Int.random(in: 0...2) }

            let survivor = (ship === needle) ? dart : needle
            if now - gameOverLastSwitchTime > 2.0 {
                gameOverFollowedShip = survivor
                gameOverLastSwitchTime = now
            }
        }

        let pieces = ship.createDebrisPieces()

        let lifetime: CGFloat = 1.5  // Reduced from 2.6 to 1.5 seconds
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
        
        // Handle Mystery Ship special case
        if ship === mysteryShip {
            explodeMysteryShip(at: ship.node.position, velocity: originalVelocity)
        }
    }
    
    // MARK: - Mystery Ship
    
    private func updateMysteryShipSpawning(currentTime: TimeInterval) {
        guard mysteryShipEnabled else { return }
        
        // Check if both main ships are visible
        let bothShipsAlive = !needle.node.isHidden && !dart.node.isHidden
        
        if bothShipsAlive {
            mysteryShipSpawnTimer += (currentTime - lastUpdateTime)
        }
        
        // Spawn Mystery Ship if timer reached and no mystery ship exists
        if mysteryShipSpawnTimer >= mysteryShipSpawnDelay && mysteryShip == nil {
            spawnMysteryShip(currentTime: currentTime)
        }
        
        // Update AI retargeting if 3+ ships present
        if ships.count >= 3 && currentTime - mysteryShipLastRetargetTime >= mysteryShipRetargetInterval {
            retargetAllAI(currentTime: currentTime)
            mysteryShipLastRetargetTime = currentTime
        }
    }
    
    private func spawnMysteryShip(currentTime: TimeInterval) {
        // Create mystery ship at random position
        let randomPos = CGPoint(
            x: CGFloat.random(in: 100...(virtualWorldWidth - 100)),
            y: CGFloat.random(in: 100...(virtualWorldHeight - 100))
        )
        
        let mystery = Ship(
            profile: .mysteryShip,
            flame: ShipProfile.mysteryShip.createFlameNode(),
            spawn: randomPos
        )
        
        mysteryShip = mystery
        ships.append(mystery)
        addChild(mystery.node)
        
        // Set up AI with random intelligence
        let mysteryState = state(for: mystery)
        mysteryState.aiEnabled = true
        mysteryState.aiIntelligence = Int.random(in: 0...2)
        mysteryState.visibleSince = currentTime
        mysteryState.bulletLimitSelection = 1
        
        // Create direction arrow for Mystery Ship
        let p = mystery.profile
        let ptr = SKShapeNode(path: p.indicatorPath)
        ptr.strokeColor = p.indicatorColor
        ptr.fillColor = .clear
        ptr.lineWidth = p.indicatorLineWidth
        ptr.glowWidth = p.indicatorGlowWidth
        ptr.alpha = 0
        ptr.zPosition = 90
        ptr.name = "dirArrow"
        addChild(ptr)
        mysteryShipDirectionArrow = ptr
        
        // Reset spawn timer
        mysteryShipSpawnTimer = 0
        
        // Trigger retargeting for all AI
        retargetAllAI(currentTime: currentTime)
        mysteryShipLastRetargetTime = currentTime
        
        print("🛸 Mystery Ship spawned at \(randomPos) with AI level \(mysteryState.aiIntelligence)")
    }
    
    private func despawnMysteryShip() {
        guard let mystery = mysteryShip else { return }
        
        mystery.node.removeFromParent()
        ships.removeAll { $0 === mystery }
        
        // Remove state
        shipStates.removeValue(forKey: ObjectIdentifier(mystery.node))
        
        // Remove direction arrow
        mysteryShipDirectionArrow?.removeFromParent()
        mysteryShipDirectionArrow = nil
        
        mysteryShip = nil
        mysteryShipSpawnTimer = 0
        
        print("🛸 Mystery Ship despawned")
    }
    
    private func explodeMysteryShip(at position: CGPoint, velocity: CGVector) {
        // Award random bonus points (2-10) to the killer
        // The killer will be determined by checking which ship's bullet hit it
        // For now, we'll display the bonus at the explosion site
        
        // Mystery ship will respawn after timer if toggle is still on
        // The normal explodeShip already removed it, so just clean up
        ships.removeAll { $0 === mysteryShip }
        mysteryShip = nil
        mysteryShipSpawnTimer = 0
        
        print("💥 Mystery Ship destroyed!")
    }
    
    private func awardMysteryShipBonus(to ship: Ship, at position: CGPoint) {
        let bonusPoints = Int.random(in: 2...10)
        ship.score += bonusPoints
        updateScoreDisplays()
        
        // Display bonus points at explosion site with 5-second fade
        displayBonusPoints(bonusPoints, at: position)
        
        print("⭐ \(ship.profile.typeName) earned \(bonusPoints) bonus points from Mystery Ship!")
    }
    
    private func displayBonusPoints(_ points: Int, at position: CGPoint) {
        let bonusNode = VectorTextRenderer.makeScoreNode(score: points, scale: 2.0, spacing: 16)
        bonusNode.position = position
        bonusNode.zPosition = 100
        bonusNode.alpha = 1.0
        addChild(bonusNode)
        
        // Fade out over 5 seconds
        let fadeAction = SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ])
        bonusNode.run(fadeAction)
    }
    
    private func retargetAllAI(currentTime: TimeInterval) {
        // When 3+ ships present, all AI should target whichever ship is closest
        guard ships.count >= 3 else { return }
        
        for ship in ships {
            let st = state(for: ship)
            guard st.aiEnabled else { continue }
            
            // Find closest opponent
            var closestShip: Ship?
            var closestDist: CGFloat = .greatestFiniteMagnitude
            
            for otherShip in ships {
                guard otherShip !== ship, !otherShip.node.isHidden else { continue }
                
                let dx = otherShip.node.position.x - ship.node.position.x
                let dy = otherShip.node.position.y - ship.node.position.y
                let dist = sqrt(dx*dx + dy*dy)
                
                if dist < closestDist {
                    closestDist = dist
                    closestShip = otherShip
                }
            }
            
            // Store target (we'll need to modify AI logic to use this)
            // For now, the AI will continue using its default opponent
            // but we've set up the retargeting infrastructure
        }
        
        print("🎯 AI retargeting complete (3+ ships present)")
    }

    // MARK: - Match control

    private func restoreNewMatchButton() {
        guard let overlay = optionsOverlay,
              let btn = overlay.childNode(withName: "game_new_match") as? SKShapeNode else { return }
        btn.fillColor = .clear; btn.strokeColor = .white
        btn.children.compactMap { $0 as? SKLabelNode }.forEach { $0.fontColor = .white }
    }

    private func startNewMatch() {
        needle.score = 0
        dart.score = 0
        updateScoreDisplays()
        enableRandomRespawn = false
        needle.reset(); dart.reset()
        
        // Despawn Mystery Ship if present
        if mysteryShip != nil {
            despawnMysteryShip()
        }
        
        let now = CACurrentMediaTime()
        needleState.visibleSince = now
        dartState.visibleSince = now
        needleState.destroyTime = 0
        dartState.destroyTime = 0
        needleState.respawnScheduled = false
        dartState.respawnScheduled = false
        needleState.respawnTarget = .zero
        dartState.respawnTarget = .zero
        needleState.cameraPanAfter = 0
        dartState.cameraPanAfter = 0
        
        shipKillTimes.removeAll()
        
        resetBulletCountsFromSelections()
        
        needleState.aiNextThrustToggle = 0
        needleState.aiNextFireTime = 0
        needleState.aiThrustOn = false
        needleState.aiCertainFireCooldown = 0
        needleState.smoothedAcceleration = .zero
        needleState.previousVelocity = .zero
        needleState.observedAcceleration = .zero
        
        dartState.aiNextThrustToggle = 0
        dartState.aiNextFireTime = 0
        dartState.aiThrustOn = false
        dartState.aiCertainFireCooldown = 0
        dartState.smoothedAcceleration = .zero
        dartState.previousVelocity = .zero
        dartState.observedAcceleration = .zero
        
        enumerateChildNodes(withName: "missile") { n, _ in n.removeFromParent() }
        enumerateChildNodes(withName: "wreckPiece") { n, _ in n.removeFromParent() }
        gameOver = false
        gameOverFollowedShip = nil
        gameOverLastSwitchTime = 0
        gameOverAnimationStartTime = 0
        victorLabelNode?.removeFromParent(); victorLabelNode = nil
        gameOverLabelNode?.removeFromParent(); gameOverLabelNode = nil
        
        virtualScreenSelection = savedVirtualScreenSelection
        virtualScreenMode = virtualScreenSelection == 0 ? .off : .medium
        applyVirtualScreenMode()

        updateNeedleControlsVisibility()
        updateWedgeControlsVisibility()
        if virtualScreenMode != .off {
            let follow = shipToFollow
            cameraCenter = follow.node.isHidden ? follow.spawnPosition : follow.node.position
            cameraNode.position = cameraCenter
        }
        refreshOptionsUI()
        
        startCountdown()
    }

    // MARK: - Score rendering

    func updateScoreDisplays() {
        // Completely recreate the score nodes to ensure clean slate
        needle.scoreNode?.removeFromParent()
        dart.scoreNode?.removeFromParent()
        
        // Create fresh score node containers WITH POSITIONS
        let needleScoreNode = SKNode()
        let dartScoreNode = SKNode()
        needleScoreNode.zPosition = 80
        dartScoreNode.zPosition = 80
        
        // Set positions BEFORE adding to camera to prevent flash at (0,0)
        needleScoreNode.position = CGPoint(x: -size.width/2 + 24, y: size.height/2 - 30 - safeAreaTopInset)
        dartScoreNode.position = CGPoint(x: size.width/2 - 24, y: size.height/2 - 30 - safeAreaTopInset)
        
        // Add to camera
        cameraNode.addChild(needleScoreNode)
        cameraNode.addChild(dartScoreNode)
        
        // Update references
        needle.scoreNode = needleScoreNode
        dart.scoreNode = dartScoreNode
        
        let left = VectorTextRenderer.makeScoreNode(score: needle.score)
        let right = VectorTextRenderer.makeScoreNode(score: dart.score)
        
        // Ship 1 (needle) - align left from scoreNode position
        left.position = .zero
        
        // Ship 2 (dart) - align right from scoreNode position
        // Calculate width manually: numDigits * digitWidth + (numDigits - 1) * spacing, all scaled
        let scale: CGFloat = 1.2  // Default scale from makeScoreNode
        let digitWidth: CGFloat = 10
        let spacing: CGFloat = 12
        let numDigits = max(1, String(dart.score).count)
        let rightWidth = (CGFloat(numDigits) * digitWidth + CGFloat(numDigits - 1) * spacing) * scale
        right.position = CGPoint(x: -rightWidth, y: 0)
        
        needleScoreNode.addChild(left)
        dartScoreNode.addChild(right)
        
        // Ensure positions are correct in camera space
        updateHUDPositions()
    }
    
    // MARK: - Countdown Timer
    
    private func startCountdown() {
        countdownActive = true
        countdownStartTime = CACurrentMediaTime()
        lastDisplayedCountdownNumber = -1

        needle.node.isHidden = false
        needle.node.position = needle.spawnPosition
        needle.node.zRotation = 0
        needle.velocity = .zero
        needle.flame.alpha = 0
        if needle.profile.headDotRadius > 0 {
            needle.node.childNode(withName: "needleHeadDot")?.alpha = 1
        }
        
        dart.node.isHidden = false
        dart.node.position = dart.spawnPosition
        dart.node.zRotation = 0
        dart.velocity = .zero
        dart.flame.alpha = 0
        
        isThrustingNeedle = false
        isThrustingDart = false
        needleState.aiThrustOn = false
        dartState.aiThrustOn = false

        if countdownContainerNode == nil {
            let container = SKNode()
            container.zPosition = 1000
            cameraNode.addChild(container)  // Add to camera, not scene
            countdownContainerNode = container
        }
        // Position relative to camera center (which is at 0,0 in camera space)
        countdownContainerNode!.position = CGPoint(x: 0, y: size.height * 0.28)
    }
    
    private func updateCountdown(currentTime: TimeInterval) {
        guard countdownActive else { return }

        let elapsed  = currentTime - countdownStartTime
        let remaining = 5 - Int(elapsed)

        if remaining > 0 {
            // Position is already set relative to camera (0, height*0.28)
            // No need to reposition every frame since it's a camera child

            if remaining != lastDisplayedCountdownNumber {
                lastDisplayedCountdownNumber = remaining
                countdownContainerNode?.removeAllChildren()

                let scale: CGFloat   = 3.0
                let spacing: CGFloat = 5.0
                let text = "\(remaining)"
                let w    = VectorTextRenderer.vectorWordWidth(text, scale: scale, spacing: spacing)
                let node = VectorTextRenderer.makeVectorWordNode(text, scale: scale, spacing: spacing)
                node.position = CGPoint(x: -w / 2, y: 0)
                countdownContainerNode?.addChild(node)

                countdownContainerNode?.setScale(1.35)
                countdownContainerNode?.run(.scale(to: 1.0, duration: 0.18))
            }
        } else {
            countdownActive = false
            countdownContainerNode?.removeFromParent()
            countdownContainerNode = nil
            lastDisplayedCountdownNumber = -1
            
            // Start Mystery Ship spawn timer when countdown ends
            mysteryShipSpawnTimer = 0
        }
    }
    
    // MARK: - Bullet counts

    func bulletsForSelection(_ sel: Int) -> Int? {
        switch sel {
        case 0: return 10
        case 1: return 50
        default: return nil
        }
    }

    func bulletLabelText(_ selection: Int, for ship: Ship) -> String {
        guard let base = bulletsForSelection(selection) else { return "∞" }
        let multiplied = Int(CGFloat(base) * ship.profile.inventory.multiplier)
        return "\(multiplied)"
    }

    func resetBulletCountsFromSelections() {
        // Apply inventory multiplier from ship profile
        if let baseNeedle = bulletsForSelection(needleBulletLimitSelection) {
            needleBulletsRemaining = Int(CGFloat(baseNeedle) * needle.profile.inventory.multiplier)
        } else {
            needleBulletsRemaining = Int.max
        }
        
        if let baseDart = bulletsForSelection(dartBulletLimitSelection) {
            dartBulletsRemaining = Int(CGFloat(baseDart) * dart.profile.inventory.multiplier)
        } else {
            dartBulletsRemaining = Int.max
        }
        
        refreshBulletCounters()
    }

    private func makeInfinityNode() -> SKNode { 
        VectorTextRenderer.makeVectorInfinityNode(scale: 0.85) 
    }

    private func refreshBulletCounters() {
        let bulletScale: CGFloat = 0.85
        let bulletSpacing: CGFloat = 3
        func setCounter(_ node: SKNode?, count: Int) {
            guard let node else { return }
            node.removeAllChildren()
            let content: SKNode
            if count == Int.max {
                content = VectorTextRenderer.makeVectorInfinityNode(scale: bulletScale)
                // Centre: native space is 20×10, so offset by half at scale
                content.position = CGPoint(x: -10 * bulletScale, y: -5 * bulletScale)
            } else {
                content = VectorTextRenderer.makeVectorWordNode("\(count)", scale: bulletScale, spacing: bulletSpacing, bright: true)
                let w = VectorTextRenderer.vectorWordWidth("\(count)", scale: bulletScale, spacing: bulletSpacing)
                content.position = CGPoint(x: -w / 2, y: -6 * bulletScale)
            }
            node.addChild(content)
        }
        setCounter(dartBulletCounterNode, count: dartBulletsRemaining)
        #if DEBUG
        setCounter(needleBulletCounterNode, count: needleBulletsRemaining)
        #endif
    }

    func endGameIfNoBullets() {
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

        let now = CACurrentMediaTime()
        gameOverAnimationStartTime = now + 5.0

        showVictorLabel(); showGameOverLabel()
        fireThrustButton?.isHidden  = true
        rightThrustButton?.isHidden = true
        #if DEBUG
        leftFireButtonRef?.isHidden = true
        leftThrustButton?.isHidden  = true
        #endif
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
        let scale: CGFloat = 1.2; let spacing: CGFloat = 5
        if needle.score == dart.score {
            for (text, cx) in [("TIE", needleCX), ("TIE", dartCX)] {
                let w = VectorTextRenderer.vectorWordWidth(text, scale: scale, spacing: spacing)
                let node = VectorTextRenderer.makeVectorWordNode(text, scale: scale, spacing: spacing)
                node.position = CGPoint(x: cx - w/2, y: labelY); container.addChild(node)
            }
        } else {
            let w = VectorTextRenderer.vectorWordWidth("WINNER", scale: scale, spacing: spacing)
            let word = VectorTextRenderer.makeVectorWordNode("WINNER", scale: scale, spacing: spacing)
            let edgeInset: CGFloat = 12
            let startX: CGFloat = needle.score > dart.score
                ? -sw/2 + edgeInset
                : sw/2 - edgeInset - w
            word.position = CGPoint(x: startX, y: labelY); container.addChild(word)
        }
    }

    private func showGameOverLabel() {
        gameOverLabelNode?.removeFromParent()
        let text = "GAME OVER", scale: CGFloat = 2.4, spacing: CGFloat = 5
        let phrase = VectorTextRenderer.makeVectorWordNode(text, scale: scale, spacing: spacing)
        phrase.zPosition = 80
        let w = VectorTextRenderer.vectorWordWidth(text, scale: scale, spacing: spacing)
        phrase.position = CGPoint(x: -w/2, y: size.height / 6)
        cameraNode.addChild(phrase); gameOverLabelNode = phrase
    }

    // MARK: - Stars, boundary, camera, arrows

    private func setupStars() {
        for s in starNodes { s.removeFromParent() }
        starNodes.removeAll()
        let vw = virtualWorldWidth, vh = virtualWorldHeight
        let refW: CGFloat = 3000, refH: CGFloat = 3000
        for (ra, dec, mag) in StarfieldData.nycStarData {
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

    func setupDirectionArrows() {
        // Remove any existing pointers
        needleDirectionArrow?.removeFromParent()
        dartDirectionArrow?.removeFromParent()
        sunDirectionArrow?.removeFromParent()
        mysteryShipDirectionArrow?.removeFromParent()
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
    func applyVirtualScreenMode() {
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
        if virtualScreenMode == .off {
            cameraCenter = CGPoint(x: size.width / 2, y: size.height / 2)
            cameraNode.position = cameraCenter
            updateHUDPositions()  // Still need to position HUD elements
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
            let st = state(for: followed)
            let respawnPt = st.respawnTarget
            let panAfter = st.cameraPanAfter
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
        let topY    = sh/2 - 30 - safeAreaTopInset
        let bottomY = -sh/2 + safeAreaBottomInset
        let br: CGFloat = 40
        let padding: CGFloat = 12

        // Scores are camera children, so position relative to camera center (0,0)
        needle.scoreNode?.position = CGPoint(x: -sw/2 + 24, y: topY)
        dart.scoreNode?.position = CGPoint(x: sw/2 - 24, y: topY)
        
        // Options button is a scene child, so use world coordinates
        optionsButton?.position = CGPoint(x: cx, y: cy + topY)
        optionsOverlay?.position = CGPoint(x: cx, y: cy)

        let fireX = cx + sw/2 - br - 20
        let fireY = cy + bottomY + br + 20
        fireThrustButton?.position  = CGPoint(x: fireX, y: fireY)
        rightThrustButton?.position = CGPoint(x: fireX - (br * 2 + padding), y: fireY)

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
            mysteryShipDirectionArrow?.alpha = 0
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

        // --- Dart pointer + distance label ---
        if dart.node.isHidden {
            dartDirectionArrow?.alpha = 0
            dartDistanceLabel?.alpha  = 0
        } else if positionPointer(dartDirectionArrow, towardPoint: dart.node.position) {
            dartDirectionArrow?.zRotation = dart.node.zRotation
            dartDirectionArrow?.alpha = 0.85
            // Show distance readout when dart is off-screen
            if let arrowPos = dartDirectionArrow?.position {
                let dist = hypot(dart.node.position.x - needle.node.position.x,
                                  dart.node.position.y - needle.node.position.y)
                dartDistanceLabel?.text = "\(Int(dist.rounded()))"
                dartDistanceLabel?.position = CGPoint(x: arrowPos.x + 24, y: arrowPos.y + 16)
                dartDistanceLabel?.alpha = 0.85
            }
        } else {
            dartDistanceLabel?.alpha = 0
        }
        
        // --- Mystery Ship pointer ---
        if let mystery = mysteryShip, !mystery.node.isHidden {
            if positionPointer(mysteryShipDirectionArrow, towardPoint: mystery.node.position) {
                mysteryShipDirectionArrow?.zRotation = mystery.node.zRotation
                mysteryShipDirectionArrow?.alpha = 0.7
            }
        } else {
            mysteryShipDirectionArrow?.alpha = 0
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

    // MARK: - Sun

    func applySunState() {
        // Sun appears when gravity is enabled (slider > 0)
        if gravitySliderSelection > 0 {
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
        let st = state(for: ship)
        
        // Always try to find a new safe random position if random respawn is enabled
        // This ensures we don't get stuck with a stale respawnTarget that's now occupied
        let pos: CGPoint
        if enableRandomRespawn, let p = safeRandomPosition(avoiding: ship) {
            pos = p
        } else if st.respawnTarget != .zero {
            pos = st.respawnTarget
        } else {
            pos = ship.spawnPosition
        }
        
        let otherShip: Ship = (ship === needle) ? dart! : needle!
        if !otherShip.node.isHidden {
            let dx = pos.x - otherShip.node.position.x
            let dy = pos.y - otherShip.node.position.y
            let dist = sqrt(dx*dx + dy*dy)
            let minSafeDist: CGFloat = 300
            if dx*dx + dy*dy < minSafeDist*minSafeDist {
                // Don't respawn yet - too close to other ship
                // Keep the original destroyTime so the respawn timer continues from when ship exploded
                // Clear the stale respawnTarget so we try a new position next time
                st.respawnTarget = .zero
                st.respawnScheduled = true
                return
            }
        }
        
        ship.node.position = pos
        ship.node.zRotation = 0
        ship.velocity = .zero
        ship.show()
        // Clear respawnTarget after successful respawn
        st.respawnTarget = .zero
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime

        updateCamera(currentTime: currentTime, dt: dt)
        
        if countdownActive {
            updateCountdown(currentTime: currentTime)
            needleTargetIndicator.alpha = 0
            dartTargetIndicator.alpha = 0
            lastUpdateTime = currentTime
            return
        }

        if optionsVisible {
            needleTargetIndicator.alpha = 0
            dartTargetIndicator.alpha = 0
            // Pause mystery ship spawn timer when options are open
            lastUpdateTime = currentTime
            return
        }
        
        // Update Mystery Ship spawn timer
        updateMysteryShipSpawning(currentTime: currentTime)

        for entity in entities { entity.update(deltaTime: dt) }

        let respawnBulletLife = bulletLifeSeconds
        for ship in ships {
            let st = state(for: ship)
            if st.respawnScheduled && ship.node.isHidden {
                let elapsed = currentTime - st.destroyTime
                if currentTime - st.destroyTime >= respawnBulletLife {
                    st.respawnScheduled = false
                    respawnShip(ship)
                    st.visibleSince = currentTime
                }
            }
        }

        if !gameOver || currentTime >= gameOverAnimationStartTime {

        if gameOver && virtualScreenMode != .medium {
            virtualScreenSelection = 1
            virtualScreenMode = .medium
            applyVirtualScreenMode()
        }

        if gameOver {
            needleAIEnabled       = true
            needleAIIntelligence  = gameOverNeedleAILevel
            wedgeAIEnabled        = true
            wedgeAIIntelligence   = gameOverDartAILevel
            if needleBulletsRemaining < Int.max / 2 { needleBulletsRemaining = Int.max }
            if dartBulletsRemaining   < Int.max / 2 { dartBulletsRemaining   = Int.max }
        }

        do {
            if !needle.node.isHidden {
                if needleAIEnabled {
                    isThrustingNeedle = updateShipAI(
                        ship: needle,
                        opponent: dart,
                        currentTime: currentTime,
                        dt: dt)
                } else if let p = aimPoint {
                    rotateShip(needle, toward: p, dt: dt)
                }
            }
            
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
                        if action.fire && currentTime >= dartState.aiNextFireTime {
                            fireMissile(from: dart, muzzleOffset: dart.muzzleOffset())
                            dartState.aiNextFireTime = currentTime + 0.1
                        }
                    } else {
                        isThrustingDart = updateShipAI(
                            ship: dart,
                            opponent: needle,
                            currentTime: currentTime,
                            dt: dt)
                    }
                } else if let p = aimPoint {
                    rotateShip(dart, toward: p, dt: dt)
                }
            }

            if isThrustingDart {
                dart.applyThrust(dt: CGFloat(dt)); dart.flame.alpha = 1
            } else { dart.flame.alpha = 0 }

            if isThrustingNeedle {
                needle.applyThrust(dt: CGFloat(dt)); needle.flame.alpha = 1
            } else { needle.flame.alpha = 0 }
            
            // Update Mystery Ship AI if present
            if let mystery = mysteryShip, !mystery.node.isHidden {
                let mysteryState = state(for: mystery)
                if mysteryState.aiEnabled {
                    // Mystery Ship targets the closest visible ship
                    var closestShip: Ship?
                    var closestDist: CGFloat = .greatestFiniteMagnitude
                    
                    for ship in [needle!, dart!] {
                        guard !ship.node.isHidden else { continue }
                        let dx = ship.node.position.x - mystery.node.position.x
                        let dy = ship.node.position.y - mystery.node.position.y
                        let dist = hypot(dx, dy)
                        if dist < closestDist {
                            closestDist = dist
                            closestShip = ship
                        }
                    }
                    
                    if let target = closestShip {
                        let mysteryThrusting = updateShipAI(
                            ship: mystery,
                            opponent: target,
                            currentTime: currentTime,
                            dt: dt)
                        
                        if mysteryThrusting {
                            mystery.applyThrust(dt: CGFloat(dt))
                            mystery.flame.alpha = 1
                        } else {
                            mystery.flame.alpha = 0
                        }
                    }
                }
            }

        }

        }

        if let sun = sunNode {
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

            enumerateChildNodes(withName: "missile") { node, _ in
                guard let data = node.userData,
                      var vx = data["vx"] as? CGFloat,
                      var vy = data["vy"] as? CGFloat else { return }
                let dx = sun.position.x - node.position.x
                let dy = sun.position.y - node.position.y
                let r2 = dx*dx + dy*dy + 100
                let invR = 1.0 / sqrt(r2)
                let G: CGFloat = 18000 * self.gravityMultiplier * (7.0 / 8.0)
                let a = G / r2
                vx += dx * invR * a * CGFloat(dt); vy += dy * invR * a * CGFloat(dt)
                node.userData?["vx"] = vx; node.userData?["vy"] = vy
            }
        }

        dart.clampSpeed(); needle.clampSpeed()
        dart.integrate(dt: CGFloat(dt)); needle.integrate(dt: CGFloat(dt))
        
        // Update Mystery Ship physics if present
        if let mystery = mysteryShip, !mystery.node.isHidden {
            mystery.clampSpeed()
            mystery.integrate(dt: CGFloat(dt))
        }

        if dt > 0 {
            for ship in ships {
                let st = state(for: ship)
                st.observedAcceleration = CGVector(
                    dx: (ship.velocity.dx - st.previousVelocity.dx) / CGFloat(dt),
                    dy: (ship.velocity.dy - st.previousVelocity.dy) / CGFloat(dt))
                let α: CGFloat = 0.08
                st.smoothedAcceleration = CGVector(
                    dx: st.smoothedAcceleration.dx + α * (st.observedAcceleration.dx - st.smoothedAcceleration.dx),
                    dy: st.smoothedAcceleration.dy + α * (st.observedAcceleration.dy - st.smoothedAcceleration.dy))
                st.previousVelocity = ship.velocity
            }
        }

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
        // Handle Mystery Ship edges too
        if let mystery = mysteryShip, !mystery.node.isHidden {
            handleEdges(mystery)
        }

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
                        let bulletLife = self.bulletLifeSeconds
                        
                        let ship = (owner === self.needle.node) ? self.needle : self.dart
                        let st = self.state(for: ship!)
                        
                        let destroyTime = st.destroyTime
                        let elapsed = currentTime - destroyTime
                        let readyToRespawn = elapsed >= bulletLife

                        if readyToRespawn {
                            self.respawnShip(ship!)
                            st.visibleSince = currentTime
                        } else {
                            st.respawnScheduled = true
                        }
                    }
                }
                node.removeFromParent()
            }
        }

        if let sun = sunNode {
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
                    if !gameOver { incrementScore(for: dart) }
                    explodeShip(ship: needle)
                }
            }
            if !dart.node.isHidden {
                let dx = dart.node.position.x - sun.position.x
                let dy = dart.node.position.y - sun.position.y
                if dx*dx + dy*dy <= sunCollisionRadius*sunCollisionRadius {
                    if !gameOver { incrementScore(for: needle) }
                    explodeShip(ship: dart)
                }
            }
            // Mystery Ship sun collision (no bonus points)
            if let mystery = mysteryShip, !mystery.node.isHidden {
                let dx = mystery.node.position.x - sun.position.x
                let dy = mystery.node.position.y - sun.position.y
                if dx*dx + dy*dy <= sunCollisionRadius*sunCollisionRadius {
                    explodeShip(ship: mystery)
                }
            }
        }

        var needleHit = false, dartHit = false
        let now = CACurrentMediaTime()
        
        // New generalized collision detection
        var shipsHit: Set<ObjectIdentifier> = []  // Track which ships were hit this frame
        
        // Bullet vs Ship collisions
        var mysteryShipKiller: Ship?  // Track who killed the Mystery Ship
        
        enumerateChildNodes(withName: "missile") { node, _ in
            guard let owner = self.missileOwner.object(forKey: node),
                  let spawn = self.missileSpawnTime.object(forKey: node)?.doubleValue else { return }
            
            let bounced = (node.userData?["bounced"] as? Bool) ?? false
            let grace = (!bounced) && (now - spawn < 1.0)
            
            // Check collision with ALL ships
            for ship in self.ships {
                let shipKey = ObjectIdentifier(ship.node)
                guard !ship.node.isHidden,
                      !shipsHit.contains(shipKey),  // Don't hit same ship twice in one frame
                      node.frame.intersects(ship.node.frame) else { continue }
                
                // Apply grace period: skip if owner shot itself within 1 second
                if owner === ship.node && grace { continue }
                
                // Determine which ship fired this bullet and get its bullet power
                let shooterShip = self.ships.first { $0.node === owner }
                let damage = shooterShip?.profile.bulletPower.damage ?? 1.0
                
                // Determine if hit was from rear (bullet came from behind the ship)
                // Ship's forward direction is along its zRotation + π/2
                let shipForward = ship.node.zRotation + .pi / 2
                // Calculate angle FROM ship TO bullet
                let dx = node.position.x - ship.node.position.x
                let dy = node.position.y - ship.node.position.y
                let hitAngle = atan2(dy, dx)
                var angleDiff = hitAngle - shipForward
                // Normalize to [-π, π]
                while angleDiff > .pi { angleDiff -= 2 * .pi }
                while angleDiff < -.pi { angleDiff += 2 * .pi }
                // Hit is from rear if bullet is within ±90° of directly BEHIND ship (at π radians from forward)
                // angleDiff ≈ 0 means bullet is in front; angleDiff ≈ ±π means bullet is behind
                let fromRear = abs(angleDiff) > .pi / 2
                
                // Apply damage
                let destroyed = ship.takeDamage(damage, fromRear: fromRear)
                
                // Remove the bullet
                node.removeFromParent()
                
                // If ship is destroyed, mark it for explosion
                if destroyed {
                    shipsHit.insert(shipKey)
                    
                    // Track Mystery Ship killer for bonus points
                    // Only award bonus if killer is needle or dart (not self-inflicted)
                    if ship === self.mysteryShip, let shooter = shooterShip {
                        if shooter === self.needle || shooter === self.dart {
                            mysteryShipKiller = shooter
                        }
                    }
                    
                    // Update legacy hit flags for backward compatibility
                    if ship === self.needle { needleHit = true }
                    if ship === self.dart { dartHit = true }
                }
                
                break  // Bullet can only hit one ship
            }
        }
        
        // Ship vs Ship collisions
        for i in 0..<ships.count {
            guard !ships[i].node.isHidden else { continue }
            for j in (i+1)..<ships.count {  // Only check each pair once
                guard !ships[j].node.isHidden,
                      ships[i].node.frame.intersects(ships[j].node.frame) else { continue }
                
                // Ship collision = instant kill for both (ram damage)
                let key1 = ObjectIdentifier(ships[i].node)
                let key2 = ObjectIdentifier(ships[j].node)
                shipsHit.insert(key1)
                shipsHit.insert(key2)
                
                // Award Mystery Ship bonus for ram kills
                // Only award if the other ship is needle or dart (not another mystery ship collision)
                if ships[i] === mysteryShip && ships[j] !== mysteryShip {
                    if ships[j] === needle || ships[j] === dart {
                        mysteryShipKiller = ships[j]
                    }
                } else if ships[j] === mysteryShip && ships[i] !== mysteryShip {
                    if ships[i] === needle || ships[i] === dart {
                        mysteryShipKiller = ships[i]
                    }
                }
                
                // Update legacy hit flags for backward compatibility
                if ships[i] === needle || ships[j] === needle { needleHit = true }
                if ships[i] === dart || ships[j] === dart { dartHit = true }
            }
        }
        
        // Process all hits using generalized system
        for ship in ships {
            let shipKey = ObjectIdentifier(ship.node)
            if shipsHit.contains(shipKey) {
                // Award Mystery Ship bonus BEFORE explosion
                if ship === mysteryShip, let killer = mysteryShipKiller {
                    awardMysteryShipBonus(to: killer, at: ship.node.position)
                }
                
                if !gameOver {
                    // Award points to all OTHER ships (but not for Mystery Ship kills)
                    if ship !== mysteryShip {
                        for otherShip in ships where otherShip !== ship {
                            incrementScore(for: otherShip)
                        }
                    }
                }
                recordKillTime(for: ship, at: currentTime)
                explodeShip(ship: ship)
            }
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
                } else if currentOptionsTab == .game,
                          let btn = aimPersistToggleButton, btn.contains(locInOverlay) {
                    aimPersistsAfterLift.toggle(); refreshOptionsUI(); handled = true
                } else if currentOptionsTab == .game,
                          let btn = mysteryShipToggleButton, btn.contains(locInOverlay) {
                    mysteryShipEnabled.toggle()
                    if !mysteryShipEnabled {
                        despawnMysteryShip()
                    }
                    refreshOptionsUI(); handled = true
                }
                if handled { continue }
                
                // Handle ship selection wheel touches
                if currentOptionsTab == .shipSelection {
                    if handleShipWheelTouch(at: location) {
                        handled = true
                        continue
                    }
                }
                
                if currentOptionsTab == .environment {
                    if let btn = edgeBounceButton, btn.contains(locInOverlay) {
                        edgeBehavior = .bounce; refreshOptionsUI(); handled = true
                    } else if let btn = edgeWrapButton, btn.contains(locInOverlay) {
                        edgeBehavior = .wrap; refreshOptionsUI(); handled = true
                    }
                }
                if !handled && currentOptionsTab == .ships {
                    if let btn = aiToggleButton, btn.contains(locInOverlay) {
                        needleAIEnabled.toggle()
                        needleState.aiNextThrustToggle = 0
                        needleState.aiNextFireTime = 0
                        needleState.aiThrustOn = false
                        needleState.aiCertainFireCooldown = 0
                        updateNeedleControlsVisibility(); refreshOptionsUI(); handled = true
                    } else if let btn = wedgeAIToggleButton, btn.contains(locInOverlay) {
                        wedgeAIEnabled.toggle()
                        dartState.aiNextThrustToggle = 0
                        dartState.aiNextFireTime = 0
                        dartState.aiThrustOn = false
                        dartState.aiCertainFireCooldown = 0
                        updateWedgeControlsVisibility(); refreshOptionsUI(); handled = true
                    }
                }
                if !handled && currentOptionsTab == .game {
                    if let btn = overlay.childNode(withName: "game_new_match") as? SKShapeNode,
                       btn.contains(locInOverlay) {
                        btn.fillColor = .white; btn.strokeColor = .white
                        btn.children.compactMap { $0 as? SKLabelNode }.forEach { $0.fontColor = .black }
                        newMatchButtonTouch = touch
                        handled = true
                    }
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
                    savedVirtualScreenSelection = virtualScreenSelection
                    draggingVirtualScreenSliderTouch = touch
                    applyVirtualScreenMode(); refreshOptionsUI(); handled = true
                } else if !handled && touchIsOnSlider(track: gravitySliderTrack, locInOverlay: locInOverlay) && currentOptionsTab == .environment {
                    let kx = -sliderTrackHalfWidth + CGFloat(gravitySliderSelection) * (sliderTrackWidth / CGFloat(gravitySliderSteps))
                    if locInOverlay.x < kx - 5 {
                        gravitySliderSelection = max(0, gravitySliderSelection - 1)
                    } else if locInOverlay.x > kx + 5 {
                        gravitySliderSelection = min(gravitySliderSteps, gravitySliderSelection + 1)
                    }
                    draggingGravitySliderTouch = touch; applySunState(); refreshOptionsUI(); handled = true
                }

                if handled { continue }
                            }

                            if optionsButton.contains(location) {
                                setOptionsVisible(!optionsVisible); refreshOptionsUI(); continue
                            }

                            if countdownActive { continue }
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
                    if needleAIIntelligence != idx { 
                        needleAIIntelligence = idx
                        // Sync ShipState
                        needleState.aiIntelligence = needleAIIntelligence
                        refreshOptionsUI() 
                    }
                    continue
                }
                if draggingWedgeAISliderTouch == touch {
                    let idx = aiSliderIndexForOverlayX(locInOverlay.x)
                    if wedgeAIIntelligence != idx { 
                        wedgeAIIntelligence = idx
                        // Sync ShipState
                        dartState.aiIntelligence = wedgeAIIntelligence
                        refreshOptionsUI() 
                    }
                    continue
                }
                if draggingVirtualScreenSliderTouch == touch {
                    let step = sliderTrackWidth / CGFloat(virtualScreenSteps)
                    let idx = max(0, min(virtualScreenSteps, Int(round((locInOverlay.x + sliderTrackHalfWidth) / step))))
                    if virtualScreenSelection != idx {
                        virtualScreenSelection = idx
                        savedVirtualScreenSelection = virtualScreenSelection
                        virtualScreenMode = [.off, .medium][idx]
                        applyVirtualScreenMode(); refreshOptionsUI()
                    }
                    continue
                }
                if draggingGravitySliderTouch == touch {
                    let step = sliderTrackWidth / CGFloat(gravitySliderSteps)
                    let idx = max(0, min(gravitySliderSteps, Int(round((locInOverlay.x + sliderTrackHalfWidth) / step))))
                    if gravitySliderSelection != idx { gravitySliderSelection = idx; applySunState(); refreshOptionsUI() }
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

        if countdownActive { continue }
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
                setOptionsVisible(false)   // dismiss panel first
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

        if countdownActive { continue }
                if optionsVisible { continue }
                if gameOver { continue }

                let id = ObjectIdentifier(touch)
                if let info = fireTouches.removeValue(forKey: id) {
                    let duration = CACurrentMediaTime() - info.startTime
                let location = touch.location(in: self)
                if duration < 0.25, let button = info.buttonNode, button.contains(location) {
                    fireMissile(from: info.ship, muzzleOffset: info.ship.muzzleOffset())
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
