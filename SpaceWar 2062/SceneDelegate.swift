//
//  SceneDelegate.swift
//  vibeGame
//
//  Created by Michael Stern on 2/8/26.
//

import UIKit
import SpriteKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let vc = GameViewController()
        window.rootViewController = vc
        self.window = window
        window.makeKeyAndVisible()
    }
}
