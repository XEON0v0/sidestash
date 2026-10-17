import CoreGraphics
import Foundation
import simd

/// Lighting for every glass surface, modeled as a curved-edge slab: a flat
/// plateau over a convex slope (`GlassBevel`). The plateau is the native glass
/// and stays untouched; only the slope is lit:
///
/// - a thin Fresnel edge where the slope turns vertical,
/// - white highlights of the default top-left light and of the light above
///   the pointer, sitting where the slope's tilt reflects them to the viewer:
///   as the pointer comes closer, its highlight rolls toward the plateau,
/// - light that crossed the glass leaving the slopes on the far side,
/// - icon light seen through the slope: the bent view ray lands further in,
///   so an icon's light is pulled out onto the slope next to it.
///
/// `lighting(...)` packs one surface's lights for `GlassBevelRenderer`;
/// `bevelLight(at:lighting:)` is the Swift reference of its shader, which
/// mirrors it line by line (see `GlassBevelRendererTests`).
enum GlassLightingEngine {
    // MARK: - Lighting

    /// One surface's bevel lighting, from the scene. Lights out of the
    /// surface's reach are left out, so they never cause a redraw.
    static func lighting(
        shape: GlassRimShape,
        frame: CGRect,
        kind: GlassSurfaceKind,
        keyLight: GlassKeyLight,
        emitters: [GlassLightEmitter],
        sceneBounds: CGRect,
        intensity: GlassLightingStyle.Intensity,
        reduceTransparency: Bool,
        scale: CGFloat
    ) -> GlassBevelLighting {
        let style = GlassLightingStyle.self
        let size = SIMD2(Float(frame.width), Float(frame.height))
        var bevel = style.bevel(for: kind)
        bevel.width = max(min(bevel.width, min(size.x, size.y) / 2), 0.001)
        // Reduce Transparency keeps only a plain white edge.
        let lit: Float = reduceTransparency ? 0 : 1

        // While the pointer leads, only a share of the default light remains.
        let weight = Float(min(max(keyLight.pointerWeight, 0), 1))
        let share = Float(style.ambientDirectionalShare)
        let directional = ((1 - weight) + weight * share) * lit

        let facing = SIMD2(Float(style.defaultKeyLightDirection.dx), Float(style.defaultKeyLightDirection.dy))
        let elevation = Float(style.keyLightElevation)
        let key = SIMD3(facing * cos(elevation), sin(elevation))

        // A pointer out of reach adds nothing, wherever it is.
        let pointerReaches = !reduceTransparency
            && weight > 0
            && distance(from: keyLight.position, to: frame) < style.pointerLightReach
        let pointer = pointerReaches
            ? SIMD2(Float(keyLight.position.x - frame.minX), Float(keyLight.position.y - frame.minY))
            : .zero
        // Light under a pointer over this surface leaves through its slopes;
        // from beside it, only what crosses the glass reaches the far ones.
        let pointerInside = pointerReaches && contains(keyLight.position, shape: shape, frame: frame)
        let pointerHighlight = pointerReaches ? Float(intensity.pointer) * weight : 0
        let pointerLeaving = pointerReaches ? Float(pointerInside ? intensity.pointer : intensity.back) * weight : 0

        let icons = reduceTransparency
            ? []
            : bevelEmitters(emitters, shape: shape, frame: frame, sceneBounds: sceneBounds)

        let uniforms = GlassBevelUniforms(
            surface: SIMD4(size.x, size.y, Float(shape.cornerRadius(in: frame.size)), Float(scale)),
            profile: SIMD4(bevel.width, bevel.heightRatio, bevel.profileExponent, bevel.refractiveIndex),
            keyLight: SIMD4(key, Float(intensity.key) * directional),
            keyFacing: SIMD4(facing.x, facing.y, Float(intensity.back) * directional, Float(intensity.edge)),
            pointer: SIMD4(pointer.x, pointer.y, Float(style.pointerLightHeight), pointerHighlight),
            pointerShape: SIMD4(
                Float(style.pointerLightReach),
                pointerLeaving,
                Float(style.keyShininess),
                Float(style.pointerShininess)
            ),
            emitterTuning: SIMD4(
                Float(intensity.emitter),
                Float(style.emitterReach),
                Float(style.facingWrap),
                Float(style.escapeExponent)
            ),
            emitterCore: SIMD4(Float(style.emitterCoreRadius), Float(style.emitterCoreGain), 0, 0),
            output: SIMD4(
                Float(intensity.maxOpacity),
                Float(style.minimumEdgeWidth),
                Float(style.edgeDirectionality),
                Float(icons.count)
            )
        )
        return GlassBevelLighting(uniforms: uniforms, emitters: icons)
    }

