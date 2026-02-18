import ExpoModulesCore
import UIKit
import Metal
import MetalKit

// MARK: - Uniforms struct

private struct LGUniforms {
    var resolution:      SIMD2<Float>
    var scale:           SIMD2<Float>
    var bgTextureSize:   SIMD2<Float>
    var viewOriginInBg:  SIMD2<Float>

    var blurRadius:          Float
    var refractionStrength:  Float
    var chromaticAberration: Float
    var edgeGlowIntensity:   Float
    var glassOpacity:        Float
    var fresnelPower:        Float
    var cornerRadius:        Float
    var glareIntensity:      Float
    var borderIntensity:     Float
    var edgeWidth:           Float
    var liquidPower:         Float
    var lightAngle:          Float
    var saturation:          Float
    var brightness:          Float
    var noiseIntensity:      Float
    var iridescence:         Float

    var tintR: Float
    var tintG: Float
    var tintB: Float
}

// MARK: - LiquidGlassView

public class LiquidGlassView: ExpoView {

    // ── Props ──────────────────────────────────────────────────────────────
    // Используем didSet { setNeedsDisplay() } для перерисовки
    var blurRadius:          Float = 20   { didSet { requestRender() } }
    var refractionStrength:  Float = 0.03 { didSet { requestRender() } }
    var chromaticAberration: Float = 0.05 { didSet { requestRender() } }
    var edgeGlowIntensity:   Float = 0.18 { didSet { requestRender() } }
    var magnification:       Float = 1.08
    var glassOpacity:        Float = 0.05 { didSet { requestRender() } }
    var tintR:               Float = 1.0  { didSet { requestRender() } }
    var tintG:               Float = 1.0  { didSet { requestRender() } }
    var tintB:               Float = 1.0  { didSet { requestRender() } }
    var fresnelPower:        Float = 3.0  { didSet { requestRender() } }
    var glassCornerRadius:   Float = 24   { didSet { updateCornerRadius() } }
    var shadowOpacityValue:  Float = 0    { didSet { updateShadow() } }
    var glareIntensity:      Float = 0.3  { didSet { requestRender() } }
    var lightAngle:          Float = 0.8  { didSet { requestRender() } }
    var borderIntensity:     Float = 0.28 { didSet { requestRender() } }
    var edgeWidth:           Float = 2.0  { didSet { requestRender() } }
    var liquidPower:         Float = 1.5  { didSet { requestRender() } }
    var saturation:          Float = 1.0  { didSet { requestRender() } }
    var brightnessValue:     Float = 1.0  { didSet { requestRender() } }
    var noiseIntensity:      Float = 0.0  { didSet { requestRender() } }
    var iridescence:         Float = 0.0  { didSet { requestRender() } }
    var ior:                 Float = 1.2

    func setTintColor(hex: String) {
        let (r, g, b) = Self.parseHexColor(hex)
        tintR = r; tintG = g; tintB = b
        requestRender()
    }

    // ── Metal ──────────────────────────────────────────────────────────────
    private var device:        MTLDevice?
    private var commandQueue:  MTLCommandQueue?
    private var pipeline:      MTLRenderPipelineState?
    private var metalLayer:    CAMetalLayer?

    private var bgTexture:     MTLTexture?
    private var bgTextureSize: CGSize = .zero
    private var quadBuffer:    MTLBuffer?
    
    // ── Fallback ───────────────────────────────────────────────────────────
    private var fallbackBlur:  UIVisualEffectView?
    private var borderLayer:   CALayer!

    // ── Loop Control ──────────────────────────────────────────────────────
    private var displayLink:   CADisplayLink?
    private var needsCapture   = true
    private var lastPosition:  CGPoint = .zero

    // ── Init ───────────────────────────────────────────────────────────────
    public required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        backgroundColor = .clear // Важно для прозрачности
        clipsToBounds   = true
        
