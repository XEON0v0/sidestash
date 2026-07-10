import AppKit
import Testing
@testable import SideStash

struct BottomBulkActionsStyleTests {
    @Test func availabilityMatrixCoversEmptyAndPopulatedStates() {
        typealias AvailabilityCase = (
            action: SideStashBulkAction,
            hasItems: Bool,
            hasRestorableItems: Bool,
            expected: SideStashBottomActionAvailability,
            expectedIsEnabled: Bool,
            expectedReasonKey: String?
        )

        let emptyCases: [AvailabilityCase] = SideStashBulkAction.allCases.flatMap { action in
            [false, true].map { hasRestorableItems in
                (
                    action: action,
                    hasItems: false,
                    hasRestorableItems: hasRestorableItems,
                    expected: .disabled(reasonKey: "bulk.unavailable.empty"),
                    expectedIsEnabled: false,
                    expectedReasonKey: "bulk.unavailable.empty"
                )
            }
        }
        let populatedCases: [AvailabilityCase] = [
            (.trashAll, true, false, .enabled, true, nil),
            (.moveAllToCurrentFolder, true, false, .enabled, true, nil),
            (
                .restoreAll,
                true,
                false,
                .disabled(reasonKey: "bulk.restore.unavailable"),
                false,
                "bulk.restore.unavailable"
            ),
            (.restoreAll, true, true, .enabled, true, nil),
        ]

        for testCase in emptyCases + populatedCases {
            let availability = testCase.action.availability(
                hasItems: testCase.hasItems,
                hasRestorableItems: testCase.hasRestorableItems
            )

            #expect(availability == testCase.expected)
            #expect(availability.isEnabled == testCase.expectedIsEnabled)
            #expect(availability.reasonKey == testCase.expectedReasonKey)
        }
    }

    @Test func everyActionDefinesSymbolAndLocalizedPurpose() {
        #expect(SideStashBulkAction.allCases.count == 3)
        #expect(SideStashBulkAction.allCases.allSatisfy { !$0.symbolName.isEmpty })
        #expect(SideStashBulkAction.allCases.allSatisfy { !$0.titleKey.isEmpty })
        #expect(SideStashBulkAction.trashAll.symbolName == "trash")
        #expect(SideStashBulkAction.moveAllToCurrentFolder.symbolName == "folder.badge.plus")
        #expect(SideStashBulkAction.restoreAll.symbolName == "arrow.uturn.backward")
        #expect(SideStashBulkAction.trashAll.titleKey == "bulk.trash.tooltip")
        #expect(SideStashBulkAction.moveAllToCurrentFolder.titleKey == "bulk.move_current.tooltip")
        #expect(SideStashBulkAction.restoreAll.titleKey == "bulk.restore.tooltip")
    }

    @Test func bottomActionsUseApprovedStableGeometry() {
        #expect(SideStashSidebarChromePolicy.bottomActionsHeight == 40)
        #expect(SideStashSidebarChromePolicy.bottomActionButtonWidth == 44)
        #expect(SideStashSidebarChromePolicy.bottomActionsOverlayHeight == 84)
        #expect(SideStashSidebarChromePolicy.bottomActionsBottomInset == 16)
        #expect(SideStashSidebarChromePolicy.bottomActionsTooltipGap == 8)
        #expect(SideStashSidebarChromePolicy.bottomActionsIconSize == 18)
        #expect(SideStashSidebarChromePolicy.bottomActionHoverScale == 1.04)
        #expect(SideStashSidebarChromePolicy.bottomActionPressedScale == 0.94)
        #expect(SideStashSidebarChromePolicy.bottomActionsEnabledIconOpacity == 0.88)
        #expect(SideStashSidebarChromePolicy.bottomActionsDisabledIconOpacity == 0.28)
        #expect(SideStashSidebarChromePolicy.bottomActionsTooltipMaxWidth == 240)
        #expect(SideStashSidebarChromePolicy.bottomActionsTooltipCornerRadius == 8)
        #expect(SideStashSidebarChromePolicy.bottomActionsTooltipDelay == 0.35)
    }

    @Test func legacyBottomActionsKeepCapsuleAndHoverGeometry() {
        #expect(
            SideStashSidebarChromePolicy.bottomActionsCornerRadius
                == SideStashSidebarChromePolicy.bottomActionsHeight / 2
        )
        #expect(
            SideStashSidebarChromePolicy.bottomActionHoverTitleYOffset
                > SideStashSidebarChromePolicy.bottomActionsHeight
        )
    }

    @Test func legacyBottomActionsKeepSubtleOpacity() {
        #expect(SideStashSidebarChromePolicy.bottomActionsBackgroundAlpha < 0.75)
        #expect(SideStashSidebarChromePolicy.bottomActionsBorderAlpha < 0.1)
        #expect(
            SideStashSidebarChromePolicy.bottomActionsDisabledIconOpacity
                < SideStashSidebarChromePolicy.bottomActionsIconOpacity
        )
    }

    @Test func legacyBottomActionsPreserveLightDarkContrast() {
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

    @Test func firstHoverSchedulesTooltipWithoutDisplayingIt() {
        var state = BottomActionInteractionState()

        let needsDelay = state.enter(.trashAll)

        #expect(needsDelay)
        #expect(state.hoveredAction == .trashAll)
        #expect(state.tooltipAction == nil)
    }

    @Test func revealOnlyDisplaysTheStillHoveredAction() {
        var state = BottomActionInteractionState()
        _ = state.enter(.trashAll)
        _ = state.enter(.moveAllToCurrentFolder)

        state.reveal(.trashAll)
        #expect(state.tooltipAction == nil)

        state.reveal(.moveAllToCurrentFolder)
        #expect(state.tooltipAction == .moveAllToCurrentFolder)
    }

    @Test func movingBetweenActionsUpdatesAVisibleTooltipImmediately() {
        var state = BottomActionInteractionState()
        _ = state.enter(.trashAll)
        state.reveal(.trashAll)

        let needsDelay = state.enter(.restoreAll)

        #expect(!needsDelay)
        #expect(state.hoveredAction == .restoreAll)
        #expect(state.tooltipAction == .restoreAll)
    }

    @Test func leavingToolbarClearsHoverAndTooltip() {
        var state = BottomActionInteractionState()
        _ = state.enter(.trashAll)
        state.reveal(.trashAll)

        state.leaveToolbar()

        #expect(state.hoveredAction == nil)
        #expect(state.tooltipAction == nil)
    }
}
