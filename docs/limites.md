# Limites

- **Création de branche** : Git n'a pas de hook à ce moment-là ; le nom est vérifié au premier commit et au push. Pour l'imposer côté serveur : [règles côté serveur](ci.md#regles-cote-serveur).
- **Hooks locaux contournables** (`--no-verify`) et à installer sur chaque poste : la CI et la protection des branches font foi.
- **`core.hooksPath` local** (husky…) prioritaire sur l'installation globale : lancer `install.sh` dans le dépôt ou laisser l'outil existant gérer.
- **Chevauchement** : si le formatage et des modifications non stagées touchent les mêmes lignes, le commit est formaté mais le dossier de travail reste dans son état d'origine.
- **Langage non listé** : le décrire dans [la configuration](configuration.md) (`format`, `test`) ou [ajouter un fichier de langage](technologies.md#ajouter-un-langage).
- **Fichiers isolés** (hors projet) : formatés, mais sans tests.
- **`pre-push` hors de la branche courante** : tests dans un worktree temporaire, où seul `node_modules` est relié.
- **Premier lancement** sur Helm, Kubernetes ou Terraform : téléchargement des schémas et providers, ensuite en cache.