        setupMetal()
        setupViewHierarchy()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        displayLink?.invalidate()
    }
    
    // ── Setup ──────────────────────────────────────────────────────────────
    private func setupMetal() {
        guard let dev = MTLCreateSystemDefaultDevice() else { return }
        device = dev
        commandQueue = dev.makeCommandQueue()
        pipeline = makeLiquidGlassPipeline(device: dev)
        
        // Создаем Metal слой, но пока не добавляем (сделаем это в setupViewHierarchy)
        let layer = CAMetalLayer()
        layer.device = dev
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false
        layer.isOpaque = false
        layer.contentsScale = UIScreen.main.scale
        metalLayer = layer
        
        // Quad geometry
        let verts: [Float] = [
            -1,  1,  0, 0,
             1,  1,  1, 0,
            -1, -1,  0, 1,
             1,  1,  1, 0,
             1, -1,  1, 1,
            -1, -1,  0, 1,
        ]
        quadBuffer = dev.makeBuffer(bytes: verts, length: verts.count * 4, options: .storageModeShared)
    }

    private func setupViewHierarchy() {
        // 1. Metal Layer (Background)
        // Добавляем самым первым, чтобы контент (текст RN) ложился ПОВЕРХ
        if let metal = metalLayer {
            layer.insertSublayer(metal, at: 0)
        } else {
            // Fallback если Metal недоступен
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            blur.frame = bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
            sendSubviewToBack(blur)
            fallbackBlur = blur
        }

        // 2. Border (Overlay)
        borderLayer = CALayer()
        layer.addSublayer(borderLayer)
        
        updateShadow()
        updateBorder()
        updateCornerRadius()
    }

    // ── Lifecycle ──────────────────────────────────────────────────────────
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startLoop()
            needsCapture = true // Захватить фон при появлении
        } else {
            stopLoop()
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let s = UIScreen.main.scale
        metalLayer?.frame = bounds
        metalLayer?.drawableSize = CGSize(width: bounds.width * s, height: bounds.height * s)
        borderLayer.frame = bounds
        
        updateCornerRadius()
        needsCapture = true // Ресайз требует перезахвата фона
    }

    // ── Loop ───────────────────────────────────────────────────────────────
    private func startLoop() {
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(onFrame))
            displayLink?.add(to: .main, forMode: .common)
        }
    }
    
    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onFrame() {
        guard window != nil, !isHidden, alpha > 0 else { return }

        // Проверяем, изменилась ли позиция на экране (скролл)
        let currentPos = convert(CGPoint.zero, to: nil)
        let scrollDiff = abs(currentPos.x - lastPosition.x) + abs(currentPos.y - lastPosition.y)
        
        var shouldRender = false
        
        if scrollDiff > 0.1 {
            lastPosition = currentPos
            shouldRender = true
        }

        if needsCapture {
            captureBackground()
            needsCapture = false
            shouldRender = true
        }
        
        if shouldRender {
            render()
        }
    }
    
    private func requestRender() {
        // Просто помечаем, что если мы в цикле, то надо бы обновиться. 
        // В текущей реализации рендеримся сразу или ждем следующего тика.
        // Для простоты — просто вызываем render(), но лучше через флаг.
        render()
    }

    // ── Capture ────────────────────────────────────────────────────────────
    private func captureBackground() {
        guard let device = device,
              let win = window,
              win.bounds.width > 1 else { return }

        let scale = UIScreen.main.scale
        
        // Оптимизация: захватываем Window. 
        // Важно: скрываем себя перед захватом, чтобы не видеть "самого себя" в отражении (рекурсия)
        let wasHidden = isHidden
        isHidden = true
        
        UIGraphicsBeginImageContextWithOptions(win.bounds.size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            isHidden = wasHidden
            return
        }
        win.layer.render(in: ctx)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        isHidden = wasHidden
        
        guard let cgImg = img?.cgImage else { return }
        
        let loader = MTKTextureLoader(device: device)
        // SRGB: false важно для корректного смешивания цветов
        bgTexture = try? loader.newTexture(cgImage: cgImg, options: [.SRGB: false])
        bgTextureSize = win.bounds.size
    }

    // ── Render ─────────────────────────────────────────────────────────────
    private func render() {
        guard let device = device,
              let queue = commandQueue,
              let pipeline = pipeline,
              let metal = metalLayer,
              let drawable = metal.nextDrawable(),
              let tex = bgTexture,
              let quad = quadBuffer else { return }

        let scale = Float(UIScreen.main.scale)
        let w = Float(bounds.width)
        let h = Float(bounds.height)
        
        // Вычисляем смещение этого вью относительно захваченного фона (окна)
        // convert(CGPoint.zero, to: nil) возвращает координаты в Window
        let winPos = convert(CGPoint.zero, to: nil)
        
        var u = LGUniforms(
            resolution: SIMD2(w, h),
            scale: SIMD2(scale, scale),
            bgTextureSize: SIMD2(Float(bgTextureSize.width) * scale, Float(bgTextureSize.height) * scale),
            viewOriginInBg: SIMD2(Float(winPos.x) * scale, Float(winPos.y) * scale),
            blurRadius: blurRadius,
            refractionStrength: refractionStrength,
            chromaticAberration: chromaticAberration,
            edgeGlowIntensity: edgeGlowIntensity,
            glassOpacity: glassOpacity,
            fresnelPower: fresnelPower,
            cornerRadius: glassCornerRadius,
            glareIntensity: glareIntensity,
            borderIntensity: borderIntensity,
            edgeWidth: edgeWidth,
            liquidPower: liquidPower,
            lightAngle: lightAngle,
            saturation: saturation,
            brightness: brightnessValue,
            noiseIntensity: noiseIntensity,
            iridescence: iridescence,
            tintR: tintR, tintG: tintG, tintB: tintB
        )

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = drawable.texture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let buffer = queue.makeCommandBuffer(),
              let enc = buffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }

        enc.setRenderPipelineState(pipeline)
        enc.setVertexBuffer(quad, offset: 0, index: 0)
        enc.setFragmentBytes(&u, length: MemoryLayout<LGUniforms>.size, index: 0)
        enc.setFragmentTexture(tex, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    private func updateCornerRadius() {
        let r = CGFloat(glassCornerRadius)
        layer.cornerRadius = r
        metalLayer?.cornerRadius = r
        // Важно: без masksToBounds слой вылезет за скругления
        metalLayer?.masksToBounds = true
        borderLayer.cornerRadius = r
        fallbackBlur?.layer.cornerRadius = r
        fallbackBlur?.clipsToBounds = true
    }

    private func updateBorder() {
        borderLayer.borderWidth = CGFloat(edgeWidth) * 0.5
        borderLayer.borderColor = UIColor.white
            .withAlphaComponent(CGFloat(borderIntensity) * 1.5).cgColor
    }

    private func updateShadow() {
        // Тень отбрасывает само вью
        layer.shadowOpacity = shadowOpacityValue
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.masksToBounds = false // Тень должна быть снаружи
    }

    static func parseHexColor(_ color: String) -> (Float, Float, Float) {
        var s = color.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        let scanner = Scanner(string: s)
        var hexNumber: UInt64 = 0
        if scanner.scanHexInt64(&hexNumber) {
            if s.count == 6 {
                let r = Float((hexNumber & 0xff0000) >> 16) / 255
                let g = Float((hexNumber & 0x00ff00) >> 8) / 255
                let b = Float(hexNumber & 0x0000ff) / 255
                return (r, g, b)
            }
        }
        return (1, 1, 1)
    }
}
