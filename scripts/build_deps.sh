#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <install-prefix>"
  exit 1
fi

PREFIX="$1"
mkdir -p "$(dirname "$PREFIX")"
PREFIX="$(cd "$(dirname "$PREFIX")" && pwd)/$(basename "$PREFIX")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${OPUSCODEC_BUILD_ROOT:-$ROOT_DIR/build/third_party}"
SRC_ROOT="$BUILD_ROOT/src"
WORK_ROOT="$BUILD_ROOT/work"

mkdir -p "$PREFIX" "$SRC_ROOT" "$WORK_ROOT"

if command -v nproc >/dev/null 2>&1; then
  JOBS="$(nproc)"
elif command -v sysctl >/dev/null 2>&1; then
  JOBS="$(sysctl -n hw.ncpu)"
else
  JOBS=4
fi

log() {
  printf '[build_deps] %s\n' "$*"
}

OPUS_VERSION="${OPUS_VERSION:-1.6.1}"
OPUS_TOOLS_VERSION="${OPUS_TOOLS_VERSION:-0.2}"
LIBOGG_VERSION="${LIBOGG_VERSION:-1.3.6}"
OPUSFILE_VERSION="${OPUSFILE_VERSION:-0.12}"
LIBOPUSENC_VERSION="${LIBOPUSENC_VERSION:-0.3}"
ENABLE_QEXT="${OPUSCODEC_ENABLE_QEXT:-1}"
WITH_OPUS_TOOLS="${OPUSCODEC_WITH_OPUS_TOOLS:-0}"
DEPS_PATCH_LEVEL="${OPUSCODEC_DEPS_PATCH_LEVEL:-20260303}"

if [[ -f "$PREFIX/.versions" ]]; then
  read_version() {
    local key="$1"
    awk -F '=' -v k="$key" '$1 == k {print $2}' "$PREFIX/.versions" | tail -n 1
  }

  if [[ "$(read_version libogg)" != "$LIBOGG_VERSION" \
      || "$(read_version opus)" != "$OPUS_VERSION" \
      || "$(read_version opusfile)" != "$OPUSFILE_VERSION" \
      || "$(read_version libopusenc)" != "$LIBOPUSENC_VERSION" \
      || "$(read_version opus_tools)" != "$OPUS_TOOLS_VERSION" \
      || "$(read_version deps_patch)" != "$DEPS_PATCH_LEVEL" \
      || "$(read_version qext)" != "$ENABLE_QEXT" ]]; then
    log "Dependency version/qext changed; cleaning prefix $PREFIX"
    rm -rf "$PREFIX"
    mkdir -p "$PREFIX"
  fi
fi

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
export CPPFLAGS="-I$PREFIX/include ${CPPFLAGS:-}"
export LDFLAGS="-L$PREFIX/lib ${LDFLAGS:-}"
export CFLAGS="-fPIC ${CFLAGS:-}"
export CXXFLAGS="-fPIC ${CXXFLAGS:-}"

download_tarball() {
  local url="$1"
  local output="$2"
  if [[ -f "$output" ]]; then
    return
  fi
  log "Downloading $url"
  curl --fail --location --retry 3 --retry-delay 2 "$url" -o "$output"
}

extract_tarball() {
  local tarball="$1"
  local dest_dir="$2"
  rm -rf "$dest_dir"
  mkdir -p "$dest_dir"
  tar -xzf "$tarball" -C "$dest_dir" --strip-components=1
}

build_autotools_project() {
  local name="$1"
  local version="$2"
  local url="$3"
  local marker="$4"
  shift 4
  local configure_args=("$@")

  if [[ -f "$marker" ]]; then
    log "$name already built ($marker)"
    return
  fi

  local tarball="$SRC_ROOT/${name}-${version}.tar.gz"
  local build_dir="$WORK_ROOT/${name}-${version}"

  download_tarball "$url" "$tarball"
  extract_tarball "$tarball" "$build_dir"

  pushd "$build_dir" >/dev/null
  log "Configuring $name $version"
  ./configure --prefix="$PREFIX" "${configure_args[@]}"
  log "Building $name $version"
  make -j"$JOBS"
  log "Installing $name $version"
  make install
  popd >/dev/null
}

build_autotools_project \
  "libogg" "$LIBOGG_VERSION" \
  "https://downloads.xiph.org/releases/ogg/libogg-${LIBOGG_VERSION}.tar.gz" \
  "$PREFIX/lib/libogg.a" \
  --disable-shared --enable-static

OPUS_CONFIG=(--disable-shared --enable-static)
if [[ "$ENABLE_QEXT" == "1" ]]; then
  OPUS_CONFIG+=(--enable-qext)
else
  OPUS_CONFIG+=(--disable-qext)
fi

