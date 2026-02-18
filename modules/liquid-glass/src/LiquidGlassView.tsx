import { requireNativeView } from 'expo';
import React from 'react';
import { Platform, View } from 'react-native';

import { LiquidGlassViewProps, LIQUID_GLASS_DEFAULTS } from './LiquidGlass.types';

const NativeView: React.ComponentType<any> =
  Platform.OS === 'android'
    ? requireNativeView('LiquidGlass')
    : View;

export default function LiquidGlassView({
  children,
  style,
  blurRadius = LIQUID_GLASS_DEFAULTS.blurRadius,
  refractionStrength = LIQUID_GLASS_DEFAULTS.refractionStrength,
  ior = LIQUID_GLASS_DEFAULTS.ior,
  chromaticAberration = LIQUID_GLASS_DEFAULTS.chromaticAberration,
  edgeGlowIntensity = LIQUID_GLASS_DEFAULTS.edgeGlowIntensity,
  magnification = LIQUID_GLASS_DEFAULTS.magnification,
  glassOpacity = LIQUID_GLASS_DEFAULTS.glassOpacity,
  tintColor = LIQUID_GLASS_DEFAULTS.tintColor,
  fresnelPower = LIQUID_GLASS_DEFAULTS.fresnelPower,
  cornerRadius = LIQUID_GLASS_DEFAULTS.cornerRadius,
  shadowOpacity = LIQUID_GLASS_DEFAULTS.shadowOpacity,
  glareIntensity = LIQUID_GLASS_DEFAULTS.glareIntensity,
  lightAngle = LIQUID_GLASS_DEFAULTS.lightAngle,
  borderIntensity = LIQUID_GLASS_DEFAULTS.borderIntensity,
  edgeWidth = LIQUID_GLASS_DEFAULTS.edgeWidth,
  liquidPower = LIQUID_GLASS_DEFAULTS.liquidPower,
  saturation = LIQUID_GLASS_DEFAULTS.saturation,
  brightness = LIQUID_GLASS_DEFAULTS.brightness,
  noiseIntensity = LIQUID_GLASS_DEFAULTS.noiseIntensity,
  iridescence = LIQUID_GLASS_DEFAULTS.iridescence,
}: LiquidGlassViewProps) {
  if (Platform.OS !== 'android') {
    return (
      <View style={[{ overflow: 'hidden', backgroundColor: 'rgba(255,255,255,0.08)' }, style]}>
        {children}
      </View>
    );
  }

  const shadowStyle =
    shadowOpacity > 0
      ? { shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity, shadowRadius: 12, elevation: 8 }
      : { elevation: 0, shadowColor: 'transparent', shadowOffset: { width: 0, height: 0 }, shadowOpacity: 0, shadowRadius: 0 };

  return (
    <View style={shadowStyle}>
      <NativeView
        style={[{ overflow: 'hidden' }, style]}
        blurRadius={blurRadius}
        refractionStrength={refractionStrength}
        ior={ior}
        chromaticAberration={chromaticAberration}
        edgeGlowIntensity={edgeGlowIntensity}
        magnification={magnification}
        glassOpacity={glassOpacity}
        glassColor={tintColor}
        fresnelPower={fresnelPower}
        cornerRadius={cornerRadius}
        shadowOpacity={shadowOpacity}
        glareIntensity={glareIntensity}
        lightAngle={lightAngle}
        borderIntensity={borderIntensity}
        edgeWidth={edgeWidth}
        liquidPower={liquidPower}
        saturation={saturation}
        brightness={brightness}
        noiseIntensity={noiseIntensity}
        iridescence={iridescence}
      >
        {children}
      </NativeView>
    </View>
  );
}
