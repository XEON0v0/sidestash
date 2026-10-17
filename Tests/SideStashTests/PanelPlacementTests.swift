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

    // MARK: - Status item

    private let primaryScreen = PanelScreenGeometry(
        frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: NSRect(x: 0, y: 70, width: 1440, height: 806)
    )
    private let secondaryScreen = PanelScreenGeometry(
        frame: NSRect(x: 1440, y: -180, width: 2560, height: 1440),
        visibleFrame: NSRect(x: 1440, y: -180, width: 2560, height: 1415)
    )

    @Test func belowStatusItem_buttonOnScreen_centersBelowButton() {
        let placement = PanelPlacement.belowStatusItem(
            buttonRect: NSRect(x: 1200, y: 876, width: 30, height: 24),
            panelSize: panelSize,
            screens: [primaryScreen],
            fallbackVisibleFrame: primaryScreen.visibleFrame,
            gap: 10,
            hiddenLift: 24
        )

        #expect(!placement.isFinderAttached)
        #expect(placement.targetRect == NSRect(x: 1055, y: 446, width: 320, height: 420))
        #expect(placement.previewRect == placement.targetRect)
        #expect(placement.hiddenRect == NSRect(x: 1055, y: 470, width: 320, height: 420))
    }

    @Test func belowStatusItem_buttonNearRightEdge_clampsToVisibleFrame() {
        let placement = PanelPlacement.belowStatusItem(
            buttonRect: NSRect(x: 1400, y: 876, width: 30, height: 24),
            panelSize: panelSize,
            screens: [primaryScreen],
            fallbackVisibleFrame: primaryScreen.visibleFrame,
            gap: 10,
            hiddenLift: 24
        )

        #expect(placement.targetRect == NSRect(x: 1120, y: 446, width: 320, height: 420))
        #expect(primaryScreen.visibleFrame.contains(placement.targetRect))
    }

    @Test func belowStatusItem_buttonOffScreen_fallsBackToTopRightOfVisibleFrame() {
        // Status items pushed into the menu bar overflow area report rects far outside every screen.
        let placement = PanelPlacement.belowStatusItem(
            buttonRect: NSRect(x: -4136, y: 876, width: 30, height: 24),
            panelSize: panelSize,
            screens: [primaryScreen, secondaryScreen],
            fallbackVisibleFrame: primaryScreen.visibleFrame,
            gap: 10,
            hiddenLift: 24
        )

        #expect(!placement.isFinderAttached)
        #expect(placement.targetRect == NSRect(x: 1110, y: 446, width: 320, height: 420))
        #expect(primaryScreen.visibleFrame.contains(placement.targetRect))
        #expect(placement.hiddenRect == NSRect(x: 1110, y: 470, width: 320, height: 420))
    }

    @Test func belowStatusItem_missingButtonRect_fallsBackToTopRightOfVisibleFrame() {
        let placement = PanelPlacement.belowStatusItem(
            buttonRect: nil,
            panelSize: panelSize,
            screens: [primaryScreen],
            fallbackVisibleFrame: primaryScreen.visibleFrame,
            gap: 10,
            hiddenLift: 24
        )

        #expect(placement.targetRect == NSRect(x: 1110, y: 446, width: 320, height: 420))
    }

    @Test func belowStatusItem_buttonOnSecondaryScreen_staysWithinThatScreen() {
        // Centering under a button at the secondary screen's left edge would straddle both screens.
        let placement = PanelPlacement.belowStatusItem(
            buttonRect: NSRect(x: 1450, y: 1235, width: 30, height: 25),
            panelSize: panelSize,
            screens: [primaryScreen, secondaryScreen],
            fallbackVisibleFrame: primaryScreen.visibleFrame,
            gap: 10,
            hiddenLift: 24
        )

        #expect(placement.targetRect == NSRect(x: 1440, y: 805, width: 320, height: 420))
        #expect(secondaryScreen.visibleFrame.contains(placement.targetRect))
    }
}
