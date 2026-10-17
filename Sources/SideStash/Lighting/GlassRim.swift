import AppKit
import SwiftUI

/// The lit edge of a glass surface, as a SwiftUI view. The drawing lives in
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

/// Draws a rim as a conic gradient masked to the outline, plus fainter inner
/// strokes for light refracted just inside it. Colors come from
/// `GlassLightingEngine` at this view's place in the scene and are only
/// touched when they change, so the GPU composites everything else.
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

    /// The stops currently on screen.
    private(set) var currentStops: [GlassRimStop] = []

    /// Everything the rim's colors depend on; unchanged inputs skip the work.
    private struct LightingInputs: Equatable {
        let shape: GlassRimShape
        let kind: GlassSurfaceKind
        let frame: CGRect
        let keyLight: GlassKeyLight
        let emitters: [GlassLightEmitter]
        let sceneBounds: CGRect
        let isDark: Bool
        let reduceTransparency: Bool
    }

    private var currentInputs: LightingInputs?

    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CALayer()
    private let rimLayer = CAShapeLayer()
    private let bandLayers: [CAShapeLayer]
    private var currentBandOpacity: Double = -1

    /// Rim changes land at once. Disabling the implicit animations per layer,
    /// rather than wrapping each change in its own `CATransaction`, lets a
    /// relight of every rim go out in the run loop's single commit: an explicit
    /// transaction outside one commits the whole layer tree on the spot.
    private static let noAnimations: [String: any CAAction] = [
        "colors": NSNull(), "locations": NSNull(), "opacity": NSNull(),
        "path": NSNull(), "lineWidth": NSNull(),
        "bounds": NSNull(), "position": NSNull(), "frame": NSNull(),
    ]

    init(shape: GlassRimShape, kind: GlassSurfaceKind) {
        self.shape = shape
        self.kind = kind
        bandLayers = GlassLightingStyle.refractionBandSteps.map { _ in CAShapeLayer() }
        super.init(frame: .zero)

        wantsLayer = true
        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.mask = maskLayer
        gradientLayer.actions = Self.noAnimations
        maskLayer.actions = Self.noAnimations
        layer?.addSublayer(gradientLayer)

        for strokeLayer in bandLayers + [rimLayer] {
            strokeLayer.fillColor = nil
            strokeLayer.strokeColor = NSColor.black.cgColor
            strokeLayer.actions = Self.noAnimations
            maskLayer.addSublayer(strokeLayer)
        }
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
        updateGeometry()
        relight()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        relight()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        relight()
    }

    /// Recomputes this rim's colors from the scene and applies them if they changed.
    func relight() {
        guard let scene, bounds.width > 1, bounds.height > 1, let frame = scene.sceneRect(of: self) else { return }

        // Reduce Transparency keeps a plain white rim.
        let inputs = LightingInputs(
            shape: shape,
            kind: kind,
            frame: frame,
            keyLight: GlassLightingEngine.effectiveKeyLight(scene.keyLight, for: frame),
            emitters: scene.reduceTransparency ? [] : GlassLightingEngine.emitters(scene.orderedEmitters, reaching: frame),
            sceneBounds: scene.bounds,
            isDark: effectiveAppearance.isDarkGlassAppearance,
            reduceTransparency: scene.reduceTransparency
        )
        guard inputs != currentInputs else { return }
        currentInputs = inputs

        let intensity = GlassLightingStyle.intensity(for: kind, colorScheme: inputs.isDark ? .dark : .light)
        let stops = GlassLightingEngine.rimStops(
            shape: inputs.shape,
            frame: inputs.frame,
            kind: inputs.kind,
            keyLight: inputs.keyLight,
            emitters: inputs.emitters,
            sceneBounds: inputs.sceneBounds,
            intensity: intensity
        )
        let bandOpacity = inputs.reduceTransparency ? 0 : intensity.refractionBand
        guard stops != currentStops || bandOpacity != currentBandOpacity else { return }
        currentStops = stops
        currentBandOpacity = bandOpacity

        gradientLayer.colors = stops.map { stop in
            CGColor(srgbRed: stop.red, green: stop.green, blue: stop.blue, alpha: stop.opacity)
        }
        gradientLayer.locations = stops.map { NSNumber(value: Double($0.location)) }
        for (bandLayer, step) in zip(bandLayers, GlassLightingStyle.refractionBandSteps) {
            bandLayer.opacity = Float(bandOpacity * step.opacity)
        }
    }

    private func updateGeometry() {
        gradientLayer.frame = bounds
        maskLayer.frame = bounds

        let rimWidth = GlassLightingStyle.rimWidth
        rimLayer.lineWidth = rimWidth
        rimLayer.path = outlinePath(insetBy: rimWidth / 2)
        for (bandLayer, step) in zip(bandLayers, GlassLightingStyle.refractionBandSteps) {
            bandLayer.lineWidth = step.width
            bandLayer.path = outlinePath(insetBy: step.inset + step.width / 2)
        }
    }

    /// The outline inset by `inset`, with concentric continuous corners, so a
    /// stroke of width `2 × inset` sits just inside the edge.
    private func outlinePath(insetBy inset: CGFloat) -> CGPath {
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return CGPath(rect: .zero, transform: nil) }
        let radius = min(max(shape.cornerRadius(in: bounds.size) - inset, 0), min(rect.width, rect.height) / 2)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
    }
}
