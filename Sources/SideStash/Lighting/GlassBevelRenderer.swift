import AppKit
import CoreVideo
import IOSurface
import Metal
import OSLog

/// A texture a bevel is drawn into, backed by an IOSurface so a layer can
/// show it as its contents.
final class GlassBevelTarget {
    let surface: IOSurface
    let texture: MTLTexture

    init(surface: IOSurface, texture: MTLTexture) {
        self.surface = surface
        self.texture = texture
    }

    var width: Int { texture.width }
    var height: Int { texture.height }
}

/// Draws glass bevels on the GPU.
///
/// The shader is MSL source compiled at run time, so `swift build` needs no
/// Metal toolchain. It mirrors `GlassLightingEngine.bevelLight(at:lighting:)`
/// line by line: change both together (`GlassBevelRendererTests` checks that
/// they agree). Draws requested during one run loop pass share a command
/// buffer; each finished draw is handed back on the main thread, so drawing
/// never blocks it.
@MainActor
final class GlassBevelRenderer {
    static let shared = GlassBevelRenderer()

    let device: MTLDevice?
    private let queue: MTLCommandQueue?
    private(set) var pipeline: MTLRenderPipelineState?
    private var isPreparing = false
    private var readyHandlers: [@MainActor () -> Void] = []
    private var batch: MTLCommandBuffer?
    private var batchCompletions: [@MainActor () -> Void] = []

    nonisolated private static let logger = Logger(subsystem: "app.sidestash.SideStash", category: "GlassBevel")

    enum RendererError: Error {
        case noDevice
    }

