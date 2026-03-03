# opuscodec

`opuscodec` 提供：

1. Python bindings：`OpusBufferedEncoder` + `OpusBufferedDecoder`
2. `opusenc` / `opusdec` self-contained 二进制构建
3. 默认启用 **Opus QEXT**（`--enable-qext`）
4. 基于 Xiph 官方稳定版依赖：
   - opus `1.6.1`
   - opus-tools `0.2`
   - libogg `1.3.6`
   - opusfile `0.12`
   - libopusenc `0.3`

## 仓库结构

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
├── opusenc.py   # encoder 兼容导出
└── opusdec.py   # decoder 兼容导出
```

## 快速开始

```bash
make test
```

常用命令：

```bash
make install    # 安装 editable 包 + test 依赖
make test       # 运行 pytest
make wheel      # 构建 wheel 到 dist/wheels
make binaries   # 构建 opusenc/opusdec 到 dist/bin
make clean      # 清理构建产物
```

## 构建配置

默认会自动下载并构建依赖，不依赖系统安装的 opus 库。

可选环境变量：

- `OPUSCODEC_ENABLE_QEXT=0`：关闭 qext（默认 `1`）
- `OPUSCODEC_USE_SYSTEM_DEPS=1`：改为使用系统依赖（默认 `0`）
- `OPUSCODEC_DEPS_PREFIX=/path/to/prefix`：指定依赖安装目录

## Python 使用示例

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

CI 在以下平台构建并上传 artifact：

- `macos-14` (arm64)
- `ubuntu-24.04` (amd64)

每个平台产物包含：

- Python wheel
- `opusenc` / `opusdec` 二进制
- `versions.txt`（依赖版本与 qext 状态）
