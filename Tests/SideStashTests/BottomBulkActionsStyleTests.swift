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

    @Test func unavailableReasonsAreLocalizedInSupportedLanguages() throws {
        let reasonKeys = ["bulk.unavailable.empty", "bulk.restore.unavailable"]
        let localizationNames = ["en", "zh-hans"]

        for localizationName in localizationNames {
            let localizationURL = try #require(Bundle.module.url(
                forResource: localizationName,
                withExtension: "lproj"
            ))
            let localizationBundle = try #require(Bundle(url: localizationURL))

            for reasonKey in reasonKeys {
                #expect(localizationBundle.localizedString(
                    forKey: reasonKey,
                    value: nil,
                    table: nil
                ) != reasonKey)
            }
        }
    }

    @Test func horizontalPointerPositionMapsToTheCorrectAction() {
        let buttonWidth = SideStashSidebarChromePolicy.bottomActionButtonWidth

        #expect(BottomActionInteractionState.action(
            at: -1,
            buttonWidth: buttonWidth
        ) == nil)
        #expect(BottomActionInteractionState.action(
            at: 0,
            buttonWidth: buttonWidth
        ) == .trashAll)
        #expect(BottomActionInteractionState.action(
            at: buttonWidth,
            buttonWidth: buttonWidth
        ) == .moveAllToCurrentFolder)
        #expect(BottomActionInteractionState.action(
            at: buttonWidth * 2,
            buttonWidth: buttonWidth
        ) == .restoreAll)
        #expect(BottomActionInteractionState.action(
            at: buttonWidth * 3,
            buttonWidth: buttonWidth
        ) == nil)
    }
}
