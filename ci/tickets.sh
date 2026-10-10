#!/usr/bin/env bash
# Suivi des tickets (issues GitHub) : chaque PR est reliée à un ticket validé,
# et le ticket suit le travail jusqu'à la production.
#
#   ci/tickets.sh pr        événement pull_request : ticket créé s'il manque,
#                           statut du ticket, vérification « ticket » de la PR
#   ci/tickets.sh issue     événement issues : nouveau ticket à valider ;
#                           étiquette « validé » → backlog, branche du ticket
#                           créée (liée au ticket), PR débloquées ; assigné →
#                           en cours ; fermé « not planned » → PR et branche
#                           fermées
#   ci/tickets.sh push      premier push sur la branche d'un ticket : PR
#                           brouillon ouverte, ticket en cours
#   ci/tickets.sh revue     corrections demandées en revue → en cours
#   ci/tickets.sh release   release publiée : tickets en préprod → done (fermés),
#                           ou prévenus de la préversion
#   ci/tickets.sh adopter   mise en route (tickets init) : tickets existants
#                           rangés, branches des PR inscrites sur leurs tickets
#
# Le ticket d'abord, la branche en découle : à valider → (validé : branche
# type/12-titre) backlog → en cours → en relecture → préprod → done. Seul un
# mainteneur pose « validé » (droits GitHub).
# Lien PR → ticket : « Ticket : #12 » dans la description, ou une branche
# feat/12-sujet. « Closes #12 » fermerait le ticket dès le merge dans develop :
# c'est la release qui le ferme.
#
# Variables : GH_TOKEN, GH_REPO, INTEGRATION ; pr : PR, ACTION, MERGED, DRAFT,
# HEAD, BASE, HEAD_SHA, AUTHOR ; issue : ISSUE, ACTION, LABEL, STATE_REASON ;
# push : PUSH_BRANCH, DELETED, PUSHER, SHA ; revue : PR, HEAD, REVIEW_STATE ;
# release : TAG
set -euo pipefail

REPOWARDEN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../hooks/lib/common.sh
source "$REPOWARDEN_DIR/hooks/lib/common.sh"
# shellcheck source=../hooks/lib/tickets.sh
source "$REPOWARDEN_DIR/hooks/lib/tickets.sh"
INTEGRATION="${INTEGRATION:-develop}"

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
    branch_ticket_r "$branch"
    n="$REPLY"
    if [ -n "$n" ]; then
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
    # ${a[@]+…} : tableau vide accepté sous set -u par le bash 3.2 de macOS
    gh issue edit "$n" --add-label "$s" ${retirer[@]+"${retirer[@]}"} >/dev/null
}

etiquettes() { gh issue view "$1" --json labels -q '.labels[].name' 2>/dev/null || true; }

# REPLY = « <n° de PR> <branche cible> » de la PR dont le merge a fermé le
# ticket $1, vide si le ticket a été fermé autrement (à la main, release…)
fermee_par_pr_r() {
    # shellcheck disable=SC2016 # variables GraphQL, pas du shell
    REPLY="$(gh api graphql -f query='query($o: String!, $r: String!, $n: Int!) {
  repository(owner: $o, name: $r) { issue(number: $n) {
    timelineItems(last: 1, itemTypes: CLOSED_EVENT) { nodes { ... on ClosedEvent {
      closer { ... on PullRequest { number baseRefName } } } } } } } }' \
        -f o="${GH_REPO%%/*}" -f r="${GH_REPO#*/}" -F n="$1" \
        -q '.data.repository.issue.timelineItems.nodes[0].closer // empty | "\(.number) \(.baseRefName)"' \
        2>/dev/null || true)"
}

# Personnes assignées au ticket $1 (une par ligne)
assignes() { gh issue view "$1" --json assignees -q '.assignees[].login' 2>/dev/null || true; }

