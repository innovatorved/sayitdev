# SayItDev

**On-device voice + AI for Mac** — part of the [innovatorved](https://github.com/innovatorved) ecosystem.

SayItDev is a fork of [Arthur-Ficial/apfel](https://github.com/Arthur-Ficial/apfel), extended with native Apple speech capabilities. Use the **`dev`** command for text-to-speech, speech-to-text, a simple voice agent, and an OpenAI-compatible local server — no API keys, no cloud.

**Maintainer:** vedgupta@protonmail.com

## Requirements

- macOS 26+ on Apple Silicon
- Apple Intelligence enabled (for LLM / `--agent` only)
- Xcode 26 / Command Line Tools with macOS 26.4 SDK

## Install

```bash
git clone https://github.com/innovatorved/sayitdev.git
cd sayitdev
make build
sudo make install   # installs `dev` to /usr/local/bin
```

Or run from the build directory:

```bash
swift build
codesign --force --sign - .build/debug/dev
.build/debug/dev --help
```

> Grant **Microphone** and **Speech Recognition** to Terminal.app in System Settings → Privacy on first use.

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

## Credits

Built on [apfel](https://github.com/Arthur-Ficial/apfel) by [Arthur-Ficial](https://github.com/Arthur-Ficial). Voice extensions by **SayItDev** / innovatorved.

## License

MIT — see [LICENSE](LICENSE).
