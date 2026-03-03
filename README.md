# opuscodec

`opuscodec` provides:

1. Python bindings: `OpusBufferedEncoder` + `OpusBufferedDecoder`
2. Self-contained `opusenc` / `opusdec` binary builds
3. Opus **QEXT** enabled by default (`--enable-qext`)
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

## Quick start

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

## Build configuration

By default, dependencies are downloaded and built automatically (no system Opus libraries required).

Optional environment variables:

- `OPUSCODEC_ENABLE_QEXT=0`: disable qext (default `1`)
- `OPUSCODEC_USE_SYSTEM_DEPS=1`: use system dependencies instead of vendored build (default `0`)
- `OPUSCODEC_DEPS_PREFIX=/path/to/prefix`: custom dependency install prefix

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
print(y.shape, opuscodec.opus_version(), opuscodec.qext_enabled())
```

## GitHub Actions

CI builds and uploads artifacts for:

- `macos-14` (arm64)
- `ubuntu-24.04` (amd64)

Each platform artifact contains:

- Python wheel
- `opusenc` / `opusdec` binaries
- `versions.txt` (dependency versions + qext status)

Release automation:

- On GitHub Release **published** (for example `v0.1.0`), CI also uploads release assets automatically:
  - platform wheel (`.whl`)
  - `opuscodec-<tag>-<target>-binaries.tar.gz` (contains `opusenc`, `opusdec`, `versions.txt`)
