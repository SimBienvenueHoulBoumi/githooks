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

## Merger la PR de release : laisser faire le bot

La PR de release est mergée **par le workflow lui-même**, dès que la CI est verte, et la release est publiée dans le même run. La merger à la main fonctionne aussi, sauf dans un cas : si un fichier de `.github/workflows/` change sur `main` avant que la release soit publiée, GitHub refuse au jeton des Actions de créer le tag (il faudrait la permission `workflow`, que ce jeton n'a jamais) : « Resource not accessible by integration ».

Le workflow le détecte et affiche la cause et les commandes exactes ; en résumé, avec un compte qui a la permission `workflow` :

```bash
gh auth refresh -h github.com -s workflow
gh release create vX.Y.Z --target <commit de merge de la PR> --title vX.Y.Z --notes-file notes.md
gh pr edit <n° de la PR> --remove-label "autorelease: pending" --add-label "autorelease: tagged"
```

puis relancer le workflow `release`. Pour ne plus y être confronté : configurer un [bot de release](#bot-de-release).

## Bot de release

Pour que les releases ne soient **jamais** bloquées, même dans le cas ci-dessus, le dépôt peut avoir son propre bot : une identité dédiée, aux droits limités, utilisée à la place du jeton automatique. Sans bot, rien ne change.

| | GitHub | GitLab (à venir) |
|---|---|---|
| Identité | **GitHub App** privée : jetons d'une heure générés à chaque run, aucun jeton long terme stocké | **jeton d'accès de projet** : utilisateur bot propre au projet, avec expiration |
| Droits | contenu, PR, workflows, étiquettes (écriture) ; métadonnées (lecture) | rôle Maintainer, portées `api` et `write_repository` |
| Rangé dans | secrets `REPOGARDE_APP_ID`, `REPOGARDE_APP_KEY` | variable CI masquée et protégée `REPOGARDE_RELEASE_TOKEN` |

Configuration guidée, depuis le dépôt du projet (formulaire de création pré-rempli, installation sur le dépôt, secrets enregistrés sans que la clé apparaisse) :

```bash
~/repogarde/bin/bot-release
```

Puis, dans `.github/workflows/release.yml` :

```yaml
  release:
    uses: SimBienvenueHoulBoumi/repogarde/.github/workflows/release-auto.yml@v2
    secrets:
      app-id: ${{ secrets.REPOGARDE_APP_ID }}
      app-key: ${{ secrets.REPOGARDE_APP_KEY }}
```

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

## Flux develop → main (mode tag)

Pour un projet à deux branches longues ([flux `integrationBranch`](configuration.md#flux-avec-branche-dintegration-develop)), la version n'est écrite dans aucun fichier : elle est calculée depuis les commits et portée par le tag (un build Maven la reçoit par exemple en `-Drevision`).

```yaml title=".github/workflows/release.yml"
on:
  push:
    branches: [main, develop]

jobs:
  release:
    uses: SimBienvenueHoulBoumi/repogarde/.github/workflows/release-auto.yml@v2
    permissions: { contents: write, pull-requests: write }
    with:
      mode: tag

  publier:
    needs: release
    if: needs.release.outputs.release_created == 'true'
    runs-on: ubuntu-latest
    permissions: { contents: write }
    steps:
      - uses: actions/checkout@v4
        with: { ref: "${{ needs.release.outputs.tag_name }}" }
      - run: ./mvnw -B verify -Drevision="${{ needs.release.outputs.version }}"
      - run: gh release upload "${{ needs.release.outputs.tag_name }}" target/*.jar
        env: { GH_TOKEN: "${{ github.token }}" }
```

1. À chaque merge sur `develop`, la **PR de livraison** `develop` → `main` est créée ou mise à jour : titre `chore(release): vX.Y.Z`, notes groupées (incompatibles, fonctionnalités, corrections, maintenance) ;
2. la merger (décision humaine, **merge commit** de préférence : les notes gardent le détail des commits) publie : tag `vX.Y.Z` et release GitHub sur `main` ;
3. un `hotfix/…` mergé sur `main` publie un correctif de la même façon.

La CI du projet doit tourner sur les pushs vers `develop` : ses vérifications portent sur le commit de tête, et valent donc pour la PR de livraison.

## Entrées et sorties

| Entrée | Défaut | Rôle |
|---|---|---|
| `release-type` | détection | type release-please (`maven`, `node`, `python`, `simple`…) |
| `workflows` | détection | workflows lancés sur la PR de release ; par défaut ceux qui réagissent à `pull_request` et à `workflow_dispatch` |
| `initial-version` | `0.1.0` | version de la première release (aucun tag existant) |
| `merge-auto` | `true` | `false` : la PR de release est préparée et validée par la CI, un humain la merge ; une relecture exigée par la protection est toujours respectée |
| `notify` | `release attente echec` | événements envoyés au canal de l'équipe (secret `webhook`) : voir [Validation humaine](validation.md#canal-de-lequipe) |
| `mode` | `pr` | `tag` : flux develop → main, sans PR de release ni fichier de version |
| `integration-branch`, `main-branch` | `develop`, `main` | branches du mode tag |
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
