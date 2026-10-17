import AppKit
import SwiftUI
import Testing
@testable import SideStash

@MainActor
struct FileGlassRowTests {
    private let blue = NSColor(srgbRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)
    private let red = NSColor(srgbRed: 0.92, green: 0.18, blue: 0.16, alpha: 1)

    @Test func light_ofAColorfulIconMatchesItsHue() throws {
        let light = try #require(IconLightSampler.light(from: icon { rect in
            blue.setFill()
            rect.fill()
        }))
        let color = sRGB(of: light)

        #expect(isClose(color.hueComponent, blue.hueComponent))
        // Emitted light is bright, whatever the icon's shading.
        #expect(isClose(color.brightnessComponent, 1))
        #expect(color.saturationComponent >= IconLightStyle.minLightSaturation - 0.01)
        #expect(color.saturationComponent <= IconLightStyle.maxLightSaturation + 0.01)
    }

    @Test func light_ofAWhiteDocumentComesFromItsColoredBadge() throws {
        let light = try #require(IconLightSampler.light(from: icon { rect in
            NSColor.white.setFill()
            rect.fill()
            red.setFill()
            NSRect(x: 0, y: 0, width: rect.width / 3, height: rect.height / 3).fill()
        }))
        let color = sRGB(of: light)

        let hue = color.hueComponent
        #expect(hue < 0.05 || hue > 0.95)
        // Red light is kept paler than other hues.
        #expect(color.saturationComponent <= IconLightStyle.maxRedLightSaturation + 0.01)
    }

    @Test func lightStrength_growsWithHowColorfulTheIconIs() throws {
        let badge = try #require(IconLightSampler.light(from: icon { rect in
            NSColor.white.setFill()
            rect.fill()
            blue.setFill()
            NSRect(x: 0, y: 0, width: rect.width / 3, height: rect.height / 3).fill()
        }))
        let solid = try #require(IconLightSampler.light(from: icon { rect in
            blue.setFill()
            rect.fill()
        }))

        #expect(badge.strength < solid.strength)
        #expect(badge.strength >= IconLightStyle.minStrength)
        #expect(solid.strength <= 1)
    }

    @Test func lightSaturation_capsRedsLowerAndEasesBack() {
        let style = IconLightStyle.self

        #expect(style.maxSaturation(forHue: 0) == style.maxRedLightSaturation)
        #expect(style.maxSaturation(forHue: 0.99) == style.maxRedLightSaturation)
        #expect(style.maxSaturation(forHue: 0.6) == style.maxLightSaturation)
        #expect(style.maxSaturation(forHue: 0.1) == style.maxLightSaturation)

        let easing = style.maxSaturation(forHue: 0.065)
        #expect(easing > style.maxRedLightSaturation)
        #expect(easing < style.maxLightSaturation)
        #expect(style.maxRedLightSaturation >= style.minLightSaturation)
    }

    @Test func light_isNilForIconsWithoutColor() {
        let gray = IconLightSampler.light(from: icon { rect in
            NSColor(srgbRed: 0.6, green: 0.6, blue: 0.62, alpha: 1).setFill()
            rect.fill()
        })
        let transparent = IconLightSampler.light(from: icon { _ in })

        #expect(gray == nil)
        #expect(transparent == nil)
    }

    @Test func plateScale_prioritizesLiftThenPressThenHover() {
        #expect(FileRowPlateStyle.scale(for: FileRowInteraction()) == 1)
        #expect(FileRowPlateStyle.scale(for: FileRowInteraction(isHovered: true)) == FileRowPlateStyle.hoverScale)
        #expect(FileRowPlateStyle.scale(for: FileRowInteraction(isHovered: true, isPressed: true)) == FileRowPlateStyle.pressedScale)
        #expect(
            FileRowPlateStyle.scale(for: FileRowInteraction(isHovered: true, isPressed: true, isLifted: true))
                == InteractionMotionStyle.dragLiftScale
        )
        #expect(FileRowPlateStyle.hoverScale > 1)
        #expect(FileRowPlateStyle.pressedScale < 1)
    }

    @Test func plateOpacity_fadesOnlyWhileLifted() {
        #expect(FileRowPlateStyle.opacity(for: FileRowInteraction(isHovered: true, isPressed: true)) == 1)
        #expect(isClose(
            FileRowPlateStyle.opacity(for: FileRowInteraction(isLifted: true)),
            InteractionMotionStyle.dragLiftAlpha
        ))
    }

    private func icon(_ draw: @escaping (NSRect) -> Void) -> NSImage {
        NSImage(size: NSSize(width: 48, height: 48), flipped: false) { rect in
            draw(rect)
            return true
        }
    }

    private func sRGB(of light: IconLight) -> NSColor {
        NSColor(
            srgbRed: LightRGB.encoded(light.color.red),
            green: LightRGB.encoded(light.color.green),
            blue: LightRGB.encoded(light.color.blue),
            alpha: 1
        )
    }

    private func isClose(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.03
    }
}
