# shellcheck shell=bash
# Suivi des tickets, vérification « ticket » d'une PR (statut de commit
# exigé par la protection) et merge automatique des PR de travail.
# Chargé par ci/tickets.sh (après hooks/lib/common.sh et hooks/lib/tickets.sh).
# shellcheck disable=SC2154 # statuts, réglages et compteurs définis dans les autres modules

# Vérification « ticket » (statut de commit) de la PR $1, commit $2
verifier() {
    local pr="$1" sha="$2" tickets="$3" n attente="" liste
    for n in $tickets; do est_valide "$n" || attente="$attente #$n"; done
    if [ -z "$tickets" ]; then
        _tr tk.none; etat=failure
    elif [ -n "$attente" ]; then
        _tr tk.waiting "${attente# }" "$VALIDE"; etat=failure
    else
        liste=""
        for n in $tickets; do liste="$liste #$n"; done
        _tr tk.ok "${liste# }"; etat=success
    fi
    echo "$_T"
    gh api "repos/$GH_REPO/statuses/$sha" -f state="$etat" -f context=ticket \
        -f description="${_T:0:140}" >/dev/null
    [ "$etat" = success ]
}

# Merge automatique (squash) de la PR de travail $1, cible $2, brouillon $3 :
# armé quand elle est prête, vise la branche d'intégration et que son ticket
# est validé (appelé après une vérification réussie) ; désarmé en brouillon.
# Seulement avec le jeton de l'App : un merge fait avec le jeton des Actions ne
# déclencherait aucun workflow (préversion, livraison, tickets).
merge_auto() {
    local pr="$1" base="$2" brouillon="$3"
    [ "${AUTO_MERGE:-true}" = true ] && [ "$base" = "${INTEGRATION:-develop}" ] || return 0
    if [ "$brouillon" = true ]; then
        gh pr merge "$pr" --disable-auto >/dev/null 2>&1 || true
        return 0
    fi
    if [ "${APP_TOKEN:-false}" != true ]; then
        notice_t tk.automerge_no_app "$pr"
        return 0
    fi
    if gh pr merge "$pr" --auto --squash >/dev/null 2>&1; then
        notice_t tk.automerge_armed "$pr"
    else
        notice_t tk.automerge_failed "$pr"
    fi
}
