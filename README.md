# @uginy/react-native-liquid-glass

[![npm version](https://img.shields.io/npm/v/@uginy/react-native-liquid-glass.svg)](https://www.npmjs.com/package/@uginy/react-native-liquid-glass)
[![license](https://img.shields.io/npm/l/@uginy/react-native-liquid-glass.svg)](LICENSE)
[![platform android](https://img.shields.io/badge/Android-13%2B-brightgreen.svg?logo=android)](https://developer.android.com/about/versions/13)
[![platform ios](https://img.shields.io/badge/iOS-15%2B-blue.svg?logo=apple)](https://developer.apple.com)

> 🔮 **Liquid glass blur effect for React Native** — AGSL GPU shader on Android, Metal GPU shader on iOS.

Real-time refraction, chromatic aberration, backdrop blur, iridescence, edge glow and more — at **60–120 FPS**.

---

## Demo

https://github.com/user-attachments/assets/67a8ec01-198a-419b-b619-a53c6c1b8fd1

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

## Quick Start

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

### Frosted glass

```tsx
<LiquidGlassView
  blurRadius={60}
  tintColor="#ffffff"
  glassOpacity={0.12}
  noiseIntensity={0.08}
  cornerRadius={16}
  style={{ padding: 20 }}
>
  <Text style={{ color: '#fff' }}>Frosted 🧊</Text>
</LiquidGlassView>
```

### Crystal / diamond

```tsx
<LiquidGlassView
  blurRadius={20}
  refractionStrength={0.12}
  chromaticAberration={0.3}
  glareIntensity={0.8}
  edgeGlowIntensity={0.5}
  cornerRadius={32}
  style={{ width: 200, height: 200 }}
>
  <Text style={{ color: '#fff' }}>Crystal 💎</Text>
</LiquidGlassView>
```

### Iridescent / rainbow

```tsx
<LiquidGlassView
  iridescence={0.7}
  edgeGlowIntensity={0.3}
  blurRadius={40}
  cornerRadius={24}
  style={{ padding: 20 }}
>
  <Text style={{ color: '#fff' }}>Iridescent 🌈</Text>
</LiquidGlassView>
```

### Built-in presets

```tsx
import { LiquidGlassView, LIQUID_GLASS_CRYSTAL } from '@uginy/react-native-liquid-glass';

<LiquidGlassView {...LIQUID_GLASS_CRYSTAL} style={{ borderRadius: 24, padding: 20 }}>
  <Text style={{ color: '#fff' }}>Crystal preset</Text>
</LiquidGlassView>
```

Available presets: `LIQUID_GLASS_DEFAULTS` · `LIQUID_GLASS_FROSTED` · `LIQUID_GLASS_CRYSTAL` · `LIQUID_GLASS_WARM` · `LIQUID_GLASS_IRIDESCENT`

---

## Key Props

| Prop | Default | Description |
|---|---|---|
| `blurRadius` | `20` | Blur strength (0–100) |
| `refractionStrength` | `0.03` | Edge distortion amount |
| `tintColor` | `#ffffff` | Glass tint color |
| `glassOpacity` | `0.05` | Tint blend strength |
| `chromaticAberration` | `0.05` | RGB color split at edges |
| `edgeGlowIntensity` | `0.18` | Fresnel edge glow |
| `glareIntensity` | `0.3` | Specular highlight |
| `iridescence` | `0.0` | Rainbow shimmer |
| `cornerRadius` | `24` | Rounded corners |
| `noiseIntensity` | `0.0` | Film grain texture |

→ [Full documentation](./modules/liquid-glass/README.md)

---

## Requirements

| | Requirement |
|---|---|
| Android | API 33+ (Android 13+), New Architecture |
| iOS | iOS 15+ |
| React Native | New Architecture (`newArchEnabled=true`) |
| Expo | SDK 54+ |

---

## Limitations

| | Android | iOS |
|---|---|---|
| Refraction / distortion | ✅ Full shader | ✅ Full shader |
| Chromatic aberration | ✅ Yes | ✅ Yes |
| Live backdrop blur | ✅ Yes | ✅ Yes |
| Expo Go | ❌ | ❌ |
| Web | ❌ | ❌ |

---

## Repository structure

```
glass/
├── modules/liquid-glass/   # npm package → @uginy/react-native-liquid-glass
└── app/                    # Expo demo app (Android + iOS)
```

## License

MIT © [Ugin](https://github.com/uginy)
