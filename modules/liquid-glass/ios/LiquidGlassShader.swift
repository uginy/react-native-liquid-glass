import Metal

// MARK: - Metal Shader Source

let kLiquidGlassMetalSource = """
#include <metal_stdlib>
using namespace metal;

// ─── Vertex ──────────────────────────────────────────────────────────────────

struct VertexIn {
    float2 position  [[attribute(0)]];
    float2 texCoord  [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut lg_vertex(uint vid [[vertex_id]],
                            constant float4* verts [[buffer(0)]]) {
    // verts[vid] = float4(posX, posY, uvX, uvY)
    VertexOut out;
    out.position = float4(verts[vid].xy, 0.0, 1.0);
    out.texCoord = verts[vid].zw;
    return out;
}

// ─── Uniforms ────────────────────────────────────────────────────────────────

struct Uniforms {
    float2  resolution;        // view size in points
    float2  scale;             // UIScreen.scale (for pixel-accurate sampling)
    float2  bgTextureSize;     // background texture size in pixels
    float2  viewOriginInBg;    // view origin inside bg texture (pixels)

    float   blurRadius;
    float   refractionStrength;
    float   chromaticAberration;
    float   edgeGlowIntensity;
    float   glassOpacity;
    float   fresnelPower;
    float   cornerRadius;
    float   glareIntensity;
    float   borderIntensity;
    float   edgeWidth;
    float   liquidPower;
    float   lightAngle;
    float   saturation;
    float   brightness;
    float   noiseIntensity;
    float   iridescence;

    float   tintR;
    float   tintG;
    float   tintB;
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

float lg_roundedBoxSDF(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - halfSize + float2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Sample background texture using absolute pixel coords inside the bg snapshot
float4 lg_sampleBg(texture2d<float> tex, float2 pixelCoord) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 bgSize = float2(tex.get_width(), tex.get_height());
    float2 uv = clamp(pixelCoord, float2(0.0), bgSize - float2(1.0)) / bgSize;
    return tex.sample(s, uv);
}

// Box-blur in pixel space (9-tap)
float4 lg_blurBg(texture2d<float> tex, float2 pixelCoord, float radius) {
    if (radius < 0.5) return lg_sampleBg(tex, pixelCoord);
    float r = radius;
    float4 c = lg_sampleBg(tex, pixelCoord) * 0.36;
    c += lg_sampleBg(tex, pixelCoord + float2(-r,-r)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2( r,-r)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2(-r, r)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2( r, r)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2(-r, 0)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2( r, 0)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2( 0,-r)) * 0.08;
    c += lg_sampleBg(tex, pixelCoord + float2( 0, r)) * 0.08;
    return c;
}

float3 lg_saturation(float3 color, float sat) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return mix(float3(luma), color, sat);
}

float lg_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// ─── Fragment ─────────────────────────────────────────────────────────────────

fragment float4 lg_fragment(VertexOut in [[stage_in]],
                             constant Uniforms& u [[buffer(0)]],
                             texture2d<float> bgTex [[texture(0)]]) {

    // UV in [0,1] over the view
    float2 uv = in.texCoord;

    // Position in view-space points (origin = top-left)
    float2 pos = uv * u.resolution;

    // SDF for rounded rectangle
    float2 center    = u.resolution * 0.5;
    float2 halfSize  = u.resolution * 0.5;
    float  sdf       = lg_roundedBoxSDF(pos - center, halfSize, u.cornerRadius);

    // Smooth mask — discard outside
    float mask = 1.0 - smoothstep(-0.5, 1.0, sdf);
    if (mask < 0.005) discard_fragment();

    // Edge amount: 0 = center, 1 = edge
    float edgeAmt  = 1.0 - smoothstep(0.0, u.cornerRadius * max(u.edgeWidth, 0.1), -sdf);
    float liquidFx = pow(clamp(edgeAmt, 0.0, 1.0), u.liquidPower);

    // SDF gradient → surface normal (points inward)
    float eps = 0.5;
    float2 sdfGrad = float2(
        lg_roundedBoxSDF(pos + float2(eps,0) - center, halfSize, u.cornerRadius) -
        lg_roundedBoxSDF(pos - float2(eps,0) - center, halfSize, u.cornerRadius),
        lg_roundedBoxSDF(pos + float2(0,eps) - center, halfSize, u.cornerRadius) -
        lg_roundedBoxSDF(pos - float2(0,eps) - center, halfSize, u.cornerRadius)
    );
    float sdfLen = length(sdfGrad);
    float2 normal = sdfLen > 0.001 ? sdfGrad / sdfLen
                                   : normalize(pos - center + float2(0.0001));

    // ── Background pixel coordinate (in bg texture pixels) ──────────────────
    // Convert view-point → bg-pixel
    float2 bgPixelBase = u.viewOriginInBg + pos * u.scale;

    // Refraction offset (stronger at edges)
    float refrStrength = u.refractionStrength * liquidFx * u.resolution.y * u.scale.y * 0.3;
    float2 refrOffset  = normal * refrStrength;

    // Blur amount: more blur at center, edge gets refraction-blurred
    float blurCenter = u.blurRadius * u.scale.x * (1.0 - edgeAmt * 0.5);
    float blurEdge   = u.blurRadius * u.scale.x * liquidFx;

    float4 centerSample = lg_blurBg(bgTex, bgPixelBase,                blurCenter);
    float4 edgeSample   = lg_blurBg(bgTex, bgPixelBase + refrOffset,   blurEdge);
    float4 res          = mix(centerSample, edgeSample, liquidFx);

    // ── Chromatic aberration ─────────────────────────────────────────────────
    float caOffset  = u.chromaticAberration * 20.0 * u.scale.x;
    float tinyBlur  = min(u.blurRadius * u.scale.x * 0.08, 3.0);
    float rSample   = lg_blurBg(bgTex, bgPixelBase + refrOffset + normal * caOffset, tinyBlur).r;
    float bSample   = lg_blurBg(bgTex, bgPixelBase + refrOffset - normal * caOffset, tinyBlur).b;
    float caMix     = clamp(u.chromaticAberration * 1.5, 0.0, 0.92);
    res.r = mix(res.r, rSample, caMix);
    res.b = mix(res.b, bSample, caMix);

    // ── Color grading ────────────────────────────────────────────────────────
    res.rgb = lg_saturation(res.rgb, u.saturation);
    res.rgb *= u.brightness;

    // ── Tint ─────────────────────────────────────────────────────────────────
    float3 tint = float3(u.tintR, u.tintG, u.tintB);
    res.rgb = mix(res.rgb, tint, clamp(u.glassOpacity, 0.0, 0.6));

    // ── Glare (specular highlight) ────────────────────────────────────────────
    float2 lightDir = normalize(float2(cos(u.lightAngle), -sin(u.lightAngle)));
    float  glareAmt = pow(max(dot(normal, lightDir), 0.0), 12.0) * liquidFx * u.glareIntensity;
    res.rgb += float3(1.0) * glareAmt;

    // ── Fresnel edge glow ────────────────────────────────────────────────────
    float fresnel = pow(clamp(edgeAmt, 0.0, 1.0), u.fresnelPower) * u.edgeGlowIntensity;
    res.rgb += float3(1.0) * fresnel;

    // ── Border highlight ─────────────────────────────────────────────────────
    float borderMask = smoothstep(2.5, 0.0, abs(sdf));
    res.rgb += float3(1.0) * borderMask * u.borderIntensity;

    // ── Iridescence ──────────────────────────────────────────────────────────
    if (u.iridescence > 0.01) {
        float2 toCenter  = pos - center;
        float  iridAngle = atan2(toCenter.y, toCenter.x);
        float  iridPhase = iridAngle * 2.5 + u.lightAngle;
        float3 irid = float3(
            0.5 + 0.5 * cos(iridPhase),
            0.5 + 0.5 * cos(iridPhase + 2.094),
            0.5 + 0.5 * cos(iridPhase + 4.189)
        );
        float iridMask = (0.25 + liquidFx * 0.75) * u.iridescence;
        res.rgb = mix(res.rgb, irid, clamp(iridMask, 0.0, 1.0));
    }

    // ── Film grain ───────────────────────────────────────────────────────────
    if (u.noiseIntensity > 0.001) {
        float grain = (lg_hash(pos + float2(0.5)) - 0.5) * u.noiseIntensity;
        res.rgb += float3(grain);
    }

    res.rgb = clamp(res.rgb, 0.0, 1.0);
    res.a   = 1.0;
    return res * mask;
}
"""

// MARK: - Pipeline factory

func makeLiquidGlassPipeline(device: MTLDevice) -> MTLRenderPipelineState? {
    guard let library = try? device.makeLibrary(source: kLiquidGlassMetalSource, options: nil) else {
        print("[LiquidGlass] ❌ Failed to compile Metal shader")
        return nil
    }
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction   = library.makeFunction(name: "lg_vertex")
    desc.fragmentFunction = library.makeFunction(name: "lg_fragment")
    desc.colorAttachments[0].pixelFormat = .bgra8Unorm

    // Alpha blending (mask already baked into alpha)
    desc.colorAttachments[0].isBlendingEnabled           = true
    desc.colorAttachments[0].rgbBlendOperation           = .add
    desc.colorAttachments[0].alphaBlendOperation         = .add
    desc.colorAttachments[0].sourceRGBBlendFactor        = .sourceAlpha
    desc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
    desc.colorAttachments[0].sourceAlphaBlendFactor      = .one
    desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    return try? device.makeRenderPipelineState(descriptor: desc)
}
