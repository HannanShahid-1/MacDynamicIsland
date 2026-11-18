import SwiftUI

struct ClipboardDock: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: store.isClipboardPaused ? "pause.circle.fill" : "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 17)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Clipboard")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text(store.isClipboardPaused ? "Paused" : "\(store.clipboardEntries.count)/5 clips")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.44))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: $store.isClipboardPaused)
                    .labelsHidden()
                    .toggleStyle(GreenSwitchToggleStyle())
                    .fixedSize()
                    .scaleEffect(0.76)
                    .frame(width: 28, height: 18)
                    .help(store.isClipboardPaused ? "Resume clipboard watching" : "Pause clipboard watching")

                IconButton(systemName: "trash", title: "Clear clipboard history") {
                    store.clearClipboardHistory()
                }
                .disabled(store.clipboardEntries.isEmpty)
            }
            .frame(height: 28)

            if store.clipboardEntries.isEmpty {
                ClipboardEmptyDock(isPaused: store.isClipboardPaused)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(store.clipboardEntries) { entry in
                            ClipboardDockItem(
                                entry: entry,
                                copy: { store.copyClipboardEntry(entry) },
                                inspect: { store.inspectClipboardEntry(entry) }
                            )
                            .transition(.islandPop(scale: 0.85, anchor: .top))
                        }
                    }
                    .padding(.bottom, 1)
                    .animation(IslandMotion.rearrange, value: store.clipboardEntries.map(\.id))
                    // The dock switches animations off below so the detail popover
                    // closes without one. The rows themselves still animate.
                    .transaction { transaction in
                        transaction.disablesAnimations = false
                    }
                }
            }
        }
        .padding(.top, 28)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .popover(item: detailPopoverBinding, arrowEdge: .bottom) { entry in
            ClipboardDetailPopover(
                entry: entry,
                copy: { store.copyClipboardEntry(entry) },
                close: { store.closeClipboardDetail() },
                hoverChanged: { store.setClipboardDetailHovered($0) }
            )
        }
        .transaction { transaction in
            transaction.disablesAnimations = store.inspectedClipboardEntry == nil
        }
    }

    private var detailPopoverBinding: Binding<ClipboardEntry?> {
        Binding(
            get: { store.inspectedClipboardEntry },
            set: { entry in
                var transaction = Transaction()
                transaction.disablesAnimations = entry == nil

                withTransaction(transaction) {
                    store.setClipboardDetailFromPopover(entry)
                }
            }
        )
    }
}

struct ClipboardEmptyDock: View {
    let isPaused: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(islandTextColor.opacity(0.075))
                    .frame(width: 44, height: 44)

                Image(systemName: isPaused ? "pause.circle" : "doc.on.clipboard")
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            Text(isPaused ? "Paused" : "Clipboard ready")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .lineLimit(1)

            Text(isPaused ? "Watching is off" : "Copied items surface here")
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(islandTextColor.opacity(0.36))
                .lineLimit(1)
        }
        .foregroundStyle(islandTextColor.opacity(0.56))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(
                colors: [
                    islandTextColor.opacity(0.050),
                    islandTextColor.opacity(0.018),
                    .clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 92
            )
        )
    }
}

struct ClipboardDockItem: View {
    let entry: ClipboardEntry
    let copy: () -> Void
    let inspect: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            Button(action: inspect) {
                HStack(spacing: 8) {
                    ClipboardThumb(entry: entry)
                        .scaleEffect(isHovered ? 1.10 : 1)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.dockTitle)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(entry.kindLabel)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(islandTextColor.opacity(0.46))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IslandButtonPressStyle())
            .help(entry.kind == .image ? "Preview image" : "Show full copied text")

            IconButton(systemName: "doc.on.doc", title: "Copy back to clipboard", action: copy)
                .frame(width: 20)
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(islandTextColor.opacity(isHovered ? 0.085 : 0.042))
        )
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }
}

struct ClipboardThumb: View {
    let entry: ClipboardEntry
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(islandTextColor.opacity(0.10))

            switch entry.kind {
            case .image:
                if let image = entry.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 10, weight: .semibold))
                }
            case .link:
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(islandTextColor.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ClipboardDetailPopover: View {
    let entry: ClipboardEntry
    let copy: () -> Void
    let close: () -> Void
    let hoverChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: headerIconName)
                    .font(.system(size: 12, weight: .semibold))

                Text(headerTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Spacer(minLength: 8)

                IconButton(systemName: "doc.on.doc", title: "Copy back to clipboard", action: copy)
                IconButton(systemName: "xmark", title: "Close preview", action: close)
            }

            detailContent
        }
        .padding(12)
        .frame(width: 390)
        .foregroundStyle(.white)
        .background(Color.black.opacity(0.92))
        .onHover(perform: hoverChanged)
        .onDisappear {
            hoverChanged(false)
        }
    }

    private var headerIconName: String {
        switch entry.kind {
        case .image:
            return "photo"
        case .link:
            return "link"
        case .text:
            return "text.alignleft"
        }
    }

    private var headerTitle: String {
        switch entry.kind {
        case .image:
            return entry.value
        case .link:
            return "Copied Link"
        case .text:
            return "Copied Text"
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if entry.kind == .image, let image = entry.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 360, height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                Text(entry.value)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(width: 360, height: 190)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }
}
