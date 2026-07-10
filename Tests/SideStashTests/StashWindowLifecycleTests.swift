import AppKit
import Testing
@testable import SideStash

struct StashWindowLifecycleTests {
    @Test @MainActor
    func hoverTrackingAcceptsMouseMovementWithoutActivatingPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        AttachedPanelInteractionPolicy.enableHoverTracking(on: panel)

        #expect(panel.acceptsMouseMovedEvents)
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }

    @Test func edgePreviewChrome_onlyShowsDuringAttachedRevealAnimation() {
        #expect(AttachedPanelChromePolicy.isEdgePreviewVisible(isFinderAttached: true, isRevealAnimating: true))
        #expect(!AttachedPanelChromePolicy.isEdgePreviewVisible(isFinderAttached: true, isRevealAnimating: false))
        #expect(!AttachedPanelChromePolicy.isEdgePreviewVisible(isFinderAttached: false, isRevealAnimating: true))
    }

    @Test func attachedPanelClosesWhenTrackedFinderWindowDisappears() {
        let decision = AttachedPanelLifecyclePolicy.decision(
            isFinderAttached: true,
            trackedSnapshot: FinderWindowSnapshot(windowID: 202, rect: NSRect(x: 226, y: 254, width: 920, height: 543)),
            latestSnapshot: nil
        )

        #expect(decision == .close)
    }

    @Test func attachedPanelIgnoresFinderLossWhileContentModalIsPresented() {
        let decision = AttachedPanelLifecyclePolicy.decision(
            isFinderAttached: true,
            trackedSnapshot: FinderWindowSnapshot(windowID: 202, rect: NSRect(x: 226, y: 254, width: 920, height: 543)),
            latestSnapshot: nil,
            isContentModalPresented: true
        )

        #expect(decision == .ignore)
    }

    @Test func attachedPanelStaysClosedToOtherFinderWindowWhenTrackedWindowChanges() {
        let decision = AttachedPanelLifecyclePolicy.decision(
            isFinderAttached: true,
            trackedSnapshot: FinderWindowSnapshot(windowID: 202, rect: NSRect(x: 226, y: 254, width: 920, height: 543)),
            latestSnapshot: FinderWindowSnapshot(windowID: 101, rect: NSRect(x: 20, y: 736, width: 160, height: 180))
        )

        #expect(decision == .close)
    }

    @Test func attachedPanelUpdatesPlacementWhenTrackedFinderWindowStillMatches() {
        let latest = FinderWindowSnapshot(windowID: 202, rect: NSRect(x: 240, y: 230, width: 880, height: 520))

        let decision = AttachedPanelLifecyclePolicy.decision(
            isFinderAttached: true,
            trackedSnapshot: FinderWindowSnapshot(windowID: 202, rect: NSRect(x: 226, y: 254, width: 920, height: 543)),
            latestSnapshot: latest
        )

        #expect(decision == .update(latest))
    }

    @Test func escapeRequestsClose() {
        #expect(AttachedPanelLifecyclePolicy.keyboardDecision(for: 53) == .close)
    }

    @Test func nonEscapeKeyDoesNothing() {
        #expect(AttachedPanelLifecyclePolicy.keyboardDecision(for: 49) == .ignore)
    }

    @Test func statusBarClickWithoutCurrentEventTogglesPanel() {
        #expect(!StatusBarClickPolicy.shouldShowContextMenu(for: nil))
        #expect(!StatusBarClickPolicy.shouldShowContextMenu(for: NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!))
    }

    @Test func statusBarRightClickShowsContextMenu() {
        #expect(StatusBarClickPolicy.shouldShowContextMenu(for: NSEvent.mouseEvent(
            with: .rightMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!))
    }

    @Test func manualCloseClearsTrackedSnapshot() {
        let state = AttachedPanelLifecyclePolicy.resetTrackingStateAfterManualClose(
            trackedSnapshot: FinderWindowSnapshot(windowID: 202, rect: NSRect(x: 226, y: 254, width: 920, height: 543))
        )

        #expect(state == nil)
    }
}
