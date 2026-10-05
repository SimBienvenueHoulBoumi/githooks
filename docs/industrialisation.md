# Déployer githooks dans une organisation

githooks impose les mêmes règles à tous les projets (messages de commit, nommage des branches, secrets, formatage, tests) à **trois niveaux** :

| Niveau | Rôle | Contournable ? |
|---|---|---|
| Poste développeur — hooks via [lefthook](https://lefthook.dev) | Retour immédiat, corrections automatiques (formatage, préfixe de commit) | Oui (`--no-verify`) |
| CI — action GitHub / template GitLab | **Fait foi** : mêmes vérifications sur chaque merge request | Non |
| Serveur — protection des branches | Interdit de merger si la CI échoue, interdit le push direct sur `main` | Non |

Les hooks locaux font gagner du temps ; **la CI et la protection des branches garantissent les règles**.

## 1. Héberger githooks

Le dépôt doit être **lisible par tous les développeurs et par la CI** :

- GitLab : importer/mirrorer le dépôt dans un groupe interne (ex. `outils/githooks`) ;
- GitHub : dépôt public, ou interne à l'organisation.

Remplacer `SimBienvenueHoulBoumi/githooks` par ce chemin dans les templates (`templates/`).

## 2. Versions et releases (automatiques)

Les numéros de version sont **calculés automatiquement** à partir des Conventional Commits par [release-please](https://github.com/googleapis/release-please) :

| Commits depuis la dernière release | Nouvelle version |
|---|---|
| `fix: …` | correctif : 1.4.**2** → 1.4.**3** |
| `feat: …` | fonctionnalité : 1.**4**.2 → 1.**5**.0 |
| `feat!: …` ou `BREAKING CHANGE:` dans le corps | majeure : **1**.4.2 → **2**.0.0 |

À chaque push sur `main`, release-please met à jour une PR « release x.y.z » (changelog + version dans les templates). **Merger cette PR** crée le tag `vX.Y.Z`, la release GitHub et déplace le tag majeur `vX`. C'est la seule action humaine : elle choisit *quand* publier.

Prérequis GitHub : *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*.

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

Outils recommandés : `gitleaks` (secrets) et les formateurs des langages utilisés (voir le README).

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

## 4. Adopter githooks dans un projet

Copier depuis `templates/project/` :

| Fichier | Rôle |
|---|---|
| `lefthook.yml` | Hooks locaux : règles githooks (version figée) + jobs propres au projet |
| `.github/workflows/githooks.yml` | CI GitHub (ajouter les `setup-*` des outils du projet) |
| `gitlab-ci.yml` | À fusionner dans `.gitlab-ci.yml` (choisir une image avec les outils du projet) |
| `.githooks.conf` | Réglages partagés : exceptions de branches, étapes désactivées, commandes personnalisées |

`.githooks.conf` est lu **par les hooks et par la CI** : une exception décidée en revue de code s'applique partout.

Avec `strict: true` (GitHub) / `GITHOOKS_STRICT: "true"` (GitLab), un outil de formatage ou de test absent de l'image CI fait échouer la vérification au lieu d'être ignoré.

## 5. Protéger les branches (serveur)

### GitHub

*Settings → Rules → Rulesets* (ou *Branches → Branch protection rules*) sur `main` :

- Require a pull request before merging
- Require status checks to pass → ajouter **`githooks`**
- Block force pushes
- (optionnel) Restrict branch names / commit metadata avec les regex du README

### GitLab

- *Settings → Repository → Protected branches* : `main` → *Allowed to push: No one*, *Allowed to merge: Developers*
- *Settings → Merge requests* : **Pipelines must succeed**
- (Premium) *Settings → Repository → Push rules* : regex de nom de branche et de message de commit (voir le README)

## 6. Ce que vérifie la CI

`ci/check.sh` compare la branche à sa base (merge request, push précédent ou branche par défaut) :

| Vérification | Échoue si |
|---|---|
| `commits` | un message n'est pas Conventional Commits, dépasse 72 caractères, ou est un `fixup!`/`squash!` non squashé |
| `branch` | le nom de branche ne respecte pas `<type>/<sujet>` (hors exceptions) |
| `secrets` | gitleaks trouve un secret dans les commits de la branche |
| `format` | un fichier modifié n'est pas formaté (le formateur est lancé, rien n'est committé) |
| `tests` | les tests d'un projet touché échouent (monorepo : seulement les projets modifiés) |

Les erreurs apparaissent en annotations sur GitHub et dans le log du job sur GitLab, avec la commande de correction.

## 7. Poste avec l'installation globale githooks

`install.sh --global` (usage personnel) et lefthook cohabitent : dans un dépôt contenant un `lefthook.yml`, les hooks globaux délèguent à lefthook (config du projet, version figée), sans `lefthook install` et sans conflit de `core.hooksPath`.
