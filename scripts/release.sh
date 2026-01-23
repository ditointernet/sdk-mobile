#!/bin/bash

# Script para release coordenado de todas as plataformas
# Uso: ./scripts/release.sh [version]

set -e

VERSION=${1:-"1.0.0"}

echo "📦 Releasing version $VERSION..."

# Verificar se estamos em um branch de release ou main
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "release" ]; then
    echo "⚠️  Warning: Not on main or release branch. Current branch: $CURRENT_BRANCH"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Atualizar versão no CHANGELOG
if [ -f "CHANGELOG.md" ]; then
    echo "📝 Updating CHANGELOG.md..."
    # O CHANGELOG deve ser atualizado manualmente antes do release
fi

# iOS: Atualizar versão no podspec
if [ -f "ios/DitoSDK.podspec" ]; then
    echo "🍎 Updating iOS podspec version..."
    sed -i.bak "s/s.version.*=.*/s.version = \"$VERSION\"/" ios/DitoSDK.podspec
    rm -f ios/DitoSDK.podspec.bak
fi

# Android: Atualizar versão no build.gradle
if [ -f "android/dito-sdk/build.gradle.kts" ]; then
    echo "🤖 Updating Android version..."
    sed -i.bak "s/versionName.*=.*/versionName = \"$VERSION\"/" android/dito-sdk/build.gradle.kts
    rm -f android/dito-sdk/build.gradle.kts.bak
fi

# Flutter: Atualizar versão no pubspec.yaml
if [ -f "flutter/pubspec.yaml" ]; then
    echo "🎯 Updating Flutter version..."
    sed -i.bak "s/^version:.*/version: $VERSION/" flutter/pubspec.yaml
    rm -f flutter/pubspec.yaml.bak
fi

# React Native: Atualizar versão no package.json
if [ -f "react-native/package.json" ]; then
    echo "⚛️  Updating React Native version..."
    # Usar node para atualizar o package.json de forma mais segura
    node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('react-native/package.json', 'utf8'));
        pkg.version = '$VERSION';
        fs.writeFileSync('react-native/package.json', JSON.stringify(pkg, null, 2) + '\n');
    "
fi

echo ""
echo "✅ Version $VERSION updated in all platforms!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git diff"
echo "2. Commit the changes: git add -A && git commit -m \"chore: bump version to $VERSION\""
echo "3. Create a tag: git tag -a v$VERSION -m \"Release version $VERSION\""
echo "4. Push changes: git push && git push --tags"
echo ""
echo "After pushing, publish to:"
echo "- iOS: cd ios && pod trunk push DitoSDK.podspec"
echo "- Flutter: cd flutter && flutter pub publish"
echo "- React Native: cd react-native && npm publish"
