// NeuralAIController.swift
// Supports two CoreML models:
//   SpaceWarAI-bounce.mlpackage  — trained with bounce edges
//   SpaceWarAI-wrap.mlpackage    — trained with wrap edges
//
// Call predict(..., edgeBehavior: .bounce/.wrap) and the correct model
// is used automatically.  If a model file is missing the controller
// falls back to the other one and logs a warning; if both are missing
// it returns .noOp every frame.
//
// OBSERVATION DIFFERENCE between bounce and wrap models:
//   Bounce: obs[6-7]  = opponent absolute position / (W, H)
//           obs[14+]  = bullet position relative to me (raw delta) / (W, H)
//   Wrap:   obs[6-7]  = nearest-torus delta to opponent / (W, H)
//           obs[14+]  = nearest-torus delta to bullet / (W, H)
// Everything else (indices 0-5, 8-13) is identical between the two models.

import CoreML
import SpriteKit
import Foundation

// MARK: - NeuralAIController

final class NeuralAIController {

    // ------------------------------------------------------------------ //
    // Constants — must match spacewar_env*.py exactly                      //
    // ------------------------------------------------------------------ //
    private static let worldW:      Float = 3000
    private static let worldH:      Float = 3000
    private static let maxSpeed:    Float = 400
    private static let bulletSpeed: Float = 480
    private static let maxEnemyBullets = 8
    static         let obsSize          = 46

    // ------------------------------------------------------------------ //
    // Edge behavior (mirrors GameScene.EdgeBehavior)                       //
    // ------------------------------------------------------------------ //
    enum EdgeBehavior { case bounce, wrap }

    // ------------------------------------------------------------------ //
    // Decoded action                                                        //
    // ------------------------------------------------------------------ //
    struct Action {
        let rotate: Int   // -1 = left, 0 = hold, +1 = right
        let thrust: Bool
        let fire:   Bool
        static let noOp = Action(rotate: 0, thrust: false, fire: false)
    }

    // ------------------------------------------------------------------ //
    // Models                                                                //
    // ------------------------------------------------------------------ //
    private let bounceModel: MLModel?
    private let wrapModel:   MLModel?

    init() {
        bounceModel = NeuralAIController.loadModel(named: "SpaceWarAI-bounce")
        wrapModel   = NeuralAIController.loadModel(named: "SpaceWarAI-wrap")

        if bounceModel == nil {
            print("[NeuralAIController] SpaceWarAI-bounce.mlpackage not found.")
        }
        if wrapModel == nil {
            print("[NeuralAIController] SpaceWarAI-wrap.mlpackage not found.")
        }
    }

