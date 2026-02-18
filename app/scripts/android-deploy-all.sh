#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/android"
APK_PATH="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
APP_ID="com.liquidglass.demo"

is_metro_running() {
  local status
  status="$(curl -fsS "http://127.0.0.1:8081/status" 2>/dev/null || true)"
  [[ "$status" == *"packager-status:running"* ]]
}

ensure_metro() {
  if is_metro_running; then
    echo "Metro is already running on :8081"
    return
  fi

  echo "Starting Metro on :8081..."
  mkdir -p "$ROOT_DIR/.expo"
  nohup npx expo start --dev-client --port 8081 --host localhost \
    >"$ROOT_DIR/.expo/metro-deploy.log" 2>&1 &

  for ((i = 0; i < 40; i += 1)); do
    sleep 0.5
    if is_metro_running; then
      echo "Metro is ready."
      return
    fi
  done

  echo "Metro has not reported ready status yet."
  echo "Check logs: $ROOT_DIR/.expo/metro-deploy.log"
}

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is not available in PATH."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not available in PATH."
  exit 1
fi

ensure_metro

echo "Building debug APK..."
(cd "$ANDROID_DIR" && ./gradlew :app:assembleDebug -x lint -x test)

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found at: $APK_PATH"
  exit 1
fi

DEVICES="$(adb devices | awk 'NR>1 && $2=="device"{print $1}')"

if [[ -z "$DEVICES" ]]; then
  echo "No active adb devices found."
  exit 1
fi

while IFS= read -r device; do
  [[ -z "$device" ]] && continue
  echo "Reverse 8081 on $device..."
  adb -s "$device" reverse tcp:8081 tcp:8081 >/dev/null 2>&1 || true
  echo "Installing on $device..."
  adb -s "$device" install -r -d "$APK_PATH" </dev/null
  echo "Launching on $device..."
  adb -s "$device" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null </dev/null
done <<< "$DEVICES"

echo "Done."
