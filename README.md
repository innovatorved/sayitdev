# SayItDev

On-device AI and voice for Mac. The **`dev`** CLI runs Apple Intelligence locally — speak, listen, chat, and serve an OpenAI-compatible API. No cloud, no API keys.

## Requirements

- macOS 26+ on Apple Silicon
- Apple Intelligence enabled (for LLM / `--agent` only)

## Install

```bash
brew tap innovatorved/tap
brew install innovatorved/tap/dev
dev --version
```

Build from source: clone this repo, run `make build && sudo make install`. See [docs/brew-install.md](docs/brew-install.md) for troubleshooting.

> For `--listen` and `--agent`, grant **Microphone** and **Speech Recognition** to Terminal.app in System Settings → Privacy.

## Usage

| Command | What it does |
|---------|----------------|
| `dev --speak "hello"` | Text to speech |
| `dev --listen` | Mic → transcript |
| `dev --agent` | Voice Q&A loop |
| `dev "your prompt"` | On-device LLM |
| `dev --serve` | Local HTTP server (port 11434) |

```bash
dev --speak "Hello from SayItDev"
dev --listen
dev --agent
dev "What is 2+2?"
dev --serve
```

Server endpoints include `/v1/chat/completions`, `/v1/audio/speech`, and `/v1/audio/transcriptions`. See [docs/server-security.md](docs/server-security.md) before exposing the server on your network.

## Docs

- [CLI reference](docs/cli-reference.md)
- [Homebrew install](docs/brew-install.md)
- [Server security](docs/server-security.md)

## Credits

Fork of [apfel](https://github.com/Arthur-Ficial/apfel) with voice extensions by SayItDev / innovatorved.

MIT — see [LICENSE](LICENSE).
