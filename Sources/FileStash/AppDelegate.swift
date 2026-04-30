import AppKit

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
        setupStatusItem()
        setupDragDetector()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DragDetector.shared.stopMonitoring()
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

        button.image = NSImage(systemSymbolName: "tray.and.arrow.up.fill", accessibilityDescription: "FileStash")
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusBarClick(_:))
        button.target = self
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            windowManager.togglePanel(near: sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "打开暂存文件夹", action: #selector(openStashFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

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

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
