import Foundation

enum WeatherAvailability: Equatable {
    case notConfigured
    case loading
    case available
    case failed
}

struct WeatherLocation: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double

    var displayName: String {
        name
    }
}

struct WeatherInfo: Equatable {
    var locationName: String
    var temperatureFahrenheit: Int
    var weatherCode: Int
    var isDay: Bool
    var updatedAt: Date

    var temperatureText: String {
        "\(temperatureFahrenheit)°"
    }

    var systemName: String {
        switch weatherCode {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        }
    }
}
