# repogarde

[![CI](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/ci.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/ci.yml)
[![e2e](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/e2e.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/e2e.yml)
[![Release](https://img.shields.io/github/v/release/SimBienvenueHoulBoumi/repogarde)](https://github.com/SimBienvenueHoulBoumi/repogarde/releases)
[![npm](https://img.shields.io/npm/v/@simbie/repogarde)](https://www.npmjs.com/package/@simbie/repogarde)
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
- **Code mort** : seul le nouveau code mort est signalé, prouvé (bloquant) ou candidat (à vérifier) ; `repogarde code-mort` en local.
- **Versions et releases** : les commits étant conventionnels, la version suivante (semver) et le changelog se déduisent de l'historique ; un workflow réutilisable en fait des releases automatiques (PR de release validée par la CI puis mergée, tag, release), sans jeton ni intervention.

**Plus de 25 technologies** : Java (Maven, Gradle), JavaScript / TypeScript, Python, Go, Rust, PHP, Ruby, .NET, Dart / Flutter, Swift, Elixir, C / C++, Shell, Terraform, Packer, Ansible, Helm, Kubernetes, Docker, GitHub Actions — [détail](https://simbienvenuehoulboumi.github.io/repogarde/technologies/). Linux, macOS, Windows.

## Démarrage

### 1. Sur ton poste, en une minute (tous tes dépôts)

```bash
npm install -g @simbie/repogarde     # paquet npm (yarn global add, pnpm add -g : idem)
repogarde install --global           # demande la langue (fr / en) et installe git cc
```

C'est tout : dans **n'importe quel dépôt**, les hooks s'appliquent dès le prochain commit. Rien n'est ajouté aux projets ni à leur `package.json`.

```bash
cd mon-projet
git switch -c feat/panier            # nom de branche vérifié
git add . && git cc                  # assistant : type, scope, description… puis commit
git push -u origin feat/panier       # tests des projets touchés avant l'envoi
repogarde code-mort                  # nouveau code mort de ta branche
```

| Action | Commande |
|---|---|
| Toutes les commandes | `repogarde --help` (`cc`, `code-mort`, `proteger`, `bot-release`, `npm-publication`…) |
| Mettre à jour | `npm update -g @simbie/repogarde` (les hooks suivent) |
| Désinstaller | `repogarde uninstall --global`, puis `npm uninstall -g @simbie/repogarde` |

Sans Node : `git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde && ~/repogarde/install.sh --global` (mise à jour : `git -C ~/repogarde pull`).

### 2. Dans un projet d'équipe : les mêmes règles pour tous

Chaque personne de l'équipe installe repogarde une fois sur son poste (partie 1). Le projet, lui, ajoute deux fichiers, à copier depuis [`templates/project/`](templates/project) :

| Fichier | Rôle |
|---|---|
| [`.github/workflows/repogarde.yml`](templates/project/.github/workflows/repogarde.yml) | la CI refait toutes les vérifications sur chaque PR : c'est elle qui fait foi, même si quelqu'un contourne les hooks (`git commit --no-verify`) |
| [`.repogarde.conf`](templates/project/.repogarde.conf) | réglages communs à toute l'équipe, dont la version minimale de repogarde attendue sur les postes |

L'essentiel des deux fichiers :

<!-- x-release-please-start-major -->
```yaml
# .github/workflows/repogarde.yml : vérifications de la PR (dernière version 3.x)
- uses: SimBienvenueHoulBoumi/repogarde@v3
  with: { strict: true }      # un outil manquant fait échouer la CI
```
<!-- x-release-please-end -->

<!-- x-release-please-start-version -->
```ini
# .repogarde.conf : un poste en retard est prévenu, avec la commande de mise à jour
[repogarde]
    version = 3.2.0
```
<!-- x-release-please-end -->

Puis rendre la CI obligatoire pour merger : `repogarde proteger` (protection de `main`, check `repogarde` exigé).

Version exacte par projet (avancé) : avec [lefthook](https://lefthook.dev) et le modèle [`lefthook.yml`](templates/project/lefthook.yml), chaque projet télécharge repogarde à sa propre version ([En organisation](https://simbienvenuehoulboumi.github.io/repogarde/industrialisation/)).

Exemple complet : [repogarde-demo](https://github.com/SimBienvenueHoulBoumi/repogarde-demo) · Releases automatiques : [documentation](https://simbienvenuehoulboumi.github.io/repogarde/releases/).

### 3. Contribuer à repogarde

```bash
git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git && cd repogarde
./install.sh                         # repogarde se vérifie lui-même (hooks de ce dépôt)
bats test/                           # tests (bats-core), aussi lancés au push
```

Voir [CONTRIBUTING.md](CONTRIBUTING.md).

**Dans VS Code** : l'extension [repogarde-vscode](https://github.com/SimBienvenueHoulBoumi/repogarde-vscode) guide la rédaction des commits, signale une branche mal nommée et des hooks inactifs. En attendant sa publication sur le Marketplace : `.vsix` dans ses [releases](https://github.com/SimBienvenueHoulBoumi/repogarde-vscode/releases), puis `code --install-extension repogarde-X.Y.Z.vsix`.

## Liens

[Démarrage rapide](https://simbienvenuehoulboumi.github.io/repogarde/demarrage/) · [Hooks et règles](https://simbienvenuehoulboumi.github.io/repogarde/hooks/) · [Technologies](https://simbienvenuehoulboumi.github.io/repogarde/technologies/) · [Configuration](https://simbienvenuehoulboumi.github.io/repogarde/configuration/) · [CI](https://simbienvenuehoulboumi.github.io/repogarde/ci/) · [Versions et releases](https://simbienvenuehoulboumi.github.io/repogarde/releases/) · [Validation humaine](https://simbienvenuehoulboumi.github.io/repogarde/validation/) · [Code mort](https://simbienvenuehoulboumi.github.io/repogarde/code-mort/) · [En organisation](https://simbienvenuehoulboumi.github.io/repogarde/industrialisation/) · [Désinstallation](https://simbienvenuehoulboumi.github.io/repogarde/desinstallation/) · [Sécurité](SECURITY.md) · [Contribuer](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

Licence [MIT](LICENSE).
