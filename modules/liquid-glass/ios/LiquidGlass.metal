#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut lg_vertex(uint vid [[vertex_id]],
                           constant float4* verts [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(verts[vid].xy, 0.0, 1.0);
    out.texCoord = verts[vid].zw;
    return out;
}

struct Uniforms {
    float2 resolution;
    float2 scale;
    float2 bgTextureSize;
    float2 viewOriginInBg;

    float blurRadius;
    float refractionStrength;
    float ior;
    float magnification;
    float chromaticAberration;
    float edgeGlowIntensity;
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

float lg_roundedBoxSDF(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - halfSize + float2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float4 lg_sampleBg(texture2d<float> tex, float2 pixelCoord) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 bgSize = float2(tex.get_width(), tex.get_height());
    float2 uv = clamp(pixelCoord, float2(0.0), bgSize - float2(1.0)) / bgSize;
    return tex.sample(s, uv);
}

float4 lg_blurBg(texture2d<float> tex, float2 pixelCoord, float radius) {
    if (radius < 0.5) {
        return lg_sampleBg(tex, pixelCoord);
    }

    float r = min(radius, 36.0);

    if (r < 2.0) {
        float4 c = lg_sampleBg(tex, pixelCoord) * 0.44;
        c += lg_sampleBg(tex, pixelCoord + float2(-r, 0.0)) * 0.14;
        c += lg_sampleBg(tex, pixelCoord + float2(r, 0.0)) * 0.14;
        c += lg_sampleBg(tex, pixelCoord + float2(0.0, -r)) * 0.14;
        c += lg_sampleBg(tex, pixelCoord + float2(0.0, r)) * 0.14;
        return c;
    }

    float d = r * 0.70710678;
    float4 c = lg_sampleBg(tex, pixelCoord) * 0.28;
    c += lg_sampleBg(tex, pixelCoord + float2(-r, 0.0)) * 0.12;
    c += lg_sampleBg(tex, pixelCoord + float2(r, 0.0)) * 0.12;
    c += lg_sampleBg(tex, pixelCoord + float2(0.0, -r)) * 0.12;
    c += lg_sampleBg(tex, pixelCoord + float2(0.0, r)) * 0.12;
    c += lg_sampleBg(tex, pixelCoord + float2(-d, -d)) * 0.06;
    c += lg_sampleBg(tex, pixelCoord + float2(d, -d)) * 0.06;
    c += lg_sampleBg(tex, pixelCoord + float2(-d, d)) * 0.06;
    c += lg_sampleBg(tex, pixelCoord + float2(d, d)) * 0.06;
    return c;
}

float3 lg_saturation(float3 color, float sat) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return mix(float3(luma), color, sat);
}

float lg_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

