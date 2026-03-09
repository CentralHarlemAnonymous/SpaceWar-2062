// NeuralAIController.swift
// SpaceWar 2062
// Copyright © 2026 Michael Stern. All rights reserved.
//
// Loads two separate CoreML models:
//   SpaceWarAI-bounce.mlpackage  — 51-float observation
//   SpaceWarAI-wrap.mlpackage    — 49-float observation
//
// The correct model is selected automatically from the edgeBehavior parameter.
//
// Observation layouts
// -------------------
// BOUNCE (51 floats):
//   [0-1]   my position / (3000, 3000)
//   [2-3]   my velocity / 400
//   [4-5]   sin/cos my heading
//   [6-7]   (opponent - me) raw delta / (3000, 3000)
//   [8-9]   opponent velocity / 400
//   [10-11] sin/cos opponent heading
//   [12-13] (sun - me) / (3000, 3000)
//   [14-45] 8 enemy bullets × 4  [raw delta_x/3000, delta_y/3000, vx/480, vy/480]
//   [46]    gravityMultiplier / 10.0
//   [47]    bulletLife / 9.0
//   [48]    min(x, 3000-x) / 1500   (wall proximity x; 0=wall, 1=center)
//   [49]    min(y, 3000-y) / 1500   (wall proximity y; 0=wall, 1=center)
//   [50]    min(1, opponentBulletsRemaining / 50)   (0=unarmed, 1=full/unlimited)
//
// WRAP (49 floats):
//   [0-1]   my position / (3000, 3000)
//   [2-3]   my velocity / 400
//   [4-5]   sin/cos my heading
//   [6-7]   torus delta to opponent / (3000, 3000)
//   [8-9]   opponent velocity / 400
//   [10-11] sin/cos opponent heading
//   [12-13] (sun - me) / (3000, 3000)
//   [14-45] 8 enemy bullets × 4  [torus delta_x/3000, torus delta_y/3000, vx/480, vy/480]
//   [46]    gravityMultiplier / 10.0
//   [47]    bulletLife / 9.0
//   [48]    min(1, opponentBulletsRemaining / 50)   (0=unarmed, 1=full/unlimited)

import CoreML
import SpriteKit
import Foundation

// MARK: - NeuralAIController

final class NeuralAIController {

    // ------------------------------------------------------------------ //
    // Physics constants — must match training envs exactly                 //
    // ------------------------------------------------------------------ //
    private static let worldW:            Float = 3000
    private static let worldH:            Float = 3000
    private static let maxSpeed:          Float = 400
    private static let bulletSpeed:       Float = 480
    private static let gravityMax:        Float = 10.0
    private static let bulletLifeMax:     Float = 9.0
    private static let bulletLimitNorm:   Float = 50.0
    private static let maxEnemyBullets          = 8

    // ------------------------------------------------------------------ //
    // Edge behavior                                                         //
    // ------------------------------------------------------------------ //
    enum EdgeBehavior { case bounce, wrap }

    // ------------------------------------------------------------------ //
    // Decoded action                                                         //
    // ------------------------------------------------------------------ //
    struct Action {
        /// -1 = rotate left, 0 = hold, +1 = rotate right
        let rotate: Int
        let thrust: Bool
        let fire:   Bool
        static let noOp = Action(rotate: 0, thrust: false, fire: false)
    }

    // ------------------------------------------------------------------ //
    // Models                                                                //
    // ------------------------------------------------------------------ //
    private let bounceModel: MLModel?   // 51-float obs
    private let wrapModel:   MLModel?   // 49-float obs

    var isBounceAvailable: Bool { bounceModel != nil }
    var isWrapAvailable:   Bool { wrapModel   != nil }

    init() {
        bounceModel = NeuralAIController.load(resource: "SpaceWarAI-bounce")
        wrapModel   = NeuralAIController.load(resource: "SpaceWarAI-wrap")
        if bounceModel == nil { print("[NeuralAI] SpaceWarAI-bounce.mlpackage not found.") }
        if wrapModel   == nil { print("[NeuralAI] SpaceWarAI-wrap.mlpackage not found.")   }
    }

    private static func load(resource: String) -> MLModel? {
        guard
            let url      = Bundle.main.url(forResource: resource,
                                            withExtension: "mlpackage"),
            let compiled = try? MLModel.compileModel(at: url),
            let loaded   = try? MLModel(contentsOf: compiled,
                                        configuration: {
                                            let c = MLModelConfiguration()
                                            c.computeUnits = .all
                                            return c
                                        }())
        else { return nil }
        return loaded
    }

    // ------------------------------------------------------------------ //
    // Inference                                                             //
    // ------------------------------------------------------------------ //

