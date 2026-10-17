import AppKit

enum PanelEdge: Equatable {
    case left
    case right
}

struct PanelScreenGeometry: Equatable {
    let frame: NSRect
    let visibleFrame: NSRect
}

extension PanelScreenGeometry {
    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }
}

struct PanelPlacement: Equatable {
    let isFinderAttached: Bool
    let edge: PanelEdge
    let targetRect: NSRect
    let previewRect: NSRect
    let hiddenRect: NSRect

    static func attachedToFinder(
        finderRect: NSRect,
        panelSize: NSSize,
        visibleFrame: NSRect,
        offset: CGFloat,
        revealInset: CGFloat,
        previewInset: CGFloat
    ) -> PanelPlacement {
        let preferredRightX = finderRect.maxX
        let canFitOnRight = preferredRightX + panelSize.width <= visibleFrame.maxX

        let edge: PanelEdge = canFitOnRight ? .right : .left
        let targetX = canFitOnRight
            ? preferredRightX
            : max(visibleFrame.minX, finderRect.minX - panelSize.width)
        let targetHeight = min(finderRect.height, visibleFrame.height)
        let targetY = clampY(
            finderRect.minY,
            panelHeight: targetHeight,
            visibleFrame: visibleFrame
        )

        let hiddenX = attachedX(
            targetX: targetX,
            panelWidth: panelSize.width,
            inset: revealInset,
            edge: edge
        )
        let previewX = attachedX(
            targetX: targetX,
            panelWidth: panelSize.width,
            inset: previewInset,
            edge: edge
        )

        let targetRect = NSRect(x: targetX, y: targetY, width: panelSize.width, height: targetHeight)
        let hiddenRect = NSRect(x: hiddenX, y: targetY, width: panelSize.width, height: targetHeight)
        let previewRect = NSRect(x: previewX, y: targetY, width: panelSize.width, height: targetHeight)
        return PanelPlacement(
            isFinderAttached: true,
            edge: edge,
            targetRect: targetRect,
            previewRect: previewRect,
            hiddenRect: hiddenRect
        )
    }

    static func nearMouse(
        point: NSPoint,
        panelSize: NSSize,
        visibleFrame: NSRect,
        offset: CGFloat,
        hiddenTravel: CGFloat
    ) -> PanelPlacement {
        var edge: PanelEdge = .right
        var targetX = point.x + offset

        if targetX + panelSize.width > visibleFrame.maxX {
            edge = .left
            targetX = point.x - panelSize.width - offset
        }

        targetX = min(max(targetX, visibleFrame.minX), visibleFrame.maxX - panelSize.width)

        var targetY = point.y - panelSize.height - offset
        if targetY < visibleFrame.minY {
            targetY = point.y + offset
        }

        targetY = clampY(targetY, panelHeight: panelSize.height, visibleFrame: visibleFrame)

        let hiddenX = edge == .right ? targetX - hiddenTravel : targetX + hiddenTravel
        let targetRect = NSRect(x: targetX, y: targetY, width: panelSize.width, height: panelSize.height)
        let hiddenRect = NSRect(x: hiddenX, y: targetY, width: panelSize.width, height: panelSize.height)
        return PanelPlacement(
            isFinderAttached: false,
            edge: edge,
            targetRect: targetRect,
            previewRect: targetRect,
            hiddenRect: hiddenRect
        )
    }

    /// Places the panel below the status item button. When the button rect is missing or lies
    /// outside every screen (e.g. the item was moved into the menu bar overflow area), the panel
    /// falls back to the top-right corner of `fallbackVisibleFrame`, just below the menu bar.
    static func belowStatusItem(
        buttonRect: NSRect?,
        panelSize: NSSize,
        screens: [PanelScreenGeometry],
        fallbackVisibleFrame: NSRect,
        gap: CGFloat,
        hiddenLift: CGFloat
    ) -> PanelPlacement {
        let proposedRect: NSRect
        let visibleFrame: NSRect

        if let buttonRect, let screen = screenHostingStatusItem(buttonRect, in: screens) {
            visibleFrame = screen.visibleFrame
            proposedRect = NSRect(
                x: buttonRect.midX - (panelSize.width / 2),
                y: buttonRect.minY - panelSize.height - gap,
                width: panelSize.width,
                height: panelSize.height
            )
        } else {
            visibleFrame = fallbackVisibleFrame
            proposedRect = NSRect(
                x: fallbackVisibleFrame.maxX - panelSize.width - gap,
                y: fallbackVisibleFrame.maxY - panelSize.height - gap,
                width: panelSize.width,
                height: panelSize.height
            )
        }

        let targetRect = NSRect(
            x: clampX(proposedRect.minX, panelWidth: panelSize.width, visibleFrame: visibleFrame),
            y: clampY(proposedRect.minY, panelHeight: panelSize.height, visibleFrame: visibleFrame),
            width: panelSize.width,
            height: panelSize.height
        )
        let hiddenRect = targetRect.offsetBy(dx: 0, dy: hiddenLift)
        return PanelPlacement(
            isFinderAttached: false,
            edge: .right,
            targetRect: targetRect,
            previewRect: targetRect,
            hiddenRect: hiddenRect
        )
    }

    /// The status item lives in the menu bar, which sits outside `visibleFrame`, so the button is
    /// matched against each screen's full frame.
    private static func screenHostingStatusItem(_ buttonRect: NSRect, in screens: [PanelScreenGeometry]) -> PanelScreenGeometry? {
        let center = NSPoint(x: buttonRect.midX, y: buttonRect.midY)
        return screens.first(where: { NSPointInRect(center, $0.frame) })
    }

    private static func clampX(_ proposedX: CGFloat, panelWidth: CGFloat, visibleFrame: NSRect) -> CGFloat {
        min(max(proposedX, visibleFrame.minX), visibleFrame.maxX - panelWidth)
    }

    private static func clampY(_ proposedY: CGFloat, panelHeight: CGFloat, visibleFrame: NSRect) -> CGFloat {
        min(max(proposedY, visibleFrame.minY), visibleFrame.maxY - panelHeight)
    }

    private static func attachedX(targetX: CGFloat, panelWidth: CGFloat, inset: CGFloat, edge: PanelEdge) -> CGFloat {
        switch edge {
        case .right:
            return targetX - (panelWidth - inset)
        case .left:
            return targetX + (panelWidth - inset)
        }
    }
}
