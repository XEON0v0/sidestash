import AppKit
import Testing
@testable import SideStash

struct BottomBulkActionsStyleTests {
    @Test func bottomActions_useFinderToolbarCapsuleGeometry() {
        #expect(SideStashSidebarChromePolicy.bottomActionsHeight >= 36)
        #expect(SideStashSidebarChromePolicy.bottomActionsHeight <= 38)
        #expect(abs(SideStashSidebarChromePolicy.bottomActionsCornerRadius - SideStashSidebarChromePolicy.bottomActionsHeight / 2) < 0.001)
        #expect(SideStashSidebarChromePolicy.bottomActionButtonWidth >= 44)
        #expect(SideStashSidebarChromePolicy.bottomActionButtonWidth <= 48)
    }

    @Test func bottomActions_useSFSymbolNames() {
        #expect(SideStashSidebarChromePolicy.trashAllSymbolName == "trash")
        #expect(SideStashSidebarChromePolicy.moveAllToCurrentFolderSymbolName == "folder.badge.plus")
        #expect(!SideStashSidebarChromePolicy.restoreAllSymbolName.isEmpty)
    }

    @Test func bottomActions_symbolsExistOnCurrentMacOS() {
        #expect(NSImage(systemSymbolName: SideStashSidebarChromePolicy.trashAllSymbolName, accessibilityDescription: nil) != nil)
        #expect(NSImage(systemSymbolName: SideStashSidebarChromePolicy.moveAllToCurrentFolderSymbolName, accessibilityDescription: nil) != nil)
        #expect(NSImage(systemSymbolName: SideStashSidebarChromePolicy.restoreAllSymbolName, accessibilityDescription: nil) != nil)
    }

    @Test func bottomActions_keepFinderLikeSubtleOpacity() {
        #expect(SideStashSidebarChromePolicy.bottomActionsBackgroundAlpha < 0.75)
        #expect(SideStashSidebarChromePolicy.bottomActionsBorderAlpha < 0.1)
        #expect(SideStashSidebarChromePolicy.bottomActionsDisabledIconOpacity < SideStashSidebarChromePolicy.bottomActionsIconOpacity)
    }
}
