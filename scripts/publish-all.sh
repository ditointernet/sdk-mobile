#!/bin/bash

# Script para publicar nos repositórios de pacotes
# Uso: ./scripts/publish-all.sh [ios] [android] [flutter] [react-native]
# Exemplo: ./scripts/publish-all.sh ios flutter

set -e

PUBLISH_IOS=false
PUBLISH_ANDROID=false
PUBLISH_FLUTTER=false
PUBLISH_REACT_NATIVE=false

for arg in "$@"; do
    case "$arg" in
        ios)
            PUBLISH_IOS=true
            ;;
        android)
            PUBLISH_ANDROID=true
            ;;
        flutter)
            PUBLISH_FLUTTER=true
            ;;
        react-native)
            PUBLISH_REACT_NATIVE=true
            ;;
        *)
            echo "Warning: Unknown project '$arg', ignoring" >&2
            ;;
    esac
done

if [ "$PUBLISH_IOS" = false ] && [ "$PUBLISH_ANDROID" = false ] && [ "$PUBLISH_FLUTTER" = false ] && [ "$PUBLISH_REACT_NATIVE" = false ]; then
    echo "No projects specified for publishing"
    exit 0
fi

FAILED_PROJECTS=()
SUCCESSFUL_PROJECTS=()

if [ "$PUBLISH_IOS" = true ]; then
    echo "🍎 Publishing iOS SDK to CocoaPods..."
    if [ -z "$COCOAPODS_TRUNK_TOKEN" ]; then
        echo "Error: COCOAPODS_TRUNK_TOKEN not set" >&2
        FAILED_PROJECTS+=("ios")
    else
        cd ios
        if pod trunk push DitoSDK.podspec --allow-warnings; then
            SUCCESSFUL_PROJECTS+=("ios")
            echo "✅ iOS SDK published successfully"
        else
            FAILED_PROJECTS+=("ios")
            echo "❌ Failed to publish iOS SDK"
        fi
        cd ..
    fi
fi

if [ "$PUBLISH_ANDROID" = true ]; then
    echo "🤖 Publishing Android SDK to Maven..."
    cd android
    export VERSION_NAME="${VERSION_NAME:-3.0.1}"
    export PUBLISH_TARGET="${PUBLISH_TARGET:-central}"
    if [ "$PUBLISH_TARGET" = "central" ]; then
        if [ -z "$SONATYPE_USERNAME" ] || [ -z "$SONATYPE_PASSWORD" ]; then
            if [ -n "$MAVEN_CENTRAL" ]; then
                SONATYPE_USERNAME=$(printf "%s" "$MAVEN_CENTRAL" | sed -n 's/.*<username>\(.*\)<\/username>.*/\1/p' | head -n 1)
                SONATYPE_PASSWORD=$(printf "%s" "$MAVEN_CENTRAL" | sed -n 's/.*<password>\(.*\)<\/password>.*/\1/p' | head -n 1)
                export SONATYPE_USERNAME
                export SONATYPE_PASSWORD
            fi
        fi
        if [ -z "$SONATYPE_USERNAME" ] || [ -z "$SONATYPE_PASSWORD" ] || [ -z "$SIGNING_KEY" ] || [ -z "$SIGNING_PASSWORD" ]; then
            echo "Error: SONATYPE_USERNAME, SONATYPE_PASSWORD, SIGNING_KEY, SIGNING_PASSWORD must be set" >&2
            FAILED_PROJECTS+=("android")
            cd ..
        else
            if ./gradlew :dito-sdk:publish --exclude-task test --exclude-task check --exclude-task lint; then
                CENTRAL_NAMESPACE="${CENTRAL_NAMESPACE:-br.com.dito}"
                CENTRAL_BEARER=$(printf "%s" "${SONATYPE_USERNAME}:${SONATYPE_PASSWORD}" | base64 | tr -d '\n')
                if curl --fail -sS -X POST \
                    -H "Authorization: Bearer ${CENTRAL_BEARER}" \
                    "https://ossrh-staging-api.central.sonatype.com/manual/upload/defaultRepository/${CENTRAL_NAMESPACE}?publishing_type=automatic"; then
                    SUCCESSFUL_PROJECTS+=("android")
                    echo "✅ Android SDK published successfully"
                    echo "📦 Published: br.com.dito:ditosdk:${VERSION_NAME}"
                    echo "🔗 Repository: https://central.sonatype.com"
                else
                    FAILED_PROJECTS+=("android")
                    echo "❌ Failed to upload deployment to Central Portal"
                fi
            else
                FAILED_PROJECTS+=("android")
                echo "❌ Failed to publish Android SDK"
            fi
            cd ..
        fi
    else
        export GITHUB_TOKEN="${GITHUB_TOKEN:-}"
        export GITHUB_ACTOR="${GITHUB_ACTOR:-}"
        if ./gradlew :dito-sdk:publish --exclude-task test --exclude-task check --exclude-task lint; then
            SUCCESSFUL_PROJECTS+=("android")
            echo "✅ Android SDK published successfully"
            echo "📦 Published: br.com.dito:ditosdk:${VERSION_NAME}"
            echo "🔗 Repository: https://github.com/ditointernet/sdk-mobile/packages"
        else
            FAILED_PROJECTS+=("android")
            echo "❌ Failed to publish Android SDK"
        fi
        cd ..
    fi
fi

if [ "$PUBLISH_FLUTTER" = true ]; then
    echo "🎯 Publishing Flutter plugin to pub.dev..."
    if [ -z "$PUB_CREDENTIALS" ]; then
        echo "Error: PUB_CREDENTIALS not set" >&2
        FAILED_PROJECTS+=("flutter")
    else
        cd flutter
        if flutter pub publish --dry-run; then
            echo "Dry run successful, publishing..."
            if flutter pub publish --force; then
                SUCCESSFUL_PROJECTS+=("flutter")
                echo "✅ Flutter plugin published successfully"
            else
                FAILED_PROJECTS+=("flutter")
                echo "❌ Failed to publish Flutter plugin"
            fi
        else
            FAILED_PROJECTS+=("flutter")
            echo "❌ Flutter plugin dry run failed"
        fi
        cd ..
    fi
fi

if [ "$PUBLISH_REACT_NATIVE" = true ]; then
    echo "⚛️  Publishing React Native plugin to npm..."
    if [ -z "$NPM_TOKEN" ]; then
        echo "Error: NPM_TOKEN not set" >&2
        FAILED_PROJECTS+=("react-native")
    else
        cd react-native
        echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc
        if npm publish --access public; then
            SUCCESSFUL_PROJECTS+=("react-native")
            echo "✅ React Native plugin published successfully"
            rm -f .npmrc
        else
            FAILED_PROJECTS+=("react-native")
            echo "❌ Failed to publish React Native plugin"
            rm -f .npmrc
        fi
        cd ..
    fi
fi

echo ""
if [ ${#SUCCESSFUL_PROJECTS[@]} -gt 0 ]; then
    echo "✅ Successfully published: ${SUCCESSFUL_PROJECTS[*]}"
fi

if [ ${#FAILED_PROJECTS[@]} -gt 0 ]; then
    echo "❌ Failed to publish: ${FAILED_PROJECTS[*]}"
    exit 1
fi

echo "✅ All specified projects published successfully"
