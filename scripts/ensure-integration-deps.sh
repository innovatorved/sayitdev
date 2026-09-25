#!/usr/bin/env bash
# Install Python deps required by Tests/integration/.
# Idempotent — safe to run before every test/release qualification.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/Tests/integration/requirements.txt"

[ -f "$REQ" ] || { echo "FATAL: missing $REQ"; exit 1; }

PIP_FLAGS=()
if python3 -m pip install --help 2>/dev/null | grep -q break-system-packages; then
    PIP_FLAGS+=(--break-system-packages)
fi

echo "Installing integration test Python deps from Tests/integration/requirements.txt ..."
python3 -m pip install "${PIP_FLAGS[@]}" -r "$REQ" -q

python3 -c "
import httpx, jsonschema, openai, pytest, yaml
from openapi_core import Config, OpenAPI
print('Integration test deps OK')
"
