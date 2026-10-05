# shellcheck shell=bash
#
# Sourced by the gitleaks hooks. Sets GITLEAKS_CONFIGS to the configurations a scan
# runs with, in order: the shared gitleaks.toml beside these scripts, then the
# project's own .gitleaks.toml when the directory the hook runs in has one.
#
# gitleaks can extend a configuration only from a path on disk, and a project cannot
# name a path inside pre-commit's cache. So a project's own rules are a second scan
# rather than an extension of the shared file.

shared_config="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gitleaks.toml"

GITLEAKS_CONFIGS=("$shared_config")
if [ -f .gitleaks.toml ]; then
    GITLEAKS_CONFIGS+=(.gitleaks.toml)
fi

command -v gitleaks > /dev/null || {
    echo "gitleaks is not installed: see https://github.com/gitleaks/gitleaks#installing" >&2
    exit 1
}
