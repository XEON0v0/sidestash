import AppKit
import SwiftUI

/// The shared light environment of the panel: where each icon light sits and
/// where the key light is. Positions are in `GlassLightingSpace` (panel,
/// top-left origin).
///
/// It pushes changes straight to the registered `GlassRimView`s, which update
/// their gradient layers in place: pointer moves and scrolling never go
/// through a SwiftUI update, which would re-render the panel every frame.
@MainActor
final class GlassLightingScene {
    private(set) var emitters: [String: GlassLightEmitter] = [:] {
        didSet { orderedEmittersCache = nil }
    }
    /// The key light as currently drawn; its pointer weight eases toward `targetKeyLight`.
    private(set) var keyLight = GlassKeyLight.default
    private(set) var targetKeyLight = GlassKeyLight.default
    /// The panel's bounds; icons fade out as they leave it.
    var bounds: CGRect = .zero {
        didSet {
            if bounds != oldValue { scheduleRelight() }
        }
    }
    /// Off while Reduce Motion is on: the key light then stays top-left.
    var followsPointer = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    /// With Reduce Transparency on, rims keep a plain white edge.
    private(set) var reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    /// The view whose top-left-origin coordinates are scene coordinates.
    weak var coordinateRoot: NSView? {
        didSet { scheduleRelight() }
    }

    private let rims = NSHashTable<GlassRimView>.weakObjects()
    private var relightScheduled = false
    private var lastPointerUpdate: TimeInterval = 0
    private var pendingPointer: CGPoint?
    private var pointerFlushTimer: Timer?
    private var easeTimer: Timer?
    private var orderedEmittersCache: [GlassLightEmitter]?
    private var accessibilityObserver: NSObjectProtocol?

    init() {
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.followsPointer = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
                if !self.followsPointer {
                    self.pointerExited(animated: false)
                }
                self.scheduleRelight()
            }
        }
    }

    deinit {
        if let accessibilityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver)
        }
    }

    /// Emitters in a stable order, so identical scenes light rims identically.
    /// Sorted once per change (by UTF-8 bytes: path comparison is costly) and
    /// shared by every rim.
    var orderedEmitters: [GlassLightEmitter] {
        if let orderedEmittersCache {
            return orderedEmittersCache
        }
        let ordered = emitters
            .sorted { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }
            .map(\.value)
        orderedEmittersCache = ordered
        return ordered
    }

    // MARK: - Rims

    func register(_ rim: GlassRimView) {
        rims.add(rim)
        rim.relight()
    }

    func unregister(_ rim: GlassRimView) {
        rims.remove(rim)
    }

    /// A view's frame in scene coordinates, or `nil` before the scene is attached.
    func sceneRect(of view: NSView) -> CGRect? {
        guard let root = coordinateRoot, view.window != nil, view.window === root.window else { return nil }
        let rect = view.convert(view.bounds, to: root)
        return root.isFlipped
            ? rect
            : CGRect(x: rect.minX, y: root.bounds.height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Relights every rim once on the next run loop pass, however many changes
    /// (a scroll moves every row's light) arrive before it.
    func scheduleRelight() {
        guard !relightScheduled else { return }
        relightScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.relightScheduled = false
                self.relightNow()
            }
        }
    }

    private func relightNow() {
        for rim in rims.allObjects {
            rim.relight()
        }
    }

    // MARK: - Icon lights

    /// Places an icon's light. Called whenever its row moves, so it also keeps
    /// rims current while scrolling; icons without color emit nothing.
    func setEmitter(id: String, position: CGPoint, light: IconLight?) {
        if let light {
            let emitter = GlassLightEmitter(position: position, light: light)
            if emitters[id] != emitter {
                emitters[id] = emitter
            }
        } else if emitters[id] != nil {
            emitters[id] = nil
        }
        scheduleRelight()
    }

    func removeEmitter(id: String) {
        guard emitters[id] != nil else { return }
        emitters[id] = nil
        scheduleRelight()
    }

    // MARK: - Key light

    /// The key light follows the pointer. It eases in when the pointer first
    /// arrives, then tracks it directly, at most once per
    /// `pointerUpdateInterval` (the latest position always lands).
    func pointerMoved(to point: CGPoint, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard followsPointer else {
            pointerExited()
            return
        }

        if targetKeyLight.pointerWeight < 1 {
            cancelPendingPointer()
            lastPointerUpdate = now
            keyLight.position = point
            ease(to: GlassKeyLight(position: point, pointerWeight: 1), animated: true)
            return
        }

        let elapsed = now - lastPointerUpdate
        guard elapsed < GlassLightingStyle.pointerUpdateInterval else {
            applyPointer(point, at: now)
            return
        }

        pendingPointer = point
        guard pointerFlushTimer == nil else { return }
        pointerFlushTimer = Timer.scheduledTimer(
            withTimeInterval: GlassLightingStyle.pointerUpdateInterval - elapsed,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pointerFlushTimer = nil
                if let pending = self.pendingPointer {
                    self.pendingPointer = nil
                    self.applyPointer(pending, at: ProcessInfo.processInfo.systemUptime)
                }
            }
        }
    }

    /// The key light eases back to its default top-left position.
    func pointerExited(animated: Bool = true) {
        cancelPendingPointer()
        guard targetKeyLight.pointerWeight > 0 || keyLight.pointerWeight > 0 else { return }
        ease(to: GlassKeyLight(position: keyLight.position, pointerWeight: 0), animated: animated)
    }

    private func applyPointer(_ point: CGPoint, at now: TimeInterval) {
        lastPointerUpdate = now
        // The pointer may have left while this update waited.
        guard targetKeyLight.pointerWeight >= 1 else { return }
        targetKeyLight.position = point
        guard keyLight.position != point else { return }
        keyLight.position = point
        scheduleRelight()
    }

    private func cancelPendingPointer() {
        pendingPointer = nil
        pointerFlushTimer?.invalidate()
        pointerFlushTimer = nil
    }

    /// Eases the pointer weight toward `target` (ease-out cubic); the position
    /// always tracks the target directly.
    private func ease(to target: GlassKeyLight, animated: Bool) {
        targetKeyLight = target
        easeTimer?.invalidate()
        easeTimer = nil

        guard animated else {
            keyLight = target
            scheduleRelight()
            return
        }

        let startWeight = keyLight.pointerWeight
        let start = ProcessInfo.processInfo.systemUptime
        let duration = GlassLightingStyle.pointerEnterExitDuration
        easeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }
                let progress = min((ProcessInfo.processInfo.systemUptime - start) / duration, 1)
                let eased = 1 - pow(1 - progress, 3)
                let weight = startWeight + (self.targetKeyLight.pointerWeight - startWeight) * eased
                self.keyLight = GlassKeyLight(position: self.targetKeyLight.position, pointerWeight: weight)
                self.relightNow()
                if progress >= 1 {
                    timer.invalidate()
                    self.easeTimer = nil
                }
            }
        }
    }
}

private struct GlassLightingSceneKey: EnvironmentKey {
    static let defaultValue: GlassLightingScene? = nil
}

extension EnvironmentValues {
    /// The panel's light environment, injected by `StashWindowManager`.
    var glassLightingScene: GlassLightingScene? {
        get { self[GlassLightingSceneKey.self] }
        set { self[GlassLightingSceneKey.self] = newValue }
    }
}
