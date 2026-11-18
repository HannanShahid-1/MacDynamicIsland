import AppKit
import UniformTypeIdentifiers

extension IslandStore {
    func startClipboardWatcher() {
        clipboardTimer?.invalidate()

        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboardFromTimer()
            }
        }
        timer.tolerance = 0.25

        clipboardTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func addFile(_ url: URL) {
        guard url.isFileURL else { return }

        files.removeAll { $0.url == url }
        files.insert(ShelfFile(url: url), at: 0)
        keepFiveFiles()
    }

    func removeFile(_ file: ShelfFile) {
        files.removeAll { $0.id == file.id }
    }

    func revealFile(_ file: ShelfFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func clearClipboardHistory() {
        closeClipboardDetail()
        clipboardEntries.removeAll()
    }

    func inspectClipboardEntry(_ entry: ClipboardEntry) {
        pauseAmbientRefreshes(for: 0.28)
        clipboardDetailDismissalGuardUntil = Date.distantPast
        isClipboardDetailHovered = false
        shouldConsumeNextOutsideCollapse = false
        inspectedClipboardEntry = entry
    }

    func closeClipboardDetail() {
        guardNextClipboardDetailDismissal()
        suppressNextClipboardDetailDismissal = true
        inspectedClipboardEntry = nil
    }

    func setClipboardDetailFromPopover(_ entry: ClipboardEntry?) {
        if entry == nil {
            pauseAmbientRefreshes(for: 0.32)
            isClipboardDetailHovered = false
        }

        inspectedClipboardEntry = entry
    }

    func setClipboardDetailHovered(_ isHovered: Bool) {
        isClipboardDetailHovered = isHovered && inspectedClipboardEntry != nil
    }

    func consumeOutsideClickForClipboardDetailIfNeeded() -> Bool {
        if inspectedClipboardEntry != nil {
            closeClipboardDetail()
            return true
        }

        if shouldConsumeNextOutsideCollapse {
            shouldConsumeNextOutsideCollapse = false
            return true
        }

        if Date() < clipboardDetailDismissalGuardUntil {
            return true
        }

        return false
    }

    var isClipboardDetailDismissing: Bool {
        Date() < clipboardDetailDismissalGuardUntil
    }

    func copyClipboardEntry(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general

        switch entry.kind {
        case .image:
            guard let image = entry.image else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        case .link, .text:
            pasteboard.clearContents()
            pasteboard.setString(entry.value, forType: .string)
        }

        lastPasteboardChangeCount = pasteboard.changeCount
    }

    func handleClipboardPauseChange() {
        guard !isClipboardPaused else { return }
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
    }

    func handleClipboardDetailChange(from oldValue: ClipboardEntry?, to newValue: ClipboardEntry?) {
        guard oldValue != nil, newValue == nil else {
            suppressNextClipboardDetailDismissal = false
            return
        }

        isClipboardDetailHovered = false
        guardNextClipboardDetailDismissal()

        if suppressNextClipboardDetailDismissal {
            suppressNextClipboardDetailDismissal = false
        } else {
            shouldConsumeNextOutsideCollapse = true
        }
    }

    private func guardNextClipboardDetailDismissal() {
        clipboardDetailDismissalGuardUntil = max(
            clipboardDetailDismissalGuardUntil,
            Date().addingTimeInterval(0.45)
        )
    }

    private func pollClipboard() {
        guard !isClipboardPaused else { return }

        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastPasteboardChangeCount else { return }

        lastPasteboardChangeCount = changeCount

        if pasteboard.types?.contains(where: { concealedPasteboardTypes.contains($0) }) == true {
            return
        }

        if let image = Self.clipboardImage(from: pasteboard) {
            addClipboardImage(image)
            return
        }

        if let string = pasteboard.string(forType: .string) {
            addClipboardString(string)
        }
    }

    private func pollClipboardFromTimer() {
        guard !ambientRefreshesArePaused else { return }
        pollClipboard()
    }

    private func addClipboardString(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        let kind = Self.clipboardKind(for: value)
        let entry = ClipboardEntry(value: value, kind: kind)

        clipboardEntries.removeAll { $0.value == value }
        clipboardEntries.insert(entry, at: 0)
        keepFiveClipboardEntries()
    }

    private func addClipboardImage(_ image: NSImage) {
        clipboardEntries.insert(ClipboardEntry(image: image), at: 0)
        keepFiveClipboardEntries()
    }

    private func keepFiveFiles() {
        if files.count > 5 {
            files = Array(files.prefix(5))
        }
    }

    private func keepFiveClipboardEntries() {
        if clipboardEntries.count > 5 {
            clipboardEntries = Array(clipboardEntries.prefix(5))
        }
    }

    private static func clipboardKind(for value: String) -> ClipboardKind {
        if let url = URL(string: value),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "file"].contains(scheme),
           url.host != nil || scheme == "file" {
            return .link
        }

        return .text
    }

    private static func clipboardImage(from pasteboard: NSPasteboard) -> NSImage? {
        guard pasteboard.canReadItem(withDataConformingToTypes: [UTType.image.identifier]),
              let image = NSImage(pasteboard: pasteboard),
              image.isValid else {
            return nil
        }

        return image.copy() as? NSImage ?? image
    }
}
