# Uninstalling

`repowarden uninstall` only removes **repowarden's** hooks: a `core.hooksPath` pointing to another tool (husky…) is left untouched, with a warning.

## Global installation (all repositories on the machine)

```bash
repowarden uninstall --global
npm uninstall -g repowarden
```

In this order: npm runs nothing when uninstalling, and hooks wired to a deleted package silently stop firing. `repowarden` (status) shows what is still active.

Full uninstall, removing the caches (`~/.cache/repowarden`) and listing the repositories still wired to repowarden:

```bash
repowarden uninstall --global --purge --scan ~/projets
```

The command **lists** the affected repositories and the command to run for each one, without modifying them. At the end, it prints the last command to run yourself: `npm uninstall -g repowarden`, or deleting the directory for a clone installation.

Clone installation: same commands with `~/repowarden/install.sh --uninstall` instead of `repowarden uninstall`.

## A single repository

```bash
cd my-project
repowarden uninstall
```

## Project still configured with lefthook (repowarden 3)

```bash
cd my-project
lefthook uninstall
```

Then remove the repowarden `remotes` entry from `lefthook.yml`, or the file itself. Since repowarden 4, lefthook is no longer supported: the project's own commands go in `.repowarden/<hook>` ([Configuration](configuration.md#project-specific-hooks)).
