import AppKit
import SwiftUI
import Testing
import simd
@testable import SideStash

struct GlassLightingEngineTests {
    private typealias Engine = GlassLightingEngine
    private typealias Intensity = GlassLightingStyle.Intensity

    private let plateFrame = CGRect(x: 12, y: 70, width: 296, height: 44)
    private let plateShape = GlassRimShape.roundedRect(cornerRadius: 12)
    private let sceneBounds = CGRect(x: 0, y: 0, width: 320, height: 420)
    private let blue = IconLight(color: LightRGB(sRGBRed: 0.3, green: 0.6, blue: 1), strength: 1)
    private let red = IconLight(color: LightRGB(sRGBRed: 1, green: 0.4, blue: 0.4), strength: 1)

    // One light at a time, so each can be read directly.
    private let keyOnly = Intensity(key: 1, pointer: 0, back: 0, edge: 0, emitter: 0, maxOpacity: 1)
    private let backOnly = Intensity(key: 0, pointer: 0, back: 1, edge: 0, emitter: 0, maxOpacity: 1)
    private let pointerOnly = Intensity(key: 0, pointer: 1, back: 0, edge: 0, emitter: 0, maxOpacity: 1)
    private let edgeOnly = Intensity(key: 0, pointer: 0, back: 0, edge: 1, emitter: 0, maxOpacity: 1)
    private let emitterOnly = Intensity(key: 0, pointer: 0, back: 0, edge: 0, emitter: 1, maxOpacity: 1)

    /// The plate's top-left corner, where its outline faces the key light,
    /// and the opposite corner; `inset` points in along the outline's normal.
    private func facingKeyLight(_ inset: Float) -> SIMD2<Float> {
        SIMD2(4.8 + 0.6 * inset, 2.4 + 0.8 * inset)
    }

    private func facingAway(_ inset: Float) -> SIMD2<Float> {
        SIMD2(291.2 - 0.6 * inset, 41.6 - 0.8 * inset)
    }

    // MARK: - Key light

    @Test func keyLight_putsAHighlightInsideTheSlopeFacingIt() {
        let lighting = plateLighting(intensity: keyOnly)

        let peak = brightestInset(lighting, along: facingKeyLight)
        // Inside the slope: neither on the outline nor at the plateau.
        #expect(peak > 0.5)
        #expect(peak < 4)
        let highlight = white(at: facingKeyLight(peak), lighting)
        #expect(highlight > 0.8)

        // The slope facing away catches next to none of it.
        #expect(brightest(lighting, along: facingAway) < highlight * 0.05)
    }

    @Test func backLight_leavesTheSlopesFacingAway() {
        let lighting = plateLighting(intensity: backOnly)

        #expect(brightest(lighting, along: facingAway) > 0.3)
        #expect(brightest(lighting, along: facingKeyLight) == 0)

        for scheme in [ColorScheme.light, .dark] {
            for kind in [GlassSurfaceKind.panel, .pill, .plate] {
                let intensity = GlassLightingStyle.intensity(for: kind, colorScheme: scheme)
                #expect(intensity.back < intensity.key)
            }
        }
    }

    // MARK: - Pointer light

    @Test func pointerHighlight_rollsTowardThePlateauAsThePointerComesCloser() {
        func peak(pointerDistance: CGFloat) -> Float {
            let pointer = GlassKeyLight(
                position: CGPoint(x: plateFrame.maxX + pointerDistance, y: plateFrame.midY),
                pointerWeight: 1
            )
            let lighting = plateLighting(intensity: pointerOnly, keyLight: pointer)
            return brightestInset(lighting) { SIMD2(296 - $0, 22) }
        }

        let far = peak(pointerDistance: 100)
        let near = peak(pointerDistance: 12)
        #expect(far > 0.3)
        #expect(near > far + 0.5)
    }

    @Test func pointerOverASurface_lightsItsNearestSlopeFromWithin() {
        let pointer = GlassKeyLight(position: CGPoint(x: plateFrame.minX + 30, y: plateFrame.midY), pointerWeight: 1)
        let lighting = plateLighting(intensity: pointerOnly, keyLight: pointer)

        let leading = brightest(lighting) { SIMD2($0, 22) }
        let trailing = brightest(lighting) { SIMD2(296 - $0, 22) }
        #expect(leading > 0.2)
        #expect(leading > trailing * 4)
    }

