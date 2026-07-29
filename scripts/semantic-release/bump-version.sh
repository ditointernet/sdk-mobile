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
    for spec in ios/DitoSDK.podspec ios/DitoSDKNotificationService.podspec; do
      sed -i.bak -E "s/(s\\.version[[:space:]]*=[[:space:]]*')[^']+(')/\\1${version}\\2/" "$spec"
      sed -i.bak -E "s/(:tag[[:space:]]*=>[[:space:]]*')[^']+(' \\+ s\\.version\\.to_s)/\\1ios-v\\2/" "$spec"
      rm -f "$spec.bak"
    done
    ;;
  flutter)
    sed -i.bak -E "s/^version:[[:space:]]+.*/version: ${version}/" flutter/pubspec.yaml
    rm -f flutter/pubspec.yaml.bak
    ;;
  react-native)
    node -e "const fs=require('fs');const p='react-native/package.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));j.version='${version}';fs.writeFileSync(p,JSON.stringify(j,null,2)+'\\n');"
    ;;
  android)
    ;;
  *)
    exit 1
    ;;
esac

