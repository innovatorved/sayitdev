# How to use the Apple Foundation Model from AWK

AWK can't do HTTP on its own - it was designed for text processing, not networking. The UNIX convention is to **pair AWK with curl**: curl handles transport, AWK parses the response. That's what every script in this guide does.

Runnable scripts + tests: [__UPSTREAM_DEV_REPO__-guides-lab/scripts/awk](__UPSTREAM_DEV_URL__-guides-lab/tree/main/scripts/awk).

## Prerequisites

- macOS 26+ Tahoe, Apple Silicon, Apple Intelligence enabled
- `brew install dev jq` (`jq` is only needed for the JSON-mode + tool-calling examples)
- `dev --serve` running (port `11434`)
- `awk` (ships with macOS)

## 1. One-shot

```bash
#!/usr/bin/env bash
set -euo pipefail

PROMPT="In one sentence, what is the Swift programming language?"
PAYLOAD=$(awk -v prompt="$PROMPT" 'BEGIN {
  gsub(/"/, "\\\"", prompt)
  printf "{\"model\":\"sayitdev-on-device\",\"messages\":[{\"role\":\"user\",\"content\":\"%s\"}],\"max_tokens\":80}", prompt
}')

curl -sS http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" -d "$PAYLOAD" \
  | awk 'BEGIN { RS="\"content\" :" } NR==2 {
      match($0, /"([^"\\]|\\.)*"/)
      s = substr($0, RSTART+1, RLENGTH-2)
      gsub(/\\n/, "\n", s); gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s)
      print s
    }'
```

Real output:

```text
Swift is a modern, open-source programming language developed by Apple for developing apps and systems across platforms, known for its safety, performance, and ease of use.
```

Lab script: [`01_oneshot.sh`](__UPSTREAM_DEV_URL__-guides-lab/blob/main/scripts/awk/01_oneshot.sh).

## 2. Streaming

```bash
#!/usr/bin/env bash
set -euo pipefail

curl -sS -N http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"sayitdev-on-device","messages":[{"role":"user","content":"List three Apple silicon chips, one per line."}],"max_tokens":80,"stream":true}' \
  | awk '
      /^data: / {
        json = substr($0, 7)
        if (json == "[DONE]" || json == "") next
        if (match(json, /"content":"([^"\\]|\\.)*"/)) {
          s = substr(json, RSTART + 11, RLENGTH - 12)
          gsub(/\\n/, "\n", s); gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s)
          printf "%s", s
          fflush()
        }
      }
      END { print "" }
    '
```

Real output:

```text
Apple M1
Apple M1 Pro
Apple M1 Max
```

Lab script: [`02_stream.sh`](__UPSTREAM_DEV_URL__-guides-lab/blob/main/scripts/awk/02_stream.sh).

## 3. JSON mode

AWK is not a JSON parser. It can extract the string `content` field well enough, but for real validation we hand off to `jq`:

```bash
PAYLOAD='{"model":"sayitdev-on-device","messages":[{"role":"user","content":"Return JSON with fields chip, year, cores. Describe the Apple M1 chip. Return ONLY JSON."}],"response_format":{"type":"json_object"},"max_tokens":120}'

curl -sS http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" -d "$PAYLOAD" \
  | awk 'BEGIN { RS="\"content\" :" } NR==2 {
      match($0, /"([^"\\]|\\.)*"/)
      s = substr($0, RSTART+1, RLENGTH-2)
      gsub(/\\n/, "\n", s); gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s)
      print s
    }' \
  | sed -E 's/^```(json)?//; s/```$//' \
  | jq '.'
