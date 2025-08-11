//
//  AppContainer.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import Foundation

/// Simple DI container wiring services, repositories and coordinators.
internal final class AppContainer {
    internal static let shared = AppContainer()

    internal let http: HTTPClient
    internal let repository: BatteryRepository
    internal let batteryService: BatteryService
    internal let batteryVM: BatteryViewModel
    internal let backgroundCoordinator: BackgroundCoordinator

    private init() {
        self.http = HTTPClient()
        self.repository = NetworkBatteryRepository(httpClient: http)
        self.batteryService = BatteryService()

        let vm = BatteryViewModel(repository: repository, service: batteryService)
        self.batteryVM = vm

        let coord = BackgroundCoordinator(batteryViewModel: vm)
        self.backgroundCoordinator = coord
    }
}
