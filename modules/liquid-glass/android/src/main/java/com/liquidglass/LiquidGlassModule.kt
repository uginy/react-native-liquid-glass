package com.liquidglass

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class LiquidGlassModule : Module() {
    override fun definition() = ModuleDefinition {
        Name("LiquidGlass")

        View(LiquidGlassView::class) {
            Name("LiquidGlass")
            Prop("blurRadius") { view: LiquidGlassView, value: Double -> view.blurRadius = value.toFloat() }
            Prop("refractionStrength") { view: LiquidGlassView, value: Double -> view.refractionStrength = value.toFloat() }
            Prop("ior") { view: LiquidGlassView, value: Double -> view.ior = value.toFloat() }
            Prop("chromaticAberration") { view: LiquidGlassView, value: Double -> view.chromaticAberration = value.toFloat() }
            Prop("edgeGlowIntensity") { view: LiquidGlassView, value: Double -> view.edgeGlowIntensity = value.toFloat() }
            Prop("magnification") { view: LiquidGlassView, value: Double -> view.magnification = value.toFloat() }
            Prop("glassOpacity") { view: LiquidGlassView, value: Double -> view.glassOpacity = value.toFloat() }
            Prop("glassColor") { view: LiquidGlassView, value: String -> view.tintColor = value }
            Prop("fresnelPower") { view: LiquidGlassView, value: Double -> view.fresnelPower = value.toFloat() }
            Prop("cornerRadius") { view: LiquidGlassView, value: Double -> view.cornerRadius = value.toFloat() }
            Prop("glareIntensity") { view: LiquidGlassView, value: Double -> view.glareIntensity = value.toFloat() }
            Prop("borderIntensity") { view: LiquidGlassView, value: Double -> view.borderIntensity = value.toFloat() }
            Prop("edgeWidth") { view: LiquidGlassView, value: Double -> view.edgeWidth = value.toFloat() }
            Prop("liquidPower") { view: LiquidGlassView, value: Double -> view.liquidPower = value.toFloat() }
            Prop("lightAngle") { view: LiquidGlassView, value: Double -> view.lightAngle = value.toFloat() }
            Prop("saturation") { view: LiquidGlassView, value: Double -> view.saturation = value.toFloat() }
            Prop("brightness") { view: LiquidGlassView, value: Double -> view.brightness = value.toFloat() }
            Prop("noiseIntensity") { view: LiquidGlassView, value: Double -> view.noiseIntensity = value.toFloat() }
            Prop("iridescence") { view: LiquidGlassView, value: Double -> view.iridescence = value.toFloat() }
            Prop("shadowOpacity") { _: LiquidGlassView, _: Double -> }
        }
    }
}
