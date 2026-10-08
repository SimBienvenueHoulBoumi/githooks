# Uninstalling

`repogarde uninstall` only removes **repogarde's** hooks: a `core.hooksPath` pointing to another tool (husky…) is left untouched, with a warning.

## Global installation (all repositories on the machine)

```bash
repogarde uninstall --global
npm uninstall -g @simbie/repogarde
```

In this order: npm runs nothing when uninstalling, and hooks wired to a deleted package silently stop firing. `repogarde` (status) shows what is still active.

Full uninstall, removing the caches (`~/.cache/repogarde`) and listing the repositories still wired to repogarde:

```bash
repogarde uninstall --global --purge --scan ~/projets
```

The command **lists** the affected repositories and the command to run for each one, without modifying them. At the end, it prints the last command to run yourself: `npm uninstall -g @simbie/repogarde`, or deleting the directory for a clone installation.

Clone installation: same commands with `~/repogarde/install.sh --uninstall` instead of `repogarde uninstall`.

## A single repository

```bash
cd my-project
repogarde uninstall
```

## Project configured with lefthook

```bash
cd my-project
lefthook uninstall
```

Then remove the repogarde `remotes` entry from `lefthook.yml`, or the file itself.
