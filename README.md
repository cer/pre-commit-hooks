# pre-commit-hooks

Shared [pre-commit](https://pre-commit.com) hooks, the gitleaks configuration they scan with, and
template configurations for a new project.

A project refers to these hooks by id. It does not copy them, and it does not need a gitleaks
configuration of its own.

## The hooks

| Id | Stage | What it does |
|---|---|---|
| `gitleaks-staged` | `pre-commit` | Runs gitleaks on the staged changes |
| `gitleaks-commit-message` | `commit-msg` | Runs gitleaks on the commit message |
| `block-claude-coauthor` | `commit-msg` | Refuses a message containing the Anthropic co-author address |
| `shellcheck` | `pre-commit` | Runs shellcheck on each staged shell script |

Both gitleaks hooks scan with [`gitleaks.toml`](gitleaks.toml) from this repository. It loads
gitleaks' default secret rules and adds rules for a home directory path, written in full or with a
tilde, and for a file under `.hitl`.

The hooks run programs installed on the machine, and download none:

- the gitleaks hooks run `gitleaks`: see
  [installing gitleaks](https://github.com/gitleaks/gitleaks#installing)
- the shellcheck hook runs `shellcheck`: see
  [installing shellcheck](https://github.com/koalaman/shellcheck#installing)

So the version of each is the one the machine has. A project passes shellcheck options with
`args`, for example `args: [-x]` to follow sourced files.

## Using the hooks in a project

Copy the template that fits the project to `.pre-commit-config.yaml`:

| Template | For |
|---|---|
| [`templates/base.pre-commit-config.yaml`](templates/base.pre-commit-config.yaml) | Any project: the four hooks |
| [`templates/kotlin-gradle.pre-commit-config.yaml`](templates/kotlin-gradle.pre-commit-config.yaml) | Kotlin or Java built with Gradle |
| [`templates/python-uv.pre-commit-config.yaml`](templates/python-uv.pre-commit-config.yaml) | Python run with uv |
| [`templates/typescript-npm.pre-commit-config.yaml`](templates/typescript-npm.pre-commit-config.yaml) | TypeScript built with npm |

Then install both hook types, because two of the hooks run at the commit message stage:

```
pre-commit install --hook-type pre-commit --hook-type commit-msg
```

The part every template shares is:

```yaml
repos:
  - repo: https://github.com/cer/pre-commit-hooks
    rev: v1.1.0
    hooks:
      - id: gitleaks-staged
      - id: gitleaks-commit-message
      - id: block-claude-coauthor
      - id: shellcheck
```

## A project's own gitleaks rules

A project that needs a rule the shared configuration does not have puts it in a `.gitleaks.toml`
at its root. When that file exists, each gitleaks hook scans twice: with the shared configuration,
then with the project's. The project's file contains only its own rules.

A project that needs to permit one specific finding lists it in a `.gitleaksignore` file at its
root, which gitleaks reads.

## Changing a hook or a rule

1. Change the script under `bin/` or the rule in `gitleaks.toml`.
2. Add a check for it to `test/test-hooks.sh` and run the script.
3. Commit, tag a new version and push the tag.
4. In each project, run `pre-commit autoupdate --repo https://github.com/cer/pre-commit-hooks`
   and commit the changed `rev`.

A project gets a change only when its `rev` is updated.

## Testing

```
test/test-hooks.sh
```

It calls each hook script directly, then runs all four through pre-commit in a scratch project
that uses a copy of this checkout as its hooks repository. It needs gitleaks, shellcheck and
pre-commit.
