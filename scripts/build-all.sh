#!/bin/bash

# Script para build de todas as plataformas do monorepo Dito SDK
# Uso: ./scripts/build-all.sh

set -e

echo "🚀 Building all platforms..."

# iOS
if [ -d "ios" ]; then
    echo "📱 Building iOS SDK..."
    cd ios
    xcodebuild -workspace DitoSDK.xcworkspace -scheme DitoSDK -configuration Release
    cd ..
fi

# Android
if [ -d "android" ]; then
    echo "🤖 Building Android SDK..."
    cd android
    ./gradlew build
    cd ..
fi

# Flutter
if [ -d "flutter" ]; then
    echo "🎯 Building Flutter plugin..."
    cd flutter
    flutter pub get
    flutter test
    cd ..
fi

# React Native
if [ -d "react-native" ]; then
    echo "⚛️  Building React Native plugin..."
    cd react-native
    npm install
    npm test
    cd ..
fi

echo "✅ All platforms built successfully!"
