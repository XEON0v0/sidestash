import AppKit
import Testing
@testable import FileStash

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
        #expect(InteractionMotionStyle.dropZoneActiveFillAlpha < 0.2)
        #expect(InteractionMotionStyle.dropZoneActiveStrokeAlpha < 0.3)
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
        #expect(InteractionMotionStyle.dropZoneActiveFillAlpha < 0.2)
        #expect(InteractionMotionStyle.dragLiftScale < 1.0)
        #expect(InteractionMotionStyle.dragLiftAlpha < 1.0)
    }
}
