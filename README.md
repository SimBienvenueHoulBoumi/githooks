# githooks

Hooks git réutilisables, qui s'adaptent au langage du projet.

## Installation

```bash
git clone git@github.com:SimBienvenueHoulBoumi/githooks.git ~/Desktop/Bureau/projets/githooks
cd ~/Desktop/Bureau/projets/githooks

./install.sh --global       # tous les dépôts de la machine
# ou, dans un projet :
/chemin/vers/githooks/install.sh   # ce dépôt uniquement
```

Mise à jour : `git pull` dans ce dépôt, aucun projet à toucher.

## Hooks

| Hook | Rôle |
|---|---|
| `pre-commit` | Bloque les commits directs sur `main`/`master`, détecte les secrets (gitleaks), formate les fichiers stagés |
| `commit-msg` | Impose [Conventional Commits](https://www.conventionalcommits.org) (`feat(scope): …`), 72 caractères max |
| `pre-push` | Build et tests complets |

## Détection du langage

À partir des fichiers à la racine du dépôt (plusieurs langages possibles) :

| Fichier | Formatage (pre-commit) | Tests (pre-push) |
|---|---|---|
| `pom.xml` | `mvnw spotless:apply` (si Spotless configuré) | `mvnw verify` |
| `build.gradle(.kts)` | `gradlew spotlessApply` (si Spotless configuré) | `gradlew check` |
| `package.json` | `prettier` de `node_modules` | `npm test` |
| `pyproject.toml` / `setup.py` / `requirements.txt` | `ruff format`, sinon `black` | `pytest` |
| `go.mod` | `gofmt` | `go test ./...` |
| `Cargo.toml` | `cargo fmt` | `cargo test` |

Un outil absent est ignoré avec un avertissement, jamais bloquant.

## Configuration par projet

```bash
git config hooks.skip true                    # désactive tout
git config hooks.skip "pre-push"              # désactive un hook
git config hooks.skip "protect-branch,format" # désactive des étapes
git config hooks.protectedBranches "main develop"   # défaut : "main master"
```

Étapes désactivables : `protect-branch`, `secrets`, `format`, `tests`.

Contournement ponctuel : `git commit --no-verify`, `git push --no-verify`.

## Hooks spécifiques à un projet

Un script exécutable dans `.githooks/<hook>` ou `.git/hooks/<hook>` du projet est lancé en plus, avant les vérifications communes.

## Limites

- Un `core.hooksPath` local (husky, etc.) est prioritaire sur l'installation globale.
- Un fichier partiellement stagé est re-stagé entièrement après formatage.
