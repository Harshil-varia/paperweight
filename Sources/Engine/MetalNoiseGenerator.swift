import Foundation
import Metal
import AppKit

// MARK: - Embedded Shader Source

/// Metal shader source for noise generation (embedded as fallback for resource bundling issues)
private let NOISE_SHADER_SOURCE = """
#include <metal_stdlib>
using namespace metal;

struct NoiseParameters {
    uint tileSize;
    uint noiseType;
    float tint;
    float matteLift;
    uint seed;
    float scale;
};

// Seeded integer hash (Murmur3-like, deterministic across runs)
uint hash(uint x, uint seed) {
    x ^= seed;
    x ^= x >> 16;
    x *= 0x85ebca6b;
    x ^= x >> 13;
    x *= 0xc2b2ae35;
    x ^= x >> 16;
    return x;
}

// 2D Murmur-like hash for lattice coordinates
uint hash2D(uint x, uint y, uint seed) {
    uint h = hash(x ^ (y << 16), seed);
    return h;
}

// Fade function for smoothstep-like behavior
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Lerp
float lerp(float a, float b, float t) {
    return mix(a, b, t);
}

// Value noise: interpolate between random values at lattice points
float valueNoise(float x, float y, uint seed, uint tileSize) {
    float xi = fmod(floor(x), float(tileSize));
    float yi = fmod(floor(y), float(tileSize));
    float xf = fract(x);
    float yf = fract(y);

    uint x0 = uint(xi) % tileSize;
    uint y0 = uint(yi) % tileSize;
    uint x1 = (x0 + 1) % tileSize;
    uint y1 = (y0 + 1) % tileSize;

    float v00 = float(hash2D(x0, y0, seed)) / 4294967295.0;
    float v10 = float(hash2D(x1, y0, seed)) / 4294967295.0;
    float v01 = float(hash2D(x0, y1, seed)) / 4294967295.0;
    float v11 = float(hash2D(x1, y1, seed)) / 4294967295.0;

    float u = fade(xf);
    float v = fade(yf);

    float nx0 = lerp(v00, v10, u);
    float nx1 = lerp(v01, v11, u);
    float result = lerp(nx0, nx1, v);

    return result;
}

// White noise: pure random per pixel
float whiteNoise(float x, float y, uint seed) {
    uint xi = uint(x);
    uint yi = uint(y);
    return float(hash2D(xi, yi, seed)) / 4294967295.0;
}

// Main compute kernel
kernel void generateNoise(
    device uchar4 *output [[buffer(0)]],
    constant NoiseParameters &params [[buffer(1)]],
    uint2 id [[thread_position_in_grid]]
) {
    if (id.x >= params.tileSize || id.y >= params.tileSize) {
        return;
    }

    float x = float(id.x);
    float y = float(id.y);

    // Generate noise based on type
    float noise = 0.0;
    if (params.noiseType == 0) {
        // White noise
        noise = whiteNoise(x, y, params.seed);
    } else {
        // Value noise (default for most types in Phase 2)
        noise = valueNoise(x * params.scale, y * params.scale, params.seed, params.tileSize);
    }

    // Apply matte lift (brighten the darks)
    noise = mix(params.matteLift, 1.0, noise);

    // Apply tint (warm up or cool down, luminance-only so no hue shift)
    // For now, tint is not applied at the pixel level (reserved for later enhancement)

    // Convert to 0-255 range
    uchar value = uchar(clamp(noise * 255.0, 0.0, 255.0));

    // Output as RGBA with full opacity
    uint index = id.y * params.tileSize + id.x;
    output[index] = uchar4(value, value, value, 255);
}
"""

// MARK: - MetalNoiseGenerator

class MetalNoiseGenerator: TextureGenerating {
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private var pipelineState: MTLComputePipelineState?

    init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()

        if let device = device {
            self.pipelineState = Self.makePipelineState(device)
        }
    }

    func tile(for profile: TextureProfile, scale: CGFloat) -> TileImage? {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipelineState = pipelineState else {
            return nil
        }

        let tileSize = profile.tileSize
        let pixelCount = tileSize * tileSize

        // Create output buffer for the tile (RGBA, 4 bytes per pixel)
        guard let outputBuffer = device.makeBuffer(length: pixelCount * 4, options: .storageModeShared) else {
            return nil
        }

        // Create command buffer and compute encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        // Set up compute pipeline
        computeEncoder.setComputePipelineState(pipelineState)

        // Create parameters buffer with stable noise type code (not String.hashValue)
        var params = NoiseParameters(
            tileSize: UInt32(tileSize),
            noiseType: profile.noiseType.stableCode,
            tint: profile.tint,
            matteLift: profile.matteLift,
            seed: profile.seed,
            scale: Float(scale)
        )

        guard let paramsBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<NoiseParameters>.size) else {
            return nil
        }

        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)

        // Dispatch work
        let threadsPerThreadgroup = MTLSizeMake(8, 8, 1)
        let threadgroups = MTLSizeMake(
            (tileSize + 7) / 8,
            (tileSize + 7) / 8,
            1
        )

        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert output buffer to CGImage
        return Self.makeImage(from: outputBuffer, size: tileSize)
    }

    private static func makePipelineState(_ device: MTLDevice) -> MTLComputePipelineState? {
        // Try to load from bundled Noise.metal file first, fall back to embedded source
        var shaderSource: String?

        // Attempt 1: Load from bundle
        if let shaderURL = Bundle.main.url(forResource: "Noise", withExtension: "metal") {
            shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8)
        }

        // Attempt 2: Use embedded shader source (fallback for resource bundling issues)
        if shaderSource == nil {
            shaderSource = NOISE_SHADER_SOURCE
        }

        guard let shaderSource else {
            return nil
        }

        // Compile the shader source at runtime
        let compileOptions = MTLCompileOptions()
        guard let library = try? device.makeLibrary(source: shaderSource, options: compileOptions) else {
            return nil
        }

        guard let kernel = library.makeFunction(name: "generateNoise") else {
            return nil
        }

        return try? device.makeComputePipelineState(function: kernel)
    }

    private static func makeImage(from buffer: MTLBuffer, size: Int) -> TileImage? {
        // Copy the buffer data into owned memory (fixes use-after-free)
        let bytesPerRow = size * 4  // RGBA
        let totalBytes = size * size * 4

        let data = buffer.contents()

        // Create a Data copy that the CGDataProvider will own
        let dataCopy = Data(bytes: data, count: totalBytes)

        let dataProvider = dataCopy.withUnsafeBytes { buffer -> CGDataProvider? in
            guard let baseAddress = buffer.baseAddress else {
                return nil
            }
            return CGDataProvider(data: NSData(bytes: baseAddress, length: totalBytes))
        }

        guard let dataProvider = dataProvider else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgImage = CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )

        guard let cgImage = cgImage else {
            return nil
        }

        return TileImage(cgImage: cgImage, size: CGSize(width: size, height: size))
    }
}

// MARK: - Metal Parameters

struct NoiseParameters {
    var tileSize: UInt32
    var noiseType: UInt32
    var tint: Float
    var matteLift: Float
    var seed: UInt32
    var scale: Float
}
