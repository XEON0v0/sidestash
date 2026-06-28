import AppKit

enum FileStashSidebarStyle {
    static let paneCornerRadius: CGFloat = 20
    static let paneFillAlpha: CGFloat = 0.18
    static let paneBorderAlpha: CGFloat = 0.1
    static let paneShadowOpacity: Float = 0.1
    static let paneShadowBlur: CGFloat = 20

    static let headerHeight: CGFloat = 38
    static let headerCornerRadius: CGFloat = 12
    static let headerHorizontalInset: CGFloat = 12
    static let headerTopInset: CGFloat = 10
    static let headerBackgroundAlpha: CGFloat = 0.58
    static let headerShadowOpacity: Float = 0.08

    static let rowHeight: CGFloat = 39
    static let rowCornerRadius: CGFloat = 10
    static let rowHoverFillAlpha: CGFloat = 0.09
    static let emptyIconSize: CGFloat = 44
    static let emptySpacing: CGFloat = 10
}

enum FileStashSidebarChromePolicy {
    static var contentTopInset: CGFloat {
        FileStashSidebarStyle.headerTopInset + FileStashSidebarStyle.headerHeight + 6
    }

    static var headerContainerHeight: CGFloat {
        54
    }

    static var closeButtonSize: CGFloat {
        18
    }

    static var paneBorderWidth: CGFloat {
        1
    }

    static var paneShadowOffsetY: CGFloat {
        -2
    }
}
