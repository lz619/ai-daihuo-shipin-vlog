#!/usr/bin/env python3
"""Pinned local ASR entry point for final-video quality checks."""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
import sys
import wave
from pathlib import Path


EXPECTED_VERSION = "1.2.1"
MODEL_NAME = "base.en"


def load_model(model_directory: Path):
    actual_version = importlib.metadata.version("faster-whisper")
    if actual_version != EXPECTED_VERSION:
        raise RuntimeError(
            f"Expected faster-whisper {EXPECTED_VERSION}, found {actual_version}. "
            "Run scripts/setup-faster-whisper.ps1 to repair the fixed runtime."
        )
    from faster_whisper import WhisperModel

    model_directory.mkdir(parents=True, exist_ok=True)
    threads = max(1, min(4, os.cpu_count() or 1))
    return WhisperModel(
        MODEL_NAME,
        device="cpu",
        compute_type="int8",
        cpu_threads=threads,
        download_root=str(model_directory),
    )


def read_pcm_wav(audio_path: Path):
    """Load the 16 kHz mono PCM WAV emitted by run-faster-whisper-qa.ps1.

    Passing samples directly avoids PyAV container-decoder version drift; FFmpeg
    performs the media decoding and resampling in the PowerShell entry point.
    """
    import numpy as np

    with wave.open(str(audio_path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        sample_rate = wav.getframerate()
        if sample_width != 2 or sample_rate != 16000:
            raise RuntimeError(
                f"Expected 16-bit 16 kHz PCM WAV, got sample_width={sample_width}, "
                f"sample_rate={sample_rate}. Run the PowerShell QA wrapper."
            )
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2")
    if channels > 1:
        if samples.size % channels:
            raise RuntimeError("Invalid multichannel PCM WAV frame length.")
        samples = samples.reshape(-1, channels).mean(axis=1)
    return samples.astype(np.float32) / 32768.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True, type=Path)
    parser.add_argument("--audio", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--download-model", action="store_true")
    args = parser.parse_args()

    if args.download_model:
        load_model(args.model_dir)
        print(json.dumps({"status": "model_ready", "model": MODEL_NAME}, ensure_ascii=False))
        return 0
    if args.audio is None or args.output is None:
        parser.error("--audio and --output are required unless --download-model is used")
    if not args.audio.is_file():
        raise FileNotFoundError(f"Audio input does not exist: {args.audio}")

    actual_version = importlib.metadata.version("faster-whisper")
    model = load_model(args.model_dir)
    audio_samples = read_pcm_wav(args.audio)
    segments, info = model.transcribe(
        audio_samples,
        language="en",
        beam_size=5,
        word_timestamps=True,
        vad_filter=False,
        condition_on_previous_text=False,
    )
    segment_results = []
    for segment in segments:
        words = []
        for word in segment.words or []:
            words.append(
                {
                    "start": word.start,
                    "end": word.end,
                    "text": word.word,
                    "probability": word.probability,
                }
            )
        segment_results.append(
            {
                "start": segment.start,
                "end": segment.end,
                "text": segment.text,
                "words": words,
            }
        )

    result = {
        "schema_version": 1,
        "status": "transcribed",
        "engine": "faster-whisper",
        "engine_version": actual_version,
        "model": MODEL_NAME,
        "device": "cpu",
        "compute_type": "int8",
        "language": info.language,
        "language_probability": info.language_probability,
        "duration_seconds": info.duration,
        "audio_path": str(args.audio.resolve()),
        "segments": segment_results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "output": str(args.output.resolve()), "segments": len(segment_results)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # fail closed: the QA caller must not report a pass
        print(f"faster-whisper ASR failed: {exc}", file=sys.stderr)
        raise SystemExit(2)
