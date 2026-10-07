# Configuration

Tout est optionnel : sans configuration, repogarde détecte les langages et applique les règles par défaut.

## Fichier `.repogarde.conf` (partagé)

Versionné à la racine du projet, au format `git config`, lu **par les hooks et par la CI** : une exception décidée en revue s'applique partout.

```ini
[repogarde]
    # Commandes personnalisées : remplacent la détection automatique
    format = npm run lint:fix --        # reçoit les fichiers stagés en arguments
    test = make ci                      # lancée à la racine ; fichiers modifiés sur l'entrée standard
    # Réglages
    skip = protect-branch python        # étapes, hooks ou langages désactivés
    protectedBranches = main develop    # commit et push directs interdits ; défaut : main master
    allowedBranches = main develop release/*
    exclude = vendor/* generated/*      # chemins ni formatés ni testés
```

## Flux avec branche d'intégration (`develop`)

Par défaut, tout part de `main` et y revient par PR. Pour un flux à deux branches longues, où le travail s'intègre dans `develop` puis est livré sur `main` :

```ini
[repogarde]
    integrationBranch = develop     # active le flux
    mainBranch = main               # défaut : main
    protectedBranches = main develop
    allowedBranches = main develop release/* release-please--* dependabot/* renovate/*
```

La CI vérifie alors la cible de chaque PR :

| Branche de la PR                                   | Cible attendue      |
| -------------------------------------------------- | ------------------- |
| travail (`feat/…`, `fix/…`), bots (`dependabot/…`) | `develop`           |
| `develop`                                          | `main`              |
| `release/…`, `hotfix/…`                            | `main` ou `develop` |

Une PR mal ciblée est refusée, avec la commande de correction (`gh pr edit --base develop`). Avec l'entrée `fix-pr: true` de l'action, elle est **reciblée automatiquement** (ou fermée si une PR de la même branche vise déjà la bonne cible), et un titre non conforme est remplacé : par le commit conforme au plus fort impact de version (incompatible, puis `feat`, puis `fix`/`perf` ; « ! » ajouté si un pied `BREAKING CHANGE` existe), sinon déduit de la branche.

## Réglages locaux (non partagés)

Prioritaires sur `.repogarde.conf` :

```bash
git config repogarde.skip true                    # désactive tout
git config repogarde.skip "pre-push"              # désactive un hook
git config repogarde.skip "protect-branch,format" # désactive des étapes
git config repogarde.skip "node"                  # désactive un langage
```

## Ce qui peut être désactivé (`skip`)

| Catégorie          | Valeurs                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| Hooks              | `pre-commit`, `prepare-commit-msg`, `commit-msg`, `pre-push`, `post-checkout`, `post-merge`      |
| Étapes             | `branch-name`, `protect-branch`, `secrets`, `format`, `tests`, `prune-branches`                  |
| Langages et outils | `maven`, `gradle`, `node`, `python`, `go`, `helm`, `docker`… (nom du fichier dans `hooks/lang/`) |
| Tout               | `true`                                                                                           |

## Hooks propres au projet

Un script exécutable `.repogarde/<hook>` (ou `.git/hooks/<hook>`) est lancé en plus, avant les vérifications communes. Avec lefthook, déclarer plutôt les jobs du projet dans `lefthook.yml`.

## Affichage

Tous les messages de repogarde (hooks, CI, assistant `git cc`, installation) suivent la même charte : `✔` succès en vert, `✖` erreur en rouge, `⚠` avertissement en jaune, `ℹ` information en bleu, `▶` étape en cours en cyan, aides en gris atténué.

Les couleurs s'affichent dans un terminal et dans les logs de l'action GitHub. Elles sont désactivées par `NO_COLOR=1`, par `TERM=dumb` ou quand la sortie est redirigée (fichier, tube) ; `FORCE_COLOR=1` les impose.