est_mainteneur() { [[ "${1:-}" =~ ^(OWNER|MEMBER|COLLABORATOR)$ ]]; }

# Registre des branches d'un ticket : repère invisible dans les commentaires
# du bot. GitHub ne lie une branche au ticket qu'à sa création, et une branche
# liée supprimée y perd son nom : le registre garde le nom de chaque branche.
REPERE="repowarden:branche"
repere() { printf '<!-- %s %s -->' "$REPERE" "$1"; }

# REPLY = branches inscrites sur le ticket $1 (séparées par des espaces)
branches_inscrites_r() {
    local corps
    corps="$(gh issue view "$1" --json comments -q '.comments[].body' 2>/dev/null || true)"
    REPLY="$(grep -oE "<!-- $REPERE [^ ]+ -->" <<<"$corps" | awk '{ printf "%s ", $3 }' || true)"
    REPLY="${REPLY% }"
}

# Inscrit la branche $2 sur le ticket $1, une seule fois ($3 : origine, ex. PR #7).
# Une seconde branche pour le même ticket est inscrite et signalée.
INSCRITES=0
inscrire_branche() {
    local n="$1" b="$2" origine="${3:-}"
    branches_inscrites_r "$n"
    [[ " $REPLY " != *" $b "* ]] || return 0
    if [ -n "$REPLY" ]; then
        _tr tk.branch_second "$b" "${REPLY// /, }"
        notice "$_T"
    else
        _tr tk.branch_registered "$b"
    fi
    [ -z "$origine" ] || _T="$_T ($origine)"
    gh issue comment "$n" --body "$_T"$'\n\n'"$(repere "$b")" >/dev/null
    INSCRITES=$((INSCRITES + 1))
}
est_valide() { grep -qxF "$VALIDE" <<<"$(etiquettes "$1")"; }

# REPLY = branche du dépôt portant le ticket $1 (type/<n>-…), vide si aucune
branche_du_ticket_r() {
    local ref
    REPLY=""
    while IFS= read -r ref; do
        ref="${ref#refs/heads/}"
        branch_ticket_r "$ref"
        if [ "$REPLY" = "$1" ]; then REPLY="$ref"; return 0; fi
        REPLY=""
    done < <(gh api "repos/$GH_REPO/git/matching-refs/heads/" --paginate -q '.[].ref' 2>/dev/null || true)
}

