#!/bin/bash

set -euo pipefail

project_dir="${1:-}"
tag_prefix="${2:-}"

if [ -z "$project_dir" ] || [ -z "$tag_prefix" ]; then
  exit 0
fi

last_tag="$(git tag --list "${tag_prefix}v*" --sort=-v:refname | head -n 1 || true)"
if [ -z "$last_tag" ]; then
  exit 0
fi

lines="$(git log "${last_tag}..HEAD" --format='%h %s' -- "$project_dir" 2>/dev/null || true)"
if [ -z "$lines" ]; then
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

