import AppKit
import Testing
@testable import SideStash

struct SideStashSidebarStyleTests {
    @Test func liquidGlassPane_usesTahoeCornerRadius() {
        #expect(SideStashSidebarStyle.paneCornerRadius == 24)
    }

    @Test func header_keepsCompactGeometry() {
        #expect(SideStashSidebarStyle.headerHeight == 32)
        #expect(SideStashSidebarStyle.headerTopInset == 16)
        #expect(SideStashSidebarStyle.headerHorizontalInset == 12)
        #expect(SideStashSidebarChromePolicy.headerContainerHeight == 58)
        #expect(
            SideStashSidebarChromePolicy.headerContainerHeight
                >= SideStashSidebarStyle.headerTopInset + SideStashSidebarStyle.headerHeight
        )
        #expect(SideStashSidebarChromePolicy.closeButtonSlotWidth == 18)
    }

    @Test func headerLayout_keepsTrafficLightLeftAndMoreActionsPillRight() {
        #expect(SideStashSidebarChromePolicy.closeButtonLeadingInset == 12)
        #expect(SideStashSidebarChromePolicy.moreActionsHeight < SideStashSidebarStyle.headerHeight)
        #expect(SideStashSidebarChromePolicy.moreActionsDividerHeight < SideStashSidebarChromePolicy.moreActionsHeight)
        #expect(SideStashSidebarChromePolicy.moreActionsDividerWidth <= 1)
        // Close button, pill and the gap between them fit the panel's 320 pt width.
        let headerWidth: CGFloat = 320 - SideStashSidebarStyle.headerHorizontalInset * 2
        let reserved = SideStashSidebarChromePolicy.closeButtonLeadingInset
            + SideStashSidebarChromePolicy.closeButtonSlotWidth
            + SideStashSidebarChromePolicy.moreActionsLeadingMaxWidth
            + SideStashSidebarChromePolicy.moreActionsDividerWidth
            + SideStashSidebarChromePolicy.moreActionsMenuSegmentWidth
            + SideStashSidebarChromePolicy.moreActionsTrailingInset
        #expect(reserved < headerWidth)
    }

    @Test func panelDepth_usesOnlyTheSystemPanelShadow() {
        #expect(SideStashSidebarChromePolicy.usesSystemPanelShadow)
    }

    @Test func fileRows_sitOnConcentricGlassPlates() {
        #expect(SideStashSidebarStyle.rowHeight == 44)
        #expect(SideStashSidebarStyle.rowSpacing == 6)
        #expect(SideStashSidebarStyle.fileListInset == 12)
        #expect(
            SideStashSidebarStyle.rowCornerRadius
                == SideStashSidebarStyle.paneCornerRadius - SideStashSidebarStyle.fileListInset
        )
        #expect(SideStashSidebarStyle.emptyIconSize == 44)
    }
}
