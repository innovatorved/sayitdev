"""Voice mode integration tests (HTTP routes + speak stdin policy)."""

import os
import subprocess
import threading
import time

import httpx
import pytest

from conftest import BINARY


VOICE_SERVER = "http://127.0.0.1:11434"


@pytest.fixture(scope="session", autouse=True)
def guard_server_11435():
    yield


@pytest.mark.serial
def test_speak_with_explicit_text_does_not_hang_on_open_stdin():
    """Regression: dev --speak \"hi\" must not block reading an open stdin pipe."""
    if not BINARY.exists():
        pytest.skip("release binary not built; run make build first")

    reader, writer = os.pipe()
    proc = subprocess.Popen(
        [str(BINARY), "--speak", "hi"],
        stdin=reader,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    os.close(reader)

    def hold_stdin_open():
        time.sleep(0.2)
        os.close(writer)

    threading.Thread(target=hold_stdin_open, daemon=True).start()

    try:
        stdout, stderr = proc.communicate(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        pytest.fail("dev --speak hung with open stdin while text was provided on argv")

    assert proc.returncode == 0, f"stderr:\n{stderr}\nstdout:\n{stdout}"


def test_audio_voices_list():
    resp = httpx.get(f"{VOICE_SERVER}/v1/audio/voices", timeout=10)
    assert resp.status_code == 200
    payload = resp.json()
    assert "voices" in payload
    assert isinstance(payload["voices"], list)
    assert len(payload["voices"]) > 0


def test_audio_speech_returns_bytes():
    resp = httpx.post(
        f"{VOICE_SERVER}/v1/audio/speech",
        json={"model": "sayitdev-on-device", "input": "Hello", "response_format": "wav"},
        timeout=30,
    )
    assert resp.status_code == 200
    assert len(resp.content) > 44
    assert resp.headers.get("content-type", "").startswith("audio/")
