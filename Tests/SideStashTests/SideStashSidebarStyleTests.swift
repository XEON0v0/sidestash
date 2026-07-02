import AppKit
import Testing
@testable import SideStash

struct SideStashSidebarStyleTests {
    @Test func paneChrome_matchesFinderFamilyRanges() {
        #expect(SideStashSidebarStyle.paneCornerRadius >= 18)
        #expect(SideStashSidebarStyle.paneCornerRadius <= 20)
        #expect(SideStashSidebarStyle.sidebarPlateInset == 5)
        #expect(SideStashSidebarStyle.sidebarPlateCornerRadius >= 16)
        #expect(SideStashSidebarStyle.sidebarPlateCornerRadius < SideStashSidebarStyle.paneCornerRadius)
        #expect(SideStashSidebarStyle.paneShadowBlur < 24)
        #expect(SideStashSidebarStyle.paneBorderAlpha < 0.14)
    }

    @Test func balancedGlassHeader_staysLighterThanPaneChrome() {
        #expect(SideStashSidebarStyle.headerHeight < 40)
        #expect(SideStashSidebarStyle.headerCornerRadius < SideStashSidebarStyle.paneCornerRadius)
        #expect(SideStashSidebarStyle.headerShadowOpacity == 0)
        #expect(SideStashSidebarStyle.headerBackgroundAlpha == 0)
    }

    @Test func headerGlass_usesFinderSidebarMaterial() {
        #expect(SideStashSidebarChromePolicy.headerMaterial == .sidebar)
        #expect(SideStashSidebarChromePolicy.headerBlendingMode == .behindWindow)
        #expect(!SideStashSidebarChromePolicy.isHeaderMaterialEmphasized)
    }

    @Test func headerAppearance_usesFinderSourceListRowOverlay() {
        let light = SideStashSidebarStyle.headerAppearance(for: .light)
        let dark = SideStashSidebarStyle.headerAppearance(for: .dark)

        #expect(light.overlayBase == .black)
        #expect(dark.overlayBase == .white)
        #expect(light.overlayAlpha == 0)
        #expect(dark.overlayAlpha == 0)
        #expect(light.textOpacity <= 0.92)
        #expect(dark.textOpacity <= 0.9)
    }

    @Test func headerMaterial_readsAsFinderSidebarContinuation() {
        let light = SideStashSidebarStyle.headerAppearance(for: .light)
        let dark = SideStashSidebarStyle.headerAppearance(for: .dark)

        #expect(light.overlayAlpha == SideStashSidebarStyle.headerBackgroundAlpha)
        #expect(dark.overlayAlpha == SideStashSidebarStyle.headerBackgroundAlpha)
        #expect(SideStashSidebarChromePolicy.headerHighlightStrokeAlpha == 0)
        #expect(SideStashSidebarChromePolicy.headerSubtleBorderAlpha == 0)
        #expect(SideStashSidebarChromePolicy.headerShadowRadius == 0)
        #expect(SideStashSidebarChromePolicy.headerShadowYOffset == 0)
    }

    @Test func paneAppearance_matchesFinderBackplateTint() {
        let lightPane = SideStashSidebarStyle.paneAppearance(for: .light)
        let darkPane = SideStashSidebarStyle.paneAppearance(for: .dark)
        let lightHeader = SideStashSidebarStyle.headerAppearance(for: .light)
        let darkHeader = SideStashSidebarStyle.headerAppearance(for: .dark)

        #expect(lightHeader.overlayAlpha == 0)
        #expect(darkHeader.overlayAlpha == 0)
        #expect(lightPane.contentBackgroundAlpha >= 0.37)
        #expect(lightPane.contentBackgroundAlpha <= 0.43)
        #expect(darkPane.contentBackgroundAlpha >= 0.14)
        #expect(darkPane.contentBackgroundAlpha <= 0.22)
    }

    @Test func contentMetrics_keepFinderLikeDensity() {
        #expect(SideStashSidebarStyle.rowHeight >= 38)
        #expect(SideStashSidebarStyle.rowHeight <= 40)
        #expect(SideStashSidebarStyle.emptyIconSize < 48)
        #expect(SideStashSidebarChromePolicy.contentTopInset > SideStashSidebarStyle.headerHeight)
    }

    @Test func headerHelpers_matchBalancedGlassGeometry() {
        #expect(SideStashSidebarChromePolicy.headerContainerHeight == 58)
        #expect(SideStashSidebarChromePolicy.closeButtonSize == 12)
        #expect(SideStashSidebarChromePolicy.closeButtonHoverSize == 18)
    }

    @Test func headerLayout_keepsTrafficLightLeftAndTitleCentered() {
        #expect(SideStashSidebarChromePolicy.closeButtonLeadingInset == 12)
        #expect(SideStashSidebarChromePolicy.headerTitleReservedSideWidth >= 36)
        #expect(SideStashSidebarChromePolicy.headerTitleReservedSideWidth == SideStashSidebarChromePolicy.closeButtonLeadingInset + SideStashSidebarChromePolicy.closeButtonHoverSize + 8)
    }

    @Test func closeButton_usesSampledLowSaturationFinderRed() throws {
        let color = try #require(SideStashSidebarChromePolicy.closeButtonFill.usingColorSpace(.sRGB))

        #expect(color.redComponent >= 0.91)
        #expect(color.redComponent <= 0.94)
        #expect(color.greenComponent >= 0.39)
        #expect(color.greenComponent <= 0.42)
        #expect(color.blueComponent >= 0.38)
        #expect(color.blueComponent <= 0.41)
        #expect(SideStashSidebarChromePolicy.closeButtonBorderAlpha < 0.3)
    }

    @Test func paneChrome_helpers_lockBorderAndShadowGeometry() {
        #expect(SideStashSidebarChromePolicy.paneBorderWidth == 1)
        #expect(SideStashSidebarChromePolicy.outerPaneFillAlpha < 0.2)
        #expect(SideStashSidebarChromePolicy.sidebarPlateHighlightStrokeAlpha >= 0.5)
        #expect(SideStashSidebarChromePolicy.sidebarPlateSubtleBorderAlpha <= 0.05)
        #expect(SideStashSidebarChromePolicy.sidebarPlateShadowOpacity < 0.1)
        #expect(SideStashSidebarChromePolicy.sidebarPlateShadowRadius >= 16)
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