# Ticket $1 validé : sa branche naît de la branche d'intégration, liée au
# ticket (panneau « Development »). Rien si elle existe déjà, ou si une PR
# ouverte cite déjà le ticket (travail commencé hors de sa branche).
creer_branche() {
    local n="$1" titre labels branche pr head body
    # Travail déjà mergé ou en production : plus de branche à (re)créer
    travail_termine "$(etiquettes "$n")" && return 0
    branche_du_ticket_r "$n"
    [ -z "$REPLY" ] || return 0
    while IFS=$'\t' read -r pr head; do
        [ -n "$pr" ] || continue
        body="$(gh pr view "$pr" --json body -q .body)"
        pr_tickets_r "$body" "$head"
        [[ " $REPLY " != *" $n "* ]] || return 0
    done < <(gh pr list --state open --json number,headRefName -q '.[] | [.number, .headRefName] | @tsv')
    titre="$(gh issue view "$n" --json title -q .title)"
    labels="$(etiquettes "$n")"
    ticket_type_r "$labels"
    ticket_branch_r "$n" "$titre" "$REPLY"
    branche="$REPLY"
    # shellcheck disable=SC2016 # variables GraphQL, pas du shell
    gh api graphql -f query='mutation($issue: ID!, $repo: ID!, $oid: GitObjectID!, $name: String!) {
  createLinkedBranch(input: {issueId: $issue, repositoryId: $repo, oid: $oid, name: $name}) { linkedBranch { id } }
}' -f issue="$(gh issue view "$n" --json id -q .id)" \
        -f repo="$(gh api "repos/$GH_REPO" -q .node_id)" \
        -f oid="$(gh api "repos/$GH_REPO/git/ref/heads/$INTEGRATION" -q .object.sha)" \
        -f name="$branche" >/dev/null
    _tr tk.branch_created "$branche" "$INTEGRATION" "$n" "$branche"
    gh issue comment "$n" --body "$_T"$'\n\n'"$(repere "$branche")" >/dev/null
    notice_t tk.branch_notice "$branche" "$n"
}

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
    # PR partant d'une branche persistante : seules la livraison (develop →
    # main) et le retour (main → develop, si main a un contenu propre) ont un
    # sens ; les autres sont fermées, avec la marche à suivre
    if [[ "$HEAD" == "${INTEGRATION:-develop}" || "$HEAD" == "${MAIN:-main}" ]] &&
        [[ "$ACTION" == opened || "$ACTION" == reopened ]]; then
        if [[ "$HEAD" == "${INTEGRATION:-develop}" && "${BASE:-}" != "${MAIN:-main}" ]] ||
            [[ "$HEAD" == "${MAIN:-main}" && "${BASE:-}" != "${INTEGRATION:-develop}" ]]; then
            _tr tk.pr_inverted "$HEAD" "${BASE:-}" "${INTEGRATION:-develop}"
            gh pr close "$PR" --comment "$_T" >/dev/null
            notice "$_T"
        elif [ "$HEAD" = "${MAIN:-main}" ] &&
            [ "$(gh api "repos/$GH_REPO/compare/$BASE...$HEAD" -q '.files | length')" = 0 ]; then
            _tr tk.pr_backmerge_empty "$HEAD" "$BASE"
            gh pr close "$PR" --comment "$_T" >/dev/null
            notice "$_T"
        fi
    fi
    # Bots de dépendances, PR de release, livraisons et retours : pas de ticket
    # exigé. Les PR ouvertes par le suivi des tickets lui-même (jeton des
    # Actions, github-actions[bot]) citent leur ticket : suivies normalement.
    if [[ "${AUTHOR:-}" =~ ^(dependabot|renovate)(\[bot\])?$ || "$HEAD" == release-please--* ||
        "$HEAD" == "${INTEGRATION:-develop}" || "$HEAD" == "${MAIN:-main}" ]]; then
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
    # Le blocage est porté par le statut « ticket » (exigé par la protection) :
    # le job reste vert, un rouge signale une vraie panne
    verifier "$PR" "$HEAD_SHA" "$tickets" || true
}

# Ticket $1 validé : backlog s'il attendait la validation, sa branche, et
# vérification relancée sur les PR ouvertes qui l'attendaient
accepter() {
    local n="$1" pr head sha body
    if grep -qxF "$S_AVALIDER" <<<"$(etiquettes "$n")"; then
        statut "$n" "$S_BACKLOG"
    fi
    # La branche naît quand le ticket est pris (assigné) : un ticket validé
    # pour plus tard n'a pas de branche qui vieillit en attendant
    if [ -n "$(assignes "$n")" ]; then
        creer_branche "$n"
    else
        _tr tk.validated_waiting "$n"
        gh issue comment "$n" --body "$_T" >/dev/null
    fi
    while IFS=$'\t' read -r pr head sha; do
        [ -n "$pr" ] || continue
        body="$(gh pr view "$pr" --json body -q .body)"
        pr_tickets_r "$body" "$head"
        [[ " $REPLY " == *" $n "* ]] || continue
        verifier "$pr" "$sha" "$REPLY" || true
    done < <(gh pr list --state open --json number,headRefName,headRefOid \
        -q '.[] | [.number, .headRefName, .headRefOid] | @tsv')
}

