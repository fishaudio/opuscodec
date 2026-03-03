import os

import numpy as np
import pytest

import opuscodec


def _make_pcm(sample_rate: int = 48_000, seconds: float = 1.0, channels: int = 1) -> np.ndarray:
    t = np.arange(int(sample_rate * seconds), dtype=np.float64) / sample_rate
    mono = 0.2 * np.sin(2 * np.pi * 440 * t)
    pcm = (mono * 32767).astype(np.int16)
    if channels == 1:
        return pcm.reshape(-1, 1)
    return np.repeat(pcm.reshape(-1, 1), channels, axis=1)


def _best_aligned_corr(x: np.ndarray, y: np.ndarray) -> float:
    x = x.astype(np.float64)
    y = y.astype(np.float64)
    corr = np.correlate(y, x, mode="full")
    lag = int(np.argmax(np.abs(corr)) - (len(x) - 1))
    if lag >= 0:
        x_aligned = x[: len(y) - lag]
        y_aligned = y[lag : lag + len(x_aligned)]
    else:
        y_aligned = y[: len(x) + lag]
        x_aligned = x[-lag : -lag + len(y_aligned)]

    n = min(len(x_aligned), len(y_aligned))
    if n < 1000:
        return 0.0
    x_aligned = x_aligned[:n]
    y_aligned = y_aligned[:n]
    return float(np.corrcoef(x_aligned, y_aligned)[0, 1])


def test_encode_decode_roundtrip() -> None:
    pcm = _make_pcm(channels=1)

    encoder = opuscodec.OpusBufferedEncoder(sample_rate=48_000, channels=1, bitrate=64_000)
    encoded = b""
    for i in range(0, len(pcm), 960):
        encoded += encoder.write(pcm[i : i + 960])
    encoded += encoder.flush()

    decoder = opuscodec.OpusBufferedDecoder()
    decoded = decoder.decode(encoded)

    assert decoded.dtype == np.int16
    assert decoded.ndim == 2
    assert decoded.shape[1] == 1
    assert decoded.shape[0] > 10_000

    corr = _best_aligned_corr(pcm[:, 0], decoded[:, 0])
    assert corr > 0.70


def test_encoder_rejects_invalid_channels() -> None:
    with pytest.raises(ValueError):
        opuscodec.OpusBufferedEncoder(sample_rate=48_000, channels=0)


def test_flush_requires_write() -> None:
    encoder = opuscodec.OpusBufferedEncoder(sample_rate=48_000, channels=1)
    with pytest.raises(ValueError):
        encoder.flush()


def test_qext_default_enabled() -> None:
    expected = os.environ.get("OPUSCODEC_ENABLE_QEXT", "1") != "0"
    assert opuscodec.qext_enabled() is expected


def test_encoder_qext_runtime_default_enabled() -> None:
    encoder = opuscodec.OpusBufferedEncoder(sample_rate=48_000, channels=1)
    expected = os.environ.get("OPUSCODEC_ENABLE_QEXT", "1") != "0"
    assert encoder.qext_enabled() is expected


def test_encoder_qext_runtime_can_disable() -> None:
    encoder = opuscodec.OpusBufferedEncoder(sample_rate=48_000, channels=1, qext=False)
    assert encoder.qext_enabled() is False
