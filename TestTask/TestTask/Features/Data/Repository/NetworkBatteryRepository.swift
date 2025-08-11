//
//  NetworkBatteryRepository.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import Foundation
import OSLog

internal final class NetworkBatteryRepository: BatteryRepository {
    private let httpClient: HTTPClient
    private let iso = ISO8601DateFormatter()
    private let log = Logger(subsystem: "com.DaniilKukhar.TestTask", category: "network")

    internal init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    internal func sendBatteryLevel(_ level: Float) async throws {
        // Build payload
        let payload: [String: Any] = [
            "level": level,
            "timestamp": iso.string(from: Date())
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])

        // Base64 wrap for basic protection
        let base64 = jsonData.base64EncodedString()

        // JSON wrapper as required: { "data": "<b64>" }
        let wrapper = ["data": base64]
        let body = try JSONSerialization.data(withJSONObject: wrapper, options: [])

        // Send and log result (HTTPClient.post returns (Data, Int))
        let (data, code) = try await httpClient.post(
            to: "https://jsonplaceholder.typicode.com/posts",
            body: body
        )

        guard (200..<300).contains(code) else {
            log.error("Battery send failed, status=\(code)")
            throw URLError(.badServerResponse)
        }

        let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8 \(data.count)B>"
        log.debug("Battery sent OK, status=\(code), respPreview=\(preview, privacy: .auto)")
    }
}
