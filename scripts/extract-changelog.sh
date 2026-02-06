#!/bin/bash

# Script para extrair versão e notas do CHANGELOG.md
# Uso: ./scripts/extract-changelog.sh [changelog_file]
# Retorna: versão na primeira linha, conteúdo do changelog nas linhas seguintes

set -euo pipefail

CHANGELOG_FILE=${1:-"CHANGELOG.md"}

project_dir="$(dirname "$CHANGELOG_FILE")"
project_name="$(basename "$project_dir")"

tag_prefix=""
case "$project_name" in
  android|flutter|ios)
    tag_prefix="${project_name}-"
    ;;
  react-native)
    tag_prefix="react-native-"
    ;;
esac

current_tag=""
if [ -n "$tag_prefix" ]; then
  current_tag="$(git tag --merged HEAD --list "${tag_prefix}v*" --sort=-v:refname | sed -n '1p' || true)"
fi

previous_tag=""
if [ -n "$tag_prefix" ] && [ -n "$current_tag" ]; then
  previous_tag="$(git describe --tags --abbrev=0 --match "${tag_prefix}v*" "${current_tag}^" 2>/dev/null || true)"
fi

VERSION_LINE=""
if [ -f "$CHANGELOG_FILE" ]; then
  VERSION_LINE="$(grep -m 1 "^## \\[" "$CHANGELOG_FILE" || true)"
fi

VERSION=""
if [ -n "$VERSION_LINE" ]; then
  VERSION="$(printf "%s" "$VERSION_LINE" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | sed -n '1p' || true)"
fi

if [ -z "$VERSION" ] && [ -n "$tag_prefix" ] && [ -n "$current_tag" ]; then
  VERSION="${current_tag#${tag_prefix}v}"
fi

if [ -z "$VERSION" ]; then
  echo "Error: Could not determine version" >&2
  exit 1
fi

echo "$VERSION"

if [ -f "$CHANGELOG_FILE" ] && [ -n "$VERSION_LINE" ]; then
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
  exit 0
fi

range=""
if [ -n "$previous_tag" ] && [ -n "$current_tag" ]; then
  range="${previous_tag}..${current_tag}"
elif [ -n "$current_tag" ]; then
  range="${current_tag}"
fi

lines="$(git log ${range:+$range} --format='%h %s' --no-merges -- "$project_dir" 2>/dev/null || true)"
if [ -z "$lines" ]; then
  printf "### Mudanças\n\n- Sem mudanças relevantes desde a última release.\n"
  exit 0
fi

breaking="$(printf "%s\n" "$lines" | grep -E '^[0-9a-f]+ [a-zA-Z]+(\([^)]+\))?!:' || true)"
features="$(printf "%s\n" "$lines" | grep -E '^[0-9a-f]+ feat(\([^)]+\))?: ' || true)"
fixes="$(printf "%s\n" "$lines" | grep -E '^[0-9a-f]+ fix(\([^)]+\))?: ' || true)"
others="$(printf "%s\n" "$lines" | grep -Ev '^[0-9a-f]+ (feat|fix)(\([^)]+\))?: ' | grep -Ev '^[0-9a-f]+ [a-zA-Z]+(\([^)]+\))?!:' || true)"

emit_section() {
  local title="$1"
  local content="$2"
  if [ -z "$content" ]; then
    return 0
  fi
  printf "### %s\n\n" "$title"
  printf "%s\n" "$content" | sed -E 's/^([0-9a-f]+) (.*)$/- \2 (\1)/'
  printf "\n"
}

emit_section "Quebras" "$breaking"
emit_section "Funcionalidades" "$features"
emit_section "Correções" "$fixes"
emit_section "Outros" "$others"
