import Foundation

enum IslandDefaultsKey {
    static let backgroundOption = "island.appearance.backgroundOption"
    static let textOption = "island.appearance.textOption"
    static let sizeOption = "island.appearance.sizeOption"
    static let autoExpandOnHover = "island.behavior.autoExpandOnHover"
    static let weatherLocationInput = "island.weather.locationInput"
    static let weatherLocationName = "island.weather.locationName"
    static let weatherLatitude = "island.weather.latitude"
    static let weatherLongitude = "island.weather.longitude"
    static let nbaScoresEnabled = "island.nba.scoresEnabled"
    static let layoutMode = "island.layout.mode"
    static let homeWidgets = "island.layout.homeWidgets"
    static let showHomeWeather = "island.layout.showHomeWeather"
}

extension IslandStore {
    static func storedBackgroundOption() -> IslandBackgroundOption {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.backgroundOption) else {
            return .black
        }

        return IslandBackgroundOption(rawValue: rawValue) ?? .black
    }

    static func storedTextOption() -> IslandTextOption {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.textOption) else {
            return .white
        }

        return IslandTextOption(rawValue: rawValue) ?? .white
    }

    static func storedSizeOption() -> IslandSizeOption {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.sizeOption) else {
            return .standard
        }

        return IslandSizeOption(rawValue: rawValue) ?? .standard
    }

    static func storedLayoutMode() -> IslandLayoutMode {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.layoutMode) else {
            return .classicThreeModes
        }

        return IslandLayoutMode(rawValue: rawValue) ?? .classicThreeModes
    }

    static func storedHomeWidgets() -> [HomeWidget] {
        let rawValues = UserDefaults.standard.stringArray(forKey: IslandDefaultsKey.homeWidgets) ?? []
        let widgets = rawValues.compactMap(HomeWidget.init(rawValue:))
        let cleanedWidgets = uniquedHomeWidgets(widgets)
        return cleanedWidgets.isEmpty ? HomeWidget.defaultOrder : cleanedWidgets
    }

    static func storedShowHomeWeather() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: IslandDefaultsKey.showHomeWeather) != nil else {
            return true
        }

        return defaults.bool(forKey: IslandDefaultsKey.showHomeWeather)
    }

    static func storedWeatherLocationInput() -> String {
        UserDefaults.standard.string(forKey: IslandDefaultsKey.weatherLocationInput) ?? ""
    }

    static func storedWeatherLocation() -> WeatherLocation? {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: IslandDefaultsKey.weatherLocationName),
              !name.isEmpty,
              defaults.object(forKey: IslandDefaultsKey.weatherLatitude) != nil,
              defaults.object(forKey: IslandDefaultsKey.weatherLongitude) != nil else {
            return nil
        }

        return WeatherLocation(
            name: name,
            latitude: defaults.double(forKey: IslandDefaultsKey.weatherLatitude),
            longitude: defaults.double(forKey: IslandDefaultsKey.weatherLongitude)
        )
    }

    func storeWeatherLocation(_ location: WeatherLocation) {
        let defaults = UserDefaults.standard
        defaults.set(location.displayName, forKey: IslandDefaultsKey.weatherLocationName)
        defaults.set(location.latitude, forKey: IslandDefaultsKey.weatherLatitude)
        defaults.set(location.longitude, forKey: IslandDefaultsKey.weatherLongitude)
    }
}
