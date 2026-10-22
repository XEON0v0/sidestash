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

    @Test func headerLayout_keepsTrafficLightLeftAndTitleCentered() {
        #expect(SideStashSidebarChromePolicy.closeButtonLeadingInset == 12)
        #expect(SideStashSidebarChromePolicy.headerTitleReservedSideWidth >= 36)
        #expect(SideStashSidebarChromePolicy.headerTitleReservedSideWidth == SideStashSidebarChromePolicy.closeButtonLeadingInset + SideStashSidebarChromePolicy.closeButtonSlotWidth + 8)
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
