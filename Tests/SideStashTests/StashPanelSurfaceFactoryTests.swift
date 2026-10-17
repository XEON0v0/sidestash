import AppKit
import Testing
@testable import SideStash

@MainActor
struct StashPanelSurfaceFactoryTests {
    @Test func make_hostsContentInsideOneRegularGlassSurface() {
        let frame = NSRect(x: 0, y: 0, width: 320, height: 420)
        let contentView = NSView(frame: frame)

        let surface = StashPanelSurfaceFactory.make(frame: frame, contentView: contentView)

        #expect(surface.style == .regular)
        #expect(surface.cornerRadius == 24)
        #expect(surface.contentView === contentView)
        #expect(surface.frame == frame)
        #expect(surface.autoresizingMask.contains(.width))
        #expect(surface.autoresizingMask.contains(.height))
    }

    @Test func tint_followsLightAndDarkAppearance() throws {
        let frame = NSRect(x: 0, y: 0, width: 320, height: 420)
        let surface = StashPanelSurfaceFactory.make(frame: frame, contentView: NSView(frame: frame))

        surface.appearance = NSAppearance(named: .aqua)
        surface.viewDidChangeEffectiveAppearance()
        let lightTint = try #require(surface.tintColor)
        #expect(abs(lightTint.alphaComponent - 0.28) < 0.002)

        surface.appearance = NSAppearance(named: .darkAqua)
        surface.viewDidChangeEffectiveAppearance()
        let darkTint = try #require(surface.tintColor)
        #expect(abs(darkTint.alphaComponent - 0.12) < 0.002)
        #expect(lightTint.brightnessComponent > darkTint.brightnessComponent)
    }
}
