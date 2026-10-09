#!/usr/bin/env bash
# Suivi des tickets (issues GitHub) : chaque PR est reliée à un ticket validé,
# et le ticket suit le travail jusqu'à la production.
#
#   ci/tickets.sh pr        événement pull_request : ticket créé s'il manque,
#                           statut du ticket, vérification « ticket » de la PR
#   ci/tickets.sh issue     événement issues : nouveau ticket à valider ;
#                           étiquette « validé » → backlog, PR débloquées
#   ci/tickets.sh release   release publiée : tickets en préprod → done (fermés),
#                           ou prévenus de la préversion
#
# Statuts (étiquettes) : à valider → backlog → en cours → en relecture →
# préprod → done. Seul un mainteneur pose « validé » (droits GitHub).
# Lien PR → ticket : « Ticket : #12 » dans la description, ou une branche
# feat/12-sujet. « Closes #12 » fermerait le ticket dès le merge dans develop :
# c'est la release qui le ferme.
#
# Variables : GH_TOKEN, GH_REPO ; pr : PR, ACTION, MERGED, DRAFT, HEAD, BASE,
# HEAD_SHA, AUTHOR ; issue : ISSUE, ACTION, LABEL ; release : TAG
set -euo pipefail

REPOGARDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../hooks/lib/common.sh
source "$REPOGARDE_DIR/hooks/lib/common.sh"

VALIDE="validé"
S_AVALIDER="statut: à valider"
S_BACKLOG="statut: backlog"
S_ENCOURS="statut: en cours"
S_RELECTURE="statut: en relecture"
S_PREPROD="statut: préprod"
S_DONE="statut: done"

# REPLY = numéros de tickets (uniques) cités par la description $1 (« Ticket : #12 »,
# « Tickets : #3, #4 », ou un mot-clé de fermeture) et la branche $2 (type/12-sujet)
pr_tickets_r() {
    local body="$1" branch="$2" found="" n line
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*(Tickets?|Refs?|Closes|Fixes|Resolves)[[:space:]]*:?[[:space:]]*(.*)$ ]]; then
            for n in $(grep -oE '#[0-9]+' <<<"${BASH_REMATCH[2]}" | tr -d '#'); do
                [[ " $found " == *" $n "* ]] || found="$found $n"
            done
        fi
    done <<<"$body"
    if [[ "$branch" =~ ^[a-z]+/([0-9]+)(-|$) ]]; then
        n="${BASH_REMATCH[1]}"
        [[ " $found " == *" $n "* ]] || found="$found $n"
    fi
    REPLY="${found# }"
}

# Statut $2 sur le ticket $1 : remplace les autres étiquettes « statut: »
statut() {
    local n="$1" s="$2" l retirer=()
    while IFS= read -r l; do
        [[ "$l" == "statut: "* && "$l" != "$s" ]] && retirer+=(--remove-label "$l")
    done < <(gh issue view "$n" --json labels -q '.labels[].name' 2>/dev/null || true)
    gh issue edit "$n" --add-label "$s" "${retirer[@]}" >/dev/null
}

est_valide() { grep -qxF "$VALIDE" <<<"$(gh issue view "$1" --json labels -q '.labels[].name' 2>/dev/null || true)"; }

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

cmd_pr() {
    local body tickets n url
    : "${PR:?}" "${HEAD:?}" "${HEAD_SHA:?}" "${ACTION:?}"
    # Bots de dépendances et PR de release : pas de ticket exigé
    if [[ "${AUTHOR:-}" =~ \[bot\]$ || "$HEAD" == release-please--* || "$HEAD" == "${INTEGRATION:-develop}" ]]; then
        gh api "repos/$GH_REPO/statuses/$HEAD_SHA" -f state=success -f context=ticket \
            -f description="Sans ticket (bot, release ou livraison)" >/dev/null
        return 0
    fi
    body="$(gh pr view "$PR" --json body -q .body)"
    pr_tickets_r "$body" "$HEAD"
    tickets="$REPLY"

    if [ "$ACTION" = closed ]; then
        [ "${MERGED:-false}" = true ] || return 0
        for n in $tickets; do
            statut "$n" "$S_PREPROD"
            _tr tk.merged "$PR" "$BASE"
            gh issue comment "$n" --body "$_T" >/dev/null
        done
        return 0
    fi

    # Aucun ticket : créé à partir de la PR, à valider, et relié à la PR
    if [ -z "$tickets" ]; then
        _tr tk.created_body "$PR"
        url="$(gh issue create --title "$(gh pr view "$PR" --json title -q .title)" \
            --body "$_T" --label "$S_AVALIDER")"
        tickets="${url##*/}"
        gh pr edit "$PR" --body "$(printf '%s\n\nTicket : #%s\n' "$body" "$tickets")" >/dev/null
        notice_t tk.created "$tickets" "$PR"
    fi

    # Statut du travail (seulement pour un ticket validé)
    for n in $tickets; do
        est_valide "$n" || continue
        if [ "${DRAFT:-false}" = true ]; then statut "$n" "$S_ENCOURS"; else statut "$n" "$S_RELECTURE"; fi
    done
    verifier "$PR" "$HEAD_SHA" "$tickets"
}

cmd_issue() {
    local pr sha head body
    case "$ACTION" in
        opened)
            est_valide "$ISSUE" || statut "$ISSUE" "$S_AVALIDER"
            ;;
        labeled)
            [ "${LABEL:-}" = "$VALIDE" ] || return 0
            # Accepté : backlog s'il attendait la validation
            if grep -qxF "$S_AVALIDER" <<<"$(gh issue view "$ISSUE" --json labels -q '.labels[].name')"; then
                statut "$ISSUE" "$S_BACKLOG"
            fi
            # PR ouvertes qui attendaient ce ticket : vérification relancée
            while IFS=$'\t' read -r pr head sha; do
                [ -n "$pr" ] || continue
                body="$(gh pr view "$pr" --json body -q .body)"
                pr_tickets_r "$body" "$head"
                [[ " $REPLY " == *" $ISSUE "* ]] || continue
                verifier "$pr" "$sha" "$REPLY" || true
            done < <(gh pr list --state open --json number,headRefName,headRefOid \
                -q '.[] | [.number, .headRefName, .headRefOid] | @tsv')
            ;;
    esac
}

cmd_release() {
    local n
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        if [[ "$TAG" == *-* ]]; then
            _tr tk.prerelease "$TAG"
            gh issue comment "$n" --body "$_T" >/dev/null
        else
            _tr tk.released "$TAG"
            statut "$n" "$S_DONE"
            gh issue close "$n" --comment "$_T" >/dev/null
        fi
    done < <(gh issue list --state open --label "$S_PREPROD" --limit 500 --json number -q '.[].number')
}

notice() { echo "::notice title=repogarde::$*"; }
notice_t() { _tr "$@"; notice "$_T"; }

# Chargé par les tests (source) : fonctions seulement
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

case "${1:-}" in
    pr) cmd_pr ;;
    issue) cmd_issue ;;
    release) cmd_release ;;
    *) echo "usage : ci/tickets.sh pr|issue|release" >&2; exit 2 ;;
esac