    /// The icons that light some part of `frame`, in its own coordinates,
    /// faded as they leave the panel. When more reach it than the shader
    /// takes, the nearest win.
    static func bevelEmitters(
        _ emitters: [GlassLightEmitter],
        shape: GlassRimShape,
        frame: CGRect,
        sceneBounds: CGRect
    ) -> [GlassBevelEmitter] {
        var visible = self.emitters(emitters, reaching: frame).compactMap { emitter -> (GlassLightEmitter, CGFloat)? in
            let visibility = visibility(of: emitter.position, in: sceneBounds)
            return visibility > 0 ? (emitter, visibility) : nil
        }
        if visible.count > GlassLightingStyle.maxEmitters {
            visible = visible.enumerated()
                .sorted { lhs, rhs in
                    let left = distance(from: lhs.element.0.position, to: frame)
                    let right = distance(from: rhs.element.0.position, to: frame)
                    return left == right ? lhs.offset < rhs.offset : left < right
                }
                .prefix(GlassLightingStyle.maxEmitters)
                .map(\.element)
        }
        return visible.map { emitter, visibility in
            let light = emitter.light.color * (emitter.light.strength * visibility)
            return GlassBevelEmitter(
                position: SIMD4(
                    Float(emitter.position.x - frame.minX),
                    Float(emitter.position.y - frame.minY),
                    contains(emitter.position, shape: shape, frame: frame) ? 1 : 0,
                    0
                ),
                light: SIMD4(Float(light.red), Float(light.green), Float(light.blue), 0)
            )
        }
    }

    // MARK: - Reference shading

    struct BevelSample: Equatable {
        /// Linear light, already faded into the plateau.
        var light: SIMD3<Float>
        /// How much of the pixel lies inside the outline.
        var coverage: Float

        static let dark = BevelSample(light: .zero, coverage: 0)
    }

    /// The light on the slope at `point` (the surface's own points). The
    /// shader in `GlassBevelRenderer` computes exactly this, line by line.
    static func bevelLight(at point: SIMD2<Float>, lighting: GlassBevelLighting) -> BevelSample {
        let u = lighting.uniforms
        let scale = u.surface.w
        let outline = GlassOutlinePoint(point, size: SIMD2(u.surface.x, u.surface.y), cornerRadius: u.surface.z)
        let n = outline.normal
        let bevel = GlassBevel(width: u.profile.x, heightRatio: u.profile.y, profileExponent: u.profile.z, refractiveIndex: u.profile.w)

        let coverage = unitClamp(outline.inset * scale + 0.5)
        let across = outline.inset / bevel.width
        guard coverage > 0, across < 1 else { return .dark }
        let s = unitClamp(across)
        let normal = bevel.normal(at: s, outward: n)
        let view = SIMD3<Float>(0, 0, 1)
        let fade = 1 - smoothstep(0.8, 1, s)

        // Fresnel edge, at least the minimum edge width wide.
        let edgeAcross = max(outline.inset - u.output.y, 0) / bevel.width
        let fresnelEdge = bevel.fresnel(cosine: bevel.normal(at: edgeAcross, outward: n).z)
        let facingKey = simd_dot(n, SIMD2(u.keyFacing.x, u.keyFacing.y))
        let directionality = u.output.z
        let edge = u.keyFacing.w * fresnelEdge * ((1 - directionality) + directionality * (0.5 + 0.5 * facingKey))

        let keyDirection = SIMD3(u.keyLight.x, u.keyLight.y, u.keyLight.z)
        let key = u.keyLight.w * pow(max(simd_dot(normal, simd_normalize(keyDirection + view)), 0), u.pointerShape.z)

        // Light leaving the glass gathers where the slope is steep.
        let tiltSine = simd_length(SIMD2(normal.x, normal.y))
        let escape = pow(tiltSine, u.emitterTuning.w) * (1 - bevel.fresnel(cosine: normal.z))
        let back = u.keyFacing.z * pow(max(-facingKey, 0), 2) * escape

        let toPointer = SIMD2(u.pointer.x, u.pointer.y) - point
        let pointerDistance = simd_length(toPointer)
        let reach = windowedFalloff(distance: pointerDistance, range: u.pointerShape.x)
        let pointerDirection = simd_normalize(SIMD3(toPointer, u.pointer.z))
        let pointerHighlight = u.pointer.w
            * pow(max(simd_dot(normal, simd_normalize(pointerDirection + view)), 0), u.pointerShape.w)
            * reach
        let away = pointerDistance > 0.001 ? -simd_dot(n, toPointer) / pointerDistance : 0
        let pointerLeaving = u.pointerShape.y * pow(max(away, 0), 1.5) * reach * escape

        var light = SIMD3<Float>(repeating: edge + key + back + pointerHighlight + pointerLeaving)

        // Icon light seen through the slope: the bent view ray lands further in.
        let sampled = point - n * bevel.refractionOffset(at: s)
        for emitter in lighting.emitters.prefix(Int(u.output.w)) {
            let offset = SIMD2(emitter.position.x, emitter.position.y) - sampled
            let distance = simd_length(offset)
            let glow = windowedFalloff(distance: distance, range: u.emitterTuning.y)
                + u.emitterCore.y * windowedFalloff(distance: distance, range: u.emitterCore.x)
            guard glow > 0 else { continue }
            // An icon on the surface lights it from within; one beside it
            // lights the slopes facing it.
            let toward: Float = emitter.position.z > 0.5 ? -1 : 1
            let cosine = distance > 0.001 ? toward * simd_dot(n, offset) / distance : 1
            let wrap = u.emitterTuning.z
            let facing = max((cosine + wrap) / (1 + wrap), 0)
            light += SIMD3(emitter.light.x, emitter.light.y, emitter.light.z) * (u.emitterTuning.x * glow * facing * escape)
        }
        return BevelSample(light: light * fade, coverage: coverage)
    }

