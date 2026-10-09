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
    "pr list") printf '%s\n' "${FAKE_PRS:-}" ;;
    "issue create")
        n=42
        while [ $# -gt 0 ]; do [ "$1" = --label ] && echo "$2" >>"$F/issues/$n.labels"; shift; done
        echo "https://github.com/o/r/issues/$n" ;;
    "issue view") etiquettes "$3" ;;
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
