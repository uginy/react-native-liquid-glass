const { withAndroidManifest } = require('expo/config-plugins');

module.exports = function withDisablePointerTagging(config) {
  return withAndroidManifest(config, async (config) => {
    const manifest = config.modResults;
    const app = manifest.manifest.application?.[0];
    if (app) {
      app.$['android:allowNativeHeapPointerTagging'] = 'false';
    }
    return config;
  });
};
