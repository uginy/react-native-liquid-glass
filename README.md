# Liquid Glass for React Native

Monorepo containing the `react-native-liquid-glass` Expo module and a demo app.

```
glass/
├── modules/liquid-glass/   # npm package → react-native-liquid-glass
└── app/                    # Expo demo app (Android)
```

## Module

[`react-native-liquid-glass`](./modules/liquid-glass) — high-performance liquid glass effect powered by native **AGSL GPU shaders** (Android 13+).

## Demo App

The `app/` directory is a standalone Expo project that uses the module as a local dependency.

```bash
cd app
npm install
npx expo run:android
```

## Requirements

- Android 13+ (API 33) — AGSL `RuntimeShader`
- Expo SDK 54+
- New Architecture enabled

## License

MIT
