#!/bin/bash

set -euo pipefail

project="${1:-}"
version="${2:-}"

if [ -z "$project" ] || [ -z "$version" ]; then
  exit 1
fi

case "$project" in
  ios)
    sed -i.bak -E "s/(s\\.version[[:space:]]*=[[:space:]]*')[^']+(')/\\1${version}\\2/" ios/DitoSDK.podspec
    sed -i.bak -E "s/(:tag[[:space:]]*=>[[:space:]]*')[^']+(' \\+ s\\.version\\.to_s)/\\1ios-v\\2/" ios/DitoSDK.podspec
    rm -f ios/DitoSDK.podspec.bak
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

