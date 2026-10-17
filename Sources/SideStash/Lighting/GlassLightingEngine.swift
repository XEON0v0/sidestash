import CoreGraphics
import Foundation

/// Pure lighting math shared by every glass rim.
///
/// A rim is sampled around its perimeter; each sample, with its outward
/// normal, gathers white light from the key light (specular on edges facing
/// it, faint refraction on edges facing away, a constant outline) and colored
/// light from nearby icons (windowed inverse-square falloff, brighter on edges
/// that face the icon). Samples become stops of a conic `CAGradientLayer`.
enum GlassLightingEngine {
    struct RimSample: Equatable, Sendable {
        let position: CGPoint
        let normal: CGVector
    }

    // MARK: - Rim

    static func rimStops(
        shape: GlassRimShape,
        frame: CGRect,
        kind: GlassSurfaceKind,
        keyLight: GlassKeyLight,
        emitters: [GlassLightEmitter],
        sceneBounds: CGRect,
        intensity: GlassLightingStyle.Intensity
    ) -> [GlassRimStop] {
        guard frame.width > 1, frame.height > 1 else {
            let outline = stop(for: LightRGB.white * intensity.ambient, at: 0, maxOpacity: intensity.maxOpacity)
            return [outline, outline.moved(to: 1)]
        }

        var stops = perimeterSamples(of: shape, in: frame, count: GlassLightingStyle.sampleCount(for: kind))
            .map { sample -> GlassRimStop in
                let light = light(
                    at: sample,
                    shape: shape,
                    frame: frame,
                    keyLight: keyLight,
                    emitters: emitters,
                    sceneBounds: sceneBounds,
                    intensity: intensity
                )
                return stop(for: light, at: location(of: sample.position, in: frame), maxOpacity: intensity.maxOpacity)
            }
        stops.sort { $0.location < $1.location }

        // Close the loop: both ends carry the color at the seam.
        guard let first = stops.first, let last = stops.last else { return stops }
        let gap = (1 - last.location) + first.location
        let progress = gap > 0 ? (1 - last.location) / gap : 0
        let seam = GlassRimStop.interpolate(last, first, progress)
        return [seam.moved(to: 0)] + stops + [seam.moved(to: 1)]
    }

    /// Where a scene point (y down) falls in a conic `CAGradientLayer` covering
    /// `frame`: Core Animation sweeps counter-clockwise from the trailing side
    /// in y-up space, measuring angles in the layer's unit square — so they are
    /// normalized by the frame's width and height, not geometric.
    static func location(of point: CGPoint, in frame: CGRect) -> CGFloat {
        guard frame.width > 0, frame.height > 0 else { return 0 }
        let unitX = (point.x - frame.midX) / frame.width
        let unitUp = (frame.midY - point.y) / frame.height
        let angle = atan2(unitUp, unitX)
        return (angle < 0 ? angle + 2 * .pi : angle) / (2 * .pi)
    }

    static func stop(for light: LightRGB, at location: CGFloat, maxOpacity: CGFloat) -> GlassRimStop {
        let peak = light.maxComponent
        guard peak > 0.0001 else {
            return GlassRimStop(location: location, red: 1, green: 1, blue: 1, opacity: 0)
        }
        let normalized = light * (1 / peak)
        return GlassRimStop(
            location: location,
            red: LightRGB.encoded(normalized.red),
            green: LightRGB.encoded(normalized.green),
            blue: LightRGB.encoded(normalized.blue),
            opacity: min(maxOpacity, peak)
        )
    }

    // MARK: - Relevance

    /// A pointer light out of reach of `frame` adds nothing there, so its exact
    /// position doesn't matter: a canonical value keeps distant rims' inputs
    /// unchanged while the pointer moves, so they don't re-render.
    static func effectiveKeyLight(_ keyLight: GlassKeyLight, for frame: CGRect) -> GlassKeyLight {
        guard keyLight.pointerWeight >= 1, frame.width > 0, frame.height > 0 else { return keyLight }
        let distance = distance(from: keyLight.position, to: frame)
        return distance >= GlassLightingStyle.pointerLightReach
            ? GlassKeyLight(position: .zero, pointerWeight: 1)
            : keyLight
    }

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

