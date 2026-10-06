# Démarrage rapide

Choisir le parcours qui correspond à l'usage.

=== "Un projet (recommandé)"

    1. Installer [lefthook](https://lefthook.dev) sur le poste :

        ```bash
        brew install lefthook          # macOS
        winget install evilmartians.lefthook   # Windows
        npm install -g lefthook        # tout système avec Node
        ```

    2. Ajouter au projet les modèles de [`templates/project/`](https://github.com/SimBienvenueHoulBoumi/repogarde/tree/main/templates/project) :

        | Fichier | Rôle |
        |---|---|
        | `lefthook.yml` | hooks locaux, version de repogarde figée |
        | `.github/workflows/repogarde.yml` | CI GitHub (ajouter les `setup-*` des outils du projet) |
        | `gitlab-ci.yml` | à fusionner dans `.gitlab-ci.yml` |
        | `.repogarde.conf` | réglages partagés (optionnel) |

    3. Activer les hooks : `lefthook install`.
    4. Protéger `main` et exiger le check `repogarde` : voir [En organisation](industrialisation.md).

=== "Une organisation"

    Le [guide En organisation](industrialisation.md) couvre l'hébergement de repogarde, les versions, l'installation automatique sur les postes (Maven, Gradle, npm) et la protection des branches GitHub / GitLab.

=== "Usage personnel"

    Tous les dépôts du poste, sans rien ajouter aux projets :

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
    ~/repogarde/install.sh --global
    ```

    | Action | Commande |
    |---|---|
    | Vérifier | `git config --global core.hooksPath` → `…/repogarde/hooks` |
    | Mettre à jour | `git -C ~/repogarde pull` |
    | Un seul dépôt | `cd mon-projet && ~/repogarde/install.sh` |
    | Désinstaller | `~/repogarde/install.sh --uninstall --global` |

    Un dépôt qui contient un `lefthook.yml` utilise automatiquement sa propre configuration (version figée).

## Prérequis

| Élément | Requis | Notes |
|---|---|---|
| git + bash | oui | macOS, Linux, Windows via [Git for Windows](https://gitforwindows.org) |
| Outils des langages utilisés | selon les projets | un outil absent est ignoré sur le poste |
| [gitleaks](https://github.com/gitleaks/gitleaks) | conseillé | `brew install gitleaks` · `apt install gitleaks` · `winget install gitleaks` |
