import SwiftUI

struct StashContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: StashStore
    @State private var pendingAlert: BulkActionAlert?

    var panelHeight: CGFloat = 420
    var onClose: (() -> Void)?

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

        ZStack(alignment: .top) {
            GlassBackgroundView(cornerRadius: SideStashSidebarStyle.paneCornerRadius)
                .allowsHitTesting(false)

            Color(nsColor: paneAppearance.contentBackground)
                .opacity(paneAppearance.contentBackgroundAlpha)
                .clipShape(RoundedRectangle(cornerRadius: SideStashSidebarStyle.paneCornerRadius, style: .continuous))
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
        .frame(width: 320, height: panelHeight)
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

    private var floatingHeader: some View {
        let appearance = SideStashSidebarStyle.headerAppearance(for: colorScheme)

        return ZStack {
            Text("SideStash")
                .font(.system(size: Layout.headerTitleFontSize, weight: .semibold))
                .foregroundStyle(.primary.opacity(appearance.textOpacity))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SideStashSidebarChromePolicy.headerTitleReservedSideWidth)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, SideStashSidebarChromePolicy.closeButtonLeadingInset)
        }
        .frame(height: SideStashSidebarStyle.headerHeight)
        .background(
            HeaderGlassDragHandle(cornerRadius: SideStashSidebarStyle.headerCornerRadius)
                .overlay(
                    Color(nsColor: appearance.overlayBase)
                        .opacity(appearance.overlayAlpha)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SideStashSidebarStyle.headerCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(SideStashSidebarChromePolicy.headerHighlightStrokeAlpha), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SideStashSidebarStyle.headerCornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(SideStashSidebarChromePolicy.headerSubtleBorderAlpha), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: SideStashSidebarStyle.headerCornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(CGFloat(SideStashSidebarStyle.headerShadowOpacity)),
            radius: SideStashSidebarChromePolicy.headerShadowRadius,
            y: SideStashSidebarChromePolicy.headerShadowYOffset
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
            .padding(.top, 12)
            .padding(.horizontal, 12)
            .padding(.bottom, SideStashSidebarChromePolicy.bottomActionsHeight + SideStashSidebarChromePolicy.bottomActionsBottomInset + 12)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.items.count)
    }

    private var bottomBulkActions: some View {
        let isDisabled = store.items.isEmpty

        return HStack(spacing: 0) {
            bulkActionButton(
                symbolName: SideStashSidebarChromePolicy.trashAllSymbolName,
                labelKey: "bulk.trash.tooltip",
                isDisabled: isDisabled
            ) {
                pendingAlert = .confirmTrash
            }

            bulkActionButton(
                symbolName: SideStashSidebarChromePolicy.moveAllToCurrentFolderSymbolName,
                labelKey: "bulk.move_current.tooltip",
                isDisabled: isDisabled
            ) {
                moveAllToCurrentFinderFolder()
            }

            bulkActionButton(
                symbolName: SideStashSidebarChromePolicy.restoreAllSymbolName,
                labelKey: "bulk.restore.tooltip",
                isDisabled: isDisabled
            ) {
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
        .frame(height: SideStashSidebarChromePolicy.bottomActionsHeight)
        .background(bottomActionsBackground)
        .clipShape(RoundedRectangle(cornerRadius: SideStashSidebarChromePolicy.bottomActionsCornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(SideStashSidebarChromePolicy.bottomActionsShadowOpacity),
            radius: 18,
            y: 10
        )
        .disabled(isDisabled)
    }

    private var bottomActionsBackground: some View {
        RoundedRectangle(cornerRadius: SideStashSidebarChromePolicy.bottomActionsCornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: SideStashSidebarChromePolicy.bottomActionsCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(SideStashSidebarChromePolicy.bottomActionsBackgroundAlpha))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SideStashSidebarChromePolicy.bottomActionsCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(SideStashSidebarChromePolicy.bottomActionsHighlightStrokeAlpha), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SideStashSidebarChromePolicy.bottomActionsCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(SideStashSidebarChromePolicy.bottomActionsBorderAlpha), lineWidth: 1)
            )
    }

    private func bulkActionButton(
        symbolName: String,
        labelKey: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: SideStashSidebarChromePolicy.bottomActionsIconSize, weight: .medium))
                .foregroundStyle(.primary.opacity(
                    isDisabled
                    ? SideStashSidebarChromePolicy.bottomActionsDisabledIconOpacity
                    : SideStashSidebarChromePolicy.bottomActionsIconOpacity
                ))
                .frame(
                    width: SideStashSidebarChromePolicy.bottomActionButtonWidth,
                    height: SideStashSidebarChromePolicy.bottomActionsHeight
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString(labelKey, comment: "Bulk action tooltip"))
        .accessibilityLabel(Text(NSLocalizedString(labelKey, comment: "Bulk action accessibility label")))
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

struct HeaderGlassDragHandle: NSViewRepresentable {
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> WindowDragHandleView {
        let view = WindowDragHandleView()
        view.configureGlassBackground(cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: WindowDragHandleView, context: Context) {
        nsView.configureGlassBackground(cornerRadius: cornerRadius)
    }
}

class WindowDragHandleView: NSView {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var visualEffectView: NSVisualEffectView?

    func configureGlassBackground(cornerRadius: CGFloat) {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true

        let effectView: NSVisualEffectView
        if let visualEffectView {
            effectView = visualEffectView
        } else {
            effectView = NSVisualEffectView(frame: bounds)
            effectView.autoresizingMask = [.width, .height]
            effectView.state = .active
            addSubview(effectView, positioned: .below, relativeTo: nil)
            visualEffectView = effectView
        }

        effectView.material = SideStashSidebarChromePolicy.headerMaterial
        effectView.blendingMode = SideStashSidebarChromePolicy.headerBlendingMode
        effectView.isEmphasized = SideStashSidebarChromePolicy.isHeaderMaterialEmphasized
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
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
