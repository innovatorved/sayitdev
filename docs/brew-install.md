# Install with Homebrew

`dev` is available from the innovatorved tap:

```bash
brew tap innovatorved/tap
brew install innovatorved/tap/dev
```

Verify the install:

```bash
dev --version
dev --release
```

## Requirements

- Apple Silicon
- macOS 26.4 or newer
- Apple Intelligence enabled

Homebrew installs the `dev` binary plus optional `dev-*` demo companion commands. You do **not** need Xcode.

## Troubleshooting

If the binary runs but generation is unavailable, check:

```bash
dev --model-info
```

If you installed `dev` both via Homebrew and `sudo make install`, the first match on your `PATH` wins:

```bash
which -a dev
```

To prefer the Homebrew build:

```bash
brew link --overwrite innovatorved/tap/dev
```

To prefer a local `make install` build, ensure `/usr/local/bin` (or your `PREFIX`) appears before Homebrew in `PATH`, or run `brew unlink dev`.

## Maintainers

See [release.md](release.md) for the release workflow and Homebrew tap maintenance.
