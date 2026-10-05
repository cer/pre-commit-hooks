#!/bin/bash -e
#
# The gitleaks-staged hook: scans the staged changes of the repository it runs in.

# shellcheck source=bin/gitleaks-configs.sh
source "$(dirname "$0")/gitleaks-configs.sh"

for config in "${GITLEAKS_CONFIGS[@]}"; do
    gitleaks git --pre-commit --staged --config "$config" --no-banner --verbose
done
