import ExpoModulesCore
import UIKit

public final class LiquidGlassView: ExpoView {
  // MARK: - Props (Android parity)
  var blurRadius: Float = 20 { didSet { updateBlur() } }
  var refractionStrength: Float = 0.03 { didSet { updateOptics() } }
  var ior: Float = 1.2 { didSet { updateOptics() } }
  var chromaticAberration: Float = 0.05 { didSet { updateChroma() } }
  var edgeGlowIntensity: Float = 0.18 { didSet { updateGlare(); updateBorderAndGlow() } }
  var magnification: Float = 1.08 { didSet { updateOptics() } }
  var glassOpacity: Float = 0.05 { didSet { updateTint() } }
  var fresnelPower: Float = 3.0 { didSet { updateGlare(); updateBorderAndGlow() } }
  var glassCornerRadius: Float = 24 { didSet { updateCornerRadius() } }
  var shadowOpacityValue: Float = 0 { didSet { updateShadow() } }
  var glareIntensity: Float = 0.3 { didSet { updateGlare() } }
  var lightAngle: Float = 0.8 { didSet { updateOptics(); updateChroma(); updateGlare() } }
  var borderIntensity: Float = 0.28 { didSet { updateBorderAndGlow() } }
  var edgeWidth: Float = 2.0 { didSet { updateBorderAndGlow() } }
  var liquidPower: Float = 1.5 { didSet { updateOptics() } }
  var saturation: Float = 1.0 { didSet { updateColorAdjustments() } }
  var brightnessValue: Float = 1.0 { didSet { updateColorAdjustments() } }
  var noiseIntensity: Float = 0.0 { didSet { updateNoise() } }
  var iridescence: Float = 0.0 { didSet { updateGlare() } }

  private var tintR: Float = 1.0 { didSet { updateTint() } }
  private var tintG: Float = 1.0 { didSet { updateTint() } }
  private var tintB: Float = 1.0 { didSet { updateTint() } }

  // MARK: - Views
  private let blurView = UIVisualEffectView(effect: nil)
  private let tintView = UIView()
  private let desaturateView = UIView()
  private let vibranceView = UIView()
  private let brightnessView = UIView()
  private let chromaView = UIView()
  private let glareView = UIView()
  private let noiseView = UIImageView(image: LiquidGlassView.noiseTexture)

  // MARK: - Layers
  private let chromaLayer = CAGradientLayer()
  private let glareLayer = CAGradientLayer()
  private let iridescenceLayer = CAGradientLayer()
  private let edgeGlowLayer = CAShapeLayer()
  private let borderLayer = CAShapeLayer()

  private static let noiseTexture = LiquidGlassView.makeNoiseTexture()

  public required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    backgroundColor = .clear

    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    insertSubview(blurView, at: 0)

    [tintView, desaturateView, vibranceView, brightnessView, chromaView, glareView, noiseView].forEach {
      $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      $0.isUserInteractionEnabled = false
      blurView.contentView.addSubview($0)
    }

    chromaView.layer.addSublayer(chromaLayer)
    glareView.layer.addSublayer(glareLayer)
    glareView.layer.addSublayer(iridescenceLayer)
    blurView.contentView.layer.addSublayer(edgeGlowLayer)
    blurView.contentView.layer.addSublayer(borderLayer)

    noiseView.contentMode = .scaleToFill

    edgeGlowLayer.fillColor = UIColor.clear.cgColor
    borderLayer.fillColor = UIColor.clear.cgColor

    updateBlur()
    updateTint()
    updateColorAdjustments()
    updateOptics()
    updateChroma()
    updateGlare()
    updateNoise()
    updateCornerRadius()
    updateShadow()
    updateBorderAndGlow()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setTintColor(hex: String) {
    let color = Self.parseColor(hex)
    var r: CGFloat = 1
    var g: CGFloat = 1
    var b: CGFloat = 1
    color.getRed(&r, green: &g, blue: &b, alpha: nil)
    tintR = Float(r)
    tintG = Float(g)
    tintB = Float(b)
  }

  public override func didAddSubview(_ subview: UIView) {
    super.didAddSubview(subview)
    if subview !== blurView {
      ensureBackgroundBehindContent()
    }
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    ensureBackgroundBehindContent()

    // Overscan avoids edge artifacts when optical transform offsets/scales the blur.
    let overscan: CGFloat = 14
    blurView.frame = bounds.insetBy(dx: -overscan, dy: -overscan)
    blurView.contentView.bounds = blurView.bounds

    let contentBounds = blurView.bounds
    [tintView, desaturateView, vibranceView, brightnessView, chromaView, glareView, noiseView].forEach {
      $0.frame = contentBounds
    }

    chromaLayer.frame = contentBounds
    glareLayer.frame = contentBounds
    iridescenceLayer.frame = contentBounds

    let radius = CGFloat(glassCornerRadius)
    let inset = max(0.5, CGFloat(edgeWidth) * 0.5)
    let path = UIBezierPath(
      roundedRect: contentBounds.insetBy(dx: inset, dy: inset),
      cornerRadius: max(0, radius - inset)
    ).cgPath
    edgeGlowLayer.path = path
    borderLayer.path = path

    updateCornerRadius()
    updateChroma()
    updateGlare()
    updateBorderAndGlow()
  }

