#!/bin/bash
#
# Tests the hooks: each script called directly, then all three through pre-commit in a
# scratch project that uses a copy of this checkout as its hooks repository.
#
#   test/test-hooks.sh
#
# Exits 1 when any check fails. Needs gitleaks and pre-commit.

set -u

# Run as a pre-commit hook, this script inherits GIT_DIR and GIT_INDEX_FILE from the
# commit in progress, and every git command below would then work on the repository being
# committed to and not on the scratch one it names.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

HOOKS="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
export PRE_COMMIT_HOME="$SCRATCH/pre-commit-cache"

FAILURES=0

# Assembled so that this file contains no home directory path or co-author address itself.
HOME_PATH="/Us""ers/someone/project"
COAUTHOR="Co-Authored-By: Claude <noreply@""anthropic.com>"

check() {
    local expected="$1" description="$2"
    shift 2
    local actual=accepted
    "$@" > "$SCRATCH/output" 2>&1 || actual=refused
    if [ "$actual" = "$expected" ]; then
        echo "ok    $description"
    else
        echo "FAIL  $description: expected $expected, was $actual"
        sed 's/^/      /' "$SCRATCH/output"
        FAILURES=$((FAILURES + 1))
    fi
}

message_file() {
    local file="$SCRATCH/message-$RANDOM"
    echo "$1" > "$file"
    echo "$file"
}

new_project() {
    local project="$SCRATCH/$1"
    git init -q -b main "$project"
    git -C "$project" config user.email "test@example.com"
    git -C "$project" config user.name "Test"
    echo "$project"
}

in_project() {
    local project="$1"
    shift
    (cd "$project" && "$@")
}

stage_file() {
    local project="$1" content="$2"
    echo "$content" > "$project/file-$RANDOM.txt"
    git -C "$project" add -A
}

# A project's own configuration: one rule, for a word the shared configuration allows.
project_rule() {
    cat > "$1/.gitleaks.toml" <<'TOML'
[[rules]]
id = "project-forbidden-word"
description = "A word this project forbids"
regex = '''frobulate'''
TOML
}

test_commit_message_script() {
    local project
    project=$(new_project message-script)
    check accepted "commit message script accepts a clean message" \
        in_project "$project" "$HOOKS/bin/gitleaks-commit-message.sh" "$(message_file "A clean message")"
    check refused "commit message script refuses a home directory path" \
        in_project "$project" "$HOOKS/bin/gitleaks-commit-message.sh" "$(message_file "Names $HOME_PATH")"
    check accepted "commit message script accepts a word no rule forbids" \
        in_project "$project" "$HOOKS/bin/gitleaks-commit-message.sh" "$(message_file "frobulate")"
    project_rule "$project"
    check refused "commit message script applies the project's own rule" \
        in_project "$project" "$HOOKS/bin/gitleaks-commit-message.sh" "$(message_file "frobulate")"
    check refused "commit message script still applies the shared rules beside the project's" \
        in_project "$project" "$HOOKS/bin/gitleaks-commit-message.sh" "$(message_file "Names $HOME_PATH")"
}

test_staged_script() {
    local clean dirty own
    clean=$(new_project staged-clean)
    stage_file "$clean" "nothing to report"
    check accepted "staged script accepts a clean change" \
        in_project "$clean" "$HOOKS/bin/gitleaks-staged.sh"

    dirty=$(new_project staged-dirty)
    stage_file "$dirty" "path $HOME_PATH"
    check refused "staged script refuses a home directory path" \
        in_project "$dirty" "$HOOKS/bin/gitleaks-staged.sh"

    own=$(new_project staged-own-rule)
    project_rule "$own"
    stage_file "$own" "frobulate"
    check refused "staged script applies the project's own rule" \
        in_project "$own" "$HOOKS/bin/gitleaks-staged.sh"
}

test_coauthor_script() {
    check accepted "co-author script accepts a clean message" \
        "$HOOKS/bin/block-claude-coauthor.sh" "$(message_file "A clean message")"
    check refused "co-author script refuses the Anthropic co-author address" \
        "$HOOKS/bin/block-claude-coauthor.sh" "$(message_file "$COAUTHOR")"
}

# pre-commit clones a hooks repository at a commit, so the working tree is committed
# into a scratch copy for it to clone.
hooks_repository_from_working_tree() {
    local copy="$SCRATCH/hooks-copy"
    mkdir "$copy"
    (cd "$HOOKS" && tar cf - --exclude .git .) | (cd "$copy" && tar xf -)
    git init -q -b main "$copy"
    git -C "$copy" add -A
    git -C "$copy" -c user.email=test@example.com -c user.name=Test -c core.hooksPath=/dev/null commit -q -m "working tree"
    echo "$copy"
}

project_using_hooks() {
    local hooks_copy="$1" project
    project=$(new_project through-pre-commit)
    cat > "$project/.pre-commit-config.yaml" <<YAML
repos:
  - repo: $hooks_copy
    rev: $(git -C "$hooks_copy" rev-parse HEAD)
    hooks:
      - id: gitleaks-staged
      - id: gitleaks-commit-message
      - id: block-claude-coauthor
YAML
    in_project "$project" pre-commit install --hook-type pre-commit --hook-type commit-msg > /dev/null
    git -C "$project" add -A
    echo "$project"
}

test_through_pre_commit() {
    local project
    project=$(project_using_hooks "$(hooks_repository_from_working_tree)")
    check refused "through pre-commit: a home directory path in the message is refused" \
        git -C "$project" commit -m "Names $HOME_PATH"
    check refused "through pre-commit: the Anthropic co-author address is refused" \
        git -C "$project" commit -m "$COAUTHOR"
    check accepted "through pre-commit: a clean commit is accepted" \
        git -C "$project" commit -m "A clean commit"
    stage_file "$project" "path $HOME_PATH"
    check refused "through pre-commit: a home directory path in a staged file is refused" \
        git -C "$project" commit -m "A clean message"
}

test_commit_message_script
test_staged_script
test_coauthor_script
test_through_pre_commit

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES failed"
    exit 1
fi
echo "all passed"
