import AppKit
import SwiftUI

/// Header capsule in the panel's top-right corner. The trailing `…` segment
/// opens the more-actions menu; the leading segment repeats the last action
/// used, behind a faint hairline.
///
/// Dragging and sharing need an AppKit view, so the pill runs those itself;
/// every other action goes to `perform`.
struct MoreActionsPill: View {
    let items: [StashItem]
    let isBusy: Bool
    let perform: (SideStashMoreAction) -> Void
    var onSharePresentationChanged: (Bool) -> Void = { _ in }

    @State private var lastUsed = MoreActionsMemory().lastUsed
    @State private var isLeadingHovered = false
    @State private var isDragPressed = false
    @State private var isLeadingHinted = false
    @State private var isMenuHovered = false
    @State private var hintTask: Task<Void, Never>?
    @State private var sharePresenter = SystemSharePresenter()

    private var hasItems: Bool { !items.isEmpty }

    /// Same structure as the bottom toolbar: interactive glass in a container,
    /// the lit rim attached outside it.
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                leadingSegment
                divider
                menuSegment
            }
            .frame(height: SideStashSidebarChromePolicy.moreActionsHeight)
            .background {
                SharingAnchor(presenter: sharePresenter)
            }
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        // `.plate` bevel: the `.pill` slope is too wide for a 28 pt capsule.
        .overlay {
            GlassRim(shape: .capsule, kind: .plate)
        }
        .onDisappear {
            hintTask?.cancel()
            hintTask = nil
        }
    }

    // MARK: Leading segment

    private var leadingSegment: some View {
        let availability = lastUsed.availability(hasItems: hasItems)
        let isEnabled = availability.isEnabled && !isBusy

        return Button {
            run(lastUsed)
        } label: {
            leadingLabel
        }
        .buttonStyle(BottomActionButtonStyle(
            isHovered: isLeadingHovered || isDragPressed || isLeadingHinted
        ))
        .disabled(!isEnabled)
        .overlay {
            // Dragging is the action itself: the AppKit source sits on top
            // and takes the mouse, so the button never fires for it.
            if lastUsed == .dragAllOut {
                MultiFileDragSource(items: items, isEnabled: isEnabled) { pressed in
                    isDragPressed = pressed
                }
            }
        }
        .onHover { isLeadingHovered = $0 }
        .help(leadingHelpText(availability: availability))
        .accessibilityLabel(Text(NSLocalizedString(lastUsed.titleKey, comment: "More action")))
    }

    private var leadingLabel: some View {
        HStack(spacing: 5) {
            if isBusy {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: SideStashSidebarChromePolicy.moreActionsIconSize)
            } else {
                Image(systemName: lastUsed.symbolName)
                    .font(.system(size: SideStashSidebarChromePolicy.moreActionsIconSize, weight: .medium))
            }
            Text(NSLocalizedString(lastUsed.shortTitleKey, comment: "Last used more action"))
                .font(.system(size: SideStashSidebarChromePolicy.moreActionsLabelFontSize, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, SideStashSidebarChromePolicy.moreActionsLeadingHorizontalPadding)
        .frame(
            maxWidth: SideStashSidebarChromePolicy.moreActionsLeadingMaxWidth,
            minHeight: SideStashSidebarChromePolicy.moreActionsHeight,
            maxHeight: SideStashSidebarChromePolicy.moreActionsHeight
        )
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
    }

    private func leadingHelpText(availability: SideStashBottomActionAvailability) -> String {
        let title = lastUsed == .dragAllOut
            ? NSLocalizedString("more.drag_all.hint", comment: "How to use drag all out")
            : NSLocalizedString(lastUsed.titleKey, comment: "More action")
        guard let reasonKey = availability.reasonKey else { return title }
        return "\(title) - \(NSLocalizedString(reasonKey, comment: "More action unavailable reason"))"
    }

    // MARK: Divider

    private var divider: some View {
        Rectangle()
            .fill(Color(nsColor: SideStashGlassPalette.pillDivider.dynamic))
            .frame(
                width: SideStashSidebarChromePolicy.moreActionsDividerWidth,
                height: SideStashSidebarChromePolicy.moreActionsDividerHeight
            )
            .allowsHitTesting(false)
    }

    // MARK: Menu segment

    private var menuSegment: some View {
        Menu {
            Section(NSLocalizedString("more.section.share", comment: "Bulk share section")) {
                menuItem(.dragAllOut)
                menuItem(.systemShare)
            }
            menuItem(.exportArchive)
            Divider()
            menuItem(.convertFormat)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: SideStashSidebarChromePolicy.moreActionsIconSize, weight: .semibold))
                .frame(
                    width: SideStashSidebarChromePolicy.moreActionsMenuSegmentWidth,
                    height: SideStashSidebarChromePolicy.moreActionsHeight
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(BottomActionButtonStyle(isHovered: isMenuHovered))
        .fixedSize()
        .onHover { isMenuHovered = $0 }
        .help(NSLocalizedString("more.menu.title", comment: "More actions"))
        .accessibilityLabel(Text(NSLocalizedString("more.menu.title", comment: "More actions")))
    }

    private func menuItem(_ action: SideStashMoreAction) -> some View {
        let isEnabled = action.availability(hasItems: hasItems).isEnabled
            && !(isBusy && action == .exportArchive)

        return Button {
            choose(action)
        } label: {
            Label(NSLocalizedString(action.titleKey, comment: "More action"), systemImage: action.symbolName)
        }
        .disabled(!isEnabled)
    }

    // MARK: Actions

    private func choose(_ action: SideStashMoreAction) {
        guard action.isImplemented else { return }

        MoreActionsMemory().record(action)
        lastUsed = action

        // A menu item cannot start a drag; it turns the leading segment into
        // the drag handle and points at it.
        if action == .dragAllOut {
            hintLeadingSegment()
        } else {
            run(action)
        }
    }

    private func run(_ action: SideStashMoreAction) {
        switch action {
        case .dragAllOut, .convertFormat:
            break
        case .systemShare:
            sharePresenter.present(
                urls: items.map(\.url),
                onPresentationChanged: onSharePresentationChanged
            )
        case .exportArchive:
            perform(action)
        }
    }

    private func hintLeadingSegment() {
        hintTask?.cancel()
        isLeadingHinted = true
        hintTask = Task { @MainActor in
            let duration = SideStashSidebarChromePolicy.moreActionsHintDuration
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isLeadingHinted = false
        }
    }
}

// MARK: - System share

/// Shows the system share picker for a set of files, anchored on the pill.
@MainActor
final class SystemSharePresenter: NSObject, @preconcurrency NSSharingServicePickerDelegate {
    fileprivate weak var anchorView: NSView?
    private var onPresentationChanged: ((Bool) -> Void)?

    func present(urls: [URL], onPresentationChanged: @escaping (Bool) -> Void) {
        guard let anchorView, !urls.isEmpty else { return }

        self.onPresentationChanged = onPresentationChanged
        onPresentationChanged(true)

        let picker = NSSharingServicePicker(items: urls)
        picker.delegate = self
        picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    /// Called with `nil` when the picker is dismissed without a choice.
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        onPresentationChanged?(false)
        onPresentationChanged = nil
    }
}

/// Invisible view that gives the share picker something to anchor to.
private struct SharingAnchor: NSViewRepresentable {
    let presenter: SystemSharePresenter

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        presenter.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        presenter.anchorView = nsView
    }
}
