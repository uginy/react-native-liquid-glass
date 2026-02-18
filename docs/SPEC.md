# Liquid Glass — Technical Specification

## Overview

A native Android Expo module that renders a liquid glass (glassmorphism 2.0) effect
using AGSL (Android Graphics Shading Language) RuntimeShader, targeting the visual quality
of iOS 26 Liquid Glass on Android devices.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  JavaScript (React Native)                      │
│  ┌───────────────────────────────────────────┐   │
│  │ <LiquidGlassView>                        │   │
│  │   Props → tintColor, blur, ior, etc.     │   │
│  └───────────────┬───────────────────────────┘   │
│                  │ Expo Modules Bridge           │
├──────────────────┼──────────────────────────────┤
│  Native Android  │                              │
│  ┌───────────────▼───────────────────────────┐   │
│  │ LiquidGlassModule.kt                     │   │
│  │   Prop definitions → View binding         │   │
│  └───────────────┬───────────────────────────┘   │
│  ┌───────────────▼───────────────────────────┐   │
│  │ LiquidGlassView.kt (ExpoView)            │   │
│  │   ┌──────────────────────────────────┐    │   │
│  │   │ Backdrop Capture                 │    │   │
│  │   │ (ViewTreeObserver → Bitmap)      │    │   │
│  │   └──────────┬───────────────────────┘    │   │
│  │   ┌──────────▼───────────────────────┐    │   │
│  │   │ AGSL Shader (GPU)                │    │   │
│  │   │ • Multi-tap Gaussian blur        │    │   │
│  │   │ • UV refraction + IOR            │    │   │
│  │   │ • Chromatic aberration           │    │   │
│  │   │ • Lensing / magnification        │    │   │
│  │   │ • Fresnel edge glow              │    │   │
│  │   │ • Specular glare                 │    │   │
│  │   │ • Rounded rect SDF mask          │    │   │
│  │   └──────────────────────────────────┘    │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Shader Pipeline (per-pixel)

1. **SDF Mask** — rounded rectangle signed distance field for smooth card edges
2. **Edge Factor** — distance from edge for fresnel and refraction falloff
3. **Lensing** — UV magnification from center (simulates thick glass)
4. **Refraction** — UV displacement based on IOR and normal vector
5. **Chromatic Aberration** — separate R/G/B UV offsets
6. **Gaussian Blur** — 12×12 multi-tap weighted sampling at distorted UVs
7. **Glass Tint** — mix refracted color with tint
8. **Fresnel Glow** — pow(edgeDist, fresnelPower) × edgeGlow
9. **Specular Glare** — directional dot(normal, lightDir)^16
10. **Top Shine** — subtle highlight at card top edge
11. **Alpha Mask** — smooth SDF mask for anti-aliased edges

## Platform Requirements

- Android 13+ (API 33) for RuntimeShader / AGSL
- GPU: Adreno 6xx+, Mali-G78+, PowerVR 9XTP+ (any modern mobile GPU)

## Performance Targets

- **60 FPS** minimum on mid-range (Snapdragon 695+)
- **120 FPS** target on flagship (Snapdragon 8 Gen 2+)
- GPU-only rendering — zero JS thread blocking
- Backdrop capture via ViewTreeObserver (no polling)

## Parameters (15 configurable props)

| Parameter           | Range   | Default | Effect                      |
| ------------------- | ------- | ------- | --------------------------- |
| blurRadius          | 0-60    | 20      | Backdrop blur intensity     |
| refractionStrength  | 0-0.1   | 0.03    | UV displacement magnitude   |
| ior                 | 1.0-2.0 | 1.2     | Index of Refraction         |
| chromaticAberration | 0-0.03  | 0.006   | RGB channel separation      |
| edgeGlowIntensity   | 0-1.5   | 0.6     | Fresnel edge brightness     |
| magnification       | 0.9-1.3 | 1.08    | Center lens zoom            |
| glassOpacity        | 0-0.5   | 0.12    | Tint blending amount        |
| tintColor           | [0-1]×3 | [1,1,1] | Glass tint RGB              |
| fresnelPower        | 1-8     | 3.0     | Edge glow falloff sharpness |
| cornerRadius        | 0-60    | 32      | Rounded corner pixels       |
| shadowOpacity       | 0-1     | 0.2     | External drop shadow        |
| glareIntensity      | 0-1     | 0.3     | Specular highlight strength |
| lightAngle          | 0-2π    | 0.8     | Light source direction      |

## Files

```
modules/liquid-glass/
  src/
    index.ts                  — barrel exports
    LiquidGlass.types.ts      — TypeScript types + presets
    LiquidGlassView.tsx       — React wrapper component
  android/
    build.gradle              — Android library config
    src/main/java/com/liquidglass/
      LiquidGlassModule.kt   — Expo module (prop bindings)
      LiquidGlassView.kt     — Native view + AGSL shader
```
