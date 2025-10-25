//
//  Shaders.metal
//  SnatchShot
//
//  Metal shaders for advanced camera filter effects
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Grain Effect Shader

kernel void grainKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                       texture2d<float, access::write> outputTexture [[texture(1)]],
                       constant float& intensity [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    float4 color = inputTexture.read(gid);

    // Generate procedural noise based on position
    float2 uv = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
    float noise = fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);

    // Convert to monochrome noise
    float grain = (noise - 0.5) * 2.0;

    // Apply grain with soft light blend mode simulation
    float3 grainColor = float3(grain * intensity);
    color.rgb = color.rgb + grainColor * (1.0 - color.rgb) * color.rgb;

    outputTexture.write(color, gid);
}

// MARK: - Vignette Effect Shader

kernel void vignetteKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                          texture2d<float, access::write> outputTexture [[texture(1)]],
                          constant float& intensity [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    float4 color = inputTexture.read(gid);

    // Calculate vignette
    float2 uv = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);

    // Smooth vignette falloff
    float vignette = 1.0 - smoothstep(0.3, 0.8, dist);
    vignette = mix(1.0, vignette, intensity);

    color.rgb *= vignette;

    outputTexture.write(color, gid);
}

// MARK: - Chromatic Aberration Shader

kernel void chromaticAberrationKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                                     texture2d<float, access::write> outputTexture [[texture(1)]],
                                     constant float& intensity [[buffer(0)]],
                                     uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    // Sample red channel with slight shift
    int2 redOffset = int2(gid) + int2(int(-intensity * 2.0), 0);
    redOffset = clamp(redOffset, int2(0, 0), int2(int(width) - 1, int(height) - 1));

    // Sample blue channel with slight shift
    int2 blueOffset = int2(gid) + int2(int(intensity * 2.0), 0);
    blueOffset = clamp(blueOffset, int2(0, 0), int2(int(width) - 1, int(height) - 1));

    float4 redSample = inputTexture.read(uint2(redOffset));
    float4 greenSample = inputTexture.read(gid);
    float4 blueSample = inputTexture.read(uint2(blueOffset));

    float4 result;
    result.r = redSample.r;
    result.g = greenSample.g;
    result.b = blueSample.b;
    result.a = greenSample.a;

    outputTexture.write(result, gid);
}

// MARK: - Halation (Bloom) Shader

kernel void halationKernel(texture2d<float, access::read> inputTexture [[texture(0)]],
                          texture2d<float, access::write> outputTexture [[texture(1)]],
                          constant float& intensity [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    float4 color = inputTexture.read(gid);

    // Simple bloom effect - brighten highlights
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    float bloom = smoothstep(0.7, 1.0, luminance) * intensity;

    color.rgb += bloom * color.rgb * 0.5;

    outputTexture.write(color, gid);
}
