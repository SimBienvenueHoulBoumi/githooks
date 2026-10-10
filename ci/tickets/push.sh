# shellcheck shell=bash
# Suivi des tickets, premier push d'une branche de ticket (PR brouillon) et
# revues (ci/tickets.sh push, revue).
# Chargé par ci/tickets.sh (après hooks/lib/common.sh et hooks/lib/tickets.sh).
# shellcheck disable=SC2154 # statuts, réglages et compteurs définis dans les autres modules

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
    # Titre conventionnel : lecture de l'étiquette 'type:' du ticket si présente,
    # sinon déduction depuis le titre 'Tickets : ...' pour la portée,
    # le tout ≤ 72 caractères, coupé sur un mot.
    # Extraire la portée depuis le titre du ticket "Tickets : ..."
    scope=""
    if [[ "$titre" =~ ^Tickets[[:space:]]*:[[:space:]]*([a-zA-Z0-9_]+) ]]; then
        scope="${BASH_REMATCH[1]}"
    fi
    [ -z "$scope" ] && scope="tickets"
    # Construire le titre : type(scope): sujet
    # Nettoyer le titre du ticket : minuscules, sans accents, sur un mot
    clean="$(printf '%s' "$titre" | sed 's/à/a/g; s/â/a/g; s/ä/a/g; s/é/e/g; s/è/e/g; s/ê/e/g; s/ë/e/g; s/î/i/g; s/ï/i/g; s/ô/o/g; s/ö/o/g; s/ù/u/g; s/û/u/g; s/ü/u/g; s/ç/c/g; s/œ/oe/g; s/æ/ae/g; s/À/a/g; s/Â/a/g; s/Ä/a/g; s/É/e/g; s/È/e/g; s/Ê/e/g; s/Ë/e/g; s/Î/i/g; s/Ï/i/g; s/Ô/o/g; s/Ö/o/g; s/Ù/u/g; s/Û/u/g; s/Ü/u/g; s/Ç/c/g; s/Œ/oe/g; s/Æ/ae/g' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed 's/[^a-z0-9 -]\{1,\}/ - /g; s/ -$//; s/^ -//')"
    new_title="$type($scope): $clean"
    authored_length "$new_title"
    [ "$REPLY" -le 72 ] || new_title="${new_title:0:72}"
    # Couper sur un mot si dépassement
    if [ "$REPLY" -gt 72 ]; then
        new_title="$(printf '%s' "$new_title" | sed 's/ .*//')"
    fi
    titre="$new_title"
    # Description : corps du ticket + Ticket : #N, mis à jour à chaque push
    url="$(gh pr create --draft --base "$INTEGRATION" --head "$PUSH_BRANCH" --title "$titre" \
        --body "$_T$'\n\nTicket : #$n'" ${PUSHER:+--assignee "$PUSHER"})"
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
