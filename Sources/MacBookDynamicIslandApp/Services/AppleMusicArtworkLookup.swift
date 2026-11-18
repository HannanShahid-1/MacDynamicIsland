import Foundation

enum AppleMusicArtworkLookup {
    static func fetchArtworkData(searchTerms: [String]) async -> Data? {
        for searchTerm in searchTerms {
            for entity in SearchEntity.allCases {
                guard let searchURL = searchURL(for: searchTerm, entity: entity) else { continue }

                do {
                    let (searchData, searchResponse) = try await session.data(from: searchURL)
                    guard isSuccessfulHTTPResponse(searchResponse),
                          let artworkURL = try artworkURL(from: searchData) else {
                        continue
                    }

                    let (artworkData, artworkResponse) = try await session.data(from: artworkURL)
                    guard isSuccessfulHTTPResponse(artworkResponse), !artworkData.isEmpty else {
                        continue
                    }

                    return artworkData
                } catch {
                    continue
                }
            }
        }

        return nil
    }

    private static func searchURL(for searchTerm: String, entity: SearchEntity) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: searchTerm),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: entity.rawValue),
            URLQueryItem(name: "country", value: "US"),
            URLQueryItem(name: "limit", value: "10")
        ]
        return components?.url
    }

    private static func artworkURL(from data: Data) throws -> URL? {
        let response = try JSONDecoder().decode(ArtworkSearchResponse.self, from: data)

        for result in response.results {
            guard let artworkURL = result.artworkURL else { continue }
            return largerArtworkURL(from: artworkURL)
        }

        return nil
    }

    private static func largerArtworkURL(from url: URL) -> URL {
        let urlString = url.absoluteString
            .replacingOccurrences(of: "100x100bb", with: "600x600bb")
            .replacingOccurrences(of: "100x100-75", with: "600x600-75")
        return URL(string: urlString) ?? url
    }

    private static func isSuccessfulHTTPResponse(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(httpResponse.statusCode)
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    private struct ArtworkSearchResponse: Decodable {
        var results: [ArtworkSearchResult]
    }

    private struct ArtworkSearchResult: Decodable {
        var artworkURL: URL?

        enum CodingKeys: String, CodingKey {
            case artworkURL = "artworkUrl100"
        }
    }

    private enum SearchEntity: String, CaseIterable {
        case song
        case album
    }
}
