# opuscodec

`opuscodec` 提供：

1. Python bindings：`OpusBufferedEncoder` + `OpusBufferedDecoder`
2. `opusenc` / `opusdec` 自包含二进制构建（优先静态链接 Opus 相关依赖）
3. 默认启用 **Opus QEXT**（`--enable-qext`）
4. 使用 Xiph 官方稳定版本依赖（默认）：
   - opus `1.6.1`
   - opus-tools `0.2`
   - libogg `1.3.6`
   - opusfile `0.12`
   - libopusenc `0.3`

## 本地安装（构建 Python 扩展）

> 默认会自动下载并构建依赖，不依赖系统安装的 opus 库。

```bash
python3 -m pip install -U pip setuptools wheel pybind11 numpy
python3 -m pip install -e .
```

可选环境变量：

- `OPUSCODEC_ENABLE_QEXT=0`：关闭 qext（默认 `1`）
- `OPUSCODEC_USE_SYSTEM_DEPS=1`：改为使用系统依赖（默认 `0`）
- `OPUSCODEC_DEPS_PREFIX=/path/to/prefix`：指定依赖安装目录

## Python 使用示例

```python
import numpy as np
import opuscodec

sr = 48000
x = (0.1 * np.sin(2 * np.pi * 440 * np.arange(sr) / sr) * 32767).astype(np.int16)
x = x.reshape(-1, 1)

enc = opuscodec.OpusBufferedEncoder(sample_rate=sr, channels=1)
packet = enc.write(x)
packet += enc.flush()

dec = opuscodec.OpusBufferedDecoder()
y = dec.decode(packet)
print(y.shape, opuscodec.opus_version(), opuscodec.qext_enabled())
```

## 构建自包含二进制

```bash
bash scripts/build_binaries.sh
```

输出目录：`dist/bin/<target>/opusenc` 和 `opusdec`

## 运行测试

```bash
python3 -m pip install -e .[test]
pytest -q
```

## GitHub Actions

CI 会在以下平台构建并上传 artifact：

- `macos-14` (arm64)
- `ubuntu-24.04` (amd64)

Artifact 内容：

- Python wheel
- `opusenc` / `opusdec` 二进制
- `versions.txt`（构建依赖版本与 qext 状态）
