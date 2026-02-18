package com.liquidglass

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.ImageView
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.views.ExpoView
import kotlin.math.abs
import kotlin.math.roundToInt

class LiquidGlassView(context: Context, appContext: AppContext) : ExpoView(context, appContext) {

    var blurRadius: Float = 20f
        set(value) { field = value; invalidate() }
    var refractionStrength: Float = 0.03f
        set(value) { field = value; invalidate() }
    var ior: Float = 1.5f
        set(value) { field = value; invalidate() }
    var chromaticAberration: Float = 0.05f
        set(value) { field = value; invalidate() }
    var edgeGlowIntensity: Float = 0.0f
        set(value) { field = value; invalidate() }
    var magnification: Float = 1.1f
        set(value) { field = value; invalidate() }
    var glassOpacity: Float = 0.12f
        set(value) { field = value; invalidate() }
    var tintR: Float = 1.0f
        set(value) { field = value; invalidate() }
    var tintG: Float = 1.0f
        set(value) { field = value; invalidate() }
    var tintB: Float = 1.0f
        set(value) { field = value; invalidate() }

    var tintColor: String = "#ffffff"
        set(value) {
            field = value
            val (r, g, b) = parseHexColor(value)
            tintR = r; tintG = g; tintB = b
        }
    var fresnelPower: Float = 4.0f
        set(value) { field = value; invalidate() }
    var cornerRadius: Float = 32f
        set(value) { field = value; invalidate() }
    var glareIntensity: Float = 0.3f
        set(value) { field = value; invalidate() }
    var borderIntensity: Float = 0.15f
        set(value) { field = value; invalidate() }
    var edgeWidth: Float = 2.0f
        set(value) { field = value; invalidate() }
    var liquidPower: Float = 1.5f
        set(value) { field = value; invalidate() }
    var lightAngle: Float = 0.8f
        set(value) { field = value; invalidate() }
    var saturation: Float = 1.0f
        set(value) { field = value; invalidate() }
    var brightness: Float = 1.0f
        set(value) { field = value; invalidate() }
    var noiseIntensity: Float = 0.02f
        set(value) { field = value; invalidate() }
    var iridescence: Float = 0.0f
        set(value) { field = value; invalidate() }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var runtimeShader: RuntimeShader? = null
    private var localBitmapShader: BitmapShader? = null

    private var offsetX = 0f
    private var offsetY = 0f

    private var startupRetryCount = 0
    private var retryCapturePosted = false

    private val retryCaptureRunnable = Runnable {
        retryCapturePosted = false
        val bmp = sharedBgBitmap
        if (bmp != null && !bmp.isRecycled && localBitmapShader == null && isAttachedToWindow) {
            buildLocalShader(bmp)
            post { syncOffset() }
        } else if (bmp == null && width > 0 && height > 0 && isAttachedToWindow) {
            requestSharedCapture()
        }
    }

    private val preDrawListener = ViewTreeObserver.OnPreDrawListener {
        updateOffset()
        true
    }

