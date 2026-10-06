# Migration depuis githooks

Le projet s'appelait **githooks** jusqu'à la v1. Les anciennes adresses GitHub sont redirigées et les anciens noms **restent acceptés**, avec un message de migration jamais bloquant (même en mode strict).

| Ancien (githooks ≤ v1) | Nouveau (repogarde v2) |
|---|---|
| `.githooks.conf`, section `[hooks]` | `.repogarde.conf`, section `[repogarde]` |
| `git config hooks.skip …` | `git config repogarde.skip …` |
| variables `GITHOOKS_*` | `REPOGARDE_*` |
| dossier `.githooks/<hook>` | `.repogarde/<hook>` |
| `uses: …/githooks@v1`, job CI `githooks` | `uses: …/repogarde@v2`, job `repogarde` |
| `~/.cache/githooks` | `~/.cache/repogarde` |

## Migrer un projet

1. Renommer `.githooks.conf` en `.repogarde.conf` et sa section `[hooks]` en `[repogarde]`.
2. Dans `lefthook.yml`, pointer `git_url` sur `…/repogarde` et `ref` sur la v2.
3. Dans le workflow, `uses: SimBienvenueHoulBoumi/repogarde@v2` et renommer le job en `repogarde`.
4. Si la protection de branche exige le check `githooks`, lui faire exiger `repogarde`.

Installation globale : `install.sh --global` depuis le nouveau dossier.
