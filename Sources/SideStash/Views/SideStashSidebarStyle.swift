import AppKit

enum SideStashBulkAction: CaseIterable, Hashable {
    case trashAll
    case moveAllToCurrentFolder
    case restoreAll

    var symbolName: String {
        switch self {
        case .trashAll:
            return SideStashSidebarChromePolicy.trashAllSymbolName
        case .moveAllToCurrentFolder:
            return SideStashSidebarChromePolicy.moveAllToCurrentFolderSymbolName
        case .restoreAll:
            return SideStashSidebarChromePolicy.restoreAllSymbolName
        }
    }

    var titleKey: String {
        switch self {
        case .trashAll:
            return "bulk.trash.tooltip"
        case .moveAllToCurrentFolder:
            return "bulk.move_current.tooltip"
        case .restoreAll:
            return "bulk.restore.tooltip"
        }
    }
}

/// Layout metrics for the Liquid Glass panel. Colors live in
/// `SideStashGlassPalette`; the glass itself is system-drawn, so there are no
/// fill, stroke or shadow tokens here.
enum SideStashSidebarStyle {
    /// Corner radius of the panel's glass body and of the drop zone that
    /// clips content to it.
    static let paneCornerRadius: CGFloat = 24

    static let headerHeight: CGFloat = 32
    static let headerHorizontalInset: CGFloat = 12
    static let headerTopInset: CGFloat = 16

    /// Each file sits on its own glass plate.
    static let rowHeight: CGFloat = 44
    static let rowSpacing: CGFloat = 6
    /// List inset from the panel edge; with `rowCornerRadius` it keeps the
    /// plates concentric with the panel (24 - 12 = 12).
    static let fileListInset: CGFloat = 12
    static let rowCornerRadius: CGFloat = 12
    /// Center of the file icon inside a row: 8 pt leading padding + half the 32 pt icon.
    static let rowIconCenterX: CGFloat = 24
    static let emptyIconSize: CGFloat = 44
    static let emptySpacing: CGFloat = 10
}

enum SideStashSidebarChromePolicy {
    static var headerContainerHeight: CGFloat {
        58
    }

    /// Width reserved for the system close button (its own frame is ~14 pt).
    static var closeButtonSlotWidth: CGFloat {
        18
    }

    static var closeButtonLeadingInset: CGFloat {
        12
    }

    // Header "more actions" pill, right of the close button's row. Its
    // trailing inset keeps it about as far from the panel's top-right corner
    // as the close button is from the top-left one.
    static let moreActionsHeight: CGFloat = 28
    static let moreActionsTrailingInset: CGFloat = 4
    static let moreActionsMenuSegmentWidth: CGFloat = 30
    static let moreActionsLeadingMaxWidth: CGFloat = 120
    static let moreActionsLeadingHorizontalPadding: CGFloat = 10
    static let moreActionsDividerWidth: CGFloat = 1
    static let moreActionsDividerHeight: CGFloat = 14
    static let moreActionsIconSize: CGFloat = 13
    static let moreActionsLabelFontSize: CGFloat = 12
    /// How long the leading segment glows after it switches to a new action.
    static let moreActionsHintDuration: TimeInterval = 1.2

    static var usesSystemPanelShadow: Bool {
        true
    }

    static let bottomActionsHeight: CGFloat = 40
    static let bottomActionButtonWidth: CGFloat = 44
    static let bottomActionsBottomInset: CGFloat = 16
    static let bottomActionsIconSize: CGFloat = 18
    static let bottomActionsTooltipGap: CGFloat = 8
    static let bottomActionsTooltipDelay: TimeInterval = 0.35
    static let bottomActionHoverScale: CGFloat = 1.04
    static let bottomActionPressedScale: CGFloat = 0.94
    static let bottomActionsEnabledIconOpacity: CGFloat = 0.88
    static let bottomActionsDisabledIconOpacity: CGFloat = 0.28
    static let bottomActionsTooltipMaxWidth: CGFloat = 240
    static let bottomActionsTooltipCornerRadius: CGFloat = 8

    static let trashAllSymbolName = "trash"
    static let moveAllToCurrentFolderSymbolName = "folder.badge.plus"
    static let restoreAllSymbolName = "arrow.uturn.backward"
}
