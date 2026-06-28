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
}
