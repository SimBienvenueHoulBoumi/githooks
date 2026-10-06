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

## Réglages locaux (non partagés)

Prioritaires sur `.repogarde.conf` :

```bash
git config repogarde.skip true                    # désactive tout
git config repogarde.skip "pre-push"              # désactive un hook
git config repogarde.skip "protect-branch,format" # désactive des étapes
git config repogarde.skip "node"                  # désactive un langage
```

## Ce qui peut être désactivé (`skip`)

| Catégorie | Valeurs |
|---|---|
| Hooks | `pre-commit`, `prepare-commit-msg`, `commit-msg`, `pre-push`, `post-checkout`, `post-merge` |
| Étapes | `branch-name`, `protect-branch`, `secrets`, `format`, `tests`, `prune-branches` |
| Langages et outils | `maven`, `gradle`, `node`, `python`, `go`, `helm`, `docker`… (nom du fichier dans `hooks/lang/`) |
| Tout | `true` |

## Hooks propres au projet

Un script exécutable `.repogarde/<hook>` (ou `.git/hooks/<hook>`) est lancé en plus, avant les vérifications communes. Avec lefthook, déclarer plutôt les jobs du projet dans `lefthook.yml`.
