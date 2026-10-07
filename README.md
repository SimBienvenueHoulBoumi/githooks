# repogarde

[![CI](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/ci.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/ci.yml)
[![e2e](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/e2e.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/e2e.yml)
[![Release](https://img.shields.io/github/v/release/SimBienvenueHoulBoumi/repogarde)](https://github.com/SimBienvenueHoulBoumi/repogarde/releases)
[![Documentation](https://img.shields.io/badge/docs-site-indigo)](https://simbienvenuehoulboumi.github.io/repogarde/)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/SimBienvenueHoulBoumi/repogarde/badge)](https://scorecard.dev/viewer/?uri=github.com/SimBienvenueHoulBoumi/repogarde)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

**repogarde** garde l'entrée de vos dépôts Git : messages de commit, nommage des branches, secrets, formatage et tests, **quel que soit le langage** — sur les postes (hooks), en CI (GitHub, GitLab) et côté serveur.

📖 **Documentation : https://simbienvenuehoulboumi.github.io/repogarde/** · 🇬🇧 **English: https://simbienvenuehoulboumi.github.io/repogarde/en/**

## Ce qu'il fait

- **Commits** : Conventional Commits imposés, préfixe déduit de la branche ; assistant interactif `git cc` (en-tête, corps, pied).
- **Branches** : format `<type>/<sujet>`, commande de renommage proposée, branches mergées supprimées automatiquement.
- **Secrets** : gitleaks avant le commit et en CI.
- **Formatage** : seul le contenu stagé, avec l'outil du projet ; le travail en cours est préservé.
- **Tests** : au push et en CI, seulement les projets touchés, sur le commit poussé.
- **Code mort** : seul le nouveau code mort est signalé, prouvé (bloquant) ou candidat (à vérifier) ; `bin/code-mort` en local.
- **Versions et releases** : les commits étant conventionnels, la version suivante (semver) et le changelog se déduisent de l'historique ; un workflow réutilisable en fait des releases automatiques (PR de release validée par la CI puis mergée, tag, release), sans jeton ni intervention.

**Plus de 25 technologies** : Java (Maven, Gradle), JavaScript / TypeScript, Python, Go, Rust, PHP, Ruby, .NET, Dart / Flutter, Swift, Elixir, C / C++, Shell, Terraform, Packer, Ansible, Helm, Kubernetes, Docker, GitHub Actions — [détail](https://simbienvenuehoulboumi.github.io/repogarde/technologies/). Linux, macOS, Windows.

## Démarrage

### 1. Sur ton poste, en une minute (tous tes dépôts)

```bash
git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
~/repogarde/install.sh --global      # demande la langue (fr / en) et installe git cc
```

C'est tout : dans **n'importe quel dépôt**, les hooks s'appliquent dès le prochain commit.

```bash
cd mon-projet
git switch -c feat/panier            # nom de branche vérifié
git add . && git cc                  # assistant : type, scope, description… puis commit
git push -u origin feat/panier       # tests des projets touchés avant l'envoi
~/repogarde/bin/code-mort            # nouveau code mort de ta branche
```

Mettre à jour : `git -C ~/repogarde pull` · Désinstaller : `~/repogarde/install.sh --uninstall --global`.

### 2. Dans un projet d'équipe (version figée, CI qui fait foi)

Ajouter au projet les modèles de [`templates/project/`](templates/project) :

```yaml
# lefthook.yml — hooks du projet (version figée)
remotes:
  - git_url: https://github.com/SimBienvenueHoulBoumi/repogarde
    ref: v2.11.3 # x-release-please-version
    configs: [lefthook-remote.yml]
```

```yaml
# .github/workflows/repogarde.yml (extrait) — la CI fait foi
- uses: actions/checkout@v4
  with: { fetch-depth: 0 }
- uses: SimBienvenueHoulBoumi/repogarde@v2 # x-release-please-major
  with: { strict: true }
```

**Chaque personne qui clone ensuite le projet** installe [lefthook](https://lefthook.dev) une fois (`brew install lefthook`, `npm i -g lefthook`, `winget install evilmartians.lefthook`), puis :

```bash
git clone <url-du-projet> && cd <projet>
lefthook install                     # hooks du projet, à la version figée dans lefthook.yml
```

Avec l'installation de la partie 1, ce `lefthook install` est inutile : les hooks globaux délèguent au `lefthook.yml` du projet (lefthook doit être installé ; sinon, ce sont les règles repogarde par défaut qui s'appliquent, sans la version figée du projet). Un projet Maven, Gradle ou npm peut aussi l'installer au premier build ([En organisation](https://simbienvenuehoulboumi.github.io/repogarde/industrialisation/)). Sans hooks, la CI refait toutes les vérifications.

Exemple complet : [repogarde-demo](https://github.com/SimBienvenueHoulBoumi/repogarde-demo) · Releases automatiques, protection de `main` : [documentation](https://simbienvenuehoulboumi.github.io/repogarde/releases/).

### 3. Contribuer à repogarde

```bash
git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git && cd repogarde
./install.sh                         # repogarde se vérifie lui-même (hooks de ce dépôt)
bats test/                           # tests (bats-core), aussi lancés au push
```

Voir [CONTRIBUTING.md](CONTRIBUTING.md).

**Dans VS Code** : l'extension [repogarde-vscode](https://github.com/SimBienvenueHoulBoumi/repogarde-vscode) guide la rédaction des commits, signale une branche mal nommée et des hooks inactifs. En attendant sa publication sur le Marketplace : `.vsix` dans ses [releases](https://github.com/SimBienvenueHoulBoumi/repogarde-vscode/releases), puis `code --install-extension repogarde-X.Y.Z.vsix`.

## Liens

[Démarrage rapide](https://simbienvenuehoulboumi.github.io/repogarde/demarrage/) · [Hooks et règles](https://simbienvenuehoulboumi.github.io/repogarde/hooks/) · [Technologies](https://simbienvenuehoulboumi.github.io/repogarde/technologies/) · [Configuration](https://simbienvenuehoulboumi.github.io/repogarde/configuration/) · [CI](https://simbienvenuehoulboumi.github.io/repogarde/ci/) · [Versions et releases](https://simbienvenuehoulboumi.github.io/repogarde/releases/) · [Validation humaine](https://simbienvenuehoulboumi.github.io/repogarde/validation/) · [Code mort](https://simbienvenuehoulboumi.github.io/repogarde/code-mort/) · [En organisation](https://simbienvenuehoulboumi.github.io/repogarde/industrialisation/) · [Migration depuis githooks](https://simbienvenuehoulboumi.github.io/repogarde/migration/) · [Désinstallation](https://simbienvenuehoulboumi.github.io/repogarde/desinstallation/) · [Sécurité](SECURITY.md) · [Contribuer](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

Licence [MIT](LICENSE).
