#!/usr/bin/env bash
# Test the freshly built release binary through a temporary Homebrew service formula.
set -euo pipefail

formula="dev-release-test"
tap="codex/release-test"
work_dir=$(mktemp -d)
formula_file="$work_dir/$formula.rb"
tap_created=0

cleanup() {
    brew services stop "$formula" >/dev/null 2>&1 || true
    brew uninstall --force "$formula" >/dev/null 2>&1 || true
    if [[ "$tap_created" == "1" ]]; then
        brew untap "$tap" --force >/dev/null 2>&1 || true
    fi
    rm -rf "$work_dir"
}
trap cleanup EXIT

if brew list --versions "$formula" >/dev/null 2>&1; then
    echo "FATAL: $formula is already installed; refusing to replace it" >&2
    exit 1
fi

asset=$(make package-release-asset | tail -1)
sha256=$(shasum -a 256 "$asset" | awk '{print $1}')
make update-homebrew-formula \
    HOMEBREW_FORMULA_OUTPUT="$formula_file" \
    HOMEBREW_FORMULA_SHA256="$sha256"

python3 - "$formula_file" "$asset" <<'PY'
from pathlib import Path
import sys

formula = Path(sys.argv[1])
asset = Path(sys.argv[2]).resolve()
text = formula.read_text()
text = text.replace("class Dev < Formula", "class DevReleaseTest < Formula", 1)
text = text.replace(
    "class DevReleaseTest < Formula\n",
    "class DevReleaseTest < Formula\n  keg_only :versioned_formula\n",
    1,
)
start = text.index('  url "')
end = text.index('"', start + 7)
text = text[:start] + f'  url "file://{asset}' + text[end:]
text = text.replace(
    'run [opt_bin/"dev", "--serve"]',
    'run [opt_bin/"dev", "--serve", "--port", "11436"]',
    1,
)
text = text.replace('var/"log/dev.log"', 'var/"log/dev-release-test.log"')
formula.write_text(text)
PY

HOMEBREW_NO_AUTO_UPDATE=1 brew tap-new "$tap" --no-git
tap_created=1
tap_dir="$(brew --repository)/Library/Taps/codex/homebrew-release-test"
mkdir -p "$tap_dir/Formula"
cp "$formula_file" "$tap_dir/Formula/$formula.rb"
if ! HOMEBREW_NO_AUTO_UPDATE=1 brew install "$tap/$formula"; then
    # The formula may be installed into the Cellar while Homebrew refuses to
    # link its `dev` binary over a developer's existing /opt/homebrew/bin/dev.
    # The service runs from opt_bin directly, so this is safe to test without
    # replacing the user's command.
    brew list --versions "$formula" >/dev/null 2>&1 \
        || { echo "FATAL: Homebrew failed to install $formula" >&2; exit 1; }
fi
DEV_BREW_SERVICE_FORMULA="$formula" \
DEV_BREW_SERVICE_PORT=11436 \
DEV_REQUIRE_FULL=1 \
    python3 -m pytest Tests/integration/test_brew_service.py -v --tb=short
