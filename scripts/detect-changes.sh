#!/bin/bash

# Script para detectar quais projetos tiveram mudanças
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

if git diff --name-only "$BASE_REF".."$HEAD_REF" | grep -q "^ios/"; then
    CHANGED_PROJECTS+=("ios")
fi

if git diff --name-only "$BASE_REF".."$HEAD_REF" | grep -q "^android/"; then
    CHANGED_PROJECTS+=("android")
fi

if git diff --name-only "$BASE_REF".."$HEAD_REF" | grep -q "^flutter/"; then
    CHANGED_PROJECTS+=("flutter")
fi

if git diff --name-only "$BASE_REF".."$HEAD_REF" | grep -q "^react-native/"; then
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
