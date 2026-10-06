# CI : GitHub et GitLab

La CI refait toutes les vérifications des hooks sur chaque PR / MR : **c'est elle qui fait foi** (les hooks locaux se contournent avec `--no-verify`).

## Ce qui est vérifié

| Vérification | Échoue si |
|---|---|
| `commits` | un message n'est pas Conventional Commits, dépasse 72 caractères, ou est un `fixup!`/`squash!` non squashé ; **titre de la PR** non conforme (il devient le message du commit en squash) |
| `branch` | le nom de branche ne respecte pas `<type>/<sujet>` (hors exceptions) |
| `secrets` | gitleaks trouve un secret dans les commits de la branche |
| `format` | un fichier modifié n'est pas formaté (le formateur est lancé, rien n'est committé) |
| `tests` | les tests d'un projet touché échouent (monorepo : seulement les projets modifiés) |

Les erreurs apparaissent en annotations sur GitHub et dans le log du job sur GitLab, avec la commande de correction.

## GitHub Actions

```yaml title=".github/workflows/repogarde.yml"
name: repogarde
on:
  pull_request:
    types: [opened, synchronize, reopened, edited] # edited : titre de PR revérifié
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  repogarde:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      # Outils du projet (formatage, tests), ex. :
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install ruff pytest
      - uses: SimBienvenueHoulBoumi/repogarde@v2 # x-release-please-major
        with:
          strict: true
```

| Entrée | Défaut | Rôle |
|---|---|---|
| `checks` | `commits branch secrets format tests` | vérifications lancées |
| `strict` | `false` | un outil de formatage / test absent fait échouer |
| `megalinter` | `false` | lance aussi MegaLinter |
| `gitleaks-version` | `8.30.1` | version installée (somme SHA-256 vérifiée) |
| `actionlint-version` | `1.7.12` | version installée pour vérifier les workflows |

## GitLab CI

```yaml title=".gitlab-ci.yml"
include:
  - project: outils/repogarde                # repogarde hébergé sur votre GitLab
    ref: v2.2.0 # x-release-please-version
    file: templates/gitlab/repogarde.gitlab-ci.yml

repogarde:
  image: python:3.12                         # image avec bash, git, curl et les outils du projet
  variables:
    REPOGARDE_STRICT: "true"
  before_script:
    - pip install ruff pytest
```

Variables : `REPOGARDE_CHECKS`, `REPOGARDE_STRICT`, `REPOGARDE_MEGALINTER`, `REPOGARDE_URL`, `REPOGARDE_REF`, `GITLEAKS_VERSION`.

## Mode strict

Sur le poste, un outil absent est ignoré. En CI avec `strict`, il fait **échouer** la vérification : l'image de CI doit contenir l'outillage du projet. repogarde installe lui-même gitleaks et actionlint (versions figées, sommes vérifiées).

## MegaLinter

Les linters (ESLint, Checkstyle, golangci-lint…) sont délégués à [MegaLinter](https://megalinter.io) plutôt que réimplémentés : `megalinter: true` (GitHub) ou `REPOGARDE_MEGALINTER: "true"` (GitLab). Seuls les fichiers modifiés sont analysés ; configuration dans le `.mega-linter.yml` du projet.

## Règles côté serveur

Pour que les règles soient **non contournables** :

| Hébergeur | Où | Disponibilité |
|---|---|---|
| GitHub | *Settings → Rules → Rulesets* : exiger le check `repogarde`, interdire le push forcé ; « Restrict branch names », « Restrict commit metadata » | gratuit sur dépôt public, Pro / Team sur dépôt privé |
| GitLab | *Protected branches*, *Pipelines must succeed* ; *Push rules* (Premium) | selon offre |
| Bitbucket | *Branch restrictions* | selon offre |

Expressions régulières à reporter :

```text
# Nom de branche
^((feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|feature|bugfix|hotfix)/[a-z0-9._-]+(/[a-z0-9._-]+)*|main|master|develop|release/.+)$

# Message de commit
^((feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._-]+\))?!?: .+|Merge .+|Revert .+)
```
