import type { StyleProp, ViewStyle } from 'react-native';

export interface LiquidGlassConfig {
  blurRadius?: number;
  refractionStrength?: number;
  ior?: number;
  chromaticAberration?: number;
  edgeGlowIntensity?: number;
  magnification?: number;
  glassOpacity?: number;
  /** Tint color as HEX string (#RGB, #RRGGBB) or rgb(r,g,b) — default: '#ffffff' */
  tintColor?: string;
  fresnelPower?: number;
  cornerRadius?: number;
  shadowOpacity?: number;
  glareIntensity?: number;
  lightAngle?: number;
  borderIntensity?: number;
  edgeWidth?: number;
  liquidPower?: number;
  saturation?: number;
  brightness?: number;
  noiseIntensity?: number;
  iridescence?: number;
}

export interface LiquidGlassViewProps extends LiquidGlassConfig {
  children?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}

export const LIQUID_GLASS_DEFAULTS: Required<LiquidGlassConfig> = {
  blurRadius: 20,
  refractionStrength: 0.03,
  ior: 1.2,
  chromaticAberration: 0.05,
  edgeGlowIntensity: 0.18,
  magnification: 1.08,
  glassOpacity: 0.05,
  tintColor: '#ffffff',
  fresnelPower: 3.0,
  cornerRadius: 24,
  shadowOpacity: 0.0,
  glareIntensity: 0.3,
  lightAngle: 0.8,
  borderIntensity: 0.28,
  edgeWidth: 2.0,
  liquidPower: 1.5,
  saturation: 1.0,
  brightness: 1.0,
  noiseIntensity: 0.0,
  iridescence: 0.0,
};

export const LIQUID_GLASS_FROSTED: LiquidGlassConfig = {
  blurRadius: 35,
  refractionStrength: 0.01,
  chromaticAberration: 0.02,
  edgeGlowIntensity: 0.3,
  glassOpacity: 0.15,
  tintColor: '#e6eeff',
  fresnelPower: 2.0,
  cornerRadius: 24,
  glareIntensity: 0.15,
  lightAngle: 0.5,
  borderIntensity: 0.08,
  edgeWidth: 1.6,
  liquidPower: 1.2,
  saturation: 0.8,
  noiseIntensity: 0.04,
};

export const LIQUID_GLASS_CRYSTAL: LiquidGlassConfig = {
  blurRadius: 12,
  refractionStrength: 0.06,
  chromaticAberration: 0.08,
  edgeGlowIntensity: 0.9,
  glassOpacity: 0.06,
  tintColor: '#f2f5ff',
  fresnelPower: 4.0,
  cornerRadius: 40,
  glareIntensity: 0.6,
  lightAngle: 1.0,
  borderIntensity: 0.2,
  edgeWidth: 2.6,
  liquidPower: 1.9,
  saturation: 1.2,
  iridescence: 0.3,
};

export const LIQUID_GLASS_WARM: LiquidGlassConfig = {
  blurRadius: 22,
  refractionStrength: 0.03,
  chromaticAberration: 0.03,
  edgeGlowIntensity: 0.5,
  glassOpacity: 0.15,
  tintColor: '#ffead1',
  fresnelPower: 2.5,
  cornerRadius: 28,
  glareIntensity: 0.25,
  lightAngle: 0.6,
  borderIntensity: 0.12,
  edgeWidth: 1.9,
  liquidPower: 1.4,
  saturation: 1.1,
  brightness: 1.05,
};

export const LIQUID_GLASS_IRIDESCENT: LiquidGlassConfig = {
  blurRadius: 18,
  refractionStrength: 0.04,
  chromaticAberration: 0.06,
  edgeGlowIntensity: 0.6,
  glassOpacity: 0.08,
  tintColor: '#ffffff',
  fresnelPower: 3.5,
  cornerRadius: 32,
  glareIntensity: 0.4,
  lightAngle: 0.8,
  borderIntensity: 0.18,
  edgeWidth: 2.2,
  liquidPower: 1.7,
  saturation: 1.15,
  iridescence: 0.7,
};
