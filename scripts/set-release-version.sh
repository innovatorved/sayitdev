#!/usr/bin/env bash
# Set a version as part of the automated release workflow (for a fresh line).
set -euo pipefail

version="${1:-}"
version_file="${2:-.version}"

if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "error: version must be strict X.Y.Z semver (got '$version')" >&2
    exit 2
fi

[[ -f "$version_file" ]] || { echo "error: version file not found: $version_file" >&2; exit 2; }
printf '%s\n' "$version" > "$version_file"
echo "Version reset to $version"
