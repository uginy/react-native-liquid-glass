# Liquid Glass Android — Анализ реализации

## Что сделано

Expo модуль с нативным AGSL шейдером для Android 13+, демо с 20 карточками на цветном фоне.

## Архитектура

**TypeScript слой:**
- Expo module bridge с 7 активными пропами
- 4 пресета (defaults, frosted, crystal, warm)
- Fallback на обычный View для не-Android

**Kotlin нативный слой:**
- RuntimeShader (AGSL) на GPU
- Backdrop capture через ViewTreeObserver
- Sensor-based tilt tracking (акселерометр/rotation vector)
- Margin-based sampling (100px буфер вокруг view)

## Шейдер — что работает

### ✅ Реализовано корректно

1. **Rounded rect SDF** — плавные углы через signed distance field
2. **Edge-based liquid effect** — `pow(edgeAmt, 2.0)` создает концентрацию эффекта на краях
3. **Chromatic aberration** — RGB split с учетом light direction
4. **Refraction** — UV displacement по нормали, масштабируется с liquidFx
5. **Blur approximation** — 5-tap cross pattern (центр + 4 стороны)
6. **Specular highlight** — `pow(NdotL, 10.0)` для glare
7. **Iridescent rim glow** — цветовой сдвиг через cos() с tilt offset
8. **Pure transparency в центре** — `if (edgeAmt < 0.02)` пропускает центр без обработки

### 🔴 Проблемы vs iOS liquid glass

#### 1. Blur качество — КРИТИЧНО
```glsl
// Текущий код: 5-tap cross (слабый blur)
half4 sampleB(float2 uv, float radius) {
    half4 color = backdrop.eval(samUV) * 0.4;
    color += backdrop.eval(samUV + float2(off, 0.0)) * 0.15;
    // ... только 4 направления
}
```

**iOS использует:** Multi-pass Gaussian с 9-13 tap kernel или dual Kawase blur.

**Проблема:** 5 сэмплов дают "крестообразный" артефакт, не круговой blur. На iOS blur изотропный (одинаковый во все стороны).

**Решение:** Минимум 9-tap (3x3 grid) или 13-tap hexagonal pattern:
```glsl
// 9-tap box blur (быстрее чем Gaussian, но лучше чем cross)
for (float x = -1.0; x <= 1.0; x += 1.0) {
    for (float y = -1.0; y <= 1.0; y += 1.0) {
        color += backdrop.eval(uv + float2(x, y) * radius) / 9.0;
    }
}
```

Для 120fps нужен **dual-pass blur** (horizontal + vertical), но это требует FBO.

#### 2. Backdrop capture — КРИТИЧНО
```kotlin
// Текущий код: рисует только первого child ViewGroup
if (root is ViewGroup && root.childCount > 0) {
    val bgChild = root.getChildAt(0)
    bgChild.draw(canvas)
}
```

**Проблема:** Если background НЕ первый child или это не ImageView, захватится не то. React Native layout может быть непредсказуемым.

**iOS подход:** Использует `CALayer.renderInContext` который захватывает ВСЁ под view автоматически.

**Решение:** 
- Либо рисовать весь root, но с `clipChildren = false` и маской
- Либо искать view по типу `ReactImageView` рекурсивно
- Либо требовать от юзера передавать ref на background view

#### 3. Refraction масштаб
```glsl
float refrScale = min(refractionStrength * resolution.y * 0.15, margin * 0.9);
```

