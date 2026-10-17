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

/// Which glass a rim belongs to. The panel and the pill already draw a native
/// glass rim, so the lighting only supplements them; file plates rely on it.
enum GlassSurfaceKind: Sendable {
    case panel
    case pill
    case plate
}

/// One rim color stop. `location` follows a conic `CAGradientLayer` (see
/// `GlassLightingEngine.location(of:in:)`). Components are gamma-encoded sRGB.
struct GlassRimStop: Equatable, Sendable {
    let location: CGFloat
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let opacity: CGFloat

    func moved(to location: CGFloat) -> GlassRimStop {
        GlassRimStop(location: location, red: red, green: green, blue: blue, opacity: opacity)
    }

    static func interpolate(_ from: GlassRimStop, _ to: GlassRimStop, _ progress: CGFloat) -> GlassRimStop {
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        return GlassRimStop(
            location: mix(from.location, to.location),
            red: mix(from.red, to.red),
            green: mix(from.green, to.green),
            blue: mix(from.blue, to.blue),
            opacity: mix(from.opacity, to.opacity)
        )
    }
}

/// Named coordinate space shared by every glass surface and light emitter. It
/// matches the top-left-origin coordinates of the panel's hosting view, which
/// `GlassLightingScene.coordinateRoot` points at.
enum GlassLightingSpace {
    static let name = "SideStash.glassLighting"
}

/// Every tunable of the lighting model, in one place.
enum GlassLightingStyle {
    static let rimWidth: CGFloat = 1

    struct BandStep: Equatable {
        let inset: CGFloat
        let width: CGFloat
        let opacity: Double
    }

    /// Light refracted just inside the rim, as strokes fading inward (about 5 pt deep).
    static let refractionBandSteps: [BandStep] = [
        BandStep(inset: 1, width: 1.5, opacity: 1),
        BandStep(inset: 2.5, width: 1.5, opacity: 0.55),
        BandStep(inset: 4, width: 1.5, opacity: 0.25),
    ]

    /// Unit vector toward the default key light: top-left (y grows downward).
    static let defaultKeyLightDirection = CGVector(dx: -0.6, dy: -0.8)
    /// Height of the pointer light above the glass: lower is more directional.
    static let pointerLightHeight: CGFloat = 24
    /// Distance at which the pointer light stops adding highlight.
    static let pointerLightReach: CGFloat = 220
    /// Broader than the default light's falloff, so nearby edges catch it.
    static let pointerSpecularExponent: CGFloat = 1.5
    /// Share of the default top-left light kept while the pointer leads.
    static let ambientDirectionalShare: CGFloat = 0.3
    static let pointerEnterExitDuration: TimeInterval = 0.35
    /// Pointer moves are coalesced to at most one light update per frame at 60 Hz.
    static let pointerUpdateInterval: TimeInterval = 1.0 / 60

    static let specularExponent: CGFloat = 2
    /// Distance at which an icon's light no longer reaches a rim.
    static let emitterReach: CGFloat = 110
    /// Softens the facing cutoff so light wraps a little around corners.
    static let facingWrap: CGFloat = 0.25
    /// Icons fade out over this distance as they leave the panel.
    static let emitterEdgeFade: CGFloat = 16

    static func sampleCount(for kind: GlassSurfaceKind) -> Int {
        switch kind {
        case .panel: return 56
        case .pill: return 32
        case .plate: return 40
        }
    }

    struct Intensity: Equatable {
        /// White specular from the default top-left light.
        let key: CGFloat
        /// White specular from the light above the pointer. Kept separate and
        /// stronger, so the moving highlight reads even on the panel and pill,
        /// whose native glass rim already carries the static light.
        let pointer: CGFloat
        /// Faint refraction on the edges facing away from the key light.
        let back: CGFloat
        /// Constant white outline.
        let ambient: CGFloat
        /// Gain for colored icon light.
        let emitter: CGFloat
        let refractionBand: Double
        let maxOpacity: CGFloat
    }

    static func intensity(for kind: GlassSurfaceKind, colorScheme: ColorScheme) -> Intensity {
        let isDark = colorScheme == .dark
        switch kind {
        case .plate:
            return isDark
                ? Intensity(key: 0.32, pointer: 0.70, back: 0.08, ambient: 0.06, emitter: 0.60, refractionBand: 0.20, maxOpacity: 0.95)
                : Intensity(key: 0.85, pointer: 0.90, back: 0.25, ambient: 0.30, emitter: 0.55, refractionBand: 0.14, maxOpacity: 0.95)
        case .pill:
            return isDark
                ? Intensity(key: 0.19, pointer: 0.60, back: 0.05, ambient: 0.03, emitter: 0.45, refractionBand: 0.14, maxOpacity: 0.85)
                : Intensity(key: 0.51, pointer: 0.80, back: 0.15, ambient: 0.15, emitter: 0.40, refractionBand: 0.10, maxOpacity: 0.85)
        case .panel:
            return isDark
                ? Intensity(key: 0.16, pointer: 0.55, back: 0.04, ambient: 0.02, emitter: 0.35, refractionBand: 0.10, maxOpacity: 0.80)
                : Intensity(key: 0.43, pointer: 0.75, back: 0.12, ambient: 0.10, emitter: 0.30, refractionBand: 0.08, maxOpacity: 0.80)
        }
    }
}
