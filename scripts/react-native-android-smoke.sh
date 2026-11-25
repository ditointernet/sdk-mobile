#!/bin/bash
#
# Cria um app React Native limpo, instala o pacote como sai do `npm pack` e compila o Android.
# Uso: scripts/react-native-android-smoke.sh <diretório de trabalho vazio>

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$1"
work="$(cd "$1" && pwd)"
cd "$work"

tarball="$(cd "$repo/react-native" && npm pack --pack-destination "$work" --silent | tail -n 1)"

npx --yes @react-native-community/cli@15.1.3 init DitoSmoke \
  --version 0.76.9 --skip-git-init --install-pods false --pm npm
cd DitoSmoke

npm install "$work/$tarball"

# O template do RN 0.76 vem com minSdk 24 e Kotlin 1.9 (versão do plugin vinda do RN); a SDK
# Android exige minSdk 26 e traz kotlin-stdlib 2.1, que o compilador 1.9 não lê. São os ajustes
# que o README pede ao app.
sed -i -E -e 's/minSdkVersion = [0-9]+/minSdkVersion = 26/' \
  -e 's/kotlinVersion = "[^"]+"/kotlinVersion = "2.0.21"/' \
  -e 's/"org\.jetbrains\.kotlin:kotlin-gradle-plugin"/"org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion"/' \
  android/build.gradle
grep -q 'minSdkVersion = 26' android/build.gradle
grep -q 'kotlin-gradle-plugin:\$kotlinVersion' android/build.gradle

cat > App.tsx <<'APP'
import React, { useEffect } from 'react';
import { Text } from 'react-native';
import DitoSdk from '@ditointernet/dito-sdk';

export default function App() {
  useEffect(() => {
    (async () => {
      await DitoSdk.initialize({ apiKey: 'key', apiSecret: 'secret' });
      await DitoSdk.track({ action: 'smoke', data: { ok: true } });
      await DitoSdk.registerDeviceToken('token');
    })().catch(() => {});
  }, []);
  return <Text>Dito smoke</Text>;
}
APP

module=node_modules/@ditointernet/dito-sdk/android/src/main/java/br/com/dito/DitoSdkModule.kt
for method in initialize track registerDeviceToken; do
  grep -A1 '@ReactMethod' "$module" | grep -qE "fun $method\\(" || { echo "❌ @ReactMethod $method ausente em $module" >&2; exit 1; }
done

npx tsc --noEmit
npx react-native bundle --platform android --dev false --entry-file index.js \
  --bundle-output "$work/index.android.bundle"

cd android
./gradlew assembleDebug -PreactNativeArchitectures=x86_64 --no-daemon
