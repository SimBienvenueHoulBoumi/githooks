# Versions et releases

Les commits d'un projet repogarde sont conventionnels : la version suivante et le changelog s'en déduisent. Un workflow réutilisable en fait des **releases automatiques**, sans jeton à créer ni étape manuelle.

## Mise en place

```yaml title=".github/workflows/release.yml"
name: release

on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: release
  cancel-in-progress: false

permissions: {}

jobs:
  release:
    uses: SimBienvenueHoulBoumi/repogarde/.github/workflows/release-auto.yml@v2 # x-release-please-major
    permissions:
      contents: write
      pull-requests: write
      actions: write
      checks: read
      statuses: write
```

Modèle complet : [`templates/project/.github/workflows/release.yml`](https://github.com/SimBienvenueHoulBoumi/repogarde/blob/main/templates/project/.github/workflows/release.yml).

Deux prérequis :

1. *Settings → Actions → General → Workflow permissions* : cocher **Allow GitHub Actions to create and approve pull requests** ;
2. les workflows de CI du projet acceptent `workflow_dispatch` (déjà le cas du modèle `repogarde.yml`) : c'est ainsi que la CI est lancée sur la PR de release.

## Fonctionnement

| Commits depuis la dernière release | Nouvelle version |
|---|---|
| `fix:`, `perf:` | correctif : 1.4.**2** → 1.4.**3** |
| `feat:` | fonctionnalité : 1.**4**.2 → 1.**5**.0 |
| `feat!:` ou `BREAKING CHANGE:` en pied | majeure : **1**.4.2 → **2**.0.0 |
| `ci:`, `chore:`, `test:`, `refactor:`, `style:` | aucune release |

`docs:` déclenche un correctif seulement si sa section est visible dans le changelog (configuration).

À chaque push sur `main` :

1. [release-please](https://github.com/googleapis/release-please) ouvre ou met à jour la PR « release x.y.z » : changelog et version dans le fichier du projet ;
2. la CI du projet est lancée sur cette PR ; une fois verte, la PR est mergée (squash). Si `main` avance entre-temps, la PR est mise à jour et revalidée ;
3. le tag `vX.Y.Z` et la release GitHub sont créés.

Les vérifications exigées par la protection de `main` restent obligatoires : sans CI verte, rien n'est mergé.

## Fichier de version

Le type de projet est détecté d'après les fichiers à la racine :

| Fichier | Version mise à jour dans |
|---|---|
| `pom.xml` | `pom.xml` (Maven) |
| `package.json` | `package.json`, `package-lock.json` |
| `pyproject.toml`, `setup.py` | `pyproject.toml` / `setup.py` |
| `Cargo.toml` | `Cargo.toml`, `Cargo.lock` |
| `Chart.yaml` | `Chart.yaml` (Helm) |
| `go.mod` | aucun : le tag fait la version |
| `composer.json`, `pubspec.yaml`, `mix.exs` | fichier correspondant |
| autre | `version.txt` |

!!! tip "Changelog en français, monorepo, options"
    Un fichier `release-please-config.json` à la racine (avec `.release-please-manifest.json`) prend le pas sur la détection : sections du changelog, plusieurs paquets, fichiers supplémentaires à versionner… Voir la [configuration de repogarde](https://github.com/SimBienvenueHoulBoumi/repogarde/blob/main/release-please-config.json) pour un exemple en français.

!!! note "Maven"
    Après chaque release, release-please propose de repasser en `-SNAPSHOT` (PR mergée automatiquement de la même façon). Pour s'en passer : `"skip-snapshot": true` dans `release-please-config.json`.

## Entrées et sorties

| Entrée | Défaut | Rôle |
|---|---|---|
| `release-type` | détection | type release-please (`maven`, `node`, `python`, `simple`…) |
| `workflows` | détection | workflows lancés sur la PR de release ; par défaut ceux qui réagissent à `pull_request` et à `workflow_dispatch` |
| `config-file`, `manifest-file` | `release-please-config.json`, `.release-please-manifest.json` | configuration release-please |

!!! warning "Workflows qui déploient"
    Un workflow qui déploie quand il n'est pas lancé par une PR (site, environnement) serait lancé sur la branche de release : lister explicitement les workflows de CI avec `workflows:`.

Sorties : `release_created`, `tag_name`, `version`, `major`, `sha`, pour enchaîner la publication propre au projet :

```yaml
  publier:
    needs: release
    if: needs.release.outputs.release_created == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { ref: "${{ needs.release.outputs.tag_name }}" }
      # mvn deploy, npm publish, docker push…
```

Suspendre les releases : *Actions → release → Disable workflow*.
