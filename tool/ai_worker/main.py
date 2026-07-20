#!/usr/bin/env python3
"""Open Filmly's model-agnostic JSONL worker.

The Flutter app owns task state. This process only performs one request at a
time and writes machine-readable events to stdout. Optional dependencies are
loaded lazily so `probe` works on a clean machine and missing models produce a
useful task error instead of breaking the app.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from typing import Any


def emit(message: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def fail(request_id: str, message: str) -> None:
    emit({"id": request_id, "type": "error", "error": {"message": message}})


def probe(path: str) -> dict[str, Any]:
    executable = shutil.which("ffprobe")
    if executable is None:
        raise RuntimeError("ffprobe is not installed or is not on PATH")
    completed = subprocess.run(
        [
            executable,
            "-v",
            "quiet",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            path,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(completed.stdout)


def transcribe(request_id: str, data: dict[str, Any]) -> dict[str, Any]:
    try:
        from faster_whisper import WhisperModel
    except ImportError as error:
        raise RuntimeError(
            "faster-whisper is not installed; install it or configure another Worker"
        ) from error

    model_name = str(data.get("model") or "tiny")
    model_directory = str(data.get("modelDirectory") or "")
    model_path = os.path.join(model_directory, model_name) if model_directory else model_name
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg is not installed or is not on PATH")

    model = WhisperModel(model_path, device="auto", compute_type="int8")
    with tempfile.TemporaryDirectory(prefix="open-filmly-audio-") as temporary:
        audio_path = os.path.join(temporary, "audio.wav")
        subprocess.run(
            [
                ffmpeg,
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                str(data["path"]),
                "-map",
                "0:a:0",
                "-vn",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-c:a",
                "pcm_s16le",
                "-y",
                audio_path,
            ],
            check=True,
        )
        segments, info = model.transcribe(
            audio_path,
            language=None if data.get("language") in (None, "", "auto") else data["language"],
            vad_filter=True,
        )
        result: list[dict[str, Any]] = []
        for segment in segments:
            result.append(
                {
                    "startMs": round(float(segment.start) * 1000),
                    "endMs": round(float(segment.end) * 1000),
                    "text": str(segment.text).strip(),
                    "language": str(info.language or data.get("language") or ""),
                    "confidence": float(getattr(segment, "avg_logprob", 0.0)),
                }
            )
            emit(
                {
                    "id": request_id,
                    "type": "progress",
                    "progress": min(0.99, len(result) / max(len(result) + 20, 1)),
                }
            )
        return {"language": str(info.language or data.get("language") or ""), "segments": result}


def translate(data: dict[str, Any]) -> dict[str, Any]:
    try:
        from argostranslate import translate as argos_translate
    except ImportError as error:
        raise RuntimeError(
            "argostranslate is not installed; configure a remote translation adapter"
        ) from error
    source = str(data.get("sourceLanguage") or "auto")
    target = str(data["targetLanguage"])
    texts = [str(value) for value in data.get("texts") or []]
    return {
        "language": target,
        "texts": [argos_translate.translate(text, source, target) for text in texts],
    }


def embed(data: dict[str, Any]) -> dict[str, Any]:
    try:
        from sentence_transformers import SentenceTransformer
    except ImportError as error:
        raise RuntimeError(
            "sentence-transformers is not installed; embedding is optional"
        ) from error
    model = SentenceTransformer(str(data.get("model") or "all-MiniLM-L6-v2"))
    vector = model.encode(str(data.get("text") or ""), normalize_embeddings=True)
    return {"vector": vector.tolist()}


def sample_frames(request_id: str, data: dict[str, Any]) -> dict[str, Any]:
    executable = shutil.which("ffmpeg")
    if executable is None:
        raise RuntimeError("ffmpeg is not installed or is not on PATH")
    output_directory = str(data.get("outputDirectory") or "")
    if not output_directory:
        raise RuntimeError("sample_frames requires outputDirectory")
    os.makedirs(output_directory, exist_ok=True)
    count = max(1, int(data.get("count") or 12))
    duration_ms = max(0, int(data.get("durationMs") or 0))
    fps = count / (duration_ms / 1000) if duration_ms else 1
    pattern = os.path.join(output_directory, "frame-%04d.jpg")
    subprocess.run(
        [
            executable,
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(data["path"]),
            "-vf",
            f"fps={fps:.6f}",
            "-frames:v",
            str(count),
            pattern,
        ],
        check=True,
    )
    return {"paths": sorted(os.path.join(output_directory, name) for name in os.listdir(output_directory) if name.endswith(".jpg"))}


def handle(request_id: str, method: str, data: dict[str, Any]) -> dict[str, Any]:
    if method == "probe":
        return probe(str(data["path"]))
    if method == "transcribe":
        return transcribe(request_id, data)
    if method == "translate":
        return translate(data)
    if method == "embed":
        return embed(data)
    if method == "sample_frames":
        return sample_frames(request_id, data)
    raise RuntimeError(f"Unsupported Worker method: {method}")


def main() -> None:
    for line in sys.stdin:
        if not line.strip():
            continue
        request: dict[str, Any] = {}
        try:
            request = json.loads(line)
            request_id = str(request["id"])
            result = handle(request_id, str(request["method"]), dict(request.get("input") or {}))
            emit({"id": request_id, "type": "result", "result": result})
        except Exception as error:  # worker errors belong to the current task
            fail(str(request.get("id", "unknown")), str(error))


if __name__ == "__main__":
    main()
