import ExpoModulesCore
import UIKit

public class LiquidGlassView: ExpoView {

    // MARK: - Props

    var blurRadius: Float = 20 { didSet { updateBlur() } }
    var refractionStrength: Float = 0.03
    var ior: Float = 1.2
    var chromaticAberration: Float = 0.05
    var edgeGlowIntensity: Float = 0.18 { didSet { updateGlare() } }
    var magnification: Float = 1.08
    var glassOpacity: Float = 0.05 { didSet { updateTint() } }
    var tintR: Float = 1.0 { didSet { updateTint() } }
    var tintG: Float = 1.0 { didSet { updateTint() } }
    var tintB: Float = 1.0 { didSet { updateTint() } }
    var fresnelPower: Float = 3.0
    var glassCornerRadius: Float = 24 { didSet { updateCornerRadius() } }
    var shadowOpacityValue: Float = 0 { didSet { updateShadow() } }
    var glareIntensity: Float = 0.3 { didSet { updateGlare() } }
    var lightAngle: Float = 0.8 { didSet { updateGlare() } }
    var borderIntensity: Float = 0.28 { didSet { updateBorder() } }
    var edgeWidth: Float = 2.0 { didSet { updateBorder() } }
    var liquidPower: Float = 1.5
    var saturation: Float = 1.0
    var brightnessValue: Float = 1.0
    var noiseIntensity: Float = 0.0
    var iridescence: Float = 0.0 { didSet { updateGlare() } }

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

        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        tintView = UIView()
        tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(tintView)

        glareView = UIView()
        glareView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        glareView.isUserInteractionEnabled = false
        blurView.contentView.addSubview(glareView)

        borderLayer = CALayer()
        borderLayer.zPosition = 1
        layer.addSublayer(borderLayer)

        updateBlur()
        updateTint()
        updateGlare()
        updateBorder()
        updateCornerRadius()
        updateShadow()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        tintView.frame = bounds
        glareView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        borderLayer.frame = bounds
        borderLayer.cornerRadius = CGFloat(glassCornerRadius)
        CATransaction.commit()
        updateGlare()
    }

    // MARK: - Updates

    private func updateBlur() {
        let style: UIBlurEffect.Style
        switch blurRadius {
        case ..<15:  style = .systemUltraThinMaterial
        case ..<40:  style = .systemThinMaterial
        case ..<70:  style = .systemMaterial
        default:     style = .systemThickMaterial
        }
        blurView?.effect = UIBlurEffect(style: style)
    }

    private func updateTint() {
        tintView?.backgroundColor = UIColor(
            red: CGFloat(tintR),
            green: CGFloat(tintG),
            blue: CGFloat(tintB),
            alpha: CGFloat(glassOpacity)
        )
    }

    private func updateGlare() {
        guard let glare = glareView, bounds.width > 0 else { return }

        glare.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Main glare gradient
        let glareLayer = CAGradientLayer()
        glareLayer.frame = bounds
        let angle = CGFloat(lightAngle)
        let dx = cos(angle), dy = sin(angle)
        glareLayer.startPoint = CGPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5)
        glareLayer.endPoint   = CGPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
        let gi = CGFloat(glareIntensity)
        let eg = CGFloat(edgeGlowIntensity)
        glareLayer.colors = [
            UIColor.white.withAlphaComponent(gi * 0.6).cgColor,
            UIColor.white.withAlphaComponent(gi * 0.1).cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(eg * 0.4).cgColor,
        ]
        glareLayer.locations = [0, 0.3, 0.6, 1]
        glare.layer.addSublayer(glareLayer)

        // Iridescent rainbow overlay
        if iridescence > 0.01 {
            let iriLayer = CAGradientLayer()
            iriLayer.frame = bounds
            iriLayer.type = .axial
            let ia = CGFloat(iridescence) * 0.35
            iriLayer.startPoint = CGPoint(x: 0, y: 0)
            iriLayer.endPoint   = CGPoint(x: 1, y: 1)
            iriLayer.colors = [
                UIColor(red: 1, green: 0.4, blue: 0.7, alpha: ia).cgColor,
                UIColor(red: 0.5, green: 0.4, blue: 1, alpha: ia).cgColor,
                UIColor(red: 0.2, green: 0.8, blue: 1, alpha: ia).cgColor,
                UIColor(red: 0.4, green: 1, blue: 0.5, alpha: ia).cgColor,
                UIColor(red: 1, green: 0.9, blue: 0.2, alpha: ia).cgColor,
            ]
            glare.layer.addSublayer(iriLayer)
        }
    }

    private func updateBorder() {
        borderLayer?.borderWidth = CGFloat(edgeWidth) * 0.5
        borderLayer?.borderColor = UIColor.white
            .withAlphaComponent(CGFloat(borderIntensity) * 1.5).cgColor
    }

    private func updateCornerRadius() {
        let r = CGFloat(glassCornerRadius)
        layer.cornerRadius = r
        blurView?.layer.cornerRadius = r
        blurView?.clipsToBounds = true
        borderLayer?.cornerRadius = r
    }

    private func updateShadow() {
        layer.shadowOpacity = shadowOpacityValue
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOffset  = CGSize(width: 0, height: 4)
        layer.shadowRadius  = 12
        layer.masksToBounds = false
    }

    // MARK: - Helpers

    static func parseHexColor(_ color: String) -> (Float, Float, Float) {
        var s = color.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        var hex: UInt64 = 0
        Scanner(string: s).scanHexInt64(&hex)
        if s.count == 6 {
            return (
                Float((hex & 0xff0000) >> 16) / 255,
                Float((hex & 0x00ff00) >> 8)  / 255,
                Float(hex & 0x0000ff)          / 255
            )
        }
        return (1, 1, 1)
    }
}
