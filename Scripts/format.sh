#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "swiftformat is not installed. Install it with: brew install swiftformat" >&2
  exit 127
fi

swiftformat "$ROOT_DIR/Source" --config "$ROOT_DIR/.swiftformat"
