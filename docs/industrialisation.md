# Déployer repogarde dans une organisation

repogarde impose les mêmes règles à tous les projets (messages de commit, nommage des branches, secrets, formatage, tests) à **trois niveaux** :

| Niveau | Rôle | Contournable ? |
|---|---|---|
| Poste développeur — hooks via [lefthook](https://lefthook.dev) | Retour immédiat, corrections automatiques (formatage, préfixe de commit) | Oui (`--no-verify`) |
| CI — action GitHub / template GitLab | **Fait foi** : mêmes vérifications sur chaque merge request | Non |
| Serveur — protection des branches | Interdit de merger si la CI échoue, interdit le push direct sur `main` | Non |

Les hooks locaux font gagner du temps ; **la CI et la protection des branches garantissent les règles**.

## 1. Héberger repogarde

Le dépôt doit être **lisible par tous les développeurs et par la CI** :

- GitLab : importer/mirrorer le dépôt dans un groupe interne (ex. `outils/repogarde`) ;
- GitHub : dépôt public, ou interne à l'organisation.

Remplacer `SimBienvenueHoulBoumi/repogarde` par ce chemin dans les templates (`templates/`).

## 2. Versions et releases (automatiques)

Les projets peuvent obtenir les mêmes releases automatiques : voir [Versions et releases](releases.md). Ci-dessous, celles de repogarde lui-même.

Les numéros de version sont **calculés automatiquement** à partir des Conventional Commits par [release-please](https://github.com/googleapis/release-please) :

| Commits depuis la dernière release | Nouvelle version |
|---|---|
| `fix: …` | correctif : 1.4.**2** → 1.4.**3** |
| `feat: …` | fonctionnalité : 1.**4**.2 → 1.**5**.0 |
| `feat!: …` ou `BREAKING CHANGE:` dans le corps | majeure : **1**.4.2 → **2**.0.0 |

À chaque push sur `main`, le workflow `release` :

1. met à jour la PR « release x.y.z » (changelog + version dans les templates) ;
2. lance la CI sur cette PR et attend les vérifications obligatoires ;
3. la merge, crée le tag `vX.Y.Z` et la release, déplace le tag majeur `vX` et joint une archive signée.

**Aucun jeton à créer** : le workflow n'utilise que `GITHUB_TOKEN` (il déclenche la CI par `workflow_dispatch`, seul type d'événement autorisé à ce jeton). Prérequis : *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*.

Pour suspendre les releases automatiques : désactiver le workflow `release` (*Actions → release → Disable workflow*).

Politique conseillée pour les projets : **figer une version exacte** (`ref: v1.4.2`) et la monter volontairement (Renovate/Dependabot peuvent proposer la mise à jour). Une règle plus stricte = version majeure.

## 3. Poste développeur

Installer lefthook une fois :

```bash
brew install lefthook          # macOS
winget install evilmartians.lefthook   # Windows
npm install -g lefthook        # tout système avec Node
go install github.com/evilmartians/lefthook/v2@latest
```

Puis, dans chaque projet : `lefthook install` (une fois après le clone).

Outils recommandés : `gitleaks` (secrets) et les formateurs des langages utilisés (voir [Technologies](technologies.md)).

**Installation automatique** au premier build, pour ne dépendre de personne :

- Node : `npm install --save-dev lefthook` → les hooks s'installent à chaque `npm install`.
- Maven :
  ```xml
  <plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>exec-maven-plugin</artifactId>
    <executions>
      <execution>
        <id>lefthook-install</id>
        <phase>initialize</phase>
        <goals><goal>exec</goal></goals>
        <configuration>
          <executable>lefthook</executable>
          <arguments><argument>install</argument></arguments>
          <skip>${env.CI}</skip>
        </configuration>
      </execution>
    </executions>
  </plugin>
  ```
- Gradle (Kotlin DSL) :
  ```kotlin
  val lefthookInstall by tasks.registering(Exec::class) {
      commandLine("lefthook", "install")
      isIgnoreExitValue = true
      onlyIf { System.getenv("CI") == null }
  }
  tasks.named("compileJava") { dependsOn(lefthookInstall) }
  ```
  Ces deux snippets **font échouer le build si lefthook n'est pas installé** : c'est voulu (le poste doit être équipé). Hors CI uniquement.
- Python / autres : documenter `lefthook install` dans le README du projet, ou l'ajouter à `make setup`.

## 4. Adopter repogarde dans un projet

Copier depuis `templates/project/` :

| Fichier | Rôle |
|---|---|
| `lefthook.yml` | Hooks locaux : règles repogarde (version figée) + jobs propres au projet |
| `.github/workflows/repogarde.yml` | CI GitHub (ajouter les `setup-*` des outils du projet) |
| `gitlab-ci.yml` | À fusionner dans `.gitlab-ci.yml` (choisir une image avec les outils du projet) |
| `.repogarde.conf` | Réglages partagés : exceptions de branches, étapes désactivées, commandes personnalisées |

`.repogarde.conf` est lu **par les hooks et par la CI** : une exception décidée en revue de code s'applique partout.

Avec `strict: true` (GitHub) / `REPOGARDE_STRICT: "true"` (GitLab), un outil de formatage ou de test absent de l'image CI fait échouer la vérification au lieu d'être ignoré.

## 5. Protéger les branches (serveur)

### Merges en squash

Une PR = un commit sur `main`, dont le message est le **titre de la PR** : changelog propre, une ligne par PR. Réglages (*Settings → General → Pull Requests*) : autoriser uniquement *squash merging*, message par défaut *Pull request title*. La CI repogarde vérifie que ce titre suit Conventional Commits ; utiliser `!` dans le titre pour un changement majeur (`feat!: …`).

### Branches mergées : supprimées automatiquement

- Serveur — GitHub : *Settings → General → Automatically delete head branches* ; GitLab : *Settings → Merge requests → Enable "Delete source branch" option by default*.
- Flux `develop` : une branche `release/…` ou `hotfix/…` est mergée deux fois (vers `main` et `develop`) ; la suppression automatique de GitHub la supprimerait après le premier merge. Le workflow réutilisable `nettoyage-branches.yml` la conserve tant qu'une autre PR ouverte l'utilise (`bin/proteger` désactive alors la suppression automatique) :

  ```yaml
  on:
    pull_request:
      types: [closed]
  jobs:
    nettoyage:
      uses: SimBienvenueHoulBoumi/repogarde/.github/workflows/nettoyage-branches.yml@v2
      permissions: { contents: write, pull-requests: read }
  ```

- Postes : le hook `post-merge` de repogarde supprime, après un `git pull`, les branches locales dont la branche distante a disparu et dont toutes les modifications sont dans la branche courante (merge classique ou squash) ; une branche avec du travail non intégré est conservée.

### GitHub

**En une commande**, d'après `.repogarde.conf` (branches protégées, flux `develop`) — relançable sans risque, `--dry-run` pour voir avant d'appliquer :

```bash
bin/proteger --checks "repogarde,build"   # vérifications séparées par des virgules ; gh connecté (admin)
```

Le script pose le ruleset « repogarde » (PR obligatoire, vérifications exigées à jour, ni suppression ni push forcé), les modes de merge (squash ; avec un flux `develop` : merge commit sur `main`, squash ou merge commit sur `develop`, qui devient la branche par défaut), réserve les tags `v*` aux workflows (ruleset « repogarde (tags) »), prend le titre de PR comme message de commit et autorise GitHub Actions à créer des PR (releases automatiques).

À la main : *Settings → Rules → Rulesets* (ou *Branches → Branch protection rules*) sur `main` :

- Require a pull request before merging
- Require status checks to pass → ajouter **`repogarde`**
- Block force pushes
- (optionnel) Restrict branch names / commit metadata avec les [expressions régulières](ci.md#regles-cote-serveur)

### GitLab

- *Settings → Repository → Protected branches* : `main` → *Allowed to push: No one*, *Allowed to merge: Developers*
- *Settings → Merge requests* : **Pipelines must succeed**
- (Premium) *Settings → Repository → Push rules* : regex de nom de branche et de message de commit ([expressions régulières](ci.md#regles-cote-serveur))

## 6. Ce que vérifie la CI

`ci/check.sh` compare la branche à sa base (merge request, push précédent ou branche par défaut) :

| Vérification | Échoue si |
|---|---|
| `commits` | un message ou le titre de la PR n'est pas Conventional Commits, dépasse 72 caractères (format seul pour les bots de dépendances), ou est un `fixup!`/`squash!` non squashé |
| `branch` | le nom de branche ne respecte pas `<type>/<sujet>` (hors exceptions) ; dans un [flux `develop`](configuration.md#flux-avec-branche-dintegration-develop), la PR vise la mauvaise branche (reciblée automatiquement avec `fix-pr`) |
| `secrets` | gitleaks trouve un secret dans les commits de la branche |
| `format` | un fichier modifié n'est pas formaté (le formateur est lancé, rien n'est committé) |
| `tests` | les tests d'un projet touché échouent (monorepo : seulement les projets modifiés) |
| `deadcode` | du code mort **prouvé** est introduit (inaccessible, inutilisé dans sa portée) ; les candidats avertissent seulement ([Code mort](code-mort.md)) |

Les erreurs apparaissent en annotations sur GitHub et dans le log du job sur GitLab, avec la commande de correction.

## 7. Poste avec l'installation globale repogarde

`install.sh --global` (usage personnel) et lefthook cohabitent : dans un dépôt contenant un `lefthook.yml`, les hooks globaux délèguent à lefthook (config du projet, version figée), sans `lefthook install` et sans conflit de `core.hooksPath`.
