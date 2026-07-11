# Install with Homebrew

`dev` is available in homebrew-core:

```bash
brew install dev
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

Homebrew installs the `dev` binary. You do **not** need Xcode.

## Troubleshooting

If the binary runs but generation is unavailable, check:

```bash
dev --model-info
```

If you already installed `dev` manually into `/usr/local/bin/dev`, make sure the Homebrew binary is first in your `PATH`:

```bash
which dev
brew --prefix
```

## Maintainers

See [release.md](release.md) for the release workflow and Homebrew tap maintenance.