    @Test func pointerLight_visiblyBrightensNativeGlassBevels() {
        // The pill's leading end, with the pointer just beside it.
        let pillFrame = CGRect(x: 94, y: 364, width: 132, height: 40)
        let pointer = GlassKeyLight(position: CGPoint(x: pillFrame.minX - 30, y: pillFrame.midY), pointerWeight: 1)

        for scheme in [ColorScheme.light, .dark] {
            let intensity = GlassLightingStyle.intensity(for: .pill, colorScheme: scheme)
            func brightestLeadingEnd(_ keyLight: GlassKeyLight) -> Float {
                let lighting = Engine.lighting(
                    shape: .capsule,
                    frame: pillFrame,
                    kind: .pill,
                    keyLight: keyLight,
                    emitters: [],
                    sceneBounds: sceneBounds,
                    intensity: intensity,
                    reduceTransparency: false,
                    scale: 2
                )
                return brightest(lighting) { SIMD2($0, 20) }
            }

            #expect(brightestLeadingEnd(pointer) > brightestLeadingEnd(.default) + 0.25)
        }
    }

    // MARK: - Icon lights

    @Test func iconOnAPlate_lightsItsNearSlopeFromWithin() {
        let icon = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)
        let lighting = plateLighting(intensity: emitterOnly, emitters: [icon])

