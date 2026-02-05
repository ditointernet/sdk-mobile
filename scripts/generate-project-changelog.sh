#!/bin/bash

set -euo pipefail

project_dir="${1:-}"
version="${2:-}"
output_file="${3:-}"

if [ -z "$project_dir" ] || [ -z "$version" ]; then
  echo "Usage: $0 <project_dir> <version> [output_file]" >&2
  exit 1
fi

if [ ! -d "$project_dir" ]; then
  echo "Error: project_dir not found: $project_dir" >&2
  exit 1
fi

if [ -z "$output_file" ]; then
  output_file="${project_dir%/}/CHANGELOG.md"
fi

git fetch --tags origin >/dev/null 2>&1 || true

version_tag="v$version"
base_tag=""
if git rev-parse -q --verify "$version_tag" >/dev/null 2>&1; then
  base_tag="$(git describe --tags --abbrev=0 --match "v*" "${version_tag}^" 2>/dev/null || true)"
else
  base_tag="$(git describe --tags --abbrev=0 --match "v*" 2>/dev/null || true)"
fi

if [ -n "$base_tag" ]; then
  range="${base_tag}..HEAD"
else
  range=""
fi

subjects="$(git log ${range:+$range} --pretty=format:'%s' --no-merges -- "$project_dir" 2>/dev/null || true)"
if [ -z "$subjects" ]; then
  subjects="$(git log ${range:+$range} --pretty=format:'%s' -- "$project_dir" 2>/dev/null || true)"
fi

if [ -z "$subjects" ]; then
  bullets="- Sem mudanças relevantes desde a última release."
else
  bullets="$(printf "%s\n" "$subjects" | sed 's/^/- /')"
fi

date_str="$(date -u +%Y-%m-%d)"

section="$(cat <<EOF
## [$version] - $date_str

### Mudanças
$bullets

EOF
)"

tmp="$(mktemp)"

if [ -f "$output_file" ]; then
  filtered="$(mktemp)"
  awk -v ver="## [$version]" '
    BEGIN { skipping = 0 }
    $0 == ver { skipping = 1; next }
    skipping && /^## \[/ { skipping = 0 }
    !skipping { print }
  ' "$output_file" > "$filtered"

  header="$(mktemp)"
  rest="$(mktemp)"
  awk 'BEGIN{p=1} /^## \[/{p=0} p{print}' "$filtered" > "$header"
  awk 'BEGIN{p=0} /^## \[/{p=1} p{print}' "$filtered" > "$rest"

  cat "$header" > "$tmp"
  printf "\n%s" "$section" >> "$tmp"
  if [ -s "$rest" ]; then
    printf "\n" >> "$tmp"
    cat "$rest" >> "$tmp"
  fi

  rm -f "$filtered" "$header" "$rest"
else
  cat > "$tmp" <<EOF
# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

$section
EOF
fi

mkdir -p "$(dirname "$output_file")"
mv "$tmp" "$output_file"
