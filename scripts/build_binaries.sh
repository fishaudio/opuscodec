#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/bin}"
TARGET_NAME="${2:-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)}"
PREFIX="${OPUSCODEC_BIN_DEPS_PREFIX:-$ROOT_DIR/build/deps/$TARGET_NAME}"

mkdir -p "$OUTPUT_DIR/$TARGET_NAME"

OPUSCODEC_WITH_OPUS_TOOLS=1 OPUSCODEC_ENABLE_QEXT="${OPUSCODEC_ENABLE_QEXT:-1}" \
  bash "$ROOT_DIR/scripts/build_deps.sh" "$PREFIX"

cp "$PREFIX/bin/opusenc" "$OUTPUT_DIR/$TARGET_NAME/opusenc"
cp "$PREFIX/bin/opusdec" "$OUTPUT_DIR/$TARGET_NAME/opusdec"
cp "$PREFIX/.versions" "$OUTPUT_DIR/$TARGET_NAME/versions.txt"

chmod +x "$OUTPUT_DIR/$TARGET_NAME/opusenc" "$OUTPUT_DIR/$TARGET_NAME/opusdec"

echo "Built binaries in $OUTPUT_DIR/$TARGET_NAME"
if [[ "$(uname -s)" == "Darwin" ]]; then
  otool -L "$OUTPUT_DIR/$TARGET_NAME/opusenc" || true
  otool -L "$OUTPUT_DIR/$TARGET_NAME/opusdec" || true
else
  ldd "$OUTPUT_DIR/$TARGET_NAME/opusenc" || true
  ldd "$OUTPUT_DIR/$TARGET_NAME/opusdec" || true
fi
