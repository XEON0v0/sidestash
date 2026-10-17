import AppKit
import IOSurface
import Metal
import Testing
import simd
@testable import SideStash

/// The shader must draw exactly what `GlassLightingEngine.bevelColor(at:lighting:)` describes.
@MainActor
@Suite(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a Metal device"))
struct GlassBevelRendererTests {
    private let blue = IconLight(color: LightRGB(sRGBRed: 0.3, green: 0.6, blue: 1), strength: 1)
    private let red = IconLight(color: LightRGB(sRGBRed: 1, green: 0.4, blue: 0.4), strength: 1)
    private let sceneBounds = CGRect(x: 0, y: 0, width: 320, height: 420)
    /// 8-bit rounding plus float differences between the CPU and the GPU.
    private let tolerance = 3

    @Test func shader_matchesTheSwiftReference() throws {
        let renderer = GlassBevelRenderer()
        try renderer.prepareNow()
        let device = try #require(renderer.device)

        for lighting in sampleLightings() {
            let image = try render(lighting, with: renderer, device: device)
            var worst = 0
            var compared = 0
            for (x, y) in samplePixels(width: image.width, height: image.height) {
                let expected = reference(x: x, y: y, lighting: lighting)
                let actual = image.pixel(x: x, y: y)
                worst = max(worst, zip(expected, actual).map { abs($0 - $1) }.max() ?? 0)
                compared += 1
            }
            #expect(compared > 1000)
            #expect(worst <= tolerance, "worst channel difference \(worst) for \(lighting.uniforms.surface)")
        }
    }

    @Test func rimView_showsItsBevelAndRedrawsOnlyWhenItsLightingChanges() async throws {
        let renderer = GlassBevelRenderer()
        try renderer.prepareNow()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let root = FlippedRoot(frame: window.contentLayoutRect)
        window.contentView = root
        let scene = GlassLightingScene()
        scene.coordinateRoot = root
        scene.bounds = root.bounds
        let rim = GlassRimView(shape: .roundedRect(cornerRadius: 12), kind: .plate, renderer: renderer)
        rim.frame = NSRect(x: 12, y: 70, width: 296, height: 44)
        root.addSubview(rim)

        rim.scene = scene
        try await waitUntil { rim.renderCount == 1 }
        let lighting = try #require(rim.lighting)
        let surface = try #require(rim.layer?.contents as? IOSurface)

        // The layer shows the drawn bevel: a pixel on the slope facing the key light.
        let scale = lighting.uniforms.surface.w
        let x = Int(4.8 * scale + 2)
        let y = Int(2.4 * scale + 2)
        let expected = reference(x: x, y: y, lighting: lighting)
        let actual = SurfaceImage(surface).pixel(x: x, y: y)
        #expect(expected[3] > 10)
        #expect(zip(expected, actual).allSatisfy { abs($0 - $1) <= tolerance })

        // Unchanged lighting draws nothing.
        rim.relight()
        try await Task.sleep(for: .milliseconds(50))
        #expect(rim.renderCount == 1)

        // A new light draws once more, into another surface.
        scene.setEmitter(id: "file", position: CGPoint(x: 36, y: 92), light: blue)
        rim.relight()
        try await waitUntil { rim.renderCount == 2 }
        #expect((rim.layer?.contents as AnyObject?) !== surface)

        rim.scene = nil
        _ = window
    }

    // MARK: - Helpers

    /// A plate with every kind of light, the pill with the pointer over it,
    /// and the panel lit by its default light.
    private func sampleLightings() -> [GlassBevelLighting] {
        let plateFrame = CGRect(x: 12, y: 70, width: 296, height: 44)
        let plate = GlassLightingEngine.lighting(
            shape: .roundedRect(cornerRadius: 12),
            frame: plateFrame,
            kind: .plate,
            keyLight: GlassKeyLight(position: CGPoint(x: plateFrame.maxX + 14, y: plateFrame.midY), pointerWeight: 0.8),
            emitters: [
                GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.midY), light: blue),
                GlassLightEmitter(position: CGPoint(x: plateFrame.minX + 24, y: plateFrame.minY - 28), light: red),
            ],
            sceneBounds: sceneBounds,
            intensity: GlassLightingStyle.intensity(for: .plate, colorScheme: .dark),
            reduceTransparency: false,
            scale: 2
        )
        let pillFrame = CGRect(x: 94, y: 364, width: 132, height: 40)
        let pill = GlassLightingEngine.lighting(
            shape: .capsule,
            frame: pillFrame,
            kind: .pill,
            keyLight: GlassKeyLight(position: CGPoint(x: pillFrame.minX + 20, y: pillFrame.midY), pointerWeight: 1),
            emitters: [GlassLightEmitter(position: CGPoint(x: pillFrame.minX + 30, y: pillFrame.minY - 20), light: blue)],
            sceneBounds: sceneBounds,
            intensity: GlassLightingStyle.intensity(for: .pill, colorScheme: .light),
            reduceTransparency: false,
            scale: 2
        )
        let panel = GlassLightingEngine.lighting(
            shape: .roundedRect(cornerRadius: 24),
            frame: sceneBounds,
            kind: .panel,
            keyLight: .default,
            emitters: [],
            sceneBounds: sceneBounds,
            intensity: GlassLightingStyle.intensity(for: .panel, colorScheme: .dark),
            reduceTransparency: false,
            scale: 2
        )
        return [plate, pill, panel]
    }

    /// Every pixel near the outline at the four corners and halfway along each
    /// side, plus the middle of the plateau.
    private func samplePixels(width: Int, height: Int) -> [(Int, Int)] {
        let band = 26
        var pixels: [(Int, Int)] = []
        for y in 0..<height {
            for x in 0..<width {
                let nearCorner = (x < 2 * band || x >= width - 2 * band) && (y < 2 * band || y >= height - 2 * band)
                let nearMiddle = (abs(x - width / 2) < 4 && (y < band || y >= height - band))
                    || (abs(y - height / 2) < 4 && (x < band || x >= width - band))
                if nearCorner || nearMiddle {
                    pixels.append((x, y))
                }
            }
        }
        pixels.append((width / 2, height / 2))
        return pixels
    }

    /// The reference color of pixel (x, y), as 8-bit BGRA.
    private func reference(x: Int, y: Int, lighting: GlassBevelLighting) -> [Int] {
        let scale = lighting.uniforms.surface.w
        let point = SIMD2((Float(x) + 0.5) / scale, (Float(y) + 0.5) / scale)
        let color = GlassLightingEngine.bevelColor(at: point, lighting: lighting)
        return [color.z, color.y, color.x, color.w].map { Int(($0 * 255).rounded()) }
    }

    private func render(_ lighting: GlassBevelLighting, with renderer: GlassBevelRenderer, device: MTLDevice) throws -> TextureImage {
        let scale = lighting.uniforms.surface.w
        let width = Int((lighting.uniforms.surface.x * scale).rounded())
        let height = Int((lighting.uniforms.surface.y * scale).rounded())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let queue = try #require(device.makeCommandQueue())
        let commandBuffer = try #require(queue.makeCommandBuffer())
        renderer.encode(lighting, into: texture, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return TextureImage(width: width, height: height, bytes: bytes)
    }

    private func waitUntil(timeout: Duration = .seconds(3), _ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            guard clock.now < deadline else {
                Issue.record("Timed out waiting for the bevel to draw")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private struct TextureImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    /// BGRA.
    func pixel(x: Int, y: Int) -> [Int] {
        let offset = (y * width + x) * 4
        return bytes[offset..<offset + 4].map { Int($0) }
    }
}

private struct SurfaceImage {
    let surface: IOSurface

    init(_ surface: IOSurface) {
        self.surface = surface
    }

    /// BGRA.
    func pixel(x: Int, y: Int) -> [Int] {
        surface.lock(options: .readOnly, seed: nil)
        defer { surface.unlock(options: .readOnly, seed: nil) }
        let base = surface.baseAddress.assumingMemoryBound(to: UInt8.self)
        let offset = y * surface.bytesPerRow + x * 4
        return (0..<4).map { Int(base[offset + $0]) }
    }
}

private final class FlippedRoot: NSView {
    override var isFlipped: Bool { true }
}