    companion object {
        private var sharedBgBitmap: Bitmap? = null
        private var sharedBgView: View? = null
        private var sharedBgW = 0f
        private var sharedBgH = 0f
        private var isSharedCapturing = false

        private const val MAX_STARTUP_RETRIES = 40
        private const val MIN_VALID_ALPHA = 10
        private var activeInstances = 0

        private const val SHADER_SRC = """
            uniform shader backdrop;
            uniform float2 resolution;
            uniform float2 viewOffset;
            uniform float2 bgSize;
            uniform float blurRadius;
            uniform float refractionStrength;
            uniform float chromaticAberration;
            uniform float edgeGlow;
            uniform float glassOpacity;
            uniform float3 tintColor;
            uniform float fresnelPower;
            uniform float cornerRadius;
            uniform float glareIntensity;
            uniform float borderIntensity;
            uniform float edgeWidth;
            uniform float liquidPower;
            uniform float lightAngle;
            uniform float saturation;
            uniform float brightness;
            uniform float noiseIntensity;
            uniform float iridescence;

            float roundedBoxSDF(float2 p, float2 b, float r) {
                float2 q = abs(p) - b + float2(r);
                return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - r;
            }

            half4 sampleBg(float2 uv) {
                return backdrop.eval(clamp(uv + viewOffset, float2(0.0), bgSize));
            }

            half4 sampleBlurred(float2 uv, float radius) {
                if (radius < 0.5) return sampleBg(uv);
                float s = radius * 0.4;
                half4 c = sampleBg(uv) * half(0.36);
                c += sampleBg(uv + float2(-s,-s)) * half(0.08);
                c += sampleBg(uv + float2( s,-s)) * half(0.08);
                c += sampleBg(uv + float2(-s, s)) * half(0.08);
                c += sampleBg(uv + float2( s, s)) * half(0.08);
                c += sampleBg(uv + float2(-s, 0)) * half(0.08);
                c += sampleBg(uv + float2( s, 0)) * half(0.08);
                c += sampleBg(uv + float2( 0,-s)) * half(0.08);
                c += sampleBg(uv + float2( 0, s)) * half(0.08);
                return c;
            }

            float hash21(float2 p) {
                return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            half3 applySaturation(half3 color, float sat) {
                half luma = dot(color, half3(half(0.2126), half(0.7152), half(0.0722)));
                return mix(half3(luma), color, half(sat));
            }

            half4 main(float2 fragCoord) {
                float2 uv = fragCoord;
                float2 center = resolution * 0.5;
                float sdf = roundedBoxSDF(uv - center, resolution * 0.5, cornerRadius);
                float mask = 1.0 - smoothstep(-1.0, 1.5, sdf);
                if (mask < 0.01) return half4(0.0);

                float edgeAmt = 1.0 - smoothstep(0.0, cornerRadius * edgeWidth, -sdf);
                float liquidFx = pow(max(edgeAmt, 0.0), liquidPower);

                float eps = 1.0;
                float2 sdfGrad = float2(
                    roundedBoxSDF(uv + float2(eps,0) - center, resolution*0.5, cornerRadius) -
                    roundedBoxSDF(uv - float2(eps,0) - center, resolution*0.5, cornerRadius),
                    roundedBoxSDF(uv + float2(0,eps) - center, resolution*0.5, cornerRadius) -
                    roundedBoxSDF(uv - float2(0,eps) - center, resolution*0.5, cornerRadius)
                );
                float sdfLen = length(sdfGrad);
                float2 normal = sdfLen > 0.001 ? sdfGrad / sdfLen
                    : normalize((uv - center) / resolution + float2(0.0001));

                float refr = refractionStrength * liquidFx * resolution.y * 0.25;
                float2 uvRefracted = uv + normal * refr;

                float blurAmt = blurRadius * liquidFx;
                float blurCenter = blurRadius * (1.0 - edgeAmt * 0.6);

                half4 centerBlur = sampleBlurred(uv, blurCenter);
                half4 edgeBlur = sampleBlurred(uvRefracted, blurAmt);
                half4 res = mix(centerBlur, edgeBlur, half(liquidFx));

                // Chromatic aberration — skip entirely when disabled
                if (chromaticAberration > 0.001) {
                    float caOffset = chromaticAberration * 18.0;
                    float tinyBlur = min(blurRadius * 0.1, 2.5);
                    half rSample = sampleBlurred(uvRefracted + normal * caOffset, tinyBlur).r;
                    half bSample = sampleBlurred(uvRefracted - normal * caOffset, tinyBlur).b;
                    float caMix = clamp(chromaticAberration * 1.2, 0.0, 0.9);
                    res.r = mix(res.r, rSample, half(caMix));
                    res.b = mix(res.b, bSample, half(caMix));
                }

                // Saturation and brightness
                res.rgb = applySaturation(res.rgb, saturation);
                res.rgb *= half(brightness);

                // Tint
                res.rgb = mix(res.rgb, half3(tintColor), half(glassOpacity));

                // Light-angle-based glare
                float2 lightDir = normalize(float2(cos(lightAngle), -sin(lightAngle)));
                float glareAmt = pow(max(dot(normal, lightDir), 0.0), 15.0) * liquidFx * glareIntensity;
                res.rgb += half3(1.0) * half(glareAmt);

                // Fresnel edge glow
                res.rgb += half3(1.0) * half(pow(edgeAmt, fresnelPower) * edgeGlow);

                // Border highlight
                res.rgb += half3(1.0) * half(smoothstep(2.0, 0.5, abs(sdf)) * borderIntensity);

                // Iridescence — spatial rainbow around edges using angle
                float2 toCenter = uv - center;
                float iridAngle = atan(toCenter.y, toCenter.x);
                float iridPhase = iridAngle * 2.5;
                half3 irid = half3(
                    half(0.5 + 0.5 * cos(iridPhase)),
                    half(0.5 + 0.5 * cos(iridPhase + 2.094)),
                    half(0.5 + 0.5 * cos(iridPhase + 4.189))
                );
                float iridWide = 0.25 + liquidFx * 0.75;
                float iridMask = iridWide * iridescence;
                res.rgb = mix(res.rgb, irid, half(clamp(iridMask, 0.0, 1.0)));

                // Film grain / frosted noise
                float grain = (hash21(fragCoord) - 0.5) * noiseIntensity;
                res.rgb += half3(half(grain));

                res.a = 1.0;
                return res * half(mask);
            }
        """

        fun parseHexColor(color: String): Triple<Float, Float, Float> {
            val s = color.trim()
            if (s.startsWith("#")) {
                val h = s.substring(1)
                if (h.length == 3) {
                    val r = h[0].digitToInt(16) * 17 / 255f
                    val g = h[1].digitToInt(16) * 17 / 255f
                    val b = h[2].digitToInt(16) * 17 / 255f
                    return Triple(r, g, b)
                }
                if (h.length == 6) {
                    val r = h.substring(0, 2).toInt(16) / 255f
                    val g = h.substring(2, 4).toInt(16) / 255f
                    val b = h.substring(4, 6).toInt(16) / 255f
                    return Triple(r, g, b)
                }
            }
            val m = Regex("""rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)""").find(s)
            if (m != null) {
                val (r, g, b) = m.destructured
                return Triple(r.toInt() / 255f, g.toInt() / 255f, b.toInt() / 255f)
            }
            return Triple(1f, 1f, 1f)
        }

        fun findBackgroundInTree(root: View, exclude: View): View? {
            var bestImageArea = 0L
            var bestImageView: ImageView? = null
            var bestBgArea = 0L
            var bestBgView: View? = null
            fun search(v: View) {
                if (!v.isShown || v.width <= 0 || v.height <= 0 || v === exclude) return
                val area = v.width.toLong() * v.height.toLong()
                if (v is ImageView && v.drawable != null) {
                    if (area > bestImageArea) { bestImageArea = area; bestImageView = v }
                } else if (v.background != null && area > bestBgArea) {
                    bestBgArea = area; bestBgView = v
                }
                if (v is ViewGroup) for (i in 0 until v.childCount) search(v.getChildAt(i))
            }
            search(root)
            return bestImageView ?: bestBgView
        }

        fun isBitmapValid(bitmap: Bitmap): Boolean {
            val w = bitmap.width; val h = bitmap.height
            if (w <= 0 || h <= 0) return false
            val xs = intArrayOf((w*0.2f).roundToInt(), (w*0.5f).roundToInt(), (w*0.8f).roundToInt())
            val ys = intArrayOf((h*0.2f).roundToInt(), (h*0.5f).roundToInt(), (h*0.8f).roundToInt())
            var opaque = 0
            for (x in xs) for (y in ys) {
                if (Color.alpha(bitmap.getPixel(x.coerceIn(0,w-1), y.coerceIn(0,h-1))) >= MIN_VALID_ALPHA) opaque++
            }
            return opaque >= 6
        }
    }

