# SayItDev

**On-device voice + AI for Mac** — part of the [innovatorved](https://github.com/innovatorved) ecosystem.

SayItDev is a fork of [Arthur-Ficial/apfel](https://github.com/Arthur-Ficial/apfel), extended with native Apple speech capabilities. Use the **`dev`** command for text-to-speech, speech-to-text, a simple voice agent, and an OpenAI-compatible local server — no API keys, no cloud.

**Maintainer:** vedgupta@protonmail.com

## Requirements

- macOS 26+ on Apple Silicon
- Apple Intelligence enabled (for LLM / `--agent` only)
- Xcode 26 / Command Line Tools with macOS 26.4 SDK

## Install

### Homebrew (easiest)

```bash
brew tap innovatorved/tap
brew install innovatorved/tap/dev
dev --version
```

Requires macOS 26+, Apple Silicon, Apple Intelligence (for LLM / `--agent`).

### Build from source

```bash
git clone https://github.com/innovatorved/sayitdev.git
cd sayitdev
make build
codesign --force --sign - .build/release/dev
sudo make install   # installs `dev` to /usr/local/bin — do NOT run make build with sudo
```

Or run from the build directory:

```bash
swift build -c release
codesign --force --sign - .build/release/dev
.build/release/dev --help
```

Install globally so `dev` is on your PATH:

```bash
sudo make install
dev --version
```

Or for this shell only:

```bash
export PATH="$PWD/.build/release:$PATH"
dev --version
```

> Grant **Microphone** and **Speech Recognition** to Terminal.app in System Settings → Privacy on first use. Voice features (especially `--listen`, `--agent`, and `/v1/audio/transcriptions`) must be tested from **Terminal.app** — the Cursor integrated terminal does not reliably inherit TCC permissions.

## Voice commands

| Command | Description |
|---------|-------------|
| `dev --speak "hello"` | Text → speech |
| `dev --listen` | Default mic → transcript on stdout |
| `dev --agent` | Voice Q&A loop: listen → on-device LLM → speak |
| `dev --serve` | OpenAI-compatible HTTP server |

### Examples

```bash
dev --speak "Hello from SayItDev"
echo "Read this aloud" | dev --speak
dev --listen
dev --agent
dev --serve
```

### Voice options

```bash
dev --speak "hi" --voice-name personal
dev --listen --locale en-US
dev --agent --system "You are a concise assistant"
```

Environment variables: `DEV_TTS_VOICE`, `DEV_STT_LOCALE`, `DEV_TTS_RATE`, `DEV_TTS_FORMAT`, `DEV_AUDIO_INPUT`.

## Server audio API

With `dev --serve`:

- `POST /v1/audio/speech` — JSON `{ "input": "hello", "voice": "default", "response_format": "wav" }`
- `POST /v1/audio/transcriptions` — multipart upload with `file` field
- `GET /v1/audio/voices` — list system TTS voices
- `POST /v1/chat/completions` — unchanged from apfel

```bash
curl -s http://127.0.0.1:11434/v1/audio/speech \
  -H 'content-type: application/json' \
  -d '{"model":"sayitdev-on-device","input":"hello","voice":"default","response_format":"wav"}' \
  --output out.wav
```

## Complete test checklist

Use **Terminal.app** (not Cursor) for anything involving the microphone or speech recognition.

### 1. Build and install

```bash
cd sayitdev
make build
codesign --force --sign - .build/release/dev
.build/release/dev --version    # expect: dev v1.0.0
```

Optional: `sudo make install` then use `dev` from anywhere.

### 2. Automated voice smoke test

```bash
chmod +x demo/voice-check
./demo/voice-check
```

TTS + server audio routes (no mic).

```bash
./demo/voice-check --full
```

Also runs `dev --listen` (needs mic permission).

### 3. CLI voice modes (manual)

```bash
dev --speak "Hello from SayItDev"
echo "Read this aloud" | dev --speak
dev --listen                    # speak, pause; transcript on stdout
dev --agent                     # voice Q&A loop; Ctrl-C to quit
```

Voice flags:

```bash
dev --speak "hi" --voice-name personal --rate 1.1
dev --listen --locale en-US
dev --agent --system "You are a concise assistant"
```

### 4. Server + HTTP audio API

```bash
dev --serve --port 11434 &
curl -s http://127.0.0.1:11434/health | jq .
curl -s http://127.0.0.1:11434/v1/audio/voices | jq '.voices[:3]'
curl -s -X POST http://127.0.0.1:11434/v1/audio/speech \
  -H 'content-type: application/json' \
  -d '{"input":"hello","voice":"default","response_format":"wav"}' \
  --output out.wav
curl -s -X POST http://127.0.0.1:11434/v1/audio/transcriptions \
  -F file=@out.wav -F model=sayitdev-on-device | jq .
kill %1
```

### 5. LLM + demos (unchanged from apfel)

```bash
dev "What is 2+2?"
dev --stream "Write a haiku"
dev --chat
dev demos ./dev-demos && ./dev-demos/mac-narrator --say
```

### 6. Unit and integration tests

```bash
swift run sayitdev-tests                                    # 1048 unit tests
/opt/homebrew/Caskroom/miniconda/base/bin/pytest \
  Tests/integration/test_man_page.py -v                     # man page drift
make preflight                                              # build + model-free integration
```

### Permissions (System Settings → Privacy)

| Permission | Needed for |
|------------|------------|
| Microphone | `--listen`, `--agent`, mic capture |
| Speech Recognition | `--listen`, `--agent`, `/v1/audio/transcriptions` |

TTS (`--speak`, `/v1/audio/speech`) does not require Apple Intelligence.

## Credits

Built on [apfel](https://github.com/Arthur-Ficial/apfel) by [Arthur-Ficial](https://github.com/Arthur-Ficial). Voice extensions by **SayItDev** / innovatorved.

## License

MIT — see [LICENSE](LICENSE).
