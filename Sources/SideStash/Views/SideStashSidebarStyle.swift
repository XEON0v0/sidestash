import AppKit
import SwiftUI

struct SideStashHeaderAppearance {
    let overlayBase: NSColor
    let overlayAlpha: CGFloat
    let textOpacity: CGFloat
}

struct SideStashPaneAppearance {
    let contentBackground: NSColor
    let contentBackgroundAlpha: CGFloat
}

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

enum SideStashSidebarStyle {
    static let paneCornerRadius: CGFloat = 20
    static let paneFillAlpha: CGFloat = 0.18
    static let paneBorderAlpha: CGFloat = 0.1
    static let paneShadowOpacity: Float = 0.1
    static let paneShadowBlur: CGFloat = 20
    static let sidebarPlateInset: CGFloat = 5
    static let sidebarPlateCornerRadius: CGFloat = 18

    static let headerHeight: CGFloat = 32
    static let headerCornerRadius: CGFloat = 0
    static let headerHorizontalInset: CGFloat = 12
    static let headerTopInset: CGFloat = 16
    static let headerBackgroundAlpha: CGFloat = 0
    static let headerShadowOpacity: Float = 0

    static let rowHeight: CGFloat = 39
    static let rowCornerRadius: CGFloat = 10
    static let rowHoverFillAlpha: CGFloat = 0.09
    static let emptyIconSize: CGFloat = 44
    static let emptySpacing: CGFloat = 10

    static func headerAppearance(for colorScheme: ColorScheme) -> SideStashHeaderAppearance {
        switch colorScheme {
        case .dark:
            return SideStashHeaderAppearance(
                overlayBase: .white,
                overlayAlpha: 0,
                textOpacity: 0.88
            )
        default:
            return SideStashHeaderAppearance(
                overlayBase: .black,
                overlayAlpha: 0,
                textOpacity: 0.9
            )
        }
    }

    static func paneAppearance(for colorScheme: ColorScheme) -> SideStashPaneAppearance {
        switch colorScheme {
        case .dark:
            return SideStashPaneAppearance(
                contentBackground: .windowBackgroundColor,
                contentBackgroundAlpha: 0.18
            )
        default:
            return SideStashPaneAppearance(
                contentBackground: .windowBackgroundColor,
                contentBackgroundAlpha: 0.4
            )
        }
    }

}

enum SideStashSidebarChromePolicy {
    static var contentTopInset: CGFloat {
        SideStashSidebarStyle.headerTopInset + SideStashSidebarStyle.headerHeight + 6
    }

    static var headerContainerHeight: CGFloat {
        58
    }

    static var closeButtonSize: CGFloat {
        12
    }

    static var closeButtonHoverSize: CGFloat {
        18
    }

    static var closeButtonLeadingInset: CGFloat {
        12
    }

    static var headerTitleReservedSideWidth: CGFloat {
        closeButtonLeadingInset + closeButtonHoverSize + 8
    }

    static var closeButtonFill: NSColor {
        NSColor(srgbRed: 236 / 255, green: 103 / 255, blue: 101 / 255, alpha: 1)
    }

    static var closeButtonBorderAlpha: CGFloat {
        0.16
    }

    static var headerMaterial: NSVisualEffectView.Material {
        .sidebar
    }

    static var headerBlendingMode: NSVisualEffectView.BlendingMode {
        .behindWindow
    }

    static var isHeaderMaterialEmphasized: Bool {
        false
    }

    static var headerHighlightStrokeAlpha: CGFloat {
        0
    }

    static var headerSubtleBorderAlpha: CGFloat {
        0
    }

    static var headerShadowRadius: CGFloat {
        0
    }

    static var headerShadowYOffset: CGFloat {
        0
    }

    static var paneBorderWidth: CGFloat {
        1
    }

    static var outerPaneFillAlpha: CGFloat {
        0.12
    }

    static var sidebarPlateHighlightStrokeAlpha: CGFloat {
        0.56
    }

    static var sidebarPlateSubtleBorderAlpha: CGFloat {
        0.035
    }

    static var sidebarPlateShadowOpacity: CGFloat {
        0.075
    }

    static var sidebarPlateShadowRadius: CGFloat {
        18
    }

    static var sidebarPlateShadowYOffset: CGFloat {
        8
    }

    static var paneShadowOffsetY: CGFloat {
        -2
    }

    static var usesSystemPanelShadow: Bool {
        true
    }

    static let bottomActionsHeight: CGFloat = 40
    static let bottomActionButtonWidth: CGFloat = 44
    static let bottomActionsOverlayHeight: CGFloat = 84
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
