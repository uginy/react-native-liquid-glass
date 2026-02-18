import Metal

private let metalSource = """
#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float2 position;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float2 fragCoord;
};

struct Uniforms {
    float2 resolution;
    float2 viewOffset;
    float2 bgSize;
    float blurRadius;
    float refractionStrength;
    float chromaticAberration;
    float edgeGlow;
    float glassOpacity;
    float fresnelPower;
    float cornerRadius;
    float glareIntensity;
    float borderIntensity;
    float edgeWidth;
    float liquidPower;
    float lightAngle;
    float saturation;
    float brightness;
    float noiseIntensity;
    float iridescence;
    float tintR;
    float tintG;
    float tintB;
};

vertex VertexOut vertexShader(uint vid [[vertex_id]],
                               constant Vertex* verts [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(verts[vid].position, 0.0, 1.0);
    out.texCoord = verts[vid].texCoord;
    return out;
}

float roundedBoxSDF(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + float2(r);
    return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float4 sampleBg(texture2d<float> tex, float2 uv, float2 viewOffset, float2 bgSize) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 coord = clamp(uv + viewOffset, float2(0.0), bgSize - float2(1.0)) / bgSize;
    return tex.sample(s, coord);
}

float4 sampleBlurred(texture2d<float> tex, float2 uv, float radius,
                     float2 viewOffset, float2 bgSize) {
    if (radius < 0.5) return sampleBg(tex, uv, viewOffset, bgSize);
    float s = radius * 0.4;
    float4 c = sampleBg(tex, uv, viewOffset, bgSize) * 0.36;
    c += sampleBg(tex, uv + float2(-s,-s), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2( s,-s), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2(-s, s), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2( s, s), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2(-s, 0), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2( s, 0), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2( 0,-s), viewOffset, bgSize) * 0.08;
    c += sampleBg(tex, uv + float2( 0, s), viewOffset, bgSize) * 0.08;
    return c;
}

float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float3 applySaturation(float3 color, float sat) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return mix(float3(luma), color, sat);
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                constant Uniforms& u [[buffer(0)]],
                                texture2d<float> bgTex [[texture(0)]]) {
    float2 uv = in.texCoord * u.resolution;
    float2 center = u.resolution * 0.5;
    float sdf = roundedBoxSDF(uv - center, u.resolution * 0.5, u.cornerRadius);
    float mask = 1.0 - smoothstep(-1.0, 1.5, sdf);
    if (mask < 0.01) return float4(0.0);

    float edgeAmt = 1.0 - smoothstep(0.0, u.cornerRadius * u.edgeWidth, -sdf);
    float liquidFx = pow(max(edgeAmt, 0.0), u.liquidPower);

    float eps = 1.0;
    float2 sdfGrad = float2(
        roundedBoxSDF(uv + float2(eps,0) - center, u.resolution*0.5, u.cornerRadius) -
        roundedBoxSDF(uv - float2(eps,0) - center, u.resolution*0.5, u.cornerRadius),
        roundedBoxSDF(uv + float2(0,eps) - center, u.resolution*0.5, u.cornerRadius) -
        roundedBoxSDF(uv - float2(0,eps) - center, u.resolution*0.5, u.cornerRadius)
    );
    float sdfLen = length(sdfGrad);
    float2 normal = sdfLen > 0.001 ? sdfGrad / sdfLen
        : normalize((uv - center) / u.resolution + float2(0.0001));

    float refr = u.refractionStrength * liquidFx * u.resolution.y * 0.25;
    float2 uvRefracted = uv + normal * refr;

    float blurAmt = u.blurRadius * liquidFx;
    float blurCenter = u.blurRadius * (1.0 - edgeAmt * 0.6);

    float4 centerBlur = sampleBlurred(bgTex, uv, blurCenter, u.viewOffset, u.bgSize);
    float4 edgeBlur = sampleBlurred(bgTex, uvRefracted, blurAmt, u.viewOffset, u.bgSize);
    float4 res = mix(centerBlur, edgeBlur, liquidFx);

    float caOffset = u.chromaticAberration * 18.0;
    float tinyBlur = min(u.blurRadius * 0.1, 2.5);
    float rSample = sampleBlurred(bgTex, uvRefracted + normal * caOffset, tinyBlur, u.viewOffset, u.bgSize).r;
    float bSample = sampleBlurred(bgTex, uvRefracted - normal * caOffset, tinyBlur, u.viewOffset, u.bgSize).b;
    float caMix = clamp(u.chromaticAberration * 1.2, 0.0, 0.9);
    res.r = mix(res.r, rSample, caMix);
    res.b = mix(res.b, bSample, caMix);

    res.rgb = applySaturation(res.rgb, u.saturation);
    res.rgb *= u.brightness;

    res.rgb = mix(res.rgb, float3(u.tintR, u.tintG, u.tintB), u.glassOpacity);

    float2 lightDir = normalize(float2(cos(u.lightAngle), -sin(u.lightAngle)));
    float glareAmt = pow(max(dot(normal, lightDir), 0.0), 15.0) * liquidFx * u.glareIntensity;
    res.rgb += float3(1.0) * glareAmt;

    res.rgb += float3(1.0) * pow(edgeAmt, u.fresnelPower) * u.edgeGlow;

    res.rgb += float3(1.0) * smoothstep(2.0, 0.5, abs(sdf)) * u.borderIntensity;

    float2 toCenter = uv - center;
    float iridAngle = atan2(toCenter.y, toCenter.x);
    float iridPhase = iridAngle * 2.5;
    float3 irid = float3(
        0.5 + 0.5 * cos(iridPhase),
        0.5 + 0.5 * cos(iridPhase + 2.094),
        0.5 + 0.5 * cos(iridPhase + 4.189)
    );
    float iridWide = 0.25 + liquidFx * 0.75;
    float iridMask = iridWide * u.iridescence;
    res.rgb = mix(res.rgb, irid, clamp(iridMask, 0.0, 1.0));

    float grain = (hash21(uv) - 0.5) * u.noiseIntensity;
    res.rgb += float3(grain);

    res.a = 1.0;
    return res * mask;
}
"""

func makeShaderLibrary(device: MTLDevice) -> MTLLibrary? {
    return try? device.makeLibrary(source: metalSource, options: nil)
}
