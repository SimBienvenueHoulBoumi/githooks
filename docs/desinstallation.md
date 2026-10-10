# Désinstallation

`repowarden uninstall` ne retire que les hooks **de repowarden** : un `core.hooksPath` qui pointe vers un autre outil (husky…) est laissé intact, avec un avertissement.

## Installation globale (tous les dépôts du poste)

```bash
repowarden uninstall --global
npm uninstall -g repowarden
```

Dans cet ordre : npm n'exécute rien à la désinstallation, et des hooks branchés sur un paquet supprimé ne se déclenchent plus, sans prévenir. `repowarden` (statut) indique ce qui reste actif.

Désinstallation complète, avec suppression des caches (`~/.cache/repowarden`) et liste des dépôts encore branchés sur repowarden :

```bash
repowarden uninstall --global --purge --scan ~/projets
```

La commande **liste** les dépôts concernés et la commande à lancer pour chacun, sans les modifier. Elle affiche à la fin la dernière commande à lancer soi-même : `npm uninstall -g repowarden`, ou la suppression du dossier pour une installation par clone.

Installation par clone : mêmes commandes avec `~/repowarden/install.sh --uninstall` à la place de `repowarden uninstall`.

## Un seul dépôt

```bash
cd mon-projet
repowarden uninstall
```

## Projet encore configuré avec lefthook (repowarden 3)

```bash
cd mon-projet
lefthook uninstall
```

Puis retirer le `remotes` de repowarden du `lefthook.yml`, ou le fichier lui-même. Depuis repowarden 4, lefthook n'est plus pris en charge : les commandes propres au projet se déclarent dans `.repowarden/<hook>` ([Configuration](configuration.md#hooks-propres-au-projet)).
