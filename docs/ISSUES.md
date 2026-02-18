# Current Issues - Liquid Glass Android

## 1. Black borders on startup (CRITICAL)
**Problem:** Cards show black borders for ~1 second at app startup until backdrop is captured. Effect only appears after user starts scrolling.

**Current implementation:**
- View starts with `alpha=0` and fades in when backdrop ready
- Backdrop capture triggered in `onAttachedToWindow()` and `onLayout()`
- PreDrawListener updates backdrop on position changes

**Root cause:** ImageBackground not fully rendered when initial capture happens, resulting in empty/black bitmap until scroll triggers recapture.

**Attempted fixes:**
- Delayed capture with `postDelayed(50ms, 100ms)` - didn't help
- Retry mechanism with exponential backoff - didn't help
- Fade-in animation - hides problem but doesn't solve it

**Need:** Reliable way to capture backdrop only after ImageBackground is fully rendered, or show transparent fallback instead of black.

---

## 2. Dark artifacts on card edges (CRITICAL)
**Problem:** Dark/black reflections appear on card edges, especially visible when adjusting refraction strength slider.

**Root cause:** Refraction and chromatic aberration sample outside captured backdrop bitmap bounds, hitting black/empty pixels beyond margin.

**Current mitigation:**
```glsl
float maxOffset = margin * 0.7;
float refr = min(refractionStrength * liquidFx * resolution.y * 0.3, maxOffset);
float2 uvRefracted = clamp(uv + normal * refr, float2(0.0), resolution);
```

**Issue persists:** Clamping helps but dark edges still visible at higher refraction values. May need:
- Larger margin (currently 120px)
- Better edge handling in shader
- Different sampling strategy near boundaries

---

## 3. Settings panel jittering during slider drag (HIGH)
**Problem:** Settings panel and entire UI jerks/stutters when dragging sliders, making it unusable.

**Root cause:** Each slider value change triggers re-render of all 20 LiquidGlassView cards, causing frame drops.

**Current implementation:**
- Sliders use `initialValue` with local state
- `onChange` only fires on release
- Cards memoized with `useMemo`

**Issue persists:** Despite optimizations, panel still jitters. May need:
- Move settings panel to separate React context
- Use native slider component instead of PanResponder
- Throttle/debounce updates more aggressively
- Separate render tree for settings panel

---

## Technical Context

**Target:** Android 13+ (AGSL RuntimeShader)
**Performance goal:** 60 FPS minimum, 120 FPS ideal
**Current FPS:** ~45-50 during scroll/interaction

**Files:**
- `modules/liquid-glass/android/src/main/java/com/liquidglass/LiquidGlassView.kt` - Native implementation
- `app/App.tsx` - Demo app with settings panel
