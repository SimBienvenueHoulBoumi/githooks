# githooks

Hooks git réutilisables, qui s'adaptent au langage du projet.

## Prérequis

| Élément | Requis | Notes |
|---|---|---|
| git + bash | oui | macOS, Linux, Windows via [Git for Windows](https://gitforwindows.org) (hooks exécutés par Git Bash) |
| Accès au dépôt | oui | dépôt privé : clé SSH ajoutée à GitHub, ou `gh auth login` puis clone en HTTPS |
| Outils des langages utilisés | selon projets | `mvn`/`mvnw`, `gradle`/`gradlew`, `node`, `ruff`/`black`, `pytest`, `go`, `cargo` — un outil absent est ignoré |
| [gitleaks](https://github.com/gitleaks/gitleaks) | conseillé | `brew install gitleaks` · `apt install gitleaks` · `winget install gitleaks` |

## Installation

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
| Terraform / OpenTofu | — ² | `terraform fmt` / `tofu fmt` | — |
| Autre | `Makefile`, `justfile`, `Taskfile.yml` | — | `make test` · `just test` · `task test` |

¹ multi-module : build depuis le projet parent le plus haut. ² formate aussi les fichiers isolés, hors projet.

Un outil absent est ignoré (avertissement dans un projet, silence pour un fichier isolé) : jamais bloquant.
Testé en réel : Maven/Spring Boot, Node + pnpm, Python + uv, Go, Dart, Terraform, Make. Les autres suivent la documentation de leurs outils.

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
```

Ou en local (non partagé, **prioritaire** sur `.githooks.conf`) :

```bash
git config hooks.skip true                    # désactive tout
git config hooks.skip "pre-push"              # désactive un hook
git config hooks.skip "protect-branch,format" # désactive des étapes
git config hooks.skip "node"                  # désactive un langage
```

Désactivables : hooks (`pre-commit`, `pre-push`…), étapes (`branch-name`, `protect-branch`, `secrets`, `format`, `tests`), langages (`maven`, `node`, `python`…).

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
shellcheck hooks/pre-commit hooks/prepare-commit-msg hooks/commit-msg hooks/pre-push hooks/post-checkout hooks/lib/*.sh hooks/lang/*.sh install.sh
```

La CI (`.github/workflows/ci.yml`) lance shellcheck et les tests sur Linux, macOS et Windows.

## Limites

- Git n'a pas de hook à la création de branche : le nommage est averti puis bloqué au commit/push, pas empêché à la création. Pour l'imposer côté serveur : voir [GitHub, GitLab, Bitbucket](#github-gitlab-bitbucket).
- Un `core.hooksPath` local (husky, etc.) est prioritaire sur l'installation globale : dans ce dépôt, lancer `install.sh` sans `--global` ou laisser l'outil existant gérer.
- Hooks locaux = contournables (`--no-verify`) et à installer sur chaque poste. Pour imposer les règles à une équipe : CI + règles côté serveur (voir ci-dessus).
- Gradle (`spotlessApply`) formate tout le projet, pas seulement les fichiers stagés : seuls les fichiers stagés sont re-stagés, mais d'autres fichiers mal formatés peuvent apparaître modifiés.
- Si le formatage et des modifications non stagées touchent les mêmes lignes, le commit est formaté mais le dossier de travail reste dans son état d'origine (non formaté).
- Langage non listé : le décrire dans `.githooks.conf` (`format`, `test`) ou ajouter un fichier `hooks/lang/<nom>.sh`.
- Les fichiers isolés (hors projet) sont formatés mais n'ont pas de tests.
- `pre-push` en dehors de la branche courante : tests dans un worktree temporaire (seul `node_modules` est relié, les autres dépendances locales non versionnées sont absentes).
