import AppKit
import Combine
import OSLog
import SwiftUI

enum AttachedPanelLifecycleDecision: Equatable {
    case close
    case ignore
    case update(FinderWindowSnapshot)
}

enum AttachedPanelKeyboardDecision: Equatable {
    case close
    case ignore
}

enum AttachedPanelChromePolicy {
    static func isEdgePreviewVisible(isFinderAttached: Bool, isRevealAnimating: Bool) -> Bool {
        isFinderAttached && isRevealAnimating
    }
}

enum AttachedPanelInteractionPolicy {
    static func enableHoverTracking(on panel: NSPanel) {
        panel.acceptsMouseMovedEvents = true
    }
}

enum AttachedPanelLifecyclePolicy {
    static func decision(
        isFinderAttached: Bool,
        trackedSnapshot: FinderWindowSnapshot?,
        latestSnapshot: FinderWindowSnapshot?,
        isContentModalPresented: Bool = false
    ) -> AttachedPanelLifecycleDecision {
        guard isFinderAttached else { return .ignore }
        guard !isContentModalPresented else { return .ignore }
        guard let trackedSnapshot else { return .ignore }
        guard let latestSnapshot else { return .close }

        if let trackedWindowID = trackedSnapshot.windowID,
           let latestWindowID = latestSnapshot.windowID,
           trackedWindowID != latestWindowID {
            return .close
        }

        if trackedSnapshot.windowID == nil,
           latestSnapshot.windowID == nil,
           trackedSnapshot.rect != latestSnapshot.rect {
            return .close
        }

        return .update(latestSnapshot)
    }

    static func keyboardDecision(for keyCode: UInt16) -> AttachedPanelKeyboardDecision {
        keyCode == 53 ? .close : .ignore
    }

    static func resetTrackingStateAfterManualClose(trackedSnapshot: FinderWindowSnapshot?) -> FinderWindowSnapshot? {
        nil
    }
}

@MainActor
class StashWindowManager {
    static let shared = StashWindowManager(store: StashStore())
    private let logger = Logger(subsystem: "app.sidestash.SideStash", category: "Windowing")
    private let store: StashStore
    /// Shared light for every glass rim in the panel.
    private let lightingScene = GlassLightingScene()
    private var panel: NSPanel?
    private var currentPlacement: PanelPlacement?
    private var attachedFinderWindowSnapshot: FinderWindowSnapshot?
    private var finderAttachmentObserver: AnyCancellable?
    private var finderFollowTimer: Timer?
    private var hostingView: NSHostingView<AnyView>?
    private var edgePreviewView: PanelEdgePreviewView?
    private var escapeKeyMonitor: Any?
    private var isAttachedRevealAnimating = false
    private var isContentModalPresented = false

    init(store: StashStore) {
        self.store = store
        observeFinderAttachment()
    }

    private enum Layout {
        static let panelWidth: CGFloat = 320
        static let panelHeight: CGFloat = 420
        static let panelOffset: CGFloat = 20
        static let finderRevealInset: CGFloat = InteractionMotionStyle.attachedPeekInset
        static let finderPreviewInset: CGFloat = InteractionMotionStyle.attachedPreviewInset
        static let fallbackHiddenTravel: CGFloat = 48
        static let statusItemGap: CGFloat = 10
        static let statusItemHiddenLift: CGFloat = 24
    }

    // MARK: - Show Panel (Menu Bar)

    func showPanel(near statusItemButton: NSStatusBarButton?) {
        ensurePanelCreated()
        refreshFinderAttachment(preferredRect: attachedFinderWindowSnapshot?.rect)
        let placement = resolvedPlacement(statusItemButton: statusItemButton)
        currentPlacement = placement
        captureFinderAttachmentIfNeeded(for: placement)
        panel?.setFrame(placement.targetRect, display: false)
        showAndRefresh(with: placement)
    }

    // MARK: - Show Panel (Drag Detected)

    func showPanel(near point: NSPoint) {
        ensurePanelCreated()
        refreshFinderAttachment(preferredRect: attachedFinderWindowSnapshot?.rect)
        let placement = resolvedPlacement(mousePoint: point)
        currentPlacement = placement
        captureFinderAttachmentIfNeeded(for: placement)
        panel?.setFrame(placement.targetRect, display: false)
        showAndRefresh(with: placement)
    }

    // MARK: - Hide Panel

