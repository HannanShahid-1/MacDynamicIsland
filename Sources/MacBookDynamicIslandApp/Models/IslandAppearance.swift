import SwiftUI

enum IslandBackgroundOption: String, CaseIterable, Identifiable {
    case black
    case graphite
    case midnight
    case evergreen
    case bordeaux
    case porcelain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black:
            return "Black"
        case .graphite:
            return "Graphite"
        case .midnight:
            return "Midnight"
        case .evergreen:
            return "Evergreen"
        case .bordeaux:
            return "Bordeaux"
        case .porcelain:
            return "Porcelain"
        }
    }

    var color: Color {
        switch self {
        case .black:
            return Color.black
        case .graphite:
            return Color(red: 0.075, green: 0.078, blue: 0.086)
        case .midnight:
            return Color(red: 0.025, green: 0.050, blue: 0.105)
        case .evergreen:
            return Color(red: 0.025, green: 0.105, blue: 0.085)
        case .bordeaux:
            return Color(red: 0.150, green: 0.035, blue: 0.060)
        case .porcelain:
            return Color(red: 0.910, green: 0.900, blue: 0.860)
        }
    }
}

enum IslandTextOption: String, CaseIterable, Identifiable {
    case white
    case graphite
    case warm
    case ice
    case mint
    case amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white:
            return "White"
        case .graphite:
            return "Graphite"
        case .warm:
            return "Warm"
        case .ice:
            return "Ice"
        case .mint:
            return "Mint"
        case .amber:
            return "Amber"
        }
    }

    var color: Color {
        switch self {
        case .white:
            return Color.white
        case .graphite:
            return Color(red: 0.075, green: 0.078, blue: 0.086)
        case .warm:
            return Color(red: 1.000, green: 0.945, blue: 0.840)
        case .ice:
            return Color(red: 0.760, green: 0.900, blue: 1.000)
        case .mint:
            return Color(red: 0.710, green: 1.000, blue: 0.850)
        case .amber:
            return Color(red: 1.000, green: 0.780, blue: 0.360)
        }
    }
}

struct IslandTextColorKey: EnvironmentKey {
    static let defaultValue = Color.white
}

extension EnvironmentValues {
    var islandTextColor: Color {
        get { self[IslandTextColorKey.self] }
        set { self[IslandTextColorKey.self] = newValue }
    }
}