build_autotools_project \
  "opus" "$OPUS_VERSION" \
  "https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz" \
  "$PREFIX/lib/libopus.a" \
  "${OPUS_CONFIG[@]}"

if [[ "$ENABLE_QEXT" == "1" ]]; then
  touch "$PREFIX/.qext-enabled"
else
  rm -f "$PREFIX/.qext-enabled"
fi

build_autotools_project \
  "opusfile" "$OPUSFILE_VERSION" \
  "https://downloads.xiph.org/releases/opus/opusfile-${OPUSFILE_VERSION}.tar.gz" \
  "$PREFIX/lib/libopusfile.a" \
  --disable-shared --enable-static --disable-http

LIBOPUSENC_MARKER="$PREFIX/lib/libopusenc.a"
if [[ -f "$LIBOPUSENC_MARKER" ]]; then
  log "libopusenc already built ($LIBOPUSENC_MARKER)"
else
  LIBOPUSENC_TARBALL="$SRC_ROOT/libopusenc-${LIBOPUSENC_VERSION}.tar.gz"
  LIBOPUSENC_BUILD_DIR="$WORK_ROOT/libopusenc-${LIBOPUSENC_VERSION}"

  download_tarball \
    "https://downloads.xiph.org/releases/opus/libopusenc-${LIBOPUSENC_VERSION}.tar.gz" \
    "$LIBOPUSENC_TARBALL"
  extract_tarball "$LIBOPUSENC_TARBALL" "$LIBOPUSENC_BUILD_DIR"

  if [[ "$ENABLE_QEXT" == "1" ]]; then
    PATCH_FILE="$ROOT_DIR/scripts/patches/libopusenc-qext-ctl.patch"
    if [[ -f "$PATCH_FILE" ]]; then
      log "Applying libopusenc QEXT patch"
      patch -d "$LIBOPUSENC_BUILD_DIR" -p1 < "$PATCH_FILE"
    fi
  fi

  pushd "$LIBOPUSENC_BUILD_DIR" >/dev/null
  log "Configuring libopusenc $LIBOPUSENC_VERSION"
  ./configure --prefix="$PREFIX" --disable-shared --enable-static
  log "Building libopusenc $LIBOPUSENC_VERSION"
  make -j"$JOBS"
  log "Installing libopusenc $LIBOPUSENC_VERSION"
  make install
  popd >/dev/null
fi

if [[ "$WITH_OPUS_TOOLS" == "1" ]]; then
  OPUS_TOOLS_MARKER="$PREFIX/bin/opusenc"
  if [[ -f "$OPUS_TOOLS_MARKER" ]]; then
    log "opus-tools already built ($OPUS_TOOLS_MARKER)"
  else
    OPUS_TOOLS_TARBALL="$SRC_ROOT/opus-tools-${OPUS_TOOLS_VERSION}.tar.gz"
    OPUS_TOOLS_BUILD_DIR="$WORK_ROOT/opus-tools-${OPUS_TOOLS_VERSION}"

    download_tarball \
      "https://downloads.xiph.org/releases/opus/opus-tools-${OPUS_TOOLS_VERSION}.tar.gz" \
      "$OPUS_TOOLS_TARBALL"
    extract_tarball "$OPUS_TOOLS_TARBALL" "$OPUS_TOOLS_BUILD_DIR"

    if [[ "$ENABLE_QEXT" == "1" ]]; then
      PATCH_FILE="$ROOT_DIR/scripts/patches/opus-tools-qext-default.patch"
      if [[ -f "$PATCH_FILE" ]]; then
        log "Applying opus-tools QEXT patch"
        patch -d "$OPUS_TOOLS_BUILD_DIR" -p1 < "$PATCH_FILE"
      fi
    fi

    pushd "$OPUS_TOOLS_BUILD_DIR" >/dev/null
    log "Configuring opus-tools $OPUS_TOOLS_VERSION"
    ./configure --prefix="$PREFIX" \
      --disable-shared --enable-static --without-flac \
      --with-ogg="$PREFIX" --with-opusfile="$PREFIX" --with-libopusenc="$PREFIX" \
      --disable-oggtest --disable-opusfiletest --disable-libopusenctest
    log "Building opus-tools $OPUS_TOOLS_VERSION"
    make -j"$JOBS"
    log "Installing opus-tools $OPUS_TOOLS_VERSION"
    make install
    popd >/dev/null
  fi
fi

cat > "$PREFIX/.versions" <<EOF
libogg=$LIBOGG_VERSION
opus=$OPUS_VERSION
opusfile=$OPUSFILE_VERSION
libopusenc=$LIBOPUSENC_VERSION
opus_tools=$OPUS_TOOLS_VERSION
qext=$ENABLE_QEXT
deps_patch=$DEPS_PATCH_LEVEL
EOF

log "Done. Prefix: $PREFIX"