    /// The pixel the shader writes at `point`: color normalized by its peak
    /// and gamma encoded, opacity from the peak, premultiplied.
    static func bevelColor(at point: SIMD2<Float>, lighting: GlassBevelLighting) -> SIMD4<Float> {
        let sample = bevelLight(at: point, lighting: lighting)
        let peak = max(sample.light.x, sample.light.y, sample.light.z)
        guard peak > 0.0001 else { return .zero }
        let alpha = min(lighting.uniforms.output.x, peak) * sample.coverage
        let normalized = sample.light / peak
        return SIMD4(
            encodedSRGB(normalized.x) * alpha,
            encodedSRGB(normalized.y) * alpha,
            encodedSRGB(normalized.z) * alpha,
            alpha
        )
    }

    // MARK: - Relevance

    /// Only icons close enough to light some part of `frame`.
    static func emitters(_ emitters: [GlassLightEmitter], reaching frame: CGRect) -> [GlassLightEmitter] {
        guard frame.width > 0, frame.height > 0 else { return [] }
        return emitters.filter { distance(from: $0.position, to: frame) < GlassLightingStyle.emitterReach }
    }

    /// Distance from a point to the nearest point of a rect (0 inside it).
    static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - Lighting helpers

    /// `(1 - (d/R)²)²`: smooth inverse-square-like falloff that reaches zero at `range`.
    static func windowedFalloff<Value: BinaryFloatingPoint>(distance: Value, range: Value) -> Value {
        guard range > 0, distance < range else { return 0 }
        let ratio = distance / range
        let window = 1 - ratio * ratio
        return window * window
    }

    /// 1 well inside the scene, easing to 0 at its edges and outside it.
    static func visibility(of point: CGPoint, in bounds: CGRect) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return 1 }
        let inset = min(point.x - bounds.minX, bounds.maxX - point.x, point.y - bounds.minY, bounds.maxY - point.y)
        guard inset > 0 else { return 0 }
        let progress = min(inset / GlassLightingStyle.emitterEdgeFade, 1)
        return progress * progress * (3 - 2 * progress)
    }

    /// Metal's `smoothstep`.
    static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let progress = unitClamp((value - edge0) / (edge1 - edge0))
        return progress * progress * (3 - 2 * progress)
    }

    // MARK: - Geometry

    static func contains(_ point: CGPoint, shape: GlassRimShape, frame: CGRect) -> Bool {
        guard frame.contains(point) else { return false }
        let radius = shape.cornerRadius(in: frame.size)
        let dx = max(abs(point.x - frame.midX) - (frame.width / 2 - radius), 0)
        let dy = max(abs(point.y - frame.midY) - (frame.height / 2 - radius), 0)
        return dx * dx + dy * dy <= radius * radius
    }
}
