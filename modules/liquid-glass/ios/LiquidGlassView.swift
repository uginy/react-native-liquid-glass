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
    var ior:                 Float
    var magnification:       Float
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
    private static var sharedBgTexture: MTLTexture?
    private static var sharedBgTextureSize: CGSize = .zero
    private static var sharedBgSourceView: UIView?
    private static var sharedCapturing = false
    private static var activeInstances = 0
    private static let sharedStateLock = NSLock()
    private static let sharedPipelineLock = NSLock()
    private static var sharedMetalDevice: MTLDevice?
    private static var sharedMetalPipeline: MTLRenderPipelineState?
    private static let sharedFrameLock = NSLock()
    private static var sharedFrameSubscribers = NSHashTable<LiquidGlassView>.weakObjects()
    private static var sharedDisplayLink: CADisplayLink?

    // MARK: - Props
    var blurRadius:          Float = 20   { didSet { requestRender() } }
    var refractionStrength:  Float = 0.03 { didSet { requestRender() } }
    var chromaticAberration: Float = 0.05 { didSet { requestRender() } }
    var edgeGlowIntensity:   Float = 0.18 { didSet { requestRender() } }
    var magnification:       Float = 1.08 { didSet { requestRender() } }
    var glassOpacity:        Float = 0.05 { didSet { requestRender() } }
    var tintR:               Float = 1.0  { didSet { updateBorder(); requestRender() } }
    var tintG:               Float = 1.0  { didSet { updateBorder(); requestRender() } }
    var tintB:               Float = 1.0  { didSet { updateBorder(); requestRender() } }
    var fresnelPower:        Float = 3.0  { didSet { requestRender() } }
    var glassCornerRadius:   Float = 24   { didSet { updateCornerRadius() } }
    var shadowOpacityValue:  Float = 0    { didSet { updateShadow() } }
    var glareIntensity:      Float = 0.3  { didSet { requestRender() } }
    var lightAngle:          Float = 0.8  { didSet { requestRender() } }
    var borderIntensity:     Float = 0.28 { didSet { updateBorder(); requestRender() } }
    var edgeWidth:           Float = 2.0  { didSet { updateBorder(); requestRender() } }
    var liquidPower:         Float = 1.5  { didSet { requestRender() } }
    var saturation:          Float = 1.0  { didSet { requestRender() } }
    var brightnessValue:     Float = 1.0  { didSet { requestRender() } }
    var noiseIntensity:      Float = 0.0  { didSet { requestRender() } }
    var iridescence:         Float = 0.0  { didSet { requestRender() } }
    var ior:                 Float = 1.2  { didSet { requestRender() } }

    func setTintColor(hex: String) {
        let (r, g, b) = Self.parseHexColor(hex)
        tintR = r; tintG = g; tintB = b
        requestRender()
    }

    // MARK: - Metal
    private var device:        MTLDevice?
    private var commandQueue:  MTLCommandQueue?
    private var pipeline:      MTLRenderPipelineState?
    private var metalLayer:    CAMetalLayer?

    private weak var localBgSourceView: UIView?
    private var cachedOriginXInBg: CGFloat = 0
    private var quadBuffer:    MTLBuffer?
    
    // MARK: - Fallback
    private var fallbackBlur:  UIVisualEffectView?
    private var borderLayer:   CALayer!

    // MARK: - Loop
    private var needsCapture   = true
    private var needsPropRender = true
    private var lastOffsetYInBg: CGFloat = .greatestFiniteMagnitude
    private var isCountedAsActive = false
    private var nextCaptureRetryAt: CFTimeInterval = 0
    private var startupRecaptureRemaining = 0
    private var lastLayoutSize: CGSize = .zero

    // MARK: - Init
    public required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        backgroundColor = .clear
        clipsToBounds   = true
        
        setupMetal()
        setupViewHierarchy()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        LiquidGlassView.unregisterForFrames(self)
        metalLayer?.removeFromSuperlayer()
        metalLayer = nil
        commandQueue = nil
        pipeline = nil
        quadBuffer = nil
    }
    
    // MARK: - Setup
    private func setupMetal() {
        guard let (dev, pipeline) = LiquidGlassView.getSharedMetalPipeline(),
              let queue = dev.makeCommandQueue() else {
            return
        }

        device = dev
        commandQueue = queue
        self.pipeline = pipeline
        
        let layer = CAMetalLayer()
        layer.device = dev
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false
        layer.isOpaque = false
        layer.contentsScale = min(UIScreen.main.scale, 2.0)
        layer.zPosition = -100
        metalLayer = layer
        
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

    private static func getSharedMetalPipeline() -> (MTLDevice, MTLRenderPipelineState)? {
        sharedPipelineLock.lock()
        defer { sharedPipelineLock.unlock() }

        if let dev = sharedMetalDevice,
           let pipe = sharedMetalPipeline {
            return (dev, pipe)
        }

        guard let dev = MTLCreateSystemDefaultDevice(),
              let pipe = makeLiquidGlassPipeline(device: dev) else {
            return nil
        }

        sharedMetalDevice = dev
        sharedMetalPipeline = pipe
        return (dev, pipe)
    }

    private func setupViewHierarchy() {
        // Metal layer stays behind RN children.
        if let metal = metalLayer {
            layer.insertSublayer(metal, at: 0)
        } else {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            blur.frame = bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
            sendSubviewToBack(blur)
            fallbackBlur = blur
        }

        borderLayer = CALayer()
        borderLayer.zPosition = 10
        layer.addSublayer(borderLayer)
        
        updateShadow()
        updateBorder()
        updateCornerRadius()
    }

    // MARK: - Lifecycle
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            if !isCountedAsActive {
                LiquidGlassView.updateSharedState { $0.activeInstances += 1 }
                isCountedAsActive = true
            }
            startLoop()
            needsCapture = true
            needsPropRender = true
            localBgSourceView = nil
            lastOffsetYInBg = .greatestFiniteMagnitude
            nextCaptureRetryAt = 0
            startupRecaptureRemaining = 3
        } else {
            if isCountedAsActive {
                LiquidGlassView.updateSharedState {
                    $0.activeInstances = max(0, $0.activeInstances - 1)
                }
                isCountedAsActive = false
            }
            stopLoop()
            if LiquidGlassView.readSharedState({ $0.activeInstances }) == 0 {
                LiquidGlassView.updateSharedState {
                    $0.sharedBgTexture = nil
                    $0.sharedBgTextureSize = .zero
                    $0.sharedBgSourceView = nil
                    $0.sharedCapturing = false
                }
            }
        }
    }

    public override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview !== fallbackBlur {
            bringSubviewToFront(subview)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let s = min(UIScreen.main.scale, 2.0)
        metalLayer?.frame = bounds
        metalLayer?.drawableSize = CGSize(width: bounds.width * s, height: bounds.height * s)
        borderLayer.frame = bounds
        let sizeChanged = abs(bounds.width - lastLayoutSize.width) > 0.5 || abs(bounds.height - lastLayoutSize.height) > 0.5
        lastLayoutSize = bounds.size
        
        updateCornerRadius()
        needsPropRender = true
        lastOffsetYInBg = .greatestFiniteMagnitude
        if sizeChanged {
            needsCapture = true
            nextCaptureRetryAt = 0
            startupRecaptureRemaining = max(startupRecaptureRemaining, 1)
        }
    }

    // MARK: - Loop
    private static func registerForFrames(_ view: LiquidGlassView) {
        sharedFrameLock.lock()
        sharedFrameSubscribers.add(view)
        if sharedDisplayLink == nil {
            let link = CADisplayLink(target: LiquidGlassView.self, selector: #selector(onSharedFrame(_:)))
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            } else {
                link.preferredFramesPerSecond = 30
            }
            link.add(to: .main, forMode: .common)
            sharedDisplayLink = link
        }
        sharedFrameLock.unlock()
    }

    private static func unregisterForFrames(_ view: LiquidGlassView) {
        sharedFrameLock.lock()
        sharedFrameSubscribers.remove(view)
        if sharedFrameSubscribers.allObjects.isEmpty {
            sharedDisplayLink?.invalidate()
            sharedDisplayLink = nil
        }
        sharedFrameLock.unlock()
    }

    @objc private static func onSharedFrame(_ link: CADisplayLink) {
        sharedFrameLock.lock()
        let views = sharedFrameSubscribers.allObjects
        sharedFrameLock.unlock()
        for view in views { view.handleFrame() }
    }

    private func startLoop() {
        LiquidGlassView.registerForFrames(self)
    }

    private func stopLoop() {
        LiquidGlassView.unregisterForFrames(self)
    }

    private func handleFrame() {
        guard window != nil, !isHidden, alpha > 0, isVisibleInWindow() else { return }
        
        var shouldRender = false

        if needsCapture || startupRecaptureRemaining > 0 {
            let now = CACurrentMediaTime()
            if now >= nextCaptureRetryAt {
                let captured = captureBackground()
                if needsCapture {
                    needsCapture = !captured
                }
                if captured {
                    shouldRender = true
                    if startupRecaptureRemaining > 0 {
                        startupRecaptureRemaining -= 1
                    }
                    nextCaptureRetryAt = now + 0.50
                } else {
                    nextCaptureRetryAt = now + 0.16
                }
            }
        }

        if needsPropRender {
            needsPropRender = false
            shouldRender = true
        }

        let shared = LiquidGlassView.readSharedState { ($0.sharedBgTexture, $0.sharedBgTextureSize, $0.sharedBgSourceView) }
        if let source = localBgSourceView ?? shared.2 {
            localBgSourceView = source

            if shared.0 != nil {
                let bgSize = shared.1
                if abs(source.bounds.width - bgSize.width) > 1.0 || abs(source.bounds.height - bgSize.height) > 1.0 {
                    needsCapture = true
                }
            }

            let currentOrigin = convert(CGPoint.zero, to: source)
            let xDelta = abs(currentOrigin.x - cachedOriginXInBg)
            let yDelta = abs(currentOrigin.y - lastOffsetYInBg)
            cachedOriginXInBg = currentOrigin.x
            if xDelta > 0.1 || yDelta > 0.1 || lastOffsetYInBg.isInfinite {
                lastOffsetYInBg = currentOrigin.y
                shouldRender = true
            }
        } else if shared.0 != nil {
            needsCapture = true
        }

        if shouldRender {
            render()
        }
    }
    
    private func requestRender() {
        if LiquidGlassView.readSharedState({ $0.sharedBgTexture }) == nil {
            needsCapture = true
        }
        needsPropRender = true
    }

    // MARK: - Capture
    @discardableResult
    private func captureBackground() -> Bool {
        guard let device = device,
              let win = window,
              win.bounds.width > 1 else { return false }
        if LiquidGlassView.readSharedState({ $0.sharedCapturing }) { return false }

        var source = LiquidGlassView.readSharedState { $0.sharedBgSourceView }
        if source == nil
            || source?.window == nil
            || (source?.bounds.width ?? 0) < 1
            || (source?.bounds.height ?? 0) < 1
            || !isLikelyBackdropSource(source) {
            source = findBackdropSource(in: win)
            LiquidGlassView.updateSharedState { $0.sharedBgSourceView = source }
        }

        guard let sourceView = source else { return false }
        guard isBackdropSourceReady(sourceView) else { return false }

        LiquidGlassView.updateSharedState { $0.sharedCapturing = true }
        defer { LiquidGlassView.updateSharedState { $0.sharedCapturing = false } }

        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(sourceView.bounds.size, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return false
        }
        sourceView.layer.render(in: ctx)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImg = img?.cgImage else { return false }

        let loader = MTKTextureLoader(device: device)
        let texture = try? loader.newTexture(cgImage: cgImg, options: [.SRGB: false])
        guard let validTexture = texture else { return false }
        LiquidGlassView.updateSharedState {
            $0.sharedBgTexture = validTexture
            $0.sharedBgTextureSize = sourceView.bounds.size
            $0.sharedBgSourceView = sourceView
        }
        localBgSourceView = sourceView
        let origin = convert(CGPoint.zero, to: sourceView)
        cachedOriginXInBg = origin.x
        lastOffsetYInBg = origin.y
        return true
    }

    // MARK: - Render
    private func render() {
        let shared = LiquidGlassView.readSharedState { ($0.sharedBgTexture, $0.sharedBgTextureSize, $0.sharedBgSourceView) }
        guard let queue = commandQueue,
              let pipeline = pipeline,
              let metal = metalLayer,
              let drawable = metal.nextDrawable(),
              let tex = shared.0,
              let source = localBgSourceView ?? shared.2,
              let quad = quadBuffer else { return }

        let scale = Float(UIScreen.main.scale)
        let w = Float(bounds.width)
        let h = Float(bounds.height)
        
        let sourceOrigin = convert(CGPoint(x: 0, y: 0), to: source)
        let originX = Float(cachedOriginXInBg) * scale
        let originY = Float(sourceOrigin.y) * scale
        var u = LGUniforms(
            resolution: SIMD2(w, h),
            scale: SIMD2(scale, scale),
            bgTextureSize: SIMD2(Float(shared.1.width) * scale, Float(shared.1.height) * scale),
            viewOriginInBg: SIMD2(originX, originY),
            blurRadius: blurRadius,
            refractionStrength: refractionStrength,
            ior: ior,
            magnification: magnification,
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

    // MARK: - Helpers
    private func updateCornerRadius() {
        let r = CGFloat(glassCornerRadius)
        layer.cornerRadius = r
        metalLayer?.cornerRadius = r
        metalLayer?.masksToBounds = true
        borderLayer.cornerRadius = r
        fallbackBlur?.layer.cornerRadius = r
        fallbackBlur?.clipsToBounds = true
    }

    private func updateBorder() {
        if metalLayer != nil {
            borderLayer.borderWidth = 0
            borderLayer.borderColor = UIColor.clear.cgColor
            return
        }

        let tint = UIColor(
            red: CGFloat(tintR),
            green: CGFloat(tintG),
            blue: CGFloat(tintB),
            alpha: 1
        )
        borderLayer.borderWidth = CGFloat(edgeWidth) * 0.5
        borderLayer.borderColor = tint
            .withAlphaComponent(CGFloat(borderIntensity) * 1.25).cgColor
    }

    private func updateShadow() {
        layer.shadowOpacity = shadowOpacityValue
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.masksToBounds = false
    }

    private func isVisibleInWindow() -> Bool {
        guard let win = window else { return false }
        let frameInWindow = convert(bounds, to: win)
        return frameInWindow.intersects(win.bounds.insetBy(dx: 0, dy: -80))
    }

    private func findBackdropSource(in root: UIView) -> UIView? {
        var bestImageView: UIView?
        var bestScore: CGFloat = 0
        let rootArea = max(root.bounds.width * root.bounds.height, 1)

        func search(_ view: UIView) {
            if view === self || view is LiquidGlassView { return }
            if view.isHidden || view.alpha <= 0.01 || view.bounds.width <= 1 || view.bounds.height <= 1 { return }

            let score = backdropCandidateScore(view, rootArea: rootArea)
            if score > bestScore {
                bestScore = score
                bestImageView = view
            }

            for child in view.subviews {
                search(child)
            }
        }

        search(root)
        return bestImageView
    }

    private func backdropCandidateScore(_ view: UIView, rootArea: CGFloat) -> CGFloat {
        let className = String(describing: type(of: view)).lowercased()
        if className.contains("liquidglass") { return 0 }

        let isImageLike = view is UIImageView || className.contains("image")
        if !isImageLike { return 0 }

        let area = max(view.bounds.width * view.bounds.height, 1)
        let areaRatio = area / rootArea
        if areaRatio < 0.15 { return 0 }

        var score = areaRatio * 3.0
        if view is UIImageView { score += 2.4 }
        if className.contains("imagebackground") { score += 1.4 }
        if className.contains("image") { score += 1.1 }
        if view.layer.contents != nil { score += 0.8 }
        if isBackdropSourceReady(view) { score += 0.5 }
        return score
    }

    private func isLikelyBackdropSource(_ view: UIView?) -> Bool {
        guard let view else { return false }
        let className = String(describing: type(of: view)).lowercased()
        if className.contains("liquidglass") { return false }
        return view is UIImageView || className.contains("image")
    }

    private func isBackdropSourceReady(_ view: UIView, depth: Int = 0) -> Bool {
        if view.layer.contents != nil { return true }
        if let imageView = view as? UIImageView {
            return imageView.image != nil || imageView.layer.contents != nil
        }
        if depth >= 2 { return false }

        for child in view.subviews {
            if child.isHidden || child.alpha <= 0.01 { continue }
            if isBackdropSourceReady(child, depth: depth + 1) {
                return true
            }
        }
        return false
    }

    private struct SharedState {
        var sharedBgTexture: MTLTexture?
        var sharedBgTextureSize: CGSize
        var sharedBgSourceView: UIView?
        var sharedCapturing: Bool
        var activeInstances: Int
    }

    private static func readSharedState<T>(_ block: (SharedState) -> T) -> T {
        sharedStateLock.lock()
        defer { sharedStateLock.unlock() }
        let snapshot = SharedState(
            sharedBgTexture: sharedBgTexture,
            sharedBgTextureSize: sharedBgTextureSize,
            sharedBgSourceView: sharedBgSourceView,
            sharedCapturing: sharedCapturing,
            activeInstances: activeInstances
        )
        return block(snapshot)
    }

    private static func updateSharedState(_ block: (inout SharedState) -> Void) {
        sharedStateLock.lock()
        defer { sharedStateLock.unlock() }
        var state = SharedState(
            sharedBgTexture: sharedBgTexture,
            sharedBgTextureSize: sharedBgTextureSize,
            sharedBgSourceView: sharedBgSourceView,
            sharedCapturing: sharedCapturing,
            activeInstances: activeInstances
        )
        block(&state)
        sharedBgTexture = state.sharedBgTexture
        sharedBgTextureSize = state.sharedBgTextureSize
        sharedBgSourceView = state.sharedBgSourceView
        sharedCapturing = state.sharedCapturing
        activeInstances = state.activeInstances
    }

    static func parseHexColor(_ color: String) -> (Float, Float, Float) {
        let input = color.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if input.hasPrefix("rgb("), input.hasSuffix(")") {
            let body = input.dropFirst(4).dropLast()
            let components = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 3,
               let r = Float(components[0]),
               let g = Float(components[1]),
               let b = Float(components[2]) {
                return (r / 255.0, g / 255.0, b / 255.0)
            }
        }

        var s = input
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        if s.count == 3 {
            let chars = Array(s)
            s = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
        }

        let scanner = Scanner(string: s)
        var hexNumber: UInt64 = 0
        if scanner.scanHexInt64(&hexNumber), s.count == 6 {
            let r = Float((hexNumber & 0xff0000) >> 16) / 255
            let g = Float((hexNumber & 0x00ff00) >> 8) / 255
            let b = Float(hexNumber & 0x0000ff) / 255
            return (r, g, b)
        }
        return (1, 1, 1)
    }
}
