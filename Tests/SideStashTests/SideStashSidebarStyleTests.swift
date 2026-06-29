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

    @Test func headerGlass_usesFinderSidebarMaterial() {
        #expect(SideStashSidebarChromePolicy.headerMaterial == .sidebar)
        #expect(SideStashSidebarChromePolicy.headerBlendingMode == .behindWindow)
        #expect(!SideStashSidebarChromePolicy.isHeaderMaterialEmphasized)
    }

    @Test func headerAppearance_usesMilkyPlateOverlay() {
        let light = SideStashSidebarStyle.headerAppearance(for: .light)
        let dark = SideStashSidebarStyle.headerAppearance(for: .dark)

        #expect(light.overlayBase == .white)
        #expect(dark.overlayBase == .white)
        #expect(dark.overlayAlpha < light.overlayAlpha)
        #expect(light.overlayAlpha >= 0.34)
        #expect(light.overlayAlpha <= 0.44)
        #expect(dark.overlayAlpha >= 0.18)
        #expect(dark.overlayAlpha <= 0.28)
        #expect(dark.textOpacity <= light.textOpacity)
    }

    @Test func headerMaterial_readsAsPlateOverBackground() {
        let light = SideStashSidebarStyle.headerAppearance(for: .light)
        let dark = SideStashSidebarStyle.headerAppearance(for: .dark)

        #expect(light.overlayAlpha > SideStashSidebarStyle.headerBackgroundAlpha / 2)
        #expect(dark.overlayAlpha > 0.16)
        #expect(SideStashSidebarChromePolicy.headerHighlightStrokeAlpha >= 0.55)
        #expect(SideStashSidebarChromePolicy.headerSubtleBorderAlpha <= 0.025)
        #expect(SideStashSidebarChromePolicy.headerShadowRadius >= 18)
        #expect(SideStashSidebarChromePolicy.headerShadowYOffset >= 8)
    }

    @Test func paneAppearance_keepsContentMoreOpaqueThanFloatingHeader() {
        let lightPane = SideStashSidebarStyle.paneAppearance(for: .light)
        let darkPane = SideStashSidebarStyle.paneAppearance(for: .dark)
        let lightHeader = SideStashSidebarStyle.headerAppearance(for: .light)
        let darkHeader = SideStashSidebarStyle.headerAppearance(for: .dark)

        #expect(lightPane.contentBackgroundAlpha > lightHeader.overlayAlpha)
        #expect(darkPane.contentBackgroundAlpha > darkHeader.overlayAlpha)
        #expect(lightPane.contentBackgroundAlpha >= 0.92)
        #expect(darkPane.contentBackgroundAlpha >= 0.92)
        #expect(darkHeader.overlayAlpha < lightHeader.overlayAlpha)
    }

    @Test func contentMetrics_keepFinderLikeDensity() {
        #expect(SideStashSidebarStyle.rowHeight >= 38)
        #expect(SideStashSidebarStyle.rowHeight <= 40)
        #expect(SideStashSidebarStyle.emptyIconSize < 48)
        #expect(SideStashSidebarChromePolicy.contentTopInset > SideStashSidebarStyle.headerHeight)
    }

    @Test func headerHelpers_matchBalancedGlassGeometry() {
        #expect(SideStashSidebarChromePolicy.headerContainerHeight == 54)
        #expect(SideStashSidebarChromePolicy.closeButtonSize == 14)
        #expect(SideStashSidebarChromePolicy.closeButtonHoverSize == 18)
    }

    @Test func headerLayout_keepsTrafficLightLeftAndTitleCentered() {
        #expect(SideStashSidebarChromePolicy.closeButtonLeadingInset == 12)
        #expect(SideStashSidebarChromePolicy.headerTitleReservedSideWidth >= 36)
        #expect(SideStashSidebarChromePolicy.headerTitleReservedSideWidth == SideStashSidebarChromePolicy.closeButtonLeadingInset + SideStashSidebarChromePolicy.closeButtonHoverSize + 8)
    }

    @Test func closeButton_usesMacOSTrafficLightRed() {
        #expect(SideStashSidebarChromePolicy.closeButtonFill == NSColor.systemRed)
        #expect(SideStashSidebarChromePolicy.closeButtonBorderAlpha < 0.3)
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