  // MARK: - Update pipeline

  private func updateBlur() {
    let radius = clamp(blurRadius, 0, 100)
    let style: UIBlurEffect.Style
    switch radius {
    case ..<10:
      style = .systemUltraThinMaterial
    case ..<25:
      style = .systemThinMaterial
    case ..<45:
      style = .systemMaterial
    case ..<70:
      style = .systemThickMaterial
    default:
      style = .systemChromeMaterial
    }
    blurView.effect = UIBlurEffect(style: style)
  }

  private func ensureBackgroundBehindContent() {
    if blurView.superview !== self {
      insertSubview(blurView, at: 0)
      return
    }
    if let first = subviews.first, first !== blurView {
      insertSubview(blurView, at: 0)
    }
  }

  private func updateTint() {
    let tint = UIColor(
      red: CGFloat(clamp(tintR, 0, 1)),
      green: CGFloat(clamp(tintG, 0, 1)),
      blue: CGFloat(clamp(tintB, 0, 1)),
      alpha: CGFloat(clamp(glassOpacity, 0, 0.8))
    )
    tintView.backgroundColor = tint
  }

  private func updateColorAdjustments() {
    let sat = clamp(saturation, 0, 2)
    let bright = clamp(brightnessValue, 0, 2)

    // Approximate saturation by blending toward neutral gray.
    let desatAlpha = sat < 1 ? CGFloat((1 - sat) * 0.30) : 0
    desaturateView.backgroundColor = UIColor(white: 0.5, alpha: desatAlpha)

    // Approximate saturation boost with a light screen wash.
    let vibAlpha = sat > 1 ? CGFloat((sat - 1) * 0.14) : 0
    vibranceView.backgroundColor = UIColor.white.withAlphaComponent(vibAlpha)

    if bright >= 1 {
      let alpha = CGFloat((bright - 1) * 0.24)
      brightnessView.backgroundColor = UIColor.white.withAlphaComponent(min(0.4, alpha))
    } else {
      let alpha = CGFloat((1 - bright) * 0.36)
      brightnessView.backgroundColor = UIColor.black.withAlphaComponent(min(0.5, alpha))
    }
  }

  private func updateOptics() {
    let optical = opticalStrength()
    let drift = CGFloat(optical * 9)
    let angle = CGFloat(lightAngle)
    let tx = cos(angle) * drift * 0.18
    let ty = sin(angle) * drift * 0.18
    let scale = 1 + CGFloat(optical * 0.12)

    blurView.transform = CGAffineTransform.identity
      .translatedBy(x: tx, y: ty)
      .scaledBy(x: scale, y: scale)
  }

