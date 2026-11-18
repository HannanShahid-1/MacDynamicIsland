import AppKit
import SwiftUI

struct NowPlayingCardView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    private var info: NowPlayingInfo {
        store.nowPlaying
    }

    private var titleFontSize: CGFloat {
        info.hasContent ? 14 : 12.2
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NowPlayingArtworkView(
                artworkImage: info.artwork,
                placeholderIcon: info.hasContent
                    ? NowPlayingSourceCatalog.icon(forBundleID: info.sourceBundleID)
                    : nil
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(notchSafeTitle)
                    .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .foregroundStyle(islandTextColor)
                    .contentTransition(.opacity)
                    .animation(IslandMotion.crossfade, value: notchSafeTitle)
                    .frame(maxWidth: titleMaxWidth, alignment: .leading)
                    .padding(.top, info.hasContent ? 0 : 3)

                Text(info.displayArtist)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(islandTextColor.opacity(0.82))
                    .contentTransition(.opacity)
                    .animation(IslandMotion.crossfade, value: info.displayArtist)

                HStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 8, weight: .bold))
                    Text(info.detailLine)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                        .animation(IslandMotion.crossfade, value: info.detailLine)
                }
                .foregroundStyle(islandTextColor.opacity(0.58))
                .padding(.top, 1)

                if info.progressFraction != nil {
                    progressRow
                        .padding(.top, 3)
                    Spacer(minLength: 1)
                } else {
                    Spacer(minLength: 2)
                }

                HStack(spacing: 9) {
                    MediaControlButton(
                        systemName: "backward.fill",
                        title: "Previous",
                        isEnabled: info.controls.previous && info.hasContent,
                        action: store.playPreviousTrack
                    )

                    MediaControlButton(
                        systemName: info.playbackState.isPlaying ? "pause.fill" : "play.fill",
                        title: info.playbackState.isPlaying ? "Pause" : "Play",
                        isEnabled: info.controls.playPause && info.hasContent,
                        isPrimary: true,
                        action: store.togglePlayPause
                    )

                    MediaControlButton(
                        systemName: "forward.fill",
                        title: "Next",
                        isEnabled: info.controls.next && info.hasContent,
                        action: store.playNextTrack
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 94, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(IslandMotion.rearrange, value: info.progressFraction != nil)
    }

    private var progressRow: some View {
        let fraction = CGFloat(info.progressFraction ?? 0)

        return HStack(spacing: 6) {
            Text(info.positionText ?? "0:00")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(islandTextColor.opacity(0.52))
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(islandTextColor.opacity(0.16))

                    Capsule()
                        .fill(islandTextColor.opacity(0.85))
                        .frame(width: max(2.5, proxy.size.width * fraction))
                }
            }
            .frame(height: 3)
            .animation(.linear(duration: 0.85), value: fraction)

            Text(info.durationText ?? "--:--")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(islandTextColor.opacity(0.52))
                .lineLimit(1)
        }
        .frame(height: 9)
    }

    private var titleMaxWidth: CGFloat {
        store.expandedSizeOption == .large ? 210 : 132
    }

    private var notchSafeTitle: String {
        guard info.hasContent else {
            return info.displayTitle
        }

        let title = info.displayTitle.uppercased()
        let featureMarkers = [" (FEAT", " FEAT.", " FEAT ", " (FT", " FT.", " FT "]

        for marker in featureMarkers {
            if let range = title.range(of: marker) {
                return title[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
            }
        }

        let words = title.split(separator: " ")
        if words.count >= 4 {
            return words.prefix(2).joined(separator: " ") + "..."
        }

        if title.count > maxTitleCharacters {
            let prefix = title.prefix(maxTitleCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
            return prefix + "..."
        }

        return title
    }

    private var maxTitleCharacters: Int {
        store.expandedSizeOption == .large ? 26 : 18
    }
}

struct NowPlayingArtworkView: View {
    let artworkImage: NSImage?
    /// Icon of the app that is playing, shown when the media has no artwork of its own.
    var placeholderIcon: NSImage?
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        artwork
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(islandTextColor.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
            .frame(width: 84, height: 84)
            .animation(IslandMotion.select, value: artworkImage.map(ObjectIdentifier.init))
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            islandTextColor.opacity(0.14),
                            islandTextColor.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    if let placeholderIcon {
                        Image(nsImage: placeholderIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(islandTextColor.opacity(0.70))
                    }
                }

            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .scaledToFill()
                    .id(ObjectIdentifier(artworkImage))
                    // New artwork settles in from slightly oversized, so the frame
                    // stays full while one cover replaces another.
                    .transition(.opacity.combined(with: .scale(scale: 1.14)))
            }
        }
    }
}

struct MediaControlButton: View {
    let systemName: String
    let title: String
    let isEnabled: Bool
    var isPrimary = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        Button(action: action) {
            ZStack {
                // Keyed by glyph so play and pause pop past each other.
                Image(systemName: systemName)
                    .font(.system(size: isPrimary ? 13 : 11, weight: .black))
                    .id(systemName)
                    .transition(.islandPop(scale: 0.4))
            }
                .animation(IslandMotion.pop, value: systemName)
                .frame(width: isPrimary ? 28 : 22, height: isPrimary ? 28 : 22)
                .foregroundStyle(islandTextColor.opacity(isEnabled ? (isHovered ? 1.0 : 0.95) : 0.30))
                .background {
                    Circle()
                        .fill(islandTextColor.opacity(backgroundOpacity))
                }
                .scaleEffect(isHovered && isEnabled ? 1.12 : 1.0)
                .contentShape(Circle())
        }
        .buttonStyle(IslandButtonPressStyle(pressedScale: 0.86))
        .disabled(!isEnabled)
        .help(title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering && isEnabled
            }
        }
    }

    private var backgroundOpacity: CGFloat {
        if isPrimary {
            guard isEnabled else { return 0.06 }
            return isHovered ? 0.20 : 0.13
        }

        return isHovered && isEnabled ? 0.10 : 0.0
    }
}
