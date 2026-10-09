#!/usr/bin/env bash
# Tickets côté poste et côté CI : numéro du ticket d'une branche, nom de la
# branche d'un ticket, suivi des tickets géré ou non par repowarden.
# Chargé après common.sh. Compatible bash 3.2.
# shellcheck disable=SC2034 # statuts utilisés par les scripts qui chargent ce fichier

# Statuts (étiquettes) du cycle d'un ticket
VALIDE="validé"
S_AVALIDER="statut: à valider"
S_BACKLOG="statut: backlog"
S_ENCOURS="statut: en cours"
S_RELECTURE="statut: en relecture"
S_PREPROD="statut: préprod"
S_DONE="statut: done"

# REPLY = numéro du ticket porté par la branche $1 (type/12-sujet, type/12),
# vide sinon
branch_ticket_r() {
    REPLY=""
    if [[ "$1" =~ ^[a-z]+/([0-9]+)(-|$) ]]; then REPLY="${BASH_REMATCH[1]}"; fi
}

# REPLY = nom de branche d'un ticket : $1 numéro, $2 titre, $3 type (feat
# par défaut) → feat/12-ajoute-le-panier (minuscules, sans accents, 40
# caractères de titre au plus, coupé sur un tiret)
ticket_branch_r() {
    local n="$1" titre="$2" type="${3:-feat}" slug
    # Accents retirés un à un (pas de classe [àâ] : fausse en locale C)
    slug="$(printf '%s' "$titre" | sed -e 's/à/a/g' -e 's/â/a/g' -e 's/ä/a/g' -e 's/é/e/g' -e 's/è/e/g' -e 's/ê/e/g' -e 's/ë/e/g' -e 's/î/i/g' -e 's/ï/i/g' -e 's/ô/o/g' -e 's/ö/o/g' -e 's/ù/u/g' -e 's/û/u/g' -e 's/ü/u/g' -e 's/ç/c/g' -e 's/œ/oe/g' -e 's/æ/ae/g' -e 's/À/a/g' -e 's/Â/a/g' -e 's/Ä/a/g' -e 's/É/e/g' -e 's/È/e/g' -e 's/Ê/e/g' -e 's/Ë/e/g' -e 's/Î/i/g' -e 's/Ï/i/g' -e 's/Ô/o/g' -e 's/Ö/o/g' -e 's/Ù/u/g' -e 's/Û/u/g' -e 's/Ü/u/g' -e 's/Ç/c/g' -e 's/Œ/oe/g' -e 's/Æ/ae/g' |
        LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')"
    if [ "${#slug}" -gt 40 ]; then
        slug="${slug:0:40}"
        [[ "$slug" == *-* ]] && slug="${slug%-*}"
    fi
    REPLY="$type/$n${slug:+-$slug}"
}

# REPLY = type de branche d'après les étiquettes d'un ticket (une par ligne) :
# « type: fix », « bug » → fix ; feat par défaut
ticket_type_r() {
    local l
    REPLY=feat
    while IFS= read -r l; do
        case "$l" in
            "type: "*) REPLY="${l#type: }"; return 0 ;;
            bug) REPLY=fix ;;
        esac
    done <<<"$1"
}

# Vrai si la branche $1 est une branche de travail : ni protégée, ni une
# exception (main, develop, branches des bots…)
work_branch() {
    local branch="$1" pat
    [ -n "$branch" ] || return 1
    cfg_r allowedBranches "$DEFAULT_ALLOWED_BRANCHES"
    set -f
    for pat in $REPLY; do
        # shellcheck disable=SC2254
        case "$branch" in $pat) set +f; return 1 ;; esac
    done
    set +f
    cfg_r protectedBranches "main master"
    [[ " $REPLY " != *" $branch "* ]]
}

# Vrai si le suivi des tickets du projet est géré par repowarden : réglage
# tickets (true/false), sinon un workflow du dépôt appelle tickets.yml
TICKETS_MANAGED=""
tickets_managed() {
    local f
    if [ -z "$TICKETS_MANAGED" ]; then
        TICKETS_MANAGED=non
        cfg_r tickets ""
        case "$REPLY" in
            true | oui | yes) TICKETS_MANAGED=oui ;;
            false | non | no) ;;
            *)
                for f in "$GIT_TOPLEVEL"/.github/workflows/*.yml "$GIT_TOPLEVEL"/.github/workflows/*.yaml; do
                    [ -f "$f" ] || continue
                    if grep -qsE 'uses:.*workflows/tickets\.ya?ml' "$f"; then TICKETS_MANAGED=oui; break; fi
                done
                ;;
        esac
    fi
    [ "$TICKETS_MANAGED" = oui ]
}

# Branche de travail sans ticket : avertissement, jamais bloquant. Création
# proposée seulement si repowarden gère la vie des tickets du projet (et que
# gh est là pour la faire) ; sinon, comment faire taire l'avertissement.
ticket_hint() {
    local branch="$1"
    skipped tickets && return 0
    work_branch "$branch" || return 0
    branch_ticket_r "$branch"
    [ -z "$REPLY" ] || return 0
    attention_t tk.cli.no_ticket "$branch"
    if tickets_managed && has gh; then
        dim_t tk.cli.propose
    else
        dim_t tk.cli.silence
    fi
}
