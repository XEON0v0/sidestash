import SwiftUI

struct StashContentView: View {
    @EnvironmentObject var store: StashStore
    var panelHeight: CGFloat = 420
    var onClose: (() -> Void)?

    private enum Layout {
        static let closeButtonSize: CGFloat = 18
        static let closeButtonFontSize: CGFloat = 11
        static let headerFontSize: CGFloat = 14
        static let headerPadding: CGFloat = 16
        static let headerVerticalPadding: CGFloat = 12
    }

    var body: some View {
        ZStack {
            GlassBackgroundView()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                Divider()
                    .background(Color.white.opacity(0.2))

                if store.items.isEmpty {
                    emptyState
                } else {
                    fileGrid
                }
            }
        }
        .frame(width: 320, height: panelHeight)
    }

    private var header: some View {
        HStack {
            Text("FileStash")
                .font(.system(size: Layout.headerFontSize, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            Button(action: {
                onClose?()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: Layout.closeButtonFontSize, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: Layout.closeButtonSize, height: Layout.closeButtonSize)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, Layout.headerPadding)
        .padding(.vertical, Layout.headerVerticalPadding)
        .background(
            WindowDragHandle()
                .background(Color.white.opacity(0.05))
        )
    }

    private var fileGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.items) { item in
                    FileGridItem(item: item)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(12)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.items.count)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("empty_state.drag_here", comment: "Empty state instruction"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragHandleView {
        return WindowDragHandleView()
    }

    func updateNSView(_ nsView: WindowDragHandleView, context: Context) {}
}

class WindowDragHandleView: NSView {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startMouse = dragStartMouseLocation, let startOrigin = dragStartWindowOrigin else { return }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - startMouse.x
        let deltaY = currentMouse.y - startMouse.y

        window?.setFrameOrigin(NSPoint(x: startOrigin.x + deltaX, y: startOrigin.y + deltaY))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
    }
}
