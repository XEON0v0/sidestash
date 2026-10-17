import simd

/// The edge of a glass slab, seen from the side. Every glass surface is a
/// curved-edge frustum: a flat plateau on top of a convex slope that falls to
/// the outline. `u` runs across the slope, 0 at the outline and 1 where it
/// meets the plateau; seen from above, the slope is a band `width` wide.
///
/// Math is in `Float`: `GlassBevelRenderer`'s shader evaluates the same
/// formulas, and `GlassBevelRendererTests` keeps the two in step.
struct GlassBevel: Equatable, Sendable {
    /// How far the slope reaches in from the outline, in points.
    var width: Float
    /// Slope height over `width`: higher is steeper.
    var heightRatio: Float
    /// Superellipse exponent of the profile: 2 is a round edge, 4 a tight
    /// Apple-like one whose curvature gathers at the outline.
    var profileExponent: Float
    var refractiveIndex: Float

    /// Keeps the slope finite where the profile turns vertical.
    private static let minimumBase: Float = 1e-6

    /// Profile height, 0 at the outline and 1 at the plateau:
    /// `(1 − (1 − u)^p)^(1/p)`.
    func profile(at u: Float) -> Float {
        let rest = 1 - unitClamp(u)
        return pow(max(1 - pow(rest, profileExponent), 0), 1 / profileExponent)
    }

    /// Slope height in points.
    func height(at u: Float) -> Float {
        profile(at: u) * heightRatio * width
    }

    /// tanθ of the slope: near vertical at the outline, flat at the plateau.
    func slope(at u: Float) -> Float {
        let rest = 1 - unitClamp(u)
        let base = max(1 - pow(rest, profileExponent), Self.minimumBase)
        return heightRatio * pow(base, 1 / profileExponent - 1) * pow(rest, profileExponent - 1)
    }

    /// Unit surface normal (x right, y down, z toward the viewer) where the
    /// outline faces `outward`.
    func normal(at u: Float, outward: SIMD2<Float>) -> SIMD3<Float> {
        let tilt = slope(at: u)
        return simd_normalize(SIMD3(outward * tilt, 1))
    }

    /// Schlick's Fresnel reflectance where the normal makes `cosine` with the view.
    func fresnel(cosine: Float) -> Float {
        let r0 = pow((refractiveIndex - 1) / (refractiveIndex + 1), 2)
        return r0 + (1 - r0) * pow(1 - unitClamp(cosine), 5)
    }

    /// How far inward a view ray from straight above, bent by the slope,
    /// lands on the glass floor: what the slope shows comes from there.
    func refractionOffset(at u: Float) -> Float {
        let tilt = atan(slope(at: u))
        let refracted = asin(sin(tilt) / refractiveIndex)
        return height(at: u) * tan(tilt - refracted)
    }
}

/// Where a point sits against a rounded rect's outline (circular corners).
struct GlassOutlinePoint: Equatable, Sendable {
    /// Distance inside the outline; negative outside it.
    let inset: Float
    /// Outward unit normal of the nearest outline point.
    let normal: SIMD2<Float>

    /// `point` is in the shape's own coordinates: top-left origin, y down.
    init(_ point: SIMD2<Float>, size: SIMD2<Float>, cornerRadius: Float) {
        let half = size / 2
        let relative = point - half
        let q = simd_abs(relative) - (half - cornerRadius)
        inset = cornerRadius - simd_length(simd_max(q, .zero)) - min(max(q.x, q.y), 0)
        let side = SIMD2<Float>(relative.x < 0 ? -1 : 1, relative.y < 0 ? -1 : 1)
        if q.x > 0, q.y > 0 {
            normal = simd_normalize(q) * side
        } else if q.x > q.y {
            normal = SIMD2(side.x, 0)
        } else {
            normal = SIMD2(0, side.y)
        }
    }
}

func unitClamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
}

/// `LightRGB.encoded(_:)` in `Float`, as the shader computes it.
func encodedSRGB(_ component: Float) -> Float {
    let clamped = unitClamp(component)
    return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
}
