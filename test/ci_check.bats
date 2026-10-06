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
        CI_MERGE_REQUEST_SOURCE_BRANCH_NAME CI_MERGE_REQUEST_DIFF_BASE_SHA \
        CI_MERGE_REQUEST_TARGET_BRANCH_NAME REPOGARDE_TARGET
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

@test "ci : requirements.txt sans tests (ex. outils de doc) -> pas d'exigence pytest en strict" {
    mkdir -p docs
    printf 'mkdocs==1.6.1\n' >docs/requirements.txt
    printf '# Doc\n' >docs/index.md
    git add -A
    git commit -q --no-verify -m "docs: site"
    run env REPOGARDE_STRICT=true PATH="$(dirname "$(command -v git)"):/usr/bin:/bin" "$CHECK" tests
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python : aucun test"* ]]
    [[ "$output" != *"pytest absent"* ]]
}

@test "ci : suffixe (#NN) d'un merge squash non compte dans les 72 caracteres" {
    # 67 caractères écrits + « (#31) » ajouté par GitHub = 73
    git commit -q --no-verify --allow-empty -m "docs(securite): vérification SLSA corrigée, piège du dossier déplacé (#31)"
    run "$CHECK" commits
    [ "$status" -eq 0 ]
    git commit -q --no-verify --allow-empty -m "docs: $(printf 'a%.0s' {1..70})"
    run "$CHECK" commits
    [ "$status" -ne 0 ]
}

@test "longueur : caracteres et non octets, meme en locale C (Git Bash Windows)" {
    source "$HOOKS/lib/common.sh"
    LC_ALL=C authored_length "docs(securite): vérification SLSA corrigée, piège du dossier déplacé"
    [ "$REPLY" -eq 68 ]
    authored_length "fix: àéèùçôîï (#12)"
    [ "$REPLY" -eq 13 ]
}

@test "ci : flux develop, cibles de PR autorisees" {
    git config repogarde.integrationBranch develop
    git config repogarde.allowedBranches "main develop release/* release-please--* dependabot/*"
    for paire in feat/x:develop develop:main release/1.2.0:main release/1.2.0:develop \
        hotfix/crash:main dependabot/maven/x:develop release-please--branches--main:main; do
        REPOGARDE_BRANCH="${paire%%:*}" REPOGARDE_TARGET="${paire#*:}" run "$CHECK" branch
        [ "$status" -eq 0 ] || { echo "devrait passer : $paire"; echo "$output"; return 1; }
    done
}

@test "ci : flux develop, mauvaise cible refusee avec la correction" {
    git config repogarde.integrationBranch develop
    REPOGARDE_TARGET=main run "$CHECK" branch
    [ "$status" -ne 0 ]
    [[ "$output" == *"cible attendue develop"* ]]
    [[ "$output" == *"gh pr edit --base develop"* ]]
    REPOGARDE_BRANCH=develop REPOGARDE_TARGET=release/1.0.0 run "$CHECK" branch
    [ "$status" -ne 0 ]
}

@test "ci : sans integrationBranch, toute cible acceptee" {
    REPOGARDE_TARGET=develop run "$CHECK" branch
    [ "$status" -eq 0 ]
    [[ "$output" != *"Cible"* ]]
}

# --- ci/fix-pr.sh (entrée fix-pr de l'action) : gh simulé ----------------------

FIX="$BATS_TEST_DIRNAME/../ci/fix-pr.sh"

# Faux gh : journalise ses arguments ; « pr list » renvoie $GH_DUP (doublon)
fake_gh() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
[ "$1 $2" = "pr list" ] && echo "${GH_DUP:-}"
exit 0
GH
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH" GH_LOG="$BATS_TEST_TMPDIR/gh.log"
    export GITHUB_ENV="$BATS_TEST_TMPDIR/github_env" PR=7
    : >"$GH_LOG"
    : >"$GITHUB_ENV"
}

# main et develop sur le remote, branche feat/x avec un commit
flux_develop() {
    git config repogarde.integrationBranch develop
    git push -q origin HEAD:main HEAD:develop
    git fetch -q origin
    git commit -q --allow-empty -m "feat(panier): ajoute le panier"
    export HEAD=feat/x HEAD_SHA="$(git rev-parse HEAD)"
}

