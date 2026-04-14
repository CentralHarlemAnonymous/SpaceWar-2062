//
//  GameScene+ShipSelection.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 3/27/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit

// MARK: - SKColor Extension (for cross-platform color component access)

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

extension SKColor {
    var redComponent: CGFloat {
        var r: CGFloat = 0
        getRed(&r, green: nil, blue: nil, alpha: nil)
        return r
    }
    
    var greenComponent: CGFloat {
        var g: CGFloat = 0
        getRed(nil, green: &g, blue: nil, alpha: nil)
        return g
    }
    
    var blueComponent: CGFloat {
        var b: CGFloat = 0
        getRed(nil, green: nil, blue: &b, alpha: nil)
        return b
    }
}

// MARK: - Ship Selection Wheel UI

extension GameScene {
    
    /// Currently selected ship indices for each wheel
    var leftWheelShipIndex: Int {
        get {
            // Find needle's profile in playable ships only
            guard let n = needle else { return 0 }
            let playableShips = ShipProfile.allShips.filter { $0.playableByHuman }
            return playableShips.firstIndex(where: { $0.typeName == n.profile.typeName }) ?? 0
        }
        set {
            // This will be set when we implement ship switching
        }
    }
    
    var rightWheelShipIndex: Int {
        get {
            guard let d = dart else { return 1 }
            let playableShips = ShipProfile.allShips.filter { $0.playableByHuman }
            return playableShips.firstIndex(where: { $0.typeName == d.profile.typeName }) ?? 1
        }
        set {
            // This will be set when we implement ship switching
        }
    }
    
    /// Build the ship selection wheel UI (called from setupOptionsOverlay)
    func setupShipSelectionUI(in overlay: SKNode, panelWidth w: CGFloat, panelHeight h: CGFloat) {
        print("    🛸 setupShipSelectionUI START")
        guard let container = shipSelectionContainer else {
            print("    ⚠️ No shipSelectionContainer - returning")
            return
        }
        
        // Don't build UI if ships aren't initialized yet
        guard needle != nil, dart != nil else {
            print("    ⚠️ Ships not initialized yet - deferring ship selection UI setup")
            return
        }
        
        print("    🗑️ Clearing container...")
        container.removeAllChildren()
        print("    ✅ Container cleared")
        
        // Title
        let title = SKLabelNode(text: "Select Ships")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 20
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: h/2 - 100)
        title.zPosition = 202
        container.addChild(title)
        
        // Two columns: left and right (slide down 30 pixels from original position)
        let columnSpacing: CGFloat = w * 0.5
        let columnCenterY: CGFloat = -10  // Was 20, now 20-30 = -10
        
        print("    📦 Creating left column...")
        createShipColumn(in: container, centerX: -columnSpacing/2, centerY: columnCenterY,
                        shipIndex: leftWheelShipIndex, isLeftColumn: true, name: "leftColumn")
        print("    ✅ Left column created")
        
