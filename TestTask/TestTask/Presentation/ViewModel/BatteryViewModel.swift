//
//  BatteryViewModel.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import Foundation
import UIKit
import BackgroundTasks
import OSLog
import Combine

/// Orchestrates background refresh and one-off battery sends.
/// Uses BGTaskScheduler and an audio-based fallback for reliability.
final class BatteryViewModel {
    static let bgTaskId = "com.DaniilKukhar.TestTask.battery.refresh"

    private let repository: BatteryRepository
    private let service: BatteryServiceProtocol
    private let log = Logger(subsystem: "com.DaniilKukhar.TestTask", category: "battery-vm")

    // Expose UI-ready text publisher so views don't format or read UIDevice.
    /// Emits strings like "83%" or "--%" when level is unknown.
    internal lazy var batteryTextPublisher: AnyPublisher<String, Never> = {
        service.batteryLevelPublisher
            .map { [weak self] level in
                self?.formatPercentage(level) ?? "--%"
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()
    
    internal var currentBatteryText: String {
        formatPercentage(service.getBatteryLevel())
    }
    
    init(repository: BatteryRepository, service: BatteryServiceProtocol) {
        self.repository = repository
        self.service = service
    }
    
    // MARK: Formatting (single source of truth)
    
    /// Formats a normalized level into a percentage string for UI.
    func formatPercentage(_ level: Float) -> String {
        guard level >= 0 else { return "--%" }
        let v = Double(level * 100)
        let p = v < 10 ? floor(v) : round(v)
        return "\(Int(p))%"
    }

    // MARK: BGTaskScheduler

    /// Schedule a background app refresh; the system may run it later than `earliestBeginDate`.
    func scheduleBGTask() {
        guard #available(iOS 13.0, *) else { return }
        let req = BGAppRefreshTaskRequest(identifier: Self.bgTaskId)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 120) // execute no earlier than 2 minutes from now
        do { try BGTaskScheduler.shared.submit(req) }
        catch { log.debug("BGTask schedule failed: \(error.localizedDescription, privacy: .public)") }
    }

    @MainActor
    /// BGTask entry point. Runs sending work off the main thread, completes the task,
    /// and reschedules the next refresh.
    func handleBGTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = { }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { task.setTaskCompleted(success: false); return }
            let ok = await self.sendNow()
            task.setTaskCompleted(success: ok)
            self.scheduleBGTask()
        }
    }

    // MARK: Sending

    /// Called by the audio fallback timer.
    func sendOnceSilently() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let ok = await self.sendNow()
            if ok {
                self.scheduleBGTask()
            }
        }
    }

    /// Reads the current battery level and sends it. Returns true on success.
    @discardableResult
    private func sendNow() async -> Bool {
        let level = service.getBatteryLevel()
        guard level >= 0 else { return false }
        do {
            try await repository.sendBatteryLevel(level)
            log.debug("Send OK (level=\(level, privacy: .public))")
            return true
        } catch {
            log.debug("Send failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
