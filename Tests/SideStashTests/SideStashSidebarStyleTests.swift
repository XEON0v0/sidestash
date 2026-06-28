import AppKit
import Testing
@testable import SideStash

struct SideStashSidebarStyleTests {
    @Test func paneChrome_matchesFinderFamilyRanges() {
        #expect(SideStashSidebarStyle.paneCornerRadius >= 18)
        #expect(SideStashSidebarStyle.paneCornerRadius <= 20)
        #expect(SideStashSidebarStyle.paneShadowBlur < 24)
        #expect(SideStashSidebarStyle.paneBorderAlpha < 0.14)
    }

    @Test func balancedGlassHeader_staysLighterThanPaneChrome() {
        #expect(SideStashSidebarStyle.headerHeight < 40)
        #expect(SideStashSidebarStyle.headerCornerRadius < SideStashSidebarStyle.paneCornerRadius)
        #expect(SideStashSidebarStyle.headerShadowOpacity < 0.12)
        #expect(SideStashSidebarStyle.headerBackgroundAlpha > SideStashSidebarStyle.paneFillAlpha)
    }

    @Test func contentMetrics_keepFinderLikeDensity() {
        #expect(SideStashSidebarStyle.rowHeight >= 38)
        #expect(SideStashSidebarStyle.rowHeight <= 40)
        #expect(SideStashSidebarStyle.emptyIconSize < 48)
        #expect(SideStashSidebarChromePolicy.contentTopInset > SideStashSidebarStyle.headerHeight)
    }

    @Test func headerHelpers_matchBalancedGlassGeometry() {
        #expect(SideStashSidebarChromePolicy.headerContainerHeight == 54)
        #expect(SideStashSidebarChromePolicy.closeButtonSize == 18)
    }

    @Test func paneChrome_helpers_lockBorderAndShadowGeometry() {
        #expect(SideStashSidebarChromePolicy.paneBorderWidth == 1)
        #expect(SideStashSidebarChromePolicy.paneShadowOffsetY == -2)
    }

    @Test func paneChrome_prefersSystemPanelShadowForOuterDepth() {
        #expect(SideStashSidebarChromePolicy.usesSystemPanelShadow)
    }

    @Test func rowHover_keepsFillLighterThanHeaderGlass() {
        #expect(SideStashSidebarStyle.rowHoverFillAlpha < 0.12)
        #expect(SideStashSidebarStyle.rowCornerRadius == 10)
    }
}
