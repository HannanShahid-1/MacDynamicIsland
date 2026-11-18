import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private var islandController: IslandWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBarItem()

        let controller = IslandWindowController(store: store)
        islandController = controller
        controller.show()

        store.startClipboardWatcher()
        store.startNowPlayingWatcher()
        store.startAirPodsWatcher()
        store.startSystemControlWatcher()
        store.startPowerWatcher()
        store.startWeatherWatcher()
        store.startNBAScoresWatcher()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.shutdown()
    }

    private func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "capsule",
                accessibilityDescription: "MacBook Dynamic Island"
            )
            button.toolTip = "MacBook Dynamic Island"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
