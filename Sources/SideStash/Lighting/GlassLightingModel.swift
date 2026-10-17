import AppKit
import SwiftUI

/// RGB in linear light, so light from several sources adds up like real light.
struct LightRGB: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat

    static let zero = LightRGB(red: 0, green: 0, blue: 0)
    static let white = LightRGB(red: 1, green: 1, blue: 1)

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// From gamma-encoded sRGB components.
    init(sRGBRed red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.init(red: Self.linear(red), green: Self.linear(green), blue: Self.linear(blue))
    }

    init?(_ color: NSColor) {
        guard let color = color.usingColorSpace(.sRGB) else { return nil }
        self.init(sRGBRed: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }

    var maxComponent: CGFloat {
        max(red, green, blue)
    }

    static func + (lhs: LightRGB, rhs: LightRGB) -> LightRGB {
        LightRGB(red: lhs.red + rhs.red, green: lhs.green + rhs.green, blue: lhs.blue + rhs.blue)
    }

    static func * (lhs: LightRGB, scale: CGFloat) -> LightRGB {
        LightRGB(red: lhs.red * scale, green: lhs.green * scale, blue: lhs.blue * scale)
    }

    static func linear(_ component: CGFloat) -> CGFloat {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }

    static func encoded(_ component: CGFloat) -> CGFloat {
        let clamped = min(max(component, 0), 1)
        return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}

/// The light a file icon emits: its dominant hue, and a strength that grows
/// with how much color the icon has.
struct IconLight: Equatable, Sendable {
    let color: LightRGB
    let strength: CGFloat
}

/// An icon light placed in the lighting scene (panel coordinates, top-left origin).
struct GlassLightEmitter: Equatable, Sendable {
    let position: CGPoint
    let light: IconLight
}

/// The key (white specular) light. With `pointerWeight` 0 it is the default
/// top-left light; with 1 it sits above the pointer at `position`. Both values
/// animate, so the highlight glides when the pointer enters or leaves.
struct GlassKeyLight: Equatable, Sendable {
    var position: CGPoint
    var pointerWeight: CGFloat

    static let `default` = GlassKeyLight(position: .zero, pointerWeight: 0)
}

enum GlassRimShape: Equatable, Sendable {
    case roundedRect(cornerRadius: CGFloat)
    case capsule

    func cornerRadius(in size: CGSize) -> CGFloat {
        let limit = min(size.width, size.height) / 2
        switch self {
        case let .roundedRect(cornerRadius):
            return min(max(cornerRadius, 0), limit)
        case .capsule:
            return limit
        }
    }
}

/// Which glass a bevel belongs to. The panel and the pill already draw a
/// native glass edge, so their bevel light only supplements it; file plates
/// rely on it.
enum GlassSurfaceKind: Sendable {
    case panel
    case pill
    case plate
}

/// One surface's bevel lighting, laid out for the shader: each field is one
/// `float4` of `BevelUniforms` in `GlassBevelRenderer.shaderSource`, in order.
/// Positions are in the surface's own points (top-left origin, y down).
struct GlassBevelUniforms: Equatable, Sendable {
    /// Width, height, corner radius (pt), backing scale (px per pt).
    var surface: SIMD4<Float>
    /// Bevel width (pt), height ratio, profile exponent, refractive index.
    var profile: SIMD4<Float>
    /// Unit direction toward the key light (x right, y down, z toward the
    /// viewer), key highlight gain.
    var keyLight: SIMD4<Float>
    /// The key light's direction across the glass (x, y), back light gain,
    /// edge gain.
    var keyFacing: SIMD4<Float>
    /// Pointer position, pointer light height, pointer highlight gain.
    var pointer: SIMD4<Float>
    /// Pointer reach, gain of pointer light leaving the slopes, key and
    /// pointer shininess.
    var pointerShape: SIMD4<Float>
    /// Icon light gain, halo reach, facing wrap, escape exponent.
    var emitterTuning: SIMD4<Float>
    /// Icon light core radius, core gain, unused, unused.
    var emitterCore: SIMD4<Float>
    /// Max opacity, minimum edge width (pt), edge directionality, icon count.
    var output: SIMD4<Float>
}

/// An icon light as the shader sees it.
struct GlassBevelEmitter: Equatable, Sendable {
    /// Position, 1 when the icon sits on the surface (0 beside it), unused.
    var position: SIMD4<Float>
    /// Linear color × strength × visibility, unused.
    var light: SIMD4<Float>

    /// Fills the shader's emitter buffer when no icon reaches the surface.
    static let none = GlassBevelEmitter(position: .zero, light: .zero)
}

/// Everything needed to draw one surface's bevel.
struct GlassBevelLighting: Equatable, Sendable {
    var uniforms: GlassBevelUniforms
    var emitters: [GlassBevelEmitter]
}

/// Named coordinate space shared by every glass surface and light emitter. It
/// matches the top-left-origin coordinates of the panel's hosting view, which
/// `GlassLightingScene.coordinateRoot` points at.
enum GlassLightingSpace {
    static let name = "SideStash.glassLighting"
}

/// Every tunable of the lighting model, in one place.
enum GlassLightingStyle {
    /// Each surface's slope: a tight, Apple-like edge (p = 4) whose curvature
    /// gathers in the outer couple of points. The panel's slope stays inside
    /// the file list inset, so it never runs under the plates.
    static func bevel(for kind: GlassSurfaceKind) -> GlassBevel {
        switch kind {
        case .panel:
            return GlassBevel(width: 10, heightRatio: 1, profileExponent: 4, refractiveIndex: 1.5)
        case .pill:
            return GlassBevel(width: 10, heightRatio: 1, profileExponent: 4, refractiveIndex: 1.5)
        case .plate:
            return GlassBevel(width: 6, heightRatio: 1, profileExponent: 4, refractiveIndex: 1.5)
        }
    }

    /// The Fresnel edge stays at least this wide: about a pixel on a 2x display.
    static let minimumEdgeWidth: CGFloat = 0.5
    /// Share of the edge light that follows the key light's side; the rest
    /// goes all around.
    static let edgeDirectionality: CGFloat = 0.5
    /// Light leaving the glass gathers on the steep outer slope; lower spreads
    /// it further in.
    static let escapeExponent: CGFloat = 0.5

    /// Unit vector toward the default key light: top-left (y grows downward).
    static let defaultKeyLightDirection = CGVector(dx: -0.6, dy: -0.8)
    /// Elevation of the default key light above the glass.
    static let keyLightElevation: CGFloat = 40 * .pi / 180
    /// Blinn-Phong exponent of the key highlight: higher is a thinner line.
    static let keyShininess: CGFloat = 48
    /// Height of the pointer light above the glass: lower is more directional.
    static let pointerLightHeight: CGFloat = 24
    /// Distance at which the pointer light stops adding highlight.
    static let pointerLightReach: CGFloat = 220
    /// Broader than the key highlight, so every slope the pointer nears catches it.
    static let pointerShininess: CGFloat = 24
    /// Share of the default top-left light kept while the pointer leads.
    static let ambientDirectionalShare: CGFloat = 0.3
    static let pointerEnterExitDuration: TimeInterval = 0.35
    /// Pointer moves are coalesced to at most one light update per frame at 60 Hz.
    static let pointerUpdateInterval: TimeInterval = 1.0 / 60

    /// Distance at which an icon's halo no longer reaches a slope.
    static let emitterReach: CGFloat = 110
    /// An icon's bright core, about its own size: the slope right next to an
    /// icon shows its light, pulled outward by refraction.
    static let emitterCoreRadius: CGFloat = 28
    static let emitterCoreGain: CGFloat = 2
    /// Softens the facing cutoff so light wraps a little around corners.
    static let facingWrap: CGFloat = 0.25
    /// Icons fade out over this distance as they leave the panel.
    static let emitterEdgeFade: CGFloat = 16
    /// At most this many icon lights reach one surface; the nearest win.
    static let maxEmitters = 16

    struct Intensity: Equatable {
        /// White highlight of the default top-left light on the slopes facing it.
        let key: CGFloat
        /// White highlight of the light above the pointer. Kept separate and
        /// stronger, so the moving highlight reads even on the panel and pill,
        /// whose native glass edge already carries the static light.
        let pointer: CGFloat
        /// Light that crossed the glass, leaving the slopes on the far side.
        let back: CGFloat
        /// Fresnel edge: the thin bright line where the slope turns vertical.
        let edge: CGFloat
        /// Gain for colored icon light.
        let emitter: CGFloat
        let maxOpacity: CGFloat
    }

    static func intensity(for kind: GlassSurfaceKind, colorScheme: ColorScheme) -> Intensity {
        let isDark = colorScheme == .dark
        switch kind {
        case .plate:
            return isDark
                ? Intensity(key: 0.40, pointer: 0.75, back: 0.12, edge: 0.35, emitter: 0.60, maxOpacity: 0.95)
                : Intensity(key: 0.90, pointer: 0.95, back: 0.30, edge: 0.60, emitter: 0.55, maxOpacity: 0.95)
        case .pill:
            return isDark
                ? Intensity(key: 0.24, pointer: 0.60, back: 0.07, edge: 0.20, emitter: 0.45, maxOpacity: 0.85)
                : Intensity(key: 0.55, pointer: 0.80, back: 0.18, edge: 0.35, emitter: 0.40, maxOpacity: 0.85)
        case .panel:
            return isDark
                ? Intensity(key: 0.20, pointer: 0.55, back: 0.05, edge: 0.16, emitter: 0.35, maxOpacity: 0.80)
                : Intensity(key: 0.45, pointer: 0.75, back: 0.14, edge: 0.30, emitter: 0.30, maxOpacity: 0.80)
        }
    }
}
