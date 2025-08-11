//
//  SilentAudioKeepAlive.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import AVFoundation
import OSLog
import UIKit

/// Keeps a silent AVAudioEngine running and fires a tolerant timer to trigger periodic work in background.
internal final class SilentAudioKeepAlive {
    internal static let shared = SilentAudioKeepAlive()

    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var timer: DispatchSourceTimer?
    private let log = Logger(subsystem: "com.DaniilKukhar.TestTask", category: "bg-keepalive")

    private let queue = DispatchQueue(label: "bg.keepalive.timer", qos: .utility)

    // Power-saving parameters
    private let sampleRate: Double = 8000        // low sample rate
    private let ioBuffer: TimeInterval = 0.75    // large IO buffer -> fewer wake ups
    private let channels: AVAudioChannelCount = 1 // mono

    internal var isRunning: Bool { timer != nil && engine.isRunning }

    /// Starts the silent engine and tolerant timer (no-op if already running).
    /// Calls `onTick` approximately every `seconds`, subject to `leeway`.
    internal func start(sendEvery seconds: Int = 120, leeway: Int = 15, onTick: @escaping () -> Void) {
        guard timer == nil else { return }

        configureAudioSession()

        guard let format = makeAudioFormat() else {
            log.error("Failed to create AVAudioFormat at sampleRate=\(self.sampleRate, privacy: .public)")
            return
        }

        startEngine(with: format)

        let timerSource = makeTimer(seconds: seconds, leeway: leeway, onTick: onTick)
        timerSource.resume()
        timer = timerSource

        registerForNotifications()
    }

    private func configureAudioSession() {
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setPreferredSampleRate(sampleRate)
        try? session.setPreferredIOBufferDuration(ioBuffer)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func makeAudioFormat() -> AVAudioFormat? {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)
    }

    private func startEngine(with format: AVAudioFormat) {
        let node = AVAudioSourceNode { _, _, _, audioBufferList -> OSStatus in
            for buf in UnsafeMutableAudioBufferListPointer(audioBufferList) {
                memset(buf.mData, 0, Int(buf.mDataByteSize))
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.0

        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            log.error("Audio engine start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeTimer(seconds: Int, leeway: Int, onTick: @escaping () -> Void) -> DispatchSourceTimer {
        let timerSource = DispatchSource.makeTimerSource(queue: queue)
        timerSource.schedule(
            deadline: .now() + .seconds(seconds),
            repeating: .seconds(seconds),
            leeway: .seconds(leeway)
        )
        timerSource.setEventHandler { [weak self] in
            // skip tick in Low Power mode or when battery is very low
            guard self != nil else { return }
            if ProcessInfo.processInfo.isLowPowerModeEnabled { return }
            if UIDevice.current.isBatteryMonitoringEnabled == false {
                UIDevice.current.isBatteryMonitoringEnabled = true
            }
            if UIDevice.current.batteryState != .charging,
               UIDevice.current.batteryLevel >= 0,
               UIDevice.current.batteryLevel <= 0.20 {
                return
            }
            onTick()
        }
        return timerSource
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    /// Stops engine and timer, detaches nodes, deactivates session, and removes observers.
    internal func stop() {
        timer?.cancel()
        timer = nil

        if engine.isRunning { engine.stop() }
        if let node = sourceNode { engine.detach(node) }
        sourceNode = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// On interruption end, re-activate the session and restart the engine.
    @objc
    private func handleInterruption(_ not: Notification) {
        guard
            let info = not.userInfo,
            let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeVal)
        else { return }

        if type == .ended {
            do {
                try session.setActive(true)
                if !engine.isRunning { try engine.start() }
            } catch {
                self.log.error("Failed to resume audio: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// If the engine stopped due to a route change, try to restart it.
    @objc
    private func handleRouteChange(_ not: Notification) {
        if !engine.isRunning {
            do { try engine.start() } catch { log.error("Route change restart failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
