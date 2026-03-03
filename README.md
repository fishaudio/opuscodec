# opuscodec

`opuscodec` provides:

1. Python bindings: `OpusBufferedEncoder` + `OpusBufferedDecoder`
2. Self-contained `opusenc` / `opusdec` binary builds
3. Opus **QEXT** enabled by default (build-time + runtime encoder ctl)
4. Xiph stable dependencies by default:
   - opus `1.6.1`
   - opus-tools `0.2`
   - libogg `1.3.6`
   - opusfile `0.12`
   - libopusenc `0.3`

## Repository layout

```text
.
├── .github/workflows/build.yml
├── Makefile
├── pyproject.toml
├── setup.py
├── src/
│   └── opuscodec_bindings.cpp
├── scripts/
│   ├── build_deps.sh
│   └── build_binaries.sh
├── tests/
│   └── test_bindings.py
├── opusenc.py   # encoder compatibility export
└── opusdec.py   # decoder compatibility export
```

## Quick start (source build)

```bash
make test
```

Common commands:

```bash
make install    # install editable package + test deps
make test       # run pytest
make wheel      # build wheel into dist/wheels
make binaries   # build opusenc/opusdec into dist/bin
make clean      # clean build artifacts
```

## Install from prebuilt wheel (no local build)

1. Open GitHub Releases and download the wheel matching your OS + Python ABI (`cp311` or `cp312`).
2. Install directly with pip:

```bash
python -m pip install ./opuscodec-0.1.0-cp312-cp312-linux_x86_64.whl
```

You can also install from a direct release asset URL:

```bash
python -m pip install "https://github.com/fishaudio/opuscodec/releases/download/v0.1.0/<wheel-file-name>.whl"
```

## Python usage example

```python
import numpy as np
import opuscodec

sr = 48000
x = (0.1 * np.sin(2 * np.pi * 440 * np.arange(sr) / sr) * 32767).astype(np.int16).reshape(-1, 1)

enc = opuscodec.OpusBufferedEncoder(sample_rate=sr, channels=1)
packet = enc.write(x) + enc.flush()

dec = opuscodec.OpusBufferedDecoder()
y = dec.decode(packet)
print(y.shape, opuscodec.opus_version(), opuscodec.qext_enabled(), enc.qext_enabled())
```

To explicitly disable runtime QEXT for one encoder instance:

```python
enc = opuscodec.OpusBufferedEncoder(sample_rate=sr, channels=1, qext=False)
```

## Standalone binary encode/decode test (WAV or PCM)

After downloading release binaries, extract:

```bash
tar -xzf opuscodec-v0.1.0-linux-amd64-binaries.tar.gz
chmod +x opusenc opusdec
```

### WAV roundtrip

```bash
./opusenc input.wav output.opus
./opusdec output.opus roundtrip.wav
```

`opusenc` in this repository enables QEXT by default.  
To force-disable it for comparison tests:

```bash
./opusenc --set-ctl-int 4056=0 input.wav output-noqext.opus
```

### Raw PCM (16-bit little-endian) roundtrip

Encode raw PCM (`mono`, `48k`, `s16le`) to Opus:

```bash
./opusenc --raw --raw-bits 16 --raw-rate 48000 --raw-chan 1 input.pcm output.opus
```

Decode Opus back to PCM:

```bash
./opusdec output.opus decoded.pcm
```

> `decoded.pcm` is raw PCM data. If you need WAV output, decode to `*.wav` (example above).

## Build configuration

By default, dependencies are downloaded and built automatically (no system Opus libraries required).

Optional environment variables:

- `OPUSCODEC_ENABLE_QEXT=0`: disable qext (default `1`)
- `OPUSCODEC_USE_SYSTEM_DEPS=1`: use system dependencies instead of vendored build (default `0`)
- `OPUSCODEC_DEPS_PREFIX=/path/to/prefix`: custom dependency install prefix

When QEXT is enabled at build time, packaged `opusenc` binaries also enable `OPUS_SET_QEXT(1)` by default.

## GitHub Actions

CI builds for:

- `macos-14` (arm64)
- `ubuntu-24.04` (amd64)
- Python `3.11` and `3.12`

CI artifacts include:

- wheel artifacts per target + python version
- standalone binary artifacts per target (`opusenc`, `opusdec`, `versions.txt`)

Release automation:

- On GitHub Release **published** (for example `v0.1.0`), CI uploads release assets automatically:
  - wheels (`cp311`, `cp312`)
  - `opuscodec-<tag>-<target>-binaries.tar.gz`
