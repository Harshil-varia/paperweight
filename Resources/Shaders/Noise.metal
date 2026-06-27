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
