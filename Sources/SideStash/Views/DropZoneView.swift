import AppKit

class DropZoneNSView: NSView {
    var store: StashStore?
    private(set) var isDraggingOver = false
    /// Pointer position in the lighting scene (top-left origin), or `nil` when
    /// it leaves. Tracked in AppKit so it works while the app is inactive and
    /// never competes with SwiftUI hover handlers.
    var onPointerMoved: ((CGPoint?) -> Void)?
    private var pointerTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = SideStashSidebarStyle.paneCornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        registerForDraggedTypes([.fileURL])
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyDropHighlight(animated: false)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        pointerTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onPointerMoved?(scenePoint(fromWindowPoint: event.locationInWindow))
    }

    override func mouseMoved(with event: NSEvent) {
        onPointerMoved?(scenePoint(fromWindowPoint: event.locationInWindow))
    }

    override func mouseExited(with event: NSEvent) {
        onPointerMoved?(nil)
    }

    /// Converts a window point to this view's top-left-origin coordinates,
    /// which match the SwiftUI lighting scene hosted inside it.
    func scenePoint(fromWindowPoint windowPoint: NSPoint) -> CGPoint {
        let local = convert(windowPoint, from: nil)
        return CGPoint(x: local.x, y: isFlipped ? local.y : bounds.height - local.y)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setDraggingOver(true)
        onPointerMoved?(scenePoint(fromWindowPoint: sender.draggingLocation))
        return .copy
    }

    /// The key light follows a file being dragged in, too.
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        onPointerMoved?(scenePoint(fromWindowPoint: sender.draggingLocation))
        return .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDraggingOver(false)
        onPointerMoved?(nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        urls?.forEach { store?.stash(url: $0) }
        setDraggingOver(false)
        return !(urls?.isEmpty ?? true)
    }

    func setDraggingOver(_ active: Bool) {
        isDraggingOver = active
        applyDropHighlight(animated: true)
    }

    /// Layer colors are plain CGColors, so they are resolved for the current
    /// appearance here and re-applied when the system switches Light/Dark.
    private func applyDropHighlight(animated: Bool) {
        let fillColor = isDraggingOver
            ? SideStashGlassPalette.dropTargetFill.cgColor(for: effectiveAppearance)
            : NSColor.clear.cgColor
        let borderColor = isDraggingOver
            ? SideStashGlassPalette.dropTargetStroke.cgColor(for: effectiveAppearance)
            : NSColor.clear.cgColor
        let borderWidth: CGFloat = isDraggingOver ? 1 : 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? InteractionMotionStyle.dropZoneHighlightDuration : 0
            context.allowsImplicitAnimation = animated
            self.layer?.backgroundColor = fillColor
            self.layer?.borderColor = borderColor
            self.layer?.borderWidth = borderWidth
        }
    }
}
