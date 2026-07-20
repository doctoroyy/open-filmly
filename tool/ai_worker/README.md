# Open Filmly AI Worker

The worker is a line-delimited JSON process. Flutter starts it once and sends
one request per line. The worker emits progress, result, or error messages,
also one JSON object per line.

The protocol is intentionally independent of the model runtime. A production
installation may use `ffprobe`, `ffmpeg`, `whisper.cpp`, `faster-whisper`, or
another local implementation without changing the Flutter task queue.

The first Flutter integration only requires the executable path to be
configured. No model or media file is downloaded automatically.

## Real macOS E2E test

The optional `test/ai_worker_e2e_test.dart` starts the real worker process and
verifies `ffprobe → faster-whisper → intelligence database → SRT/VTT`.
Ordinary `flutter test` runs skip this test unless the required environment
variables are present.

Example setup using an isolated temporary Python environment:

```sh
uv venv --python 3.12 /tmp/open-filmly-ai-e2e
uv pip install --python /tmp/open-filmly-ai-e2e/bin/python faster-whisper

E2E_DIR=$(mktemp -d /tmp/open-filmly-ai-e2e-media.XXXXXX)
say -v Samantha -o "$E2E_DIR/voice.aiff" \
  "Hello from Open Filmly. This is a real end to end subtitle test."
ffmpeg -hide_banner -loglevel error \
  -f lavfi -i color=c=black:s=640x360:r=24 \
  -i "$E2E_DIR/voice.aiff" -shortest \
  -c:v libx264 -pix_fmt yuv420p -c:a aac "$E2E_DIR/speech.mp4"

FILMLY_AI_E2E_PYTHON=/tmp/open-filmly-ai-e2e/bin/python \
FILMLY_AI_E2E_MEDIA="$E2E_DIR/speech.mp4" \
FILMLY_AI_E2E_WORKER="$PWD/tool/ai_worker/main.py" \
HF_HOME="$E2E_DIR/huggingface" \
flutter test test/ai_worker_e2e_test.dart
```

The first run downloads the selected Whisper model into `HF_HOME`. The test
uses an empty target language so it validates the real source-transcription
and subtitle path without requiring a separate translation model package.
