import AppKit
import Testing
@testable import SideStash

struct BottomBulkActionsStyleTests {
    @Test func emptyStashDisablesEveryAction() {
        for action in SideStashBulkAction.allCases {
            let availability = action.availability(
                hasItems: false,
                hasRestorableItems: false
            )

            #expect(!availability.isEnabled)
            #expect(availability.reasonKey == "bulk.unavailable.empty")
        }
    }

    @Test func populatedStashEnablesTrashAndMove() {
        #expect(
            SideStashBulkAction.trashAll.availability(
                hasItems: true,
                hasRestorableItems: false
            ) == .enabled
        )
        #expect(
            SideStashBulkAction.moveAllToCurrentFolder.availability(
                hasItems: true,
                hasRestorableItems: false
            ) == .enabled
        )
    }

    @Test func restoreRequiresAtLeastOneOriginalLocation() {
        #expect(
            SideStashBulkAction.restoreAll.availability(
                hasItems: true,
                hasRestorableItems: false
            ) == .disabled(reasonKey: "bulk.restore.unavailable")
        )
        #expect(
            SideStashBulkAction.restoreAll.availability(
                hasItems: true,
                hasRestorableItems: true
            ) == .enabled
        )
    }

    @Test func everyActionDefinesSymbolAndLocalizedPurpose() {
        #expect(SideStashBulkAction.allCases.count == 3)
        #expect(SideStashBulkAction.allCases.allSatisfy { !$0.symbolName.isEmpty })
        #expect(SideStashBulkAction.allCases.allSatisfy { !$0.titleKey.isEmpty })
        #expect(SideStashBulkAction.trashAll.titleKey == "bulk.trash.tooltip")
        #expect(SideStashBulkAction.moveAllToCurrentFolder.titleKey == "bulk.move_current.tooltip")
        #expect(SideStashBulkAction.restoreAll.titleKey == "bulk.restore.tooltip")
    }

    @Test func bottomActionsUseApprovedStableGeometry() {
        #expect(SideStashSidebarChromePolicy.bottomActionsHeight == 40)
        #expect(SideStashSidebarChromePolicy.bottomActionButtonWidth == 44)
        #expect(SideStashSidebarChromePolicy.bottomActionsOverlayHeight == 84)
        #expect(SideStashSidebarChromePolicy.bottomActionsTooltipGap == 8)
        #expect(SideStashSidebarChromePolicy.bottomActionsIconSize == 18)
        #expect(SideStashSidebarChromePolicy.bottomActionHoverScale == 1.04)
        #expect(SideStashSidebarChromePolicy.bottomActionPressedScale == 0.94)
        #expect(SideStashSidebarChromePolicy.bottomActionsDisabledIconOpacity == 0.28)
        #expect(SideStashSidebarChromePolicy.bottomActionsTooltipDelay == 0.35)
    }

    @Test func bottomActionsSymbolsExistOnCurrentMacOS() {
        for action in SideStashBulkAction.allCases {
            #expect(
                NSImage(
                    systemSymbolName: action.symbolName,
                    accessibilityDescription: nil
                ) != nil
            )
        }
    }
}
