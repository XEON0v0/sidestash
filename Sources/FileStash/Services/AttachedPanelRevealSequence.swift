import Foundation

struct AttachedPanelRevealSequence: Equatable {
    let hiddenRect: NSRect
    let previewRect: NSRect
    let targetRect: NSRect
    let hiddenToPreviewDuration: TimeInterval
    let previewToTargetDuration: TimeInterval

    init(
        hiddenRect: NSRect,
        previewRect: NSRect,
        targetRect: NSRect,
        hiddenToPreviewDuration: TimeInterval = InteractionMotionStyle.attachedRevealFirstStageDuration,
        previewToTargetDuration: TimeInterval = InteractionMotionStyle.attachedRevealSecondStageDuration
    ) {
        self.hiddenRect = hiddenRect
        self.previewRect = previewRect
        self.targetRect = targetRect
        self.hiddenToPreviewDuration = hiddenToPreviewDuration
        self.previewToTargetDuration = previewToTargetDuration
    }

    init(placement: PanelPlacement) {
        self.init(
            hiddenRect: placement.hiddenRect,
            previewRect: placement.previewRect,
            targetRect: placement.targetRect
        )
    }
}
