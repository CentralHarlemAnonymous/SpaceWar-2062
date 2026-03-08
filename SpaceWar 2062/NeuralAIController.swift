// NeuralAIController.swift
// Drop-in CoreML inference for SpaceWar 2062.
//
// Add SpaceWarAI.mlpackage to your Xcode project target, then
// add this file to the same target.
//
// Observation vector (46 floats) must match spacewar_env.py _obs() exactly.
// Action encoding must match export_coreml.py logit layout exactly.

import CoreML
import SpriteKit
import Foundation

// MARK: - NeuralAIController

final class NeuralAIController {

    // ------------------------------------------------------------------ //
    // Constants — must match spacewar_env.py                              //
    // ------------------------------------------------------------------ //
    private static let worldW:       Float = 3000
    private static let worldH:       Float = 3000
    private static let maxSpeed:     Float = 400
    private static let bulletSpeed:  Float = 480
    private static let maxEnemyBullets = 8
    static         let obsSize             = 46      // 14 + 8*4

    // ------------------------------------------------------------------ //
    // Decoded action                                                       //
    // ------------------------------------------------------------------ //
    struct Action {
        /// -1 = rotate left, 0 = hold, +1 = rotate right
        let rotate: Int
        let thrust: Bool
        let fire:   Bool
    }

    // ------------------------------------------------------------------ //
    // Model                                                                //
    // ------------------------------------------------------------------ //
    private let model: MLModel

    /// Returns nil and logs an error if the mlpackage is missing from the bundle.
    init?() {
        guard
            let url = Bundle.main.url(forResource: "SpaceWarAI",
                                      withExtension: "mlpackage"),
            let compiled = try? MLModel.compileModel(at: url),
            let loaded   = try? MLModel(contentsOf: compiled,
                                        configuration: {
                                            let c = MLModelConfiguration()
                                            c.computeUnits = .all
                                            return c
                                        }())
        else {
            print("[NeuralAIController] Failed to load SpaceWarAI.mlpackage — "
                + "check it is added to the Xcode target.")
            return nil
        }
        self.model = loaded
    }

    // ------------------------------------------------------------------ //
    // Inference                                                            //
    // ------------------------------------------------------------------ //

    /// Build the observation vector and run one forward pass.
    ///
    /// - Parameters:
    ///   - ship:         The controlled ship's SKShapeNode.
    ///   - shipVel:      Ship velocity in world px/s.
    ///   - shipAngle:    Ship zRotation in radians (SpriteKit convention).
    ///   - opponent:     Opponent ship's SKShapeNode.
    ///   - opponentVel:  Opponent velocity.
    ///   - opponentAngle: Opponent zRotation.
    ///   - enemyBullets: Bullets fired by the opponent:
    ///                   array of (world position, world velocity).
    ///   - sunPosition:  Sun centre in world coordinates.
    ///
    /// - Returns: Decoded action, or a safe no-op on any error.
    func predict(
        ship:          SKShapeNode,
        shipVel:       CGVector,
        shipAngle:     CGFloat,
        opponent:      SKShapeNode,
        opponentVel:   CGVector,
        opponentAngle: CGFloat,
        enemyBullets:  [(pos: CGPoint, vel: CGVector)],
        sunPosition:   CGPoint
    ) -> Action {
        var obs = [Float](repeating: 0, count: Self.obsSize)
        let W   = Self.worldW
        let H   = Self.worldH
        let ms  = Self.maxSpeed
        let bs  = Self.bulletSpeed

        // [0-1] my position
        obs[0] = Float(ship.position.x) / W
        obs[1] = Float(ship.position.y) / H
        // [2-3] my velocity
        obs[2] = Float(shipVel.dx) / ms
        obs[3] = Float(shipVel.dy) / ms
        // [4-5] my heading
        obs[4] = Float(sin(shipAngle))
        obs[5] = Float(cos(shipAngle))
        // [6-7] opponent position
        obs[6] = Float(opponent.position.x) / W
        obs[7] = Float(opponent.position.y) / H
        // [8-9] opponent velocity
        obs[8] = Float(opponentVel.dx) / ms
        obs[9] = Float(opponentVel.dy) / ms
        // [10-11] opponent heading
        obs[10] = Float(sin(opponentAngle))
        obs[11] = Float(cos(opponentAngle))
        // [12-13] sun direction (relative to me, normalised)
        obs[12] = Float(sunPosition.x - ship.position.x) / W
        obs[13] = Float(sunPosition.y - ship.position.y) / H

        // [14-45] closest 8 enemy bullets
        let sorted = enemyBullets.sorted {
            let d0 = pow($0.pos.x - ship.position.x, 2) + pow($0.pos.y - ship.position.y, 2)
            let d1 = pow($1.pos.x - ship.position.x, 2) + pow($1.pos.y - ship.position.y, 2)
            return d0 < d1
        }
        for i in 0 ..< Self.maxEnemyBullets {
            let base = 14 + i * 4
            if i < sorted.count {
                let b = sorted[i]
                obs[base + 0] = Float(b.pos.x - ship.position.x) / W
                obs[base + 1] = Float(b.pos.y - ship.position.y) / H
                obs[base + 2] = Float(b.vel.dx) / bs
                obs[base + 3] = Float(b.vel.dy) / bs
            }
            // else: already zero from initialisation
        }

        // ---------------------------------------------------------------- //
        // Run model                                                          //
        // ---------------------------------------------------------------- //
        guard
            let inputArr = try? MLMultiArray(
                shape:    [1, NSNumber(value: Self.obsSize)],
                dataType: .float32)
        else { return .noOp }

        for i in 0 ..< Self.obsSize {
            inputArr[i] = NSNumber(value: obs[i])
        }

        guard
            let provider = try? MLDictionaryFeatureProvider(
                dictionary: ["observation": inputArr]),
            let output   = try? model.prediction(from: provider),
            let logits   = output.featureValue(for: "action_logits")?
                                 .multiArrayValue
        else { return .noOp }

        // ---------------------------------------------------------------- //
        // Decode: argmax within each action group                           //
        // Layout: [0:3] rotate | [3:5] thrust | [5:7] fire                 //
        // ---------------------------------------------------------------- //
        let rotIdx  = argmax(logits, start: 0, count: 3)   // 0=left 1=none 2=right
        let thrIdx  = argmax(logits, start: 3, count: 2)   // 0=off  1=on
        let fireIdx = argmax(logits, start: 5, count: 2)   // 0=no   1=yes

        let rotate: Int = rotIdx == 0 ? -1 : (rotIdx == 2 ? 1 : 0)
        return Action(rotate: rotate, thrust: thrIdx == 1, fire: fireIdx == 1)
    }