    // MARK: - Lighting

    static func light(
        at sample: RimSample,
        shape: GlassRimShape,
        frame: CGRect,
        keyLight: GlassKeyLight,
        emitters: [GlassLightEmitter],
        sceneBounds: CGRect,
        intensity: GlassLightingStyle.Intensity
    ) -> LightRGB {
        let key = keyTerms(at: sample, shape: shape, frame: frame, keyLight: keyLight)
        let share = GlassLightingStyle.ambientDirectionalShare
        // While the pointer leads, only a share of the default light remains.
        let directionalWeight = (1 - key.pointerWeight) + key.pointerWeight * share
        let white = intensity.key * key.directionalFront * directionalWeight
            + intensity.back * key.directionalBack * directionalWeight
            + key.pointerWeight * (intensity.pointer * key.pointerFront + intensity.back * key.pointerBack)
            + intensity.ambient
        var total = LightRGB.white * white

        for emitter in emitters {
            let visibility = visibility(of: emitter.position, in: sceneBounds)
            guard visibility > 0 else { continue }

            let dx = emitter.position.x - sample.position.x
            let dy = emitter.position.y - sample.position.y
            let distance = (dx * dx + dy * dy).squareRoot()
            let falloff = windowedFalloff(distance: distance, range: GlassLightingStyle.emitterReach)
            guard falloff > 0 else { continue }

            // An icon inside this shape lights the rim from within.
            let facingNormal = contains(emitter.position, shape: shape, frame: frame)
                ? CGVector(dx: -sample.normal.dx, dy: -sample.normal.dy)
                : sample.normal
            let cosine = distance > 0.001 ? (facingNormal.dx * dx + facingNormal.dy * dy) / distance : 1
            let wrap = GlassLightingStyle.facingWrap
            let facing = max(0, (cosine + wrap) / (1 + wrap))

            let amount = intensity.emitter * emitter.light.strength * falloff * facing * visibility
            total = total + emitter.light.color * amount
        }
        return total
    }

    struct KeyLightTerms: Equatable {
        /// Default top-left light: specular on facing edges, refraction on the far ones.
        let directionalFront: CGFloat
        let directionalBack: CGFloat
        /// Light above the pointer, already faded by distance.
        let pointerFront: CGFloat
        let pointerBack: CGFloat
        let pointerWeight: CGFloat
    }

    /// The key light's terms at one rim sample, before intensity is applied.
    static func keyTerms(
        at sample: RimSample,
        shape: GlassRimShape,
        frame: CGRect,
        keyLight: GlassKeyLight
    ) -> KeyLightTerms {
        let exponent = GlassLightingStyle.specularExponent
        let direction = GlassLightingStyle.defaultKeyLightDirection
        let directionalCosine = sample.normal.dx * direction.dx + sample.normal.dy * direction.dy
        let directionalFront = pow(max(0, directionalCosine), exponent)
        let directionalBack = pow(max(0, -directionalCosine), exponent)

        let weight = min(max(keyLight.pointerWeight, 0), 1)
        guard weight > 0 else {
            return KeyLightTerms(
                directionalFront: directionalFront,
                directionalBack: directionalBack,
                pointerFront: 0,
                pointerBack: 0,
                pointerWeight: 0
            )
        }

        let dx = keyLight.position.x - sample.position.x
        let dy = keyLight.position.y - sample.position.y
        let height = GlassLightingStyle.pointerLightHeight
        let length = (dx * dx + dy * dy + height * height).squareRoot()
        // A pointer over this shape lights its rim from within.
        let facingNormal = contains(keyLight.position, shape: shape, frame: frame)
            ? CGVector(dx: -sample.normal.dx, dy: -sample.normal.dy)
            : sample.normal
        let cosine = (facingNormal.dx * dx + facingNormal.dy * dy) / length
        let reach = windowedFalloff(distance: (dx * dx + dy * dy).squareRoot(), range: GlassLightingStyle.pointerLightReach)
        let pointerExponent = GlassLightingStyle.pointerSpecularExponent

        return KeyLightTerms(
            directionalFront: directionalFront,
            directionalBack: directionalBack,
            pointerFront: pow(max(0, cosine), pointerExponent) * reach,
            pointerBack: pow(max(0, -cosine), pointerExponent) * reach,
            pointerWeight: weight
        )
    }

