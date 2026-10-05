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
git config hooks.allowedBranches "main develop release/*"   # exceptions au nommage
```

Étapes désactivables : `branch-name`, `protect-branch`, `secrets`, `format`, `tests`.

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
bats test/                          # tests (dépôts jetables, Go requis pour test/safety.bats)
shellcheck hooks/pre-commit hooks/prepare-commit-msg hooks/commit-msg hooks/pre-push hooks/post-checkout hooks/lib/*.sh install.sh
```

La CI (`.github/workflows/ci.yml`) lance shellcheck et les tests sur Linux, macOS et Windows.

## Limites

- Git n'a pas de hook à la création de branche : le nommage est averti puis bloqué au commit/push, pas empêché à la création. Pour l'imposer côté serveur : voir [GitHub, GitLab, Bitbucket](#github-gitlab-bitbucket).
- Un `core.hooksPath` local (husky, etc.) est prioritaire sur l'installation globale : dans ce dépôt, lancer `install.sh` sans `--global` ou laisser l'outil existant gérer.
- Hooks locaux = contournables (`--no-verify`) et à installer sur chaque poste. Pour imposer les règles à une équipe : CI + règles côté serveur (voir ci-dessus).
- Gradle (`spotlessApply`) et Rust (`cargo fmt`) formatent tout le projet, pas seulement les fichiers stagés : seuls les fichiers stagés sont re-stagés, mais d'autres fichiers mal formatés peuvent apparaître modifiés.
- Si le formatage et des modifications non stagées touchent les mêmes lignes, le commit est formaté mais le dossier de travail reste dans son état d'origine (non formaté).
- `pre-push` en dehors de la branche courante : tests dans un worktree temporaire (seul `node_modules` est relié, les autres dépendances locales non versionnées sont absentes).
