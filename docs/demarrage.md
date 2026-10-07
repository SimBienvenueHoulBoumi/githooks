# Démarrage rapide

Trois parcours, selon l'usage. Le plus rapide pour essayer : **Sur mon poste**.

=== "Sur mon poste"

    Tous tes dépôts, sans rien ajouter aux projets :

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
    ~/repogarde/install.sh --global      # demande la langue (fr / en), installe git cc
    ```

    Essai immédiat, dans n'importe quel dépôt :

    ```bash
    git switch -c feat/panier            # nom de branche vérifié
    git add . && git cc                  # assistant de commit (type, scope, description…)
    git push -u origin feat/panier       # tests des projets touchés avant l'envoi
    ~/repogarde/bin/code-mort            # nouveau code mort de la branche
    ```

    | Action | Commande |
    |---|---|
    | Vérifier | `git config --global core.hooksPath` → `…/repogarde/hooks` |
    | Mettre à jour | `git -C ~/repogarde pull` |
    | Changer de langue | `~/repogarde/install.sh --global --lang en` |
    | Un seul dépôt | `cd mon-projet && ~/repogarde/install.sh` |
    | Désinstaller | `~/repogarde/install.sh --uninstall --global` ([désinstallation complète](desinstallation.md)) |

    Un dépôt qui contient un `lefthook.yml` utilise sa propre configuration (version figée), si lefthook est installé.

    **Avec npm** (Node installé) : même résultat, en commande globale de la machine. Rien n'est ajouté aux projets ni à leur `package.json`.

    ```bash
    npm install -g @simbienvenuehoulboumi/repogarde
    repogarde install --global           # demande la langue, installe git cc
    repogarde code-mort                  # toutes les commandes : repogarde --help
    ```

    | Action | Commande |
    |---|---|
    | Mettre à jour | `npm update -g @simbienvenuehoulboumi/repogarde` (les hooks suivent) |
    | Désinstaller | `repogarde uninstall --global`, puis `npm uninstall -g @simbienvenuehoulboumi/repogarde` |

    `npx` est refusé pour l'installation globale : son dossier temporaire peut être effacé à tout moment. Avec nvm, chaque version de Node a ses propres paquets globaux : relancer `repogarde install --global` après un changement de version.

=== "Un projet d'équipe"

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
        | `.github/workflows/release.yml` | [releases automatiques](releases.md) (optionnel) |
        | `gitlab-ci.yml` | à fusionner dans `.gitlab-ci.yml` |
        | `.repogarde.conf` | réglages partagés (optionnel) |

    3. Activer les hooks : `lefthook install`.
    4. Protéger `main` et exiger le check `repogarde` : `bin/proteger` (voir [En organisation](industrialisation.md)).

    **Ensuite, chaque personne qui clone le projet** installe lefthook une fois, puis :

    ```bash
    git clone <url-du-projet> && cd <projet>
    lefthook install                     # hooks du projet, à la version figée dans lefthook.yml
    ```

    Rien d'autre : repogarde est récupéré par lefthook, à la version du projet. Avec l'installation « Sur mon poste », ce `lefthook install` est même inutile. Un projet Maven, Gradle ou npm peut l'installer au premier build ([En organisation](industrialisation.md)). Sans hooks, la CI refait toutes les vérifications.

=== "Une organisation"

    Le [guide En organisation](industrialisation.md) couvre l'hébergement de repogarde, les versions, l'installation automatique sur les postes (Maven, Gradle, npm) et la protection des branches GitHub / GitLab.

=== "Contribuer à repogarde"

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git && cd repogarde
    ./install.sh                         # repogarde se vérifie lui-même
    bats test/                           # tests (bats-core), aussi lancés au push
    ```

    Voir [Contribuer](contribuer.md).

## Prérequis

| Élément | Requis | Notes |
|---|---|---|
| git + bash | oui | macOS, Linux, Windows via [Git for Windows](https://gitforwindows.org) |
| Outils des langages utilisés | selon les projets | un outil absent est ignoré sur le poste |
| [gitleaks](https://github.com/gitleaks/gitleaks) | conseillé | `brew install gitleaks` · `apt install gitleaks` · `winget install gitleaks` |