    /// - Parameter opponentBulletsRemaining: pass Int.max for unlimited
    func predict(
        ship:                      SKShapeNode,
        shipVel:                   CGVector,
        shipAngle:                 CGFloat,
        opponent:                  SKShapeNode,
        opponentVel:               CGVector,
        opponentAngle:             CGFloat,
        enemyBullets:              [(pos: CGPoint, vel: CGVector)],
        sunPosition:               CGPoint,
        edgeBehavior:              EdgeBehavior,
        gravityMultiplier:         CGFloat,
        bulletLife:                CGFloat,
        opponentBulletsRemaining:  Int
    ) -> Action {

        let opponentBulletFrac: Float = opponentBulletsRemaining == Int.max
            ? 1.0
            : min(1.0, Float(opponentBulletsRemaining) / Self.bulletLimitNorm)

        switch edgeBehavior {
        case .bounce:
            guard let model = bounceModel else { return .noOp }
            let obs = buildBounceObs(
                ship: ship, shipVel: shipVel, shipAngle: shipAngle,
                opponent: opponent, opponentVel: opponentVel, opponentAngle: opponentAngle,
                enemyBullets: enemyBullets, sunPosition: sunPosition,
                gravityMultiplier: gravityMultiplier, bulletLife: bulletLife,
                opponentBulletFrac: opponentBulletFrac)
            return runModel(model, obs: obs, size: 51)

        case .wrap:
            guard let model = wrapModel else { return .noOp }
            let obs = buildWrapObs(
                ship: ship, shipVel: shipVel, shipAngle: shipAngle,
                opponent: opponent, opponentVel: opponentVel, opponentAngle: opponentAngle,
                enemyBullets: enemyBullets, sunPosition: sunPosition,
                gravityMultiplier: gravityMultiplier, bulletLife: bulletLife,
                opponentBulletFrac: opponentBulletFrac)
            return runModel(model, obs: obs, size: 49)
        }
    }

    // ------------------------------------------------------------------ //
    // Observation builders                                                  //
    // ------------------------------------------------------------------ //

    private func buildBounceObs(
        ship: SKShapeNode, shipVel: CGVector, shipAngle: CGFloat,
        opponent: SKShapeNode, opponentVel: CGVector, opponentAngle: CGFloat,
        enemyBullets: [(pos: CGPoint, vel: CGVector)],
        sunPosition: CGPoint,
        gravityMultiplier: CGFloat,
        bulletLife: CGFloat,
        opponentBulletFrac: Float
    ) -> [Float] {

        let W = Self.worldW, H = Self.worldH
        let ms = Self.maxSpeed, bs = Self.bulletSpeed
        var o = [Float](repeating: 0, count: 51)

        o[0]  = Float(ship.position.x) / W
        o[1]  = Float(ship.position.y) / H
        o[2]  = Float(shipVel.dx) / ms
        o[3]  = Float(shipVel.dy) / ms
        o[4]  = Float(sin(shipAngle))
        o[5]  = Float(cos(shipAngle))
        o[6]  = Float(opponent.position.x - ship.position.x) / W
        o[7]  = Float(opponent.position.y - ship.position.y) / H
        o[8]  = Float(opponentVel.dx) / ms
        o[9]  = Float(opponentVel.dy) / ms
        o[10] = Float(sin(opponentAngle))
        o[11] = Float(cos(opponentAngle))
        o[12] = Float(sunPosition.x - ship.position.x) / W
        o[13] = Float(sunPosition.y - ship.position.y) / H

        let mx = Float(ship.position.x), my = Float(ship.position.y)
        let sorted = enemyBullets.sorted {
            let adx = Float($0.pos.x) - mx; let ady = Float($0.pos.y) - my
            let bdx = Float($1.pos.x) - mx; let bdy = Float($1.pos.y) - my
            return adx*adx + ady*ady < bdx*bdx + bdy*bdy
        }
        for i in 0 ..< Self.maxEnemyBullets {
            let base = 14 + i * 4
            if i < sorted.count {
                let b = sorted[i]
                o[base]     = (Float(b.pos.x) - mx) / W
                o[base + 1] = (Float(b.pos.y) - my) / H
                o[base + 2] = Float(b.vel.dx) / bs
                o[base + 3] = Float(b.vel.dy) / bs
            }
        }

        o[46] = Float(gravityMultiplier) / Self.gravityMax
        o[47] = Float(bulletLife)        / Self.bulletLifeMax
        o[48] = min(Float(ship.position.x), W - Float(ship.position.x)) / (W / 2)
        o[49] = min(Float(ship.position.y), H - Float(ship.position.y)) / (H / 2)
        o[50] = opponentBulletFrac

        return o
    }

