//
//  BackgroundCoordinator.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import BackgroundTasks
import OSLog
import UIKit

/// Coordinates app lifecycle transitions and the audio fallback around backgrounding.
internal final class BackgroundCoordinator {
    private let batteryViewModel: BatteryViewModel

    internal init(batteryViewModel: BatteryViewModel) {
        self.batteryViewModel = batteryViewModel
    }

    private let log = Logger(subsystem: "com.DaniilKukhar.TestTask", category: "bg-coord")
    private let audioTick: Int = 120 // tick interval (seconds)
    private let audioLeeway: Int = 15 // allowed tolerance for timer (seconds)

    private var audioArmed = false

    /// Subscribes to foreground/background notifications.
    internal func configureOnLaunch() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    @objc
    private func appDidEnterBackground() {
        batteryViewModel.scheduleBGTask()
        armAudioIfNeeded()
    }

    @objc
    private func appWillEnterForeground() {
        disarmAudioIfNeeded()
    }

    /// Arms the audio fallback if not in Low Power mode; idempotent.
    private func armAudioIfNeeded() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        if audioArmed == false {
            audioArmed = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                SilentAudioKeepAlive.shared.start(sendEvery: self.audioTick, leeway: self.audioLeeway) {
                    self.batteryViewModel.sendOnceSilently()
                }
                self.log.notice("Audio fallback ARMED")
            }
        }
    }

    /// Disarms the audio fallback if currently armed.
    private func disarmAudioIfNeeded() {
        if audioArmed {
            SilentAudioKeepAlive.shared.stop()
            audioArmed = false
            log.notice("Audio fallback DISARMED")
        }
    }
}
