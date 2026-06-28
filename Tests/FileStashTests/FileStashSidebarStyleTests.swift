import AppKit
import Testing
@testable import FileStash

struct FileStashSidebarStyleTests {
    @Test func paneChrome_matchesFinderFamilyRanges() {
        #expect(FileStashSidebarStyle.paneCornerRadius >= 18)
        #expect(FileStashSidebarStyle.paneCornerRadius <= 20)
        #expect(FileStashSidebarStyle.paneShadowBlur < 24)
        #expect(FileStashSidebarStyle.paneBorderAlpha < 0.14)
    }

    @Test func balancedGlassHeader_staysLighterThanPaneChrome() {
        #expect(FileStashSidebarStyle.headerHeight < 40)
        #expect(FileStashSidebarStyle.headerCornerRadius < FileStashSidebarStyle.paneCornerRadius)
        #expect(FileStashSidebarStyle.headerShadowOpacity < 0.12)
        #expect(FileStashSidebarStyle.headerBackgroundAlpha > FileStashSidebarStyle.paneFillAlpha)
    }

    @Test func contentMetrics_keepFinderLikeDensity() {
        #expect(FileStashSidebarStyle.rowHeight >= 38)
        #expect(FileStashSidebarStyle.rowHeight <= 40)
        #expect(FileStashSidebarStyle.emptyIconSize < 48)
        #expect(FileStashSidebarChromePolicy.contentTopInset > FileStashSidebarStyle.headerHeight)
    }

    @Test func headerHelpers_matchBalancedGlassGeometry() {
        #expect(FileStashSidebarChromePolicy.headerContainerHeight == 54)
        #expect(FileStashSidebarChromePolicy.closeButtonSize == 18)
    }

    @Test func paneChrome_helpers_lockBorderAndShadowGeometry() {
        #expect(FileStashSidebarChromePolicy.paneBorderWidth == 1)
        #expect(FileStashSidebarChromePolicy.paneShadowOffsetY == -2)
    }

    @Test func rowHover_keepsFillLighterThanHeaderGlass() {
        #expect(FileStashSidebarStyle.rowHoverFillAlpha < 0.12)
        #expect(FileStashSidebarStyle.rowCornerRadius == 10)
    }
}
