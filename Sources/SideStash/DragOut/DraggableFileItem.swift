import SwiftUI
import AppKit

struct DraggableFileItem: NSViewRepresentable {
    let item: StashItem
    let store: StashStore

    func makeNSView(context: Context) -> DraggableFileItemView {
        let view = DraggableFileItemView()
        view.item = item
        view.store = store
        return view
    }

    func updateNSView(_ nsView: DraggableFileItemView, context: Context) {
        nsView.item = item
    }
}

class DraggableFileItemView: NSView {
    var store: StashStore?
    var item: StashItem? {
        didSet {
            updateContent()
        }
    }

    private enum Layout {
        static let rowHeight: CGFloat = 38
        static let iconSize: CGFloat = 32
        static let iconLeadingPadding: CGFloat = 8
        static let labelLeadingPadding: CGFloat = 8
        static let labelTrailingPadding: CGFloat = 8
        static let labelFontSize: CGFloat = 13
    }

    private var imageView: NSImageView!
    private var label: NSTextField!
    private var trackingArea: NSTrackingArea?
    private var activeDragItem: StashItem?
    private var isDraggingSessionActive = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = SideStashSidebarStyle.rowCornerRadius
        layer?.backgroundColor = NSColor.clear.cgColor

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: Layout.labelFontSize, weight: .medium)
        label.textColor = NSColor.labelColor.withAlphaComponent(0.92)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.iconLeadingPadding),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            imageView.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: Layout.labelLeadingPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.labelTrailingPadding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        layer?.backgroundColor = NSColor.white.withAlphaComponent(SideStashSidebarStyle.rowHoverFillAlpha).cgColor
        CATransaction.commit()
    }

    override func mouseExited(with event: NSEvent) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        layer?.backgroundColor = NSColor.clear.cgColor
        CATransaction.commit()
    }

    private func updateContent() {
        imageView.image = item?.icon
        label.stringValue = item?.name ?? ""
    }

    override func mouseDown(with event: NSEvent) {
        // Capture to prepare for drag
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let restoreItem = NSMenuItem(
            title: NSLocalizedString("context_menu.restore", comment: ""),
            action: #selector(restoreToOriginal),
            keyEquivalent: ""
        )
        restoreItem.target = self
        menu.addItem(restoreItem)

        let deleteItem = NSMenuItem(
            title: NSLocalizedString("context_menu.trash", comment: ""),
            action: #selector(deleteItem),
            keyEquivalent: ""
        )
        deleteItem.target = self
        menu.addItem(deleteItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func restoreToOriginal() {
        guard let storedItem = item else { return }
        store?.restoreToOriginal(item: storedItem)
    }

    @objc private func deleteItem() {
        guard let storedItem = item else { return }
        store?.delete(item: storedItem)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let item = item else { return }
        guard !isDraggingSessionActive else { return }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        let dragImage = NSImage(size: bounds.size)
        dragImage.lockFocus()
        if let context = NSGraphicsContext.current {
            layer?.render(in: context.cgContext)
        }
        dragImage.unlockFocus()

        draggingItem.setDraggingFrame(bounds, contents: dragImage)

        activeDragItem = item
        isDraggingSessionActive = true
        setDragLiftAppearance(lifted: true, animated: true)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    private func setDragLiftAppearance(lifted: Bool, animated: Bool) {
        let targetAlpha: CGFloat = lifted ? InteractionMotionStyle.dragLiftAlpha : 1.0
        let targetTransform = lifted
            ? CATransform3DMakeScale(InteractionMotionStyle.dragLiftScale, InteractionMotionStyle.dragLiftScale, 1.0)
            : CATransform3DIdentity
        let duration: TimeInterval = animated ? InteractionMotionStyle.dragLiftDuration : 0.0
        let timingName: CAMediaTimingFunctionName = lifted ? .easeOut : .easeInEaseOut

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timingName)
            context.allowsImplicitAnimation = true
            self.animator().alphaValue = targetAlpha
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: timingName))
        layer?.transform = targetTransform
        CATransaction.commit()
    }
}

extension DraggableFileItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .move, .link]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let didCompleteDrop = operation != []
        let draggedItem = activeDragItem ?? item
        activeDragItem = nil
        isDraggingSessionActive = false

        if !didCompleteDrop {
            setDragLiftAppearance(lifted: false, animated: true)
            return
        }

        guard let draggedItem else { return }
        store?.finalizeDrag(item: draggedItem)
    }
}
