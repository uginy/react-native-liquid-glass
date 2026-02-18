const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

const modulesDir = path.resolve(__dirname, '..', 'modules', 'liquid-glass');

// Watch the module source directory for changes
config.watchFolders = [modulesDir];

// Ensure the module resolves react/react-native from the app's node_modules
// to prevent duplicate React instances
config.resolver.nodeModulesPaths = [
  path.resolve(__dirname, 'node_modules'),
];

// Block the module's node_modules from resolving react/react-native
config.resolver.blockList = [
  new RegExp(path.resolve(modulesDir, 'node_modules', 'react-native', '.*').replace(/[/\\]/g, '[/\\\\]')),
  new RegExp(path.resolve(modulesDir, 'node_modules', 'react', '.*').replace(/[/\\]/g, '[/\\\\]')),
];

module.exports = config;
