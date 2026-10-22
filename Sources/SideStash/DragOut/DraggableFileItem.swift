import SwiftUI
import AppKit

/// Pointer state of a file row. The AppKit row draws no background; it reports
/// this state so SwiftUI can brighten, scale and fade the row's glass plate.
struct FileRowInteraction: Equatable {
    var isHovered = false
    var isPressed = false
    var isLifted = false
}

struct DraggableFileItem: NSViewRepresentable {
    let item: StashItem
    let store: StashStore
    var onInteractionChanged: (FileRowInteraction) -> Void = { _ in }

    func makeNSView(context: Context) -> DraggableFileItemView {
        let view = DraggableFileItemView()
        view.item = item
        view.store = store
        view.onInteractionChanged = onInteractionChanged
        return view
    }

    func updateNSView(_ nsView: DraggableFileItemView, context: Context) {
        nsView.item = item
        nsView.onInteractionChanged = onInteractionChanged
    }

    /// The row takes the width it is offered; otherwise the label's full-length
    /// fitting width would push a long file name past the panel edge.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DraggableFileItemView, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.fittingSize.width,
            height: SideStashSidebarStyle.rowHeight
        )
    }
}

class DraggableFileItemView: NSView {
    var store: StashStore?
    var item: StashItem? {
        didSet {
            updateContent()
        }
    }
    var onInteractionChanged: ((FileRowInteraction) -> Void)?

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
    private(set) var interaction = FileRowInteraction() {
        didSet {
            guard interaction != oldValue else { return }
            onInteractionChanged?(interaction)
        }
    }

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
        layer?.backgroundColor = NSColor.clear.cgColor

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: Layout.labelFontSize, weight: .medium)
        // Plain system color: an alpha variant would freeze at the launch appearance.
        label.textColor = .labelColor
        // Middle truncation keeps the extension visible, as in Finder.
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.cell?.truncatesLastVisibleLine = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
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
        // The panel never activates the app, so hover has to track while inactive.
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    func setHovered(_ hovered: Bool) {
        interaction.isHovered = hovered
    }

    func setPressed(_ pressed: Bool) {
        interaction.isPressed = pressed
    }

    /// A lifted row is being dragged out; it is no longer pressed.
    func setLifted(_ lifted: Bool) {
        var next = interaction
        next.isLifted = lifted
        if lifted {
            next.isPressed = false
        }
        interaction = next
    }

    private func updateContent() {
        imageView.image = item?.icon
        label.stringValue = item?.name ?? ""
        toolTip = item?.name
    }

    override func mouseDown(with event: NSEvent) {
        // Mouse down only prepares a drag; it also presses the row's glass plate.
        setPressed(true)
    }

    override func mouseUp(with event: NSEvent) {
        setPressed(false)
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
        setLifted(true)
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
        setLifted(false)

        if !didCompleteDrop {
            setDragLiftAppearance(lifted: false, animated: true)
            return
        }

        guard let draggedItem else { return }
        store?.finalizeDrag(item: draggedItem)
    }
}
