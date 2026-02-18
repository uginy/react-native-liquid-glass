import ExpoModulesCore
import UIKit

public class LiquidGlassView: ExpoView {

  // MARK: - Props
  var blurRadius: Float = 20 { didSet { updateEffect() } }
  var refractionStrength: Float = 0.03
  var ior: Float = 1.2
  var chromaticAberration: Float = 0.05
  var edgeGlowIntensity: Float = 0.18 { didSet { updateOverlay() } }
  var magnification: Float = 1.08
  var glassOpacity: Float = 0.05 { didSet { updateTint() } }
  var tintR: Float = 1.0 { didSet { updateTint() } }
  var tintG: Float = 1.0 { didSet { updateTint() } }
  var tintB: Float = 1.0 { didSet { updateTint() } }
  var fresnelPower: Float = 3.0 { didSet { updateOverlay() } }
  var glassCornerRadius: Float = 24 { didSet { updateCornerRadius() } }
  var shadowOpacityValue: Float = 0 { didSet { updateShadow() } }
  var glareIntensity: Float = 0.3 { didSet { updateOverlay() } }
  var lightAngle: Float = 0.8 { didSet { updateOverlay() } }
  var borderIntensity: Float = 0.28 { didSet { updateBorder() } }
  var edgeWidth: Float = 2.0 { didSet { updateBorder() } }
  var liquidPower: Float = 1.5
  var saturation: Float = 1.0 { didSet { updateEffect() } }
  var brightnessValue: Float = 1.0 { didSet { updateTint() } }
  var noiseIntensity: Float = 0.0
  var iridescence: Float = 0.0 { didSet { updateOverlay() } }

  func setTintColor(hex: String) {
    let (r, g, b) = Self.parseHexColor(hex)
    tintR = r; tintG = g; tintB = b
  }

  // MARK: - Subviews
  private var blurView: UIVisualEffectView!
  private var tintView: UIView!
  private var glareView: UIView!
  private var borderLayer: CALayer!

  // MARK: - Init
  public required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    backgroundColor = .clear
    clipsToBounds = true
    setupSubviews()
  }

  required init?(coder: NSCoder) { fatalError() }

  private func setupSubviews() {
    // Blur layer
    blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    blurView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(blurView)
    NSLayoutConstraint.activate([
      blurView.topAnchor.constraint(equalTo: topAnchor),
      blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
      blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])

    // Tint overlay
    tintView = UIView()
    tintView.translatesAutoresizingMaskIntoConstraints = false
    blurView.contentView.addSubview(tintView)
    NSLayoutConstraint.activate([
      tintView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
      tintView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
      tintView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
      tintView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
    ])

    // Glare overlay
    glareView = UIView()
    glareView.translatesAutoresizingMaskIntoConstraints = false
    blurView.contentView.addSubview(glareView)
    NSLayoutConstraint.activate([
      glareView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
      glareView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
      glareView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
      glareView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
    ])

    // Border
    borderLayer = CALayer()
    borderLayer.borderColor = UIColor.white.cgColor
    layer.addSublayer(borderLayer)

    updateEffect()
    updateTint()
    updateOverlay()
    updateBorder()
    updateCornerRadius()
  }

  // MARK: - Layout
  public override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    borderLayer.frame = bounds
    updateCornerRadius()
    updateOverlay()
    CATransaction.commit()
  }

  // MARK: - Updates
  private func updateEffect() {
    let style: UIBlurEffect.Style
    if blurRadius < 15 {
      style = .systemUltraThinMaterial
    } else if blurRadius < 40 {
      style = .systemThinMaterial
    } else if blurRadius < 70 {
      style = .systemMaterial
    } else {
      style = .systemThickMaterial
    }
    blurView?.effect = UIBlurEffect(style: style)
  }

  private func updateTint() {
    let r = CGFloat(tintR)
    let g = CGFloat(tintG)
    let b = CGFloat(tintB)
    let alpha = CGFloat(glassOpacity) * CGFloat(brightnessValue)
    tintView?.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: min(alpha, 0.5))
  }

  private func updateOverlay() {
    guard glareView != nil else { return }
    let angle = CGFloat(lightAngle)
    let dx = cos(angle)
    let dy = -sin(angle)

    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = glareView.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 300, height: 100) : glareView.bounds
    let glare = CGFloat(glareIntensity) * 0.4
    let edgeGlow = CGFloat(edgeGlowIntensity) * 0.3
    let irid = CGFloat(iridescence)

    let startColor: UIColor
    let endColor: UIColor
    if irid > 0.1 {
      startColor = UIColor(hue: CGFloat(lightAngle / 6.28), saturation: irid * 0.8, brightness: 1, alpha: glare + edgeGlow)
      endColor = UIColor(hue: fmod(CGFloat(lightAngle / 6.28) + 0.5, 1.0), saturation: irid * 0.6, brightness: 1, alpha: edgeGlow * 0.5)
    } else {
      startColor = UIColor.white.withAlphaComponent(glare + edgeGlow)
      endColor = UIColor.white.withAlphaComponent(edgeGlow * 0.3)
    }

    gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
    let norm = sqrt(dx * dx + dy * dy)
    let ndx = norm > 0 ? dx / norm : 0
    let ndy = norm > 0 ? dy / norm : 0
    gradientLayer.startPoint = CGPoint(x: 0.5 + ndx * 0.5, y: 0.5 + ndy * 0.5)
    gradientLayer.endPoint   = CGPoint(x: 0.5 - ndx * 0.5, y: 0.5 - ndy * 0.5)

    glareView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    glareView.layer.addSublayer(gradientLayer)
  }

  private func updateBorder() {
    borderLayer?.borderWidth = CGFloat(edgeWidth) * 0.5
    borderLayer?.borderColor = UIColor.white.withAlphaComponent(CGFloat(borderIntensity) * 1.5).cgColor
  }

  private func updateCornerRadius() {
    let r = CGFloat(glassCornerRadius)
    layer.cornerRadius = r
    blurView?.layer.cornerRadius = r
    blurView?.clipsToBounds = true
    borderLayer?.cornerRadius = r
    if let gl = glareView.layer.sublayers?.first as? CAGradientLayer {
      gl.frame = glareView.bounds
      gl.cornerRadius = r
      gl.masksToBounds = true
    }
  }

  private func updateShadow() {
    layer.shadowOpacity = shadowOpacityValue
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOffset = CGSize(width: 0, height: 4)
    layer.shadowRadius = 12
  }

  // MARK: - Color parsing
  static func parseHexColor(_ color: String) -> (Float, Float, Float) {
    var s = color.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") {
      s = String(s.dropFirst())
      if s.count == 3 {
        let r = Float(Int(String(repeating: String(s[s.index(s.startIndex, offsetBy: 0)]), count: 2), radix: 16) ?? 255) / 255
        let g = Float(Int(String(repeating: String(s[s.index(s.startIndex, offsetBy: 1)]), count: 2), radix: 16) ?? 255) / 255
        let b = Float(Int(String(repeating: String(s[s.index(s.startIndex, offsetBy: 2)]), count: 2), radix: 16) ?? 255) / 255
        return (r, g, b)
      }
      if s.count == 6 {
        let r = Float(Int(s.prefix(2), radix: 16) ?? 255) / 255
        let g = Float(Int(s.dropFirst(2).prefix(2), radix: 16) ?? 255) / 255
        let b = Float(Int(s.dropFirst(4).prefix(2), radix: 16) ?? 255) / 255
        return (r, g, b)
      }
    }
    return (1, 1, 1)
  }
}
