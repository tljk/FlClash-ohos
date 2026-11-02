#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TOOL_CACHE:?RUNNER_TOOL_CACHE must be set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$RUNNER_TOOL_CACHE"

download_and_patch() {
  local name="$1"
  local version="$2"
  local sha256="$3"
  local archive="$RUNNER_TOOL_CACHE/$name-$version.tar.gz"
  local target="$GITHUB_WORKSPACE/../$name"

  if [[ ! -f "$archive" ]]; then
    curl --fail --location --silent --show-error --retry 3 \
      "https://pub.dev/api/archives/$name-$version.tar.gz" \
      --output "$archive"
  fi
  printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c
  rm -rf -- "$target"
  mkdir "$target"
  tar -xzf "$archive" -C "$target"
  patch --directory="$target" --strip=1 --batch --forward \
    < "$script_dir/${name}_ohos.patch"
}

download_and_patch \
  material_ui \
  1.8.0 \
  e4031746f96c8316864d9b92bce375f1320a36ed56e166307e1e1bda9d90b4ab
download_and_patch \
  cupertino_ui \
  1.1.4 \
  a47c4e7c66fd7444a063a602597fceb238f705c3f6b1322bc0053d0a2638ee6e
