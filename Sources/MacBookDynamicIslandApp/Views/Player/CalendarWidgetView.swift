import SwiftUI

struct CalendarWidgetView: View {
    @ObservedObject var store: IslandStore
    var showsWeather = true
    var reservesWeatherSpace = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60.0)) { context in
            let model = CalendarStripModel(date: context.date)

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(model.monthTitle)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                            .foregroundStyle(islandTextColor)
                            .frame(width: 50, alignment: .leading)

                        HStack(spacing: 3) {
                            ForEach(model.days) { day in
                                CalendarDayPill(day: day)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, showsWeather || reservesWeatherSpace ? 66 : 8)
                    }
                    .padding(.top, 7)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(islandTextColor.opacity(0.07))
                            )

                        Text("Nothing for today")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundStyle(islandTextColor.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if showsWeather {
                    WeatherMiniWidgetView(store: store)
                        .offset(x: 4, y: -10)
                }
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct WeatherMiniWidgetView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 21, height: 21)

            Text(temperatureText)
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .foregroundStyle(textColor)
        }
        .frame(width: 62, height: 26, alignment: .trailing)
        .contentShape(Rectangle())
        .help(helpText)
    }

    private var iconName: String {
        if store.weatherStatus == .loading && store.weatherInfo == nil {
            return "cloud.sun"
        }

        return store.weatherInfo?.systemName ?? "cloud.sun"
    }

    private var temperatureText: String {
        store.weatherInfo?.temperatureText ?? "--°"
    }

    private var textColor: Color {
        store.weatherInfo == nil ? islandTextColor.opacity(0.42) : islandTextColor.opacity(0.90)
    }

    private var iconColor: Color {
        guard let info = store.weatherInfo else {
            return islandTextColor.opacity(0.42)
        }

        switch info.weatherCode {
        case 0:
            return info.isDay ? Color.yellow.opacity(0.96) : Color(red: 0.76, green: 0.84, blue: 1.00)
        case 1, 2:
            return info.isDay ? Color.yellow.opacity(0.84) : Color(red: 0.70, green: 0.78, blue: 0.96)
        case 45, 48:
            return Color.gray.opacity(0.88)
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99:
            return Color(red: 0.42, green: 0.68, blue: 1.00)
        case 71, 73, 75, 77, 85, 86:
            return Color(red: 0.78, green: 0.88, blue: 1.00)
        default:
            return islandTextColor.opacity(0.64)
        }
    }

    private var helpText: String {
        switch store.weatherStatus {
        case .notConfigured:
            return "Set weather city in Options"
        case .loading:
            return "Checking weather"
        case .available:
            guard let info = store.weatherInfo else { return "Weather" }
            return "\(info.locationName) \(info.temperatureText)"
        case .failed:
            return store.weatherInfo == nil ? "Weather unavailable" : "Weather update failed"
        }
    }
}

struct CalendarDayPill: View {
    let day: CalendarStripDay
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(spacing: 2) {
            Text(day.weekday)
                .font(.system(size: day.isToday ? 9 : 8.5, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(day.dayNumber)
                .font(.system(size: day.isToday ? 17 : 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .frame(width: day.isToday ? 35 : 25, height: 43)
        .background {
            if day.isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.00, green: 0.53, blue: 0.94).opacity(0.20))
            }
        }
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.10, green: 0.67, blue: 1.00).opacity(0.72), lineWidth: 1)
            }
        }
    }

    private var foregroundColor: Color {
        if day.isToday {
            return Color(red: 0.20, green: 0.73, blue: 1.00)
        }

        if day.isWeekend {
            return Color(red: 1.00, green: 0.45, blue: 0.38).opacity(0.56)
        }

        return islandTextColor.opacity(0.54)
    }
}

struct CalendarStripModel {
    let monthTitle: String
    let days: [CalendarStripDay]

    init(date: Date) {
        let calendar = Calendar.current
        monthTitle = Self.formatted(date, format: "MMM")
        days = (-3...3).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else {
                return nil
            }

            let startOfDay = calendar.startOfDay(for: day)
            let weekdayIndex = calendar.component(.weekday, from: day)

            return CalendarStripDay(
                id: startOfDay.timeIntervalSinceReferenceDate,
                weekday: Self.formatted(day, format: "EEE").uppercased(),
                dayNumber: Self.formatted(day, format: "dd"),
                isToday: calendar.isDateInToday(day),
                isWeekend: weekdayIndex == 1 || weekdayIndex == 7
            )
        }
    }

    private static func formatted(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

struct CalendarStripDay: Identifiable {
    let id: TimeInterval
    let weekday: String
    let dayNumber: String
    let isToday: Bool
    let isWeekend: Bool
}
