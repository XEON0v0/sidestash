import AppKit
import Testing
@testable import SideStash

struct InteractionMotionTests {
    @Test func attachedRevealSequence_keepsHiddenPreviewAndTargetDistinct() {
        let sequence = AttachedPanelRevealSequence(
            hiddenRect: NSRect(x: 652, y: 220, width: 320, height: 540),
            previewRect: NSRect(x: 668, y: 220, width: 320, height: 540),
            targetRect: NSRect(x: 960, y: 220, width: 320, height: 540)
        )

        #expect(sequence.hiddenRect != sequence.previewRect)
        #expect(sequence.previewRect != sequence.targetRect)
    }

    @Test func attachedRevealSequence_usesSystemMotionDurationsByDefault() {
        let sequence = AttachedPanelRevealSequence(
            hiddenRect: .zero,
            previewRect: .zero,
            targetRect: .zero
        )

        #expect(sequence.hiddenToPreviewDuration == InteractionMotionStyle.attachedRevealFirstStageDuration)
        #expect(sequence.previewToTargetDuration == InteractionMotionStyle.attachedRevealSecondStageDuration)
    }

    @Test func dropZoneStyle_keepsFeedbackLightweight() {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = NSAppearance(named: name)!
            #expect(SideStashGlassPalette.dropTargetFill.resolved(for: appearance).alphaComponent < 0.2)
        }
        #expect(InteractionMotionStyle.dropZoneHighlightDuration > 0)
    }

    @Test func dragStyle_keepsRowsSubtleWhileDragging() {
        #expect(InteractionMotionStyle.dragLiftScale > 0.9)
        #expect(InteractionMotionStyle.dragLiftScale < 1.0)
        #expect(InteractionMotionStyle.dragLiftAlpha < 1.0)
        #expect(InteractionMotionStyle.dragLiftDuration > 0)
    }

    @Test func motionConstants_keepSystemLevelMotionSubtle() {
        #expect(InteractionMotionStyle.attachedPeekInset < InteractionMotionStyle.attachedPreviewInset)
        #expect(InteractionMotionStyle.dragLiftScale < 1.0)
        #expect(InteractionMotionStyle.dragLiftAlpha < 1.0)
    }
}
