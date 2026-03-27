//
//  GameScene+ShipUpdate.swift
//  SpaceWar 2062
//
//  Created during generalization refactor
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit

// MARK: - Generalized Ship Update Logic
// This file contains the generalized ship update system that will eventually
// replace the hardcoded needle/dart logic in the main update() method.

extension GameScene {
    
    /// Updates a single ship's AI, rotation, and thrust for one frame.
    /// This is the generalized replacement for the hardcoded needle/dart blocks.
    ///
    /// - Parameters:
    ///   - ship: The ship to update
    ///   - currentTime: Current game time
    ///   - dt: Delta time since last frame
    ///
    /// - Note: Call this in a loop over `ships` array to support variable ship count:
    ///   ```swift
    ///   for ship in ships where ship.isVisible {
    ///       updateShip(ship, currentTime: currentTime, dt: dt)
    ///   }
    ///   ```
    func updateShip(_ ship: Ship, currentTime: TimeInterval, dt: TimeInterval) {
        guard ship.isVisible else { return }
        
        let st = state(for: ship)
        
        // Find opponent (for 2-ship game, it's the other ship; for N ships, pick closest threat)
        let opponent = findOpponent(for: ship)
        
        // MARK: AI or Player Rotation
        if st.aiEnabled {
            // Neural AI special case (wedge only for now)
            if st.aiIntelligence == 3 && ship === dart {
                updateNeuralAI(ship: ship, opponent: opponent, currentTime: currentTime, dt: dt)
            } else {
                // Standard AI (levels 0-2)
                updateStandardAI(ship: ship, opponent: opponent, currentTime: currentTime, dt: dt)
            }
        } else if let aimPt = aimPoint {
            // Player-controlled rotation
            rotateShip(ship, toward: aimPt, dt: dt)
        }
        
        // MARK: Thrust Application
        let shouldThrust = st.aiEnabled ? st.aiThrustOn : st.isThrustingByPlayer
        if shouldThrust {
            ship.applyThrust(dt: CGFloat(dt))
            ship.flame.alpha = 1
        } else {
            ship.flame.alpha = 0
        }
    }
    
    // MARK: - Opponent Selection
    
    /// Finds the best opponent for a ship to target.
    /// Currently returns the other ship in a 2-ship game.
    /// TODO: For 3+ ships, should return closest visible enemy.
    private func findOpponent(for ship: Ship) -> Ship? {
        // Simple 2-ship logic
        if ship === needle { return dart }
        if ship === dart { return needle }
        
        // Future: Find closest visible opponent
        // return ships.filter { $0 !== ship && $0.isVisible }
        //             .min { ship.node.position.distance(to: $0.node.position) }
        
        return nil
    }
    
    // MARK: - Standard AI Update
    
    /// Updates a ship using standard AI (intelligence levels 0-2).
    private func updateStandardAI(ship: Ship, opponent: Ship?, currentTime: TimeInterval, dt: TimeInterval) {
        guard let opponent, opponent.isVisible else { return }
        
        let st = state(for: ship)
        let opponentState = state(for: opponent)
        
        // Check if hunting unarmed opponent
        let huntingUnarmed = st.aiIntelligence >= 2 && opponentState.bulletsRemaining == 0
        
        var isEvading = false
        var isBraking = false
        
        // Compute aim target
        let aimTarget = sunNode != nil
            ? computeAimWithSun(
                ship: ship,
                opponent: opponent,
                intelligence: st.aiIntelligence,
                huntingUnarmed: huntingUnarmed,
                isEvading: &isEvading,
                isBraking: &isBraking,
                currentTime: currentTime,
                lastKillTime: getKillTime(for: ship),
                opponentBulletsRemaining: opponentState.bulletsRemaining)
            : computeAimWithoutSun(
                ship: ship,
                opponent: opponent,
                intelligence: st.aiIntelligence,
                huntingUnarmed: huntingUnarmed,
                isEvading: &isEvading,
                isBraking: &isBraking,
                currentTime: currentTime,
                lastKillTime: getKillTime(for: ship),
                opponentBulletsRemaining: opponentState.bulletsRemaining)
        
        // Rotate toward target
        rotateShip(ship, toward: aimTarget, dt: dt)
        
        // Compute thrust
        st.aiThrustOn = computeThrust(
            ship: ship,
            opponent: opponent,
            intelligence: st.aiIntelligence,
            huntingUnarmed: huntingUnarmed,
            isBraking: isBraking,
            isEvading: isEvading,
            thrustState: &st.aiThrustOn,
            nextThrustToggle: &st.aiNextThrustToggle,
            currentTime: currentTime)
        
        // Compute firing
        if computeFire(
            ship: ship,
            opponent: opponent,
            intelligence: st.aiIntelligence,
            isBraking: isBraking,
            isEvading: isEvading,
            opponentBulletsRemaining: opponentState.bulletsRemaining,
            nextFireTime: &st.aiNextFireTime,
            certainFireCooldown: &st.aiCertainFireCooldown,
            visibleSince: opponentState.visibleSince,
            currentTime: currentTime) {
            fireMissile(from: ship, muzzleOffset: ship.muzzleOffset())
        }
    }
    
    // MARK: - Neural AI Update
    
    /// Updates a ship using neural AI (intelligence level 3).
    private func updateNeuralAI(ship: Ship, opponent: Ship?, currentTime: TimeInterval, dt: TimeInterval) {
        guard let opponent, opponent.isVisible else { return }
        
        let st = state(for: ship)
        let opponentState = state(for: opponent)
        
        // Collect enemy bullets
        var enemyBullets: [(pos: CGPoint, vel: CGVector)] = []
        enumerateChildNodes(withName: "missile") { node, _ in
            guard let owner = self.missileOwner.object(forKey: node),
                  owner === opponent.node,
                  let data = node.userData,
                  let vx = data["vx"] as? CGFloat,
                  let vy = data["vy"] as? CGFloat else { return }
            enemyBullets.append((pos: node.position, vel: CGVector(dx: vx, dy: vy)))
        }
        
        // Get prediction from neural network
        let sunPos = sunNode?.position ?? CGPoint(x: virtualWorldWidth/2, y: virtualWorldHeight/2)
        let edgeMode: NeuralAIController.EdgeBehavior = (edgeBehavior == .wrap) ? .wrap : .bounce
        let action = neuralAI.predict(
            ship: ship.node,
            shipVel: ship.velocity,
            shipAngle: ship.node.zRotation,
            opponent: opponent.node,
            opponentVel: opponent.velocity,
            opponentAngle: opponent.node.zRotation,
            enemyBullets: enemyBullets,
            sunPosition: sunPos,
            edgeBehavior: edgeMode,
            gravityMultiplier: gravityMultiplier,
            bulletLife: bulletLifeSeconds,
            opponentBulletsRemaining: opponentState.bulletsRemaining
        )
        
        // Apply neural action
        if action.rotate != 0 {
            ship.node.zRotation += CGFloat(action.rotate) * ship.profile.turnSpeed * CGFloat(dt)
        }
        st.aiThrustOn = action.thrust
        if action.fire && currentTime >= st.aiNextFireTime {
            fireMissile(from: ship, muzzleOffset: ship.muzzleOffset())
            st.aiNextFireTime = currentTime + 0.1
        }
    }
}

// MARK: - CGPoint Distance Helper

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
