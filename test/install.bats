#!/usr/bin/env bats
# install.sh : installation, désinstallation sûre, purge

load helpers

INSTALL="$BATS_TEST_DIRNAME/../install.sh"

setup() {
    setup_repo
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global.gitconfig"
    touch "$GIT_CONFIG_GLOBAL"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
}

@test "install : --uninstall retire les hooks repogarde du depot" {
    git config --unset core.hooksPath
    "$INSTALL" >/dev/null
    [ -n "$(git config --local --get core.hooksPath)" ]
    run "$INSTALL" --uninstall
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hooks repogarde retirés"* ]]
    [ -z "$(git config --local --get core.hooksPath || true)" ]
}

@test "install : --uninstall ne touche pas aux hooks d'un autre outil (husky)" {
    git config core.hooksPath .husky/_
    run "$INSTALL" --uninstall
    [ "$status" -eq 0 ]
    [[ "$output" == *"n'est pas repogarde : laissé intact"* ]]
    [ "$(git config --local --get core.hooksPath)" = ".husky/_" ]
}

@test "install : --uninstall reconnait un ancien emplacement disparu" {
    git config core.hooksPath /chemin/qui/n-existe/plus/githooks/hooks
    run "$INSTALL" --uninstall
    [[ "$output" == *"Hooks repogarde retirés"* ]]
}

@test "install : --uninstall --global --purge supprime les caches" {
    "$INSTALL" --global >/dev/null
    mkdir -p "$XDG_CACHE_HOME/repogarde/kubeconform" "$XDG_CACHE_HOME/githooks"
    run "$INSTALL" --uninstall --global --purge
    [ "$status" -eq 0 ]
    [ -z "$(git config --global --get core.hooksPath || true)" ]
    [ ! -d "$XDG_CACHE_HOME/repogarde" ] && [ ! -d "$XDG_CACHE_HOME/githooks" ]
    [[ "$output" == *'rm -rf'* ]]
}

@test "install : --scan liste les depots encore branches, sans les modifier" {
    "$INSTALL" >/dev/null # dépôt de test branché localement
    mkdir -p "$BATS_TEST_TMPDIR/autre"
    git init -q "$BATS_TEST_TMPDIR/autre/projet-lefthook"
    printf 'remotes:\n  - git_url: https://github.com/x/repogarde\n' >"$BATS_TEST_TMPDIR/autre/projet-lefthook/lefthook.yml"
    git init -q "$BATS_TEST_TMPDIR/autre/sans-rapport"
    printf 'pre-commit: {}\n' >"$BATS_TEST_TMPDIR/autre/sans-rapport/lefthook.yml"
    run "$INSTALL" --uninstall --global --purge --scan "$BATS_TEST_TMPDIR"
    [[ "$output" == *"$REPO  →  git -C"* ]]
    [[ "$output" == *"projet-lefthook (lefthook)"* ]]
    [[ "$output" != *"sans-rapport"* ]]
    [ -n "$(git config --local --get core.hooksPath)" ] # liste seulement
}

@test "install : --purge sans --uninstall refuse" {
    run "$INSTALL" --purge
    [ "$status" -ne 0 ]
}

@test "install : --lang enregistre la langue et l'applique aux messages" {
    git config --unset core.hooksPath
    run "$BATS_TEST_DIRNAME/../install.sh" --lang en
    [ "$status" -eq 0 ]
    [ "$(git config --local --get repogarde.lang)" = en ]
    [[ "$output" == *"Message language: English"* ]]
    [[ "$output" == *"Hooks enabled"* ]]
    run "$BATS_TEST_DIRNAME/../install.sh" --lang de
    [ "$status" -ne 0 ]
}
