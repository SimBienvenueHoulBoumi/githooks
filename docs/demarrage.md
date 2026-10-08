# Démarrage rapide

Trois parcours, selon l'usage. Le plus rapide pour essayer : **Sur mon poste**.

=== "Sur mon poste"

    Tous tes dépôts, sans rien ajouter aux projets ni à leur `package.json` :

    ```bash
    npm install -g @simbie/repogarde     # 1. le paquet (yarn global add, pnpm add -g : idem)
    repogarde install --global           # 2. active les hooks : demande la langue, installe git cc
    repogarde                            # 3. vérifie : état du poste et étape suivante
    ```

    L'étape 2 est indispensable : par sécurité, le paquet n'exécute rien à l'installation (aucun script `postinstall`).

    Essai immédiat, dans n'importe quel dépôt :

    ```bash
    git switch -c feat/panier            # nom de branche vérifié
    git add . && git cc                  # assistant de commit (type, scope, description…)
    git push -u origin feat/panier       # tests des projets touchés avant l'envoi
    repogarde code-mort                  # nouveau code mort de la branche
    ```

    | Action | Commande |
    |---|---|
    | État du poste, étape suivante | `repogarde` (ou `repogarde statut`) |
    | Toutes les commandes | `repogarde --help` |
    | Vérifier | `git config --global core.hooksPath` → `…/repogarde/hooks` |
    | Mettre à jour | `npm update -g @simbie/repogarde` (les hooks suivent) |
    | Changer de langue | `repogarde install --global --lang en` |
    | Un seul dépôt | `cd mon-projet && repogarde install` |
    | Désinstaller | `repogarde uninstall --global`, puis `npm uninstall -g @simbie/repogarde` ([désinstallation complète](desinstallation.md)) |

    `npx` est refusé pour l'installation globale : son dossier temporaire peut être effacé à tout moment. Avec nvm, chaque version de Node a ses propres paquets globaux : relancer `repogarde install --global` après un changement de version.

    **Registre npm interne** (entreprise, proxy) : `npm install -g @simbie/repogarde --registry <url>`, ou `registry=<url>` dans `~/.npmrc` ; voir [sources internes](industrialisation.md#8-sources-internes-reseau-ferme-nexus-artifactory).

    **Sans Node** : même résultat depuis un clone, mis à jour avec `git -C ~/repogarde pull` (les commandes deviennent `~/repogarde/install.sh`, `~/repogarde/bin/code-mort`…).

    ```bash
    git clone https://github.com/SimBienvenueHoulBoumi/repogarde.git ~/repogarde
    ~/repogarde/install.sh --global
    ```

    Un dépôt qui contient un `lefthook.yml` utilise sa propre configuration (version figée), si lefthook est installé.

=== "Un projet d'équipe"

    1. **Chaque personne** installe repogarde une fois sur son poste (onglet « Sur mon poste ») : `npm install -g @simbie/repogarde`, puis `repogarde install --global`.

    2. **Le projet** ajoute les modèles de [`templates/project/`](https://github.com/SimBienvenueHoulBoumi/repogarde/tree/main/templates/project) :

        | Fichier | Rôle |
        |---|---|
        | `.github/workflows/repogarde.yml` | CI GitHub : refait les vérifications sur chaque PR, elle fait foi (ajouter les `setup-*` des outils du projet) |
        | `.repogarde.conf` | réglages partagés, dont `version` : version minimale de repogarde attendue sur les postes |
        | `.github/workflows/release.yml` | [releases automatiques](releases.md) (optionnel) |
        | `gitlab-ci.yml` | pour GitLab, à fusionner dans `.gitlab-ci.yml` |

    3. **Rendre la CI obligatoire** pour merger : `repogarde proteger` (voir [En organisation](industrialisation.md)).

    Un poste dont repogarde est plus ancien que la `version` du projet est prévenu à chaque commit, avec la commande de mise à jour. Sans hooks, la CI refait de toute façon toutes les vérifications.

    **Version exacte par projet (avancé)** : avec [lefthook](https://lefthook.dev) et le modèle `lefthook.yml`, chaque projet télécharge repogarde à sa propre version, figée. Chaque personne installe alors lefthook une fois (`brew install lefthook`, `npm install -g lefthook`, `winget install evilmartians.lefthook`), puis `lefthook install` dans le projet ; les hooks repogarde du poste délèguent automatiquement au `lefthook.yml` du projet.

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
