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

    @Test func bottomActions_defineHoverTitlesForEveryAction() {
        #expect(SideStashBulkAction.allCases.count == 3)
        #expect(SideStashBulkAction.trashAll.titleKey == "bulk.trash.tooltip")
        #expect(SideStashBulkAction.moveAllToCurrentFolder.titleKey == "bulk.move_current.tooltip")
        #expect(SideStashBulkAction.restoreAll.titleKey == "bulk.restore.tooltip")
        #expect(SideStashBulkAction.allCases.allSatisfy { !$0.titleKey.isEmpty })
        #expect(SideStashSidebarChromePolicy.bottomActionHoverTitleYOffset > SideStashSidebarChromePolicy.bottomActionsHeight)
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

    @Test func bottomActions_darkModeUsesFinderToolbarContrast() {
        let light = SideStashSidebarStyle.bottomActionsAppearance(for: .light)
        let dark = SideStashSidebarStyle.bottomActionsAppearance(for: .dark)

        #expect(light.overlayBase == .white)
        #expect(dark.overlayBase == .black)
        #expect(dark.overlayAlpha < light.overlayAlpha)
        #expect(dark.overlayAlpha >= 0.18)
        #expect(dark.highlightStrokeAlpha < light.highlightStrokeAlpha)
        #expect(dark.borderAlpha > light.borderAlpha)
        #expect(dark.shadowOpacity <= light.shadowOpacity)
        #expect(dark.iconOpacity >= 0.72)
        #expect(dark.disabledIconOpacity < dark.iconOpacity)
    }
}
