import AppKit

class DropZoneNSView: NSView {
    var store: StashStore?
    var isDraggingOver = false

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
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setDraggingOver(true)
        return .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDraggingOver(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        urls?.forEach { store?.stash(url: $0) }
        setDraggingOver(false)
        return !(urls?.isEmpty ?? true)
    }

    private func setDraggingOver(_ active: Bool) {
        isDraggingOver = active
        let fillColor = active
            ? NSColor.white.withAlphaComponent(InteractionMotionStyle.dropZoneActiveFillAlpha).cgColor
            : NSColor.clear.cgColor
        let borderColor = active
            ? NSColor.white.withAlphaComponent(InteractionMotionStyle.dropZoneActiveStrokeAlpha).cgColor
            : NSColor.clear.cgColor
        let borderWidth: CGFloat = active ? 1 : 0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = InteractionMotionStyle.dropZoneHighlightDuration
            context.allowsImplicitAnimation = true
            self.animator().layer?.backgroundColor = fillColor
            self.animator().layer?.borderColor = borderColor
            self.animator().layer?.borderWidth = borderWidth
        }
    }
}
