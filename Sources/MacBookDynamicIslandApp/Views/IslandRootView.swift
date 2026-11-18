import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IslandRootView: View {
    @ObservedObject var store: IslandStore
    let prepareForExpansion: () -> Void
    private static let collapseCompactRevealDelay: UInt64 = 320_000_000
    @State private var surfaceSize = IslandMetrics.playerCompactSize
    @State private var surfaceTopRadius: CGFloat = IslandMetrics.compactTopRadius
    @State private var surfaceBottomRadius: CGFloat = IslandMetrics.compactBottomRadius
    @State private var rendersExpandedContent = false
    @State private var showsCompactContent = true
    @State private var showsExpandedContent = false
    @State private var expansionStartTask: Task<Void, Never>?
    @State private var contentRevealTask: Task<Void, Never>?
    @State private var hoverCollapseTask: Task<Void, Never>?
    @State private var isPointerInsideIsland = false

    var body: some View {
        GeometryReader { proxy in
            islandSurface
                .position(
                    x: proxy.size.width / 2,
                    y: surfaceSize.height / 2
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .onChange(of: store.isExpanded) { isExpanded in
            handleExpansionChange(isExpanded)
        }
        .onChange(of: store.isDragTargeted) { isDragTargeted in
            handleDragTargetChange(isDragTargeted)
        }
        .onChange(of: store.airPodsBannerName) { _ in
            handleCompactBannerChange()
        }
        .onChange(of: store.chargingBannerID) { _ in
            handleCompactBannerChange()
        }
        .onChange(of: store.systemControlFeedback) { _ in
            handleCompactBannerChange()
        }
        .onChange(of: store.islandMode) { _ in
            handleModeChange()
        }
        .onChange(of: store.layoutMode) { _ in
            handleExpandedSizeChange()
        }
        .onChange(of: store.homeWidgets) { _ in
            handleExpandedSizeChange()
        }
        .onChange(of: store.expandedSizeOption) { _ in
            handleExpandedSizeChange()
        }
        .onChange(of: store.selectedNBAGameID) { _ in
            handleNBASelectionChange()
        }
        .onChange(of: store.isClipboardDetailHovered) { isHovered in
            handleClipboardDetailHoverChange(isHovered)
        }
        .onDisappear {
            expansionStartTask?.cancel()
            contentRevealTask?.cancel()
            hoverCollapseTask?.cancel()
        }
    }

    private var islandSurface: some View {
        ZStack(alignment: .top) {
            IslandBackdrop(
                topRadius: surfaceTopRadius,
                bottomRadius: surfaceBottomRadius,
                backgroundColor: surfaceBackgroundColor
            )

            compactNotchAnchor

            content
                .environment(\.islandTextColor, store.islandTextColor)
        }
        // Top-aligned: content is laid out at its final size from the start, so
        // while the surface is smaller than that it must overflow downwards and
        // sideways, never upwards past the top of the screen.
        .frame(width: surfaceSize.width, height: surfaceSize.height, alignment: .top)
        .clipShape(IslandSurfaceShape(topRadius: surfaceTopRadius, bottomRadius: surfaceBottomRadius))
        .contentShape(IslandSurfaceShape(topRadius: surfaceTopRadius, bottomRadius: surfaceBottomRadius))
        .contextMenu {
            if store.isExpanded {
                Button {
                    store.isOptionsPresented = true
                } label: {
                    Label("Options…", systemImage: "slider.horizontal.3")
                }
            }
        }
        .popover(isPresented: $store.isOptionsPresented, arrowEdge: .top) {
            IslandOptionsPopoverView(store: store)
                .interactiveDismissDisabled(true)
        }
        .onHover { isHovering in
            handleHoverChange(isHovering)
        }
        .onTapGesture {
            guard !store.isExpanded else { return }

            prepareForExpansion()
            beginExpansion()
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: Binding(
                get: { store.isDragTargeted },
                set: { store.isDragTargeted = $0 }
            ),
            perform: handleDrop
        )
    }

    private var compactNotchAnchor: some View {
        IslandSurfaceShape(
            topRadius: transientCompactTopRadius,
            bottomRadius: transientCompactBottomRadius
        )
        .fill(surfaceBackgroundColor)
        .frame(width: transientCompactSize.width, height: transientCompactSize.height)
        .allowsHitTesting(false)
    }

    private var surfaceBackgroundColor: Color {
        if store.isDragTargeted || store.islandMode == .workspace {
            return .black
        }

        return store.islandBackgroundColor
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .top) {
            CompactIslandView(store: store)
                .padding(contentInsets)
                .frame(
                    width: compactContentSize.width,
                    height: compactContentSize.height
                )
                .opacity(showsCompactContent ? 1 : 0)
                .allowsHitTesting(showsCompactContent && !rendersExpandedContent)
                .zIndex(store.isExpanded ? 0 : 2)

            if rendersExpandedContent {
                // Laid out once at the island's resting size rather than at whatever
                // size the surface has reached: the surface opens over finished
                // content like a window, and a bounce stretches the black shape
                // without dragging the content around with it.
                ExpandedIslandView(store: store)
                    .padding(expandedContentInsets)
                    .frame(
                        width: expandedSurfaceSize.width,
                        height: expandedSurfaceSize.height,
                        alignment: .top
                    )
                    .islandMaterialize(showsExpandedContent)
                    .allowsHitTesting(showsExpandedContent)
                    .zIndex(store.isExpanded ? 2 : 1)

                // Anchored to the island's centre line (the notch) rather than to the
                // mode's content, so it holds still while modes of different widths
                // and insets come and go.
                IslandModeSelector(store: store)
                    .offset(
                        x: -store.modeSelectorCenterOffset,
                        y: IslandMetrics.modeSelectorOrigin.y
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .islandMaterialize(showsExpandedContent, hiddenScale: 0.6, hiddenBlur: 0, anchor: .top)
                    // The switcher pops in a beat after the content, and leaves with it.
                    .animation(
                        showsExpandedContent ? IslandMotion.pop.delay(0.07) : IslandMotion.contentOut,
                        value: showsExpandedContent
                    )
                    .allowsHitTesting(showsExpandedContent)
                    .zIndex(store.isExpanded ? 3 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var contentInsets: EdgeInsets {
        if store.isExpanded {
            return expandedContentInsets
        }

        if store.isDragTargeted {
            return EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        }

        return compactContentInsets
    }

    private var compactContentSize: CGSize {
        transientCompactSize
    }

    private var transientCompactSize: CGSize {
        if store.isDragTargeted { return IslandMetrics.dragSize }
        if store.systemControlFeedback != nil { return IslandMetrics.systemControlSize }
        if store.chargingBannerID != nil { return IslandMetrics.chargingSize }
        if store.airPodsBannerName != nil { return IslandMetrics.airPodsSize }
        return IslandMetrics.playerCompactSize
    }

    private var transientCompactTopRadius: CGFloat {
        if store.isDragTargeted { return 0 }
        if store.systemControlFeedback != nil { return IslandMetrics.systemControlTopRadius }
        if store.chargingBannerID != nil { return IslandMetrics.chargingTopRadius }
        if store.airPodsBannerName != nil { return IslandMetrics.airPodsTopRadius }
        return IslandMetrics.compactTopRadius
    }

    private var transientCompactBottomRadius: CGFloat {
        if store.isDragTargeted { return 22 }
        if store.systemControlFeedback != nil { return IslandMetrics.systemControlBottomRadius }
        if store.chargingBannerID != nil { return IslandMetrics.chargingBottomRadius }
        if store.airPodsBannerName != nil { return IslandMetrics.airPodsBottomRadius }
        return IslandMetrics.compactBottomRadius
    }

    private var compactContentInsets: EdgeInsets {
        return EdgeInsets(top: 4, leading: 18, bottom: 3, trailing: 18)
    }

    private var expandedContentInsets: EdgeInsets {
        IslandMetrics.expandedContentInsets(for: store.islandMode)
    }

    private var expandedSurfaceSize: CGSize {
        store.expandedSize(for: store.islandMode)
    }

    private var hasCompactBanner: Bool {
        store.systemControlFeedback != nil
            || store.chargingBannerID != nil
            || store.airPodsBannerName != nil
    }

    /// When the island opens on click, hovering makes it swell out from behind
    /// the notch to show it is there and listening.
    private var isPeeking: Bool {
        isPointerInsideIsland
            && !store.autoExpandOnHover
            && !store.isExpanded
            && !store.isDragTargeted
            && !hasCompactBanner
    }

    /// Sets the surface to where it rests in the current state. Wrap in
    /// `withAnimation` to choose how it gets there.
    private func applyRestingSurface() {
        if store.isExpanded {
            surfaceSize = expandedSurfaceSize
            surfaceTopRadius = 0
            surfaceBottomRadius = IslandMetrics.expandedBottomRadius
            return
        }

        let peek = isPeeking
        let growth = peek ? IslandMetrics.hoverPeekGrowth : .zero
        surfaceSize = CGSize(
            width: transientCompactSize.width + growth.width,
            height: transientCompactSize.height + growth.height
        )
        surfaceTopRadius = transientCompactTopRadius
        surfaceBottomRadius = transientCompactBottomRadius
            + (peek ? IslandMetrics.hoverPeekBottomRadiusGrowth : 0)
    }

    private func handleExpansionChange(_ isExpanded: Bool) {
        contentRevealTask?.cancel()
        store.pauseAmbientRefreshes(for: IslandMotion.quietTime)

        if isExpanded {
            rendersExpandedContent = false
            showsExpandedContent = false

            withAnimation(IslandMotion.contentOut) {
                showsCompactContent = false
            }

            withAnimation(IslandMotion.open) {
                applyRestingSurface()
            }

            // The surface gets a head start: content is built a few frames in,
            // then swells into place while the shape is still growing around it.
            contentRevealTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 55_000_000)
                guard !Task.isCancelled, store.isExpanded else { return }

                rendersExpandedContent = true

                try? await Task.sleep(nanoseconds: 16_000_000)
                guard !Task.isCancelled, store.isExpanded else { return }

                withAnimation(IslandMotion.contentIn) {
                    showsExpandedContent = true
                }
            }
        } else {
            expansionStartTask?.cancel()

            showsCompactContent = false

            withAnimation(IslandMotion.contentOut) {
                showsExpandedContent = false
            }

            withAnimation(IslandMotion.close) {
                applyRestingSurface()
            }

            contentRevealTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.collapseCompactRevealDelay)
                guard !Task.isCancelled, !store.isExpanded else { return }

                rendersExpandedContent = false
                withAnimation(IslandMotion.contentOut) {
                    showsCompactContent = true
                }
            }
        }
    }

    private func beginExpansion() {
        expansionStartTask?.cancel()
        contentRevealTask?.cancel()
        hoverCollapseTask?.cancel()
        store.pauseAmbientRefreshes(for: IslandMotion.quietTime)
        rendersExpandedContent = false
        showsCompactContent = true
        showsExpandedContent = false
        // The surface is left where it is. If it is still on its way back into the
        // notch, the opening spring picks it up mid-flight instead of snapping it shut.

        expansionStartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, !store.isExpanded else { return }

            store.isExpanded = true
        }
    }

    private func handleHoverChange(_ isHovering: Bool) {
        isPointerInsideIsland = isHovering

        guard store.autoExpandOnHover else {
            hoverCollapseTask?.cancel()

            if !store.isExpanded, !store.isDragTargeted {
                withAnimation(IslandMotion.hover) {
                    applyRestingSurface()
                }
            }
            return
        }

        if isHovering {
            hoverCollapseTask?.cancel()

            guard !store.isExpanded,
                  !store.isDragTargeted,
                  !hasCompactBanner else {
                return
            }

            prepareForExpansion()
            beginExpansion()
            return
        }

        guard store.isExpanded else { return }
        scheduleHoverCollapse(after: 220_000_000)
    }

    private func handleClipboardDetailHoverChange(_ isHovered: Bool) {
        guard store.autoExpandOnHover,
              store.isExpanded,
              !isPointerInsideIsland else {
            return
        }

        hoverCollapseTask?.cancel()
        if !isHovered {
            scheduleHoverCollapse(after: 90_000_000)
        }
    }

    private func scheduleHoverCollapse(after delay: UInt64) {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, shouldCollapseAfterHoverExit else { return }

            if store.inspectedClipboardEntry != nil {
                store.closeClipboardDetail()
                try? await Task.sleep(nanoseconds: 360_000_000)
                guard !Task.isCancelled, shouldCollapseAfterHoverExit else { return }
            } else if store.isClipboardDetailDismissing {
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled, shouldCollapseAfterHoverExit else { return }
            }

            store.pauseAmbientRefreshes(for: 0.48)
            store.isExpanded = false
        }
    }

    private var shouldCollapseAfterHoverExit: Bool {
        store.autoExpandOnHover
            && store.isExpanded
            && !store.isOptionsPresented
            && !isPointerInsideIsland
            && !store.isClipboardDetailHovered
    }

    private func handleDragTargetChange(_ isDragTargeted: Bool) {
        guard !store.isExpanded else { return }

        store.pauseAmbientRefreshes(for: IslandMotion.quietTime)
        withAnimation(isDragTargeted ? IslandMotion.open : IslandMotion.close) {
            applyRestingSurface()
        }
    }

    private func handleModeChange() {
        morphSurface()
    }

    private func handleExpandedSizeChange() {
        guard store.isExpanded else { return }
        morphSurface()
    }

    private func handleNBASelectionChange() {
        guard store.isExpanded, store.islandMode == .nba else { return }
        morphSurface()
    }

    private func handleCompactBannerChange() {
        guard !store.isExpanded else { return }
        morphSurface()
    }

    /// Springs the surface from one resting shape to another.
    private func morphSurface() {
        store.pauseAmbientRefreshes(for: IslandMotion.quietTime)
        withAnimation(IslandMotion.morph) {
            applyRestingSurface()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = Self.fileURL(from: item) else { return }

                Task { @MainActor in
                    store.addFile(url)
                    withAnimation(IslandMotion.select) {
                        store.showWorkspaceMode()
                    }

                    if store.isExpanded {
                        return
                    }

                    prepareForExpansion()
                    beginExpansion()
                }
            }
        }

        return accepted
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL, url.isFileURL {
            return url
        }

        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil),
           url.isFileURL {
            return url
        }

        if let string = item as? String {
            if let url = URL(string: string), url.isFileURL {
                return url
            }

            let fileURL = URL(fileURLWithPath: string)
            return fileURL.isFileURL ? fileURL : nil
        }

        return nil
    }
}
