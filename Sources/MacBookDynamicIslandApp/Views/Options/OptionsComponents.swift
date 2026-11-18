import SwiftUI

struct OptionsSidebarButton: View {
    let tab: IslandOptionsTab
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: tab.systemName)
                    .font(.system(size: 14, weight: .bold))
                    .scaleEffect(isSelected ? 1.08 : (isHovered ? 1.12 : 1))
                    .frame(width: 22)

                Text(tab.title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 0.96 : (isHovered ? 0.80 : 0.58)))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(isHovered && !isSelected ? 0.055 : 0.0))

                    // One highlight for the whole sidebar: it slides to the
                    // selected row.
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(tab.title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }

}

struct OptionsPanelHeader: View {
    let title: String
    let detail: String
    let systemName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text(detail)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
            }

            Spacer(minLength: 0)
        }
    }
}

struct OptionsSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.42))
                .padding(.leading, 2)

            VStack(spacing: 10) {
                content()
            }
        }
    }
}

struct OptionsSettingRow<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
                .frame(width: 142, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.052))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.085), lineWidth: 1)
        )
    }
}

struct OptionsToggleRow: View {
    let systemName: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                Text(detail)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.46))
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(GreenSwitchToggleStyle())
                .fixedSize()
                .help(title)
        }
        .padding(16)
        .frame(minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

struct OptionsInlineIconButton: View {
    let systemName: String
    let iconSize: CGFloat
    let baseOpacity: CGFloat
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .black))
                .scaleEffect(isHovered && isEnabled ? 1.12 : 1)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(isHovered && isEnabled ? baseOpacity + 0.06 : baseOpacity))
                )
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(IslandButtonPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
        .help(title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }
}

struct ColorSwatchButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.28))
                            .frame(width: 18, height: 18)

                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                    .transition(.islandPop(scale: 0.3))
                }
            }
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(ringOpacity), lineWidth: isSelected ? 1.6 : 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.30 : 0.0), radius: 5, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.10 : 1.0)
            .contentShape(Circle())
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }

    private var ringOpacity: CGFloat {
        if isSelected { return 0.82 }
        return isHovered ? 0.50 : 0.24
    }
}
