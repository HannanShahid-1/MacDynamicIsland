import AppKit

/// Looks up the display name and icon of the app that is playing media.
@MainActor
enum NowPlayingSourceCatalog {
    private static var names: [String: String] = [:]
    private static var icons: [String: NSImage] = [:]

    /// Apps whose tracks are worth looking up in the music catalog when they
    /// supply no artwork. Anything else (a browser video, a podcast, a movie)
    /// would just get an unrelated album cover.
    private static let musicAppBundleIDs: Set<String> = ["com.apple.Music", "com.spotify.client"]

    static func isMusicApp(bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return musicAppBundleIDs.contains(bundleID)
    }

    static func name(forBundleID bundleID: String?, reportedName: String?) -> String? {
        guard let bundleID else { return reportedName }

        if let name = names[bundleID] {
            return name
        }

        let resolved = applicationURL(forBundleID: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path) }
            .map { $0.hasSuffix(".app") ? String($0.dropLast(4)) : $0 }

        guard let name = resolved ?? reportedName else { return nil }
        names[bundleID] = name
        return name
    }

    static func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }

        if let icon = icons[bundleID] {
            return icon
        }

        guard let url = applicationURL(forBundleID: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }

    private static func applicationURL(forBundleID bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}
