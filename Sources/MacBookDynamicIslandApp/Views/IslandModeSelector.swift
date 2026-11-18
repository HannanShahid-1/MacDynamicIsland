import SwiftUI

/// The small capsule of mode icons shown beside the notch while the island is expanded.
struct IslandModeSelector: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 1) {
            ForEach(store.visibleModes, id: \.self) { mode in
                ModeSelectorButton(
                    systemName: store.modeSystemName(for: mode),
                    title: store.modeTitle(for: mode),
                    isSelected: store.islandMode == mode,
                    selectionNamespace: selectionNamespace
                ) {
                    withAnimation(IslandMotion.select) {
                        switch mode {
                        case .player:
                            store.showPlayerMode()
                        case .nba:
                            store.showNBAMode()
                        case .workspace:
                            store.showWorkspaceMode()
                        }
                    }
                }
            }
        }
        .padding(2)
        .frame(width: store.modeSelectorWidth, height: IslandMetrics.modeSelectorHeight)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
        )
        .overlay {
            Capsule()
                .stroke(islandTextColor.opacity(0.18), lineWidth: 1)
        }
        // However the mode changed (click, swipe, a dropped file), the highlight
        // slides to it.
        .animation(IslandMotion.select, value: store.islandMode)
    }
}

struct ModeSelectorButton: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .black))
                .scaleEffect(iconScale)
                .frame(width: 16, height: 16)
                .foregroundStyle(islandTextColor.opacity(isSelected ? 0.96 : (isHovered ? 0.78 : 0.48)))
                .background {
                    ZStack {
                        if isHovered && !isSelected {
                            Circle()
                                .fill(islandTextColor.opacity(0.08))
                                .transition(.islandPop())
                        }

                        // One highlight shared by every button: it travels to
                        // whichever is selected instead of blinking off and on.
                        if isSelected {
                            Circle()
                                .fill(islandTextColor.opacity(0.14))
                                .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                        }
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(IslandButtonPressStyle(pressedScale: 0.84))
        .help(title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }

    private var iconScale: CGFloat {
        if isSelected { return 1.06 }
        return isHovered ? 1.14 : 0.94
    }
}
