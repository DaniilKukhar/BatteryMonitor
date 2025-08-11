//
//  SceneDelegate.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import UIKit
import BackgroundTasks

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let container = AppContainer.shared

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }

        let root = BatteryViewController(viewModel: container.batteryVM)
        let win  = UIWindow(windowScene: ws)
        win.rootViewController = UINavigationController(rootViewController: root)
        win.makeKeyAndVisible()
        self.window = win

        container.batteryVM.scheduleBGTask()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        container.batteryVM.scheduleBGTask()
        // container.batteryVM.performOneShotOnBackground()
    }
}
