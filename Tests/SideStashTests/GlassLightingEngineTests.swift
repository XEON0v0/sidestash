import AppKit
import SwiftUI
import Testing
@testable import SideStash

struct GlassLightingEngineTests {
    private typealias Engine = GlassLightingEngine
    private let plateFrame = CGRect(x: 12, y: 70, width: 296, height: 44)
    private let plateShape = GlassRimShape.roundedRect(cornerRadius: 12)
    private let blue = IconLight(color: LightRGB(sRGBRed: 0.3, green: 0.6, blue: 1), strength: 1)
    private let red = IconLight(color: LightRGB(sRGBRed: 1, green: 0.4, blue: 0.4), strength: 1)
    /// Colored light only, so emitter behavior can be read directly.
    private let emitterOnly = GlassLightingStyle.Intensity(key: 0, pointer: 0, back: 0, ambient: 0, emitter: 1, refractionBand: 0, maxOpacity: 1)
    /// White light only.
    private let keyOnly = GlassLightingStyle.Intensity(key: 1, pointer: 1, back: 1, ambient: 0, emitter: 0, refractionBand: 0, maxOpacity: 1)

    // MARK: - Perimeter

    @Test func perimeterSamples_lieOnTheOutlineWithOutwardUnitNormals() {
        for (shape, frame) in [(plateShape, plateFrame), (GlassRimShape.capsule, CGRect(x: 94, y: 364, width: 132, height: 40))] {
            let samples = Engine.perimeterSamples(of: shape, in: frame, count: 48)
            let radius = shape.cornerRadius(in: frame.size)
            let center = CGPoint(x: frame.midX, y: frame.midY)

            #expect(samples.count == 48)
            for sample in samples {
                // On the outline: outside distance of the rounded rect is zero.
                let dx = max(abs(sample.position.x - center.x) - (frame.width / 2 - radius), 0)
                let dy = max(abs(sample.position.y - center.y) - (frame.height / 2 - radius), 0)
                let onEdge = abs(sample.position.x - frame.minX) < 0.01
                    || abs(sample.position.x - frame.maxX) < 0.01
                    || abs(sample.position.y - frame.minY) < 0.01
                    || abs(sample.position.y - frame.maxY) < 0.01
                    || abs((dx * dx + dy * dy).squareRoot() - radius) < 0.01
                #expect(onEdge)

                let length = (sample.normal.dx * sample.normal.dx + sample.normal.dy * sample.normal.dy).squareRoot()
                #expect(abs(length - 1) < 0.001)
                let outward = sample.normal.dx * (sample.position.x - center.x) + sample.normal.dy * (sample.position.y - center.y)
                #expect(outward > 0)
            }
        }
    }

    @Test func contains_respectsRoundedCorners() {
        #expect(Engine.contains(CGPoint(x: plateFrame.midX, y: plateFrame.midY), shape: plateShape, frame: plateFrame))
        #expect(Engine.contains(CGPoint(x: plateFrame.minX + 1, y: plateFrame.midY), shape: plateShape, frame: plateFrame))
        // The very corner is cut off by the 12 pt radius.
        #expect(!Engine.contains(CGPoint(x: plateFrame.minX + 1, y: plateFrame.minY + 1), shape: plateShape, frame: plateFrame))
        #expect(!Engine.contains(CGPoint(x: plateFrame.midX, y: plateFrame.minY - 1), shape: plateShape, frame: plateFrame))
    }

    // MARK: - Key light

    @Test func defaultKeyLight_brightensTopLeftAndFaintlyRefractsBottomRight() {
        let topLeft = sample(normal: CGVector(dx: -0.707, dy: -0.707), at: CGPoint(x: plateFrame.minX + 3.5, y: plateFrame.minY + 3.5))
        let bottomRight = sample(normal: CGVector(dx: 0.707, dy: 0.707), at: CGPoint(x: plateFrame.maxX - 3.5, y: plateFrame.maxY - 3.5))

        let front = Engine.keyTerms(at: topLeft, shape: plateShape, frame: plateFrame, keyLight: .default)
        let back = Engine.keyTerms(at: bottomRight, shape: plateShape, frame: plateFrame, keyLight: .default)

        #expect(front.directionalFront > 0.8)
        #expect(front.directionalBack == 0)
        #expect(back.directionalFront == 0)
        #expect(back.directionalBack > 0.8)
        #expect(front.pointerWeight == 0)

        for scheme in [ColorScheme.light, .dark] {
            for kind in [GlassSurfaceKind.panel, .pill, .plate] {
                let intensity = GlassLightingStyle.intensity(for: kind, colorScheme: scheme)
                #expect(intensity.back < intensity.key)
            }
        }
    }

