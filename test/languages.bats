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

@test "format : repogarde.skip <langage> desactive ce langage" {
    require ruff
    git config repogarde.skip "secrets python"
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

# --- .repogarde.conf -------------------------------------------------------------

@test ".repogarde.conf : format personnalise (recoit les fichiers stages)" {
    printf '#!/bin/sh\nfor f; do echo "// formaté" >>"$f"; done\n' >fmt.sh
    printf '[repogarde]\n\tformat = sh fmt.sh\n' >.repogarde.conf
    git add -A
    git commit -q --no-verify -m "chore: conf"
    echo "code" >a.txt
    git add a.txt
    git commit -q -m "ajoute a"
    git show HEAD:a.txt | grep -q '// formaté'
}

@test ".repogarde.conf : format personnalise qui echoue -> commit refuse" {
    printf '[repogarde]\n\tformat = false\n' >.repogarde.conf
    git add -A
    run git commit -q -m "ajoute conf"
    [ "$status" -ne 0 ]
}

@test ".repogarde.conf : test personnalise qui echoue -> push refuse" {
    printf '[repogarde]\n\ttest = echo tests-perso && exit 3\n' >.repogarde.conf
    git add -A
    git commit -q -m "ajoute conf"
    run git push -q origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests-perso"* ]]
}

@test ".repogarde.conf : test personnalise recoit les fichiers modifies sur stdin" {
    printf '#!/bin/sh\ngrep -qx src/a.txt || { echo pas-de-liste; exit 1; }\n' >verifie.sh
    chmod +x verifie.sh
    printf '[repogarde]\n\ttest = ./verifie.sh\n' >.repogarde.conf
    mkdir -p src && echo a >src/a.txt
    git add -A
    git commit -q -m "ajoute conf"
    run git push -q origin feat/x
    [ "$status" -eq 0 ]
}

@test ".repogarde.conf : reglages partages (skip)" {
    git switch -q main
    printf '[repogarde]\n\tskip = secrets protect-branch\n' >.repogarde.conf
    git add .repogarde.conf
    git config --unset repogarde.skip
    run git commit -q -m "chore: conf partagée"
    [ "$status" -eq 0 ]
}

@test ".repogarde.conf : git config local prioritaire" {
    printf '[repogarde]\n\tallowedBranches = main\n' >.repogarde.conf
    load_engine
    [ "$(cfg allowedBranches)" = main ]
    git config repogarde.allowedBranches "main develop"
    cfg_reset
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

@test "format : erreur de syntaxe -> commit refuse, message clair" {
    require ruff
    printf 'def f(:\n' >casse.py
    git add casse.py
    run git commit -q -m "ajoute casse"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Échec du formatage"* ]]
}

@test "format : outil du projet (.venv) prioritaire sur celui du poste" {
    mkdir -p .venv/bin
    printf '#!/bin/sh\n[ "$1" = --version ] && exit 0\necho RUFF-DU-PROJET >&2\n' >.venv/bin/ruff
    chmod +x .venv/bin/ruff
    touch pyproject.toml
    printf 'x = 1\n' >a.py
    git add a.py pyproject.toml
    run git commit -q -m "ajoute a"
    [[ "$output" == *"RUFF-DU-PROJET"* ]]
}

# --- Infrastructure as code ---------------------------------------------------

@test "IaC : les YAML d'un chart Helm ne sont confies qu'a helm (jamais prettier)" {
    load_engine
    mkdir -p chart/templates
    touch chart/Chart.yaml package.json
    plugins_for_file_r chart/templates/svc.yaml
    nearest_project_r chart/templates/svc.yaml "$REPLY"
    [ "$REPLY" = "helm chart" ]
    ! declare -F helm_format
}

@test "IaC : detection Kubernetes, Ansible, Terraform, Packer, Docker, Actions" {
    load_engine
    mkdir -p k8s infra ansible img .github/workflows
    touch k8s/kustomization.yaml infra/main.tf ansible/ansible.cfg img/build.pkr.hcl Dockerfile
    [ "$(nearest_project k8s/deploy.yaml "kubernetes node")" = "kubernetes k8s" ]
    [ "$(nearest_project infra/vars.tf terraform)" = "terraform infra" ]
    [ "$(nearest_project ansible/site.yml "ansible node")" = "ansible ansible" ]
    [ "$(nearest_project img/vars.pkrvars.hcl packer)" = "packer img" ]
    [[ " $(plugins_for_file Dockerfile.prod) " == *" docker "* ]]
    has_marker . actions
}

@test "IaC : workflow GitHub modifie -> actionlint lance au push" {
    require actionlint
    mkdir -p .github/workflows
    printf 'name: ci\non: push\njobs:\n  b:\n    runs-onn: ubuntu-latest\n    steps:\n      - run: echo\n' >.github/workflows/ci.yml
    git add -A
    git commit -q -m "ci: workflow"
    run git push -q origin feat/x
    [ "$status" -ne 0 ]
    [[ "$output" == *"actionlint"* ]]
}

@test "python : pas de faux succes avec un .pyc perime (meme taille, meme seconde)" {
    require pytest
    load_engine
    mkdir -p tests
    printf '[tool.pytest.ini_options]\npythonpath = ["."]\n' >pyproject.toml
    printf 'def test_x():\n    assert 1 == 1\n' >tests/test_x.py
    python_test >/dev/null 2>&1
    pytest -q >/dev/null 2>&1 || true # laisse un .pyc dans __pycache__
    printf 'def test_x():\n    assert 1 == 2\n' >tests/test_x.py
    touch -r pyproject.toml tests/test_x.py
    run python_test
    [ "$status" -ne 0 ]
}

@test "config : lue une seule fois, cles insensibles a la casse, derniere valeur" {
    git config repogarde.allowedBranches "a"
    git config --add repogarde.allowedBranches "b"
    git config repogarde.skip ""
    load_engine
    [ "$(cfg allowedbranches)" = b ]
    [ "$(cfg ALLOWEDBRANCHES)" = b ]
    [ -z "$(cfg skip)" ]
    [ "$(cfg inexistante defaut)" = defaut ]
}
