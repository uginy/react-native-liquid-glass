# Changelog

All notable changes to `react-native-liquid-glass` will be documented here.

## [1.2.4] - 2026-02-18

### Added

- Re-enabled iOS native module autolinking in `expo-module.config.json`
- Native iOS `LiquidGlassView` rebuilt with `UIVisualEffectView` + compositor layers
- iOS implementation now supports the same public props as Android (`blurRadius`, `refractionStrength`, `ior`, `chromaticAberration`, `edgeGlowIntensity`, `magnification`, `glassOpacity`, `glassColor`, `fresnelPower`, `cornerRadius`, `glareIntensity`, `borderIntensity`, `edgeWidth`, `liquidPower`, `lightAngle`, `saturation`, `brightness`, `noiseIntensity`, `iridescence`, `shadowOpacity`)

### Changed

- JS wrapper now uses native `LiquidGlass` view on both Android and iOS
- Package metadata and README updated to document cross-platform support and iOS requirements

## [1.1.0] - 2026-02-18

### Added

- Props: `saturation`, `brightness`, `noiseIntensity`, `iridescence`
- Props: `borderIntensity`, `edgeWidth`, `liquidPower`
- Preset `LIQUID_GLASS_IRIDESCENT`
- Updated README with full props table

### Fixed

- `tintColor` renamed to native prop `glassColor` to avoid React Native New Architecture reserved prop conflict
- AAPT2 PNG crunch disabled in release builds

## [1.0.0] - 2025-02-18

### Added

- Initial stable release
- AGSL `RuntimeShader` based liquid glass effect (Android 13+)
- Props: `blurRadius`, `refractionStrength`, `ior`, `chromaticAberration`, `magnification`
- Props: `tintColor` (hex/rgb string), `glassOpacity`
- Props: `saturation`, `brightness` — backdrop image adjustments
- Props: `noiseIntensity` — frosted glass film grain overlay
- Props: `iridescence` — rainbow edge iridescent effect
- Props: `edgeGlowIntensity`, `fresnelPower`, `glareIntensity`, `lightAngle`
- Props: `borderIntensity`, `edgeWidth`, `liquidPower`
- Props: `cornerRadius`, `shadowOpacity`
- Presets: `LIQUID_GLASS_DEFAULTS`, `LIQUID_GLASS_FROSTED`, `LIQUID_GLASS_CRYSTAL`, `LIQUID_GLASS_WARM`, `LIQUID_GLASS_IRIDESCENT`
- Shared background bitmap capture (single GPU upload for all glass views)
- Auto-retry background capture via `ViewTreeObserver`
- New Architecture (Fabric) compatible

### Fixed

- `tintColor` renamed to native prop `glassColor` to avoid React Native reserved style prop conflict
- AAPT2 PNG crunch disabled in release builds (`android.enablePngCrunchInReleaseBuilds=false`)
