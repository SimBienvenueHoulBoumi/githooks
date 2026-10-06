#!/usr/bin/env bats
# ci/check.sh : mêmes règles que les hooks, en CI

load helpers

CHECK="$BATS_TEST_DIRNAME/../ci/check.sh"

setup() {
    setup_repo
    # contexte CI : pas de hooks (prepare-commit-msg corrigerait les messages testés)
    mkdir -p "$BATS_TEST_TMPDIR/nohooks"
    git config core.hooksPath "$BATS_TEST_TMPDIR/nohooks"
    git config --unset repogarde.skip # contexte CI : aucune config locale
    initial_commit
    BASE_SHA="$(git rev-parse HEAD)"
    git switch -q -c feat/x
    export REPOGARDE_BASE="$BASE_SHA" REPOGARDE_BRANCH=feat/x
    # isole des variables CI de l'environnement d'exécution
    unset GITHUB_ACTIONS GITHUB_BASE_REF GITHUB_HEAD_REF GITHUB_REF_NAME CI_COMMIT_BRANCH \
        CI_MERGE_REQUEST_SOURCE_BRANCH_NAME CI_MERGE_REQUEST_DIFF_BASE_SHA
}

@test "ci : commits conformes" {
    git commit -q --no-verify --allow-empty -m "feat: a"
    git commit -q --no-verify --allow-empty -m "fix(api): b"
    run "$CHECK" commits
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 commit(s) conforme(s)"* ]]
}

@test "ci : commit non conforme refuse" {
    git commit -q --no-verify --allow-empty -m "feat: a"
    git commit -q --no-verify --allow-empty -m "wip"
    run "$CHECK" commits
    [ "$status" -ne 0 ]
    [[ "$output" == *"« wip »"* ]]
}

@test "ci : fixup! refuse (a squasher avant merge)" {
    git commit -q --no-verify --allow-empty -m "fixup! feat: a"
    run "$CHECK" commits
    [ "$status" -ne 0 ]
    [[ "$output" == *"squasher"* ]]
}

@test "ci : nom de branche" {
    run "$CHECK" branch
    [ "$status" -eq 0 ]
    REPOGARDE_BRANCH=Mauvais run "$CHECK" branch
    [ "$status" -ne 0 ]
    [[ "$output" == *"feat/mauvais"* ]]
}

@test "ci : branche detectee depuis les variables GitLab" {
    unset REPOGARDE_BRANCH
    CI_COMMIT_BRANCH=Mauvais run "$CHECK" branch
    [ "$status" -ne 0 ]
    CI_MERGE_REQUEST_SOURCE_BRANCH_NAME=fix/ok run "$CHECK" branch
    [ "$status" -eq 0 ]
}

@test "ci : tag, pas de verification de branche" {
    unset REPOGARDE_BRANCH
    CI_COMMIT_TAG=v1.0.0 CI_COMMIT_BRANCH="" run "$CHECK" branch
    [ "$status" -eq 0 ]
}

@test "ci : format non conforme refuse, dossier de travail restaure" {
    require ruff
    printf 'x  =  1\n' >a.py
    git add a.py
    git commit -q --no-verify -m "feat: a"
    run "$CHECK" format
    [ "$status" -ne 0 ]
    [[ "$output" == *"a.py : non formaté"* ]]
    [ -z "$(git status --porcelain)" ]
}

@test "ci : format conforme" {
    require ruff
    printf 'x = 1\n' >a.py
    git add a.py
    git commit -q --no-verify -m "feat: a"
    run "$CHECK" format
    [ "$status" -eq 0 ]
}

@test "ci : tests des projets touches" {
    require make
    printf 'test:\n\t@echo ci-make && exit 1\n' >Makefile
    git add Makefile
    git commit -q --no-verify -m "build: make"
    run "$CHECK" tests
    [ "$status" -ne 0 ]
    [[ "$output" == *"ci-make"* ]]
}

@test "ci : secrets detectes" {
    require gitleaks
    printf 'token = ghp_%s\n' "4Rk9vQ2xLm7TzP0aWc3Ny8BdHs5Ju1Ef6GiX" >config.ini # factice
    git add config.ini
    git commit -q --no-verify -m "feat: config"
    run "$CHECK" secrets
    [ "$status" -ne 0 ]
}

@test "ci : skip via .repogarde.conf versionne" {
    git commit -q --no-verify --allow-empty -m "wip"
    printf '[repogarde]\n\tskip = commit-msg\n' >.repogarde.conf
    git add .repogarde.conf
    git commit -q --no-verify -m "chore: conf"
    run "$CHECK" commits
    [ "$status" -eq 0 ]
    [[ "$output" == *"Désactivé par .repogarde.conf"* ]]
}

@test "ci : mode strict, outil manquant = echec" {
    printf '{"name":"x","scripts":{"test":"exit 0"}}\n' >package.json
    printf 'const a=1\n' >a.js
    git add -A
    git commit -q --no-verify -m "feat: js"
    run env PATH="$(dirname "$(command -v git)"):/usr/bin:/bin" REPOGARDE_STRICT=true "$CHECK" format
    [ "$status" -ne 0 ]
    [[ "$output" == *"prettier introuvable"* ]]
}

@test "ci : annotations GitHub" {
    git commit -q --no-verify --allow-empty -m "wip"
    GITHUB_ACTIONS=true run "$CHECK" commits
    [[ "$output" == *"::error title=repogarde::"* ]]
}

@test "ci : verification inconnue" {
    run "$CHECK" nimporte
    [ "$status" -ne 0 ]
}

@test "ci : formateur en erreur (syntaxe) -> echec" {
    require ruff
    printf 'def f(:\n' >casse.py
    git add casse.py
    git commit -q --no-verify -m "feat: casse"
    run "$CHECK" format
    [ "$status" -ne 0 ]
}

@test "ci : titre de PR conforme / non conforme (message du commit en squash)" {
    git commit -q --no-verify --allow-empty -m "feat: a"
    REPOGARDE_PR_TITLE="feat(api): ajoute la route" run "$CHECK" commits
    [ "$status" -eq 0 ]
    [[ "$output" == *"Titre de la PR conforme"* ]]
    REPOGARDE_PR_TITLE="Ajout de la route" run "$CHECK" commits
    [ "$status" -ne 0 ]
    [[ "$output" == *"Titre de la PR « Ajout de la route »"* ]]
}
