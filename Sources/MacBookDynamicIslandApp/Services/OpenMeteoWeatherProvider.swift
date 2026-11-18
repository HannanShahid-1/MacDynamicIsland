import Foundation
import os

let weatherLog = Logger(subsystem: "local.hannan.MacBookDynamicIslandApp", category: "weather")

enum OpenMeteoWeatherProvider {
    static func fetchWeather(forCity query: String) async throws -> (WeatherLocation, WeatherInfo) {
        let location = try await resolveLocation(for: query)
        let info = try await fetchWeather(for: location)
        return (location, info)
    }

    static func fetchWeather(for location: WeatherLocation) async throws -> WeatherInfo {
        guard let weatherURL = weatherURL(for: location) else {
            throw WeatherLookupError.invalidURL
        }

        let (data, response) = try await data(from: weatherURL)
        guard isSuccessfulHTTPResponse(response) else {
            throw WeatherLookupError.badResponse
        }

        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return WeatherInfo(
            locationName: location.displayName,
            temperatureFahrenheit: Int(forecast.current.temperature2m.rounded()),
            weatherCode: forecast.current.weatherCode,
            isDay: forecast.current.isDay == 1,
            updatedAt: Date()
        )
    }

    private static func resolveLocation(for query: String) async throws -> WeatherLocation {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            throw WeatherLookupError.emptyQuery
        }

        guard let geocodingURL = geocodingURL(for: trimmedQuery) else {
            throw WeatherLookupError.invalidURL
        }

        let (data, response) = try await data(from: geocodingURL)
        guard isSuccessfulHTTPResponse(response) else {
            throw WeatherLookupError.badResponse
        }

        let geocoding = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        guard let result = geocoding.results?.first else {
            throw WeatherLookupError.locationNotFound
        }

        return WeatherLocation(
            name: displayName(for: result),
            latitude: result.latitude,
            longitude: result.longitude
        )
    }

    private static func geocodingURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        return components?.url
    }

    private static func weatherURL(for location: WeatherLocation) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        return components?.url
    }

    private static func displayName(for result: GeocodingResult) -> String {
        var pieces = [result.name]

        if let admin1 = result.admin1?.trimmingCharacters(in: .whitespacesAndNewlines),
           !admin1.isEmpty,
           admin1.caseInsensitiveCompare(result.name) != .orderedSame {
            pieces.append(admin1)
        }

        if let country = result.country?.trimmingCharacters(in: .whitespacesAndNewlines),
           !country.isEmpty,
           !pieces.contains(where: { $0.caseInsensitiveCompare(country) == .orderedSame }) {
            pieces.append(country)
        }

        return pieces.joined(separator: ", ")
    }

    private static func isSuccessfulHTTPResponse(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(httpResponse.statusCode)
    }

    /// Fetches a URL, retrying once on transient network errors (timeout, connection
    /// lost, DNS hiccup) so a single flaky request doesn't fail the whole update.
    private static func data(from url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch let error as URLError where Self.transientCodes.contains(error.code) {
            weatherLog.notice("Transient weather network error (\(error.code.rawValue, privacy: .public)); retrying once")
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await session.data(from: url)
        }
    }

    private static let transientCodes: Set<URLError.Code> = [
        .timedOut, .networkConnectionLost, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet
    ]

    /// Maps any thrown error to a short, user-facing reason shown in Options.
    static func userMessage(for error: Error) -> String {
        if let lookupError = error as? WeatherLookupError {
            switch lookupError {
            case .emptyQuery:
                return "Enter a city name"
            case .locationNotFound:
                return "City not found — check spelling"
            case .invalidURL, .badResponse:
                return "Weather service unavailable"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost:
                return "No internet connection"
            case .timedOut, .networkConnectionLost:
                return "Weather request timed out"
            default:
                return "Network error — try again"
            }
        }
        if error is DecodingError {
            return "Unexpected weather data"
        }
        return "Could not update weather"
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    enum WeatherLookupError: Error {
        case emptyQuery
        case invalidURL
        case badResponse
        case locationNotFound
    }

    private struct GeocodingResponse: Decodable {
        var results: [GeocodingResult]?
    }

    private struct GeocodingResult: Decodable {
        var name: String
        var latitude: Double
        var longitude: Double
        var admin1: String?
        var country: String?
    }

    private struct ForecastResponse: Decodable {
        var current: CurrentWeather
    }

    private struct CurrentWeather: Decodable {
        var temperature2m: Double
        var weatherCode: Int
        var isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }
}
