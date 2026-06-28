import AppKit

final class PanelEdgePreviewView: NSView {
    var edge: PanelEdge = .right {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
        postsFrameChangedNotifications = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let stripWidth = InteractionMotionStyle.attachedPeekInset
        let stripRect: CGRect
        switch edge {
        case .right:
            stripRect = CGRect(x: 0, y: 0, width: stripWidth, height: bounds.height)
        case .left:
            stripRect = CGRect(x: bounds.width - stripWidth, y: 0, width: stripWidth, height: bounds.height)
        }

        let context = NSGraphicsContext.current?.cgContext
        guard let context else { return }

        context.setFillColor(NSColor.white.withAlphaComponent(0.06).cgColor)
        context.fill(stripRect)

        context.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        let accentRect: CGRect
        switch edge {
        case .right:
            accentRect = CGRect(x: stripRect.minX, y: stripRect.minY, width: 1, height: stripRect.height)
        case .left:
            accentRect = CGRect(x: stripRect.maxX - 1, y: stripRect.minY, width: 1, height: stripRect.height)
        }
        context.fill(accentRect)
    }
}