**Проблема:** `resolution.y * 0.15` может быть слишком большим на больших экранах. На iOS IOR работает через физическую модель (Snell's law), а не через произвольный множитель.

**Решение:** Привязать к `cornerRadius` или фиксированному пикселю:
```glsl
float refrScale = refractionStrength * cornerRadius * 2.0;
```

#### 4. Chromatic aberration offset
```glsl
float caParams = chromaticAberration * liquidFx * 20.0;
float2 caOff = (normal + lightDir * 0.5) * caParams;
```

**Проблема:** `* 20.0` — магическое число. На разных DPI будет выглядеть по-разному.

**Решение:** Нормализовать к resolution:
```glsl
float caParams = chromaticAberration * liquidFx * resolution.y * 0.01;
```

#### 5. Tilt integration
```kotlin
tiltX = (orientation[2] * 2.0).toFloat().coerceIn(-1.5f, 1.5f)
```

**Хорошо:** Используется rotation vector (лучше чем просто акселерометр).

**Проблема:** Обновление на каждом `onSensorChanged` вызывает `invalidate()` → 60+ FPS redraw даже когда не нужно.

**Решение:** Throttle updates (например, только если изменение > 0.05) или использовать `SENSOR_DELAY_GAME` вместо `SENSOR_DELAY_UI`.

#### 6. Performance — margin overhead
```kotlin
val targetW = (width + margin * 2).toInt() // +200px
val targetH = (height + margin * 2).toInt()
```

**Проблема:** Каждая карточка захватывает bitmap на 200px больше с каждой стороны. Для 20 карточек это огромный memory overhead.

**iOS подход:** Использует shared backdrop texture или tile-based rendering.

**Решение:** 
- Уменьшить margin до 20-40px (достаточно для refraction)
- Или использовать один shared backdrop для всех карточек (если они на одном фоне)

## Сравнение с iOS liquid glass

### Визуальное качество (субъективно)

| Параметр | iOS | Текущая реализация | Оценка |
|----------|-----|-------------------|--------|
| Blur smoothness | 10/10 | 5/10 | ❌ Cross pattern видно |
| Edge glow | 10/10 | 8/10 | ✅ Iridescence хорош |
| Refraction | 10/10 | 7/10 | ⚠️ Работает, но не физичный |
| Chromatic aberration | 10/10 | 6/10 | ⚠️ Слишком сильный на краях |
| Transparency | 10/10 | 9/10 | ✅ Центр прозрачен |
| Performance | 10/10 | 6/10 | ⚠️ Memory overhead |

### Performance

**Текущий FPS (оценка):**
- Mid-range (SD 695): ~45-50 FPS при скролле (из-за backdrop recapture)
- Flagship (SD 8 Gen 2): ~60-80 FPS

**Bottleneck:**
- Backdrop capture на каждом pre-draw (даже когда view не двигается)
- 5-tap blur слишком слаб, но 9-tap будет медленнее
- Margin 100px → большие bitmaps

**iOS достигает 120fps потому что:**
- Использует hardware-accelerated `CABackdropLayer`
- Blur делается через Metal compute shader (dual-pass)
- Backdrop кэшируется и обновляется только при изменении layout

## Рекомендации для достижения iOS-качества

### Критичные (must-fix)

1. **Blur kernel → 9-tap minimum**
   - Заменить cross на box или hexagonal
   - Или dual-pass (horizontal + vertical) через FBO

2. **Backdrop capture → smart invalidation**
   - Не вызывать `captureBackdrop()` на каждом pre-draw
   - Только при layout change или scroll stop

3. **Margin → reduce to 40px**
   - 100px избыточен для refraction 0.03-0.6

### Желательные (nice-to-have)

4. **Refraction → физическая модель**
   - Использовать IOR через Snell's law вместо произвольного scale

5. **Chromatic aberration → DPI-aware**
   - Нормализовать к resolution вместо `* 20.0`

6. **Tilt → throttle updates**
   - Обновлять только при значимом изменении

## Итоговая оценка

**Текущая реализация: 7/10**

✅ Работает, выглядит как "стекло"  
✅ Хорошая архитектура (Expo module, AGSL shader)  
✅ Iridescent glow — уникальная фича  
⚠️ Blur слабый (главная проблема)  
⚠️ Performance не достигает 120fps  
❌ Не идентичен iOS (но близко)

**Для production-ready нужно:**
- Улучшить blur (9-13 tap)
- Оптимизировать backdrop capture
- Уменьшить memory footprint

**Для "неотличимо от iOS" нужно:**
- Dual-pass Gaussian blur через FBO
- Hardware-accelerated backdrop (RenderEffect API 31+)
- Физическая модель refraction
