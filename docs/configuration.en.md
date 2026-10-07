# Configuration

Everything is optional: without configuration, repogarde detects the languages and applies the default rules.

## `.repogarde.conf` file (shared)

Versioned at the project root, in `git config` format, read **by the hooks and by the CI**: an exception agreed during review applies everywhere.

```ini
[repogarde]
    # Custom commands: replace automatic detection
    format = npm run lint:fix --        # receives the staged files as arguments
    test = make ci                      # run at the root; modified files on standard input
    # Settings
    skip = protect-branch python        # disabled steps, hooks or languages
    protectedBranches = main develop    # direct commit and push forbidden; default: main master
    allowedBranches = main develop release/*
    exclude = vendor/* generated/*      # paths neither formatted nor tested
```

## Integration branch flow (`develop`)

By default, everything starts from `main` and returns to it through a PR. For a flow with two long-lived branches, where work is integrated into `develop` and then delivered to `main`:

```ini
[repogarde]
    integrationBranch = develop     # enables the flow
    mainBranch = main               # default: main
    protectedBranches = main develop
    allowedBranches = main develop release/* release-please--* dependabot/* renovate/*
```

The CI then checks the target of each PR:

| PR branch                                       | Expected target      |
| ----------------------------------------------- | -------------------- |
| work (`feat/…`, `fix/…`), bots (`dependabot/…`) | `develop`            |
| `develop`                                       | `main`               |
| `release/…`, `hotfix/…`                         | `main` or `develop`  |

A wrongly targeted PR is rejected, with the command to fix it (`gh pr edit --base develop`). With the action's `fix-pr: true` input, it is **retargeted automatically** (or closed if a PR from the same branch already targets the right branch), and a non-compliant title is replaced: by the compliant commit with the highest version impact (breaking, then `feat`, then `fix`/`perf`; "!" added if a `BREAKING CHANGE` footer exists), otherwise derived from the branch.

## Local settings (not shared)

Take precedence over `.repogarde.conf`:

```bash
git config repogarde.skip true                    # disables everything
git config repogarde.skip "pre-push"              # disables a hook
git config repogarde.skip "protect-branch,format" # disables steps
git config repogarde.skip "node"                  # disables a language
```

## What can be disabled (`skip`)

| Category            | Values                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| Hooks               | `pre-commit`, `prepare-commit-msg`, `commit-msg`, `pre-push`, `post-checkout`, `post-merge`      |
| Steps               | `branch-name`, `protect-branch`, `secrets`, `format`, `tests`, `deadcode`, `prune-branches`                  |
| Languages and tools | `maven`, `gradle`, `node`, `python`, `go`, `helm`, `docker`… (file name in `hooks/lang/`)        |
| Everything          | `true`                                                                                           |

## Project-specific hooks

An executable script `.repogarde/<hook>` (or `.git/hooks/<hook>`) is also run, before the common checks. With lefthook, declare the project's jobs in `lefthook.yml` instead.

## Output

All repogarde messages (hooks, CI, `git cc` assistant, installation) follow the same style: `✔` success in green, `✖` error in red, `⚠` warning in yellow, `ℹ` information in blue, `▶` step in progress in cyan, hints in dimmed grey.

Colours are displayed in a terminal and in the GitHub action logs. They are disabled by `NO_COLOR=1`, by `TERM=dumb` or when the output is redirected (file, pipe); `FORCE_COLOR=1` forces them.

## Message language

French or English, chosen **once at installation** (prompted, or `./install.sh --global --lang en`) and stored in `repogarde.lang`. Order of precedence:

| Where | Language used |
|---|---|
| Developer machine | `REPOGARDE_LANG`, otherwise `repogarde.lang` (installation), otherwise `lang` from `.repogarde.conf`, otherwise the system language |
| CI | `REPOGARDE_LANG`, otherwise `lang` from `.repogarde.conf` (team language), otherwise English |

## Platform (GitHub, GitLab, Bitbucket, Gitea)

repogarde recognises the platform and adapts its vocabulary (PR or MR) and its examples (`Closes #12`, `!34` on GitLab, `PROJ-42` on Bitbucket): `forge` setting, otherwise CI variables (GitHub Actions, GitLab CI, Bitbucket Pipelines, Gitea / Forgejo Actions), otherwise the URL of the `origin` remote. A self-hosted GitLab whose URL does not contain "gitlab" is declared as follows:

```ini
[repogarde]
    forge = gitlab        # github, gitlab, bitbucket, gitea
```
