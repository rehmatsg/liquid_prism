#include <metal_stdlib>
using namespace metal;

// Standalone, fitted artwork shader. It does not change the package's shader ABI.
// The SDF bevel approach follows the project's glass surfaces, with a text mask
// replacing their capsule/superellipse geometry. This lighting is fitted to the
// supplied artwork, not a measurement of Apple's native glass implementation.
constexpr sampler linearSampler(coord::pixel, address::clamp_to_edge, filter::linear);
float sample(texture2d<float, access::sample> t, float2 p) {
    return t.sample(linearSampler, p).r;
}
kernel void gaussian(texture2d<float, access::read> input [[texture(0)]],
                     texture2d<float, access::write> output [[texture(1)]],
                     constant float4 &params [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    float sigma = params.x;
    int radius = int(ceil(3.0 * sigma));
    float sum = 0, weight = 0;
    for (int i = -radius; i <= radius; ++i) {
        int2 p = int2(id) + (params.y < 0.5 ? int2(i, 0) : int2(0, i));
        p = clamp(p, int2(0), int2(input.get_width() - 1, input.get_height() - 1));
        float w = exp(-float(i * i) / (2 * sigma * sigma));
        sum += input.read(uint2(p)).r * w;
        weight += w;
    }
    output.write(float4(sum / weight), id);
}
float bell(float x, float center, float width) {
    float t = (x - center) / width;
    return exp(-0.5 * t * t);
}
kernel void wordmark(texture2d<float, access::sample> mask [[texture(0)]],
                     texture2d<float, access::sample> sdf [[texture(1)]],
                     texture2d<float, access::sample> broadShadow [[texture(2)]],
                     texture2d<float, access::sample> contactShadow [[texture(3)]],
                     texture2d<float, access::sample> islands [[texture(4)]],
                     texture2d<float, access::write> output [[texture(5)]],
                     constant float4 *params [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    float scale = params[0].x, baseline = params[0].z, bevel = params[0].w;
    float2 uv = float2(id) + 0.5;
    float2 p = uv / scale;
    // The source is RGB 248 through most of the canvas, tapering to 247 at edges.
    float vignette = smoothstep(0.2, 1.0, length((p - float2(960, 540)) / float2(1250, 900)));
    float3 background = float3((248.0 - vignette) / 255.0);
    float broad = sample(broadShadow, uv - float2(11, 12) * scale);
    float contact = sample(contactShadow, uv - float2(3.5, 4.5) * scale);
    float shadow = (0.12 * broad + 0.065 * contact) * params[1].y;
    float3 color = background * (1 - shadow);
    float coverage = sample(mask, uv);
    if (coverage > 0) {
        float d = max(sample(sdf, uv), 0.0);
        float step = 1.5 * scale;
        float2 grad = float2(sample(sdf, uv + float2(step, 0)) - sample(sdf, uv - float2(step, 0)),
                            sample(sdf, uv + float2(0, step)) - sample(sdf, uv - float2(0, step)));
        float2 outward = -grad / max(length(grad), 0.001);
        float vertical = clamp((p.y - (baseline - 164)) / 172, 0.0, 1.0);
        float3 face = mix(float3(208, 210, 216), float3(235, 237, 240), vertical) / 255.0;
        // Small isolated islands (the i dots) catch more of the broad studio fill.
        // Components are identified from the font mask, so this works for other text.
        face = mix(face, float3(240, 241, 244) / 255.0, sample(islands, uv) * 0.50);
        // Faint broad reflected pastel light, restricted to the lower letter faces.
        float low = bell(p.y, baseline - 15, 23);
        float pink = bell(p.x, 480, 180);
        float peach = bell(p.x, 770, 140);
        float green = bell(p.x, 1060, 115);
        face += low * (float3(0.018, -0.060, -0.056) * pink
                      + float3(0.013, -0.011, -0.049) * peach
                      + float3(-0.033, 0.012, -0.025) * green);
        // Broad bevel rolls a cool face into a nearly white rounded lip.
        float edge = exp(-d * d / (2 * bevel * bevel));
        float facing = clamp(dot(outward, normalize(float2(0.55, 0.85))) * 0.5 + 0.5, 0.0, 1.0);
        float bevelLight = edge * (0.035 + 0.92 * pow(facing, 2.8));
        face = mix(face, float3(1), bevelLight);
        // A narrow clear rim and an inner dark refraction shoulder retain depth.
        float rim = bell(d, 0.95, 0.72) * (0.88 + 0.12 * facing);
        face = mix(face, float3(1), rim * 0.98);
        float shoulder = bell(d, 2.4, 0.85) * max(-outward.x, 0.0)
                       + bell(d, bevel + 1.5, 2.2) * max(-outward.y, 0.0) * 0.35;
        face -= float3(0.019, 0.020, 0.023) * shoulder;
        face = mix(background, face, params[1].x);
        color = mix(color, clamp(face, 0.0, 1.0), coverage);
    }
    output.write(float4(color, 1), id);
}
kernel void resolve(texture2d<float, access::read> input [[texture(0)]],
                    texture2d<float, access::write> output [[texture(1)]],
                    constant uint &scale [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= output.get_width() || id.y >= output.get_height()) return;
    float4 color = 0;
    for (uint y = 0; y < scale; ++y) {
        for (uint x = 0; x < scale; ++x) { color += input.read(id * scale + uint2(x, y)); }
    }
    output.write(color / float(scale * scale), id);
}