```

Real output:

```json
{
  "chip": "Apple M1",
  "year": 2020,
  "cores": {
    "CPU": 8,
    "GPU": 8
  }
}
```

Lab script: [`03_json.sh`](__UPSTREAM_DEV_URL__-guides-lab/blob/main/scripts/awk/03_json.sh).

## 4. Error handling

Use AWK to extract the `.error.message` string from the JSON body after curl gives you the HTTP status:

```bash
tmp=$(mktemp)
status=$(curl -sS -o "$tmp" -w '%{http_code}' \
  http://localhost:11434/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"sayitdev-on-device","input":"dev runs 100% on-device."}')

if [[ "$status" -ge 400 ]]; then
  msg=$(awk 'BEGIN { RS="\"message\" :" } NR==2 {
    match($0, /"([^"\\]|\\.)*"/)
    s = substr($0, RSTART+1, RLENGTH-2)
    gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s)
    print s
  }' "$tmp")
  echo "Got expected error: HTTP $status - ${msg:-see response}"
fi
rm -f "$tmp"
```

Real output:

```text
Got expected error: HTTP 501 - Embeddings not supported by Apple's on-device model.
```

Lab script: [`04_errors.sh`](__UPSTREAM_DEV_URL__-guides-lab/blob/main/scripts/awk/04_errors.sh).

## 5. Tool calling (delegate to Bash)

Tool calling requires constructing nested JSON with escaped strings, modifying the conversation, and posting back - this is outside AWK's sweet spot. The idiomatic AWK solution is to delegate to the Bash tool-calling script:

```bash
#!/usr/bin/env bash
here=$(cd "$(dirname "$0")" && pwd)
bash "$here/../bash-curl/05_tools.sh"
```

Real output:

```text
The current temperature in Vienna is 14 degrees Celsius.
```

Lab script: [`05_tools.sh`](__UPSTREAM_DEV_URL__-guides-lab/blob/main/scripts/awk/05_tools.sh). For tool-heavy code, reach for [python.md](python.md) or [nodejs.md](nodejs.md).

## 6. Real example - summarize stdin

AWK does what AWK is good at - text cleanup - then hands the clean text to dev:

```bash
cleaned=$(awk '
  { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); gsub(/[[:space:]]+/, " ") }
  { print }
' | awk 'NF')

payload=$(jq -n --arg text "$cleaned" '{
  model:"sayitdev-on-device",
  messages:[
    {role:"system", content:"You are a concise summarizer. Reply with one short paragraph."},
    {role:"user", content:("Summarize:\n\n" + $text)}
  ],
  max_tokens:150
}')

curl -sS http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" -d "$payload" \
  | awk 'BEGIN { RS="\"content\" :" } NR==2 {
      match($0, /"([^"\\]|\\.)*"/)
      s = substr($0, RSTART+1, RLENGTH-2)
      gsub(/\\n/, "\n", s); gsub(/\\"/, "\"", s); gsub(/\\\\/, "\\", s)
      print s
    }'
```

Real output:

```text
The Apple M1 chip, launched in November 2020, marked Apple's first ARM-based system-on-a-chip for Macs. This chip features an 8-core CPU with four performance and four efficiency cores, along with an integrated GPU capable of up to 8 cores. By consolidating the CPU, GPU, memory, and neural engine on a single die, the M1 chip achieved notable performance-per-watt improvements compared to its Intel counterparts.
```

Lab script: [`06_example.sh`](__UPSTREAM_DEV_URL__-guides-lab/blob/main/scripts/awk/06_example.sh).

## Troubleshooting

- **AWK doesn't parse JSON** - true, and we don't pretend it does. Use AWK for the `content` string extraction and delegate nested work to `jq`.
- **Escaped characters leaking through** - order matters: unescape `\\n` first, then `\\"`, then `\\\\`, as shown in the `gsub` chain.
- **macOS `awk` vs `gawk`** - the scripts above use only POSIX AWK features that work with the system BSD `awk`.

## Tested with

- dev v1.0.3 / macOS 26.3.1 Apple Silicon (original capture; the CLI and HTTP surfaces used here are release-gated by dev's test suite on every version)
- BSD awk 20200816 (system) / jq 1.7 / curl
- Date: 2026-04-16

Runnable tests: [tests/test_awk.py](__UPSTREAM_DEV_URL__-guides-lab/blob/main/tests/test_awk.py).

## See also

[bash-curl.md](bash-curl.md), [perl.md](perl.md), [zsh.md](zsh.md), [dev-guides-lab](__UPSTREAM_DEV_URL__-guides-lab)
