import AppKit
import SwiftUI

@MainActor
class StashWindowManager {
    static let shared = StashWindowManager(store: StashStore())
    private let store: StashStore
    private var panel: NSPanel?

    init(store: StashStore) {
        self.store = store
    }

    private enum Layout {
        static let panelWidth: CGFloat = 300
        static let panelHeight: CGFloat = 420
        static let panelOffset: CGFloat = 20
    }

    func showPanel(near statusItemButton: NSStatusBarButton?) {
        ensurePanelCreated()

        if let button = statusItemButton {
            let buttonRect = button.window?.convertToScreen(button.frame) ?? NSRect(x: 300, y: 300, width: 0, height: 0)
            let panelX = buttonRect.midX - Layout.panelWidth / 2
            let panelY = buttonRect.minY - Layout.panelHeight - 10
            panel?.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        } else {
            panel?.center()
        }

        panel?.makeKeyAndOrderFront(nil)
        store.refreshItems()
        DragDetector.shared.stopMonitoring()
    }

    func showPanel(near point: NSPoint) {
        ensurePanelCreated()

        let offset = Layout.panelOffset
        let panelSize = NSSize(width: Layout.panelWidth, height: Layout.panelHeight)
        var origin = NSPoint(x: point.x + offset, y: point.y - panelSize.height - offset)

        if let screen = NSScreen.screens.first(where: { NSPointInRect(point, $0.frame) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if origin.x + panelSize.width > visibleFrame.maxX {
                origin.x = point.x - panelSize.width - offset
            }
            if origin.x < visibleFrame.minX {
                origin.x = visibleFrame.minX
            }
            if origin.y < visibleFrame.minY {
                origin.y = point.y + offset
            }
            if origin.y + panelSize.height > visibleFrame.maxY {
                origin.y = visibleFrame.maxY - panelSize.height
            }
        }

        panel?.setFrameOrigin(origin)
        panel?.makeKeyAndOrderFront(nil)
        store.refreshItems()
        DragDetector.shared.stopMonitoring()
    }

    private func ensurePanelCreated() {
        guard panel == nil else { return }

        let contentView = StashContentView(
            onClose: { [weak self] in
                self?.hidePanel()
            }
        )
            .environmentObject(store)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.hasShadow = true
        panel.backgroundColor = .clear

        let dropZone = DropZoneNSView()
        dropZone.store = store
        dropZone.frame = panel.frame
        dropZone.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = dropZone.bounds
        hostingView.autoresizingMask = [.width, .height]

        dropZone.addSubview(hostingView)
        panel.contentView = dropZone

        self.panel = panel
    }

    var panelOrigin: NSPoint? {
        panel?.frame.origin
    }

    func setPanelOrigin(_ origin: NSPoint) {
        panel?.setFrameOrigin(origin)
    }

    func hidePanel() {
        panel?.orderOut(nil)
        DragDetector.shared.startMonitoring()
    }

    func togglePanel(near statusItemButton: NSStatusBarButton?) {
        if let panel = panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel(near: statusItemButton)
            store.refreshItems()
        }
    }
}
