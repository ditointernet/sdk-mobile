#!/bin/bash

set -euo pipefail

project_dir="${1:-}"
tag_prefix="${2:-}"

if [ -z "$project_dir" ] || [ -z "$tag_prefix" ]; then
  exit 0
fi

last_tag="$(git tag --merged HEAD --list "${tag_prefix}v*" --sort=-v:refname | head -n 1 || true)"
if [ -z "$last_tag" ]; then
  exit 0
fi

subjects="$(git log "${last_tag}..HEAD" --format='%s' -- "$project_dir" 2>/dev/null || true)"
if [ -z "$subjects" ]; then
  exit 0
fi

bodies="$(git log "${last_tag}..HEAD" --format='%B%n' -- "$project_dir" 2>/dev/null || true)"

if printf "%s\n" "$subjects" | grep -Eq '^[a-zA-Z]+(\([^)]+\))?!:'; then
  echo major
  exit 0
fi

if printf "%s\n" "$bodies" | grep -Eq 'BREAKING CHANGE(S)?:'; then
  echo major
  exit 0
fi

if printf "%s\n" "$subjects" | grep -Eq '^feat(\([^)]+\))?: '; then
  echo minor
  exit 0
fi

echo patch

