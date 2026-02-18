# react-native-liquid-glass

[![npm version](https://img.shields.io/npm/v/react-native-liquid-glass.svg)](https://www.npmjs.com/package/react-native-liquid-glass)
[![license](https://img.shields.io/npm/l/react-native-liquid-glass.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-Android%2013%2B-brightgreen.svg)](https://developer.android.com/about/versions/13)

High-performance **Liquid Glass** effect for React Native (Android), powered by native **AGSL GPU shaders**. Brings the iOS 26 liquid glass aesthetic to Android with real-time refraction, chromatic aberration, backdrop blur, iridescence, and more — all at **60–120 FPS**.

## Features

- 🔮 Real refraction with configurable IOR
- 🌈 Chromatic aberration — per-channel RGB offset at edges
- 🎨 Glass tinting — hex/rgb color string (`#rrggbb`, `#rgb`, `rgb(r,g,b)`)
- 💎 Fresnel edge glow with configurable power falloff
- ✨ Directional specular glare
- 🫧 Iridescent rainbow edge effect
- 🎞️ Film grain / frosted noise overlay
- 🌈 Saturation & brightness controls
- 🟦 Multi-tap backdrop blur
- 📦 Presets: Default, Frosted, Crystal, Warm, Iridescent
- ⚡ 60–120 FPS — GPU-accelerated via Android `RuntimeShader`
- 🧩 Expo Module — works with Expo dev builds & bare RN

## Requirements

- **Android 13+** (API 33) — required for AGSL `RuntimeShader`
- **Expo SDK 54+** or bare React Native with Expo Modules
- **New Architecture** enabled (`newArchEnabled=true`)

## Installation

```bash
npm install react-native-liquid-glass
```

If using Expo:

```bash
npx expo prebuild --clean
npx expo run:android
```

## Quick Start

```tsx
import { LiquidGlassView } from 'react-native-liquid-glass';

export default function MyScreen() {
  return (
    <ImageBackground source={backgroundImage} style={{ flex: 1 }}>
      <LiquidGlassView
        blurRadius={20}
        refractionStrength={0.04}
        tintColor="#e6eeff"
        glassOpacity={0.15}
        cornerRadius={24}
        style={{ width: '100%', height: 100 }}
      >
        <Text style={{ color: '#fff', padding: 20 }}>Glass Card</Text>
      </LiquidGlassView>
    </ImageBackground>
  );
}
```

## Props

### Blur & Distortion

| Prop                  | Type     | Default | Range    | Description                      |
| --------------------- | -------- | ------- | -------- | -------------------------------- |
| `blurRadius`          | `number` | `20`    | 0–100    | Backdrop blur radius             |
| `refractionStrength`  | `number` | `0.03`  | 0–0.2    | UV displacement at edges         |
| `ior`                 | `number` | `1.2`   | 1–3      | Index of Refraction              |
| `chromaticAberration` | `number` | `0.05`  | 0–1      | RGB channel split amount         |
| `magnification`       | `number` | `1.08`  | 1–1.5    | Center lens zoom factor          |

### Tint & Color

| Prop           | Type     | Default     | Description                                              |
| -------------- | -------- | ----------- | -------------------------------------------------------- |
| `tintColor`    | `string` | `'#ffffff'` | Glass tint color — hex `#rgb`, `#rrggbb`, or `rgb(...)` |
| `glassOpacity` | `number` | `0.05`      | 0–0.5  — tint blend amount                               |
| `saturation`   | `number` | `1.0`       | 0–2  — backdrop saturation multiplier                    |
| `brightness`   | `number` | `1.0`       | 0–2  — backdrop brightness multiplier                    |
| `noiseIntensity` | `number` | `0.0`     | 0–0.15 — frosted glass film grain                        |
| `iridescence`  | `number` | `0.0`       | 0–1  — rainbow iridescent edge effect                    |

### Edges & Light

| Prop               | Type     | Default | Range     | Description                         |
| ------------------ | -------- | ------- | --------- | ----------------------------------- |
| `edgeGlowIntensity`| `number` | `0.18`  | 0–1       | Fresnel edge glow brightness        |
| `fresnelPower`     | `number` | `3.0`   | 0.5–8     | Edge glow falloff sharpness         |
| `glareIntensity`   | `number` | `0.3`   | 0–1       | Specular highlight intensity        |
| `lightAngle`       | `number` | `0.8`   | 0–6.28    | Light source angle (radians)        |
| `borderIntensity`  | `number` | `0.28`  | 0–0.5     | Inner border highlight strength     |
| `edgeWidth`        | `number` | `2.0`   | 0.5–5     | Thickness of the liquid edge zone   |
| `liquidPower`      | `number` | `1.5`   | 0.5–3     | Liquid edge effect curvature        |

### Shape & Shadow

| Prop            | Type     | Default | Description                    |
| --------------- | -------- | ------- | ------------------------------ |
| `cornerRadius`  | `number` | `24`    | Rounded corner radius (px)     |
| `shadowOpacity` | `number` | `0.0`   | Drop shadow opacity (0 = off)  |

## Presets

```tsx
import {
  LIQUID_GLASS_DEFAULTS,
  LIQUID_GLASS_FROSTED,
  LIQUID_GLASS_CRYSTAL,
  LIQUID_GLASS_WARM,
  LIQUID_GLASS_IRIDESCENT,
} from 'react-native-liquid-glass';

<LiquidGlassView {...LIQUID_GLASS_CRYSTAL} style={styles.card}>
  <Text>Crystal Glass</Text>
</LiquidGlassView>
```

| Preset                    | Description                          |
| ------------------------- | ------------------------------------ |
| `LIQUID_GLASS_DEFAULTS`   | iOS-like default glass               |
| `LIQUID_GLASS_FROSTED`    | Matte frosted look with grain        |
| `LIQUID_GLASS_CRYSTAL`    | High-refraction diamond-like crystal |
| `LIQUID_GLASS_WARM`       | Warm amber tint                      |
| `LIQUID_GLASS_IRIDESCENT` | Rainbow iridescent effect            |

## Performance

Shader runs entirely on the GPU via Android `RuntimeShader` API:

- Zero JS thread blocking
- Hardware-accelerated blur and refraction
- Shared background bitmap across all views (single capture)
- Efficient position tracking via `ViewTreeObserver.OnPreDrawListener`
- 60 FPS on mid-range, 120 FPS on flagship devices

## License

MIT
