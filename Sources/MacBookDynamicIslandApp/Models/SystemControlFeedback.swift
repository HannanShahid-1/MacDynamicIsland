import SwiftUI

enum SystemControlFeedbackKind: Equatable {
    case volume
    case brightness

    func systemName(level: CGFloat) -> String {
        switch self {
        case .volume:
            if level <= 0.001 { return "speaker.slash.fill" }
            if level < 0.34 { return "speaker.wave.1.fill" }
            if level < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return level < 0.34 ? "sun.min.fill" : "sun.max.fill"
        }
    }

    var tint: Color {
        Color(red: 0.800, green: 0.940, blue: 1.000)
    }
}

struct SystemControlFeedback: Identifiable, Equatable {
    let id: UUID
    let kind: SystemControlFeedbackKind
    let level: CGFloat

    init(kind: SystemControlFeedbackKind, level: Float) {
        id = UUID()
        self.kind = kind
        self.level = CGFloat(min(max(level, 0), 1))
    }
}