  private func updateChroma() {
    let angle = CGFloat(lightAngle)
    let dx = cos(angle)
    let dy = sin(angle)
    chromaLayer.startPoint = CGPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5)
    chromaLayer.endPoint = CGPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)

    let base = clamp(chromaticAberration, 0, 1)
    let alpha = CGFloat(base * (0.12 + opticalStrength() * 0.5))
    let spread = max(0.02, CGFloat(base * 0.18))

    chromaLayer.colors = [
      UIColor(red: 1, green: 0.25, blue: 0.35, alpha: alpha).cgColor,
      UIColor.clear.cgColor,
      UIColor(red: 0.25, green: 0.45, blue: 1, alpha: alpha).cgColor,
    ]
    chromaLayer.locations = [0, NSNumber(value: Float(0.5 - spread)), 1]
    chromaView.alpha = alpha > 0.001 ? 1 : 0
  }

  private func updateGlare() {
    let angle = CGFloat(lightAngle)
    let dx = cos(angle)
    let dy = sin(angle)
    glareLayer.startPoint = CGPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5)
    glareLayer.endPoint = CGPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)

    let glare = CGFloat(clamp(glareIntensity, 0, 1))
    let edgeGlow = CGFloat(clamp(edgeGlowIntensity, 0, 1.5))
    let fresnel = CGFloat(clamp(fresnelPower, 0.5, 8))
    let centerFalloff = max(0.10, min(0.34, 0.72 / fresnel))

    glareLayer.colors = [
      UIColor.white.withAlphaComponent(glare * 0.70).cgColor,
      UIColor.white.withAlphaComponent(glare * 0.24).cgColor,
      UIColor.clear.cgColor,
      UIColor.white.withAlphaComponent(edgeGlow * 0.45).cgColor,
    ]
    glareLayer.locations = [0, NSNumber(value: Float(centerFalloff)), 0.70, 1]

    let iri = CGFloat(clamp(iridescence, 0, 1))
    iridescenceLayer.frame = glareLayer.frame
    iridescenceLayer.startPoint = CGPoint(x: 0, y: 0)
    iridescenceLayer.endPoint = CGPoint(x: 1, y: 1)
    iridescenceLayer.colors = [
      UIColor(red: 1.0, green: 0.35, blue: 0.70, alpha: iri * 0.35).cgColor,
      UIColor(red: 0.50, green: 0.40, blue: 1.00, alpha: iri * 0.35).cgColor,
      UIColor(red: 0.20, green: 0.80, blue: 1.00, alpha: iri * 0.35).cgColor,
      UIColor(red: 0.40, green: 1.00, blue: 0.45, alpha: iri * 0.30).cgColor,
      UIColor(red: 1.00, green: 0.90, blue: 0.20, alpha: iri * 0.30).cgColor,
    ]
    iridescenceLayer.isHidden = iri < 0.01
  }

  private func updateBorderAndGlow() {
    let edge = CGFloat(clamp(edgeWidth, 0.5, 8))
    let border = CGFloat(clamp(borderIntensity, 0, 1))
    let glow = CGFloat(clamp(edgeGlowIntensity, 0, 1.5))
    let fresnel = CGFloat(clamp(fresnelPower, 0.5, 8))

    borderLayer.lineWidth = max(0.4, edge * 0.55)
    borderLayer.strokeColor = UIColor.white.withAlphaComponent(border * 0.9).cgColor

    edgeGlowLayer.lineWidth = max(0.7, edge * 0.9)
    edgeGlowLayer.strokeColor = UIColor.white.withAlphaComponent(glow * 0.35 + border * 0.25).cgColor
    edgeGlowLayer.shadowColor = UIColor.white.cgColor
    edgeGlowLayer.shadowOpacity = Float(min(1.0, glow * 0.9))
    edgeGlowLayer.shadowRadius = 4 + edge * 2 + (8.0 / fresnel)
    edgeGlowLayer.shadowOffset = .zero
  }

  private func updateCornerRadius() {
    let radius = CGFloat(max(0, glassCornerRadius))
    layer.cornerRadius = radius
    layer.masksToBounds = false

    blurView.layer.cornerRadius = radius
    blurView.clipsToBounds = true

    borderLayer.cornerRadius = radius
    edgeGlowLayer.cornerRadius = radius
  }

  private func updateShadow() {
    let shadow = clamp(shadowOpacityValue, 0, 1)
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = shadow
    layer.shadowOffset = CGSize(width: 0, height: 5)
    layer.shadowRadius = 14
  }

  private func updateNoise() {
    let n = CGFloat(clamp(noiseIntensity, 0, 0.25))
    noiseView.alpha = n * 1.8
  }

  // MARK: - Helpers

  private func opticalStrength() -> Float {
    let refraction = clamp(refractionStrength, 0, 1) * 0.9
    let iorTerm = max(0, ior - 1) * 0.22
    let magnifyTerm = max(0, magnification - 1) * 0.85
    let liquidTerm = max(0, liquidPower - 1) * 0.25
    return clamp(refraction + iorTerm + magnifyTerm + liquidTerm, 0, 0.35)
  }

  private static func makeNoiseTexture(size: Int = 96) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { ctx in
      ctx.cgContext.setFillColor(UIColor.clear.cgColor)
      ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
      for _ in 0..<(size * size / 4) {
        let x = Int.random(in: 0..<size)
        let y = Int.random(in: 0..<size)
        let alpha = CGFloat.random(in: 0.02...0.14)
        ctx.cgContext.setFillColor(UIColor(white: CGFloat.random(in: 0.75...1.0), alpha: alpha).cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
      }
    }
  }

  static func parseColor(_ color: String) -> UIColor {
    let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
    if let rgb = parseRGB(trimmed) {
      return rgb
    }

    var hex = trimmed
    if hex.hasPrefix("#") {
      hex.removeFirst()
    }

    if hex.count == 3 {
      let chars = Array(hex)
      hex = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
    }

    guard hex.count == 6, let value = UInt64(hex, radix: 16) else {
      return .white
    }

    let r = CGFloat((value >> 16) & 0xFF) / 255.0
    let g = CGFloat((value >> 8) & 0xFF) / 255.0
    let b = CGFloat(value & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: 1)
  }

  private static func parseRGB(_ input: String) -> UIColor? {
    guard input.hasPrefix("rgb("), input.hasSuffix(")") else {
      return nil
    }
    let content = input.dropFirst(4).dropLast()
    let components = content.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard components.count == 3 else {
      return nil
    }

    let values = components.compactMap { Float($0) }
    guard values.count == 3 else {
      return nil
    }

    return UIColor(
      red: CGFloat(clamp(values[0] / 255.0, 0, 1)),
      green: CGFloat(clamp(values[1] / 255.0, 0, 1)),
      blue: CGFloat(clamp(values[2] / 255.0, 0, 1)),
      alpha: 1
    )
  }
}

private func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
  max(minValue, min(maxValue, value))
}
