#!/usr/bin/env bats
# Paquet npm : commande repogarde (installation sur la machine), contenu publié

load helpers

PKG="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"

setup() {
    setup_repo
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global.gitconfig"
    touch "$GIT_CONFIG_GLOBAL"
}

@test "npm : version du paquet = version de la derniere release" {
    run "$PKG/bin/repogarde" --version
    [ "$status" -eq 0 ]
    [[ "$(cat "$PKG/.release-please-manifest.json")" == *"\"$output\""* ]]
}

@test "npm : appelee par un lien symbolique (npm install -g), installe les vrais hooks" {
    mkdir -p "$BATS_TEST_TMPDIR/prefix/bin"
    ln -s "$PKG/bin/repogarde" "$BATS_TEST_TMPDIR/prefix/bin/repogarde" 2>/dev/null || true
    # Git Bash (Windows) copie au lieu de lier ; npm y crée des scripts .cmd
    [ -L "$BATS_TEST_TMPDIR/prefix/bin/repogarde" ] || skip "liens symboliques indisponibles"
    git config --unset core.hooksPath
    run "$BATS_TEST_TMPDIR/prefix/bin/repogarde" install --global --lang fr
    [ "$status" -eq 0 ]
    [ "$(git config --global --get core.hooksPath)" = "$PKG/hooks" ]
    [[ "$(git config --global --get alias.cc)" == *"$PKG/bin/commit"* ]]
    run "$BATS_TEST_TMPDIR/prefix/bin/repogarde" uninstall --global
    [ "$status" -eq 0 ]
    [ -z "$(git config --global --get core.hooksPath || true)" ]
}

@test "npm : npx refuse une installation globale (dossier temporaire)" {
    npx="$BATS_TEST_TMPDIR/_npx/abc/node_modules/repogarde"
    mkdir -p "$npx"
    cp -R "$PKG/bin" "$PKG/hooks" "$PKG/install.sh" "$PKG/package.json" "$npx/"
    run "$npx/bin/repogarde" install --global
    [ "$status" -ne 0 ]
    [[ "$output" == *"npm install -g"* ]]
    [ -z "$(git config --global --get core.hooksPath || true)" ]
}

@test "npm : commande inconnue refusee, aide affichee" {
    run "$PKG/bin/repogarde" inconnue
    [ "$status" -ne 0 ]
    [[ "$output" == *"repogarde install"* ]]
}

@test "npm : le paquet contient les hooks et rien des tests" {
    require npm
    run bash -c "cd '$PKG' && npm pack --dry-run --json 2>/dev/null"
    [ "$status" -eq 0 ]
    for f in bin/repogarde bin/commit install.sh hooks/lib/common.sh hooks/pre-commit ci/check.sh; do
        [[ "$output" == *"\"$f\""* ]]
    done
    [[ "$output" != *'"test/'* ]]
}
