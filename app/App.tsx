import React, {
  memo,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react';
import {
  StyleSheet,
  View,
  Text,
  ImageBackground,
  Platform,
  FlatList,
  TouchableOpacity,
  ScrollView,
} from 'react-native';
import { LiquidGlassView } from 'react-native-liquid-glass';
import Slider from '@react-native-community/slider';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';

const PANEL_HEIGHT = 480;

const TINT_PRESETS = [
  { label: 'White', color: '#ffffff' },
  { label: 'Ice', color: '#e6eeff' },
  { label: 'Warm', color: '#ffead1' },
  { label: 'Pink', color: '#ffe4f0' },
  { label: 'Mint', color: '#d4f5e9' },
  { label: 'Gold', color: '#fff3cc' },
  { label: 'Violet', color: '#f0e6ff' },
  { label: 'Dark', color: '#1a1a2e' },
];

const CARDS = Array.from({ length: 20 }, (_, i) => ({
  id: `${i + 1}`,
  icon: ['🎵', '⛅', '📱', '📸', '🗓️', '💳', '🏃', '🔋', '🎮', '📍'][i % 10],
  title: `Card ${i + 1}`,
  subtitle: `Sub-description for item ${i + 1}`,
}));

type GlassSettings = {
  blurRadius: number;
  refractionStrength: number;
  chromaticAberration: number;
  edgeGlowIntensity: number;
  glassOpacity: number;
  tintColor: string;
  cornerRadius: number;
  glareIntensity: number;
  lightAngle: number;
  borderIntensity: number;
  edgeWidth: number;
  liquidPower: number;
  fresnelPower: number;
  saturation: number;
  brightness: number;
  noiseIntensity: number;
  iridescence: number;
};

type NumericKey = Exclude<keyof GlassSettings, 'tintColor'>;
type CardModel = (typeof CARDS)[number];

const INITIAL_SETTINGS: GlassSettings = {
  blurRadius: 60,
  refractionStrength: 0.6,
  chromaticAberration: 0.05,
  edgeGlowIntensity: 0.18,
  glassOpacity: 0.05,
  tintColor: '#ffffff',
  cornerRadius: 24,
  glareIntensity: 0.3,
  lightAngle: 0.8,
  borderIntensity: 0.28,
  edgeWidth: 2.0,
  liquidPower: 1.5,
  fresnelPower: 3.0,
  saturation: 1.0,
  brightness: 1.0,
  noiseIntensity: 0.0,
  iridescence: 0.0,
};

const GlassCard = memo(function GlassCard({
  card,
  settings,
}: {
  card: CardModel;
  settings: GlassSettings;
}) {
  return (
    <LiquidGlassView
      blurRadius={settings.blurRadius}
      refractionStrength={settings.refractionStrength}
      chromaticAberration={settings.chromaticAberration}
      edgeGlowIntensity={settings.edgeGlowIntensity}
      glassOpacity={settings.glassOpacity}
      tintColor={settings.tintColor}
      cornerRadius={settings.cornerRadius}
      glareIntensity={settings.glareIntensity}
      lightAngle={settings.lightAngle}
      borderIntensity={settings.borderIntensity}
      edgeWidth={settings.edgeWidth}
      liquidPower={settings.liquidPower}
      fresnelPower={settings.fresnelPower}
      saturation={settings.saturation}
      brightness={settings.brightness}
      noiseIntensity={settings.noiseIntensity}
      iridescence={settings.iridescence}
      style={styles.card}
    >
      <View style={styles.cardContent}>
        <Text style={styles.cardIcon}>{card.icon}</Text>
        <View style={styles.cardTextContainer}>
          <Text style={styles.cardTitle}>{card.title}</Text>
          <Text style={styles.cardSubtitle}>{card.subtitle}</Text>
        </View>
      </View>
    </LiquidGlassView>
  );
});

export default function App() {
  return (
    <SafeAreaProvider>
      <AppScreen />
    </SafeAreaProvider>
  );
}

function AppScreen() {
  const insets = useSafeAreaInsets();
  const topInset = insets.top > 0 ? insets.top : Platform.OS === 'android' ? 24 : 0;
  const [showSettings, setShowSettings] = useState(false);
  const [settings, setSettings] = useState<GlassSettings>(INITIAL_SETTINGS);
  const frameRef = useRef<number | null>(null);
  const pendingRef = useRef<Partial<GlassSettings>>({});

  const handleNumChange = useCallback((key: NumericKey, value: number) => {
    setSettings((prev) => prev[key] === value ? prev : { ...prev, [key]: value });
  }, []);

  const handleNumChangeLive = useCallback((key: NumericKey, value: number) => {
    pendingRef.current[key] = value;
    if (frameRef.current !== null) return;
    frameRef.current = requestAnimationFrame(() => {
      frameRef.current = null;
      const pending = pendingRef.current;
      pendingRef.current = {};
      setSettings((prev) => {
        let changed = false;
        const next: GlassSettings = { ...prev };
        (Object.keys(pending) as NumericKey[]).forEach((k) => {
          const v = pending[k];
          if (typeof v === 'number' && next[k] !== v) { next[k] = v; changed = true; }
        });
        return changed ? next : prev;
      });
    });
  }, []);

  const handleTintColor = useCallback((color: string) => {
    setSettings((prev) => ({ ...prev, tintColor: color }));
  }, []);

  const handleReset = useCallback(() => setSettings(INITIAL_SETTINGS), []);

  useEffect(() => () => { if (frameRef.current !== null) cancelAnimationFrame(frameRef.current); }, []);

  const renderCardItem = useCallback(
    ({ item }: { item: CardModel }) => <GlassCard card={item} settings={settings} />,
    [settings]
  );

  return (
    <View style={styles.container}>
      <ImageBackground
        source={require('./assets/background_contrast.png')}
        style={styles.background}
        resizeMode="cover"
      >
        <View style={[styles.header, { paddingTop: topInset + 8 }]}>
          <Text style={styles.headerTitle}>Liquid Glass Demo</Text>
        </View>

        <FlatList
          style={styles.scrollView}
          contentContainerStyle={[styles.scrollContent, { paddingBottom: Math.max(40, insets.bottom + 28) }]}
          showsVerticalScrollIndicator={false}
          data={CARDS}
          renderItem={renderCardItem}
          keyExtractor={(item) => item.id}
          removeClippedSubviews
          initialNumToRender={6}
          maxToRenderPerBatch={4}
          windowSize={7}
          updateCellsBatchingPeriod={48}
          extraData={settings}
        />

        {!showSettings && (
          <TouchableOpacity
            onPress={() => setShowSettings(true)}
            style={[styles.floatingBtn, { bottom: insets.bottom + 20 }]}
          >
            <Text style={styles.floatingBtnText}>⚙</Text>
          </TouchableOpacity>
        )}

        {showSettings && (
          <SettingsPanel
            settings={settings}
            onNumChange={handleNumChangeLive}
            onNumCommit={handleNumChange}
            onTintColor={handleTintColor}
            onReset={handleReset}
            onClose={() => setShowSettings(false)}
            bottomInset={insets.bottom}
          />
        )}
      </ImageBackground>
    </View>
  );
}

function SettingsPanel({
  settings,
  onNumChange,
  onNumCommit,
  onTintColor,
  onReset,
  onClose,
  bottomInset,
}: {
  settings: GlassSettings;
  onNumChange: (key: NumericKey, value: number) => void;
  onNumCommit: (key: NumericKey, value: number) => void;
  onTintColor: (color: string) => void;
  onReset: () => void;
  onClose: () => void;
  bottomInset: number;
}) {
  const s = (key: NumericKey, min: number, max: number, step = 0.01, label?: string) => (
    <SettingSlider
      key={key}
      label={label ?? key}
      value={settings[key] as number}
      min={min}
      max={max}
      step={step}
      onChange={(v) => onNumChange(key, v)}
      onCommit={(v) => onNumCommit(key, v)}
    />
  );

  return (
    <View style={[styles.settingsPanel, { height: PANEL_HEIGHT + bottomInset, paddingBottom: bottomInset + 8 }]}>
      <View style={styles.settingsHeader}>
        <Text style={styles.settingsTitle}>Glass Settings</Text>
        <View style={styles.settingsActions}>
          <TouchableOpacity onPress={onReset} style={styles.resetBtn}>
            <Text style={styles.resetBtnText}>Reset</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeBtnText}>✕</Text>
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView style={styles.settingsScroll} showsVerticalScrollIndicator={false}>
        <Text style={styles.sectionLabel}>— Blur & Distortion —</Text>
        {s('blurRadius', 0, 100, 1, 'Blur')}
        {s('refractionStrength', 0, 1, 0.01, 'Refraction')}
        {s('chromaticAberration', 0, 1.0, 0.01, 'Chromatic')}

        <Text style={styles.sectionLabel}>— Tint Color —</Text>
        <View style={styles.swatchRow}>
          {TINT_PRESETS.map((p) => (
            <TouchableOpacity
              key={p.color}
              onPress={() => onTintColor(p.color)}
              style={[
                styles.swatch,
                { backgroundColor: p.color },
                settings.tintColor === p.color && styles.swatchSelected,
              ]}
            />
          ))}
        </View>
        <Text style={styles.swatchHex}>{settings.tintColor}</Text>
        {s('glassOpacity', 0, 0.5, 0.01, 'Tint Opacity')}

        <Text style={styles.sectionLabel}>— Image —</Text>
        {s('saturation', 0, 2, 0.05, 'Saturation')}
        {s('brightness', 0, 2, 0.05, 'Brightness')}
        {s('noiseIntensity', 0, 0.15, 0.005, 'Noise / Grain')}

        <Text style={styles.sectionLabel}>— Edges & Light —</Text>
        {s('edgeGlowIntensity', 0, 1, 0.01, 'Edge Glow')}
        {s('glareIntensity', 0, 1, 0.01, 'Glare')}
        {s('lightAngle', 0, 6.28, 0.05, 'Light Angle')}
        {s('borderIntensity', 0, 0.5, 0.01, 'Border')}
        {s('fresnelPower', 0.5, 8, 0.1, 'Fresnel Power')}
        {s('iridescence', 0, 1, 0.01, 'Iridescence')}

        <Text style={styles.sectionLabel}>— Shape —</Text>
        {s('cornerRadius', 0, 60, 1, 'Corner Radius')}
        {s('edgeWidth', 0.5, 5, 0.1, 'Edge Width')}
        {s('liquidPower', 0.5, 3, 0.1, 'Liquid Power')}

        <View style={{ height: 16 }} />
      </ScrollView>
    </View>
  );
}

