import AppKit

enum StatusBarClickPolicy {
    static func shouldShowContextMenu(for event: NSEvent?) -> Bool {
        event?.type == .rightMouseUp
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StashStore()
    private let windowManager: StashWindowManager
    private var statusItem: NSStatusItem?

    override init() {
        windowManager = StashWindowManager(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Compile the glass bevel shader before the panel first shows.
        GlassBevelRenderer.shared.prepare()
        setupStatusItem()
        setupDragDetector()
        FinderWindowTracker.shared.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DragDetector.shared.stopMonitoring()
        FinderWindowTracker.shared.stopMonitoring()
    }

    private func setupDragDetector() {
        DragDetector.shared.onDragDetected = { [weak self] location in
            self?.windowManager.showPanel(near: location)
        }
        DragDetector.shared.startMonitoring()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "tray.and.arrow.up.fill", accessibilityDescription: "SideStash")
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusBarClick(_:))
        button.target = self
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        if StatusBarClickPolicy.shouldShowContextMenu(for: NSApp.currentEvent) {
            showContextMenu()
        } else {
            windowManager.togglePanel(near: sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.show_hide", comment: "Toggle panel"), action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.open_stash", comment: "Open stash folder in Finder"), action: #selector(openStashFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let trackerItem = NSMenuItem(
            title: NSLocalizedString("menu.enable_finder_integration", comment: "Enable Finder window integration"),
            action: #selector(promptAccessibilityPermission),
            keyEquivalent: ""
        )
        trackerItem.target = self
        let granted = FinderWindowTracker.shared.isAccessibilityGranted
        trackerItem.state = granted ? .on : .off
        trackerItem.attributedTitle = NSAttributedString(
            string: trackerItem.title,
            attributes: granted ? [:] : [.foregroundColor: NSColor.secondaryLabelColor]
        )
        menu.addItem(trackerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.quit", comment: "Quit the application"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func togglePanel() {
        windowManager.togglePanel(near: statusItem?.button)
    }

    @objc private func openStashFolder() {
        NSWorkspace.shared.open(store.stashDirectory)
    }

    @objc private func promptAccessibilityPermission() {
        FinderWindowTracker.shared.promptAccessibility()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
