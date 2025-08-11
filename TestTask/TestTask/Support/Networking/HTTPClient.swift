//
//  HTTPClient.swift
//  TestTask
//
//  Created by Daniil Kukhar on 8/11/25.
//

import Foundation
import OSLog

internal final class HTTPClient {
    private let session: URLSession
    private let log = Logger(subsystem: "com.DaniilKukhar.TestTask", category: "network")

    internal init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 45
        self.session = URLSession(configuration: cfg)
    }

    /// Sends JSON body to URL and returns (data, statusCode) for verification/logging.
    @discardableResult
    internal func post(to url: String, body: Data) async throws -> (Data, Int) {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        log.debug("POST \(url.absoluteString, privacy: .public) → status \(code), bytes \(data.count)")
        return (data, code)
    }
}
