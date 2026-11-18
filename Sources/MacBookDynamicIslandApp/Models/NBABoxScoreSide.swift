import Foundation

enum NBABoxScoreSide: String, CaseIterable, Identifiable {
    case away
    case home

    var id: String { rawValue }
}
