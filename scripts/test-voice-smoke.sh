#!/usr/bin/env bash
# Smoke test: dev --listen must not abort (exit 134) on silence teardown.
# Requires mic + speech permissions for the calling terminal (Terminal.app recommended).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "${TERM_PROGRAM:-}" == "Cursor" ]] || [[ -n "${CURSOR_TRACE_ID:-}" ]]; then
  echo "NOTE: Run this script from Terminal.app (not Cursor) — TCC blocks mic/speech from IDE shells."
  echo ""
fi

DEV="${DEV_BIN:-$ROOT/.build/release/dev}"

if [[ ! -x "$DEV" ]]; then
  echo "Building release binary..."
  make build
fi

abort_exit=134
failures=0

run_silence_test() {
  local label="$1"
  local cmd=("${@:2}")
  echo "==> $label (10s silence, must not abort)"
  "${cmd[@]}" </dev/null >/dev/null 2>&1 &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [[ "$waited" -lt 10 ]]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    echo "    OK: survived 10s (clean kill)"
    return 0
  fi
  wait "$pid"
  local code=$?
  if [[ "$code" -eq "$abort_exit" ]]; then
    echo "    FAIL: aborted with exit $code (heap corruption / SIGABRT)"
    failures=$((failures + 1))
    return 1
  fi
  echo "    OK: exited $code within ${waited}s (no abort)"
  return 0
}

run_sequential_listen_test() {
  echo "==> dev --listen twice sequentially (second capture must not abort)"
  local code1 code2
  set +e
  "$DEV" --listen </dev/null >/dev/null 2>&1 &
  local pid1=$!
  local waited=0
  while kill -0 "$pid1" 2>/dev/null && [[ "$waited" -lt 10 ]]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid1" 2>/dev/null; then
    kill "$pid1" 2>/dev/null || true
    wait "$pid1" 2>/dev/null || true
    code1=0
  else
    wait "$pid1"
    code1=$?
  fi

  "$DEV" --listen </dev/null >/dev/null 2>&1 &
  local pid2=$!
  waited=0
  while kill -0 "$pid2" 2>/dev/null && [[ "$waited" -lt 10 ]]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid2" 2>/dev/null; then
    kill "$pid2" 2>/dev/null || true
    wait "$pid2" 2>/dev/null || true
    code2=0
  else
    wait "$pid2"
    code2=$?
  fi
  set -e

  if [[ "$code1" -eq "$abort_exit" || "$code2" -eq "$abort_exit" ]]; then
    echo "    FAIL: first=$code1 second=$code2 (exit $abort_exit abort)"
    failures=$((failures + 1))
    return 1
  fi
  echo "    OK: first=$code1 second=$code2 (no abort on second capture)"
  return 0
}

run_silence_test "dev --listen" "$DEV" --listen || true
run_sequential_listen_test || true

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "Voice smoke test FAILED ($failures run(s) aborted with exit $abort_exit)"
  exit 1
fi

echo ""
echo "Voice smoke test passed (no exit $abort_exit abort)"
