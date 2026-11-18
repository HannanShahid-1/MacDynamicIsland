import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileShelfGallery: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Files")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text("\(store.files.count) of 5")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(height: 30)
            .padding(.top, 12)
            .padding(.leading, -8)
            .padding(.trailing, 12)

            if store.files.isEmpty {
                DropFilePlaceholder(isLarge: store.expandedSizeOption == .large)
                    .padding(.leading, -8)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: store.expandedSizeOption == .large ? 12 : 10) {
                        ForEach(store.files) { file in
                            FilePreviewTile(
                                file: file,
                                isLarge: store.expandedSizeOption == .large,
                                reveal: { store.revealFile(file) },
                                remove: { store.removeFile(file) }
                            )
                            .transition(.islandPop(scale: 0.7))
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
                    .animation(IslandMotion.rearrange, value: store.files.map(\.id))
                }
            }
        }
    }
}

struct DropFilePlaceholder: View {
    let isLarge: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack(alignment: .leading) {
            RadialGradient(
                colors: [
                    islandTextColor.opacity(0.065),
                    islandTextColor.opacity(0.020),
                    .clear
                ],
                center: .leading,
                startRadius: 8,
                endRadius: isLarge ? 260 : 210
            )

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(islandTextColor.opacity(0.075))
                        .frame(width: isLarge ? 48 : 42, height: isLarge ? 48 : 42)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: isLarge ? 24 : 21, weight: .semibold))
                        .foregroundStyle(islandTextColor.opacity(0.82))
                }
                .frame(width: isLarge ? 68 : 56, height: isLarge ? 96 : 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Drop anywhere")
                        .font(.system(size: isLarge ? 16 : 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)

                    Text("Files blend into this shelf")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.40))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: isLarge ? 20 : 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: isLarge ? 20 : 18, style: .continuous))
    }
}

struct FilePreviewTile: View {
    let file: ShelfFile
    let isLarge: Bool
    let reveal: () -> Void
    let remove: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 8.0)) { _ in
            let existsOnDisk = file.existsOnDisk

            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    FilePreviewVisual(
                        file: file,
                        size: previewSize,
                        existsOnDisk: existsOnDisk
                    )

                    HStack(spacing: 2) {
                        IconButton(systemName: "magnifyingglass", title: "Reveal in Finder", action: reveal)
                            .disabled(!existsOnDisk)
                        IconButton(systemName: "xmark", title: "Remove", action: remove)
                    }
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.58))
                    )
                    .padding(4)
                    .opacity(isHovered ? 1 : 0)
                    .scaleEffect(isHovered ? 1 : 0.7, anchor: .topTrailing)
                }

                Text(file.displayName)
                    .font(.system(size: isLarge ? 10 : 9.5, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.middle)
                    .frame(width: tileWidth, height: isLarge ? 28 : 26, alignment: .top)
                    .foregroundStyle(islandTextColor.opacity(existsOnDisk ? 0.82 : 0.42))
            }
            .frame(width: tileWidth)
            .modifier(FileDragOutModifier(file: file, isEnabled: existsOnDisk))
            .opacity(existsOnDisk ? 1 : 0.58)
            .help(existsOnDisk ? "Drag out as a file" : "Missing")
            .onHover { hovering in
                withAnimation(IslandMotion.hover) {
                    isHovered = hovering
                }
            }
        }
    }

    private var tileWidth: CGFloat {
        isLarge ? 92 : 80
    }

    private var previewSize: CGSize {
        isLarge ? CGSize(width: 82, height: 96) : CGSize(width: 66, height: 74)
    }
}

struct FilePreviewVisual: View {
    let file: ShelfFile
    let size: CGSize
    let existsOnDisk: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(islandTextColor.opacity(0.040))

            if existsOnDisk, let image = FileVisualCache.preview(for: file.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Image(nsImage: FileVisualCache.icon(for: file.url, size: iconSize))
                    .resizable()
                    .scaledToFit()
                    .padding(9)
                    .opacity(existsOnDisk ? 1 : 0.55)
            }

            if !existsOnDisk {
                Text("Missing")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.72))
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(islandTextColor.opacity(0.08), lineWidth: 1)
        )
    }

    private var iconSize: CGSize {
        CGSize(width: size.width * 0.66, height: size.height * 0.66)
    }
}

@MainActor
enum FileVisualCache {
    private static var imagePreviews: [String: NSImage] = [:]
    private static var icons: [String: NSImage] = [:]

    static func preview(for url: URL) -> NSImage? {
        let key = url.path
        if let image = imagePreviews[key] {
            return image
        }

        guard let type = UTType(filenameExtension: url.pathExtension),
              type.conforms(to: .image),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        imagePreviews[key] = image
        return image
    }

    static func icon(for url: URL, size: CGSize) -> NSImage {
        let key = "\(url.path)#\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        if let icon = icons[key] {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = size
        icons[key] = icon
        return icon
    }
}

struct FileDragOutModifier: ViewModifier {
    let file: ShelfFile
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .onDrag {
                    file.makeDragItemProvider()
                }
        } else {
            content
        }
    }
}
