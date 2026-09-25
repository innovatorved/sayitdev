"""Guard against reintroducing unreplaced upstream placeholders."""

import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIP_DIRS = {".build", ".git", "Package.resolved"}
PLACEHOLDERS = ("__UPSTREAM_DEV_URL__", "__UPSTREAM_DEV_REPO__")


@pytest.fixture(scope="session", autouse=True)
def guard_server_11434():
    yield


@pytest.fixture(scope="session", autouse=True)
def guard_server_11435():
    yield


def _tracked_text_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix in {".png", ".jpg", ".jpeg", ".gif", ".webp", ".gz", ".tar", ".zip"}:
            continue
        yield path


def test_no_upstream_placeholders_remain():
    offenders = []
    for path in _tracked_text_files():
        if path.name == "test_rebrand_guard.py":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue
        if any(p in text for p in PLACEHOLDERS):
            offenders.append(str(path.relative_to(ROOT)))
    assert offenders == [], f"unreplaced upstream placeholders: {offenders}"
