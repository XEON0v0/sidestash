import AppKit
import CoreGraphics
import Testing
@testable import SideStash

struct FinderWindowTrackerTests {
    @Test func visibilityPolicy_tracksOnlyActiveUnminimizedFinderWindows() {
        #expect(FinderWindowVisibilityPolicy.shouldExposeFinderWindow(isFinderActive: true, isWindowMinimized: false))
        #expect(!FinderWindowVisibilityPolicy.shouldExposeFinderWindow(isFinderActive: false, isWindowMinimized: false))
        #expect(!FinderWindowVisibilityPolicy.shouldExposeFinderWindow(isFinderActive: true, isWindowMinimized: true))
    }

    @Test func appKitRect_convertsAccessibilityTopLeftCoordinatesIntoBottomLeftCoordinates() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let accessibilityRect = CGRect(x: 226, y: 159, width: 920, height: 543)

        let rect = FinderWindowTracker.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            onScreenFrame: screenFrame
        )

        #expect(rect == NSRect(x: 226, y: 254, width: 920, height: 543))
    }

    @Test func bestFinderWindowRect_prefersWindowContainingPointerAndIgnoresOtherOwners() {
        let finderPID: pid_t = 638
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let preferredPoint = NSPoint(x: 500, y: 320)
        let windows: [[String: Any]] = [
            [
                kCGWindowNumber as String: 101,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 20,
                    "Y": 40,
                    "Width": 160,
                    "Height": 180,
                ],
            ],
            [
                kCGWindowNumber as String: 202,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 226,
                    "Y": 159,
                    "Width": 920,
                    "Height": 543,
                ],
            ],
            [
                kCGWindowNumber as String: 303,
                kCGWindowOwnerPID as String: 999,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 226,
                    "Y": 159,
                    "Width": 920,
                    "Height": 543,
                ],
            ],
        ]

        let rect = FinderWindowTracker.bestFinderWindowRect(
            fromWindowInfo: windows,
            finderPID: finderPID,
            preferredPoint: preferredPoint,
            screenFrame: screenFrame
        )

        #expect(rect == NSRect(x: 226, y: 254, width: 920, height: 543))
    }

    @Test func bestFinderWindowSnapshot_prefersWindowMatchingAttachedFinderRect() {
        let finderPID: pid_t = 638
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let attachedFinderRect = NSRect(x: 226, y: 254, width: 920, height: 543)
        let windows: [[String: Any]] = [
            [
                kCGWindowNumber as String: 101,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 20,
                    "Y": 40,
                    "Width": 160,
                    "Height": 180,
                ],
            ],
            [
                kCGWindowNumber as String: 202,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 226,
                    "Y": 159,
                    "Width": 920,
                    "Height": 543,
                ],
            ],
        ]

        let snapshot = FinderWindowTracker.bestFinderWindowSnapshot(
            fromWindowInfo: windows,
            finderPID: finderPID,
            preferredRect: attachedFinderRect,
            preferredPoint: nil,
            preferredWindowID: nil,
            screenFrame: screenFrame
        )

        #expect(snapshot?.windowID == 202)
        #expect(snapshot?.rect == attachedFinderRect)
    }

    @Test func finderWindowSnapshot_returnsNilAfterTrackedFinderWindowDisappears() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let windows: [[String: Any]] = [
            [
                kCGWindowNumber as String: 101,
                kCGWindowOwnerPID as String: 638,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 20,
                    "Y": 40,
                    "Width": 160,
                    "Height": 180,
                ],
            ],
        ]

        let snapshot = FinderWindowTracker.finderWindowSnapshot(
            windowID: 202,
            fromWindowInfo: windows,
            screenFrame: screenFrame
        )

        #expect(snapshot == nil)
    }

    @Test func bestFinderWindowSnapshot_prefersExactWindowIDWhenStillPresent() {
        let finderPID: pid_t = 638
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let windows: [[String: Any]] = [
            [
                kCGWindowNumber as String: 101,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 20,
                    "Y": 40,
                    "Width": 160,
                    "Height": 180,
                ],
            ],
            [
                kCGWindowNumber as String: 202,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 226,
                    "Y": 159,
                    "Width": 920,
                    "Height": 543,
                ],
            ],
        ]

        let snapshot = FinderWindowTracker.bestFinderWindowSnapshot(
            fromWindowInfo: windows,
            finderPID: finderPID,
            preferredRect: NSRect(x: 20, y: 736, width: 160, height: 180),
            preferredPoint: NSPoint(x: 500, y: 320),
            preferredWindowID: 202,
            screenFrame: screenFrame
        )

        #expect(snapshot?.windowID == 202)
        #expect(snapshot?.rect == NSRect(x: 226, y: 254, width: 920, height: 543))
    }

    @Test func bestFinderWindowSnapshot_fallsBackToClosestRectWhenPreferredWindowIDMissing() {
        let finderPID: pid_t = 638
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let attachedFinderRect = NSRect(x: 226, y: 254, width: 920, height: 543)
        let windows: [[String: Any]] = [
            [
                kCGWindowNumber as String: 101,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 226,
                    "Y": 159,
                    "Width": 920,
                    "Height": 543,
                ],
            ],
        ]

        let snapshot = FinderWindowTracker.bestFinderWindowSnapshot(
            fromWindowInfo: windows,
            finderPID: finderPID,
            preferredRect: attachedFinderRect,
            preferredPoint: nil,
            preferredWindowID: 202,
            screenFrame: screenFrame
        )

        #expect(snapshot?.windowID == 101)
        #expect(snapshot?.rect == attachedFinderRect)
    }

    @Test func accessibilitySnapshot_backfillsVisibleFinderWindowIDFromClosestRect() {
        let finderPID: pid_t = 638
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let accessibilityRect = CGRect(x: 226, y: 159, width: 920, height: 543)
        let windows: [[String: Any]] = [
            [
                kCGWindowNumber as String: 101,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 20,
                    "Y": 40,
                    "Width": 160,
                    "Height": 180,
                ],
            ],
            [
                kCGWindowNumber as String: 202,
                kCGWindowOwnerPID as String: finderPID,
                kCGWindowLayer as String: 0,
                kCGWindowBounds as String: [
                    "X": 226,
                    "Y": 159,
                    "Width": 920,
                    "Height": 543,
                ],
            ],
        ]

        let snapshot = FinderWindowTracker.accessibilitySnapshot(
            fromAccessibilityRect: accessibilityRect,
            fromWindowInfo: windows,
            finderPID: finderPID,
            screenFrame: screenFrame
        )

        #expect(snapshot?.windowID == 202)
        #expect(snapshot?.rect == NSRect(x: 226, y: 254, width: 920, height: 543))
    }
}
