import AppKit
import UniformTypeIdentifiers

struct ShelfFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func makeDragItemProvider() -> NSItemProvider {
        let provider = NSItemProvider(object: url as NSURL)
        provider.suggestedName = displayName
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(url.absoluteString.data(using: .utf8), nil)
            return nil
        }
        return provider
    }
}
