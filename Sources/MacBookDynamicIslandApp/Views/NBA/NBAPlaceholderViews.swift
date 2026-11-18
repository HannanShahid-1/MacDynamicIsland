import SwiftUI

struct NBAEmptyStateView: View {
    let systemName: String
    let title: String
    let detail: String
    let buttonTitle: String?
    let action: (() -> Void)?
    @State private var isButtonHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .frame(width: 48, height: 48)
                .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.18).opacity(0.92))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .frame(width: 74, height: 32)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(isButtonHovered ? 0.18 : 0.12))
                        )
                        .scaleEffect(isButtonHovered ? 1.05 : 1)
                }
                .buttonStyle(IslandButtonPressStyle())
                .onHover { hovering in
                    withAnimation(IslandMotion.hover) {
                        isButtonHovered = hovering
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }
}

struct NBALoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    NBASkeletonBlock(width: 150, height: 48)
                }
            }

            NBASkeletonBlock(width: nil, height: 64)
        }
        .padding(.top, 3)
    }
}

struct NBAPlayerRowsLoadingView: View {
    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                NBASkeletonBlock(width: nil, height: 14)
            }
        }
        .padding(.top, 2)
    }
}

struct NBASkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var isShimmering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay {
                GeometryReader { proxy in
                    let bandWidth = max(proxy.size.width * 0.55, 40)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.085),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: isShimmering ? proxy.size.width : -bandWidth)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    isShimmering = true
                }
            }
    }
}

struct NBAInlineMessage: View {
    let systemName: String
    let text: String
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(islandTextColor.opacity(0.50))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
