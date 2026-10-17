import AppKit
import Testing
@testable import SideStash

@MainActor
struct GlassLightingSceneTests {
    private let blue = IconLight(color: LightRGB(sRGBRed: 0.3, green: 0.6, blue: 1), strength: 1)

    @Test func emitters_areAddedMovedAndRemoved() {
        let scene = GlassLightingScene()

        scene.setEmitter(id: "b", position: CGPoint(x: 36, y: 92), light: blue)
        scene.setEmitter(id: "a", position: CGPoint(x: 36, y: 142), light: blue)
        #expect(scene.orderedEmitters.map(\.position.y) == [142, 92])

        scene.setEmitter(id: "b", position: CGPoint(x: 36, y: 60), light: blue)
        #expect(scene.emitters["b"]?.position == CGPoint(x: 36, y: 60))

        scene.removeEmitter(id: "a")
        #expect(scene.emitters["a"] == nil)

        // An icon without color emits nothing.
        scene.setEmitter(id: "b", position: CGPoint(x: 36, y: 60), light: nil)
        #expect(scene.emitters.isEmpty)
    }

    @Test func keyLight_followsThePointerAndReturnsWhenItLeaves() {
        let scene = GlassLightingScene()
        #expect(scene.keyLight == .default)

        scene.pointerMoved(to: CGPoint(x: 200, y: 120), now: 10)
        #expect(scene.targetKeyLight == GlassKeyLight(position: CGPoint(x: 200, y: 120), pointerWeight: 1))
        #expect(scene.keyLight.position == CGPoint(x: 200, y: 120))

        scene.pointerExited(animated: false)
        #expect(scene.targetKeyLight.pointerWeight == 0)
        #expect(scene.keyLight.pointerWeight == 0)
    }

    @Test func pointerMoves_areCoalescedToTheUpdateInterval() {
        let scene = GlassLightingScene()
        let interval = GlassLightingStyle.pointerUpdateInterval

        scene.pointerMoved(to: CGPoint(x: 100, y: 100), now: 10)
        scene.pointerMoved(to: CGPoint(x: 110, y: 100), now: 10 + interval / 4)
        // Too soon: held for the next update.
        #expect(scene.keyLight.position == CGPoint(x: 100, y: 100))

        scene.pointerMoved(to: CGPoint(x: 120, y: 100), now: 10 + interval * 1.5)
        #expect(scene.keyLight.position == CGPoint(x: 120, y: 100))
    }

    @Test func pointerExit_dropsAPendingMove() {
        let scene = GlassLightingScene()
        let interval = GlassLightingStyle.pointerUpdateInterval

        scene.pointerMoved(to: CGPoint(x: 100, y: 100), now: 10)
        scene.pointerMoved(to: CGPoint(x: 110, y: 100), now: 10 + interval / 4)
        scene.pointerExited(animated: false)

        #expect(scene.keyLight.pointerWeight == 0)
        #expect(scene.keyLight.position == CGPoint(x: 100, y: 100))
    }

    @Test func keyLight_staysStillWhenPointerFollowingIsOff() {
        let scene = GlassLightingScene()
        scene.followsPointer = false

        scene.pointerMoved(to: CGPoint(x: 200, y: 120), now: 10)

        #expect(scene.targetKeyLight.pointerWeight == 0)
        #expect(scene.keyLight.pointerWeight == 0)
    }

    @Test func sceneRect_usesTopLeftOrigin() throws {
        let (window, root) = makeWindow(rootFlipped: false)
        let scene = GlassLightingScene()
        scene.coordinateRoot = root
        let child = NSView(frame: NSRect(x: 12, y: 306, width: 296, height: 44))
        root.addSubview(child)

        // A bottom-left root is flipped into scene (top-left) coordinates.
        let rect = try #require(scene.sceneRect(of: child))
        #expect(rect == CGRect(x: 12, y: 70, width: 296, height: 44))
        _ = window
    }

    @Test func rimView_isLitFromTheSceneAndFollowsItsLights() throws {
        let (window, root) = makeWindow(rootFlipped: true)
        let scene = GlassLightingScene()
        scene.coordinateRoot = root
        scene.bounds = root.bounds
        // No GPU: this checks the lighting, not the drawing.
        let rim = GlassRimView(shape: .roundedRect(cornerRadius: 12), kind: .plate, renderer: GlassBevelRenderer(device: nil))
        rim.frame = NSRect(x: 12, y: 70, width: 296, height: 44)
        root.addSubview(rim)

        rim.scene = scene
        let unlit = try #require(rim.lighting)
        #expect(unlit.emitters.isEmpty)
        #expect(unlit.uniforms.surface.x == 296)
        #expect(unlit.uniforms.surface.y == 44)
        #expect(unlit.uniforms.surface.z == 12)

        // The file's own icon, on the plate 24 pt from its leading edge.
        scene.setEmitter(id: "file", position: CGPoint(x: 36, y: 92), light: blue)
        rim.relight()
        let lit = try #require(rim.lighting)
        #expect(lit.emitters.map(\.position) == [SIMD4(24, 22, 1, 0)])

        let leading = GlassLightingEngine.bevelLight(at: SIMD2(1, 22), lighting: lit).light
        let trailing = GlassLightingEngine.bevelLight(at: SIMD2(295, 22), lighting: lit).light
        #expect(leading.z - leading.x > trailing.z - trailing.x)
        // Without the shader nothing is drawn.
        #expect(rim.renderCount == 0)

        rim.scene = nil
        _ = window
    }

    private func makeWindow(rootFlipped: Bool) -> (NSWindow, NSView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let root: NSView = rootFlipped ? FlippedView(frame: window.contentLayoutRect) : NSView(frame: window.contentLayoutRect)
        window.contentView = root
        return (window, root)
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