function SettingSlider({
  label,
  value,
  min,
  max,
  step = 0.01,
  onChange,
  onCommit,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  onChange: (v: number) => void;
  onCommit: (v: number) => void;
}) {
  const digits = step < 0.01 ? 3 : step < 1 ? 2 : 0;
  const normalize = useCallback(
    (v: number) => Number((Math.round(Math.max(min, Math.min(max, v)) / step) * step).toFixed(4)),
    [min, max, step]
  );
  return (
    <View style={styles.sliderRow}>
      <View style={styles.sliderLabelRow}>
        <Text style={styles.sliderLabel}>{label}</Text>
        <Text style={styles.sliderValue}>{value.toFixed(digits)}</Text>
      </View>
      <Slider
        style={styles.nativeSlider}
        minimumValue={min}
        maximumValue={max}
        step={step}
        value={value}
        onValueChange={(v) => onChange(normalize(v))}
        onSlidingComplete={(v) => onCommit(normalize(v))}
        minimumTrackTintColor="rgba(255,255,255,0.75)"
        maximumTrackTintColor="rgba(255,255,255,0.22)"
        thumbTintColor="#ffffff"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  background: { flex: 1, width: '100%', height: '100%' },
  header: { paddingHorizontal: 20, paddingBottom: 12 },
  headerTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#fff',
    textShadowColor: 'rgba(0,0,0,0.3)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 10,
  },
  floatingBtn: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: 'rgba(0,0,0,0.7)',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 8,
  },
  floatingBtnText: { fontSize: 28, color: '#fff' },
  scrollView: { flex: 1 },
  scrollContent: { paddingHorizontal: 16, paddingTop: 10, gap: 16 },
  card: { width: '100%', minHeight: 90, borderRadius: 24 },
  plainCard: { backgroundColor: 'rgba(255,255,255,0.08)' },
  cardContent: { flexDirection: 'row', alignItems: 'center', padding: 20, gap: 16 },
  cardIcon: { fontSize: 36 },
  cardTextContainer: { flex: 1 },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#fff',
    textShadowColor: 'rgba(0,0,0,0.2)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },
  cardSubtitle: { fontSize: 14, color: 'rgba(255,255,255,0.85)', marginTop: 4 },
  settingsPanel: {
    position: 'absolute',
    bottom: 40,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(0,0,0,0.95)',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    paddingTop: 10,
    paddingHorizontal: 12,
  },
  settingsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  settingsActions: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  settingsScroll: { flex: 1 },
  settingsTitle: { color: '#fff', fontSize: 16, fontWeight: '700' },
  sectionLabel: {
    color: 'rgba(255,255,255,0.4)',
    fontSize: 10,
    fontWeight: '600',
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 4,
    letterSpacing: 1,
  },
  swatchRow: {
    flexDirection: 'row',
    gap: 8,
    paddingVertical: 4,
  },
  swatch: {
    width: 28,
    height: 28,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  swatchSelected: {
    borderWidth: 2.5,
    borderColor: '#fff',
  },
  swatchHex: {
    color: 'rgba(255,255,255,0.5)',
    fontSize: 10,
    marginBottom: 2,
  },
  closeBtn: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: 'rgba(255,255,255,0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  closeBtnText: { color: '#fff', fontSize: 16 },
  resetBtn: {
    height: 28,
    borderRadius: 14,
    paddingHorizontal: 10,
    backgroundColor: 'rgba(255,255,255,0.12)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  resetBtnText: { color: '#fff', fontSize: 12, fontWeight: '700' },
  sliderRow: { marginBottom: 0 },
  sliderLabelRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  sliderLabel: { color: '#fff', fontSize: 11, fontWeight: '600' },
  sliderValue: { color: 'rgba(255,255,255,0.9)', fontSize: 11 },
  nativeSlider: { width: '100%', height: 24, marginTop: -2, marginBottom: -2 },
});
