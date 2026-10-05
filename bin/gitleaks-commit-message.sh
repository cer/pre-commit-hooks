#!/bin/bash -e
#
# The gitleaks-commit-message hook: scans the commit message in the file given.
#
#   gitleaks-commit-message.sh <commit message file>

# shellcheck source=bin/gitleaks-configs.sh
source "$(dirname "$0")/gitleaks-configs.sh"

message_file="${1:?usage: gitleaks-commit-message.sh <commit message file>}"

for config in "${GITLEAKS_CONFIGS[@]}"; do
    gitleaks stdin --config "$config" --no-banner --verbose < "$message_file"
done