    func hidePanel() {
        guard let panel = panel, panel.isVisible else { return }

        let exitRect = currentPlacement?.hiddenRect
            ?? panel.frame.offsetBy(dx: Layout.fallbackHiddenTravel, dy: 0)

        PanelAnimator.shared.animatePanelOut(panel: panel, to: exitRect) { [weak self] in
            self?.currentPlacement = nil
            self?.attachedFinderWindowSnapshot = AttachedPanelLifecyclePolicy.resetTrackingStateAfterManualClose(
                trackedSnapshot: self?.attachedFinderWindowSnapshot
            )
            self?.stopFinderFollow()
            self?.removeEscapeKeyMonitor()
            // No exit event arrives once the panel is gone.
            self?.lightingScene.pointerExited(animated: false)
            DragDetector.shared.startMonitoring()
        }
    }

    // MARK: - Toggle

    func togglePanel(near statusItemButton: NSStatusBarButton?) {
        if let panel = panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel(near: statusItemButton)
            store.refreshItems()
        }
    }

    // MARK: - Panel Origin

    var panelOrigin: NSPoint? {
        panel?.frame.origin
    }

    func setPanelOrigin(_ origin: NSPoint) {
        panel?.setFrameOrigin(origin)
    }

    // MARK: - Private: Panel Creation

    private func ensurePanelCreated() {
        guard panel == nil else { return }

        let panelRect = NSRect(x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight)

        let panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        AttachedPanelInteractionPolicy.enableHoverTracking(on: panel)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.hasShadow = SideStashSidebarChromePolicy.usesSystemPanelShadow
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let hostingView = NSHostingView(rootView: makeContentView(height: panelRect.height))

        // The drop zone clips everything to the panel's rounded shape and is
        // hosted through the glass view's contentView, the only placement
        // NSGlassEffectView guarantees to render inside the glass.
        let dropZone = DropZoneNSView(frame: panelRect)
        dropZone.store = store
        dropZone.onPointerMoved = { [weak self] point in
            guard let self else { return }
            if let point {
                self.lightingScene.pointerMoved(to: point)
            } else {
                self.lightingScene.pointerExited()
            }
        }
        dropZone.autoresizingMask = [.width, .height]

        hostingView.frame = dropZone.bounds
        hostingView.autoresizingMask = [.width, .height]
        dropZone.addSubview(hostingView)
        // The SwiftUI root fills the hosting view, so its coordinates are the
        // lighting scene's (the drop zone reports the pointer the same way).
        lightingScene.coordinateRoot = hostingView

        let edgePreviewView = PanelEdgePreviewView(frame: dropZone.bounds)
        edgePreviewView.autoresizingMask = [.width, .height]
        edgePreviewView.isHidden = true
        dropZone.addSubview(edgePreviewView)

        panel.contentView = StashPanelSurfaceFactory.make(frame: panelRect, contentView: dropZone)
        self.panel = panel
        self.hostingView = hostingView
        self.edgePreviewView = edgePreviewView
        installEscapeKeyMonitorIfNeeded()
    }

    // MARK: - Private: Positioning

    private func resolvedPlacement(statusItemButton: NSStatusBarButton?) -> PanelPlacement {
        let panelSize = NSSize(width: Layout.panelWidth, height: Layout.panelHeight)

        if let finderRect = FinderWindowTracker.shared.activeFinderWindowRect,
           let screen = screenContaining(finderRect) {
            let placement = PanelPlacement.attachedToFinder(
                finderRect: finderRect,
                panelSize: panelSize,
                visibleFrame: screen.visibleFrame,
                offset: Layout.panelOffset,
                revealInset: Layout.finderRevealInset,
                previewInset: Layout.finderPreviewInset
            )
            logPlacement(source: "statusItem", placement: placement, finderRect: finderRect)
            return placement
        }

        if let button = statusItemButton {
            let buttonRect = button.window?.convertToScreen(button.frame) ?? NSRect(x: 300, y: 300, width: 0, height: 0)
            let targetRect = NSRect(
                x: buttonRect.midX - (Layout.panelWidth / 2),
                y: buttonRect.minY - Layout.panelHeight - Layout.statusItemGap,
                width: Layout.panelWidth,
                height: Layout.panelHeight
            )
            let hiddenRect = targetRect.offsetBy(dx: 0, dy: Layout.statusItemHiddenLift)
            let placement = PanelPlacement(
                isFinderAttached: false,
                edge: .right,
                targetRect: targetRect,
                previewRect: targetRect,
                hiddenRect: hiddenRect
            )
            logPlacement(source: "statusItemFallback", placement: placement, finderRect: nil)
            return placement
        }

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetRect = NSRect(
            x: screen.midX - (Layout.panelWidth / 2),
            y: screen.midY - (Layout.panelHeight / 2),
            width: Layout.panelWidth,
            height: Layout.panelHeight
        )
        let hiddenRect = targetRect.offsetBy(dx: 0, dy: Layout.statusItemHiddenLift)
        let placement = PanelPlacement(
            isFinderAttached: false,
            edge: .right,
            targetRect: targetRect,
            previewRect: targetRect,
            hiddenRect: hiddenRect
        )
        logPlacement(source: "statusItemCenterFallback", placement: placement, finderRect: nil)
        return placement
    }

    private func resolvedPlacement(mousePoint: NSPoint) -> PanelPlacement {
        let panelSize = NSSize(width: Layout.panelWidth, height: Layout.panelHeight)

        if let finderRect = FinderWindowTracker.shared.activeFinderWindowRect,
           let screen = screenContaining(finderRect) {
            let placement = PanelPlacement.attachedToFinder(
                finderRect: finderRect,
                panelSize: panelSize,
                visibleFrame: screen.visibleFrame,
                offset: Layout.panelOffset,
                revealInset: Layout.finderRevealInset,
                previewInset: Layout.finderPreviewInset
            )
            logPlacement(source: "mouse", placement: placement, finderRect: finderRect)
            return placement
        }

        let visibleFrame = screenContaining(mousePoint)?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let placement = PanelPlacement.nearMouse(
            point: mousePoint,
            panelSize: panelSize,
            visibleFrame: visibleFrame,
            offset: Layout.panelOffset,
            hiddenTravel: Layout.fallbackHiddenTravel
        )
        logPlacement(source: "mouseFallback", placement: placement, finderRect: nil)
        return placement
    }

    private func screenContaining(_ rect: NSRect) -> NSScreen? {
        screenContaining(NSPoint(x: rect.midX, y: rect.midY))
    }

    private func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { NSPointInRect(point, $0.frame) }) ?? NSScreen.main
    }

    // MARK: - Private: Show & Refresh

    private func showAndRefresh(with placement: PanelPlacement) {
        guard let panel = panel else { return }
        updatePanelLayout(for: placement)
        if placement.isFinderAttached {
            isAttachedRevealAnimating = true
            updateAttachmentChrome(for: placement)
            PanelAnimator.shared.animatePanelIn(
                panel: panel,
                sequence: AttachedPanelRevealSequence(placement: placement)
            ) { [weak self] in
                guard let self else { return }
                self.isAttachedRevealAnimating = false
                self.updateAttachmentChrome(for: placement)
            }
        } else {
            isAttachedRevealAnimating = false
            updateAttachmentChrome(for: placement)
            PanelAnimator.shared.animatePanelIn(
                panel: panel,
                from: placement.hiddenRect,
                to: placement.targetRect
            )
        }
        store.refreshItems()
        DragDetector.shared.stopMonitoring()
        installEscapeKeyMonitorIfNeeded()
        startFinderFollow()
    }

    private func observeFinderAttachment() {
        finderAttachmentObserver = FinderWindowTracker.shared.$activeFinderWindowRect
            .dropFirst()
            .sink { [weak self] finderRect in
                guard let self else { return }
                guard self.currentPlacement?.isFinderAttached == true else { return }

                if let finderRect, let screen = self.screenContaining(finderRect) {
                    let latestSnapshot = FinderWindowTracker.shared.activeFinderWindowSnapshot
                    switch AttachedPanelLifecyclePolicy.decision(
                        isFinderAttached: true,
                        trackedSnapshot: self.attachedFinderWindowSnapshot,
                        latestSnapshot: latestSnapshot,
                        isContentModalPresented: self.isContentModalPresented
                    ) {
                    case .close:
                        self.hidePanel()
                        return
                    case .ignore:
                        return
                    case .update(let snapshot):
                        self.attachedFinderWindowSnapshot = snapshot
                    }

                    let updatedPlacement = PanelPlacement.attachedToFinder(
                        finderRect: finderRect,
                        panelSize: NSSize(width: Layout.panelWidth, height: Layout.panelHeight),
                        visibleFrame: screen.visibleFrame,
                        offset: Layout.panelOffset,
                        revealInset: Layout.finderRevealInset,
                        previewInset: Layout.finderPreviewInset
                    )
                    self.currentPlacement = updatedPlacement
                    self.updatePanelLayout(for: updatedPlacement)
                    self.updateAttachmentChrome(for: updatedPlacement)
                    self.panel?.setFrame(updatedPlacement.targetRect, display: true, animate: false)
                    self.logPlacement(source: "finderFollow", placement: updatedPlacement, finderRect: finderRect)
                } else {
                    switch AttachedPanelLifecyclePolicy.decision(
                        isFinderAttached: true,
                        trackedSnapshot: self.attachedFinderWindowSnapshot,
                        latestSnapshot: nil,
                        isContentModalPresented: self.isContentModalPresented
                    ) {
                    case .close:
                        self.hidePanel()
                    case .ignore, .update:
                        break
                    }
                }
            }
    }

    private func updatePanelLayout(for placement: PanelPlacement) {
        hostingView?.rootView = makeContentView(height: placement.targetRect.height)
    }

    private func updateAttachmentChrome(for placement: PanelPlacement) {
        let isVisible = AttachedPanelChromePolicy.isEdgePreviewVisible(
            isFinderAttached: placement.isFinderAttached,
            isRevealAnimating: isAttachedRevealAnimating
        )
        edgePreviewView?.isHidden = !isVisible
        edgePreviewView?.alphaValue = isVisible ? 1.0 : 0.0
        edgePreviewView?.edge = placement.edge
    }

    private func makeContentView(height: CGFloat) -> AnyView {
        AnyView(
            StashContentView(
                panelHeight: height,
                onClose: { [weak self] in self?.hidePanel() },
                onAlertPresentationChanged: { [weak self] isPresented in
                    self?.setContentModalPresentation(isPresented)
                }
            )
            .environmentObject(store)
            .environment(\.glassLightingScene, lightingScene)
        )
    }

    private func logPlacement(source: StaticString, placement: PanelPlacement, finderRect: NSRect?) {
        logger.debug(
            "Resolved placement source=\(source, privacy: .public) finderAttached=\(placement.isFinderAttached, privacy: .public) finderRect=\(String(describing: finderRect), privacy: .public) targetRect=\(String(describing: placement.targetRect), privacy: .public) hiddenRect=\(String(describing: placement.hiddenRect), privacy: .public)"
        )
    }

    private func startFinderFollow() {
        stopFinderFollow()

        guard currentPlacement?.isFinderAttached == true else { return }
        guard !isContentModalPresented else { return }

        finderFollowTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                self.refreshFinderAttachment(preferredRect: self.attachedFinderWindowSnapshot?.rect)
            }
        }
    }

    private func stopFinderFollow() {
        finderFollowTimer?.invalidate()
        finderFollowTimer = nil
    }

    private func captureFinderAttachmentIfNeeded(for placement: PanelPlacement) {
        guard placement.isFinderAttached else {
            attachedFinderWindowSnapshot = nil
            return
        }

        attachedFinderWindowSnapshot = FinderWindowTracker.shared.activeFinderWindowSnapshot
    }

    private func refreshFinderAttachment(preferredRect: NSRect?) {
        guard !isContentModalPresented else { return }

        if attachedFinderWindowSnapshot?.windowID != nil || !FinderWindowTracker.shared.isAccessibilityGranted {
            _ = FinderWindowTracker.shared.refreshAttachedFinderWindowSnapshot(
                windowID: attachedFinderWindowSnapshot?.windowID,
                preferredRect: preferredRect
            )
        } else {
            FinderWindowTracker.shared.updateActiveFinderWindowRect()
        }
    }

    private func setContentModalPresentation(_ isPresented: Bool) {
        guard isContentModalPresented != isPresented else { return }
        isContentModalPresented = isPresented

        if isPresented {
            stopFinderFollow()
        } else if panel?.isVisible == true {
            startFinderFollow()
        }
    }

    private func installEscapeKeyMonitorIfNeeded() {
        guard escapeKeyMonitor == nil else { return }
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }

            switch AttachedPanelLifecyclePolicy.keyboardDecision(for: event.keyCode) {
            case .close:
                self.hidePanel()
                return nil
            case .ignore:
                return event
            }
        }
    }

    private func removeEscapeKeyMonitor() {
        guard let escapeKeyMonitor else { return }
        NSEvent.removeMonitor(escapeKeyMonitor)
        self.escapeKeyMonitor = nil
    }
}