fragment float4 lg_fragment(VertexOut in [[stage_in]],
                            constant Uniforms& u [[buffer(0)]],
                            texture2d<float> bgTex [[texture(0)]]) {
    float2 uv = in.texCoord;
    float2 pos = uv * u.resolution;

    float2 center = u.resolution * 0.5;
    float2 halfSize = u.resolution * 0.5;
    float sdf = lg_roundedBoxSDF(pos - center, halfSize, u.cornerRadius);

    float mask = 1.0 - smoothstep(-0.5, 1.0, sdf);
    if (mask < 0.005) {
        discard_fragment();
    }

    float edgeAmt = 1.0 - smoothstep(0.0, u.cornerRadius * max(u.edgeWidth, 0.1), -sdf);
    float liquidFx = pow(clamp(edgeAmt, 0.0, 1.0), u.liquidPower);

    float eps = 0.5;
    float2 sdfGrad = float2(
        lg_roundedBoxSDF(pos + float2(eps, 0.0) - center, halfSize, u.cornerRadius) -
            lg_roundedBoxSDF(pos - float2(eps, 0.0) - center, halfSize, u.cornerRadius),
        lg_roundedBoxSDF(pos + float2(0.0, eps) - center, halfSize, u.cornerRadius) -
            lg_roundedBoxSDF(pos - float2(0.0, eps) - center, halfSize, u.cornerRadius)
    );
    float sdfLen = length(sdfGrad);
    float2 normal = sdfLen > 0.001 ? sdfGrad / sdfLen : normalize(pos - center + float2(0.0001));

    float2 bgPixelBase = u.viewOriginInBg + pos * u.scale;

    float opticalGain = 1.0 + max(0.0, u.ior - 1.0) * 0.28 + max(0.0, u.magnification - 1.0) * 0.45;
    float refrStrength = u.refractionStrength * opticalGain * liquidFx * u.resolution.y * u.scale.y * 0.18;
    float2 refrOffset = normal * refrStrength;

    float blurCenter = u.blurRadius * u.scale.x * (1.0 - edgeAmt * 0.5);
    float blurEdge = u.blurRadius * u.scale.x * liquidFx;

    float4 centerSample = lg_blurBg(bgTex, bgPixelBase, blurCenter);
    float4 res = centerSample;
    if (liquidFx > 0.02 && refrStrength > 0.001) {
        float4 edgeSample = lg_blurBg(bgTex, bgPixelBase + refrOffset, blurEdge);
        res = mix(centerSample, edgeSample, liquidFx);
    }

    if (u.chromaticAberration > 0.001) {
        float caOffset = u.chromaticAberration * 12.0 * u.scale.x;
        float tinyBlur = min(u.blurRadius * u.scale.x * 0.08, 3.0);
        float rSample = lg_blurBg(bgTex, bgPixelBase + refrOffset + normal * caOffset, tinyBlur).r;
        float bSample = lg_blurBg(bgTex, bgPixelBase + refrOffset - normal * caOffset, tinyBlur).b;
        float caMix = clamp(u.chromaticAberration * 1.5, 0.0, 0.92);
        res.r = mix(res.r, rSample, caMix);
        res.b = mix(res.b, bSample, caMix);
    }

    res.rgb = lg_saturation(res.rgb, u.saturation);
    res.rgb *= u.brightness;

    float3 tint = float3(u.tintR, u.tintG, u.tintB);
    res.rgb = mix(res.rgb, tint, clamp(u.glassOpacity, 0.0, 0.6));

    float2 lightDir = normalize(float2(cos(u.lightAngle), -sin(u.lightAngle)));
    float glareAmt = pow(max(dot(normal, lightDir), 0.0), 12.0) * liquidFx * u.glareIntensity;
    res.rgb += float3(1.0) * glareAmt;

    float fresnel = pow(clamp(edgeAmt, 0.0, 1.0), u.fresnelPower) * u.edgeGlowIntensity;
    res.rgb += float3(1.0) * fresnel;

    float borderMask = smoothstep(2.5, 0.0, abs(sdf));
    res.rgb += float3(1.0) * borderMask * u.borderIntensity;

    if (u.iridescence > 0.01) {
        float2 toCenter = pos - center;
        float iridAngle = atan2(toCenter.y, toCenter.x);
        float iridPhase = iridAngle * 2.5 + u.lightAngle;
        float3 irid = float3(
            0.5 + 0.5 * cos(iridPhase),
            0.5 + 0.5 * cos(iridPhase + 2.094),
            0.5 + 0.5 * cos(iridPhase + 4.189)
        );
        float iridMask = (0.25 + liquidFx * 0.75) * u.iridescence;
        res.rgb = mix(res.rgb, irid, clamp(iridMask, 0.0, 1.0));
    }

    if (u.noiseIntensity > 0.001) {
        float grain = (lg_hash(pos + float2(0.5)) - 0.5) * u.noiseIntensity;
        res.rgb += float3(grain);
    }

    res.rgb = clamp(res.rgb, 0.0, 1.0);
    res.a = 1.0;
    return res * mask;
}