cmd_issue() {
    local pr sha head body
    case "$ACTION" in
        opened)
            est_valide "$ISSUE" && return 0
            # Ouvert par un mainteneur (droits d'écriture) : c'est déjà sa
            # décision, validé d'office ; sinon, un mainteneur pose « validé »
            if [ "${AUTO_VALIDATE:-maintainers}" = maintainers ] &&
                est_mainteneur "${ISSUE_ASSOCIATION:-}"; then
                gh issue edit "$ISSUE" --add-label "$VALIDE" >/dev/null
                statut "$ISSUE" "$S_AVALIDER"
                accepter "$ISSUE"
            else
                statut "$ISSUE" "$S_AVALIDER"
            fi
            ;;
        labeled)
            [ "${LABEL:-}" = "$VALIDE" ] || return 0
            accepter "$ISSUE"
            ;;
        assigned)
            # Pris en charge : sa branche (s'il est validé), en cours s'il
            # attendait dans le backlog
            est_valide "$ISSUE" && creer_branche "$ISSUE"
            grep -qxF "$S_BACKLOG" <<<"$(etiquettes "$ISSUE")" && statut "$ISSUE" "$S_ENCOURS"
            return 0
            ;;
        closed)
            # Fermé par GitHub au merge d'une PR liée dans la branche par défaut
            # (develop) : pas encore en production, rouvert en préprod. Une
            # fermeture à la main (sans PR) est respectée.
            if [ "${STATE_REASON:-}" = completed ] && ! grep -qxF "$S_DONE" <<<"$(etiquettes "$ISSUE")"; then
                fermee_par_pr_r "$ISSUE"
                local fpr="${REPLY%% *}" fbase="${REPLY#* }"
                if [ -n "$fpr" ] && [ "$fbase" != "${MAIN:-main}" ]; then
                    gh issue reopen "$ISSUE" >/dev/null
                    statut "$ISSUE" "$S_PREPROD"
                    _tr tk.reopened "$fpr" "$fbase"
                    gh issue comment "$ISSUE" --body "$_T" >/dev/null
                    notice "$_T"
                fi
                return 0
            fi
            # Abandonné : PR fermées, branche supprimée (un ticket terminé est
            # fermé par la release, sa branche est déjà supprimée au merge)
            [ "${STATE_REASON:-}" = not_planned ] || return 0
            branche_du_ticket_r "$ISSUE"
            [ -n "$REPLY" ] || return 0
            local branche="$REPLY"
            while IFS= read -r pr; do
                [ -n "$pr" ] || continue
                _tr tk.abandoned "$ISSUE"
                gh pr close "$pr" --comment "$_T" >/dev/null
            done < <(gh pr list --state open --head "$branche" --json number -q '.[].number')
            gh api -X DELETE "repos/$GH_REPO/git/refs/heads/$branche" >/dev/null
            notice_t tk.branch_deleted "$branche" "$ISSUE"
            ;;
    esac
}

# Premier push sur la branche d'un ticket : PR brouillon vers la branche
# d'intégration, citant le ticket, assignée à l'auteur du push ; ticket en
# cours. Ouverte par le jeton des Actions, elle ne lance pas la CI : elle
# tourne au push suivant, ou au passage « prête pour revue ».
cmd_push() {
    local n pr titre type url
    : "${PUSH_BRANCH:?}" "${SHA:?}"
    [ "${DELETED:-false}" != true ] || return 0
    branch_ticket_r "$PUSH_BRANCH"
    n="$REPLY"
    [ -n "$n" ] || return 0
    # Branche faite hors du ticket (à la main) : inscrite sur le ticket
    inscrire_branche "$n" "$PUSH_BRANCH"
    pr="$(gh pr list --state open --head "$PUSH_BRANCH" --json number -q '.[0].number // empty')"
    [ -z "$pr" ] || return 0
    [ "$(gh api "repos/$GH_REPO/compare/$INTEGRATION...$PUSH_BRANCH" -q .ahead_by)" != 0 ] || return 0
    titre="$(gh issue view "$n" --json title -q .title)"
    type="${PUSH_BRANCH%%/*}"
    case "$type" in feature) type=feat ;; bugfix | hotfix) type=fix ;; esac
    # Titre conventionnel (message du commit en squash) : type: titre du ticket
    titre="$type: $(tr '[:upper:]' '[:lower:]' <<<"${titre:0:1}")${titre:1}"
    authored_length "$titre"
    [ "$REPLY" -le 72 ] || titre="${titre:0:72}"
    url="$(gh pr create --draft --base "$INTEGRATION" --head "$PUSH_BRANCH" --title "$titre" \
        --body "Ticket : #$n" ${PUSHER:+--assignee "$PUSHER"})"
    [ -z "${PUSHER:-}" ] || gh issue edit "$n" --add-assignee "$PUSHER" >/dev/null || true
    est_valide "$n" && statut "$n" "$S_ENCOURS"
    notice_t tk.draft_opened "${url##*/}" "$n"
    verifier "${url##*/}" "$SHA" "$n" || true
}