        let leading = Engine.bevelLight(at: SIMD2(1, 22), lighting: lighting).light
        let trailing = Engine.bevelLight(at: SIMD2(295, 22), lighting: lighting).light
        #expect(leading.z > 0.3)
        #expect(leading.z > leading.x)
        #expect(trailing == .zero)
    }

    @Test func refraction_pullsAnIconsLightOutOntoTheSlope() {
        let icon = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)
        var bent = plateLighting(intensity: emitterOnly, emitters: [icon])
        // The icon's core alone falls off fast enough to show the shift.
        bent.uniforms.emitterTuning.y = 0
        var straight = bent
        straight.uniforms.profile.w = 1

        let slope = SIMD2<Float>(1, 22)
        let refracted = Engine.bevelLight(at: slope, lighting: bent).light.z
        let unrefracted = Engine.bevelLight(at: slope, lighting: straight).light.z
        #expect(refracted > unrefracted * 1.3)
    }

    @Test func iconAboveAPlate_lightsItsTopSlopeMoreThanItsBottom() {
        let neighbor = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.minY - 28), light: blue)
        let lighting = plateLighting(intensity: emitterOnly, emitters: [neighbor])

        let top = Engine.bevelLight(at: SIMD2(24, 1), lighting: lighting).light.z
        let bottom = Engine.bevelLight(at: SIMD2(24, 43), lighting: lighting).light.z
        #expect(top > 0.1)
        #expect(top > bottom * 4)
    }

    @Test func iconsBeyondReachOrOutsideThePanel_addNoLight() {
        let farAway = GlassLightEmitter(
            position: CGPoint(x: plateFrame.minX + 7 + GlassLightingStyle.emitterReach, y: plateFrame.midY),
            light: blue
        )
        let outsidePanel = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: -10), light: blue)

        let lighting = plateLighting(intensity: emitterOnly, emitters: [farAway])
        #expect(Engine.bevelLight(at: SIMD2(1, 22), lighting: lighting).light == .zero)
        #expect(plateLighting(intensity: emitterOnly, emitters: [outsidePanel]).emitters.isEmpty)
    }

    @Test func iconsFadeOutNearThePanelEdge() {
        #expect(Engine.visibility(of: CGPoint(x: 160, y: 200), in: sceneBounds) == 1)
        let nearEdge = Engine.visibility(of: CGPoint(x: 160, y: 4), in: sceneBounds)
        #expect(nearEdge > 0)
        #expect(nearEdge < 1)
        #expect(Engine.visibility(of: CGPoint(x: 160, y: -4), in: sceneBounds) == 0)
    }

    @Test func overlappingIconLights_mixTheirColors() {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let emitters = [
            GlassLightEmitter(position: CGPoint(x: 80, y: 30), light: red),
            GlassLightEmitter(position: CGPoint(x: 120, y: 30), light: blue),
        ]
        let lighting = Engine.lighting(
            shape: .roundedRect(cornerRadius: 12),
            frame: frame,
            kind: .plate,
            keyLight: .default,
            emitters: emitters,
            sceneBounds: sceneBounds,
            intensity: emitterOnly,
            reduceTransparency: false,
            scale: 2
        )

        let mixed = Engine.bevelLight(at: SIMD2(100, 1), lighting: lighting).light
        #expect(mixed.x > mixed.y)
        #expect(mixed.z > mixed.y)
    }

    @Test func windowedFalloff_isFullAtTheSourceAndZeroAtTheRange() {
        #expect(Engine.windowedFalloff(distance: 0, range: 100) == 1)
        #expect(Engine.windowedFalloff(distance: 100, range: 100) == 0)
        #expect(Engine.windowedFalloff(distance: 30, range: 100) > Engine.windowedFalloff(distance: 60, range: 100))
    }

    // MARK: - Relevance

    @Test func distantPointers_lightSurfacesIdentically() {
        let reach = GlassLightingStyle.pointerLightReach
        let intensity = GlassLightingStyle.intensity(for: .plate, colorScheme: .dark)
        let near = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + 20, y: plateFrame.midY), pointerWeight: 1)
        let farA = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + reach + 10, y: plateFrame.midY), pointerWeight: 1)
        let farB = GlassKeyLight(position: CGPoint(x: plateFrame.maxX + reach + 60, y: plateFrame.minY), pointerWeight: 1)

        // Out of reach, the pointer's position changes nothing, so nothing redraws.
        #expect(plateLighting(intensity: intensity, keyLight: farA) == plateLighting(intensity: intensity, keyLight: farB))
        #expect(plateLighting(intensity: intensity, keyLight: farA).uniforms.pointer.w == 0)
        #expect(plateLighting(intensity: intensity, keyLight: near) != plateLighting(intensity: intensity, keyLight: farA))
    }

    @Test func surfaces_onlyReceiveIconsThatReachThem() {
        let inside = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)
        let nearby = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.maxY + 30), light: blue)
        let distant = GlassLightEmitter(
            position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.maxY + GlassLightingStyle.emitterReach + 1),
            light: blue
        )

        let lit = Engine.bevelEmitters([inside, nearby, distant], shape: plateShape, frame: plateFrame, sceneBounds: sceneBounds)
        // In the plate's own coordinates, flagged when on the plate.
        #expect(lit.map(\.position) == [SIMD4(24, 22, 1, 0), SIMD4(24, 74, 0, 0)])
        #expect(Engine.bevelEmitters([inside], shape: plateShape, frame: .zero, sceneBounds: sceneBounds).isEmpty)
    }

    @Test func manyIcons_leaveTheFarthestOut() {
        let icons = (0..<20).map { index in
            GlassLightEmitter(
                position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.maxY + 2 + CGFloat(19 - index) * 5),
                light: blue
            )
        }

        let lit = Engine.bevelEmitters(icons, shape: plateShape, frame: plateFrame, sceneBounds: sceneBounds)
        #expect(lit.count == GlassLightingStyle.maxEmitters)
        // The four farthest, 97…82 pt below the plate, are left out.
        #expect(lit.map(\.position.y).max() == Float(44 + 77))
    }

    @Test func reduceTransparency_keepsOnlyAPlainEdge() {
        let intensity = GlassLightingStyle.intensity(for: .plate, colorScheme: .dark)
        let icon = GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue)
        let pointer = GlassKeyLight(position: CGPoint(x: plateFrame.minX + 40, y: plateFrame.midY), pointerWeight: 1)
        let lighting = plateLighting(intensity: intensity, keyLight: pointer, emitters: [icon], reduceTransparency: true)

        #expect(lighting.emitters.isEmpty)
        let edge = Engine.bevelLight(at: SIMD2(148, 0.25), lighting: lighting).light
        #expect(edge.x > 0.1)
        #expect(edge.x == edge.y && edge.y == edge.z)
        #expect(white(at: SIMD2(148, 3), lighting) < edge.x * 0.1)

        // The pointer moving changes nothing.
        let moved = GlassKeyLight(position: CGPoint(x: 60, y: 80), pointerWeight: 1)
        #expect(plateLighting(intensity: intensity, keyLight: moved, emitters: [icon], reduceTransparency: true) == lighting)
    }

    // MARK: - Slope and plateau

    @Test func plateau_staysDarkAndTheSlopeFadesIntoIt() {
        let lighting = plateLighting(intensity: GlassLightingStyle.intensity(for: .plate, colorScheme: .light))

        #expect(Engine.bevelLight(at: SIMD2(148, 7), lighting: lighting).light == .zero)
        #expect(white(at: SIMD2(148, 5.9), lighting) < 0.02)
    }

    @Test func bevelColor_normalizesColorCapsOpacityAndSmoothsTheOutline() {
        let lighting = plateLighting(intensity: edgeOnly)

        let edge = Engine.bevelColor(at: SIMD2(148, 0.25), lighting: lighting)
        #expect(abs(edge.w - 0.95) < 0.001)
        // White, premultiplied.
        #expect(abs(edge.x - edge.w) < 0.001)

        var capped = lighting
        capped.uniforms.output.x = 0.5
        #expect(abs(Engine.bevelColor(at: SIMD2(148, 0.25), lighting: capped).w - 0.5) < 0.001)

        // A pixel straddling the outline is partly covered; one outside isn't drawn.
        let straddling = Engine.bevelColor(at: SIMD2(148, -0.1), lighting: lighting).w
        #expect(straddling > 0)
        #expect(straddling < edge.w)
        #expect(Engine.bevelColor(at: SIMD2(148, -1), lighting: lighting) == .zero)
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

    @Test func bevels_fitTheirSurfaces() {
        // The panel's slope stays out from under the plates.
        #expect(CGFloat(GlassLightingStyle.bevel(for: .panel).width) <= SideStashSidebarStyle.fileListInset)
        #expect(CGFloat(GlassLightingStyle.bevel(for: .plate).width) < SideStashSidebarStyle.rowCornerRadius)
        #expect(CGFloat(GlassLightingStyle.bevel(for: .pill).width) <= SideStashSidebarChromePolicy.bottomActionsHeight / 2)
        // The header pill borrows the plate bevel; it must fit its 28 pt capsule.
        #expect(CGFloat(GlassLightingStyle.bevel(for: .plate).width) < SideStashSidebarChromePolicy.moreActionsHeight / 2)
        // A tight, Apple-like edge everywhere.
        for kind in [GlassSurfaceKind.panel, .pill, .plate] {
            #expect(GlassLightingStyle.bevel(for: kind).profileExponent == 4)
        }
    }

    // MARK: - Helpers

    private func plateLighting(
        intensity: Intensity,
        keyLight: GlassKeyLight = .default,
        emitters: [GlassLightEmitter] = [],
        reduceTransparency: Bool = false
    ) -> GlassBevelLighting {
        Engine.lighting(
            shape: plateShape,
            frame: plateFrame,
            kind: .plate,
            keyLight: keyLight,
            emitters: emitters,
            sceneBounds: sceneBounds,
            intensity: intensity,
            reduceTransparency: reduceTransparency,
            scale: 2
        )
    }

    private func white(at point: SIMD2<Float>, _ lighting: GlassBevelLighting) -> Float {
        Engine.bevelLight(at: point, lighting: lighting).light.x
    }

    private var slopeInsets: [Float] {
        Array(stride(from: Float(0.05), to: 6, by: 0.05))
    }

    /// The brightest white light across a slope, sampled `point(inset)`.
    private func brightest(_ lighting: GlassBevelLighting, along point: (Float) -> SIMD2<Float>) -> Float {
        slopeInsets.map { white(at: point($0), lighting) }.max() ?? 0
    }

    /// How far in from the outline the white light peaks across a slope.
    private func brightestInset(_ lighting: GlassBevelLighting, along point: (Float) -> SIMD2<Float>) -> Float {
        slopeInsets.max { white(at: point($0), lighting) < white(at: point($1), lighting) } ?? 0
    }
}