    @Test func pointerKeyLight_brightensTheEdgesFacingIt() {
        let pointer = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + 40, y: plateFrame.midY), pointerWeight: 1)
        let rightEdge = sample(normal: CGVector(dx: 1, dy: 0), at: CGPoint(x: plateFrame.maxX, y: plateFrame.midY))
        let leftEdge = sample(normal: CGVector(dx: -1, dy: 0), at: CGPoint(x: plateFrame.minX, y: plateFrame.midY))

        let right = Engine.keyTerms(at: rightEdge, shape: plateShape, frame: plateFrame, keyLight: pointer)
        let left = Engine.keyTerms(at: leftEdge, shape: plateShape, frame: plateFrame, keyLight: pointer)

        #expect(right.pointerFront > 0.3)
        // The edge facing away from the pointer gets none of its specular.
        #expect(left.pointerFront == 0)
    }

    @Test func pointerLight_visiblyBrightensNativeGlassRims() {
        // The pill's leading end, with the pointer just beside it.
        let pillFrame = CGRect(x: 94, y: 364, width: 132, height: 40)
        let leadingEnd = sample(normal: CGVector(dx: -1, dy: 0), at: CGPoint(x: pillFrame.minX, y: pillFrame.midY))
        let pointer = GlassKeyLight(position: CGPoint(x: pillFrame.minX - 30, y: pillFrame.midY), pointerWeight: 1)

        for scheme in [ColorScheme.light, .dark] {
            let intensity = GlassLightingStyle.intensity(for: .pill, colorScheme: scheme)
            func white(_ keyLight: GlassKeyLight) -> CGFloat {
                Engine.light(
                    at: leadingEnd,
                    shape: .capsule,
                    frame: pillFrame,
                    keyLight: keyLight,
                    emitters: [],
                    sceneBounds: CGRect(x: 0, y: 0, width: 320, height: 420),
                    intensity: intensity
                ).maxComponent
            }

            #expect(white(pointer) > white(.default) + 0.25)
        }
    }

    @Test func pointerKeyLight_fadesWithDistance() {
        let edge = sample(normal: CGVector(dx: 1, dy: 0), at: CGPoint(x: plateFrame.maxX, y: plateFrame.midY))
        let near = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + 40, y: plateFrame.midY), pointerWeight: 1)
        let far = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + 240, y: plateFrame.midY), pointerWeight: 1)

        let nearFront = Engine.keyTerms(at: edge, shape: plateShape, frame: plateFrame, keyLight: near).pointerFront
        let farFront = Engine.keyTerms(at: edge, shape: plateShape, frame: plateFrame, keyLight: far).pointerFront
        #expect(nearFront > farFront)
    }

    // MARK: - Icon lights

    @Test func iconInsideAPlate_lightsItsNearEdgeFromWithin() {
        let icon = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)
        let leftEdge = sample(normal: CGVector(dx: -1, dy: 0), at: CGPoint(x: plateFrame.minX, y: plateFrame.midY))
        let rightEdge = sample(normal: CGVector(dx: 1, dy: 0), at: CGPoint(x: plateFrame.maxX, y: plateFrame.midY))

        let left = light(at: leftEdge, emitters: [icon])
        let right = light(at: rightEdge, emitters: [icon])

        #expect(left.blue > 0.5)
        #expect(right.maxComponent == 0)
    }

    @Test func iconAboveAPlate_lightsItsTopEdgeMoreThanItsBottom() {
        let neighbor = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.minY - 28), light: blue)
        let topEdge = sample(normal: CGVector(dx: 0, dy: -1), at: CGPoint(x: plateFrame.minX + 24, y: plateFrame.minY))
        let bottomEdge = sample(normal: CGVector(dx: 0, dy: 1), at: CGPoint(x: plateFrame.minX + 24, y: plateFrame.maxY))

        #expect(light(at: topEdge, emitters: [neighbor]).blue > light(at: bottomEdge, emitters: [neighbor]).blue)
    }

    @Test func iconsBeyondReachOrOutsideThePanel_addNoLight() {
        let edge = sample(normal: CGVector(dx: -1, dy: 0), at: CGPoint(x: plateFrame.minX, y: plateFrame.midY))
        let farAway = GlassLightEmitter(
            position: CGPoint(x: plateFrame.minX + GlassLightingStyle.emitterReach + 1, y: plateFrame.midY),
            light: blue
        )
        let outsidePanel = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: -10), light: blue)

        #expect(light(at: edge, emitters: [farAway]).maxComponent == 0)
        #expect(light(at: edge, emitters: [outsidePanel]).maxComponent == 0)
    }

    @Test func iconsFadeOutNearThePanelEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 420)

        #expect(Engine.visibility(of: CGPoint(x: 160, y: 200), in: bounds) == 1)
        let nearEdge = Engine.visibility(of: CGPoint(x: 160, y: 4), in: bounds)
        #expect(nearEdge > 0)
        #expect(nearEdge < 1)
        #expect(Engine.visibility(of: CGPoint(x: 160, y: -4), in: bounds) == 0)
    }

    @Test func overlappingIconLights_mixTheirColors() {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let topEdge = sample(normal: CGVector(dx: 0, dy: -1), at: CGPoint(x: 100, y: 0))
        let emitters = [
            GlassLightEmitter(position: CGPoint(x: 80, y: 30), light: red),
            GlassLightEmitter(position: CGPoint(x: 120, y: 30), light: blue),
        ]

        let mixed = Engine.light(
            at: topEdge,
            shape: .roundedRect(cornerRadius: 12),
            frame: frame,
            keyLight: .default,
            emitters: emitters,
            sceneBounds: CGRect(x: 0, y: 0, width: 320, height: 420),
            intensity: emitterOnly
        )

        #expect(mixed.red > mixed.green)
        #expect(mixed.blue > mixed.green)
    }

    @Test func windowedFalloff_isFullAtTheSourceAndZeroAtTheRange() {
        #expect(Engine.windowedFalloff(distance: 0, range: 100) == 1)
        #expect(Engine.windowedFalloff(distance: 100, range: 100) == 0)
        #expect(Engine.windowedFalloff(distance: 30, range: 100) > Engine.windowedFalloff(distance: 60, range: 100))
    }

    // MARK: - Relevance

    @Test func distantRims_seeACanonicalKeyLight() {
        let reach = GlassLightingStyle.pointerLightReach
        let near = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + 20, y: plateFrame.midY), pointerWeight: 1)
        let farA = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + reach + 10, y: plateFrame.midY), pointerWeight: 1)
        let farB = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + reach + 60, y: plateFrame.minY), pointerWeight: 1)
        let entering = GlassKeyLight(position: farA.position, pointerWeight: 0.5)

        #expect(Engine.effectiveKeyLight(near, for: plateFrame) == near)
        // Out of reach, any pointer position lights the rim identically.
        #expect(Engine.effectiveKeyLight(farA, for: plateFrame) == Engine.effectiveKeyLight(farB, for: plateFrame))
        // While gliding in or out, the light is passed through untouched.
        #expect(Engine.effectiveKeyLight(entering, for: plateFrame) == entering)
    }

    @Test func rims_onlyReceiveIconsThatReachThem() {
        let inside = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)
        let nearby = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.maxY + 30), light: blue)
        let distant = GlassLightEmitter(
            position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.maxY + GlassLightingStyle.emitterReach + 1),
            light: blue
        )

        #expect(Engine.emitters([inside, nearby, distant], reaching: plateFrame) == [inside, nearby])
        #expect(Engine.distance(from: inside.position, to: plateFrame) == 0)
        #expect(Engine.emitters([inside], reaching: .zero).isEmpty)
    }

    // MARK: - Stops

    @Test func rimStops_wrapAroundTheShapeInOrder() {
        let stops = Engine.rimStops(
            shape: plateShape,
            frame: plateFrame,
            kind: .plate,
            keyLight: .default,
            emitters: [GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)],
            sceneBounds: CGRect(x: 0, y: 0, width: 320, height: 420),
            intensity: GlassLightingStyle.intensity(for: .plate, colorScheme: .dark)
        )

        #expect(stops.count == GlassLightingStyle.sampleCount(for: .plate) + 2)
        #expect(stops.first?.location == 0)
        #expect(stops.last?.location == 1)
        #expect(zip(stops, stops.dropFirst()).allSatisfy { $0.location <= $1.location })
        if let first = stops.first, let last = stops.last {
            #expect(first.moved(to: 1) == last)
        }
    }

    @Test func stop_normalizesColorAndCapsOpacity() {
        let white = Engine.stop(for: LightRGB.white * 0.3, at: 0.5, maxOpacity: 0.9)
        #expect(abs(white.opacity - 0.3) < 0.0001)
        #expect(abs(white.red - 1) < 0.0001)

        let bright = Engine.stop(for: LightRGB.white * 4, at: 0.5, maxOpacity: 0.9)
        #expect(bright.opacity == 0.9)

        #expect(Engine.stop(for: .zero, at: 0.5, maxOpacity: 0.9).opacity == 0)
    }

    @Test func location_followsCoreAnimationsConicSweep() {
        let frame = CGRect(x: 0, y: 0, width: 296, height: 44)

        // Counter-clockwise from the trailing side, as seen on screen.
        #expect(abs(Engine.location(of: CGPoint(x: 296, y: 22), in: frame) - 0) < 0.0001)
        #expect(abs(Engine.location(of: CGPoint(x: 148, y: 0), in: frame) - 0.25) < 0.0001)
        #expect(abs(Engine.location(of: CGPoint(x: 0, y: 22), in: frame) - 0.5) < 0.0001)
        #expect(abs(Engine.location(of: CGPoint(x: 148, y: 44), in: frame) - 0.75) < 0.0001)

        // Angles are measured in the layer's unit square, not geometrically.
        let normalized = atan2(0.5, 52.0 / 296.0) / (2 * .pi)
        #expect(abs(Engine.location(of: CGPoint(x: 200, y: 0), in: frame) - normalized) < 0.0001)
    }

    @Test func surfaceGains_letPlatesLeadAndNativeGlassFollow() {
        for scheme in [ColorScheme.light, .dark] {
            let plate = GlassLightingStyle.intensity(for: .plate, colorScheme: scheme)
            let pill = GlassLightingStyle.intensity(for: .pill, colorScheme: scheme)
            let panel = GlassLightingStyle.intensity(for: .panel, colorScheme: scheme)

            #expect(plate.emitter > pill.emitter)
            #expect(pill.emitter > panel.emitter)
            #expect(plate.key > pill.key)
            #expect(pill.key > panel.key)
        }
        for kind in [GlassSurfaceKind.panel, .pill, .plate] {
            #expect(
                GlassLightingStyle.intensity(for: kind, colorScheme: .light).key
                    > GlassLightingStyle.intensity(for: kind, colorScheme: .dark).key
            )
        }
    }

    // MARK: - Helpers

    private func sample(normal: CGVector, at position: CGPoint) -> Engine.RimSample {
        let length = (normal.dx * normal.dx + normal.dy * normal.dy).squareRoot()
        return Engine.RimSample(position: position, normal: CGVector(dx: normal.dx / length, dy: normal.dy / length))
    }

    private func light(at sample: Engine.RimSample, emitters: [GlassLightEmitter]) -> LightRGB {
        Engine.light(
            at: sample,
            shape: plateShape,
            frame: plateFrame,
            keyLight: .default,
            emitters: emitters,
            sceneBounds: CGRect(x: 0, y: 0, width: 320, height: 420),
            intensity: emitterOnly
        )
    }
}
