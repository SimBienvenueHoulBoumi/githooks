#!/usr/bin/env bats
# Compatibilité avec les anciens noms (githooks ≤ v1) : toujours acceptés,
# avec un message de migration, jamais bloquants

load helpers

setup() { setup_repo; initial_commit; git switch -q -c feat/x; }

@test "compat : ancien fichier .githooks.conf [hooks] lu, avec message" {
    git config --unset repogarde.skip
    printf '[hooks]\n\tskip = secrets protect-branch\n' >.githooks.conf
    git switch -q main
    run git commit -q --allow-empty -m "chore: ancien fichier"
    [ "$status" -eq 0 ]
    [[ "$output" == *".githooks.conf : ancien nom"* ]]
}

@test "compat : anciennes cles git config hooks.* lues, les nouvelles priment" {
    source "$HOOKS/lib/common.sh"
    git config hooks.allowedBranches "ancienne"
    git config repogarde.allowedBranches "nouvelle"
    cfg_reset
    [ "$(cfg allowedBranches)" = nouvelle ]
    git config --unset repogarde.allowedBranches
    cfg_reset
    [ "$(cfg allowedBranches)" = ancienne ]
}

@test "compat : variables GITHOOKS_* acceptees en CI" {
    git commit -q --no-verify --allow-empty -m "feat: a"
    run env GITHOOKS_BASE="$(git rev-parse HEAD~1)" GITHOOKS_BRANCH=Mauvais \
        "$BATS_TEST_DIRNAME/../ci/check.sh" branch
    [ "$status" -ne 0 ]
    [[ "$output" == *"GITHOOKS_BRANCH : ancien nom"* ]]
    [[ "$output" == *"Mauvais"* ]]
}

@test "compat : ancien dossier .githooks/ de hooks du projet execute" {
    mkdir -p .githooks
    printf '#!/bin/sh\necho HOOK-ANCIEN-DOSSIER\n' >.githooks/pre-commit
    chmod +x .githooks/pre-commit
    git add -A
    run git commit -q -m "feat: x"
    [[ "$output" == *"HOOK-ANCIEN-DOSSIER"* ]]
    [[ "$output" == *".githooks/ : ancien nom"* ]]
}
