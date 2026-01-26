#!/bin/bash

# Script para detectar quais projetos tiveram mudanças (excluindo apenas testes)
# Uso: ./scripts/detect-changes.sh [base_ref] [head_ref]
# Se não especificado, compara HEAD com a última tag

set -e

BASE_REF=${1:-""}
HEAD_REF=${2:-"HEAD"}

if [ -z "$BASE_REF" ]; then
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -z "$LAST_TAG" ]; then
        BASE_REF="HEAD~1"
    else
        BASE_REF="$LAST_TAG"
    fi
fi

CHANGED_PROJECTS=()
HAS_CHANGELOG=false

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    echo "Warning: Base reference '$BASE_REF' not found, checking all projects" >&2
    BASE_REF="HEAD~1"
fi

has_code_changes() {
    local project=$1
    local changed_files=$(git diff --name-only "$BASE_REF".."$HEAD_REF" | grep "^${project}/" || true)

    if [ -z "$changed_files" ]; then
        return 1
    fi

    local code_files=""
    case "$project" in
        ios)
            code_files=$(echo "$changed_files" | grep -vE "(Tests/|.*Test\.swift$|.*Tests\.swift$)" | grep -E "(\.(swift|m|h|plist|podspec|pbxproj|yml)$|/Podfile$|/project\.yml$)" || true)
            ;;
        android)
            code_files=$(echo "$changed_files" | grep -vE "(test/|androidTest/|.*Test\.kt$|.*Tests\.kt$)" | grep -E "\.(kt|java|xml|gradle|gradle\.kts|properties)$" || true)
            ;;
        flutter)
            code_files=$(echo "$changed_files" | grep -vE "(test/|.*_test\.dart$)" | grep -E "\.(dart|yaml|yml|json)$" || true)
            ;;
        react-native)
            code_files=$(echo "$changed_files" | grep -vE "(__tests__/|.*\.test\.(ts|tsx)$|.*\.spec\.(ts|tsx)$)" | grep -E "\.(ts|tsx|js|jsx|json)$" || true)
            ;;
        *)
            return 1
            ;;
    esac

    [ -n "$code_files" ] && return 0 || return 1
}

if has_code_changes "ios"; then
    CHANGED_PROJECTS+=("ios")
fi

if has_code_changes "android"; then
    CHANGED_PROJECTS+=("android")
fi

if has_code_changes "flutter"; then
    CHANGED_PROJECTS+=("flutter")
fi

if has_code_changes "react-native"; then
    CHANGED_PROJECTS+=("react-native")
fi

if git diff --name-only "$BASE_REF".."$HEAD_REF" | grep -q "^CHANGELOG.md"; then
    HAS_CHANGELOG=true
fi

if [ ${#CHANGED_PROJECTS[@]} -eq 0 ] && [ "$HAS_CHANGELOG" = false ]; then
    exit 0
fi

if [ "$HAS_CHANGELOG" = true ]; then
    echo "changelog"
fi

for project in "${CHANGED_PROJECTS[@]}"; do
    echo "$project"
done
