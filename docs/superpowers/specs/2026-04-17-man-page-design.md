# dev(1) man page — design

**Date:** 2026-04-17
**Issue:** [#103](__UPSTREAM_DEV_URL__/issues/103) — _Proposal: Create man page for apfel_
**Author:** Arthur Ficial

## Goal

Ship a proper `dev(1)` man page so `man dev` works after any supported install (`brew install dev`, `make install`, `nix profile install nixpkgs#dev-ai`). The page must stay **in lockstep with `dev --help`** — a flag change without a man-page change must break CI.

## Non-goals

- Translating the man page. English only for now.
- Generating from `--help` text. Our help is prose; a man page deserves more structure (`ENVIRONMENT`, `EXIT STATUS`, `FILES`, `SEE ALSO`) and richer wording than `--help` carries.
- Shipping `dev-completions(1)` or multi-page `man` sets. Single page only.

## Decisions

### 1. Hand-written troff source at `man/dev.1.in`

A versioned troff template with a single placeholder `@VERSION@`. No pandoc dependency at release time, no markdown build step, diffs are human-readable in PRs.

Rejected alternatives:

- **Markdown + pandoc.** Adds a release-time dep (`pandoc`) and another format-conversion step. Preflight already has enough surface area.
- **Generate from `--help`.** Duplicates prose; loses man-page sections; tight-couples two things we explicitly want separately reviewed.

### 2. Version injection via Makefile

New target `generate-man-page` substitutes `@VERSION@` from `.version` and writes `.build/release/dev.1`. Flow mirrors `generate-build-info`.

### 3. Install wiring

- `make install` copies `dev.1` to `$(PREFIX)/share/man/man1/dev.1`.
- `make uninstall` removes it.
- `make package-release-asset` now writes a tarball with `dev` + `dev.1` at its root (layout: `dev-<v>-arm64-macos.tar.gz` → contains `dev`, `dev.1`).
- `scripts/write-homebrew-formula.sh` emits `man1.install "dev.1"` alongside the existing `bin.install "dev"`.
- nixpkgs: no change on our side — the nixpkgs derivation installs any `share/man/man1/*.1` automatically when present in the tarball.

### 4. Drift prevention (the automation the user asked for)

A single integration test, `Tests/integration/test_man_page.py`, enforces:

1. `dev.1` passes `mandoc -Tlint -W warning,stop` with zero warnings.
2. `man -l dev.1` renders without error.
3. **Bidirectional flag coverage.** Every flag in `dev --help` appears in the man page `OPTIONS`/`CONTEXT OPTIONS`/`SERVER OPTIONS` sections; every flag in those sections appears in `dev --help`. Added, removed, or renamed flags _must_ touch both files or the test fails.
4. **Bidirectional environment coverage.** Same check for `ENVIRONMENT` section ↔ `dev --help` `ENVIRONMENT` block.
5. **Exit-status coverage.** Every exit code in `main.swift` is listed in the man-page `EXIT STATUS` section.
6. Version in the man page header matches `.version`.

This test runs in three places:

- `swift run dev-tests` + `python3 -m pytest Tests/integration/test_man_page.py` during local dev.
- GitHub CI (`ci.yml`) on every push and PR — blocks merge.
- `make preflight` — blocks every release.

Because the drift test is model-free, it fits into the subset GitHub runners can execute.

### 5. Content sections

```
NAME
SYNOPSIS
DESCRIPTION
OPTIONS
CONTEXT OPTIONS
SERVER OPTIONS
ENVIRONMENT
EXIT STATUS
FILES
EXAMPLES
BUGS
SEE ALSO
AUTHORS
```

`FILES` documents `.env`/`DEV_*` consumers and the Homebrew plist path. `SEE ALSO` references `jq(1)`, `curl(1)`, `brew(1)`, and the GitHub repo.

## Testing

- **Unit** (`Tests/apfelTests/ManPageTests.swift`):
  - `man/dev.1.in` exists and is non-empty.
  - Contains all required section headers.
  - `@VERSION@` placeholder present exactly once, inside `.TH`.
  - No stray `@.*@` placeholders besides `@VERSION@`.
- **Integration** (`Tests/integration/test_man_page.py`): the six drift checks above, run against the generated `.build/release/dev.1`.

## Rollout

1. Land change behind new tests (red → green).
2. `make preflight`.
3. `make release` (patch bump 1.0.4 → 1.0.5).
4. `post-release-verify.sh`.
5. Close [#103](__UPSTREAM_DEV_URL__/issues/103) with a short friendly note crediting CamJN.

## Risks / open questions

- **mandoc strictness.** `mandoc -Tlint -W warning,stop` can be fussy about `.TH` date format. We pin the format the tests expect so drift is caught deterministically.
- **GitHub CI macOS runner.** Confirmed `mandoc(1)` ships with macOS; the workflow already selects the latest Xcode, which is unrelated. No new apt/brew install on the runner.
- **Nixpkgs auto-install.** If the nixpkgs derivation uses a bare `installPhase` that only installs `bin/*`, the man page may be missed. We will file a follow-up if `nix-build` doesn't pick it up; the derivation is community-maintained.
