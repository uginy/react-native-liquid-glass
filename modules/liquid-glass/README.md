# @uginy/react-native-liquid-glass

[![npm version](https://img.shields.io/npm/v/@uginy/react-native-liquid-glass.svg)](https://www.npmjs.com/package/@uginy/react-native-liquid-glass)
[![npm downloads](https://img.shields.io/npm/dm/@uginy/react-native-liquid-glass.svg)](https://www.npmjs.com/package/@uginy/react-native-liquid-glass)
[![license](https://img.shields.io/npm/l/@uginy/react-native-liquid-glass.svg)](LICENSE)
[![platform android](https://img.shields.io/badge/Android-13%2B-brightgreen.svg?logo=android)](https://developer.android.com/about/versions/13)
[![platform ios](https://img.shields.io/badge/iOS-15%2B-blue.svg?logo=apple)](https://developer.apple.com)

**📦 [npmjs.com/package/@uginy/react-native-liquid-glass](https://www.npmjs.com/package/@uginy/react-native-liquid-glass)**

---

## Demo

[![Watch Demo on YouTube](https://raw.githubusercontent.com/uginy/react-native-liquid-glass/main/modules/liquid-glass/demo.jpg)](https://www.youtube.com/shorts/GCt0NsWkf98)

---

## What is this?

**A beautiful "liquid glass" blur effect for React Native cards and UI elements — on both Android and iOS.**

The "liquid glass" aesthetic became popular in modern mobile UI design. It gives UI elements a translucent, frosted-glass look with light refraction, blurred backdrop, edge glow, and glare — similar to looking through a piece of slightly curved glass.

**The problem this solves:** React Native has no built-in way to achieve this effect with rich glass controls across platforms. This library provides a unified API with high-fidelity Android shaders and a native iOS Metal renderer.

---

## Platform support

| Platform | Implementation | Min version | Notes |
|----------|---------------|-------------|-------|
| **Android** | AGSL GPU shader (`RuntimeShader`) | API 33 (Android 13) | Full shader: refraction, chromatic aberration, iridescence |
| **iOS** | Metal shader + shared backdrop texture | iOS 15+ | Same props API, iOS-native GPU pipeline |

---

## Installation

```bash
npm install @uginy/react-native-liquid-glass
# or
yarn add @uginy/react-native-liquid-glass
```

**If you use Expo (most common):**

```bash
npx expo prebuild --clean
npx expo run:android   # for Android
npx expo run:ios       # for iOS
```

> ⚠️ This library uses native code. **Expo Go does not work** — you need a dev build or bare React Native.

---

## Requirements

| | Requirement |
|---|---|
| Android | API 33+ (Android 13+), New Architecture enabled |
| iOS | iOS 15+ |
| React Native | New Architecture (`newArchEnabled=true`) |
| Expo | SDK 54+ |

**Enable New Architecture in `app.json`:**

```json
{
  "expo": {
    "plugins": [
      ["expo-build-properties", {
        "android": { "newArchEnabled": true },
        "ios": { "newArchEnabled": true }
      }]
    ]
  }
}
```

---

## Quick Start

The simplest example — a glass card over a background image:

```tsx
import React from 'react';
import { ImageBackground, Text, StyleSheet } from 'react-native';
import { LiquidGlassView } from '@uginy/react-native-liquid-glass';

const bg = require('./assets/background.png');

export default function App() {
  return (
    <ImageBackground source={bg} style={styles.bg}>
      <LiquidGlassView style={styles.card}>
        <Text style={styles.text}>Hello, Glass! 🔮</Text>
      </LiquidGlassView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  bg: { flex: 1, justifyContent: 'center', padding: 20 },
  card: { borderRadius: 24, padding: 20 },
  text: { color: '#fff', fontSize: 20, fontWeight: '700' },
});
```

---

## Examples

### Basic glass card

```tsx
<LiquidGlassView
  blurRadius={30}
  tintColor="#ffffff"
  glassOpacity={0.08}
  cornerRadius={20}
  style={{ width: '100%', height: 100 }}
>
  <Text style={{ color: '#fff', padding: 20 }}>Simple card</Text>
</LiquidGlassView>
```

### Frosted glass panel

```tsx
<LiquidGlassView
  blurRadius={60}
  tintColor="#ffffff"
  glassOpacity={0.12}
  noiseIntensity={0.08}   // adds grain — more "frosted" look
  saturation={1.2}
  cornerRadius={16}
  style={{ padding: 20 }}
>
  <Text style={{ color: '#fff' }}>Frosted panel</Text>
</LiquidGlassView>
```

### Crystal / diamond effect

```tsx
<LiquidGlassView
  blurRadius={20}
  refractionStrength={0.12}   // strong refraction
  chromaticAberration={0.3}   // rainbow edges
  glareIntensity={0.8}
  edgeGlowIntensity={0.5}
  fresnelPower={2.5}
  glassOpacity={0.02}
  cornerRadius={32}
  style={{ width: 200, height: 200 }}
>
  <Text style={{ color: '#fff' }}>Crystal 💎</Text>
</LiquidGlassView>
```

### Iridescent / rainbow glass

```tsx
<LiquidGlassView
  iridescence={0.7}           // rainbow shimmer
  edgeGlowIntensity={0.3}
  blurRadius={40}
  cornerRadius={24}
  style={{ padding: 20 }}
>
  <Text style={{ color: '#fff' }}>Iridescent 🌈</Text>
</LiquidGlassView>
```

### Warm amber tint

```tsx
<LiquidGlassView
  tintColor="#ffead1"
  glassOpacity={0.2}
  blurRadius={45}
  saturation={1.3}
  brightness={1.1}
  cornerRadius={24}
  style={{ padding: 20 }}
>
  <Text style={{ color: '#fff' }}>Warm ☀️</Text>
</LiquidGlassView>
```

### Using built-in presets (fastest way to start)

```tsx
import {
  LiquidGlassView,
  LIQUID_GLASS_DEFAULTS,
  LIQUID_GLASS_FROSTED,
  LIQUID_GLASS_CRYSTAL,
  LIQUID_GLASS_WARM,
  LIQUID_GLASS_IRIDESCENT,
} from '@uginy/react-native-liquid-glass';

// Just spread a preset and override style
<LiquidGlassView {...LIQUID_GLASS_CRYSTAL} style={{ borderRadius: 24, padding: 20 }}>
  <Text style={{ color: '#fff' }}>Crystal preset</Text>
</LiquidGlassView>
```

| Preset | Description |
|---|---|
| `LIQUID_GLASS_DEFAULTS` | Balanced default |
| `LIQUID_GLASS_FROSTED` | Matte frosted glass with grain |
| `LIQUID_GLASS_CRYSTAL` | High refraction, diamond-like |
| `LIQUID_GLASS_WARM` | Warm amber tint |
| `LIQUID_GLASS_IRIDESCENT` | Rainbow shimmer effect |

---

## All Props

### Blur & Distortion

| Prop | Type | Default | Range | Description |
|---|---|---|---|---|
| `blurRadius` | `number` | `20` | 0–100 | Blur strength behind the glass |
| `refractionStrength` | `number` | `0.03` | 0–0.2 | How much edges bend/distort the background |
| `ior` | `number` | `1.2` | 1–3 | Index of Refraction (like glass=1.5, water=1.33) |
| `chromaticAberration` | `number` | `0.05` | 0–1 | RGB color split at edges (prism effect) |
| `magnification` | `number` | `1.08` | 1–1.5 | Center magnification (lens effect) |

### Tint & Color

| Prop | Type | Default | Range | Description |
|---|---|---|---|---|
| `tintColor` | `string` | `'#ffffff'` | hex color | Glass color tint (`#fff`, `#e6eeff`, etc.) |
| `glassOpacity` | `number` | `0.05` | 0–0.5 | How strongly the tint blends |
| `saturation` | `number` | `1.0` | 0–2 | Backdrop saturation (0=grayscale, 2=vivid) |
| `brightness` | `number` | `1.0` | 0–2 | Backdrop brightness multiplier |
| `noiseIntensity` | `number` | `0.0` | 0–0.15 | Film grain / frosted texture overlay |
| `iridescence` | `number` | `0.0` | 0–1 | Rainbow iridescent shimmer at edges |

### Edges & Light

| Prop | Type | Default | Range | Description |
|---|---|---|---|---|
| `edgeGlowIntensity` | `number` | `0.18` | 0–1 | Brightness of the edge glow (Fresnel) |
| `fresnelPower` | `number` | `3.0` | 0.5–8 | How sharp/narrow the edge glow falloff is |
| `glareIntensity` | `number` | `0.3` | 0–1 | Specular highlight (bright spot) intensity |
| `lightAngle` | `number` | `0.8` | 0–6.28 | Light direction in radians (0=right, π/2=up) |
| `borderIntensity` | `number` | `0.28` | 0–0.5 | Inner border highlight brightness |
| `edgeWidth` | `number` | `2.0` | 0.5–5 | Width of the liquid edge distortion zone |
| `liquidPower` | `number` | `1.5` | 0.5–3 | Curvature of liquid edge shape |

### Shape & Shadow

| Prop | Type | Default | Description |
|---|---|---|---|
| `cornerRadius` | `number` | `24` | Rounded corner radius in points |
| `shadowOpacity` | `number` | `0.0` | Drop shadow opacity (0 = disabled) |

---

## How does it work?

**Android:** Uses Android 13's `RuntimeShader` (AGSL — Android Graphics Shading Language) to run a custom GPU shader that:
1. Captures a screenshot of the background view once (shared across all glass views)
2. Passes it as a `BitmapShader` texture to the GPU shader
3. Renders per-pixel: blur samples, refraction offset, edge SDF (signed distance field), chromatic aberration, Fresnel, glare, iridescence, noise
4. `propsDirty` flag ensures AGSL uniform updates only on prop changes — scroll/position redraws cost just 2 uniform calls

**iOS:** Uses a native Metal shader pipeline:
1. Shared `MTLDevice` + `MTLRenderPipelineState` — compiled once for all instances
2. Single `CADisplayLink` shared across all views — one frame callback regardless of how many glass views are on screen
3. Shared backdrop `MTLTexture` — captured once, reused by all instances with per-view offset mapping
4. `CAMetalLayer.contentsScale` capped at 2× — prevents overdraw on 3× ProMotion screens

---

## Limitations

| | Android | iOS |
|---|---|---|
| Live blur (updates on scroll) | ✅ Yes | ✅ Yes |
| Refraction / distortion | ✅ Full shader | ✅ Full shader |
| Chromatic aberration | ✅ Yes | ✅ Yes |
| Blur style control | ✅ Exact radius | ✅ Exact radius |
| Iridescence | ✅ Yes | ✅ Yes |
| Minimum OS | Android 13+ | iOS 15+ |
| Expo Go | ❌ Not supported | ❌ Not supported |
| Web | ❌ Not supported | ❌ Not supported |

> **Why Android 13+?** The AGSL `RuntimeShader` API was introduced in API 33. On older Android versions, you'll need to use a different blur approach or hide the component.

---

## Troubleshooting

### The effect doesn't show / cards are transparent

- Make sure you have a **background image or colored view** behind the `LiquidGlassView`. The glass effect blurs what's behind it — if there's nothing behind, it will be transparent.
- On Android: check you're running **Android 13+** and have **New Architecture** enabled.
- Make sure you're using a **dev build**, not Expo Go.

### Build errors after installing

Run:
```bash
npx expo prebuild --clean
npx expo run:android
npx expo run:ios
```

### On Android the glass is opaque / no blur

Ensure `newArchEnabled=true` in your `android/gradle.properties` or `app.json`.

## TypeScript

The library is fully typed. Import types if needed:

```tsx
import type { LiquidGlassViewProps } from '@uginy/react-native-liquid-glass';
```

---

## Performance tips

- Use `blurRadius` ≤ 60 for best performance on mid-range devices
- Avoid rendering more than 10–15 glass views simultaneously
- Use `shadowOpacity={0}` unless you specifically need shadows (saves a render pass)
- **Shared backdrop** — background capture is done once and reused by all glass views on screen; scroll only updates the view offset (2 AGSL uniform calls on Android, lightweight on iOS)
- **iOS:** all instances share one `CADisplayLink` and one Metal pipeline — adding more glass views has near-zero overhead on the frame loop
- **Android:** static props (blur, tint, refraction, etc.) are set on the AGSL shader only when they change, not on every frame

---

## License

MIT © [Ugin](https://github.com/uginy)
