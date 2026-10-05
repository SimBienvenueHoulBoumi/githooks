#!/usr/bin/env bats
# Nommage des branches + protection de main

load helpers

setup() { setup_repo; initial_commit; }

@test "suggestion de nom de branche" {
    source "$HOOKS/lib/common.sh"
    [ "$(suggest_branch_name 'Mon_Truc')" = "feat/mon-truc" ]
    [ "$(suggest_branch_name 'Feat/Mon Truc')" = "feat/mon-truc" ]
    [ "$(suggest_branch_name 'bug/login')" = "fix/login" ]
    [ "$(suggest_branch_name 'doc/api')" = "docs/api" ]
    [ "$(suggest_branch_name 'wip/x')" = "feat/x" ]
}

@test "validité des noms de branche" {
    source "$HOOKS/lib/common.sh"
    for ok in feat/bean fix/user/login hotfix/x feat/a_b.c main master develop release/1.0; do
        branch_name_valid "$ok" || { echo "devrait être valide : $ok"; return 1; }
    done
    for ko in Feat/Bean wip/x test2 feat/ releases/x; do
        ! branch_name_valid "$ko" || { echo "devrait être invalide : $ko"; return 1; }
    done
}

@test "hooks.allowedBranches remplace les exceptions" {
    source "$HOOKS/lib/common.sh"
    git config hooks.allowedBranches "main"
    ! branch_name_valid develop
    branch_name_valid main
}

@test "post-checkout : avertit sans bloquer" {
    run git switch -c Mon_Truc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nom de branche invalide"* ]]
    [[ "$output" == *"git branch -m feat/mon-truc"* ]]
}

@test "pre-commit : refuse une branche mal nommée" {
    git switch -q -c Mon_Truc 2>/dev/null
    run git commit -q --allow-empty -m "feat: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Commit refusé : nom de branche non conforme"* ]]
}

@test "pre-push : refuse une branche mal nommée" {
    git switch -q -c Bad 2>/dev/null
    git commit -q --no-verify --allow-empty -m "feat: x"
    run git push -q origin Bad
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push refusé : nom de branche non conforme"* ]]
    [ -z "$(git ls-remote --heads origin Bad)" ]
}

@test "main : commit direct refusé après le commit initial" {
    run git commit -q --allow-empty -m "fix: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Commit direct sur 'main' interdit"* ]]
}

@test "main : hooks.skip protect-branch l'autorise" {
    git config hooks.skip "secrets protect-branch"
    run git commit -q --allow-empty -m "fix: x"
    [ "$status" -eq 0 ]
}
