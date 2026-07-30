#!/bin/bash

set -euo pipefail

project="${1:-}"
version="${2:-}"

if [ -z "$project" ] || [ -z "$version" ]; then
  exit 1
fi

case "$project" in
  ios)
    # Both podspecs must move together: DitoSDK depends on
    # DitoSDKNotificationService at an exact version, so a bump that touches only
    # one of them produces a dependency that was never published.
    for spec in DitoSDK.podspec DitoSDKNotificationService.podspec; do
      sed -i.bak -E "s/(s\\.version[[:space:]]*=[[:space:]]*')[^']+(')/\\1${version}\\2/" "$spec"
      sed -i.bak -E "s/(:tag[[:space:]]*=>[[:space:]]*')[^']+(' \\+ s\\.version\\.to_s)/\\1ios-v\\2/" "$spec"
      rm -f "$spec.bak"
    done
    # The Flutter plugin's floor moves with the SDK it wraps. It was left out of
    # this bump once already, and the result was a plugin asking trunk for a
    # DitoSDK version that existed nowhere — no `pod install` in the sample could
    # resolve. Only major.minor goes in the constraint, so a patch release of the
    # SDK does not need a plugin release to be installable.
    ios_rest="${version#*.}"
    sed -i.bak -E "s/(s\\.dependency 'DitoSDK', '~> )[^']+(')/\\1${version%%.*}.${ios_rest%%.*}\\2/" flutter/ios/dito_sdk.podspec
    rm -f flutter/ios/dito_sdk.podspec.bak
    ;;
  flutter)
    sed -i.bak -E "s/^version:[[:space:]]+.*/version: ${version}/" flutter/pubspec.yaml
    rm -f flutter/pubspec.yaml.bak
    # The plugin's iOS podspec carries the same version as the package.
    sed -i.bak -E "s/(s\\.version[[:space:]]*=[[:space:]]*')[^']+(')/\\1${version}\\2/" flutter/ios/dito_sdk.podspec
    rm -f flutter/ios/dito_sdk.podspec.bak
    ;;
  react-native)
    node -e "const fs=require('fs');const p='react-native/package.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));j.version='${version}';fs.writeFileSync(p,JSON.stringify(j,null,2)+'\\n');"
    ;;
  android)
    # A versão real vem de VERSION_NAME na publicação, mas o default no build script é o
    # que vale para quem compila do repositório — e é o número que o plugin Flutter fixa.
    # Ficar de fora deste bump é o que deixou o plugin pedindo `ditosdk:4.1.0`, versão que
    # não existia nem no Maven Central nem no repositório: nenhum `flutter build apk` do
    # sample resolvia.
    sed -i.bak -E "s/(^version = System\\.getenv\\(\"VERSION_NAME\"\\) \\?: \")[^\"]+(\")/\\1${version}\\2/" \
      android/dito-sdk/build.gradle.kts
    rm -f android/dito-sdk/build.gradle.kts.bak
    sed -i.bak -E "s/(DITO_ANDROID_SDK_VERSION\"\\) \\?: \")[^\"]+(\")/\\1${version}\\2/" \
      flutter/android/build.gradle
    rm -f flutter/android/build.gradle.bak
    ;;
  *)
    exit 1
    ;;
esac

