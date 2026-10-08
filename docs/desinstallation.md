# Désinstallation

`repogarde uninstall` ne retire que les hooks **de repogarde** : un `core.hooksPath` qui pointe vers un autre outil (husky…) est laissé intact, avec un avertissement.

## Installation globale (tous les dépôts du poste)

```bash
repogarde uninstall --global
npm uninstall -g @simbie/repogarde
```

Dans cet ordre : npm n'exécute rien à la désinstallation, et des hooks branchés sur un paquet supprimé ne se déclenchent plus, sans prévenir. `repogarde` (statut) indique ce qui reste actif.

Désinstallation complète, avec suppression des caches (`~/.cache/repogarde`) et liste des dépôts encore branchés sur repogarde :

```bash
repogarde uninstall --global --purge --scan ~/projets
```

La commande **liste** les dépôts concernés et la commande à lancer pour chacun, sans les modifier. Elle affiche à la fin la dernière commande à lancer soi-même : `npm uninstall -g @simbie/repogarde`, ou la suppression du dossier pour une installation par clone.

Installation par clone : mêmes commandes avec `~/repogarde/install.sh --uninstall` à la place de `repogarde uninstall`.

## Un seul dépôt

```bash
cd mon-projet
repogarde uninstall
```

## Projet configuré avec lefthook

```bash
cd mon-projet
lefthook uninstall
```

Puis retirer le `remotes` de repogarde du `lefthook.yml`, ou le fichier lui-même.
