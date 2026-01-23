#!/bin/bash

# Script para release coordenado de todas as plataformas
# Uso: ./scripts/release.sh [version] [--publish]

set -e

VERSION=${1:-""}
PUBLISH=${2:-""}

if [ -z "$VERSION" ]; then
    if [ -f "CHANGELOG.md" ]; then
        VERSION=$(./scripts/extract-changelog.sh | head -n 1)
        if [ -z "$VERSION" ]; then
            echo "Error: Could not extract version from CHANGELOG.md" >&2
            exit 1
        fi
        echo "📝 Extracted version $VERSION from CHANGELOG.md"
    else
        echo "Error: No version provided and CHANGELOG.md not found" >&2
        exit 1
    fi
fi

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

# Detectar quais projetos tiveram mudanças
echo "🔍 Detecting changes..."
CHANGED_PROJECTS=$(./scripts/detect-changes.sh)
HAS_CHANGELOG=false
HAS_IOS=false
HAS_ANDROID=false
HAS_FLUTTER=false
HAS_REACT_NATIVE=false

if echo "$CHANGED_PROJECTS" | grep -q "^changelog$"; then
    HAS_CHANGELOG=true
fi
if echo "$CHANGED_PROJECTS" | grep -q "^ios$"; then
    HAS_IOS=true
fi
if echo "$CHANGED_PROJECTS" | grep -q "^android$"; then
    HAS_ANDROID=true
fi
if echo "$CHANGED_PROJECTS" | grep -q "^flutter$"; then
    HAS_FLUTTER=true
fi
if echo "$CHANGED_PROJECTS" | grep -q "^react-native$"; then
    HAS_REACT_NATIVE=true
fi

if [ "$HAS_CHANGELOG" = false ] && [ "$HAS_IOS" = false ] && [ "$HAS_ANDROID" = false ] && [ "$HAS_FLUTTER" = false ] && [ "$HAS_REACT_NATIVE" = false ]; then
    echo "⚠️  No changes detected in any project"
    exit 0
fi

echo "📋 Changed projects:"
[ "$HAS_CHANGELOG" = true ] && echo "  - CHANGELOG.md"
[ "$HAS_IOS" = true ] && echo "  - iOS"
[ "$HAS_ANDROID" = true ] && echo "  - Android"
[ "$HAS_FLUTTER" = true ] && echo "  - Flutter"
[ "$HAS_REACT_NATIVE" = true ] && echo "  - React Native"

# Atualizar versão apenas nos projetos que mudaram
if [ "$HAS_IOS" = true ] && [ -f "ios/DitoSDK.podspec" ]; then
    echo "🍎 Updating iOS podspec version..."
    sed -i.bak "s/s.version.*=.*/s.version = \"$VERSION\"/" ios/DitoSDK.podspec
    rm -f ios/DitoSDK.podspec.bak
fi

if [ "$HAS_ANDROID" = true ] && [ -f "android/dito-sdk/build.gradle.kts" ]; then
    echo "🤖 Updating Android version..."
    sed -i.bak "s/versionName.*=.*/versionName = \"$VERSION\"/" android/dito-sdk/build.gradle.kts
    rm -f android/dito-sdk/build.gradle.kts.bak
fi

if [ "$HAS_FLUTTER" = true ] && [ -f "flutter/pubspec.yaml" ]; then
    echo "🎯 Updating Flutter version..."
    sed -i.bak "s/^version:.*/version: $VERSION/" flutter/pubspec.yaml
    rm -f flutter/pubspec.yaml.bak
fi

if [ "$HAS_REACT_NATIVE" = true ] && [ -f "react-native/package.json" ]; then
    echo "⚛️  Updating React Native version..."
    node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('react-native/package.json', 'utf8'));
        pkg.version = '$VERSION';
        fs.writeFileSync('react-native/package.json', JSON.stringify(pkg, null, 2) + '\n');
    "
fi

echo ""
echo "✅ Version $VERSION updated in changed projects!"
echo ""

# Publicar se solicitado
if [ "$PUBLISH" = "--publish" ]; then
    echo "📤 Publishing packages..."
    PUBLISH_ARGS=()
    [ "$HAS_IOS" = true ] && PUBLISH_ARGS+=("ios")
    [ "$HAS_ANDROID" = true ] && PUBLISH_ARGS+=("android")
    [ "$HAS_FLUTTER" = true ] && PUBLISH_ARGS+=("flutter")
    [ "$HAS_REACT_NATIVE" = true ] && PUBLISH_ARGS+=("react-native")

    if [ ${#PUBLISH_ARGS[@]} -gt 0 ]; then
        ./scripts/publish-all.sh "${PUBLISH_ARGS[@]}"
    else
        echo "No projects to publish"
    fi
else
    echo "Next steps:"
    echo "1. Review the changes: git diff"
    echo "2. Commit the changes: git add -A && git commit -m \"chore: bump version to $VERSION\""
    echo "3. Create a tag: git tag -a v$VERSION -m \"Release version $VERSION\""
    echo "4. Push changes: git push && git push --tags"
    echo ""
    echo "To publish packages, run:"
    PUBLISH_ARGS=()
    [ "$HAS_IOS" = true ] && PUBLISH_ARGS+=("ios")
    [ "$HAS_ANDROID" = true ] && PUBLISH_ARGS+=("android")
    [ "$HAS_FLUTTER" = true ] && PUBLISH_ARGS+=("flutter")
    [ "$HAS_REACT_NATIVE" = true ] && PUBLISH_ARGS+=("react-native")

    if [ ${#PUBLISH_ARGS[@]} -gt 0 ]; then
        echo "  ./scripts/release.sh $VERSION --publish"
        echo ""
        echo "Or publish individually:"
        [ "$HAS_IOS" = true ] && echo "  ./scripts/publish-all.sh ios"
        [ "$HAS_ANDROID" = true ] && echo "  ./scripts/publish-all.sh android"
        [ "$HAS_FLUTTER" = true ] && echo "  ./scripts/publish-all.sh flutter"
        [ "$HAS_REACT_NATIVE" = true ] && echo "  ./scripts/publish-all.sh react-native"
    fi
fi