        print("    📦 Creating right column...")
        createShipColumn(in: container, centerX: columnSpacing/2, centerY: columnCenterY,
                        shipIndex: rightWheelShipIndex, isLeftColumn: false, name: "rightColumn")
        print("    ✅ Right column created")
        print("    🛸 setupShipSelectionUI COMPLETE")
    }
    
    /// Create a single ship selection column (side-by-side layout)
    private func createShipColumn(in container: SKNode, centerX: CGFloat, centerY: CGFloat,
                                  shipIndex: Int, isLeftColumn: Bool, name: String) {
        let columnNode = SKNode()
        columnNode.name = name
        columnNode.position = CGPoint(x: centerX, y: centerY)
        columnNode.zPosition = 202
        container.addChild(columnNode)
        
        // Filter to only show playable ships in the selector
        let allShips = ShipProfile.allShips.filter { $0.playableByHuman }
        let currentProfile = allShips[shipIndex]
        
        // Column header (Ship 1 / Ship 2)
        let headerLabel = SKLabelNode(text: isLeftColumn ? "Ship 1" : "Ship 2")
        headerLabel.fontName = "AvenirNext-Bold"
        headerLabel.fontSize = 13
        headerLabel.fontColor = .white
        headerLabel.verticalAlignmentMode = .center
        headerLabel.horizontalAlignmentMode = .center
        headerLabel.position = CGPoint(x: 0, y: 120)
        columnNode.addChild(headerLabel)
        
        // Ship name
        let nameLabel = SKLabelNode(text: currentProfile.typeName.uppercased())
        nameLabel.fontName = "AvenirNext-Bold"
        nameLabel.fontSize = 11
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: 100)
        nameLabel.name = "\(name)_nameLabel"
        columnNode.addChild(nameLabel)
        
        // Ship preview - MUCH HIGHER to prevent overlap
        let shipPreview = createShipPreview(profile: currentProfile, scale: 1.4, alpha: 1.0)
        shipPreview.position = CGPoint(x: 0, y: 45)
        shipPreview.name = "\(name)_preview"
        columnNode.addChild(shipPreview)
        
        // Navigation buttons - MUCH LOWER to prevent overlap
        let buttonY: CGFloat = -20
        let buttonSpacing: CGFloat = 85
        let buttonWidth: CGFloat = 40
        let buttonHeight: CGFloat = 28
        
        // Previous button with ◀ arrow
        let prevButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 5)
        prevButton.fillColor = SKColor(white: 0.2, alpha: 0.6)
        prevButton.strokeColor = .white
        prevButton.lineWidth = 2
        prevButton.position = CGPoint(x: -buttonSpacing/2, y: buttonY)
        prevButton.name = "\(name)_prevButton"
        columnNode.addChild(prevButton)
        
        let prevLabel = SKLabelNode(text: "<")
        prevLabel.fontName = "AvenirNext-Bold"
        prevLabel.fontSize = 20
        prevLabel.fontColor = .white
        prevLabel.verticalAlignmentMode = .center
        prevLabel.horizontalAlignmentMode = .center
        prevLabel.position = CGPoint(x: 0, y: 1)
        prevButton.addChild(prevLabel)
        
        // Next button with ▶ arrow
        let nextButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 5)
        nextButton.fillColor = SKColor(white: 0.2, alpha: 0.6)
        nextButton.strokeColor = .white
        nextButton.lineWidth = 2
        nextButton.position = CGPoint(x: buttonSpacing/2, y: buttonY)
        nextButton.name = "\(name)_nextButton"
        columnNode.addChild(nextButton)
        
        let nextLabel = SKLabelNode(text: ">")
        nextLabel.fontName = "AvenirNext-Bold"
        nextLabel.fontSize = 20
        nextLabel.fontColor = .white
        nextLabel.verticalAlignmentMode = .center
        nextLabel.horizontalAlignmentMode = .center
        nextLabel.position = CGPoint(x: 0, y: 1)
        nextButton.addChild(nextLabel)
        
        // Compact stats display (much lower to avoid button overlap)
        let statsStartY: CGFloat = -45
        let lineHeight: CGFloat = 16
        let fontSize: CGFloat = 10
        
        func addCompactStat(_ text: String, row: Int) {
            let label = SKLabelNode(text: text)
            label.fontName = "AvenirNext-Medium"
            label.fontSize = fontSize
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: statsStartY - CGFloat(row) * lineHeight)
            columnNode.addChild(label)
        }
        
        // Show key stats
        addCompactStat("Inv: \(currentProfile.inventory.label)", row: 0)
        addCompactStat("Speed: \(currentProfile.flightSpeed.label)", row: 1)
        addCompactStat("HP: \(currentProfile.hitPoints.label)", row: 2)
        addCompactStat("Fire: \(currentProfile.fireRate.label)", row: 3)

        let gunCount = currentProfile.muzzleOffsets.count
        let bulletLabel = gunCount > 1
            ? "Damage: \(currentProfile.bulletPower.label) ×\(gunCount)"
            : "Damage: \(currentProfile.bulletPower.label)"
        addCompactStat(bulletLabel, row: 4)

        var nextRow = 5
        // Only show shield if present
        if currentProfile.shield != .none {
            addCompactStat("Shield: \(currentProfile.shield.label)", row: nextRow)
            nextRow += 1
        }
    }
    
    /// Create a single ship selection wheel
    private func createShipWheel(in container: SKNode, centerX: CGFloat, centerY: CGFloat,
                                 shipIndex: Int, isLeftWheel: Bool, name: String) {
        let wheelNode = SKNode()
        wheelNode.name = name
        wheelNode.position = CGPoint(x: centerX, y: centerY)
        wheelNode.zPosition = 202
        container.addChild(wheelNode)
        
        let allShips = ShipProfile.allShips
        let currentProfile = allShips[shipIndex]
        
        // Pseudo-3D wheel: show 3 ships (previous, current, next)
        let itemHeight: CGFloat = 60
        let shipScale: CGFloat = 1.5
        
        // Current ship (center, full size)
        let currentShip = createShipPreview(profile: currentProfile, scale: shipScale, alpha: 1.0)
        currentShip.position = CGPoint(x: 0, y: 0)
        currentShip.name = "\(name)_current"
        wheelNode.addChild(currentShip)
        
        // Previous ship (above, smaller, faded)
        let prevIndex = (shipIndex - 1 + allShips.count) % allShips.count
        let prevProfile = allShips[prevIndex]
        let prevShip = createShipPreview(profile: prevProfile, scale: shipScale * 0.6, alpha: 0.4)
        prevShip.position = CGPoint(x: 0, y: itemHeight)
        prevShip.name = "\(name)_prev"
        wheelNode.addChild(prevShip)
        
        // Next ship (below, smaller, faded)
        let nextIndex = (shipIndex + 1) % allShips.count
        let nextProfile = allShips[nextIndex]
        let nextShip = createShipPreview(profile: nextProfile, scale: shipScale * 0.6, alpha: 0.4)
        nextShip.position = CGPoint(x: 0, y: -itemHeight)
        nextShip.name = "\(name)_next"
        wheelNode.addChild(nextShip)
        
        // Touch zones for scrolling
        let touchZoneWidth: CGFloat = 80
        let touchZoneHeight: CGFloat = 50
        
        // Up arrow (click to see previous ship)
        let upZone = SKShapeNode(rectOf: CGSize(width: touchZoneWidth, height: touchZoneHeight))
        upZone.fillColor = .clear
        upZone.strokeColor = .clear
        upZone.position = CGPoint(x: 0, y: itemHeight)
        upZone.name = "\(name)_scrollUp"
        wheelNode.addChild(upZone)
        
        // Down arrow (click to see next ship)
        let downZone = SKShapeNode(rectOf: CGSize(width: touchZoneWidth, height: touchZoneHeight))
        downZone.fillColor = .clear
        downZone.strokeColor = .clear
        downZone.position = CGPoint(x: 0, y: -itemHeight)
        downZone.name = "\(name)_scrollDown"
        wheelNode.addChild(downZone)
        
        // Ship stats display below the wheel
        let statsY: CGFloat = -120
        displayShipStats(in: wheelNode, profile: currentProfile, y: statsY, name: "\(name)_stats")
    }
    
    /// Create a visual preview of a ship (just the ship path, no flame)
    private func createShipPreview(profile: ShipProfile, scale: CGFloat, alpha: CGFloat) -> SKNode {
        let container = SKNode()
        
        let shipNode = SKShapeNode(path: profile.shipPath)
        shipNode.strokeColor = profile.shipColor
        shipNode.lineWidth = 2
        shipNode.glowWidth = 2
        shipNode.setScale(scale)
        shipNode.alpha = alpha
        container.addChild(shipNode)
        
        // Add head dot if present
        if profile.headDotRadius > 0 {
            let dot = SKShapeNode(circleOfRadius: profile.headDotRadius * scale)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: 0, y: profile.headDotY * scale)
            dot.alpha = alpha
            container.addChild(dot)
        }
        
        return container
    }
    
    /// Display ship statistics below the wheel
    private func displayShipStats(in parent: SKNode, profile: ShipProfile, y: CGFloat, name: String) {
        let statsContainer = SKNode()
        statsContainer.name = name
        statsContainer.position = CGPoint(x: 0, y: y)
        parent.addChild(statsContainer)
        
        let fontSize: CGFloat = 11
        let lineHeight: CGFloat = 16
        
        func addStat(_ text: String, row: Int) {
            let label = SKLabelNode(text: text)
            label.fontName = "AvenirNext-Medium"
            label.fontSize = fontSize
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: CGFloat(row) * -lineHeight)
            statsContainer.addChild(label)
        }
        
        addStat(profile.typeName, row: 0)
        addStat("Inventory: \(profile.inventory.label)", row: 1)
        addStat("Fire Rate: \(profile.fireRate.label)", row: 2)
        addStat("Speed: \(profile.flightSpeed.label)", row: 3)
        addStat("HP: \(profile.hitPoints.label)", row: 4)
        let gunCount = profile.muzzleOffsets.count
        if gunCount > 1 {
            addStat("Bullet Damage: \(profile.bulletPower.label) ×\(gunCount)", row: 5)
        } else {
            addStat("Bullet Damage: \(profile.bulletPower.label)", row: 5)
        }
        addStat("Turn Rate: \(profile.turnRate.label)", row: 6)
        
        // Notes (word-wrapped if long)
        let notesLabel = SKLabelNode(text: profile.notes)
        notesLabel.fontName = "AvenirNext-Medium"
        notesLabel.fontSize = 10
        notesLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
        notesLabel.horizontalAlignmentMode = .center
        notesLabel.verticalAlignmentMode = .top
        notesLabel.preferredMaxLayoutWidth = 150
        notesLabel.numberOfLines = 0
        notesLabel.position = CGPoint(x: 0, y: -7 * lineHeight)
        statsContainer.addChild(notesLabel)
    }
    
    /// Handle ship selection button touches (call from touch handler)
    func handleShipWheelTouch(at location: CGPoint) -> Bool {
        guard let overlay = optionsOverlay,
              let container = shipSelectionContainer,
              currentOptionsTab == .shipSelection else { return false }
        
        // location is already in scene coordinates, convert to container coordinates
        let locInContainer = convert(location, to: container)
        
        // Check left column buttons
        if let leftColumn = container.childNode(withName: "leftColumn") {
            let locInColumn = convert(location, to: leftColumn)
            
            if let prevButton = leftColumn.childNode(withName: "leftColumn_prevButton"),
               prevButton.contains(locInColumn) {
                scrollShipWheel(isLeft: true, direction: -1)
                return true
            }
            
            if let nextButton = leftColumn.childNode(withName: "leftColumn_nextButton"),
               nextButton.contains(locInColumn) {
                scrollShipWheel(isLeft: true, direction: 1)
                return true
            }
        }
        
        // Check right column buttons
        if let rightColumn = container.childNode(withName: "rightColumn") {
            let locInColumn = convert(location, to: rightColumn)
            
            if let prevButton = rightColumn.childNode(withName: "rightColumn_prevButton"),
               prevButton.contains(locInColumn) {
                scrollShipWheel(isLeft: false, direction: -1)
                return true
            }
            
            if let nextButton = rightColumn.childNode(withName: "rightColumn_nextButton"),
               nextButton.contains(locInColumn) {
                scrollShipWheel(isLeft: false, direction: 1)
                return true
            }
        }
        
        return false
    }
    
    /// Scroll a wheel up or down
    /// - Parameters:
    ///   - isLeft: true for left wheel (needle), false for right wheel (dart)
    ///   - direction: -1 for up/previous, +1 for down/next
    private func scrollShipWheel(isLeft: Bool, direction: Int) {
        // Filter to only show playable ships
        let allShips = ShipProfile.allShips.filter { $0.playableByHuman }
        let currentIndex = isLeft ? leftWheelShipIndex : rightWheelShipIndex
        let newIndex = (currentIndex + direction + allShips.count) % allShips.count
        let newProfile = allShips[newIndex]
        
        // Check if other wheel is using this ship
        let otherIndex = isLeft ? rightWheelShipIndex : leftWheelShipIndex
        if newIndex == otherIndex {
            // Can't select the same ship on both wheels - skip to next
            let nextIndex = (newIndex + direction + allShips.count) % allShips.count
            setShipProfile(isLeft: isLeft, profile: allShips[nextIndex])
        } else {
            setShipProfile(isLeft: isLeft, profile: newProfile)
        }
        
        // Refresh the wheel display
        refreshShipWheelUI()
    }
    
    /// Update a ship's profile (requires recreating the ship instance)
    private func setShipProfile(isLeft: Bool, profile: ShipProfile) {
        guard let oldShip = (isLeft ? needle : dart) else { return }
        
        let spawnPos = oldShip.spawnPosition
        let score = oldShip.score
        
        // Preserve state before replacing ship
        let oldState = state(for: oldShip)
        let preservedAIEnabled = oldState.aiEnabled
        let preservedAIIntelligence = oldState.aiIntelligence
        let preservedBulletSelection = oldState.bulletLimitSelection
        let preservedBulletCounterNode = oldState.bulletCounterNode
        
        // Create new ship with new profile
        let newShip = Ship(profile: profile, 
                          flame: profile.createFlameNode(), 
                          spawn: spawnPos)
        newShip.score = score
        
        if isLeft {
            // Replace needle
            
            // IMPORTANT: Remove old score node from camera before removing ship
            if let oldScoreNode = needle?.scoreNode {
                oldScoreNode.removeFromParent()
            }
            
            needle?.node.removeFromParent()
            
            // Remove old state
            if let n = needle {
                shipStates.removeValue(forKey: ObjectIdentifier(n.node))
            }
            
            needle = newShip
            ships[0] = newShip
            addChild(newShip.node)
            
            // Transfer state to new ship
            let newState = state(for: newShip)
            newState.aiEnabled = preservedAIEnabled
            newState.aiIntelligence = preservedAIIntelligence
            newState.bulletLimitSelection = preservedBulletSelection
            newState.bulletCounterNode = preservedBulletCounterNode
            newState.visibleSince = CACurrentMediaTime()
            
            // Score node will be recreated by updateScoreDisplays() below
            
            // Update cluster title
            #if DEBUG
            leftClusterTitle?.text = profile.typeName.uppercased()
            #endif
        } else {
            // Replace dart
            
            // IMPORTANT: Remove old score node from camera before removing ship
            if let oldScoreNode = dart?.scoreNode {
                oldScoreNode.removeFromParent()
            }
            
            dart?.node.removeFromParent()
            
            // Remove old state
            if let d = dart {
                shipStates.removeValue(forKey: ObjectIdentifier(d.node))
            }
            
            dart = newShip
            ships[1] = newShip
            addChild(newShip.node)
            
            // Transfer state to new ship
            let newState = state(for: newShip)
            newState.aiEnabled = preservedAIEnabled
            newState.aiIntelligence = preservedAIIntelligence
            newState.bulletLimitSelection = preservedBulletSelection
            newState.bulletCounterNode = preservedBulletCounterNode
            newState.visibleSince = CACurrentMediaTime()
            
            // Score node will be recreated by updateScoreDisplays() below
            
            // Update cluster title
            rightClusterTitle?.text = profile.typeName.uppercased()
        }
        
        // Recreate direction arrows with new profile colors
        setupDirectionArrows()
        
        // Update button colors to match new ship
        let color = profile.indicatorColor
        if !isLeft {
            // Right side (dart/wedge) - use indicator color
            let fillColor = SKColor(
                red: color.redComponent,
                green: color.greenComponent,
                blue: color.blueComponent,
                alpha: 0.7)
            fireThrustButton?.fillColor = fillColor
            rightThrustButton?.fillColor = fillColor
        } else {
            #if DEBUG
            // Left side (needle) - use indicator color
            let fillColor = SKColor(
                red: color.redComponent,
                green: color.greenComponent,
                blue: color.blueComponent,
                alpha: 0.7)
            leftFireButtonRef?.fillColor = fillColor
            leftThrustButton?.fillColor = fillColor
            #endif
        }
        
        updateScoreDisplays()
        resetBulletCountsFromSelections()
        updateNeedleControlsVisibility()
        updateWedgeControlsVisibility()
        layoutForCurrentSize()
    }
    
    /// Refresh the ship wheel UI to show current selections
    func refreshShipWheelUI() {
        guard let overlay = optionsOverlay,
              let container = shipSelectionContainer else { return }
        
        // Rebuild wheels
        let w = min(380, size.width - 40)
        let h: CGFloat = 492
        container.removeAllChildren()
        setupShipSelectionUI(in: overlay, panelWidth: w, panelHeight: h)
    }
    
    /// Helper to convert view coordinates to node coordinates
    private func convertPoint(fromView viewPoint: CGPoint, to node: SKNode) -> CGPoint {
        // Convert from view to scene
        let scenePoint = convertPoint(fromView: viewPoint)
        // Convert from scene to node
        return convert(scenePoint, to: node)
    }
}