@test "fix-pr : PR vers main recible vers develop, titre conforme garde" {
    fake_gh
    flux_develop
    BASE=main TITLE="feat: panier" run "$FIX"
    [ "$status" -eq 0 ]
    grep -q "pr edit 7 --base develop" "$GH_LOG"
    ! grep -q -- "--title" "$GH_LOG"
    grep -q "^REPOGARDE_FIXED_TARGET=develop$" "$GITHUB_ENV"
    grep -q "^REPOGARDE_FIXED_BASE=$BASE_SHA$" "$GITHUB_ENV"
}

@test "fix-pr : doublon ferme au lieu d'etre recible" {
    fake_gh
    flux_develop
    GH_DUP=3 BASE=main TITLE="feat: panier" run "$FIX"
    [ "$status" -eq 0 ]
    grep -q "pr close 7 --comment Doublon de #3" "$GH_LOG"
    ! grep -q -- "--base" "$GH_LOG"
    grep -q "^REPOGARDE_PR_CLOSED=true$" "$GITHUB_ENV"
}

@test "fix-pr : titre non conforme remplace par le commit unique" {
    fake_gh
    flux_develop
    BASE=develop TITLE="Feat/x" run "$FIX"
    [ "$status" -eq 0 ]
    grep -q "pr edit 7 --title feat(panier): ajoute le panier" "$GH_LOG"
    grep -q "^REPOGARDE_FIXED_TITLE=feat(panier): ajoute le panier$" "$GITHUB_ENV"
}

@test "fix-pr : plusieurs commits -> celui au plus fort impact de version" {
    fake_gh
    flux_develop
    git commit -q --allow-empty -m "test: panier"
    git commit -q --allow-empty -m "fix: arrondi"
    export HEAD_SHA="$(git rev-parse HEAD)"
    BASE=develop TITLE="Ajout du panier" run "$FIX"
    [ "$status" -eq 0 ]
    grep -q "^REPOGARDE_FIXED_TITLE=feat(panier): ajoute le panier$" "$GITHUB_ENV"
}

@test "fix-pr : pied BREAKING CHANGE -> « ! » ajoute au titre" {
    fake_gh
    flux_develop
    git commit -q --allow-empty -m "fix: format" -m "BREAKING CHANGE: nouveau format"
    export HEAD_SHA="$(git rev-parse HEAD)"
    BASE=develop TITLE="wip" run "$FIX"
    [ "$status" -eq 0 ]
    grep -q "^REPOGARDE_FIXED_TITLE=feat(panier)!: ajoute le panier$" "$GITHUB_ENV"
}

@test "fix-pr : aucun commit conforme -> titre deduit de la branche" {
    fake_gh
    git config repogarde.integrationBranch develop
    git push -q origin HEAD:main HEAD:develop
    git fetch -q origin
    git commit -q --no-verify --allow-empty -m "wip"
    export HEAD=feat/ajout-du-panier HEAD_SHA="$(git rev-parse HEAD)"
    BASE=develop TITLE="Ajout du panier" run "$FIX"
    [ "$status" -eq 0 ]
    grep -q "^REPOGARDE_FIXED_TITLE=feat: ajout du panier$" "$GITHUB_ENV"
}

@test "titres deduits des branches" {
    source "$BATS_TEST_DIRNAME/../hooks/lib/common.sh"
    git config repogarde.integrationBranch develop
    cfg_reset
    for paire in "hotfix/crash-login:fix: crash login" "release/1.2.0:chore(release): 1.2.0" \
        "develop:chore(release): livrer develop sur main" "wip:chore: wip" \
        "feature/a_b:feat: a b"; do
        suggest_pr_title_r "${paire%%:*}"
        [ "$REPLY" = "${paire#*:}" ] || { echo "${paire%%:*} -> « $REPLY »"; return 1; }
    done
    suggest_pr_title_r "feat/$(printf 'mot-%.0s' {1..30})fin"
    header_valid "$REPLY" || { echo "trop long : $REPLY"; return 1; }
}