    /// `(1 - (d/R)²)²`: smooth inverse-square-like falloff that reaches zero at `range`.
    static func windowedFalloff(distance: CGFloat, range: CGFloat) -> CGFloat {
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

    // MARK: - Geometry

    static func contains(_ point: CGPoint, shape: GlassRimShape, frame: CGRect) -> Bool {
        guard frame.contains(point) else { return false }
        let radius = shape.cornerRadius(in: frame.size)
        let dx = max(abs(point.x - frame.midX) - (frame.width / 2 - radius), 0)
        let dy = max(abs(point.y - frame.midY) - (frame.height / 2 - radius), 0)
        return dx * dx + dy * dy <= radius * radius
    }

    /// Points evenly spaced by arc length around the shape, clockwise from the
    /// start of the top edge, each with its outward unit normal.
    static func perimeterSamples(of shape: GlassRimShape, in frame: CGRect, count: Int) -> [RimSample] {
        guard count > 0, frame.width > 0, frame.height > 0 else { return [] }

        let radius = shape.cornerRadius(in: frame.size)
        let horizontal = max(frame.width - 2 * radius, 0)
        let vertical = max(frame.height - 2 * radius, 0)
        let arc = CGFloat.pi / 2 * radius
        let segments: [(length: CGFloat, sample: (CGFloat) -> RimSample)] = [
            (horizontal, { t in
                RimSample(position: CGPoint(x: frame.minX + radius + t, y: frame.minY), normal: CGVector(dx: 0, dy: -1))
            }),
            (arc, { t in
                corner(center: CGPoint(x: frame.maxX - radius, y: frame.minY + radius), radius: radius, from: -.pi / 2, progress: t / max(arc, 0.0001))
            }),
            (vertical, { t in
                RimSample(position: CGPoint(x: frame.maxX, y: frame.minY + radius + t), normal: CGVector(dx: 1, dy: 0))
            }),
            (arc, { t in
                corner(center: CGPoint(x: frame.maxX - radius, y: frame.maxY - radius), radius: radius, from: 0, progress: t / max(arc, 0.0001))
            }),
            (horizontal, { t in
                RimSample(position: CGPoint(x: frame.maxX - radius - t, y: frame.maxY), normal: CGVector(dx: 0, dy: 1))
            }),
            (arc, { t in
                corner(center: CGPoint(x: frame.minX + radius, y: frame.maxY - radius), radius: radius, from: .pi / 2, progress: t / max(arc, 0.0001))
            }),
            (vertical, { t in
                RimSample(position: CGPoint(x: frame.minX, y: frame.maxY - radius - t), normal: CGVector(dx: -1, dy: 0))
            }),
            (arc, { t in
                corner(center: CGPoint(x: frame.minX + radius, y: frame.minY + radius), radius: radius, from: .pi, progress: t / max(arc, 0.0001))
            }),
        ]

        let perimeter = segments.reduce(0) { $0 + $1.length }
        guard perimeter > 0 else { return [] }

        let drawable = segments.filter { $0.length > 0 }
        var samples: [RimSample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            var distance = (CGFloat(index) + 0.5) * perimeter / CGFloat(count)
            var sample: RimSample?
            for segment in drawable {
                if distance <= segment.length {
                    sample = segment.sample(distance)
                    break
                }
                distance -= segment.length
            }
            // Rounding can push the last distance a hair past the end.
            if let sample {
                samples.append(sample)
            } else if let last = drawable.last {
                samples.append(last.sample(last.length))
            }
        }
        return samples
    }

    /// A point on a quarter arc, `progress` 0…1 clockwise from `start` (radians, y down).
    private static func corner(center: CGPoint, radius: CGFloat, from start: CGFloat, progress: CGFloat) -> RimSample {
        let angle = start + .pi / 2 * min(max(progress, 0), 1)
        let normal = CGVector(dx: cos(angle), dy: sin(angle))
        return RimSample(
            position: CGPoint(x: center.x + radius * normal.dx, y: center.y + radius * normal.dy),
            normal: normal
        )
    }
}
