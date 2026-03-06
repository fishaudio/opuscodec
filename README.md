# opuscodec

Python bindings and self-contained Opus CLI builds, with **QEXT enabled by default**.

`opuscodec` packages three things together:

- `OpusBufferedEncoder` / `OpusBufferedDecoder` Python bindings
- self-contained `opusenc` / `opusdec` release binaries
- vendored Xiph dependencies, built from source when needed

Stable dependency set:

- `opus` `1.6.1`
- `opus-tools` `0.2`
- `libogg` `1.3.6`
- `opusfile` `0.12`
- `libopusenc` `0.3`

## Why this package

- no system Opus install required by default
- runtime + build-time QEXT control
- Python API and CLI assets released from one repo
- PyPI wheels for supported targets, source build fallback everywhere else

## Installation

### PyPI (recommended)

```bash
python -m pip install opuscodec==0.1.2
```

### GitHub Release asset

```bash
python -m pip install "https://github.com/fishaudio/opuscodec/releases/download/v0.1.2/<wheel-file-name>.whl"
```

Example Linux wheel name:

```bash
python -m pip install ./opuscodec-0.1.2-cp312-cp312-manylinux_2_28_x86_64.whl
```

### Source build

```bash
make test
```

Common commands:

```bash
make install    # editable install + test deps
make test       # run pytest
make wheel      # build wheel into dist/wheels
make binaries   # build opusenc/opusdec into dist/bin
make clean      # clean build artifacts
```

## Python example

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

Disable runtime QEXT for one encoder instance:

```python
enc = opuscodec.OpusBufferedEncoder(sample_rate=48000, channels=1, qext=False)
```

## Standalone binary usage

After downloading release binaries:

```bash
tar -xzf opuscodec-v0.1.2-linux-amd64-binaries.tar.gz
chmod +x opusenc opusdec
```

### WAV roundtrip

```bash
./opusenc input.wav output.opus
./opusdec output.opus roundtrip.wav
```

`opusenc` enables QEXT by default in this repository build. Disable it explicitly for comparison tests:

```bash
./opusenc --set-ctl-int 4056=0 input.wav output-noqext.opus
```

### Raw PCM roundtrip

Encode raw PCM (`mono`, `48k`, `s16le`) to Opus:

```bash
./opusenc --raw --raw-bits 16 --raw-rate 48000 --raw-chan 1 input.pcm output.opus
```

Decode Opus back to PCM:

```bash
./opusdec output.opus decoded.pcm
```

## Build configuration

Defaults: vendored dependencies; QEXT enabled.

Optional environment variables:

- `OPUSCODEC_ENABLE_QEXT=0` — disable QEXT
- `OPUSCODEC_USE_SYSTEM_DEPS=1` — use system libraries instead of vendored build
- `OPUSCODEC_DEPS_PREFIX=/path/to/prefix` — custom dependency prefix

When QEXT is enabled at build time, packaged `opusenc` binaries also enable `OPUS_SET_QEXT(1)` by default.

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
├── opusenc.py
└── opusdec.py
```

## Release automation

On tag push (for example `v0.1.2`), GitHub Actions will:

- run tests on Linux + macOS
- build PyPI-compatible manylinux wheels for Linux
- build macOS arm64 wheels
- build an `sdist`
- publish wheel + sdist artifacts to PyPI via OIDC
- create a GitHub Release and upload wheels + binary tarballs

## License

Apache License 2.0. See [LICENSE](./LICENSE).
