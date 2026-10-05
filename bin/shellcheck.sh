#!/bin/bash -e
#
# The shellcheck hook: runs the shellcheck installed on the machine on the files given.
# It takes shellcheck's own options, then the files.

command -v shellcheck > /dev/null || {
    echo "shellcheck is not installed: see https://github.com/koalaman/shellcheck#installing" >&2
    exit 1
}

exec shellcheck "$@"
