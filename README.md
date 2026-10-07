# repogarde

[![CI](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/ci.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/ci.yml)
[![e2e](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/e2e.yml/badge.svg)](https://github.com/SimBienvenueHoulBoumi/repogarde/actions/workflows/e2e.yml)
[![Release](https://img.shields.io/github/v/release/SimBienvenueHoulBoumi/repogarde)](https://github.com/SimBienvenueHoulBoumi/repogarde/releases)
[![Documentation](https://img.shields.io/badge/docs-site-indigo)](https://simbienvenuehoulboumi.github.io/repogarde/)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/SimBienvenueHoulBoumi/repogarde/badge)](https://scorecard.dev/viewer/?uri=github.com/SimBienvenueHoulBoumi/repogarde)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

**repogarde** garde l'entrée de vos dépôts Git : messages de commit, nommage des branches, secrets, formatage et tests, **quel que soit le langage** — sur les postes (hooks), en CI (GitHub, GitLab) et côté serveur.

📖 **Documentation : https://simbienvenuehoulboumi.github.io/repogarde/**

## Ce qu'il fait

- **Commits** : Conventional Commits imposés, préfixe déduit de la branche ; assistant interactif `git cc` (en-tête, corps, pied).
- **Branches** : format `<type>/<sujet>`, commande de renommage proposée, branches mergées supprimées automatiquement.
- **Secrets** : gitleaks avant le commit et en CI.
- **Formatage** : seul le contenu stagé, avec l'outil du projet ; le travail en cours est préservé.
- **Tests** : au push et en CI, seulement les projets touchés, sur le commit poussé.
- **Versions et releases** : les commits étant conventionnels, la version suivante (semver) et le changelog se déduisent de l'historique ; un workflow réutilisable en fait des releases automatiques (PR de release validée par la CI puis mergée, tag, release), sans jeton ni intervention.

**Plus de 25 technologies** : Java (Maven, Gradle), JavaScript / TypeScript, Python, Go, Rust, PHP, Ruby, .NET, Dart / Flutter, Swift, Elixir, C / C++, Shell, Terraform, Packer, Ansible, Helm, Kubernetes, Docker, GitHub Actions — [détail](https://simbienvenuehoulboumi.github.io/repogarde/technologies/). Linux, macOS, Windows.

## Démarrage

```yaml
# lefthook.yml — hooks du projet (version figée)
remotes:
  - git_url: https://github.com/SimBienvenueHoulBoumi/repogarde
    ref: v2.6.2 # x-release-please-version
    configs: [lefthook-remote.yml]
```

```yaml
# .github/workflows/repogarde.yml (extrait) — la CI fait foi
- uses: actions/checkout@v4
  with: { fetch-depth: 0 }
- uses: SimBienvenueHoulBoumi/repogarde@v2 # x-release-please-major
  with: { strict: true }
```

Modèles complets : [`templates/project/`](templates/project) · Exemple : [repogarde-demo](https://github.com/SimBienvenueHoulBoumi/repogarde-demo) · Usage personnel (tous les dépôts du poste) : `./install.sh --global`.

**Dans VS Code** : l'extension [repogarde-vscode](https://github.com/SimBienvenueHoulBoumi/repogarde-vscode) guide la rédaction des commits, signale une branche mal nommée et des hooks inactifs. En attendant sa publication sur le Marketplace : `.vsix` dans ses [releases](https://github.com/SimBienvenueHoulBoumi/repogarde-vscode/releases), puis `code --install-extension repogarde-X.Y.Z.vsix`.

## Liens

[Démarrage rapide](https://simbienvenuehoulboumi.github.io/repogarde/demarrage/) · [Hooks et règles](https://simbienvenuehoulboumi.github.io/repogarde/hooks/) · [Technologies](https://simbienvenuehoulboumi.github.io/repogarde/technologies/) · [Configuration](https://simbienvenuehoulboumi.github.io/repogarde/configuration/) · [CI](https://simbienvenuehoulboumi.github.io/repogarde/ci/) · [Versions et releases](https://simbienvenuehoulboumi.github.io/repogarde/releases/) · [En organisation](https://simbienvenuehoulboumi.github.io/repogarde/industrialisation/) · [Migration depuis githooks](https://simbienvenuehoulboumi.github.io/repogarde/migration/) · [Désinstallation](https://simbienvenuehoulboumi.github.io/repogarde/desinstallation/) · [Sécurité](SECURITY.md) · [Contribuer](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

Licence [MIT](LICENSE).
