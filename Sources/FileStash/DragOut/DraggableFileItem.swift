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
        static let cornerRadius: CGFloat = 10
        static let borderWidth: CGFloat = 1
        static let iconSize: CGFloat = 40
        static let iconTopPadding: CGFloat = 8
        static let labelTopPadding: CGFloat = 4
        static let labelHorizontalPadding: CGFloat = 4
        static let labelFontSize: CGFloat = 11
    }

    private var imageView: NSImageView!
    private var label: NSTextField!

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
        layer?.cornerRadius = Layout.cornerRadius
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        layer?.borderWidth = Layout.borderWidth
        layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: Layout.labelFontSize)
        label.textColor = NSColor.labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.iconTopPadding),
            imageView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            imageView.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Layout.labelTopPadding),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.labelHorizontalPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.labelHorizontalPadding),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Layout.labelHorizontalPadding)
        ])

        updateContent()
    }

    private func updateContent() {
        imageView.image = item?.icon
        label.stringValue = item?.name ?? ""
    }

    override func mouseDown(with event: NSEvent) {
        // Capture to prepare for drag
    }

    override func mouseDragged(with event: NSEvent) {
        guard let item = item else { return }

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

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}

extension DraggableFileItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .move, .link]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation != [], let item = item else { return }

        DispatchQueue.main.async {
            self.store?.finalizeDrag(item: item)
        }
    }
}