# Revue : corrections demandées → le ticket repasse en cours
cmd_revue() {
    local body n
    : "${PR:?}" "${HEAD:?}"
    [ "${REVIEW_STATE:-}" = changes_requested ] || return 0
    body="$(gh pr view "$PR" --json body -q .body)"
    pr_tickets_r "$body" "$HEAD"
    for n in $REPLY; do
        est_valide "$n" && statut "$n" "$S_ENCOURS"
    done
    return 0
}

# Mise en route sur un dépôt existant (tickets init, relançable) : tickets
# ouverts sans statut rangés (validé ou ouvert par un mainteneur → backlog,
# sinon à valider) ; branches des PR ouvertes et mergées inscrites sur les
# tickets qu'elles citent. Aucune branche créée en masse : elle naît quand le
# ticket est pris (repowarden ticket N).
cmd_adopter() {
    local n assoc labels pr head ranges=0 t
    while IFS=$'\t' read -r n assoc; do
        [ -n "$n" ] || continue
        labels="$(etiquettes "$n")"
        ! grep -q '^statut: ' <<<"$labels" || continue
        if grep -qxF "$VALIDE" <<<"$labels"; then
            statut "$n" "$S_BACKLOG"
        elif [ "${AUTO_VALIDATE:-maintainers}" = maintainers ] && est_mainteneur "$assoc"; then
            gh issue edit "$n" --add-label "$VALIDE" >/dev/null
            statut "$n" "$S_BACKLOG"
        else
            statut "$n" "$S_AVALIDER"
        fi
        ranges=$((ranges + 1))
    done < <(gh api "repos/$GH_REPO/issues?state=open&per_page=100" --paginate \
        -q '.[] | select(.pull_request | not) | [.number, .author_association] | @tsv')
    while IFS=$'\t' read -r pr head; do
        [ -n "$pr" ] || continue
        [[ "$head" != "${INTEGRATION:-develop}" && "$head" != release-please--* ]] || continue
        pr_tickets_r "$(gh pr view "$pr" --json body -q .body)" "$head"
        for t in $REPLY; do inscrire_branche "$t" "$head" "PR #$pr"; done
    done < <(gh pr list --state all --limit 1000 --json number,headRefName,state \
        -q '.[] | select(.state != "CLOSED") | [.number, .headRefName] | @tsv')
    _tr tk.adopted "$ranges" "$INSCRITES"
    echo "$_T"
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

notice() { echo "::notice title=repowarden::$*"; }
notice_t() { _tr "$@"; notice "$_T"; }

# Chargé par les tests (source) : fonctions seulement
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

case "${1:-}" in
    pr) cmd_pr ;;
    issue) cmd_issue ;;
    push) cmd_push ;;
    revue) cmd_revue ;;
    release) cmd_release ;;
    adopter) cmd_adopter ;;
    *) echo "usage : ci/tickets.sh pr|issue|push|revue|release|adopter" >&2; exit 2 ;;
esac
