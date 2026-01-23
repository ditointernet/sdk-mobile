#!/bin/bash

# Script para extrair versão e notas do CHANGELOG.md
# Uso: ./scripts/extract-changelog.sh [changelog_file]
# Retorna: versão na primeira linha, conteúdo do changelog nas linhas seguintes

set -e

CHANGELOG_FILE=${1:-"CHANGELOG.md"}

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Error: CHANGELOG.md not found" >&2
    exit 1
fi

VERSION_LINE=$(grep -m 1 "^## \[" "$CHANGELOG_FILE" || echo "")

if [ -z "$VERSION_LINE" ]; then
    echo "Error: No version found in CHANGELOG.md" >&2
    exit 1
fi

VERSION=$(echo "$VERSION_LINE" | sed -n 's/^## \[\([0-9]\+\.[0-9]\+\.[0-9]\+\)\].*/\1/p')

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from CHANGELOG.md" >&2
    exit 1
fi

echo "$VERSION"

awk '
/^## \[/ {
    if (found) exit
    found = 1
    print
    next
}
found {
    if (/^## \[/) exit
    print
}
' "$CHANGELOG_FILE"
