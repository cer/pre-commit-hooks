#!/bin/bash -e
#
# The block-claude-coauthor hook: refuses a commit message that contains the
# Anthropic co-author address.
#
#   block-claude-coauthor.sh <commit message file>

message_file="${1:?usage: block-claude-coauthor.sh <commit message file>}"

if grep -q "noreply@anthropic.com" "$message_file"; then
    echo "Commit message contains noreply@anthropic.com. Use the idea-to-code:commit-guidelines skill for the correct commit message format."
    exit 1
fi
