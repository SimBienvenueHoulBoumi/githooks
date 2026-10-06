#!/usr/bin/env bats
# Multi-langages : scripts isolés, monorepos, multi-modules, config projet, fallback

load helpers

setup() {
    setup_repo
    initial_commit
    git switch -q -c feat/x
}

load_engine() {
    source "$HOOKS/lib/common.sh"
    source "$HOOKS/lib/lang.sh"
}

# --- Détection ---------------------------------------------------------------

@test "detection : multi-module Maven -> projet parent le plus haut" {
    load_engine
    mkdir -p module/src
    touch pom.xml module/pom.xml
    [ "$(nearest_project module/src/A.java maven)" = "maven ." ]
}

@test "detection : monorepo Python -> projet le plus proche" {
    load_engine
    mkdir -p api/app
    touch pyproject.toml api/pyproject.toml
    [ "$(nearest_project api/app/main.py python)" = "python api" ]
}

@test "detection : marqueurs en glob (.NET *.csproj)" {
    load_engine
    mkdir -p src/Api
    touch src/Api/Api.csproj
    [ "$(nearest_project src/Api/Program.cs dotnet)" = "dotnet src/Api" ]
}

@test "detection : gestionnaire de paquets Node depuis un sous-dossier (monorepo)" {
    load_engine
    mkdir -p packages/web
    touch pnpm-lock.yaml packages/web/package.json
    cd packages/web
    [ "$(node_pm)" = pnpm ]
}

@test "detection : extension -> plugins candidats" {
    load_engine
    [[ " $(plugins_for_file src/A.java) " == *" maven "* ]]
    [[ " $(plugins_for_file src/A.java) " == *" gradle "* ]]
    [ "$(plugins_for_file deploy.sh | tr -d ' ')" = shell ]
    [ -z "$(plugins_for_file image.png | tr -d ' ')" ]
}

# --- Formatage -----------------------------------------------------------------

@test "format : script Python isole (sans projet) formate par extension" {
    require ruff
    printf 'x  =  1\n' >script.py
    git add script.py
    run git commit -q -m "ajoute script"
    [ "$status" -eq 0 ]
    [ "$(git show HEAD:script.py)" = "x = 1" ]
}

@test "format : monorepo, chaque fichier formate dans son projet" {
    require gofmt
    require ruff
    mkdir -p backend frontend
    printf 'module x\n\ngo 1.21\n' >backend/go.mod
    printf 'package main\nfunc main(){  }\n' >backend/main.go
    touch frontend/pyproject.toml
    printf 'y  =  2\n' >frontend/app.py
    git add -A
    run git commit -q -m "ajoute les deux"
    [ "$status" -eq 0 ]
    [[ "$output" == *"go (backend)"* ]]
    [[ "$output" == *"python (frontend)"* ]]
    git show HEAD:backend/main.go | grep -q '^func main() {}$'
    [ "$(git show HEAD:frontend/app.py)" = "y = 2" ]
}

@test "format : hooks.skip <langage> desactive ce langage" {
    require ruff
    git config hooks.skip "secrets python"
    printf 'x  =  1\n' >script.py
    git add script.py
    git commit -q -m "ajoute script"
    [ "$(git show HEAD:script.py)" = "x  =  1" ]
}

@test "format : Dart isole" {
    require dart
    printf 'void main(){print(1);}\n' >a.dart
    git add a.dart
    git commit -q -m "ajoute dart"
    git show HEAD:a.dart | grep -q '^  print(1);$'
}

@test "format : Terraform isole" {
    require terraform
    printf 'variable "a" {\ndefault="x"\n}\n' >main.tf
    git add main.tf
    git commit -q -m "ajoute tf"
    git show HEAD:main.tf | grep -q '^  default = "x"$'
}

@test "format : outil absent pour un fichier isole -> silencieux" {
    command -v prettier >/dev/null && skip "prettier installé globalement"
    printf '# Titre\n' >NOTES.md
    git add NOTES.md
    run git commit -q -m "ajoute notes"
    [ "$status" -eq 0 ]
    [[ "$output" != *"prettier introuvable"* ]]
}

# --- .githooks.conf -------------------------------------------------------------

@test ".githooks.conf : format personnalise (recoit les fichiers stages)" {
    printf '#!/bin/sh\nfor f; do echo "// formaté" >>"$f"; done\n' >fmt.sh
    printf '[hooks]\n\tformat = sh fmt.sh\n' >.githooks.conf
    git add -A
    git commit -q --no-verify -m "chore: conf"
    echo "code" >a.txt
    git add a.txt
    git commit -q -m "ajoute a"
    git show HEAD:a.txt | grep -q '// formaté'
}

