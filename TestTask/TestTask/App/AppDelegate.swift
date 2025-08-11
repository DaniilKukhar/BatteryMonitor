//
//  AppDelegate.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import UIKit
import BackgroundTasks

/// Application delegate: registers BG task and wires dependencies early.

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let container = AppContainer.shared

        BGTaskScheduler.shared.register(forTaskWithIdentifier: BatteryViewModel.bgTaskId,
                                        using: nil) { task in
            guard let appRefresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            container.batteryVM.handleBGTask(appRefresh)
        }

        container.backgroundCoordinator.configureOnLaunch()

        return true
    }
}
