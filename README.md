# githooks

[![CI](https://github.com/SimBienvenueHoulBoumi/githooks/actions/workflows/ci.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/githooks/actions/workflows/ci.yml)
[![e2e](https://github.com/SimBienvenueHoulBoumi/githooks/actions/workflows/e2e.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/githooks/actions/workflows/e2e.yml)
[![Release](https://img.shields.io/github/v/release/SimBienvenueHoulBoumi/githooks)](https://github.com/SimBienvenueHoulBoumi/githooks/releases)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/SimBienvenueHoulBoumi/githooks/badge)](https://scorecard.dev/viewer/?uri=github.com/SimBienvenueHoulBoumi/githooks)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

Hooks git réutilisables, qui s'adaptent au langage du projet : messages de commit, nommage des branches, secrets, formatage et tests.

| Usage | Comment | Garantie |
|---|---|---|
| **Organisation / équipe** | lefthook (config partagée, version figée) + action GitHub / template GitLab + protection des branches | Règles imposées : la CI fait foi → **[guide de déploiement](docs/industrialisation.md)** |
| **Personnel** | `./install.sh --global` : tous les dépôts du poste, sans configuration | Confort local, contournable |

### En bref, dans un projet

```yaml
# lefthook.yml
remotes:
  - git_url: https://github.com/SimBienvenueHoulBoumi/githooks
    ref: v1.2.0 # x-release-please-version
    configs: [lefthook-remote.yml]
```

```yaml
# .github/workflows/githooks.yml (extrait)
- uses: actions/checkout@v4
  with: { fetch-depth: 0 }
- uses: SimBienvenueHoulBoumi/githooks@v1 # x-release-please-major
```

```yaml
# .gitlab-ci.yml (extrait)
include:
  - project: outils/githooks
    ref: v1.2.0 # x-release-please-version
    file: templates/gitlab/githooks.gitlab-ci.yml
```

Modèles complets : [`templates/project/`](templates/project). Versions et changelog : [releases](https://github.com/SimBienvenueHoulBoumi/githooks/releases) (automatiques, voir le guide).

## Technologies prises en charge

Détectées automatiquement, chacune vérifiée en CI sur un vrai projet (`test/e2e/`) :

| Domaine | Technologies |
|---|---|
| **Java / JVM** | Maven, Gradle (Java, Kotlin, Groovy) — Spring Boot, Quarkus, Android |
| **JavaScript / TypeScript** | npm, pnpm, yarn, bun, Deno — React, Next.js, Vue, Angular, Svelte, Nest |
| **Python** | pip, uv, poetry, pipenv — Django, FastAPI, Flask, scripts |
| **Autres langages** | Go · Rust · PHP (Laravel, Symfony) · Ruby (Rails) · .NET (C#, F#, ASP.NET) · Dart / Flutter · Swift · Elixir (Phoenix) · C / C++ / Objective-C (CMake, Meson) · Shell |
| **Infrastructure** | Terraform / OpenTofu · Packer · Ansible · Helm · Kubernetes (kustomize) · Docker (Dockerfile, Compose) · GitHub Actions |
| **Sans langage reconnu** | `Makefile`, `justfile`, `Taskfile` — ou toute commande via `.githooks.conf` |
| **Hébergement** | GitHub, GitLab, Bitbucket, Gitea, serveur Git (hooks locaux) |
| **CI** | GitHub Actions (action), GitLab CI (template) |
| **Systèmes** | Linux, macOS, Windows (Git Bash) |
| **Projets** | script isolé, projet unique, monorepo, multi-module |

Détail par technologie (formateur, commande de test) : [Langages et types de projets](#langages-et-types-de-projets). Exemple complet : [githooks-demo](https://github.com/SimBienvenueHoulBoumi/githooks-demo).

## Installation personnelle (globale)

### Prérequis

| Élément | Requis | Notes |
|---|---|---|
| git + bash | oui | macOS, Linux, Windows via [Git for Windows](https://gitforwindows.org) (hooks exécutés par Git Bash) |
| Accès au dépôt | oui | dépôt privé : clé SSH ajoutée à GitHub, ou `gh auth login` puis clone en HTTPS |
| Outils des langages utilisés | selon projets | `mvn`/`mvnw`, `gradle`/`gradlew`, `node`, `ruff`/`black`, `pytest`, `go`, `cargo` — un outil absent est ignoré |
| [gitleaks](https://github.com/gitleaks/gitleaks) | conseillé | `brew install gitleaks` · `apt install gitleaks` · `winget install gitleaks` |

### Installation

Le dépôt peut être cloné n'importe où : `install.sh` utilise son propre emplacement.

```bash
git clone git@github.com:SimBienvenueHoulBoumi/githooks.git ~/githooks
~/githooks/install.sh --global      # tous les dépôts de la machine
```

Pour un seul dépôt plutôt que toute la machine :

```bash
cd mon-projet
~/githooks/install.sh
```

Vérifier : `git config --global core.hooksPath` doit afficher `…/githooks/hooks`.

| Action | Commande |
|---|---|
| Mettre à jour | `git -C ~/githooks pull` (aucun projet à toucher) |
| Déplacer le dossier | relancer `install.sh --global` depuis le nouvel emplacement |
| Désinstaller | `~/githooks/install.sh --uninstall --global` |

## Hooks

| Hook | Rôle |
|---|---|
| `post-checkout` | Avertit dès qu'on arrive sur une branche mal nommée (non bloquant) |
| `pre-commit` | Refuse les branches mal nommées, bloque les commits directs sur `main`/`master`, détecte les secrets (gitleaks), formate uniquement le contenu stagé (le travail non stagé est préservé) |
| `prepare-commit-msg` | Préfixe le message d'après la branche : sur `feat/bean`, `git commit -m "ajoute X"` → `feat(bean): ajoute X` |
| `commit-msg` | Impose [Conventional Commits](https://www.conventionalcommits.org) (`feat(scope): …`), 72 caractères max |
| `post-merge` | Après un `git pull` : supprime les branches locales mergées (classique ou squash) dont la branche distante a été supprimée ; jamais une branche contenant du travail non intégré |
| `pre-push` | Refuse les branches mal nommées, build et tests complets **du commit poussé** (pas du dossier de travail) |

## Nommage des branches

Format imposé : `<type>/<sujet>` (sujet en `a-z0-9._-`, `/` pour sous-découper).
Ex. : `feat/inscription`, `fix/user/login`, `hotfix/timeout-db`.

- Averti à la création (`post-checkout`), refusé au commit et au push, avec la commande de renommage à copier.
- Exceptions par défaut : `main`, `master`, `develop`, `release/*` (modifiables via `hooks.allowedBranches`).
- Le type devient le préfixe du commit, le sujet son scope (omis au-delà de 20 caractères).
- Types : `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- Alias : `feature/` → `feat`, `bugfix/` et `hotfix/` → `fix`
- Un message déjà conforme n'est jamais modifié ; merge, squash et amend sont ignorés.

## Langages et types de projets

Fonctionne sur **n'importe quel dépôt** : simple script, projet unique, monorepo, multi-module.

**Formatage (pre-commit)** — chaque fichier stagé est traité selon :
1. le **projet le plus proche** en remontant ses dossiers (`backend/pom.xml`, `apps/web/package.json`…) ;
2. sinon, son **extension** (script isolé, `deploy.sh`, `outil.py`) avec l'outil installé sur la machine.

**Tests (pre-push)** — seuls les **projets touchés par le push** sont testés (un fichier non-code comme un README compte pour son projet). Sans langage reconnu : cible `test` d'un `Makefile`, `justfile` ou `Taskfile`.

| Langage / frameworks | Détecté par | Formatage | Tests |
|---|---|---|---|
| Java — Maven (Spring Boot, Quarkus) | `pom.xml` ¹ | Spotless si configuré (fichiers stagés) | `mvnw verify` |
| Java/Kotlin — Gradle (Spring, Android) | `settings.gradle`, `build.gradle(.kts)` ¹ | Spotless si configuré | `gradlew check` |
| JS/TS (React, Next, Vue, Angular, Nest…) | `package.json` ² | prettier (projet, sinon global) | `npm`/`pnpm`/`yarn`/`bun` `test` (selon lockfile) |
| Deno | `deno.json` | `deno fmt` | `deno test` |
| Python (Django, FastAPI, Flask) | `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`, `manage.py` ² | ruff, sinon black | pytest via uv/poetry/pipenv/.venv · `manage.py test` (Django) |
| Go | `go.mod` ² | gofmt | `go test ./...` |
| Rust | `Cargo.toml` ¹ ² | rustfmt (fichiers stagés) | `cargo test` |
| PHP (Laravel, Symfony) | `composer.json` | pint, sinon php-cs-fixer | `composer test` · `artisan test` · pest · phpunit |
| Ruby (Rails) | `Gemfile` | rubocop -a / standardrb (si dans le Gemfile) | `rails test` · rspec · `rake test` |
| .NET (ASP.NET, C#, F#) | `*.sln`, `*.csproj`… ¹ | `dotnet format` | `dotnet test` |
| Dart / Flutter | `pubspec.yaml` ² | `dart format` | `flutter test` / `dart test` |
| Swift | `Package.swift` ² | swift-format / SwiftFormat **si config présente** | `swift test` |
| Elixir (Phoenix) | `mix.exs` | `mix format` | `mix test` |
| C / C++ / Obj-C | `CMakeLists.txt`, `meson.build` ¹ ² | clang-format **si `.clang-format`** | ctest / meson test (si build configuré) |
| Shell | — ² | shfmt (`.editorconfig`, sinon 4 espaces) | — |
| **Terraform / OpenTofu** | `*.tf` ² | `terraform fmt` / `tofu fmt` | `init -backend=false` + `validate` · tflint |
| **Packer** | `*.pkr.hcl` ² | `packer fmt` | `packer validate -syntax-only` |
| **Ansible** | `ansible.cfg`, `galaxy.yml`, `requirements.yml` | reformatage YAML (`ansible-lint --fix=none`) | `ansible-lint` |
| **Helm** | `Chart.yaml` | **aucun** (templates Go : un formateur YAML les casserait) | `helm lint` · `helm template` + kubeconform · `helm unittest` |
| **Kubernetes** (kustomize) | `kustomization.yaml` | prettier | `kubectl kustomize` + kubeconform (schémas) |
| **Docker** | `Dockerfile`, `Containerfile`, `compose.yaml` | — | hadolint · `docker compose config` |
| **GitHub Actions** | `.github/workflows` | — | actionlint |
| Autre | `Makefile`, `justfile`, `Taskfile.yml` | — | `make test` · `just test` · `task test` |

¹ multi-module : build depuis le projet parent le plus haut. ² formate aussi les fichiers isolés, hors projet.

Pour l'infrastructure, l'étape « tests » est une **validation** (lint, rendu, schémas) : rien n'est déployé.

Un outil absent est ignoré (avertissement dans un projet, silence pour un fichier isolé) : jamais bloquant sur le poste ; bloquant en CI avec le mode strict.

**Versions des outils** : celles déclarées par le projet sont prioritaires (`node_modules`, `.venv`/uv, `vendor/bin`, `bundle exec`, wrapper Maven/Gradle, plugin Spotless versionné), pour que tout le monde formate à l'identique ; à défaut, l'outil installé sur le poste.

**Testé en réel** : chaque langage et outil ci-dessus a un projet exemple (`test/e2e/`) vérifié en CI avec son outillage : formatage au commit, vérification CI, tests au vert puis cassés (et, pour Helm, templates laissés intacts).

**Linters** : délégués à [MegaLinter](https://megalinter.io) (option `megalinter: true` de l'action, `GITHOOKS_MEGALINTER: "true"` sur GitLab) plutôt que réimplémentés.

### Ajouter un langage

Créer `hooks/lang/<nom>.sh` :

```bash
register elm "elm.json" '\.elm$' standalone   # nom, marqueurs, regex d'extensions, options
elm_format() { elm-format --yes "$@"; }       # fichiers relatifs au projet
elm_test()   { elm-test; }                    # lancé dans le dossier du projet
```

Options : `standalone` (formate hors projet), `outermost` (multi-module), `fallback` (tests seulement si rien d'autre).

## Configuration par projet

Dans un fichier **`.githooks.conf` versionné** à la racine du projet (partagé avec l'équipe), au format `git config` :

```ini
[hooks]
    # commandes personnalisées : remplacent la détection automatique
    format = npm run lint:fix --        # reçoit les fichiers stagés en arguments
    test = make ci                      # lancé à la racine
    # réglages
    skip = protect-branch python        # étapes, hooks ou langages désactivés
    protectedBranches = main develop    # défaut : main master
    allowedBranches = main develop release/*
    exclude = vendor/* generated/*      # chemins ni formatés ni testés
```

Ou en local (non partagé, **prioritaire** sur `.githooks.conf`) :

```bash
git config hooks.skip true                    # désactive tout
git config hooks.skip "pre-push"              # désactive un hook
git config hooks.skip "protect-branch,format" # désactive des étapes
git config hooks.skip "node"                  # désactive un langage
```

Désactivables : hooks (`pre-commit`, `pre-push`…), étapes (`branch-name`, `protect-branch`, `secrets`, `format`, `tests`, `prune-branches`), langages et outils (`maven`, `node`, `helm`, `docker`…).

Contournement ponctuel : `git commit --no-verify`, `git push --no-verify`.

## Hooks spécifiques à un projet

Un script exécutable dans `.githooks/<hook>` ou `.git/hooks/<hook>` du projet est lancé en plus, avant les vérifications communes.

## GitHub, GitLab, Bitbucket

Les hooks sont **locaux** : ils fonctionnent à l'identique quel que soit l'hébergeur du projet (GitHub, GitLab, Bitbucket, Gitea, serveur maison).

Pour imposer les mêmes règles **côté serveur** (non contournables) :

| Hébergeur | Où | Disponibilité |
|---|---|---|
| GitLab | *Settings → Repository → Push rules* : « Branch name » et « Require expression in commit messages » | GitLab Premium / Ultimate |
| GitHub | *Settings → Rules → Rulesets* : « Restrict branch names », « Restrict commit metadata » | gratuit sur dépôt public, GitHub Pro / Team sur dépôt privé |
| Bitbucket | *Repository settings → Branch restrictions* + app de vérification des messages | selon offre |

Regex à reporter :

```text
# Nom de branche
^((feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|feature|bugfix|hotfix)/[a-z0-9._-]+(/[a-z0-9._-]+)*|main|master|develop|release/.+)$

# Message de commit
^((feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._-]+\))?!?: .+|Merge .+|Revert .+)
```

## Développement

```bash
brew install bats-core shellcheck   # ou apt install bats shellcheck
bats test/                          # tests (dépôts jetables ; ceux dont l'outil manque sont ignorés)
shellcheck ci/*.sh hooks/pre-commit hooks/prepare-commit-msg hooks/commit-msg hooks/pre-push hooks/post-checkout hooks/post-merge hooks/lib/*.sh hooks/lang/*.sh install.sh .lefthook/*/githooks
```

La CI lance shellcheck, actionlint et les tests sur Linux, macOS et Windows (`ci.yml`), un projet réel par langage (`e2e.yml`) et l'évaluation OpenSSF (`scorecard.yml`). Voir [CONTRIBUTING.md](CONTRIBUTING.md).

## Limites

- Git n'a pas de hook à la création de branche : le nommage est averti puis bloqué au commit/push, pas empêché à la création. Pour l'imposer côté serveur : voir [GitHub, GitLab, Bitbucket](#github-gitlab-bitbucket).
- Un `core.hooksPath` local (husky, etc.) est prioritaire sur l'installation globale : dans ce dépôt, lancer `install.sh` sans `--global` ou laisser l'outil existant gérer.
- Hooks locaux = contournables (`--no-verify`) et à installer sur chaque poste. Pour imposer les règles à une équipe : CI + règles côté serveur (voir ci-dessus).
- Gradle (`spotlessApply`) formate tout le projet, pas seulement les fichiers stagés : seuls les fichiers stagés sont re-stagés, mais d'autres fichiers mal formatés peuvent apparaître modifiés.
- Si le formatage et des modifications non stagées touchent les mêmes lignes, le commit est formaté mais le dossier de travail reste dans son état d'origine (non formaté).
- Langage non listé : le décrire dans `.githooks.conf` (`format`, `test`) ou ajouter un fichier `hooks/lang/<nom>.sh`.
- Les fichiers isolés (hors projet) sont formatés mais n'ont pas de tests.
- `pre-push` en dehors de la branche courante : tests dans un worktree temporaire (seul `node_modules` est relié, les autres dépendances locales non versionnées sont absentes).
