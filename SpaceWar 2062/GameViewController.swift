//
//  GameViewController.swift
//  vibeGame
//
//  Created by Michael Stern on 1/9/26.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView: SKView
        if let existing = self.view as? SKView {
            skView = existing
        } else {
            skView = SKView(frame: self.view.bounds)
            skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view = skView
        }

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill   // recommended if you want it to match device size changes

        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }


    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
