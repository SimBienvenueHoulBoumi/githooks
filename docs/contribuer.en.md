# Contributing

## Setup

```bash
brew install bats-core shellcheck actionlint gitleaks lefthook   # or apt / winget equivalents
./install.sh   # repogarde hooks on this repository (it tests itself)
```

## Before each PR

```bash
shellcheck bin/* ci/*.sh hooks/pre-commit hooks/prepare-commit-msg hooks/commit-msg hooks/pre-push hooks/post-checkout hooks/post-merge hooks/lib/*.sh hooks/lang/*.sh install.sh .lefthook/*/repogarde
actionlint .github/workflows/*.yml
bats test/                      # unit and integration tests
test/e2e/run.sh python go       # real-world tests (languages whose tooling is installed)
```

The CI re-runs everything on Linux, macOS and Windows, plus one e2e job per language with its real tooling.

## Conventions

- **Branches**: `<type>/<topic>` (`feat/helm-unittest`, `fix/windows-paths`).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org). The type determines the published version: `fix` → patch, `feat` → minor, `!` → major.
- **Bash 3.2** (macOS): no associative arrays and no `mapfile`. In functions called per file, no subprocesses (`$(…)`): return the result in `REPLY`.
- **ASCII bats test names** (bats on Windows ignores others). In `languages.bats`, the name starts with a prefix covered by the Windows filters in `ci.yml` (`detection`, `format`, `pre-push`…): a test checks that none is missed.
- **Performance**: each process creation costs 20 to 50 ms on Windows. Read the config with `cfg_r` (no subshell), reuse `GIT_TOPLEVEL`, avoid `$(…)` in loops.
- A missing tool is **never blocking** on the developer machine (`warn` / `tool_missing`); the CI's strict mode makes it blocking.

## Adding a language or a tool

1. `hooks/lang/<name>.sh`: `register`, `<name>_format`, `<name>_test` (see `docs/technologies.md`).
2. `test/e2e/<name>/`: `project/` (clean), `bad/` (badly formatted), `break/` (broken tests), `keep/` (must not be modified), `e2e.env`.
3. Add `<name>` to the matrix in `.github/workflows/e2e.yml` with the installation of its tooling.
4. Update the table in `docs/technologies.md`.

## Branches and releases

- PRs target **`develop`** (default branch); a PR opened against `main` is retargeted automatically. Only urgent fixes (`hotfix/…`) may target `main`.
- A **delivery PR** `develop` → `main` is kept up to date on every merge (upcoming version, notes). Merging it, as a merge commit, starts the release: release PR (changelog, version files), tag, npm, site. `main` then flows back into `develop` automatically.
- Details: [Versions and releases, cycle mode](releases.md#develop-main-cycle-with-version-files-cycle-mode).
