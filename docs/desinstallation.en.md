# Uninstalling

`install.sh --uninstall` only removes **repogarde's** hooks: a `core.hooksPath` pointing to another tool (husky…) is left untouched, with a warning.

## Global installation (all repositories on the machine)

```bash
~/repogarde/install.sh --uninstall --global
```

Full uninstall, removing the caches (`~/.cache/repogarde`) and listing the repositories still wired to repogarde:

```bash
~/repogarde/install.sh --uninstall --global --purge --scan ~/projets
```

The script **lists** the affected repositories and the command to run for each one, without modifying them. At the end, it prints the command to delete the repogarde directory, for you to run yourself.

## A single repository

```bash
cd mon-projet
~/repogarde/install.sh --uninstall
```

## Project configured with lefthook

```bash
cd mon-projet
lefthook uninstall
```

Then remove the repogarde `remotes` entry from `lefthook.yml`, or the file itself.
