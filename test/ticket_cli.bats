#!/usr/bin/env bats
# Tickets côté poste : branche sans ticket prévenue (jamais bloquée), création
# proposée seulement si repowarden gère les tickets du projet ; repowarden ticket

load helpers

TICKET="$BATS_TEST_DIRNAME/../bin/ticket"
CC="$BATS_TEST_DIRNAME/../bin/commit"

setup() {
    setup_repo
    initial_commit
    F="$BATS_TEST_TMPDIR/gh"
    mkdir -p "$F/bin"
    cat >"$F/bin/gh" <<'GH'
#!/usr/bin/env bash
# gh simulé : journal dans $FAKE/log
echo "$*" >>"$FAKE/log"
case "$1 $2" in
    "issue create") echo "https://github.com/o/r/issues/42" ;;
    "issue view") printf '%s\n' "${FAKE_ISSUE:-$(printf 'OPEN\tAjoute le panier\tvalidé')}" ;;
    "issue develop")
        while [ $# -gt 0 ]; do [ "$1" = --name ] && git switch -q -c "$2"; shift; done ;;
esac
exit 0
GH
    chmod +x "$F/bin/gh"
    export FAKE="$F"
}

# Projet dont repowarden gère les tickets (workflow qui appelle tickets.yml)
gere() {
    mkdir -p .github/workflows
    printf 'jobs:\n  t:\n    uses: o/repowarden/.github/workflows/tickets.yml@v4\n' >.github/workflows/tickets.yml
}

@test "ticket cli : branche sans ticket -> prevenu, comment le faire taire (suivi non gere)" {
    run git switch -c feat/panier
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branche feat/panier sans ticket"* ]]
    [[ "$output" == *"repowarden.skip tickets"* ]]
    [[ "$output" != *"ticket nouveau"* ]]
}

@test "ticket cli : suivi gere par repowarden -> creation du ticket proposee" {
    gere
    PATH="$F/bin:$PATH" run git switch -c feat/panier
    [[ "$output" == *"sans ticket"* ]]
    [[ "$output" == *"repowarden ticket nouveau"* ]]
}

@test "ticket cli : branche avec ticket, main ou skip tickets -> aucun avertissement" {
    run git switch -c feat/12-panier
    [[ "$output" != *"sans ticket"* ]]
    git config repowarden.skip "secrets tickets"
    run git switch -c feat/autre
    [[ "$output" != *"sans ticket"* ]]
    run git switch main
    [[ "$output" != *"sans ticket"* ]]
}

@test "ticket cli : git cc sans ticket -> commit fait, prevenu (jamais bloque)" {
    git switch -q -c feat/panier
    echo a >a.txt && git add a.txt
    run "$CC" -m "ajoute le panier"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sans ticket"* ]]
    [ "$(subject)" = "feat(panier): ajoute le panier" ]
}

@test "ticket cli : git cc, suivi gere -> ticket cree sur demande et cite" {
    gere
    git add .github && git commit -q --no-verify -m "ci: tickets"
    git switch -q -c feat/panier
    echo a >a.txt && git add a.txt
    PATH="$F/bin:$PATH" run bash -c "printf '%s\n' '' '' '' 'ajoute le panier' '' 'o' '' '' | '$CC'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ticket #42 créé"* ]]
    git log -1 --format=%B | grep -qx 'Ticket : #42'
    grep -q 'issue create --title ajoute le panier' "$F/log"
}

@test "ticket cli : repowarden ticket <n> -> branche existante du ticket" {
    git switch -q -c feat/12-panier
    git push -q --no-verify origin feat/12-panier
    git switch -q main
    git branch -q -D feat/12-panier
    PATH="$F/bin:$PATH" run "$TICKET" 12
    [ "$status" -eq 0 ]
    [ "$(git branch --show-current)" = feat/12-panier ]
    [[ "$output" == *"Sur la branche feat/12-panier (ticket #12)"* ]]
}

@test "ticket cli : repowarden ticket <n> sans branche -> creee et liee, sauf ticket a valider" {
    git config repowarden.integrationBranch main
    PATH="$F/bin:$PATH" run "$TICKET" 12
    [ "$status" -eq 0 ]
    grep -q "issue develop 12 --name feat/12-ajoute-le-panier --base main --checkout" "$F/log"
    [ "$(git branch --show-current)" = feat/12-ajoute-le-panier ]
    git switch -q main
    gere
    FAKE_ISSUE="$(printf 'OPEN\tAutre\tstatut: à valider')" PATH="$F/bin:$PATH" run "$TICKET" 13
    [ "$status" -ne 0 ]
    [[ "$output" == *"pas encore validé"* ]]
}

@test "ticket cli : repowarden ticket nouveau -> a valider si le suivi est gere" {
    gere
    PATH="$F/bin:$PATH" run "$TICKET" nouveau "Ajoute le panier" --type fix
    [ "$status" -eq 0 ]
    grep -q -- "--label statut: à valider --label type: fix" "$F/log"
    [[ "$output" == *"Ticket #42 créé, à valider"* ]]
}
