import AppKit
import SwiftUI

/// The lit bevel of a glass surface, as a SwiftUI view. The drawing lives in
/// `GlassRimView`, which the shared `GlassLightingScene` updates directly.
struct GlassRim: NSViewRepresentable {
    let shape: GlassRimShape
    let kind: GlassSurfaceKind

    @Environment(\.glassLightingScene) private var scene

    func makeNSView(context: Context) -> GlassRimView {
        let view = GlassRimView(shape: shape, kind: kind)
        view.scene = scene
        return view
    }

    func updateNSView(_ view: GlassRimView, context: Context) {
        view.shape = shape
        view.kind = kind
        view.scene = scene
    }

    static func dismantleNSView(_ view: GlassRimView, coordinator: ()) {
        view.scene = nil
    }
}

/// Shows a surface's bevel: the slope band between its outline and its
/// plateau, lit by `GlassLightingEngine` at this view's place in the scene and
/// drawn on the GPU by `GlassBevelRenderer`. It only draws when its lighting
/// changes; the layer's contents swap in once the GPU is done.
final class GlassRimView: NSView {
    var shape: GlassRimShape {
        didSet {
            guard shape != oldValue else { return }
            needsLayout = true
        }
    }

    var kind: GlassSurfaceKind {
        didSet {
            guard kind != oldValue else { return }
            relight()
        }
    }

    weak var scene: GlassLightingScene? {
        didSet {
            guard scene !== oldValue else { return }
            oldValue?.unregister(self)
            scene?.register(self)
        }
    }

    /// The lighting most recently computed from the scene.
    private(set) var lighting: GlassBevelLighting?
    /// The lighting most recently drawn, or being drawn.
    private(set) var renderedLighting: GlassBevelLighting?
    /// Finished draws.
    private(set) var renderCount = 0

    private let renderer: GlassBevelRenderer
    /// At most three: one on screen, one just replaced (the compositor may
    /// still read it) and one to draw into.
    private var targets: [GlassBevelTarget] = []
    private var displayedTarget: GlassBevelTarget?
    private var replacedTarget: GlassBevelTarget?
    private var isRendering = false
    private var isWaitingForRenderer = false

    private static let maxTargets = 3

    /// Contents and geometry land at once, in the run loop's single commit.
    private static let noAnimations: [String: any CAAction] = [
        "contents": NSNull(), "contentsScale": NSNull(), "cornerRadius": NSNull(),
        "bounds": NSNull(), "position": NSNull(), "frame": NSNull(),
    ]

    /// `renderer` defaults to the shared one.
    init(shape: GlassRimShape, kind: GlassSurfaceKind, renderer: GlassBevelRenderer? = nil) {
        self.shape = shape
        self.kind = kind
        self.renderer = renderer ?? .shared
        super.init(frame: .zero)

        wantsLayer = true
        // Clip to the native glass outline, whose corners are continuous.
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.contentsGravity = .resize
        layer?.actions = Self.noAnimations
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = shape.cornerRadius(in: bounds.size)
        relight()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        relight()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        relight()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        relight()
    }

    /// Recomputes this bevel's lighting from the scene and draws it if it changed.
    func relight() {
        guard let scene, let window, bounds.width > 1, bounds.height > 1,
              let frame = scene.sceneRect(of: self) else { return }
        let isDark = effectiveAppearance.isDarkGlassAppearance
        lighting = GlassLightingEngine.lighting(
            shape: shape,
            frame: frame,
            kind: kind,
            keyLight: scene.keyLight,
            emitters: scene.orderedEmitters,
            sceneBounds: scene.bounds,
            intensity: GlassLightingStyle.intensity(for: kind, colorScheme: isDark ? .dark : .light),
            reduceTransparency: scene.reduceTransparency,
            scale: window.backingScaleFactor
        )
        renderIfNeeded()
    }

    private func renderIfNeeded() {
        // One draw at a time; a newer lighting is drawn when it finishes.
        guard let lighting, lighting != renderedLighting, !isRendering else { return }
        guard renderer.isReady else {
            waitForRenderer()
            return
        }
        let scale = CGFloat(lighting.uniforms.surface.w)
        let width = Int((CGFloat(lighting.uniforms.surface.x) * scale).rounded())
        let height = Int((CGFloat(lighting.uniforms.surface.y) * scale).rounded())
        guard let target = nextTarget(width: width, height: height) else { return }

        isRendering = true
        renderedLighting = lighting
        let started = renderer.render(lighting, into: target) { [weak self] in
            guard let self else { return }
            self.isRendering = false
            self.renderCount += 1
            self.replacedTarget = self.displayedTarget
            self.displayedTarget = target
            self.layer?.contentsScale = scale
            self.layer?.contents = target.surface
            self.renderIfNeeded()
        }
        if !started {
            isRendering = false
            renderedLighting = nil
        }
    }

    /// A target of the current pixel size that is neither on screen nor just
    /// replaced. A new size starts a new set; the layer keeps showing the old
    /// contents until the first draw at the new size lands.
    private func nextTarget(width: Int, height: Int) -> GlassBevelTarget? {
        if let first = targets.first, first.width != width || first.height != height {
            targets.removeAll()
            replacedTarget = nil
        }
        if let free = targets.first(where: { $0 !== displayedTarget && $0 !== replacedTarget }) {
            return free
        }
        guard targets.count < Self.maxTargets, let target = renderer.makeTarget(width: width, height: height) else {
            return nil
        }
        targets.append(target)
        return target
    }

    private func waitForRenderer() {
        renderer.prepare()
        guard !isWaitingForRenderer else { return }
        isWaitingForRenderer = true
        renderer.whenReady { [weak self] in
            guard let self else { return }
            self.isWaitingForRenderer = false
            self.renderIfNeeded()
        }
    }
}
