#!/usr/bin/env bats
# commit-msg + prepare-commit-msg

load helpers

setup() { setup_repo; initial_commit; }

@test "commit-msg : message conforme accepté" {
    git switch -q -c feat/x
    run git commit -q --allow-empty -m "fix: corrige un truc"
    [ "$status" -eq 0 ]
    [ "$(subject)" = "fix: corrige un truc" ]
}

@test "commit-msg : message invalide refusé avec l'aide" {
    git switch -q -c wip-x 2>/dev/null
    git config hooks.skip "secrets branch-name"
    run git commit -q --allow-empty -m "n'importe quoi"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Message de commit invalide"* ]]
    [[ "$output" == *"nouvelle fonctionnalité"* ]]
}

@test "commit-msg : première ligne > 72 caractères refusée" {
    git switch -q -c feat/x
    run git commit -q --allow-empty -m "fix: $(printf 'a%.0s' {1..80})"
    [ "$status" -ne 0 ]
    [[ "$output" == *"trop longue"* ]]
}

@test "prepare-commit-msg : préfixe déduit de la branche" {
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "ajoute le bean"
    [ "$(subject)" = "feat(bean): ajoute le bean" ]
}

@test "prepare-commit-msg : alias de branche (bugfix → fix)" {
    git switch -q -c bugfix/timeout
    git commit -q --allow-empty -m "corrige"
    [ "$(subject)" = "fix(timeout): corrige" ]
}

@test "prepare-commit-msg : scope trop long omis" {
    git switch -q -c fix/un-sujet-vraiment-tres-long
    git commit -q --allow-empty -m "corrige"
    [ "$(subject)" = "fix: corrige" ]
}

@test "prepare-commit-msg : message déjà conforme inchangé" {
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "docs: readme"
    [ "$(subject)" = "docs: readme" ]
}

@test "prepare-commit-msg : amend sans double préfixe" {
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "ajoute"
    GIT_EDITOR=true git commit -q --amend --allow-empty
    [ "$(subject)" = "feat(bean): ajoute" ]
}

@test "hooks.skip true désactive tout" {
    git config hooks.skip true
    run git commit -q --allow-empty -m "n'importe quoi"
    [ "$status" -eq 0 ]
}