    init {
        setWillNotDraw(false)
        setBackgroundColor(Color.TRANSPARENT)
        setLayerType(LAYER_TYPE_HARDWARE, null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            runtimeShader = RuntimeShader(SHADER_SRC)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        activeInstances++
        viewTreeObserver.addOnPreDrawListener(preDrawListener)
        val bmp = sharedBgBitmap
        if (bmp != null && !bmp.isRecycled && sharedBgW > 0f) {
            buildLocalShader(bmp)
            post { syncOffset() }
        } else {
            startupRetryCount = 0
            retryCapturePosted = false
            post { requestSharedCapture() }
        }
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        if (changed && width > 0 && height > 0) {
            val bmp = sharedBgBitmap
            if (bmp == null || bmp.isRecycled) post { requestSharedCapture() }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        viewTreeObserver.removeOnPreDrawListener(preDrawListener)
        removeCallbacks(retryCaptureRunnable)
        retryCapturePosted = false
        localBitmapShader = null
        runtimeShader = null
        activeInstances = maxOf(0, activeInstances - 1)
        if (activeInstances == 0) {
            sharedBgBitmap?.recycle()
            sharedBgBitmap = null
            sharedBgView = null
            sharedBgW = 0f
            sharedBgH = 0f
        }
    }

    private fun buildLocalShader(bmp: Bitmap) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val bs = BitmapShader(bmp, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        localBitmapShader = bs
        val s = runtimeShader ?: RuntimeShader(SHADER_SRC).also { runtimeShader = it }
        s.setInputShader("backdrop", bs)
        paint.shader = s
        invalidate()
    }

    private fun syncOffset() {
        val bgView = sharedBgView ?: return
        val bgLoc = IntArray(2); val viewLoc = IntArray(2)
        bgView.getLocationOnScreen(bgLoc); getLocationOnScreen(viewLoc)
        offsetX = (viewLoc[0] - bgLoc[0]).toFloat()
        offsetY = (viewLoc[1] - bgLoc[1]).toFloat()
        invalidate()
    }

    private fun updateOffset() {
        if (width <= 0 || height <= 0) return
        val bgView = sharedBgView ?: return
        val bmp = sharedBgBitmap
        if (bmp == null || bmp.isRecycled) {
            if (!isSharedCapturing) requestSharedCapture()
            return
        }
        val bgLoc = IntArray(2); val viewLoc = IntArray(2)
        bgView.getLocationOnScreen(bgLoc); getLocationOnScreen(viewLoc)
        val newX = (viewLoc[0] - bgLoc[0]).toFloat()
        val newY = (viewLoc[1] - bgLoc[1]).toFloat()
        if (localBitmapShader == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            offsetX = newX; offsetY = newY
            buildLocalShader(bmp)
            return
        }
        val densityDelta = 0.5f * resources.displayMetrics.density
        if (abs(newX - offsetX) >= densityDelta || abs(newY - offsetY) >= densityDelta) {
            offsetX = newX; offsetY = newY
            invalidate()
        }
    }

    private fun scheduleRetry() {
        if (retryCapturePosted || startupRetryCount >= MAX_STARTUP_RETRIES) return
        retryCapturePosted = true
        startupRetryCount += 1
        postDelayed(retryCaptureRunnable, if (startupRetryCount < 12) 16L else 33L)
    }

    private fun requestSharedCapture() {
        if (isSharedCapturing || width <= 0 || height <= 0) return
        val bgView = findBackgroundInTree(rootView, this)
        if (bgView == null || bgView.width <= 0 || bgView.height <= 0) { scheduleRetry(); return }

        isSharedCapturing = true
        try {
            val bmp = Bitmap.createBitmap(bgView.width, bgView.height, Bitmap.Config.ARGB_8888)
            Canvas(bmp).also { c -> bgView.draw(c) }

            if (!isBitmapValid(bmp)) { bmp.recycle(); scheduleRetry(); return }

            sharedBgBitmap?.recycle()
            sharedBgBitmap = bmp
            sharedBgView = bgView
            sharedBgW = bgView.width.toFloat()
            sharedBgH = bgView.height.toFloat()

            buildLocalShader(bmp)

            val bgLoc = IntArray(2); val viewLoc = IntArray(2)
            bgView.getLocationOnScreen(bgLoc); getLocationOnScreen(viewLoc)
            offsetX = (viewLoc[0] - bgLoc[0]).toFloat()
            offsetY = (viewLoc[1] - bgLoc[1]).toFloat()

            startupRetryCount = 0
            retryCapturePosted = false
            invalidate()
        } catch (_: Exception) {
            scheduleRetry()
        } finally {
            isSharedCapturing = false
        }
    }

    override fun onDraw(canvas: Canvas) {
        val bmp = sharedBgBitmap
        if (bmp == null || bmp.isRecycled || sharedBgW <= 0f) {
            if (!isSharedCapturing && width > 0 && height > 0) post { requestSharedCapture() }
            super.onDraw(canvas)
            return
        }
        if (canvas.isHardwareAccelerated && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val bs = localBitmapShader
            if (bs == null) {
                buildLocalShader(bmp)
                super.onDraw(canvas)
                return
            }
            try {
                val s = runtimeShader ?: RuntimeShader(SHADER_SRC).also { runtimeShader = it }
                s.setInputShader("backdrop", bs)
                s.setFloatUniform("resolution", width.toFloat(), height.toFloat())
                s.setFloatUniform("viewOffset", offsetX, offsetY)
                s.setFloatUniform("bgSize", sharedBgW, sharedBgH)
                s.setFloatUniform("blurRadius", blurRadius)
                s.setFloatUniform("refractionStrength", refractionStrength)
                s.setFloatUniform("chromaticAberration", chromaticAberration)
                s.setFloatUniform("edgeGlow", edgeGlowIntensity)
                s.setFloatUniform("glassOpacity", glassOpacity)
                s.setFloatUniform("tintColor", tintR, tintG, tintB)
                s.setFloatUniform("fresnelPower", fresnelPower)
                s.setFloatUniform("cornerRadius", cornerRadius)
                s.setFloatUniform("glareIntensity", glareIntensity)
                s.setFloatUniform("borderIntensity", borderIntensity)
                s.setFloatUniform("edgeWidth", edgeWidth)
                s.setFloatUniform("liquidPower", liquidPower)
                s.setFloatUniform("lightAngle", lightAngle)
                s.setFloatUniform("saturation", saturation)
                s.setFloatUniform("brightness", brightness)
                s.setFloatUniform("noiseIntensity", noiseIntensity)
                s.setFloatUniform("iridescence", iridescence)
                paint.shader = s
                canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
            } catch (_: Exception) {}
        }
        super.onDraw(canvas)
    }
}
