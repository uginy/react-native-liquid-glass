import ExpoModulesCore

public class LiquidGlassModule: Module {
  public func definition() -> ModuleDefinition {
    Name("LiquidGlass")

    View(LiquidGlassView.self) {
      Prop("blurRadius") { (view: LiquidGlassView, value: Double) in view.blurRadius = Float(value) }
      Prop("refractionStrength") { (view: LiquidGlassView, value: Double) in view.refractionStrength = Float(value) }
      Prop("ior") { (view: LiquidGlassView, value: Double) in view.ior = Float(value) }
      Prop("chromaticAberration") { (view: LiquidGlassView, value: Double) in view.chromaticAberration = Float(value) }
      Prop("edgeGlowIntensity") { (view: LiquidGlassView, value: Double) in view.edgeGlowIntensity = Float(value) }
      Prop("magnification") { (view: LiquidGlassView, value: Double) in view.magnification = Float(value) }
      Prop("glassOpacity") { (view: LiquidGlassView, value: Double) in view.glassOpacity = Float(value) }
      Prop("glassColor") { (view: LiquidGlassView, value: String) in view.setTintColor(hex: value) }
      Prop("fresnelPower") { (view: LiquidGlassView, value: Double) in view.fresnelPower = Float(value) }
      Prop("cornerRadius") { (view: LiquidGlassView, value: Double) in view.glassCornerRadius = Float(value) }
      Prop("shadowOpacity") { (view: LiquidGlassView, value: Double) in view.shadowOpacityValue = Float(value) }
      Prop("glareIntensity") { (view: LiquidGlassView, value: Double) in view.glareIntensity = Float(value) }
      Prop("lightAngle") { (view: LiquidGlassView, value: Double) in view.lightAngle = Float(value) }
      Prop("borderIntensity") { (view: LiquidGlassView, value: Double) in view.borderIntensity = Float(value) }
      Prop("edgeWidth") { (view: LiquidGlassView, value: Double) in view.edgeWidth = Float(value) }
      Prop("liquidPower") { (view: LiquidGlassView, value: Double) in view.liquidPower = Float(value) }
      Prop("saturation") { (view: LiquidGlassView, value: Double) in view.saturation = Float(value) }
      Prop("brightness") { (view: LiquidGlassView, value: Double) in view.brightnessValue = Float(value) }
      Prop("noiseIntensity") { (view: LiquidGlassView, value: Double) in view.noiseIntensity = Float(value) }
      Prop("iridescence") { (view: LiquidGlassView, value: Double) in view.iridescence = Float(value) }
    }
  }
}
