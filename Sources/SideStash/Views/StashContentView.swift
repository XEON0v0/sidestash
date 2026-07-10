import SwiftUI

struct StashContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: StashStore
    @State private var pendingAlert: BulkActionAlert?

    var panelHeight: CGFloat = 420
    var onClose: (() -> Void)?
    var onAlertPresentationChanged: ((Bool) -> Void)?

    private enum BulkActionAlert: Identifiable {
        case confirmTrash
        case result(title: String, message: String)

        var id: String {
            switch self {
            case .confirmTrash:
                return "confirmTrash"
            case let .result(title, message):
                return "result:\(title):\(message)"
            }
        }
    }

    private enum Layout {
        static let headerTitleFontSize: CGFloat = 13
        static let emptyStateBottomPadding: CGFloat = 18
        static let emptyStateFontSize: CGFloat = 14
    }

    var body: some View {
        let paneAppearance = SideStashSidebarStyle.paneAppearance(for: colorScheme)

        ZStack {
            Color(nsColor: paneAppearance.contentBackground)
                .opacity(SideStashSidebarChromePolicy.outerPaneFillAlpha)
                .clipShape(RoundedRectangle(cornerRadius: SideStashSidebarStyle.paneCornerRadius, style: .continuous))
                .allowsHitTesting(false)

            sidebarPlate(paneAppearance: paneAppearance)
                .padding(SideStashSidebarStyle.sidebarPlateInset)
        }
        .frame(width: 320, height: panelHeight)
        .onChange(of: pendingAlert?.id) { _, alertID in
            onAlertPresentationChanged?(alertID != nil)
        }
        .onDisappear {
            onAlertPresentationChanged?(false)
        }
        .alert(item: $pendingAlert) { alert in
            switch alert {
            case .confirmTrash:
                return Alert(
                    title: Text(NSLocalizedString("bulk.trash.confirm.title", comment: "Confirm moving all files to Trash")),
                    message: Text(NSLocalizedString("bulk.trash.confirm.message", comment: "Trash all confirmation message")),
                    primaryButton: .destructive(Text(NSLocalizedString("bulk.trash.confirm.button", comment: "Confirm trash all"))) {
                        let result = store.trashAll()
                        showResult(
                            result,
                            successKey: "bulk.trash.result.success",
                            partialKey: "bulk.trash.result.partial"
                        )
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("bulk.cancel.button", comment: "Cancel bulk action")))
                )
            case let .result(title, message):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text(NSLocalizedString("bulk.result.ok.button", comment: "Dismiss result alert")))
                )
            }
        }
    }

    private func sidebarPlate(paneAppearance: SideStashPaneAppearance) -> some View {
        ZStack(alignment: .top) {
            GlassBackgroundView(cornerRadius: SideStashSidebarStyle.sidebarPlateCornerRadius)
                .overlay(
                    Color(nsColor: paneAppearance.contentBackground)
                        .opacity(paneAppearance.contentBackgroundAlpha)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SideStashSidebarStyle.sidebarPlateCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(SideStashSidebarChromePolicy.sidebarPlateHighlightStrokeAlpha), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SideStashSidebarStyle.sidebarPlateCornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(SideStashSidebarChromePolicy.sidebarPlateSubtleBorderAlpha), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: SideStashSidebarStyle.sidebarPlateCornerRadius, style: .continuous))
                .shadow(
                    color: .black.opacity(SideStashSidebarChromePolicy.sidebarPlateShadowOpacity),
                    radius: SideStashSidebarChromePolicy.sidebarPlateShadowRadius,
                    y: SideStashSidebarChromePolicy.sidebarPlateShadowYOffset
                )
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

            bottomBulkActions
                .padding(.bottom, SideStashSidebarChromePolicy.bottomActionsBottomInset)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var floatingHeader: some View {
        let appearance = SideStashSidebarStyle.headerAppearance(for: colorScheme)

        return ZStack {
            HeaderDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)

            Text("SideStash")
                .font(.system(size: Layout.headerTitleFontSize, weight: .semibold))
                .foregroundStyle(.primary.opacity(appearance.textOpacity))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SideStashSidebarChromePolicy.headerTitleReservedSideWidth)

            closeButton
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, SideStashSidebarChromePolicy.closeButtonLeadingInset)
        }
        .frame(height: SideStashSidebarStyle.headerHeight)
    }

    private var closeButton: some View {
        Button(action: {
            onClose?()
        }) {
            Circle()
                .fill(Color(nsColor: SideStashSidebarChromePolicy.closeButtonFill))
                .frame(
                    width: SideStashSidebarChromePolicy.closeButtonSize,
                    height: SideStashSidebarChromePolicy.closeButtonSize
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.black.opacity(SideStashSidebarChromePolicy.closeButtonBorderAlpha),
                            lineWidth: 1
                        )
                )
                .frame(
                    width: SideStashSidebarChromePolicy.closeButtonHoverSize,
                    height: SideStashSidebarChromePolicy.closeButtonHoverSize
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close"))
    }

    private var fileGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.items) { item in
                    FileGridItem(item: item)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            .padding(
                .bottom,
                SideStashSidebarChromePolicy.bottomActionsOverlayHeight
                    + SideStashSidebarChromePolicy.bottomActionsBottomInset
                    + 12
            )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.items.count)
    }

    private var bottomBulkActions: some View {
        BottomActionToolbar(
            hasItems: !store.items.isEmpty,
            hasRestorableItems: store.items.contains { $0.originalURL != nil },
            perform: performBulkAction
        )
    }

    private func performBulkAction(_ action: SideStashBulkAction) {
        switch action {
        case .trashAll:
            pendingAlert = .confirmTrash

        case .moveAllToCurrentFolder:
            moveAllToCurrentFinderFolder()

        case .restoreAll:
            guard store.items.contains(where: { $0.originalURL != nil }) else {
                pendingAlert = .result(
                    title: NSLocalizedString("bulk.restore.tooltip", comment: "Restore all title"),
                    message: NSLocalizedString("bulk.restore.result.none", comment: "No restorable files")
                )
                return
            }

            let result = store.restoreAllToOriginal()
            showResult(
                result,
                successKey: "bulk.restore.result.success",
                partialKey: "bulk.restore.result.partial"
            )
        }
    }

    private func moveAllToCurrentFinderFolder() {
        guard let destination = FinderCurrentFolderResolver.shared.currentFinderFolder() else {
            pendingAlert = .result(
                title: NSLocalizedString("bulk.current_folder.missing.title", comment: "Missing Finder folder title"),
                message: NSLocalizedString("bulk.current_folder.missing.message", comment: "Missing Finder folder message")
            )
            return
        }

        let result = store.moveAll(to: destination)
        showResult(
            result,
            successKey: "bulk.move.result.success",
            partialKey: "bulk.move.result.partial"
        )
    }

    private func showResult(
        _ result: BatchOperationResult,
        successKey: String,
        partialKey: String
    ) {
        let key = result.failureCount == 0 ? successKey : partialKey
        let format = NSLocalizedString(key, comment: "Bulk operation result")
        let message: String
        if result.failureCount == 0 {
            message = String(format: format, result.successCount)
        } else {
            message = String(format: format, result.successCount, result.failureCount)
        }

        pendingAlert = .result(title: "SideStash", message: message)
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

struct HeaderDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragHandleView {
        let view = WindowDragHandleView()
        view.configureTransparentDragSurface()
        return view
    }

    func updateNSView(_ nsView: WindowDragHandleView, context: Context) {
        nsView.configureTransparentDragSurface()
    }
}

class WindowDragHandleView: NSView {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    func configureTransparentDragSurface() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

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
