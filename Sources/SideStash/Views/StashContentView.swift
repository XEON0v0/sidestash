import SwiftUI

struct StashContentView: View {
    @EnvironmentObject var store: StashStore
    var panelHeight: CGFloat = 420
    var onClose: (() -> Void)?

    private enum Layout {
        static let headerTitleFontSize: CGFloat = 13
        static let headerCloseFontSize: CGFloat = 11
        static let headerInternalSpacing: CGFloat = 10
        static let headerHorizontalPadding: CGFloat = 12
        static let headerShadowRadius: CGFloat = 12
        static let headerShadowYOffset: CGFloat = 4
        static let emptyStateBottomPadding: CGFloat = 18
        static let emptyStateFontSize: CGFloat = 14
    }

    var body: some View {
        ZStack(alignment: .top) {
            GlassBackgroundView(cornerRadius: SideStashSidebarStyle.paneCornerRadius)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: SideStashSidebarChromePolicy.headerContainerHeight)

                if store.items.isEmpty {
                    emptyState
                } else {
                    fileGrid
                }
            }

            floatingHeader
                .padding(.top, SideStashSidebarStyle.headerTopInset)
                .padding(.horizontal, SideStashSidebarStyle.headerHorizontalInset)
        }
        .frame(width: 320, height: panelHeight)
    }

    private var floatingHeader: some View {
        HStack(spacing: Layout.headerInternalSpacing) {
            Text("SideStash")
                .font(.system(size: Layout.headerTitleFontSize, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.96))
            Spacer()

            Button(action: {
                onClose?()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: Layout.headerCloseFontSize, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .frame(
                        width: SideStashSidebarChromePolicy.closeButtonSize,
                        height: SideStashSidebarChromePolicy.closeButtonSize
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .frame(height: SideStashSidebarStyle.headerHeight)
        .background(
            WindowDragHandle()
                .background(Color.white.opacity(SideStashSidebarStyle.headerBackgroundAlpha))
        )
        .clipShape(RoundedRectangle(cornerRadius: SideStashSidebarStyle.headerCornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(CGFloat(SideStashSidebarStyle.headerShadowOpacity)),
            radius: Layout.headerShadowRadius,
            y: Layout.headerShadowYOffset
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
        VStack(spacing: SideStashSidebarStyle.emptySpacing) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: SideStashSidebarStyle.emptyIconSize))
                .foregroundStyle(.secondary.opacity(0.72))
            Text(NSLocalizedString("empty_state.drag_here", comment: "Empty state instruction"))
                .font(.system(size: Layout.emptyStateFontSize, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.82))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, Layout.emptyStateBottomPadding)
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
