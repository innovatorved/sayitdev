# CLI Reference

`dev` has seven primary modes: single prompt, `--stream`, `--chat`, `--serve`, and the SayItDev voice modes `--speak`, `--listen`, and `--agent`. This page is the full flag, exit-code, and environment reference for the installed CLI.

## Modes

```text
MODES
  dev <prompt>                          Single prompt (default)
  dev --stream <prompt>                 Stream response tokens
  dev --chat                            Interactive conversation
  dev --serve                           Start OpenAI-compatible server
  dev --speak [text]                    Text-to-speech (stdin or argument)
  dev --listen                          Speech-to-text from default microphone
  dev --agent                           Voice agent: listen → LLM → speak
  dev --benchmark                       Run internal performance benchmarks
  dev --count-tokens <prompt>           Preflight token count (no inference)

INPUT
  dev -f, --file <path> <prompt>        Attach file content (repeatable)
  dev -s, --system <text> <prompt>      Set system prompt
  dev --system-file <path> <prompt>     Read system prompt from file
  dev --mcp <path|url> <prompt>         Attach local or remote MCP tool server (repeatable)
  dev --mcp-token <token> <prompt>      Bearer token for remote MCP servers
  dev --mcp-timeout <n> <prompt>        MCP timeout in seconds [default: 5]
  dev --messages <path|->               One-shot multi-turn from OpenAI messages JSON (file or stdin)

OUTPUT
  -o, --output <fmt>                      Output format: plain, json
  -q, --quiet                             Suppress non-essential output
  --no-color                              Disable ANSI colors
  --code                                  Print only the code: first fenced block, or the bare response (exit 7 if empty)
  --schema <path>                         Constrain output to a JSON Schema file (guaranteed valid JSON)

MODEL
  --temperature <n>                       Sampling temperature (e.g., 0.7); 0 = deterministic
  --top-p <n>                             Nucleus sampling threshold in (0, 1] (e.g., 0.9)
  --seed <n>                              Random seed for reproducibility
  --max-tokens <n>                        Maximum response tokens
  --permissive                            Relaxed guardrails (reduces false positives)
  --retry [n]                             Retry transient errors with backoff (default: 3)
  --debug                                 Enable debug logging to stderr (all modes)
  --count-tokens                          Count tokens without calling the model
  --strict                                With --count-tokens: exit 4 if over budget

CONTEXT (--chat)
  --context-strategy <s>                  newest-first, oldest-first, sliding-window, summarize, strict
  --context-max-turns <n>                 Max history turns (sliding-window only)
  --context-output-reserve <n>            Tokens reserved for output (default: 512)
  --context-status                        Print chat context fill after each turn

SERVER (--serve)
  --port <n>                              Server port (default: 11434)
  --host <addr>                           Bind address (default: 127.0.0.1)
  --cors                                  Enable CORS headers
  --allowed-origins <origins>             Comma-separated allowed origins
  --no-origin-check                       Disable origin checking
  --token <secret>                        Require Bearer token auth
  --token-auto                            Generate random Bearer token
  --public-health                         Keep /health unauthenticated
  --i-know-what-im-doing                  Allow non-loopback --serve without --token
  --footgun                               Disable all protections
  --max-concurrent <n>                    Max concurrent requests (default: 5)

VOICE (--speak, --listen, --agent)
  --input-device <uid>                    Microphone device UID [DEV_AUDIO_INPUT]
  --voice-name <name>                     TTS voice id or personal [DEV_TTS_VOICE]
  --locale <id>                           STT/TTS locale [DEV_STT_LOCALE, default en-US]
  --rate <n>                              TTS speaking rate [DEV_TTS_RATE]
  --audio-format <fmt>                    TTS output format: wav, pcm, aac [DEV_TTS_FORMAT]
  --timestamps                            Include timing in transcriptions

META
  -v, --version                           Print version
  -h, --help                              Show help
  --release                               Detailed build info
  --model-info                            Print model capabilities
  --update                                Check for updates via Homebrew
  --demos [dir]                           Write bundled demo scripts to dir [default: ./dev-demos]

SUBCOMMANDS
  dev completions <shell>               Print shell completions (bash, zsh, fish)
```

## Examples By Flag

