#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:-$(pwd)/build/deps/local}"
bash scripts/build_deps.sh "$PREFIX"
echo "Dependencies installed to: $PREFIX"
