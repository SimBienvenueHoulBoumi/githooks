# Migrating from githooks

The project was called **githooks** up to v1. The old GitHub URLs redirect, and the old names **are still accepted**, with a migration message that never blocks (even in strict mode).

| Old (githooks ≤ v1) | New (repogarde v2) |
|---|---|
| `.githooks.conf`, section `[hooks]` | `.repogarde.conf`, section `[repogarde]` |
| `git config hooks.skip …` | `git config repogarde.skip …` |
| `GITHOOKS_*` variables | `REPOGARDE_*` |
| `.githooks/<hook>` directory | `.repogarde/<hook>` |
| `uses: …/githooks@v1`, CI job `githooks` | `uses: …/repogarde@v2`, job `repogarde` |
| `~/.cache/githooks` | `~/.cache/repogarde` |

## Migrating a project

1. Rename `.githooks.conf` to `.repogarde.conf` and its `[hooks]` section to `[repogarde]`.
2. In `lefthook.yml`, point `git_url` to `…/repogarde` and `ref` to v2.
3. In the workflow, use `uses: SimBienvenueHoulBoumi/repogarde@v2` and rename the job to `repogarde`.
4. If branch protection requires the `githooks` check, make it require `repogarde` instead.

Global installation: run `install.sh --global` from the new directory.
