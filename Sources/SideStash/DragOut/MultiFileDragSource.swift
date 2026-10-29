import AppKit
import SwiftUI

/// Transparent drag source that lifts every given file in one session, so a
/// whole stash can be dropped into an upload area at once.
///
/// Only `.copy` is offered and the drop is not finalized: unlike dragging a
/// single row out, the files stay in the stash.
struct MultiFileDragSource: NSViewRepresentable {
    let items: [StashItem]
    var isEnabled = true
    var onPressedChanged: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> MultiFileDragSourceView {
        let view = MultiFileDragSourceView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: MultiFileDragSourceView, context: Context) {
        nsView.items = items
        nsView.isEnabled = isEnabled
        nsView.onPressedChanged = onPressedChanged
    }
}

final class MultiFileDragSourceView: NSView {
    var items: [StashItem] = []
    var isEnabled = true
    var onPressedChanged: ((Bool) -> Void)?

    private enum Layout {
        static let iconSize: CGFloat = 40
        static let stackOffset: CGFloat = 6
        /// Icons past this many share the last position; the badge-less stack
        /// still reads as "many".
        static let maxVisibleOffsets = 4
    }

    private var isDraggingSessionActive = false

    /// The panel never activates the app; take the first click anyway.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, !items.isEmpty else { return }
        onPressedChanged?(true)
    }

    override func mouseUp(with event: NSEvent) {
        onPressedChanged?(false)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, !items.isEmpty, !isDraggingSessionActive else { return }

        let origin = convert(event.locationInWindow, from: nil)
        let draggingItems = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let offset = CGFloat(min(index, Layout.maxVisibleOffsets)) * Layout.stackOffset
            let frame = NSRect(
                x: origin.x - Layout.iconSize / 2 + offset,
                y: origin.y - Layout.iconSize / 2 - offset,
                width: Layout.iconSize,
                height: Layout.iconSize
            )
            draggingItem.setDraggingFrame(frame, contents: item.icon)
            return draggingItem
        }

        isDraggingSessionActive = true
        onPressedChanged?(false)
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.draggingFormation = .stack
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
}

extension MultiFileDragSourceView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        isDraggingSessionActive = false
    }
}
