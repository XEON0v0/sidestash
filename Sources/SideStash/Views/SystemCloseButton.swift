import AppKit
import SwiftUI

/// The system's own close (traffic-light) button, hosted in the borderless panel.
struct SystemCloseButton: NSViewRepresentable {
    var action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> CloseButtonGroupView {
        let group = CloseButtonGroupView()
        if let button = NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable]) {
            button.target = context.coordinator
            button.action = #selector(Coordinator.close)
            button.setAccessibilityLabel(NSLocalizedString("Close", comment: "Close panel"))
            group.install(button)
        }
        return group
    }

    func updateNSView(_ nsView: CloseButtonGroupView, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func close() {
            action()
        }
    }
}

/// Stands in for the titlebar's button group: a standalone standard button
/// asks its superview `_mouseInGroup:` whether to draw its hover state, but
/// outside a titlebar nothing tells it the pointer arrived, so this view
/// tracks the pointer and pokes the button to re-query.
final class CloseButtonGroupView: NSView {
    private static let refreshHoverSelector = Selector(("mouseEnteredOrExited"))

    private var button: NSButton?
    private var isMouseInside = false {
        didSet {
            guard isMouseInside != oldValue, let button else { return }
            if button.responds(to: Self.refreshHoverSelector) {
                button.perform(Self.refreshHoverSelector)
            }
            button.needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        button?.frame.size ?? NSSize(width: 14, height: 16)
    }

    func install(_ button: NSButton) {
        self.button = button
        addSubview(button)
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        guard let button else { return }
        let size = button.frame.size
        button.setFrameOrigin(NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
    }

    @objc(_mouseInGroup:)
    func mouseInGroup(_ button: NSButton) -> Bool {
        isMouseInside
    }
}
