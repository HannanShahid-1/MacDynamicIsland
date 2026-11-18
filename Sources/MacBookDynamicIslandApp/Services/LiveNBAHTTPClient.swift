import Foundation
import MacBookDynamicIslandCore

final class LiveNBAHTTPClient: NBAHTTPClient, @unchecked Sendable {
    static let shared = LiveNBAHTTPClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        session = URLSession(configuration: configuration)
    }

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NBADataError.badStatus(-1)
        }
        return (data, httpResponse)
    }
}