    // ------------------------------------------------------------------ //
    // Helpers                                                              //
    // ------------------------------------------------------------------ //

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

extension NeuralAIController.Action {
    static let noOp = NeuralAIController.Action(rotate: 0, thrust: false, fire: false)
}

// MARK: - GameScene integration sketch
//
// 1. Add a property to GameScene:
//      private let neuralAI = NeuralAIController()
//
// 2. In the AI rotation block, where you currently call rotateShip / strategicPositionTarget,
//    add a new branch for neural AI (e.g. intelligence level 3):
//
//      if wedgeAIIntelligence == 3, let ai = neuralAI {
//          // Collect opponent bullets
//          var enemyBullets: [(pos: CGPoint, vel: CGVector)] = []
//          enumerateChildNodes(withName: "missile") { node, _ in
//              guard let owner = self.missileOwner.object(forKey: node),
//                    owner === self.needle.node,
//                    let data = node.userData,
//                    let vx = data["vx"] as? CGFloat,
//                    let vy = data["vy"] as? CGFloat else { return }
//              enemyBullets.append((pos: node.position,
//                                   vel: CGVector(dx: vx, dy: vy)))
//          }
//          let sunPos = sunNode?.position ?? CGPoint(x: 1500, y: 1500)
//          let action = ai.predict(
//              ship:          dart.node,
//              shipVel:       dart.velocity,
//              shipAngle:     dart.node.zRotation,
//              opponent:      needle.node,
//              opponentVel:   needle.velocity,
//              opponentAngle: needle.node.zRotation,
//              enemyBullets:  enemyBullets,
//              sunPosition:   sunPos)
//
//          // Apply rotation
//          if action.rotate != 0 {
//              dart.node.zRotation += CGFloat(action.rotate) * rotationSpeed * CGFloat(dt)
//          }
//          isThrustingDart = action.thrust
//          if action.fire && currentTime >= wedgeAINextFireTime {
//              fireMissile(from: dart, muzzleOffset: muzzleOffset(for: dart))
//              wedgeAINextFireTime = currentTime + 0.1
//          }
//      }
//
// Note: wire up the neural AI after validating it in a test build first.
//       The handcrafted expert AI (intelligence == 2) remains as a fallback.
