import Foundation

enum IslandMode: Hashable {
    case player
    case nba
    case workspace
}

enum IslandLayoutMode: String, CaseIterable, Hashable, Identifiable {
    case classicThreeModes
    case customTwoModes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classicThreeModes:
            return "Classic"
        case .customTwoModes:
            return "Two UI"
        }
    }
}

enum HomeWidget: String, CaseIterable, Hashable, Identifiable {
    /// The now-playing card. The raw value predates Spotify and browser support
    /// and is kept because it is what saved layouts contain.
    case appleMusic
    case calendar
    case nbaScores

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic:
            return "Now Playing"
        case .calendar:
            return "Calendar"
        case .nbaScores:
            return "NBA Scores"
        }
    }

    var shortTitle: String {
        switch self {
        case .appleMusic:
            return "Music"
        case .calendar:
            return "Calendar"
        case .nbaScores:
            return "NBA"
        }
    }

    var systemName: String {
        switch self {
        case .appleMusic:
            return "music.note"
        case .calendar:
            return "calendar"
        case .nbaScores:
            return "basketball.fill"
        }
    }

    static let defaultOrder: [HomeWidget] = [.appleMusic, .calendar]
    static let optionOrder: [HomeWidget] = [.calendar, .appleMusic, .nbaScores]
}

enum IslandSizeOption: String, CaseIterable, Identifiable {
    case standard = "default"
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Default"
        case .large:
            return "Large"
        }
    }
}