@test ".githooks.conf : format personnalise qui echoue -> commit refuse" {
    printf '[hooks]\n\tformat = false\n' >.githooks.conf
    git add -A
    run git commit -q -m "ajoute conf"
    [ "$status" -ne 0 ]
}

@test ".githooks.conf : test personnalise qui echoue -> push refuse" {
    printf '[hooks]\n\ttest = echo tests-perso && exit 3\n' >.githooks.conf
    git add -A
    git commit -q -m "ajoute conf"
    run git push -q origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests-perso"* ]]
}

@test ".githooks.conf : reglages partages (skip)" {
    git switch -q main
    printf '[hooks]\n\tskip = secrets protect-branch\n' >.githooks.conf
    git add .githooks.conf
    git config --unset hooks.skip
    run git commit -q -m "chore: conf partagée"
    [ "$status" -eq 0 ]
}

@test ".githooks.conf : git config local prioritaire" {
    load_engine
    printf '[hooks]\n\tallowedBranches = main\n' >.githooks.conf
    [ "$(cfg allowedBranches)" = main ]
    git config hooks.allowedBranches "main develop"
    [ "$(cfg allowedBranches)" = "main develop" ]
}

# --- Tests (pre-push) -------------------------------------------------------------

@test "pre-push : monorepo, seuls les projets modifies sont testes" {
    require go
    mkdir -p ok ko
    (cd ok && go_project ok)
    (cd ko && go_project fail)
    git add -A
    git commit -q --no-verify -m "chore: deux modules"
    git push -q --no-verify origin feat/x

    echo "// modif" >>ok/x_test.go
    git commit -q -am "test: modifie ok"
    run git push -q origin feat/x
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tests go (ok)"* ]]
    [[ "$output" != *"(ko)"* ]]

    echo "// modif" >>ko/x_test.go
    git commit -q -am "test: modifie ko"
    run git push -q origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"Échec des tests go (ko)"* ]]
}

@test "pre-push : fichier non-code d'un projet (README) -> tests du projet" {
    require go
    go_project fail
    git add -A
    git commit -q --no-verify -m "chore: base"
    git push -q --no-verify origin feat/x
    echo doc >>README.md
    git commit -q -am "docs: readme"
    run git push -q origin feat/x
    [ "$status" -ne 0 ]
}

@test "pre-push : Makefile en secours quand aucun langage reconnu" {
    require make
    printf 'test:\n\t@echo make-test-lance && exit 1\n' >Makefile
    git add Makefile
    git commit -q -m "build: makefile"
    run git push -q origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"make-test-lance"* ]]
}

@test "pre-push : Makefile ignore quand un langage est reconnu" {
    require go
    go_project ok
    printf 'test:\n\t@exit 1\n' >Makefile
    git add -A
    git commit -q -m "build: go + make"
    run git push -q origin feat/x
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tests go"* ]]
}

@test "pre-push : simple script sans projet -> rien a tester, push OK" {
    printf 'echo hi\n' >deploy.sh
    git add deploy.sh
    git commit -q -m "ajoute script"
    run git push -q origin feat/x
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aucun projet testable"* ]]
}

@test "find_up : s'arrete a la racine du depot (chemins Windows/Git Bash)" {
    load_engine
    mkdir -p a/b
    touch marker
    cd a/b
    [ "$(find_up marker)" = "$(cd "$REPO" && pwd -P)/marker" ]
    ! find_up introuvable-xyz
}

@test "detection : multi-module sur 3 niveaux, sans boucle" {
    load_engine
    mkdir -p a/b/c/src
    touch pom.xml a/pom.xml a/b/pom.xml a/b/c/pom.xml
    [ "$(nearest_project a/b/c/src/A.java maven)" = "maven ." ]
    # mémo : deuxième appel identique
    [ "$(nearest_project a/b/c/src/B.java maven)" = "maven ." ]
}

@test "performance : commit de 300 fichiers en moins de 30 s" {
    touch pom.xml
    for d in a b c d e; do
        mkdir -p "src/$d/sub"
        for i in $(seq 1 60); do echo "# doc $i" >"src/$d/sub/F$i.md"; done
    done
    git add -A
    start=$SECONDS
    run git commit -q -m "ajoute 300 fichiers"
    [ "$status" -eq 0 ]
    echo "durée : $((SECONDS - start)) s"
    [ $((SECONDS - start)) -lt 30 ]
}
