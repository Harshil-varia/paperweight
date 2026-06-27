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

// 3D hash for Worley/cellular noise
uint hash3D(uint x, uint y, uint z, uint seed) {
    uint h = hash(x ^ (y << 16) ^ (z << 8), seed);
    return h;
}

// Fade function for smoothstep-like behavior (Perlin/Simplex)
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Lerp
float lerp(float a, float b, float t) {
    return mix(a, b, t);
}

// ===== White Noise (type 0) =====
float whiteNoise(float x, float y, uint seed) {
    uint xi = uint(x);
    uint yi = uint(y);
    return float(hash2D(xi, yi, seed)) / 4294967295.0;
}

// ===== Value Noise (type 1) =====
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

// ===== Perlin Noise (type 2) =====
float perlinNoise(float x, float y, uint seed, uint tileSize) {
    // Same as value noise for now; can be enhanced with gradient vectors
    return valueNoise(x, y, seed, tileSize);
}

// ===== Simplex Noise (type 3) =====
float simplexNoise(float x, float y, uint seed, uint tileSize) {
    // Simplified simplex using value noise as base
    float scale = 0.7;  // Simplex typically gives values in a different range
    return valueNoise(x, y, seed, tileSize) * scale + (1.0 - scale) * 0.5;
}

// ===== Fractional Brownian Motion (type 4) =====
float fbm(float x, float y, uint seed, uint tileSize, int octaves, float lacunarity, float gain) {
    float result = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (int i = 0; i < octaves && i < 8; i++) {
        result += amplitude * valueNoise(x * frequency, y * frequency, seed + uint(i), tileSize);
        maxValue += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return result / maxValue;
}

// ===== Ridged Multifractal (type 5) =====
float ridgedNoise(float x, float y, uint seed, uint tileSize, int octaves, float lacunarity, float gain) {
    float result = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (int i = 0; i < octaves && i < 8; i++) {
        float n = valueNoise(x * frequency, y * frequency, seed + uint(i), tileSize);
        n = 1.0 - abs(n * 2.0 - 1.0);  // Ridge the noise
        result += amplitude * n;
        maxValue += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return result / maxValue;
}

// ===== Worley/Cellular Noise (type 6) =====
float worleyNoise(float x, float y, uint seed, uint tileSize) {
    float cellX = floor(x);
    float cellY = floor(y);
    float fracX = fract(x);
    float fracY = fract(y);

    float minDist = 2.0;

    // Check 3x3 neighborhood
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint neighborX = uint(cellX + dx) % tileSize;
            uint neighborY = uint(cellY + dy) % tileSize;

            // Random point in the cell
            float px = float(hash2D(neighborX, neighborY, seed)) / 4294967295.0;
            float py = float(hash2D(neighborX + 1, neighborY + 1, seed)) / 4294967295.0;

            float dx_f = fracX - (float(dx) + px);
            float dy_f = fracY - (float(dy) + py);
            float dist = sqrt(dx_f * dx_f + dy_f * dy_f);

            minDist = min(minDist, dist);
        }
    }

    return minDist / 1.414;  // Normalize by max distance
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
    float scaledX = x * params.scale;
    float scaledY = y * params.scale;

    // Generate noise based on type
    float noise = 0.0;
    switch (params.noiseType) {
        case 0:
            // White noise
            noise = whiteNoise(scaledX, scaledY, params.seed);
            break;
        case 1:
            // Value noise
            noise = valueNoise(scaledX, scaledY, params.seed, params.tileSize);
            break;
        case 2:
            // Perlin noise
            noise = perlinNoise(scaledX, scaledY, params.seed, params.tileSize);
            break;
        case 3:
            // Simplex noise
            noise = simplexNoise(scaledX, scaledY, params.seed, params.tileSize);
            break;
        case 4:
            // fBm (Fractional Brownian Motion)
            noise = fbm(scaledX, scaledY, params.seed, params.tileSize, 4, 2.0, 0.5);
            break;
        case 5:
            // Ridged multifractal
            noise = ridgedNoise(scaledX, scaledY, params.seed, params.tileSize, 4, 2.0, 0.5);
            break;
        case 6:
            // Worley/Cellular noise
            noise = worleyNoise(scaledX, scaledY, params.seed, params.tileSize);
            break;
        default:
            noise = valueNoise(scaledX, scaledY, params.seed, params.tileSize);
    }

    // Clamp to valid range
    noise = clamp(noise, 0.0, 1.0);

    // Apply matte lift (brighten the darks)
    noise = mix(params.matteLift, 1.0, noise);

    // Convert to 0-255 range
    uchar value = uchar(clamp(noise * 255.0, 0.0, 255.0));

    // Output as RGBA with full opacity
    uint index = id.y * params.tileSize + id.x;
    output[index] = uchar4(value, value, value, 255);
}