    init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.device = device
        queue = device?.makeCommandQueue()
    }

    var isReady: Bool {
        pipeline != nil
    }

    // MARK: - Shader

    /// Compiles the shader in the background; calling it again does nothing.
    /// If compiling fails, bevels stay undrawn and the native glass edge remains.
    func prepare() {
        guard pipeline == nil, !isPreparing, let device else { return }
        isPreparing = true
        device.makeLibrary(source: Self.shaderSource, options: Self.compileOptions()) { [weak self] library, error in
            var pipeline: MTLRenderPipelineState?
            if let library {
                do {
                    pipeline = try device.makeRenderPipelineState(descriptor: Self.pipelineDescriptor(library: library))
                } catch {
                    Self.logger.error("Glass bevel pipeline failed: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                Self.logger.error("Glass bevel shader failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            }
            let result = PipelineResult(pipeline: pipeline)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.finishPreparing(result.pipeline)
                }
            }
        }
    }

    /// Compiles on the spot; for tests.
    func prepareNow() throws {
        guard pipeline == nil else { return }
        guard let device else { throw RendererError.noDevice }
        let library = try device.makeLibrary(source: Self.shaderSource, options: Self.compileOptions())
        pipeline = try device.makeRenderPipelineState(descriptor: Self.pipelineDescriptor(library: library))
        runReadyHandlers()
    }

    /// Runs `handler` once the shader is ready, right away if it already is.
    func whenReady(_ handler: @escaping @MainActor () -> Void) {
        if pipeline != nil {
            handler()
        } else {
            readyHandlers.append(handler)
        }
    }

    private func finishPreparing(_ pipeline: MTLRenderPipelineState?) {
        isPreparing = false
        guard let pipeline else { return }
        self.pipeline = pipeline
        runReadyHandlers()
    }

    private func runReadyHandlers() {
        let handlers = readyHandlers
        readyHandlers.removeAll()
        handlers.forEach { $0() }
    }

    // MARK: - Drawing

    /// A target of the given pixel size, tagged sRGB like the shader's output.
    func makeTarget(width: Int, height: Int) -> GlassBevelTarget? {
        guard let device, width > 0, height > 0,
              let surface = IOSurface(properties: [
                  .width: width,
                  .height: height,
                  .bytesPerElement: 4,
                  .pixelFormat: kCVPixelFormatType_32BGRA,
              ]) else {
            return nil
        }
        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)?.copyPropertyList() {
            IOSurfaceSetValue(surface, kIOSurfaceColorSpace, colorSpace)
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else { return nil }
        return GlassBevelTarget(surface: surface, texture: texture)
    }

    /// Draws `lighting` into `target`. `completion` runs on the main thread
    /// once the GPU is done; nothing is drawn (and false returned) before the
    /// shader is ready.
    @discardableResult
    func render(
        _ lighting: GlassBevelLighting,
        into target: GlassBevelTarget,
        completion: @escaping @MainActor () -> Void
    ) -> Bool {
        guard pipeline != nil, let commandBuffer = batchCommandBuffer() else { return false }
        encode(lighting, into: target.texture, commandBuffer: commandBuffer)
        batchCompletions.append(completion)
        return true
    }

    /// Encodes one bevel into `texture`, cleared first.
    func encode(_ lighting: GlassBevelLighting, into texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let pipeline else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        var uniforms = lighting.uniforms
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlassBevelUniforms>.stride, index: 0)
        let emitters = lighting.emitters.isEmpty ? [GlassBevelEmitter.none] : lighting.emitters
        emitters.withUnsafeBytes { bytes in
            if let base = bytes.baseAddress {
                encoder.setFragmentBytes(base, length: bytes.count, index: 1)
            }
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        // A discrete GPU keeps its own copy; the compositor reads the IOSurface.
        if texture.storageMode == .managed, let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.synchronize(resource: texture)
            blit.endEncoding()
        }
    }

    /// Commits the draws gathered in this run loop pass.
    func flush() {
        guard let batch else { return }
        self.batch = nil
        let completions = Completions(handlers: batchCompletions)
        batchCompletions.removeAll()
        batch.addCompletedHandler { _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completions.run()
                }
            }
        }
        batch.commit()
    }

    private func batchCommandBuffer() -> MTLCommandBuffer? {
        if let batch {
            return batch
        }
        guard let commandBuffer = queue?.makeCommandBuffer() else { return nil }
        commandBuffer.label = "Glass bevels"
        batch = commandBuffer
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.flush()
            }
        }
        return commandBuffer
    }

    nonisolated private static func pipelineDescriptor(library: MTLLibrary) -> MTLRenderPipelineDescriptor {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Glass bevel"
        descriptor.vertexFunction = library.makeFunction(name: "glass_bevel_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "glass_bevel_fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return descriptor
    }

    nonisolated private static func compileOptions() -> MTLCompileOptions {
        let options = MTLCompileOptions()
        // Precise math keeps the shader in step with the Swift reference.
        options.mathMode = .safe
        return options
    }

    /// One triangle covers the target; the fragment shader is
    /// `GlassLightingEngine.bevelLight(at:lighting:)` and `bevelColor(at:lighting:)`.
    nonisolated static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct BevelUniforms {
        float4 surface;
        float4 profile;
        float4 keyLight;
        float4 keyFacing;
        float4 pointer;
        float4 pointerShape;
        float4 emitterTuning;
        float4 emitterCore;
        float4 output;
    };

    struct BevelEmitter {
        float4 position;
        float4 light;
    };

    struct RasterPoint {
        float4 position [[position]];
    };

    vertex RasterPoint glass_bevel_vertex(uint vertexID [[vertex_id]]) {
        float2 corner = float2(float((vertexID << 1) & 2), float(vertexID & 2));
        RasterPoint out;
        out.position = float4(corner * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
        return out;
    }

    static float unit_clamp(float value) {
        return clamp(value, 0.0f, 1.0f);
    }

    static float bevel_profile(float u, float4 profile) {
        float rest = 1.0f - unit_clamp(u);
        return pow(max(1.0f - pow(rest, profile.z), 0.0f), 1.0f / profile.z);
    }

    static float bevel_slope(float u, float4 profile) {
        float rest = 1.0f - unit_clamp(u);
        float base = max(1.0f - pow(rest, profile.z), 1e-6f);
        return profile.y * pow(base, 1.0f / profile.z - 1.0f) * pow(rest, profile.z - 1.0f);
    }

    static float3 bevel_normal(float u, float2 outward, float4 profile) {
        float tilt = bevel_slope(u, profile);
        return normalize(float3(outward * tilt, 1.0f));
    }

    static float bevel_fresnel(float cosine, float index) {
        float r0 = pow((index - 1.0f) / (index + 1.0f), 2.0f);
        return r0 + (1.0f - r0) * pow(1.0f - unit_clamp(cosine), 5.0f);
    }

    static float bevel_refraction_offset(float u, float4 profile) {
        float tilt = atan(bevel_slope(u, profile));
        float refracted = asin(sin(tilt) / profile.w);
        float height = bevel_profile(u, profile) * profile.y * profile.x;
        return height * tan(tilt - refracted);
    }

    static float windowed_falloff(float value, float range) {
        if (range <= 0.0f || value >= range) {
            return 0.0f;
        }
        float ratio = value / range;
        float window = 1.0f - ratio * ratio;
        return window * window;
    }

    static float encoded_srgb(float component) {
        float clamped = unit_clamp(component);
        return clamped <= 0.0031308f ? clamped * 12.92f : 1.055f * pow(clamped, 1.0f / 2.4f) - 0.055f;
    }

    fragment float4 glass_bevel_fragment(RasterPoint in [[stage_in]],
                                         constant BevelUniforms &u [[buffer(0)]],
                                         constant BevelEmitter *emitters [[buffer(1)]]) {
        float scale = u.surface.w;
        float2 point = in.position.xy / scale;

        // Where the pixel sits against the outline.
        float2 halfSize = u.surface.xy * 0.5f;
        float radius = u.surface.z;
        float2 relative = point - halfSize;
        float2 q = abs(relative) - (halfSize - radius);
        float inset = radius - length(max(q, float2(0.0f))) - min(max(q.x, q.y), 0.0f);
        float2 side = float2(relative.x < 0.0f ? -1.0f : 1.0f, relative.y < 0.0f ? -1.0f : 1.0f);
        float2 n;
        if (q.x > 0.0f && q.y > 0.0f) {
            n = normalize(q) * side;
        } else if (q.x > q.y) {
            n = float2(side.x, 0.0f);
        } else {
            n = float2(0.0f, side.y);
        }

        float width = u.profile.x;
        float coverage = unit_clamp(inset * scale + 0.5f);
        float across = inset / width;
        if (coverage <= 0.0f || across >= 1.0f) {
            return float4(0.0f);
        }
        float s = unit_clamp(across);
        float3 normal = bevel_normal(s, n, u.profile);
        float3 view = float3(0.0f, 0.0f, 1.0f);
        float fade = 1.0f - smoothstep(0.8f, 1.0f, s);

        // Fresnel edge, at least the minimum edge width wide.
        float edgeAcross = max(inset - u.output.y, 0.0f) / width;
        float fresnelEdge = bevel_fresnel(bevel_normal(edgeAcross, n, u.profile).z, u.profile.w);
        float facingKey = dot(n, u.keyFacing.xy);
        float directionality = u.output.z;
        float edge = u.keyFacing.w * fresnelEdge * ((1.0f - directionality) + directionality * (0.5f + 0.5f * facingKey));

        float key = u.keyLight.w * pow(max(dot(normal, normalize(u.keyLight.xyz + view)), 0.0f), u.pointerShape.z);

        // Light leaving the glass gathers where the slope is steep.
        float tiltSine = length(normal.xy);
        float escape = pow(tiltSine, u.emitterTuning.w) * (1.0f - bevel_fresnel(normal.z, u.profile.w));
        float back = u.keyFacing.z * pow(max(-facingKey, 0.0f), 2.0f) * escape;

        float2 toPointer = u.pointer.xy - point;
        float pointerDistance = length(toPointer);
        float reach = windowed_falloff(pointerDistance, u.pointerShape.x);
        float3 pointerDirection = normalize(float3(toPointer, u.pointer.z));
        float pointerHighlight = u.pointer.w
            * pow(max(dot(normal, normalize(pointerDirection + view)), 0.0f), u.pointerShape.w)
            * reach;
        float away = pointerDistance > 0.001f ? -dot(n, toPointer) / pointerDistance : 0.0f;
        float pointerLeaving = u.pointerShape.y * pow(max(away, 0.0f), 1.5f) * reach * escape;

        float3 light = float3(edge + key + back + pointerHighlight + pointerLeaving);

        // Icon light seen through the slope: the bent view ray lands further in.
        float2 sampled = point - n * bevel_refraction_offset(s, u.profile);
        int count = int(u.output.w);
        for (int index = 0; index < count; index++) {
            float2 offset = emitters[index].position.xy - sampled;
            float iconDistance = length(offset);
            float glow = windowed_falloff(iconDistance, u.emitterTuning.y)
                + u.emitterCore.y * windowed_falloff(iconDistance, u.emitterCore.x);
            if (glow <= 0.0f) {
                continue;
            }
            float toward = emitters[index].position.z > 0.5f ? -1.0f : 1.0f;
            float cosine = iconDistance > 0.001f ? toward * dot(n, offset) / iconDistance : 1.0f;
            float wrap = u.emitterTuning.z;
            float facing = max((cosine + wrap) / (1.0f + wrap), 0.0f);
            light += emitters[index].light.rgb * (u.emitterTuning.x * glow * facing * escape);
        }
        light *= fade;

        float peak = max(light.r, max(light.g, light.b));
        if (peak <= 0.0001f) {
            return float4(0.0f);
        }
        float alpha = min(u.output.x, peak) * coverage;
        float3 normalized = light / peak;
        return float4(encoded_srgb(normalized.r) * alpha,
                      encoded_srgb(normalized.g) * alpha,
                      encoded_srgb(normalized.b) * alpha,
                      alpha);
    }
    """
}

/// Carries a compiled pipeline from Metal's compile thread to the main thread.
private struct PipelineResult: @unchecked Sendable {
    let pipeline: MTLRenderPipelineState?
}

/// Finished-draw callbacks, handed from Metal's completion thread to the main thread.
private final class Completions: @unchecked Sendable {
    private let handlers: [@MainActor () -> Void]

    init(handlers: [@MainActor () -> Void]) {
        self.handlers = handlers
    }

    @MainActor
    func run() {
        handlers.forEach { $0() }
    }
}
