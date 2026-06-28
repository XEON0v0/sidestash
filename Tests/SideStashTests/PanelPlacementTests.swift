import AppKit
import Testing
@testable import SideStash

struct PanelPlacementTests {
    private let panelSize = NSSize(width: 320, height: 420)
    private let visibleFrame = NSRect(x: 0, y: 80, width: 1440, height: 820)

    @Test func attachedToFinder_matchesFinderHeightAndSlidesFromRightEdge() {
        let finderRect = NSRect(x: 240, y: 220, width: 720, height: 540)

        let placement = PanelPlacement.attachedToFinder(
            finderRect: finderRect,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            offset: 20,
            revealInset: 12,
            previewInset: 28
        )

        #expect(placement.isFinderAttached)
        #expect(placement.edge == .right)
        #expect(placement.targetRect == NSRect(x: 960, y: 220, width: 320, height: 540))
        #expect(placement.hiddenRect == NSRect(x: 652, y: 220, width: 320, height: 540))
        #expect(placement.previewRect == NSRect(x: 668, y: 220, width: 320, height: 540))
    }

    @Test func attachedToFinder_flipsLeftAndStillMatchesFinderHeight() {
        let finderRect = NSRect(x: 1040, y: 180, width: 220, height: 420)

        let placement = PanelPlacement.attachedToFinder(
            finderRect: finderRect,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            offset: 20,
            revealInset: 12,
            previewInset: 28
        )

        #expect(placement.isFinderAttached)
        #expect(placement.edge == .left)
        #expect(placement.targetRect == NSRect(x: 720, y: 180, width: 320, height: 420))
        #expect(placement.hiddenRect == NSRect(x: 1028, y: 180, width: 320, height: 420))
        #expect(placement.previewRect == NSRect(x: 1012, y: 180, width: 320, height: 420))
    }

    @Test func nearMouse_clampsToVisibleFrameAndPreservesEntrySide() {
        let placement = PanelPlacement.nearMouse(
            point: NSPoint(x: 1410, y: 120),
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            offset: 20,
            hiddenTravel: 48
        )

        #expect(!placement.isFinderAttached)
        #expect(placement.edge == .left)
        #expect(placement.targetRect == NSRect(x: 1070, y: 140, width: 320, height: 420))
        #expect(placement.hiddenRect == NSRect(x: 1118, y: 140, width: 320, height: 420))
    }
}
