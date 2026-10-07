#!/usr/bin/env bash
# Catalogue français (langue de référence : toute clé existe ici).
# Formats printf : %s pour les arguments, %% pour un « % » littéral.
_msg_fr() {
    case "$1" in
        # Assistant de commit (git cc)
        cc.title) REPLY="commit conventionnel" ;;
        cc.help) REPLY="Entrée = valeur proposée entre [crochets] · Ctrl+C pour abandonner" ;;
        cc.nothing_staged) REPLY="Rien n'est stagé : ajoute d'abord tes modifications (git add …)." ;;
        cc.step1) REPLY="Type de changement" ;;
        cc.type.feat) REPLY="nouvelle fonctionnalité" ;;
        cc.type.fix) REPLY="correction de bug" ;;
        cc.type.docs) REPLY="documentation uniquement" ;;
        cc.type.style) REPLY="formatage, sans changement de logique" ;;
        cc.type.refactor) REPLY="restructuration sans changement de comportement" ;;
        cc.type.perf) REPLY="amélioration de performance" ;;
        cc.type.test) REPLY="ajout ou modification de tests" ;;
        cc.type.build) REPLY="build, dépendances" ;;
        cc.type.ci) REPLY="intégration continue" ;;
        cc.type.chore) REPLY="maintenance diverse" ;;
        cc.type.revert) REPLY="annulation d'un commit" ;;
        cc.type_prompt) REPLY="Numéro ou nom [%s] : " ;;
        cc.type_invalid) REPLY="« %s » : choisis un numéro (1 à %s) ou un nom de la liste." ;;
        cc.step2) REPLY="Scope (optionnel)" ;;
        cc.scope_hint) REPLY="Partie du projet concernée, ex. api, auth, chart ; Entrée pour aucun." ;;
        cc.scope_prompt_default) REPLY="Scope (« - » pour aucun) [%s] : " ;;
        cc.scope_prompt) REPLY="Scope : " ;;
        cc.scope_invalid) REPLY="Scope : minuscules, chiffres, . _ - uniquement." ;;
        cc.step3) REPLY="Changement incompatible ?" ;;
        cc.first_commit) REPLY="Premier commit du dépôt : rien d'existant à casser, question sautée." ;;
        cc.breaking_hint1) REPLY="Oui seulement si l'existant cesse de fonctionner pour ses utilisateurs" ;;
        cc.breaking_hint2) REPLY="(API, configuration, format, commande supprimés ou modifiés). Version majeure." ;;
        cc.breaking_prompt) REPLY="Incompatible ? [o/N] : " ;;
        cc.breaking_note_hint) REPLY="Ce qui casse et comment migrer (affiché dans les notes de version)." ;;
        cc.breaking_note_prompt) REPLY="Ce qui change : " ;;
        cc.breaking_note_invalid) REPLY="Décris le changement (10 caractères au moins) ; sinon, réponds non à la question précédente." ;;
        cc.step4) REPLY="Description" ;;
        cc.desc_hint) REPLY="À l'impératif, sans majuscule initiale ni point final ; %s caractères au plus." ;;
        cc.desc_required) REPLY="La description est obligatoire." ;;
        cc.header_too_long) REPLY="En-tête trop long : %s caractères (72 max). Raccourcis la description." ;;
        cc.step5) REPLY="Détails (optionnels)" ;;
        cc.body_hint) REPLY="Corps : explique le pourquoi, sur plusieurs lignes ; ligne vide pour terminer." ;;
        cc.refs_prompt) REPLY="Références (ex. %s ; Entrée pour aucune) : " ;;
        cc.preview) REPLY="Message" ;;
        cc.confirm) REPLY="Commiter ? [O/n] : " ;;
        cc.aborted) REPLY="Abandonné : rien n'a été commité." ;;
        cc.created) REPLY="Commit créé." ;;
        cc.next_branch) REPLY="Prochains changements : sur une branche, ex. %s, puis une %s." ;;
        cc.topic) REPLY="sujet" ;;
        cc.next_push) REPLY="Envoyer : %s" ;;
        # Installation
        install.unknown_arg) REPLY="Argument inconnu : %s" ;;
        install.not_repo) REPLY="Pas dans un dépôt git (utilise --global pour tous les dépôts)." ;;
        install.alias_taken) REPLY="Alias git cc déjà utilisé ('%s') : assistant de commit non installé." ;;
        install.alias_ok) REPLY="Assistant de commit : git cc" ;;
        install.alias_removed) REPLY="Alias git cc retiré (%s)." ;;
        install.nothing) REPLY="Aucun core.hooksPath (%s) : rien à retirer." ;;
        install.removed) REPLY="Hooks repogarde retirés (%s)." ;;
        install.foreign) REPLY="core.hooksPath (%s) = '%s' n'est pas repogarde : laissé intact." ;;
        install.cache_removed) REPLY="Cache supprimé : %s" ;;
        install.scan) REPLY="Dépôts de %s encore branchés sur repogarde :" ;;
        install.none) REPLY="aucun" ;;
        install.last_step) REPLY="Dernière étape, à lancer toi-même si tu n'utilises plus repogarde :" ;;
        install.purge_needs_uninstall) REPLY="--purge et --scan s'utilisent avec --uninstall." ;;
        install.replaced) REPLY="core.hooksPath (%s) valait '%s', remplacé." ;;
        install.enabled) REPLY="Hooks activés (%s) → %s" ;;
        install.local_wins) REPLY="Un core.hooksPath local (ex. husky) reste prioritaire dans le dépôt concerné." ;;
        install.lang_set) REPLY="Langue des messages : français (changer : ./install.sh --global --lang en)" ;;
        install.lang_invalid) REPLY="--lang : fr ou en." ;;
        *) REPLY="" ;;
    esac
}
