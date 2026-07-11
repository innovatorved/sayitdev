# dev Integrations

Community-contributed configurations for using dev with other tools.

For **scripting language guides** (how to call dev from Python, Node.js, Ruby, PHP, Bash, Zsh, AppleScript, Swift, Perl, AWK) see [docs/guides/index.md](guides/index.md). Every snippet there was run against a live dev server; lab repo: [dev-guides-lab](__UPSTREAM_DEV_URL__-guides-lab).

---

## opencode

[opencode](https://opencode.ai) is an open-source terminal AI coding agent. Wire it to dev's OpenAI-compatible server and every token stays on-device at zero cost. Re-verified end-to-end on opencode 1.17.16 + dev 1.8.2.

Full setup, the verified config, a real transcript, and every gotcha are on the dedicated page: [docs/integrations/opencode.md](integrations/opencode.md). The one you must not miss: opencode pastes your global `~/.claude/CLAUDE.md` into the system prompt, which overflows dev's 4096-token window - fix it with `export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1`.

---

## Zed

[Zed](https://zed.dev)'s agent panel works with dev via the chat-completions provider. On-device, no key.

**Heads-up:** use `language_models.openai_compatible` (chat). Do **not** use `edit_predictions.open_ai_compatible_api` - that's a legacy text-completions endpoint dev deliberately doesn't support.

**Config:** `~/.config/zed/settings.json`

```json
{
  "language_models": {
    "openai_compatible": {
      "Apfel": {
        "api_url": "http://127.0.0.1:11434/v1",
        "available_models": [
          {
            "name": "sayitdev-on-device",
            "display_name": "Apfel (apple on-device)",
            "max_tokens": 4096,
            "max_output_tokens": 1024,
            "capabilities": { "tools": true, "images": false, "parallel_tool_calls": false, "prompt_cache_key": false }
          }
        ]
      }
    }
  }
}
```

Start dev:

```bash
dev --serve
```

Launch Zed (Zed insists on a key for the provider; dev ignores it):

```bash
DEV_API_KEY=dummy zed
```

Open the agent panel (`Cmd+?`), pick `Apfel (apple on-device)`, send a prompt. Zed POSTs to `/v1/chat/completions` on dev.

---

## Visual Studio Code + Continue

Use `dev` as the local review/chat model in Visual Studio Code and pair it with a second model for Edit/Apply. (See also: [Leveraging multiple, repository-specific OpenAI Codex API Keys with Visual Studio Code on macOS](https://snelson.us/2026/04/many-to-one-api-keys/).)

Step-by-step setup: [local-setup-with-vs-code.md](local-setup-with-vs-code.md)

Why this setup works well:

- `dev` stays in the small-context, low-latency review lane
- Continue provides the Visual Studio Code integration
- a second model can handle larger edit/apply tasks without overloading `dev`'s 4096-token context window

---

*Have an integration to share? Open an issue at [__UPSTREAM_DEV_URL__/issues](__UPSTREAM_DEV_URL__/issues).*
