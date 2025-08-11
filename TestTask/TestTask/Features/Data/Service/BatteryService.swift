//
//  BatteryService.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import Combine
import UIKit

/// Provides access to battery-related information.
/// Implementations should return a normalized battery level or an "unknown" sentinel.
/// Use when UI or background processes need the current battery percentage.
internal protocol BatteryServiceProtocol {
    /// Returns the current battery level as a fraction in the range [0.0, 1.0].
    /// - Returns: A value where 1.0 == 100% charge, 0.0 == 0% charge, or -1.0 if the level is unknown.
    func getBatteryLevel() -> Float

    var batteryLevelPublisher: AnyPublisher<Float, Never> { get }
}

// MARK: - Battery Service
/// UIKit-backed implementation of `BatteryServiceProtocol` that reads from `UIDevice`.
internal final class BatteryService: BatteryServiceProtocol {
    private let subject: CurrentValueSubject<Float, Never>
    private var bag = Set<AnyCancellable>()

    internal init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        subject = CurrentValueSubject<Float, Never>(UIDevice.current.batteryLevel)

        // Bridge NotificationCenter → Combine subject
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .map { _ in UIDevice.current.batteryLevel }
            .sink { [subject] level in
                subject.send(level)
            }
            .store(in: &bag)
    }

    internal func getBatteryLevel() -> Float { UIDevice.current.batteryLevel }

    internal var batteryLevelPublisher: AnyPublisher<Float, Never> {
        subject.eraseToAnyPublisher()
    }
}