```bash
# -f, --file - attach file content to prompt (repeatable)
dev -f main.swift "Explain this code"
dev -f before.txt -f after.txt "What changed?"

# -s, --system - set a system prompt
dev -s "You are a pirate" "What is recursion?"
dev -s "Reply in JSON only" "List 3 colors"

# --system-file - read system prompt from a file
dev --system-file persona.txt "Introduce yourself"

# --schema - guaranteed schema-valid JSON output (single-prompt mode only)
dev --schema person.schema.json "Extract the person: Alice is 30 years old."
dev --schema invoice.schema.json -f invoice.txt "Extract the invoice data" | jq .total

# --code - only the code, no prose, no fences (pipe-safe)
dev --code "a python function that deduplicates a list" > dedupe.py
dev --code "shell one-liner to find the 10 largest files here" | pbcopy

# --messages - one-shot multi-turn: conversation JSON in, next assistant turn out
dev --messages conversation.json
jq '. += [{"role":"user","content":"and in German?"}]' conv.json | dev --messages -

# --mcp, --mcp-token, --mcp-timeout
dev --mcp ./mcp/calculator/server.py "What is 15 times 27?"
dev --mcp ./calc.py --mcp ./weather.py "Use both tools"
dev --mcp https://mcp.example.com/v1 "Remote MCP server"
DEV_MCP_TOKEN=mytoken dev --mcp https://mcp.example.com/v1 "With auth"
dev --mcp-timeout 30 --mcp ./slow-remote-server.py "hello"

# -o, --output
dev -o json "Translate to German: hello" | jq .content

# -q, --quiet
dev -q "Give me a UUID"

# --no-color
NO_COLOR=1 dev "Hello"

# --temperature
dev --temperature 0.0 "What is 2+2?"
dev --temperature 1.5 "Write a wild poem"

# --top-p
dev --top-p 0.9 "Write a short poem"

# --seed
dev --seed 42 "Tell me a joke"

# --max-tokens
dev --max-tokens 50 "Explain quantum computing"

# --permissive
dev --permissive "Write a villain monologue"
dev --permissive -f long-document.md "Summarize this"

# --retry
dev --retry "What is 2+2?"

# --debug
dev --debug "Hello world"
dev --serve --debug

# --count-tokens, --strict
dev --count-tokens -f README.md "Summarize this"
dev --count-tokens -o json "hello" | jq .
dev --count-tokens --strict -f large-file.txt "process"
# Counts use the on-device tokenizer API (macOS 26.4+). When it is unusable
# (older macOS, or Apple Intelligence off), counts are a chars/4 approximation:
# a stderr warning names the reason and JSON output carries "approximate": true.

# --stream
dev --stream "Write a haiku about code"

# --chat
dev --chat
dev --chat -s "You are a helpful coding assistant"

# --chat with persistent history across sessions (opt-in, off by default)
DEV_HISTFILE=~/.dev_history dev --chat

# --context-strategy
dev --chat --context-strategy newest-first
dev --chat --context-strategy sliding-window --context-max-turns 6
dev --chat --context-strategy summarize
dev --chat --context-output-reserve 256
dev --chat --context-status

# --serve
dev --serve
dev --serve --port 3000 --host 0.0.0.0

# --cors, --token, --footgun
dev --serve --cors
dev --serve --token "my-secret-token"
dev --serve --footgun

# --token-auto, --public-health
dev --serve --token-auto --host 0.0.0.0 --public-health

# --allowed-origins, --no-origin-check
dev --serve --allowed-origins "https://myapp.com,https://staging.myapp.com"
dev --serve --no-origin-check

# --max-concurrent
dev --serve --max-concurrent 2

# --i-know-what-im-doing
dev --serve --i-know-what-im-doing --host 0.0.0.0 --token "secret"

# --benchmark, --model-info, --update, --release, --version, --help
dev --benchmark -o json | jq '.benchmarks[] | {name, speedup_ratio}'
dev --model-info
dev --update
dev --release
dev --version
dev --help

# --demos: write the bundled demo scripts out (works on every install channel)
dev demos ./dev-demos
dev --demos ./dev-demos

# --speak, --listen, --agent (SayItDev voice modes)
dev --speak "Hello from SayItDev"
echo "Read this aloud" | dev --speak
dev --listen
dev --agent
dev --speak "Hi" --voice-name personal --rate 1.1
dev --listen --locale en-US
dev --listen --input-device <uid> --timestamps
dev --speak "Hi" --audio-format wav
```

Security details live in [server-security.md](server-security.md). Background-service usage lives in [background-service.md](background-service.md).

## Shell Completions

`dev completions <shell>` prints a completion script to stdout for `bash`, `zsh`, or `fish`. Homebrew installs them automatically. To enable them for a source/manual install, write the script to your shell's completion directory.

bash:

```bash
dev completions bash | sudo tee "$(brew --prefix)/etc/bash_completion.d/dev" >/dev/null
```

zsh (a directory already on your `$fpath`):

```bash
dev completions zsh > "${fpath[1]}/_dev"
```

fish:

```fish
dev completions fish > ~/.config/fish/completions/dev.fish
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Usage error (bad flags) |
| 3 | Guardrail blocked |
| 4 | Context overflow |
| 5 | Model unavailable |
| 6 | Rate limited |
| 7 | No code in response (`--code`) |
| 8 | Microphone permission denied |
| 9 | Speech asset / engine failure |
| 10 | No audio input device |
| 130 | Interrupted (Ctrl-C at chat prompt) |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DEV_SYSTEM_PROMPT` | Default system prompt |
| `DEV_HOST` | Server bind address |
| `DEV_PORT` | Server port |
| `DEV_TOKEN` | Bearer token for server authentication |
| `DEV_TEMPERATURE` | Default temperature |
| `DEV_MAX_TOKENS` | Default max tokens |
| `DEV_CONTEXT_STRATEGY` | Default context strategy |
| `DEV_CONTEXT_MAX_TURNS` | Max turns for sliding-window |
| `DEV_CONTEXT_OUTPUT_RESERVE` | Tokens reserved for output |
| `DEV_MCP` | MCP server paths - colon-separated for local paths, comma-separated for mixed local+remote URLs |
| `DEV_MCP_TOKEN` | Bearer token for remote HTTP MCP servers (preferred over `--mcp-token`; not visible in `ps aux`) |
| `DEV_MCP_TIMEOUT` | MCP timeout in seconds (default: 5, max: 300) |
| `DEV_DEBUG` | Enable debug logging (same as `--debug`) |
| `DEV_HISTFILE` | Persist `--chat` line-editing history to this file across sessions (off by default; bounded to 500 entries, mode 0600) |
| `DEV_TTS_VOICE` | Default TTS voice id or `personal` |
| `DEV_STT_LOCALE` | Default STT locale (e.g. `en-US`) |
| `DEV_TTS_RATE` | Default speaking rate (0.25–4.0) |
| `DEV_TTS_FORMAT` | Default server TTS format: `wav`, `pcm`, or `aac` |
| `DEV_AUDIO_INPUT` | Default microphone device UID |
| `NO_COLOR` | Disable colors ([https://no-color.org](https://no-color.org)) |