    private func buildWrapObs(
        ship: SKShapeNode, shipVel: CGVector, shipAngle: CGFloat,
        opponent: SKShapeNode, opponentVel: CGVector, opponentAngle: CGFloat,
        enemyBullets: [(pos: CGPoint, vel: CGVector)],
        sunPosition: CGPoint,
        gravityMultiplier: CGFloat,
        bulletLife: CGFloat,
        opponentBulletFrac: Float
    ) -> [Float] {

        let W = Self.worldW, H = Self.worldH
        let ms = Self.maxSpeed, bs = Self.bulletSpeed
        var o = [Float](repeating: 0, count: 49)

        o[0]  = Float(ship.position.x) / W
        o[1]  = Float(ship.position.y) / H
        o[2]  = Float(shipVel.dx) / ms
        o[3]  = Float(shipVel.dy) / ms
        o[4]  = Float(sin(shipAngle))
        o[5]  = Float(cos(shipAngle))

        let (odx, ody) = torusDelta(
            ax: Float(ship.position.x), ay: Float(ship.position.y),
            bx: Float(opponent.position.x), by: Float(opponent.position.y))
        o[6]  = odx / W
        o[7]  = ody / H

        o[8]  = Float(opponentVel.dx) / ms
        o[9]  = Float(opponentVel.dy) / ms
        o[10] = Float(sin(opponentAngle))
        o[11] = Float(cos(opponentAngle))
        o[12] = Float(sunPosition.x - ship.position.x) / W
        o[13] = Float(sunPosition.y - ship.position.y) / H

        let mx = Float(ship.position.x), my = Float(ship.position.y)
        let sorted = enemyBullets.sorted {
            let (adx, ady) = torusDelta(ax: mx, ay: my,
                                         bx: Float($0.pos.x), by: Float($0.pos.y))
            let (bdx, bdy) = torusDelta(ax: mx, ay: my,
                                         bx: Float($1.pos.x), by: Float($1.pos.y))
            return adx*adx + ady*ady < bdx*bdx + bdy*bdy
        }
        for i in 0 ..< Self.maxEnemyBullets {
            let base = 14 + i * 4
            if i < sorted.count {
                let b = sorted[i]
                let (bdx, bdy) = torusDelta(ax: mx, ay: my,
                                             bx: Float(b.pos.x), by: Float(b.pos.y))
                o[base]     = bdx / W
                o[base + 1] = bdy / H
                o[base + 2] = Float(b.vel.dx) / bs
                o[base + 3] = Float(b.vel.dy) / bs
            }
        }

        o[46] = Float(gravityMultiplier) / Self.gravityMax
        o[47] = Float(bulletLife)        / Self.bulletLifeMax
        o[48] = opponentBulletFrac

        return o
    }

    // ------------------------------------------------------------------ //
    // Model runner                                                          //
    // ------------------------------------------------------------------ //

    private func runModel(_ model: MLModel, obs: [Float], size: Int) -> Action {
        guard
            let inputArr = try? MLMultiArray(
                shape: [1, NSNumber(value: size)], dataType: .float32)
        else { return .noOp }

        for i in 0 ..< size { inputArr[i] = NSNumber(value: obs[i]) }

        guard
            let provider = try? MLDictionaryFeatureProvider(
                dictionary: ["observation": inputArr]),
            let output   = try? model.prediction(from: provider),
            let logits   = output.featureValue(for: "action_logits")?
                                 .multiArrayValue
        else { return .noOp }

        let rotIdx  = argmax(logits, start: 0, count: 3)
        let thrIdx  = argmax(logits, start: 3, count: 2)
        let fireIdx = argmax(logits, start: 5, count: 2)

        return Action(
            rotate: rotIdx == 0 ? -1 : (rotIdx == 2 ? 1 : 0),
            thrust: thrIdx  == 1,
            fire:   fireIdx == 1)
    }

    // ------------------------------------------------------------------ //
    // Helpers                                                               //
    // ------------------------------------------------------------------ //

    private func torusDelta(ax: Float, ay: Float,
                             bx: Float, by: Float) -> (Float, Float) {
        let W = Self.worldW, H = Self.worldH
        var dx = bx - ax, dy = by - ay
        if      dx >  W / 2 { dx -= W }
        else if dx < -W / 2 { dx += W }
        if      dy >  H / 2 { dy -= H }
        else if dy < -H / 2 { dy += H }
        return (dx, dy)
    }

    private func argmax(_ arr: MLMultiArray, start: Int, count: Int) -> Int {
        var bestIdx = 0
        var bestVal = arr[start].floatValue
        for i in 1 ..< count {
            let v = arr[start + i].floatValue
            if v > bestVal { bestVal = v; bestIdx = i }
        }
        return bestIdx
    }
}

// MARK: - GameScene integration note
//
// In the wedgeAIIntelligence == 3 block, update the predict call to:
//
//   let action = neuralAI.predict(
//       ship:                     dart.node,
//       shipVel:                  dart.velocity,
//       shipAngle:                dart.node.zRotation,
//       opponent:                 needle.node,
//       opponentVel:              needle.velocity,
//       opponentAngle:            needle.node.zRotation,
//       enemyBullets:             enemyBullets,
//       sunPosition:              sunPos,
//       edgeBehavior:             edgeMode,
//       gravityMultiplier:        gravityMultiplier,
//       bulletLife:               bulletLifeSeconds,
//       opponentBulletsRemaining: needleBulletsRemaining)
