# dev demos

Real-world shell scripts powered by Apple Intelligence via `dev`.

All demos work within the 4096-token context window - small input, small output, instant results.

## cmd

Natural language to shell command. Faster than Googling, works offline.

```bash
./cmd "find all .log files modified today"
$ find . -name "*.log" -type f -mtime -1

./cmd -c "disk usage sorted by size"    # copy to clipboard
./cmd -x "show open ports"              # execute (asks confirmation)
```

## oneliner

Complex pipe chains from plain English. Specializes in awk, sed, find, xargs, sort, uniq, grep, cut, tr, jq.

```bash
./oneliner "sum the third column of a CSV"
$ awk -F',' '{sum += $3} END {print sum}' file.csv

./oneliner "count unique IPs in access.log"
$ awk '{print $1}' access.log | sort | uniq -c | sort -rn

./oneliner -c "remove duplicate lines keeping order"    # copy to clipboard
./oneliner -x "sort processes by memory"                # execute (asks confirmation)
```

## wtd

What's this directory? Instant orientation in any project.

```bash
./wtd                    # current directory
./wtd ~/some/project     # any directory
./wtd -c .               # copy summary to clipboard
```

Checks file listing, README, package.json/Package.swift/Cargo.toml/go.mod, git branch and last commit, then tells you what this project is, what language, and how to run it.

**Example output:**

```
The directory /Users/you/dev/dev contains a Swift package project that
appears to be a macOS application. It utilizes Swift 6.2 and the Swift
Package Manager (SPM). To build or run the project, use swift build.
```

## explain

Explain a command, error message, or code snippet.

```bash
./explain "awk -F: '{print \$1,\$3}' /etc/passwd | sort -t' ' -k2 -n"
./explain "error: use of undeclared identifier 'URLSession'"
./explain "curl -sSL -o /dev/null -w '%{http_code}'"
pbpaste | ./explain       # explain whatever's on clipboard
dmesg | tail -5 | ./explain
```

**Example output:**

```
This command processes /etc/passwd, extracting the username (field 1) and
user ID (field 3) using colon as delimiter, then sorts the output
numerically by user ID.
```

## naming

Name things well. Describe what something does, get naming suggestions.

```bash
./naming "function that retries HTTP requests with exponential backoff"
./naming "variable for the count of failed login attempts"
./naming "class that manages WebSocket connections"
./naming -c "file containing database migration scripts"    # copy to clipboard
```

**Example output:**

```
retryWithBackoff | retry_with_backoff | retries with exponential delay
httpRetryHandler | http_retry_handler | handles HTTP retry logic
fetchWithRetry | fetch_with_retry | fetch with automatic retries
resilientRequest | resilient_request | request that survives failures
backoffExecutor | backoff_executor | executes with increasing delays
```

## port

What's using this port? Identifies the process and explains what it is.

```bash
./port 3000
./port 8080
./port 5432
./port -c 3000    # copy to clipboard
```

**Example output:**

```
Process 1234, named node, is listening on port 3000 - this is likely
a Node.js development server (Express, Next.js, or similar).
```

## gitsum

Summarize recent git activity in plain English.

```bash
./gitsum          # last 10 commits
./gitsum 20       # last 20 commits
./gitsum -c       # copy summary to clipboard
```

**Example output:**

```
Recent work focused on adding tool calling documentation with real experiment
results, implementing OpenAPI schema validation tests, and adding cmd and
oneliner demo scripts. Documentation was also rewritten for the README.
```

## mac-narrator

Your Mac's inner monologue. Narrates system state in dry British humor. With `--say`, speaks via `dev --speak` (SayItDev TTS).

```bash
./mac-narrator                    # one-shot observation
./mac-narrator --watch            # continuous, every 60s
./mac-narrator --watch -i 30      # every 30 seconds
./mac-narrator --say              # speak the narration aloud
```

**Example output:**

```
[14:23:07] Ah, the eternal dance - Claude Code consuming 8.2% CPU whilst
its human presumably waits for it to finish. Meanwhile, WindowServer
soldiers on at 3.1%, dutifully rendering pixels that nobody is looking at.
```

## voice-check

Quick smoke test for SayItDev voice features (run from **Terminal.app** after `make build`):

```bash
./voice-check
```

TTS + server audio routes (no mic).

```bash
./voice-check --full
```

Also runs `--listen` once (needs mic permission).

## Requirements

- `dev` installed and on PATH (`make install` or use `.build/release/dev`)
- Apple Intelligence enabled in System Settings (for LLM demos and `--agent`; not required for `--speak` / `--listen` alone)
- macOS 26+, Apple Silicon
- **Microphone + Speech Recognition** granted to Terminal.app (for `--listen`, `--agent`, transcriptions API)

## Install demos globally (optional)

`brew install innovatorved/tap/dev` installs companion scripts as `dev-cmd`, `dev-port`, etc. (see the formula). They live under Homebrew's `pkgshare` and are symlinked into `$(brew --prefix)/bin`.

If you are developing from a source clone instead, you can symlink from `demo/` manually — names like `cmd`, `port`, and `explain` are too generic for unprefixed global `$PATH` (`port` would shadow MacPorts).

```bash
mkdir -p "$HOME/.local/bin"
for d in cmd explain gitsum mac-narrator naming oneliner port wtd; do
  ln -sf "$(pwd)/demo/$d" "$HOME/.local/bin/dev-$d"
done
```

Then invoke them as `dev-cmd "find large files"`, `dev-port 3000`, etc.

**Caveats:**

- The symlinks point at your current clone. If you move or delete the `dev/` directory, the symlinks break - re-run the loop from the new location.
- Make sure `$HOME/.local/bin` is on your `$PATH` (`echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc`).
- To remove later: `for d in cmd explain gitsum mac-narrator naming oneliner port wtd; do rm -f "$HOME/.local/bin/dev-$d"; done`
