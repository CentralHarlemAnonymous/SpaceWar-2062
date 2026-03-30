//
//  GameScene+AI.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 3/15/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit

extension GameScene {
    
    // MARK: - AI Prediction & Targeting
    
    /// Predict where `target` will be when a bullet fired from `shooter` arrives.
    /// Intelligence 0 = current position, 1+ = quadratic prediction (velocity + acceleration)
    func predictedAimPoint(shooter: Ship, target: Ship, intelligence: Int) -> CGPoint {
        guard intelligence >= 1 else { return target.node.position }

        let origin    = shooter.node.position
        let bulletSpeed = shooter.profile.bulletSpeed
        let targetPos = target.node.position
        let targetVel = target.velocity
        let acc = state(for: target).smoothedAcceleration

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
    
    /// Level-3 firing solution: quadratic prediction with 15 iterations for accuracy.
    func level3AimPoint(shooter: Ship, target: Ship) -> CGPoint {
        let bulletSpeed = shooter.profile.bulletSpeed
        let origin = shooter.node.position
        let targetPos = target.node.position
        let targetVel = target.velocity
        let acc = state(for: target).smoothedAcceleration
        var t = hypot(targetPos.x - origin.x, targetPos.y - origin.y) / bulletSpeed
        for _ in 0..<15 {
            let px = targetPos.x + targetVel.dx * t + 0.5 * acc.dx * t * t
            let py = targetPos.y + targetVel.dy * t + 0.5 * acc.dy * t * t
            t = hypot(px - origin.x, py - origin.y) / bulletSpeed
        }
        let predicted = CGPoint(
            x: targetPos.x + targetVel.dx * t + 0.5 * acc.dx * t * t,
            y: targetPos.y + targetVel.dy * t + 0.5 * acc.dy * t * t)
        return predicted
    }
    
    // MARK: - Sun Collision Prediction
    
    /// Simulate `ship`'s trajectory under gravity and return true if it will
    /// hit the sun within `seconds` seconds.
    func shipWillHitSun(_ ship: Ship, in seconds: CGFloat, steps: Int = 20) -> Bool {
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
    func simulateBulletHitsSun(from ship: Ship, target: Ship? = nil) -> Bool {
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
        let baseG: CGFloat = 18000 * gravityMultiplier * (7.0 / 8.0)
        for _ in 0..<simSteps {
            let dx = sx - bx, dy = sy - by
            let r2 = dx*dx + dy*dy + 100
            let invR = 1.0 / sqrt(r2)
            let a = baseG / r2
            bvx += dx * invR * a * simStep
            bvy += dy * invR * a * simStep
            bx += bvx * simStep
            by += bvy * simStep
            if (bx-sx)*(bx-sx) + (by-sy)*(by-sy) <= sunR*sunR { return true }
        }
        return false
    }
    
    // MARK: - World Geometry Helpers
    
    /// Returns `targetPos` directly (no wrapping — the world is a bounded circle).
    func nearestVirtualPosition(of targetPos: CGPoint, from origin: CGPoint) -> CGPoint {
        return targetPos
    }

    /// Clamp a point to lie within the play field (with inset margin).
    /// Rectangular when virtual screen is off, circular when on.
    func clampToWorld(_ p: CGPoint, margin: CGFloat = 50) -> CGPoint {
        if virtualScreenMode == .off {
            return CGPoint(x: max(margin, min(size.width  - margin, p.x)),
                           y: max(margin, min(size.height - margin, p.y)))
        }
        let center = virtualWorldCenter
        let r = virtualWorldRadius - margin
        let dx = p.x - center.x, dy = p.y - center.y
        let dist = hypot(dx, dy)
        guard dist > r else { return p }
        return CGPoint(x: center.x + dx / dist * r,
                       y: center.y + dy / dist * r)
    }
    
    // MARK: - Strategic AI (Level 2+)
    
    /// Determine if ship should brake to avoid collision with opponent (expert AI).
    func collisionDecision(ship: Ship, opponent: Ship,
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
    
    /// When hunting an unarmed opponent, blend direct pursuit with intercept.
    func huntAimPoint(shooter: Ship, target: Ship) -> CGPoint {
        let myPos = shooter.node.position
        let oppPos = target.node.position
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
    
    /// Return a point to aim at when avoiding collision with opponent.
    func collisionAvoidancePoint(for ship: Ship, opponent: Ship) -> CGPoint {
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
    
    // MARK: - Bullet Hit Detection & Prediction
    
    /// Check if any of shooter's own bullets will hit the target.
    func ownBulletWillHit(shooter: Ship, target: Ship, hitRadius: CGFloat = 18) -> Bool {
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
            let baseG: CGFloat = 18000 * self.gravityMultiplier * (7.0 / 8.0)
            for _ in 0..<simSteps {
                if let sun = self.sunNode {
                    let sdx = sun.position.x - bx, sdy = sun.position.y - by
                    let r2 = sdx*sdx + sdy*sdy + 100
                    let a  = baseG / r2
                    let invR = 1.0 / sqrt(r2)
                    bvx += sdx * invR * a * simStep
                    bvy += sdy * invR * a * simStep
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
    
    /// Simulate a bullet fired from current rotation and check if it hits target.
    func bulletWillHit(shooter: Ship, target: Ship, hitRadius: CGFloat = 18) -> Bool {
        let angle = shooter.node.zRotation
        let bulletSpeed = shooter.profile.bulletSpeed
        var bx = shooter.node.position.x, by = shooter.node.position.y
        var bvx = -bulletSpeed * sin(angle), bvy = bulletSpeed * cos(angle)
        let simStep: CGFloat = 0.05
        let simLife: CGFloat = bulletLifeSeconds
        let simSteps = Int(simLife / simStep)
        var tx = target.node.position.x, ty = target.node.position.y
        let tvx = target.velocity.dx,    tvy = target.velocity.dy
        let baseG: CGFloat = 18000 * gravityMultiplier * (7.0 / 8.0)

        for _ in 0..<simSteps {
            if let sun = sunNode {
                let sdx = sun.position.x - bx, sdy = sun.position.y - by
                let r2  = sdx*sdx + sdy*sdy + 100
                let a   = baseG / r2
                let invR = 1.0 / sqrt(r2)
                bvx += sdx * invR * a * simStep
                bvy += sdy * invR * a * simStep
                if sdx*sdx + sdy*sdy <= sunCollisionRadius * sunCollisionRadius { return false }
            }
            bx += bvx * simStep; by += bvy * simStep
            tx += tvx * simStep; ty += tvy * simStep
            let ddx = bx - tx, ddy = by - ty
            if ddx*ddx + ddy*ddy <= hitRadius * hitRadius { return true }
        }
        return false
    }
    
    /// Check if any incoming bullet is unavoidable within the horizon.
    func bulletHitUnavoidable(for ship: Ship, horizon: CGFloat = 1.2) -> Bool {
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
    
    /// Detect incoming bullet danger, accounting for world edges and opponent position.
    func edgeAwareBulletDanger(for ship: Ship,
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
            let oppPos = opp.node.position
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
    
    /// Find optimal strategic position relative to opponent (flanking, range control).
    func strategicPositionTarget(for ship: Ship, opponent: Ship,
                                pursueBehind: Bool = false) -> CGPoint {
        guard !opponent.node.isHidden else {
            return level3AimPoint(shooter: ship, target: opponent)
        }

        let myPos  = ship.node.position
        let oppPos = opponent.node.position

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
            return clampToWorld(CGPoint(x: behindX, y: behindY))
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
            let tdx = p.x - myPos.x, tdy = p.y - myPos.y
            s += hypot(tdx, tdy) * 0.08
            return s
        }

        return score(c1) <= score(c2) ? clampToWorld(c1) : clampToWorld(c2)
    }
    
    // MARK: - Rotation Helpers
    
    /// Calculate the shortest angular difference between two angles.
    func shortestAngleBetween(_ angle1: CGFloat, _ angle2: CGFloat) -> CGFloat {
        let twoPi = CGFloat.pi * 2
        var angle = (angle2 - angle1).truncatingRemainder(dividingBy: twoPi)
        if angle >= .pi  { angle -= twoPi }
        if angle <= -.pi { angle += twoPi }
        return angle
    }
    
    /// Rotate ship toward a world point at its turn speed.
    func rotateShip(_ ship: Ship, toward worldPoint: CGPoint, dt: TimeInterval) {
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
    
    // MARK: - High-Level AI Execution
    
    /// Complete AI decision for one frame
    struct AIDecision {
        var aimTarget: CGPoint?
        var shouldThrust: Bool
        var shouldFire: Bool
        var isEvading: Bool
        var isBraking: Bool
    }
    
    /// Compute rotation target for a ship with sun avoidance
    func computeAimWithSun(ship: Ship, opponent: Ship, intelligence: Int,
                          huntingUnarmed: Bool, isEvading: inout Bool,
                          isBraking: inout Bool, currentTime: TimeInterval,
                          lastKillTime: TimeInterval, opponentBulletsRemaining: Int) -> CGPoint {
        
        guard let sun = sunNode else {
            return computeAimWithoutSun(ship: ship, opponent: opponent, intelligence: intelligence,
                                       huntingUnarmed: huntingUnarmed, isEvading: &isEvading,
                                       isBraking: &isBraking, currentTime: currentTime,
                                       lastKillTime: lastKillTime, opponentBulletsRemaining: opponentBulletsRemaining)
        }
        
        let dxs = sun.position.x - ship.node.position.x
        let dys = sun.position.y - ship.node.position.y
        let dist2 = dxs*dxs + dys*dys
        let vx = ship.velocity.dx, vy = ship.velocity.dy
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
        
        let avoidRadius: CGFloat = (intelligence >= 2) ? 180 : 140
        let tooClose = dist2 < avoidRadius * avoidRadius
        let shouldAvoidSun = (intelligence >= 1)
            ? (shipWillHitSun(ship, in: 3.5) || tooClose)
            : (tooClose || onCollisionCourse)
        
        if intelligence >= 2 && !shouldAvoidSun {
            isBraking = collisionDecision(ship: ship, opponent: opponent,
                                         killTime: lastKillTime, currentTime: currentTime)
        }
        
        if shouldAvoidSun {
            isEvading = true
            return CGPoint(x: ship.node.position.x - dxs, y: ship.node.position.y - dys)
        } else if huntingUnarmed {
            return huntAimPoint(shooter: ship, target: opponent)
        } else if isBraking {
            return collisionAvoidancePoint(for: ship, opponent: opponent)
        } else if intelligence >= 2 {
            if bulletHitUnavoidable(for: ship) {
                return level3AimPoint(shooter: ship, target: opponent)
            } else {
                let (inDanger, awayPoint) = edgeAwareBulletDanger(for: ship, opponent: opponent)
                if inDanger { isEvading = true }
                return inDanger ? awayPoint
                    : strategicPositionTarget(for: ship, opponent: opponent, pursueBehind: opponentBulletsRemaining > 0)
            }
        } else {
            // Level 0/1: simple bullet avoidance + basic targeting
            var nearestMissilePos = CGPoint.zero
            var nearestMissileD2 = CGFloat.greatestFiniteMagnitude
            enumerateChildNodes(withName: "missile") { node, _ in
                let dxm = node.position.x - ship.node.position.x
                let dym = node.position.y - ship.node.position.y
                let d2m = dxm*dxm + dym*dym
                if d2m < nearestMissileD2 { nearestMissileD2 = d2m; nearestMissilePos = node.position }
            }
            let avoidBulletR: CGFloat = 120
            if nearestMissileD2 < avoidBulletR*avoidBulletR {
                return CGPoint(x: ship.node.position.x - (nearestMissilePos.x - ship.node.position.x),
                              y: ship.node.position.y - (nearestMissilePos.y - ship.node.position.y))
            } else if !opponent.node.isHidden {
                let dxw = opponent.node.position.x - ship.node.position.x
                let dyw = opponent.node.position.y - ship.node.position.y
                let d2w = dxw*dxw + dyw*dyw
                if d2w < 90*90 {
                    return CGPoint(x: ship.node.position.x - dxw, y: ship.node.position.y - dyw)
                }
            }
            return predictedAimPoint(shooter: ship, target: opponent, intelligence: intelligence)
        }
    }
    
    /// Compute rotation target without sun
    func computeAimWithoutSun(ship: Ship, opponent: Ship, intelligence: Int,
                             huntingUnarmed: Bool, isEvading: inout Bool,
                             isBraking: inout Bool, currentTime: TimeInterval,
                             lastKillTime: TimeInterval, opponentBulletsRemaining: Int) -> CGPoint {
        
        if intelligence >= 2 {
            isBraking = collisionDecision(ship: ship, opponent: opponent,
                                         killTime: lastKillTime, currentTime: currentTime)
        }
        
        if huntingUnarmed {
            return huntAimPoint(shooter: ship, target: opponent)
        } else if isBraking {
            return collisionAvoidancePoint(for: ship, opponent: opponent)
        } else if intelligence >= 2 {
            if bulletHitUnavoidable(for: ship) {
                return level3AimPoint(shooter: ship, target: opponent)
            } else {
                let (inDanger, awayPoint) = edgeAwareBulletDanger(for: ship, opponent: opponent)
                if inDanger { isEvading = true }
                return inDanger ? awayPoint
                    : strategicPositionTarget(for: ship, opponent: opponent, pursueBehind: opponentBulletsRemaining > 0)
            }
        } else {
            var nearestMissilePos = CGPoint.zero
            var nearestMissileD2 = CGFloat.greatestFiniteMagnitude
            enumerateChildNodes(withName: "missile") { node, _ in
                let dxm = node.position.x - ship.node.position.x
                let dym = node.position.y - ship.node.position.y
                let d2m = dxm*dxm + dym*dym
                if d2m < nearestMissileD2 { nearestMissileD2 = d2m; nearestMissilePos = node.position }
            }
            let avoidBulletR: CGFloat = 120
            if nearestMissileD2 < avoidBulletR*avoidBulletR {
                return CGPoint(x: ship.node.position.x - (nearestMissilePos.x - ship.node.position.x),
                              y: ship.node.position.y - (nearestMissilePos.y - ship.node.position.y))
            }
            return predictedAimPoint(shooter: ship, target: opponent, intelligence: intelligence)
        }
    }
    
    /// Compute thrust decision
    func computeThrust(ship: Ship, opponent: Ship, intelligence: Int,
                      huntingUnarmed: Bool, isBraking: Bool, isEvading: Bool,
                      thrustState: inout Bool, nextThrustToggle: inout TimeInterval,
                      currentTime: TimeInterval) -> Bool {
        
        if intelligence >= 2 {
            if huntingUnarmed {
                return !isBraking
            } else if isBraking {
                return true
            } else {
                if isEvading {
                    thrustState = true
                    nextThrustToggle = currentTime + Double.random(in: 0.5...1.0)
                } else if currentTime >= nextThrustToggle {
                    thrustState.toggle()
                    let oppDist = hypot(opponent.node.position.x - ship.node.position.x,
                                       opponent.node.position.y - ship.node.position.y)
                    let outOfPosition = abs(oppDist - 260) > 80
                    nextThrustToggle = currentTime + Double.random(
                        in: thrustState ? (outOfPosition ? 0.6...1.1 : 0.2...0.5)
                                        : (outOfPosition ? 0.1...0.2 : 0.2...0.5))
                }
                return thrustState
            }
        } else {
            if currentTime >= nextThrustToggle {
                thrustState.toggle()
                nextThrustToggle = currentTime + Double.random(in: thrustState ? 0.3...0.8 : 0.4...1.2)
            }
            return thrustState
        }
    }
    
    /// Compute fire decision
    func computeFire(ship: Ship, opponent: Ship, intelligence: Int,
                    isBraking: Bool, isEvading: Bool, opponentBulletsRemaining: Int,
                    nextFireTime: inout TimeInterval, certainFireCooldown: inout TimeInterval,
                    visibleSince: TimeInterval, currentTime: TimeInterval) -> Bool {
        
        guard !opponent.node.isHidden else { return false }
        guard (currentTime - visibleSince) >= 1.0 else { return false }
        guard !ownBulletWillHit(shooter: ship, target: opponent) else { return false }
        
        let huntingUnarmed = intelligence >= 2 && opponentBulletsRemaining == 0
        
        // Certain-fire check for level 2+
        if intelligence >= 2 && !isBraking && !isEvading
            && currentTime >= certainFireCooldown {
            let aim = level3AimPoint(shooter: ship, target: opponent)
            let aimAngle = atan2(aim.y - ship.node.position.y,
                                aim.x - ship.node.position.x) - .pi/2
            if abs(shortestAngleBetween(ship.node.zRotation, aimAngle)) < .pi / 7
                && bulletWillHit(shooter: ship, target: opponent) {
                certainFireCooldown = currentTime + 0.2
                nextFireTime = currentTime + 0.25
                return true
            }
        }
        
        // Regular firing
        guard currentTime >= nextFireTime else { return false }
        
        var shouldFire = true
        
        if intelligence < 2 {
            let oppDist = hypot(opponent.node.position.x - ship.node.position.x,
                               opponent.node.position.y - ship.node.position.y)
            if oppDist > 1000 { shouldFire = false }
        }
        
        if shouldFire && intelligence >= 1 && sunNode != nil {
            shouldFire = !simulateBulletHitsSun(from: ship, target: opponent)
        }
        
        if shouldFire && intelligence >= 2 {
            if isBraking {
                shouldFire = false
            } else if huntingUnarmed {
                let oppPos = opponent.node.position
                let ddx = oppPos.x - ship.node.position.x
                let ddy = oppPos.y - ship.node.position.y
                let oppDist = hypot(ddx, ddy)
                if oppDist > 600 {
                    shouldFire = false
                } else {
                    let toOppX = ddx / max(oppDist, 1), toOppY = ddy / max(oppDist, 1)
                    let netSpeed: CGFloat = 480 + ship.velocity.dx * toOppX + ship.velocity.dy * toOppY
                    if netSpeed < 80 {
                        shouldFire = false
                    } else {
                        let aimPt = huntAimPoint(shooter: ship, target: opponent)
                        let aimAngle = atan2(aimPt.y - ship.node.position.y,
                                            aimPt.x - ship.node.position.x) - .pi/2
                        if abs(shortestAngleBetween(ship.node.zRotation, aimAngle)) > .pi / 9 {
                            shouldFire = false
                        }
                    }
                }
            } else {
                let oppDist = hypot(opponent.node.position.x - ship.node.position.x,
                                   opponent.node.position.y - ship.node.position.y)
                if oppDist > 600 {
                    shouldFire = false
                } else {
                    let aim = level3AimPoint(shooter: ship, target: opponent)
                    let aimAngle = atan2(aim.y - ship.node.position.y,
                                        aim.x - ship.node.position.x) - .pi/2
                    if abs(shortestAngleBetween(ship.node.zRotation, aimAngle)) > .pi / 12 {
                        shouldFire = false
                    }
                }
            }
        }
        
        if shouldFire {
            nextFireTime = currentTime + Double.random(in: 0.35...0.7)
        } else {
            nextFireTime = currentTime + 0.1
        }
        
        return shouldFire
    }
    
    // MARK: - High-Level AI Update (Artisanal AI)
    
    /// Updates a ship's AI for rotation, thrust, and firing.
    /// This is the "artisanal" AI logic that should be called from the update loop
    /// instead of having it inline in GameScene.update().
    ///
    /// - Parameters:
    ///   - ship: The ship to update
    ///   - opponent: The opponent ship
    ///   - currentTime: Current game time
    ///   - dt: Delta time
    /// - Returns: true if the ship should be thrusting
    func updateShipAI(
        ship: Ship,
        opponent: Ship,
        currentTime: TimeInterval,
        dt: TimeInterval
    ) -> Bool {
        let st = state(for: ship)
        let opponentState = state(for: opponent)
        
        guard st.aiEnabled, !ship.node.isHidden else {
            return false
        }
        
        // If opponent is hidden, just focus on sun avoidance
        if opponent.node.isHidden {
            if let sun = sunNode {
                let dxs = sun.position.x - ship.node.position.x
                let dys = sun.position.y - ship.node.position.y
                let dist2 = dxs*dxs + dys*dys
                let avoidRadius: CGFloat = 180
                
                // Check if we should avoid the sun
                let tooClose = dist2 < avoidRadius * avoidRadius
                let shouldAvoidSun = shipWillHitSun(ship, in: 3.5) || tooClose
                
                if shouldAvoidSun {
                    // Aim away from sun
                    let awayPoint = CGPoint(x: ship.node.position.x - dxs, 
                                          y: ship.node.position.y - dys)
                    rotateShip(ship, toward: awayPoint, dt: dt)
                    return true  // Always thrust when escaping sun
                }
            }
            // No opponent and no sun danger: idle
            return false
        }
        
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
                lastKillTime: getKillTime(for: opponent),
                opponentBulletsRemaining: opponentState.bulletsRemaining)
            : computeAimWithoutSun(
                ship: ship,
                opponent: opponent,
                intelligence: st.aiIntelligence,
                huntingUnarmed: huntingUnarmed,
                isEvading: &isEvading,
                isBraking: &isBraking,
                currentTime: currentTime,
                lastKillTime: getKillTime(for: opponent),
                opponentBulletsRemaining: opponentState.bulletsRemaining)
        
        // Rotate toward target
        rotateShip(ship, toward: aimTarget, dt: dt)
        
        // Compute thrust (updates st.aiThrustOn via inout parameter)
        let shouldThrust = computeThrust(
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
        
        return shouldThrust
    }
}

