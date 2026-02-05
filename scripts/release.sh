#!/bin/bash
set -euo pipefail

target="${1:-all}"

if [ "$target" = "--publish" ]; then
  echo "Error: publishing is handled by tag-based CI workflows" >&2
  exit 1
fi

android_version="$(sed -nE 's/^version[[:space:]]*=.*\\?:[[:space:]]*"([^"]+)".*/\1/p' android/dito-sdk/build.gradle.kts | head -n 1)"
ios_version="$(sed -nE "s/.*s\\.version[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/p" ios/DitoSDK.podspec | head -n 1)"
flutter_version="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' flutter/pubspec.yaml | head -n 1)"
rn_version="$(node -e "const j=require('./react-native/package.json');process.stdout.write(j.version)")"

ensure_tag() {
  local prefix="$1"
  local version="$2"
  if ! printf "%s" "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'; then
    echo "Invalid version for ${prefix}: '${version}'" >&2
    exit 1
  fi
  if git tag --list "${prefix}v*" | grep -Eq "^${prefix}v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$"; then
    return 0
  fi
  git tag -a "${prefix}v${version}" -m "chore: baseline ${prefix}v${version}"
}

ensure_tag "android-" "$android_version"
ensure_tag "ios-" "$ios_version"
ensure_tag "flutter-" "$flutter_version"
ensure_tag "react-native-" "$rn_version"

run_semantic_release() {
  local config="$1"
  npx -y \
    -p semantic-release \
    -p @semantic-release/changelog \
    -p @semantic-release/exec \
    -p @semantic-release/git \
    semantic-release --config "$config"
}

case "$target" in
  android)
    run_semantic_release ".github/semantic-release/android.release.config.cjs"
    ;;
  ios)
    run_semantic_release ".github/semantic-release/ios.release.config.cjs"
    ;;
  flutter)
    run_semantic_release ".github/semantic-release/flutter.release.config.cjs"
    ;;
  react-native)
    run_semantic_release ".github/semantic-release/react-native.release.config.cjs"
    ;;
  all)
    run_semantic_release ".github/semantic-release/android.release.config.cjs"
    run_semantic_release ".github/semantic-release/ios.release.config.cjs"
    run_semantic_release ".github/semantic-release/flutter.release.config.cjs"
    run_semantic_release ".github/semantic-release/react-native.release.config.cjs"
    ;;
  *)
    echo "Usage: $0 [android|ios|flutter|react-native|all]" >&2
    exit 1
    ;;
esac