    private static func loadModel(named name: String) -> MLModel? {
        guard
            let url      = Bundle.main.url(forResource: name,
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

    func isAvailable(for edge: EdgeBehavior) -> Bool {
        switch edge {
        case .bounce: return bounceModel != nil
        case .wrap:   return wrapModel   != nil
        }
    }

    // ------------------------------------------------------------------ //
    // Inference                                                             //
    // ------------------------------------------------------------------ //

    func predict(
        ship:          SKShapeNode,
        shipVel:       CGVector,
        shipAngle:     CGFloat,
        opponent:      SKShapeNode,
        opponentVel:   CGVector,
        opponentAngle: CGFloat,
        enemyBullets:  [(pos: CGPoint, vel: CGVector)],
        sunPosition:   CGPoint,
        edgeBehavior:  EdgeBehavior
    ) -> Action {

        // Pick model; fall back gracefully if one is missing
        let model: MLModel
        switch edgeBehavior {
        case .bounce:
            if let m = bounceModel      { model = m }
            else if let m = wrapModel   { model = m }
            else                        { return .noOp }
        case .wrap:
            if let m = wrapModel        { model = m }
            else if let m = bounceModel { model = m }
            else                        { return .noOp }
        }

        let W  = Self.worldW
        let H  = Self.worldH
        let ms = Self.maxSpeed
        let bs = Self.bulletSpeed

        var obs = [Float](repeating: 0, count: Self.obsSize)

        // [0-1] My absolute position
        obs[0] = Float(ship.position.x) / W
        obs[1] = Float(ship.position.y) / H
        // [2-3] My velocity
        obs[2] = Float(shipVel.dx) / ms
        obs[3] = Float(shipVel.dy) / ms
        // [4-5] My heading
        obs[4] = Float(sin(shipAngle))
        obs[5] = Float(cos(shipAngle))

        // [6-7] Opponent — absolute for bounce, torus-delta for wrap
        switch edgeBehavior {
        case .bounce:
            obs[6] = Float(opponent.position.x) / W
            obs[7] = Float(opponent.position.y) / H
        case .wrap:
            let (odx, ody) = torusDelta(
                ax: Float(ship.position.x), ay: Float(ship.position.y),
                bx: Float(opponent.position.x), by: Float(opponent.position.y))
            obs[6] = odx / W
            obs[7] = ody / H
        }

        // [8-9] Opponent velocity
        obs[8]  = Float(opponentVel.dx) / ms
        obs[9]  = Float(opponentVel.dy) / ms
        // [10-11] Opponent heading
        obs[10] = Float(sin(opponentAngle))
        obs[11] = Float(cos(opponentAngle))
        // [12-13] Sun direction (relative to me)
        obs[12] = Float(sunPosition.x - ship.position.x) / W
        obs[13] = Float(sunPosition.y - ship.position.y) / H

        // [14-45] Closest enemy bullets, sorted by shortest-path distance
        let mx = Float(ship.position.x)
        let my = Float(ship.position.y)

        let sorted = enemyBullets.sorted { a, b in
            let (adx, ady) = bulletDelta(mx: mx, my: my,
                                          bx: Float(a.pos.x), by: Float(a.pos.y),
                                          edge: edgeBehavior)
            let (bdx, bdy) = bulletDelta(mx: mx, my: my,
                                          bx: Float(b.pos.x), by: Float(b.pos.y),
                                          edge: edgeBehavior)
            return adx*adx + ady*ady < bdx*bdx + bdy*bdy
        }

        for i in 0 ..< Self.maxEnemyBullets {
            let base = 14 + i * 4
            if i < sorted.count {
                let bullet = sorted[i]
                let (bdx, bdy) = bulletDelta(
                    mx: mx, my: my,
                    bx: Float(bullet.pos.x), by: Float(bullet.pos.y),
                    edge: edgeBehavior)
                obs[base + 0] = bdx / W
                obs[base + 1] = bdy / H
                obs[base + 2] = Float(bullet.vel.dx) / bs
                obs[base + 3] = Float(bullet.vel.dy) / bs
            }
        }

        // ---------------------------------------------------------------- //
        // Run model                                                          //
        // ---------------------------------------------------------------- //
        guard
            let inputArr = try? MLMultiArray(
                shape:    [1, NSNumber(value: Self.obsSize)],
                dataType: .float32)
        else { return .noOp }

        for i in 0 ..< Self.obsSize { inputArr[i] = NSNumber(value: obs[i]) }

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
        var dx = bx - ax
        var dy = by - ay
        if      dx >  W / 2 { dx -= W }
        else if dx < -W / 2 { dx += W }
        if      dy >  H / 2 { dy -= H }
        else if dy < -H / 2 { dy += H }
        return (dx, dy)
    }

    private func bulletDelta(mx: Float, my: Float,
                              bx: Float, by: Float,
                              edge: EdgeBehavior) -> (Float, Float) {
        switch edge {
        case .bounce: return (bx - mx, by - my)
        case .wrap:   return torusDelta(ax: mx, ay: my, bx: bx, by: by)
        }
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

// MARK: - GameScene integration
//
// Replace the existing neuralAI predict call in the wedgeAIIntelligence == 3
// rotation block with the version below.  The only change is the added
// edgeBehavior parameter — everything else stays the same.
//
//   let edgeMode: NeuralAIController.EdgeBehavior =
//       (edgeBehavior == .wrap) ? .wrap : .bounce
//
//   let action = ai.predict(
//       ship:          dart.node,
//       shipVel:       dart.velocity,
//       shipAngle:     dart.node.zRotation,
//       opponent:      needle.node,
//       opponentVel:   needle.velocity,
//       opponentAngle: needle.node.zRotation,
//       enemyBullets:  enemyBullets,
//       sunPosition:   sunPos,
//       edgeBehavior:  edgeMode)
//
// Also drag SpaceWarAI-wrap.mlpackage into Xcode once training completes
// (Target Membership checked).  SpaceWarAI-bounce.mlpackage stays as-is.
