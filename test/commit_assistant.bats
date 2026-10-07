#!/usr/bin/env bats
# Assistant de commit (git cc) : en-tête, corps, pied

load helpers

CC="$BATS_TEST_DIRNAME/../bin/commit"

setup() {
    setup_repo
    initial_commit
    git switch -q -c feat/panier
    echo x >a.txt
    git add a.txt
}

# Réponses, une par ligne : type, scope, majeur [, ce qui change], description,
# corps…, références, confirmation
answer() { printf '%s\n' "$@" | "$CC" 2>&1; }

@test "assistant : type et scope proposes d'apres la branche" {
    run answer "" "" "" "ajoute le panier" "" "" ""
    [ "$status" -eq 0 ]
    [ "$(subject)" = "feat(panier): ajoute le panier" ]
}

@test "assistant : corps et references dans le message" {
    run answer "" "" "" "ajoute le panier" "Le client garde ses articles." "" "Closes #12" ""
    [ "$status" -eq 0 ]
    git log -1 --format=%B >msg
    grep -qx 'Le client garde ses articles.' msg
    grep -qx 'Closes #12' msg
}

@test "assistant : choix du type par numero, sans scope" {
    run answer "2" "-" "" "corrige le total" "" "" ""
    [ "$(subject)" = "fix: corrige le total" ]
}

@test "assistant : changement majeur -> ! et BREAKING CHANGE" {
    run answer "" "" "o" "le format de sortie change" "change l'API du panier" "" "" ""
    [ "$(subject)" = "feat(panier)!: change l'API du panier" ]
    git log -1 --format=%B | grep -qx 'BREAKING CHANGE: le format de sortie change'
}

@test "assistant : changement majeur sans description reelle -> redemande" {
    run answer "" "" "o" "RAS" "court" "le format de sortie change" "change l'API" "" "" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"10 caractères au moins"* ]]
    git log -1 --format=%B | grep -qx 'BREAKING CHANGE: le format de sortie change'
}

@test "assistant : premier commit du depot -> pas de question sur l'incompatibilite" {
    rm -rf .git
    git init -q -b main
    git config user.name test
    git config user.email test@example.com
    git config core.hooksPath /dev/null
    git add a.txt
    run answer "" "" "initialise le projet" "" "" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Premier commit du dépôt"* ]]
    [ "$(subject)" = "feat: initialise le projet" ]
}

@test "assistant : touches parasites (Echap, fleches) et point final ignores" {
    run answer $'1\033' $'\033[A' "" "ajoute le panier." "" "" ""
    [ "$status" -eq 0 ]
    [ "$(subject)" = "feat(panier): ajoute le panier" ]
}

@test "assistant : en-tete trop long -> nouvelle saisie" {
    long="$(printf 'a%.0s' {1..80})"
    run answer "" "" "" "$long" "description courte" "" "" ""
    [[ "$output" == *"En-tête trop long"* ]]
    [ "$(subject)" = "feat(panier): description courte" ]
}

@test "assistant : rien de stage -> refus" {
    git reset -q
    run answer "" "" "" "x" "" "" ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"Rien n'est stagé"* ]]
}

@test "assistant : abandon a la confirmation" {
    before="$(git rev-parse HEAD)"
    run answer "" "" "" "ajoute le panier" "" "" "n"
    [ "$status" -ne 0 ]
    [ "$(git rev-parse HEAD)" = "$before" ]
}

@test "assistant : alias git cc installe et retire, sans ecraser un alias existant" {
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global.gitconfig"
    touch "$GIT_CONFIG_GLOBAL"
    git config --unset core.hooksPath
    run "$BATS_TEST_DIRNAME/../install.sh"
    [[ "$output" == *"git cc"* ]]
    [[ "$(git config --local --get alias.cc)" == *"/bin/commit"* ]]
    "$BATS_TEST_DIRNAME/../install.sh" --uninstall >/dev/null
    [ -z "$(git config --local --get alias.cc || true)" ]
    git config alias.cc "commit -v"
    run "$BATS_TEST_DIRNAME/../install.sh"
    [[ "$output" == *"déjà utilisé"* ]]
    [ "$(git config --local --get alias.cc)" = "commit -v" ]
}
