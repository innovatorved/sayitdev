#!/usr/bin/env bash
# Ad-hoc sign the release binary after swift build so TCC permissions persist
# locally. Release signing (Developer ID + notarization) lives in
# scripts/publish-release.sh instead.
set -euo pipefail
binary="${1:?usage: adhoc-codesign.sh <path-to-binary>}"
/usr/bin/codesign --force --sign - "$binary" 2>/dev/null || true
