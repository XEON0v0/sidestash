import AppKit

@MainActor
final class PanelAnimator {
    static let shared = PanelAnimator()
    private(set) var isAnimating = false
    private init() {}

    func animatePanelIn(
        panel: NSPanel,
        from startRect: NSRect,
        to targetRect: NSRect,
        completion: @escaping () -> Void = {}
    ) {
        let sequence = AttachedPanelRevealSequence(
            hiddenRect: startRect,
            previewRect: targetRect,
            targetRect: targetRect,
            hiddenToPreviewDuration: 0.12,
            previewToTargetDuration: 0.0
        )
        animatePanelIn(panel: panel, sequence: sequence, completion: completion)
    }

    func animatePanelIn(
        panel: NSPanel,
        sequence: AttachedPanelRevealSequence,
        completion: @escaping () -> Void = {}
    ) {
        guard !isAnimating else { return }
        isAnimating = true

        panel.alphaValue = 0.92
        panel.setFrame(sequence.hiddenRect, display: false)
        panel.orderFront(nil)

        animateStage(
            panel: panel,
            targetRect: sequence.previewRect,
            duration: sequence.hiddenToPreviewDuration,
            timingFunction: .easeOut,
            alpha: 0.96
        ) { [weak self] in
            guard let self else { return }
            self.animateStage(
                panel: panel,
                targetRect: sequence.targetRect,
                duration: sequence.previewToTargetDuration,
                timingFunction: .easeInEaseOut,
                alpha: 1.0
            ) {
                MainActor.assumeIsolated {
                    self.isAnimating = false
                }
                completion()
            }
        }
    }

    func animatePanelOut(
        panel: NSPanel,
        to endRect: NSRect,
        completion: @escaping () -> Void = {}
    ) {
        guard !isAnimating else { return }
        isAnimating = true

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.88
            panel.animator().setFrame(endRect, display: true)
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1.0
            MainActor.assumeIsolated {
                self?.isAnimating = false
            }
            completion()
        })
    }

    private func animateStage(
        panel: NSPanel,
        targetRect: NSRect,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunctionName,
        alpha: CGFloat,
        completion: @escaping () -> Void
    ) {
        guard duration > 0 else {
            panel.setFrame(targetRect, display: true)
            panel.alphaValue = alpha
            completion()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timingFunction)
            panel.animator().alphaValue = alpha
            panel.animator().setFrame(targetRect, display: true)
        }, completionHandler: completion)
    }
}
