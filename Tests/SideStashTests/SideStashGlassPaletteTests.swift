import AppKit
import Testing
@testable import SideStash

struct SideStashGlassPaletteTests {
    private let light = NSAppearance(named: .aqua)!
    private let dark = NSAppearance(named: .darkAqua)!

    @Test func darkGlassAppearance_coversTheDarkAquaFamily() throws {
        #expect(!light.isDarkGlassAppearance)
        #expect(dark.isDarkGlassAppearance)

        let vibrantDark = try #require(NSAppearance(named: .vibrantDark))
        #expect(vibrantDark.isDarkGlassAppearance)

        if let highContrastDark = NSAppearance(named: .accessibilityHighContrastDarkAqua) {
            #expect(highContrastDark.isDarkGlassAppearance)
        }
        if let highContrastLight = NSAppearance(named: .accessibilityHighContrastAqua) {
            #expect(!highContrastLight.isDarkGlassAppearance)
        }
    }

    @Test func paneTint_isFrostierInLightThanInDark() {
        let lightTint = SideStashGlassPalette.paneTint.resolved(for: light)
        let darkTint = SideStashGlassPalette.paneTint.resolved(for: dark)

        #expect(isClose(lightTint.alphaComponent, 0.28))
        #expect(isClose(darkTint.alphaComponent, 0.12))
        #expect(lightTint.brightnessComponent > darkTint.brightnessComponent)
    }

    @Test func inkOverlays_flipBetweenLightAndDark() {
        let overlays: [(token: SideStashAdaptiveColor, lightAlpha: CGFloat, darkAlpha: CGFloat)] = [
            (SideStashGlassPalette.edgePreviewFill, 0.04, 0.06),
            (SideStashGlassPalette.edgePreviewAccent, 0.12, 0.18),
        ]

        for overlay in overlays {
            let lightColor = overlay.token.resolved(for: light)
            let darkColor = overlay.token.resolved(for: dark)

            #expect(isClose(lightColor.alphaComponent, overlay.lightAlpha))
            #expect(isClose(darkColor.alphaComponent, overlay.darkAlpha))
            // Dark ink on light glass, light ink on dark glass.
            #expect(lightColor.brightnessComponent < 0.5)
            #expect(darkColor.brightnessComponent > 0.5)
        }
    }

    @Test func darkPlates_liftWithAWhiteGlassTint() {
        let tint = SideStashGlassPalette.rowGlassTint.resolved(for: dark)
        let hoverTint = SideStashGlassPalette.rowGlassHoverTint.resolved(for: dark)

        #expect(isClose(tint.alphaComponent, 0.10))
        #expect(isClose(hoverTint.alphaComponent, 0.26))
        #expect(tint.brightnessComponent > 0.9)
        #expect(hoverTint.brightnessComponent > 0.9)
        #expect(SideStashGlassPalette.rowPlateWash.resolved(for: dark).alphaComponent == 0)
        #expect(SideStashGlassPalette.rowPlateHoverWash.resolved(for: dark).alphaComponent == 0)
    }

    @Test func lightPlates_liftWithAWhiteWashInsteadOfATint() {
        // Any tint turns light glass gray, so light plates are washed white instead.
        #expect(SideStashGlassPalette.rowGlassTint.resolved(for: light).alphaComponent == 0)
        #expect(SideStashGlassPalette.rowGlassHoverTint.resolved(for: light).alphaComponent == 0)

        let wash = SideStashGlassPalette.rowPlateWash.resolved(for: light)
        let hoverWash = SideStashGlassPalette.rowPlateHoverWash.resolved(for: light)
        #expect(isClose(wash.alphaComponent, 0.50))
        #expect(isClose(hoverWash.alphaComponent, 0.72))
        #expect(wash.brightnessComponent > 0.9)
        #expect(hoverWash.alphaComponent > wash.alphaComponent)
    }

    @Test func dropTarget_followsAccentColor() {
        let cases: [(token: SideStashAdaptiveColor, lightAlpha: CGFloat, darkAlpha: CGFloat)] = [
            (SideStashGlassPalette.dropTargetFill, 0.10, 0.16),
            (SideStashGlassPalette.dropTargetStroke, 0.45, 0.55),
        ]

        for testCase in cases {
            for (appearance, alpha) in [(light, testCase.lightAlpha), (dark, testCase.darkAlpha)] {
                let color = testCase.token.resolved(for: appearance)
                let accent = SideStashAdaptiveColor(
                    light: { .controlAccentColor },
                    dark: { .controlAccentColor }
                ).resolved(for: appearance)

                #expect(isClose(color.alphaComponent, alpha))
                #expect(isClose(color.redComponent, accent.redComponent))
                #expect(isClose(color.greenComponent, accent.greenComponent))
                #expect(isClose(color.blueComponent, accent.blueComponent))
            }
        }
    }

    @Test func dynamicColor_resolvesForTheCurrentDrawingAppearance() {
        let dynamic = SideStashGlassPalette.edgePreviewAccent.dynamic
        var lightAlpha: CGFloat = 0
        var darkAlpha: CGFloat = 0

        light.performAsCurrentDrawingAppearance { lightAlpha = dynamic.cgColor.alpha }
        dark.performAsCurrentDrawingAppearance { darkAlpha = dynamic.cgColor.alpha }

        #expect(isClose(lightAlpha, 0.12))
        #expect(isClose(darkAlpha, 0.18))
    }

    private func isClose(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.002
    }
}
