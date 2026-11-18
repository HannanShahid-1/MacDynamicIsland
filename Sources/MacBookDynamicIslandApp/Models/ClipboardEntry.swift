import AppKit

enum ClipboardKind {
    case image
    case link
    case text
}

struct ClipboardEntry: Identifiable {
    let id: UUID
    let value: String
    let kind: ClipboardKind
    let image: NSImage?

    init(value: String, kind: ClipboardKind) {
        id = UUID()
        self.value = value
        self.kind = kind
        image = nil
    }

    init(image: NSImage) {
        id = UUID()
        value = Self.imageDisplayName(for: image)
        kind = .image
        self.image = image
    }

    private static func imageDisplayName(for image: NSImage) -> String {
        let representation = image.representations.max { first, second in
            first.pixelsWide * first.pixelsHigh < second.pixelsWide * second.pixelsHigh
        }
        let width = representation?.pixelsWide ?? Int(image.size.width.rounded())
        let height = representation?.pixelsHigh ?? Int(image.size.height.rounded())

        guard width > 0, height > 0 else { return "Image" }
        return "Image \(width)x\(height)"
    }
}

extension ClipboardEntry {
    var dockTitle: String {
        value
    }

    var kindLabel: String {
        switch kind {
        case .image:
            return "Image"
        case .link:
            return "Link"
        case .text:
            return "Text"
        }
    }
}
