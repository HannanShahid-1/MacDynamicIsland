import Foundation

extension IslandStore {
    func startWeatherWatcher() {
        weatherTimer?.invalidate()
        if showHomeWeather {
            refreshWeatherIfConfigured(force: true)
        }

        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshWeatherFromTimer()
            }
        }
        timer.tolerance = 20.0

        weatherTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    var canApplyWeatherLocation: Bool {
        weatherStatus != .loading
            && weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var weatherOptionsStatusText: String {
        switch weatherStatus {
        case .notConfigured:
            return "Off until a city is saved"
        case .loading:
            return "Checking weather…"
        case .available:
            guard let weatherInfo else { return "Weather ready" }
            return "\(weatherInfo.locationName) · \(weatherInfo.temperatureText)"
        case .failed:
            return weatherErrorMessage ?? "Could not update weather"
        }
    }

    func applyWeatherLocationFromInput() {
        let query = weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            clearWeatherLocation()
            return
        }

        guard query.count >= 2 else {
            weatherErrorMessage = "Enter a city name"
            weatherStatus = .failed
            return
        }

        weatherLocationInput = query
        weatherRefreshTask?.cancel()
        weatherErrorMessage = nil
        weatherStatus = .loading

        weatherRefreshTask = Task { [weak self, query] in
            do {
                let result = try await OpenMeteoWeatherProvider.fetchWeather(forCity: query)
                guard !Task.isCancelled else { return }
                weatherLog.info("Weather city lookup succeeded: \(result.0.displayName, privacy: .public) \(result.1.temperatureFahrenheit, privacy: .public)°F")

                await MainActor.run {
                    guard let self else { return }

                    self.weatherLocation = result.0
                    self.storeWeatherLocation(result.0)
                    self.weatherLocationInput = result.0.displayName
                    self.weatherInfo = result.1
                    self.weatherErrorMessage = nil
                    self.weatherStatus = .available
                    self.lastWeatherRefreshDate = Date()
                    self.weatherRefreshTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                weatherLog.error("Weather city lookup failed for \"\(query, privacy: .public)\": \(String(describing: error), privacy: .public)")

                await MainActor.run {
                    guard let self else { return }
                    self.weatherErrorMessage = OpenMeteoWeatherProvider.userMessage(for: error)
                    self.weatherStatus = .failed
                    self.weatherRefreshTask = nil
                }
            }
        }
    }

    func clearWeatherLocation() {
        weatherRefreshTask?.cancel()
        weatherRefreshTask = nil
        weatherLocation = nil
        weatherInfo = nil
        weatherErrorMessage = nil
        weatherStatus = .notConfigured
        weatherLocationInput = ""
        lastWeatherRefreshDate = Date.distantPast
        UserDefaults.standard.removeObject(forKey: IslandDefaultsKey.weatherLocationName)
        UserDefaults.standard.removeObject(forKey: IslandDefaultsKey.weatherLatitude)
        UserDefaults.standard.removeObject(forKey: IslandDefaultsKey.weatherLongitude)
    }

    func handleHomeWeatherVisibilityChange() {
        if showHomeWeather {
            refreshWeatherIfConfigured(force: true)
            return
        }

        weatherRefreshTask?.cancel()
        weatherRefreshTask = nil
    }

    private func refreshWeatherFromTimer() {
        guard !ambientRefreshesArePaused else { return }
        guard showHomeWeather else { return }
        refreshWeatherIfConfigured(force: false)
    }

    private func refreshWeatherIfConfigured(force: Bool) {
        guard showHomeWeather else { return }

        guard let location = weatherLocation else {
            weatherStatus = .notConfigured
            return
        }

        guard force || Date().timeIntervalSince(lastWeatherRefreshDate) >= Self.weatherRefreshInterval else {
            return
        }

        guard weatherRefreshTask == nil else { return }
        if weatherInfo == nil {
            weatherStatus = .loading
        }

        weatherRefreshTask = Task { [weak self, location] in
            do {
                let info = try await OpenMeteoWeatherProvider.fetchWeather(for: location)
                guard !Task.isCancelled else { return }
                weatherLog.info("Weather refresh succeeded: \(info.locationName, privacy: .public) \(info.temperatureFahrenheit, privacy: .public)°F")

                await MainActor.run {
                    guard let self else { return }
                    self.weatherInfo = info
                    self.weatherErrorMessage = nil
                    self.weatherStatus = .available
                    self.lastWeatherRefreshDate = Date()
                    self.weatherRefreshTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                weatherLog.error("Weather refresh failed: \(String(describing: error), privacy: .public)")

                await MainActor.run {
                    guard let self else { return }
                    self.weatherErrorMessage = OpenMeteoWeatherProvider.userMessage(for: error)
                    self.weatherStatus = .failed
                    self.lastWeatherRefreshDate = Date()
                    self.weatherRefreshTask = nil
                }
            }
        }
    }
}
