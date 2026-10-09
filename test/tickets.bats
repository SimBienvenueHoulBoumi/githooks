#!/usr/bin/env bats
# Suivi des tickets (ci/tickets.sh) : gh simulé, état des tickets en fichiers

load helpers

TICKETS="$BATS_TEST_DIRNAME/../ci/tickets.sh"

setup() {
    setup_repo
    F="$BATS_TEST_TMPDIR/gh"
    mkdir -p "$F/bin" "$F/issues"
    cat >"$F/bin/gh" <<'GH'
#!/usr/bin/env bash
# gh simulé : tickets dans $F/issues/<n>.labels, journal dans $F/log
F="$FAKE"
echo "$*" >>"$F/log"
etiquettes() { cat "$F/issues/$1.labels" 2>/dev/null || true; }
case "$1 $2" in
    "pr view")
        case "$*" in
            *"-q .body"*) cat "$F/pr_body" 2>/dev/null || true ;;
            *"-q .title"*) echo "feat: panier" ;;
        esac ;;
    "pr edit")
        while [ $# -gt 0 ]; do [ "$1" = --body ] && printf '%s' "$2" >"$F/pr_body"; shift; done ;;
    "pr list")
        case "$*" in
            *--head*) printf '%s\n' "${FAKE_PR_HEAD:-}" ;;
            *) printf '%s\n' "${FAKE_PRS:-}" ;;
        esac ;;
    "pr create")
        echo "pr-creee $*" >>"$F/events"
        echo "https://github.com/o/r/pull/9" ;;
    "pr close") echo "pr-fermee $3" >>"$F/events" ;;
    "api graphql")
        for a in "$@"; do case "$a" in name=*) echo "branche-creee ${a#name=}" >>"$F/events" ;; esac; done ;;
    "api -X")
        echo "branche-supprimee ${4#repos/o/r/git/refs/heads/}" >>"$F/events" ;;
    "api repos/o/r/git/matching-refs/heads/") cat "$F/refs" 2>/dev/null || true ;;
    "api repos/o/r") echo R_1 ;;
    "api repos/o/r/git/ref/heads/develop") echo sha0 ;;
    "api repos/o/r/compare/"*) echo "${FAKE_AHEAD:-1}" ;;
    "issue create")
        n=42
        while [ $# -gt 0 ]; do [ "$1" = --label ] && echo "$2" >>"$F/issues/$n.labels"; shift; done
        echo "https://github.com/o/r/issues/$n" ;;
    "issue view")
        case "$*" in
            *"-q .title"*) cat "$F/issues/$3.title" 2>/dev/null || echo "Ajoute le panier" ;;
            *"-q .id"*) echo "I_$3" ;;
            *) etiquettes "$3" ;;
        esac ;;
    "issue edit")
        n="$3"; shift 3
        while [ $# -gt 0 ]; do
            case "$1" in
                --add-label) echo "$2" >>"$F/issues/$n.labels" ;;
                --remove-label) grep -vxF "$2" "$F/issues/$n.labels" >"$F/tmp" || true; mv "$F/tmp" "$F/issues/$n.labels" ;;
            esac
            shift
        done ;;
    "issue comment") echo "commentaire $3" >>"$F/events" ;;
    "issue close") echo "fermé $3" >>"$F/events" ;;
    "issue list")
        while [ $# -gt 0 ]; do [ "$1" = --label ] && l="$2"; shift; done
        for f in "$F"/issues/*.labels; do
            [ -e "$f" ] && grep -qxF "$l" "$f" && basename "$f" .labels
        done ;;
    "api repos/"*)
        for a in "$@"; do case "$a" in state=*) echo "statut-pr ${a#state=}" >>"$F/events" ;; esac; done ;;
esac
exit 0
GH
    chmod +x "$F/bin/gh"
    export PATH="$F/bin:$PATH" FAKE="$F" GH_REPO=o/r
    export PR=7 HEAD=feat/panier BASE=develop HEAD_SHA=abc AUTHOR=dev DRAFT=false MERGED=false
}

labels() { cat "$F/issues/$1.labels" 2>/dev/null; }
ticket() { printf '%s\n' "$@" >"$F/issues/$N.labels"; }

@test "tickets : references lues dans la description et la branche, sans doublon" {
    source "$TICKETS"
    pr_tickets_r $'Ajoute le panier.\n\nTickets : #3, #4\nCloses #7' feat/12-panier
    [ "$REPLY" = "3 4 7 12" ]
    pr_tickets_r "Ticket : #3" fix/3-bug
    [ "$REPLY" = 3 ]
    pr_tickets_r "rien" feat/panier
    [ -z "$REPLY" ]
}

@test "tickets : PR sans ticket -> ticket cree a valider, relie, PR bloquee" {
    printf 'Ajoute le panier.' >"$F/pr_body"
    ACTION=opened run "$TICKETS" pr
    [ "$status" -ne 0 ]
    grep -qxF "statut: à valider" "$F/issues/42.labels"
    grep -q "Ticket : #42" "$F/pr_body"
    grep -qx "statut-pr failure" "$F/events"
    [[ "$output" == *"#42 à valider"* ]]
}

@test "tickets : ticket valide -> en cours (brouillon), en relecture (prete), PR debloquee" {
    N=12 ticket "validé" "statut: backlog"
    printf 'Ticket : #12' >"$F/pr_body"
    ACTION=opened DRAFT=true run "$TICKETS" pr
    [ "$status" -eq 0 ]
    [ "$(labels 12 | grep statut)" = "statut: en cours" ]
    ACTION=ready_for_review DRAFT=false run "$TICKETS" pr
    [ "$(labels 12 | grep statut)" = "statut: en relecture" ]
    grep -qx "statut-pr success" "$F/events"
}

@test "tickets : etiquette valide -> backlog et PR en attente debloquee" {
    N=12 ticket "statut: à valider" "validé"
    printf 'Ticket : #12' >"$F/pr_body"
    FAKE_PRS=$'7\tfeat/panier\tabc' ISSUE=12 ACTION=labeled LABEL=validé run "$TICKETS" issue
    [ "$status" -eq 0 ]
    [ "$(labels 12 | grep statut)" = "statut: backlog" ]
    grep -qx "statut-pr success" "$F/events"
}

@test "tickets : PR mergee -> preprod ; release -> done et ferme ; preversion -> commentaire" {
    N=12 ticket "validé" "statut: en relecture"
    printf 'Ticket : #12' >"$F/pr_body"
    ACTION=closed MERGED=true run "$TICKETS" pr
    [ "$(labels 12 | grep statut)" = "statut: préprod" ]
    TAG=v3.6.0-next.2 run "$TICKETS" release
    ! grep -q "fermé 12" "$F/events"
    grep -q "commentaire 12" "$F/events"
    TAG=v3.6.0 run "$TICKETS" release
    [ "$(labels 12 | grep statut)" = "statut: done" ]
    grep -qx "fermé 12" "$F/events"
}

@test "tickets : bots et livraisons sans ticket exige" {
    ACTION=opened AUTHOR='dependabot[bot]' run "$TICKETS" pr
    [ "$status" -eq 0 ]
    ACTION=opened HEAD=develop run "$TICKETS" pr
    [ "$status" -eq 0 ]
    [ ! -e "$F/issues/42.labels" ]
}

@test "tickets : ticket valide -> sa branche cree depuis develop, liee au ticket, une seule fois" {
    N=12 ticket "statut: à valider" "validé" "type: fix"
    echo "Corrige le total à payer" >"$F/issues/12.title"
    ISSUE=12 ACTION=labeled LABEL=validé run "$TICKETS" issue
    [ "$status" -eq 0 ]
    grep -qx "branche-creee fix/12-corrige-le-total-a-payer" "$F/events"
    grep -q "commentaire 12" "$F/events"
    [ "$(labels 12 | grep statut)" = "statut: backlog" ]
    # Branche deja la : rien de plus
    : >"$F/events"
    echo "refs/heads/fix/12-corrige-le-total-a-payer" >"$F/refs"
    ISSUE=12 ACTION=labeled LABEL=validé run "$TICKETS" issue
    ! grep -q "branche-creee" "$F/events"
}

@test "tickets : premier push sur la branche du ticket -> PR brouillon, en cours" {
    N=12 ticket "validé" "statut: backlog"
    PUSH_BRANCH=feat/12-panier SHA=def PUSHER=dev run "$TICKETS" push
    [ "$status" -eq 0 ]
    grep -q "pr-creee pr create --draft --base develop --head feat/12-panier --title feat: ajoute le panier --body Ticket : #12 --assignee dev" "$F/events"
    [ "$(labels 12 | grep statut)" = "statut: en cours" ]
    grep -qx "statut-pr success" "$F/events"
    # PR deja ouverte, branche sans ticket, ou rien de nouveau : aucune PR
    : >"$F/events"
    FAKE_PR_HEAD=9 PUSH_BRANCH=feat/12-panier SHA=def run "$TICKETS" push
    PUSH_BRANCH=feat/panier SHA=def run "$TICKETS" push
    FAKE_AHEAD=0 PUSH_BRANCH=feat/12-panier SHA=def run "$TICKETS" push
    ! grep -q "pr-creee" "$F/events"
}

@test "tickets : assigne -> en cours ; corrections demandees -> en cours" {
    N=12 ticket "validé" "statut: backlog"
    ISSUE=12 ACTION=assigned run "$TICKETS" issue
    [ "$(labels 12 | grep statut)" = "statut: en cours" ]
    N=12 ticket "validé" "statut: en relecture"
    printf 'Ticket : #12' >"$F/pr_body"
    REVIEW_STATE=approved run "$TICKETS" revue
    [ "$(labels 12 | grep statut)" = "statut: en relecture" ]
    REVIEW_STATE=changes_requested run "$TICKETS" revue
    [ "$(labels 12 | grep statut)" = "statut: en cours" ]
}

@test "tickets : ticket abandonne -> PR fermee, branche supprimee" {
    echo "refs/heads/feat/12-panier" >"$F/refs"
    FAKE_PR_HEAD=9 ISSUE=12 ACTION=closed STATE_REASON=completed run "$TICKETS" issue
    ! grep -q "branche-supprimee" "$F/events" 2>/dev/null
    FAKE_PR_HEAD=9 ISSUE=12 ACTION=closed STATE_REASON=not_planned run "$TICKETS" issue
    [ "$status" -eq 0 ]
    grep -qx "pr-fermee 9" "$F/events"
    grep -qx "branche-supprimee feat/12-panier" "$F/events"
}

@test "tickets : nom de branche du ticket (type, numero, titre sans accents, tronque)" {
    source "$BATS_TEST_DIRNAME/../hooks/lib/tickets.sh"
    ticket_branch_r 12 "Élargir l'accès à la façade : ÉTAPE 2" fix
    [ "$REPLY" = "fix/12-elargir-l-acces-a-la-facade-etape-2" ]
    ticket_branch_r 7 "Un titre vraiment très long qui dépasse largement la limite fixée"
    [ "$REPLY" = "feat/7-un-titre-vraiment-tres-long-qui-depasse" ]
    ticket_type_r $'statut: backlog\nbug'
    [ "$REPLY" = fix ]
}
