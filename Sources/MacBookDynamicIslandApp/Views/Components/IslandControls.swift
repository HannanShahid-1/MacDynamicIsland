import SwiftUI

/// Sinks under the pointer at once, then springs back past its resting size on release.
struct IslandButtonPressStyle: ButtonStyle {
    /// Small controls can sink further than large ones before it looks like a lurch.
    var pressedScale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(
                configuration.isPressed ? IslandMotion.pressDown : IslandMotion.pressUp,
                value: configuration.isPressed
            )
    }
}

struct IconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    @State private var isConfirming = false
    @State private var isHovered = false
    @State private var confirmationTask: Task<Void, Never>?
    @Environment(\.islandTextColor) private var islandTextColor
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .opacity(iconOpacity)
                .scaleEffect(isHovered && !isConfirming ? 1.08 : 1.0)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(islandTextColor.opacity(backgroundOpacity))
                        .scaleEffect(isConfirming ? 1.12 : (isHovered ? 1.0 : 0.6))
                )
                .scaleEffect(isConfirming ? 0.80 : 1.0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering && isEnabled
            }
        }
        .onDisappear {
            confirmationTask?.cancel()
        }
    }

    private var iconOpacity: CGFloat {
        guard isEnabled else { return 0.34 }
        return isHovered ? 1.0 : 0.88
    }

    private var backgroundOpacity: CGFloat {
        if isConfirming { return 0.22 }
        return isHovered ? 0.12 : 0.0
    }

    private func handleTap() {
        action()
        confirmationTask?.cancel()

        // A quick squeeze, then a springy release: the click visibly lands.
        withAnimation(IslandMotion.pressDown) {
            isConfirming = true
        }

        confirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(IslandMotion.pressUp) {
                isConfirming = false
            }
            confirmationTask = nil
        }
    }
}

struct GreenSwitchToggleStyle: ToggleStyle {
    @Environment(\.islandTextColor) private var islandTextColor

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(IslandMotion.toggle) {
                configuration.isOn.toggle()
            }
        } label: {
            Capsule()
                .fill(configuration.isOn ? Color(red: 0.18, green: 0.70, blue: 0.34) : islandTextColor.opacity(0.18))
                .frame(width: 34, height: 20)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.black.opacity(0.22), radius: 1.5, x: 0, y: 1)
                        .padding(2)
                }
                .overlay {
                    Capsule()
                        .stroke(islandTextColor.opacity(configuration.isOn ? 0.18 : 0.12), lineWidth: 1)
                }
        }
        .buttonStyle(IslandButtonPressStyle())
    }
}
