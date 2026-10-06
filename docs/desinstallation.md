# Désinstallation

`install.sh --uninstall` ne retire que les hooks **de repogarde** : un `core.hooksPath` qui pointe vers un autre outil (husky…) est laissé intact, avec un avertissement.

## Installation globale (tous les dépôts du poste)

```bash
~/repogarde/install.sh --uninstall --global
```

Désinstallation complète, avec suppression des caches (`~/.cache/repogarde`, ancien `~/.cache/githooks`) et liste des dépôts encore branchés sur repogarde :

```bash
~/repogarde/install.sh --uninstall --global --purge --scan ~/projets
```

Le script **liste** les dépôts concernés et la commande à lancer pour chacun, sans les modifier. Il affiche à la fin la commande pour supprimer le dossier repogarde, à lancer soi-même.

## Un seul dépôt

```bash
cd mon-projet
~/repogarde/install.sh --uninstall
```

## Projet configuré avec lefthook

```bash
cd mon-projet
lefthook uninstall
```

Puis retirer le `remotes` de repogarde du `lefthook.yml`, ou le fichier lui-même.
