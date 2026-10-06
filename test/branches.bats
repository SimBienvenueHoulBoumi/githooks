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

@test "validite des noms de branche" {
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
    cfg_reset
    ! branch_name_valid develop
    branch_name_valid main
}

@test "post-checkout : avertit sans bloquer" {
    run git switch -c Mon_Truc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nom de branche invalide"* ]]
    [[ "$output" == *"git branch -m feat/mon-truc"* ]]
}

@test "pre-commit : refuse une branche mal nommee" {
    git switch -q -c Mon_Truc 2>/dev/null
    run git commit -q --allow-empty -m "feat: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Commit refusé : nom de branche non conforme"* ]]
}

@test "pre-push : refuse une branche mal nommee" {
    git switch -q -c Bad 2>/dev/null
    git commit -q --no-verify --allow-empty -m "feat: x"
    run git push -q origin Bad
    [ "$status" -ne 0 ]
    [[ "$output" == *"Push refusé : nom de branche non conforme"* ]]
    [ -z "$(git ls-remote --heads origin Bad)" ]
}

@test "main : commit direct refuse apres le commit initial" {
    run git commit -q --allow-empty -m "fix: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Commit direct sur 'main' interdit"* ]]
}

@test "main : hooks.skip protect-branch l'autorise" {
    git config hooks.skip "secrets protect-branch"
    run git commit -q --allow-empty -m "fix: x"
    [ "$status" -eq 0 ]
}

# Simule le merge d'une PR côté serveur, puis la suppression de sa branche
server_merge_and_delete() {
    local tmp="$BATS_TEST_TMPDIR/serveur"
    git clone -q -b main "$REMOTE" "$tmp"
    git -C "$tmp" config core.hooksPath /dev/null
    git -C "$tmp" config user.name serveur
    git -C "$tmp" config user.email serveur@example.com
    git -C "$tmp" merge -q --no-ff "origin/$1" -m "Merge $1"
    git -C "$tmp" push -q origin main
    git -C "$tmp" push -q origin --delete "$1"
    rm -rf "$tmp"
}

push_branch() {
    git switch -q -c "$1"
    git commit -q --allow-empty -m "feat: travail sur $1"
    git push -q -u origin "$1"
}

@test "post-merge : branche mergee et supprimee sur le serveur -> supprimee en local" {
    git push -q -u origin main
    push_branch feat/x
    server_merge_and_delete feat/x
    git switch -q main
    run git pull -q
    [ "$status" -eq 0 ]
    [[ "$output" == *"Branche locale supprimée"*"feat/x"* ]]
    ! git show-ref -q --verify refs/heads/feat/x
}

@test "post-merge : branche supprimee mais non integree -> conservee" {
    git push -q -u origin main
    push_branch feat/y
    git push -q origin --delete feat/y # supprimée sans merge
    git switch -q main
    git commit -q --allow-empty -m "fix: autre travail" --no-verify
    git push -q origin main --no-verify
    git reset -q --hard HEAD~1
    run git pull -q
    [[ "$output" == *"feat/y : supprimée sur le serveur mais pas intégrée"* ]]
    git show-ref -q --verify refs/heads/feat/y
}

@test "post-merge : desactivable (skip prune-branches)" {
    git config hooks.skip "secrets prune-branches"
    git push -q -u origin main
    push_branch feat/z
    server_merge_and_delete feat/z
    git switch -q main
    git pull -q
    git show-ref -q --verify refs/heads/feat/z
}
