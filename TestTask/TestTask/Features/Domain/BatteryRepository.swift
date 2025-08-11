//
//  BatteryRepository.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import Foundation

/// Abstraction over network/storage for sending battery level.
internal protocol BatteryRepository {
    func sendBatteryLevel(_ level: Float) async throws
}
