"""
dev Integration Tests - release pipeline wiring (static, model-free).

These tests assert structural facts about the release scripts and CI so a
regression in the release plumbing is caught without cutting a real release.

Covered:
- #269: previous-tag selection must use a fixed-string, whole-line filter
  (`grep -Fxv`) so re-publishing vX.Y.Z when vX.Y.Z0+ exists does not filter
  those tags out of the release-notes commit range.
- #225: the divergent `workflow_dispatch` release path (publish-release.yml)
  must not exist - CLAUDE.md mandates local releases because GitHub-hosted
  runners lack Apple Intelligence, and the stale workflow could publish an
  unqualified release.
"""

import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
PUBLISH = ROOT / "scripts" / "publish-release.sh"


def test_prev_tag_uses_fixed_string_whole_line_filter():
    """#269: publish-release.sh must filter the current tag with grep -Fxv."""
    text = PUBLISH.read_text()
    assert 'grep -Fxv "v$version"' in text, (
        "publish-release.sh must select the previous tag with "
        "`grep -Fxv \"v$version\"` (fixed-string, whole-line) so re-publishing "
        "v1.6.1 does not also filter out v1.6.10+ (#269)"
    )
    # The unanchored substring form must be gone.
    assert 'grep -v "v$version"' not in text, (
        "publish-release.sh still uses the unanchored `grep -v \"v$version\"` "
        "which filters v1.6.10+ as substrings of v1.6.1 (#269)"
    )


def test_no_divergent_dispatch_release_workflow():
    """#225: the stale workflow_dispatch release path must be deleted."""
    stale = ROOT / ".github" / "workflows" / "publish-release.yml"
    assert not stale.exists(), (
        "'.github/workflows/publish-release.yml' is a divergent dispatch path "
        "that can publish an unqualified release (no server-readiness gate, no "
        "CHANGELOG stamp, no nixpkgs bump) on a runner without Apple "
        "Intelligence; CLAUDE.md mandates local releases only (#225)"
    )


def test_full_build_jobs_use_xcode_27_sdk():
    """FoundationModels reasoning and image attachment APIs need the macOS 27 SDK."""
    ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text()
    release = (ROOT / ".github" / "workflows" / "release.yml").read_text()
    assert "build-and-test:\n    runs-on: xcode-27" in ci
    assert "build-and-release:\n    runs-on: xcode-27" in release
    assert "xcode=/Applications/Xcode_27.0.app" in ci
    assert "xcode=/Applications/Xcode_27.0.app" in release
    assert "git describe --tags --abbrev=0 2>/dev/null || true" in ci


def test_release_version_reset_validates_before_writing(tmp_path):
    """A fresh release line can reset version only through the release helper."""
    helper = ROOT / "scripts" / "set-release-version.sh"
    version_file = tmp_path / ".version"
    version_file.write_text("2.0.0\n")

    valid = subprocess.run(
        ["bash", str(helper), "1.0.0", str(version_file)],
        capture_output=True,
        text=True,
    )
    assert valid.returncode == 0, valid.stderr
    assert version_file.read_text() == "1.0.0\n"

    invalid = subprocess.run(
        ["bash", str(helper), "1.0", str(version_file)],
        capture_output=True,
        text=True,
    )
    assert invalid.returncode != 0
    assert version_file.read_text() == "1.0.0\n"


def test_reset_release_prunes_drafts():
    text = PUBLISH.read_text()
    assert 'gh release delete "$draft" --yes --cleanup-tag' in text


def test_release_suite_runs_homebrew_service_checks_from_local_binary():
    text = PUBLISH.read_text()
    assert "--ignore=Tests/integration/test_brew_service.py" in text
    assert "scripts/test-homebrew-release.sh" in text
