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

# --- bin/proteger (protection GitHub d'après .repogarde.conf) : gh simulé --------

PROTEGER="$BATS_TEST_DIRNAME/../bin/proteger"

# Faux gh : branches existantes = $GH_BRANCHES ; journalise les appels
fake_gh_repo() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
case "$*" in
    "repo view"*) echo moi/projet ;;
    "api repos/moi/projet/branches/"*) [[ " $GH_BRANCHES " == *" ${2##*/} "* ]] ;;
esac
GH
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH" GH_LOG="$BATS_TEST_TMPDIR/gh.log"
}

# Rulesets affichés par --dry-run → JSON (liste) dans $RULESETS
rulesets_json() {
    python3 -c 'import json,sys
d=json.JSONDecoder(); t=sys.stdin.read(); i=t.index("{"); out=[]
while i < len(t):
    if t[i] in " \n": i+=1; continue
    o,i=d.raw_decode(t,i); out.append(o)
print(json.dumps(out))' <<<"$(sed -n '/^{/,$p' <<<"$1")"
}

@test "proteger : flux main seul -> squash, branches supprimees au merge, tags reserves" {
    require python3
    fake_gh_repo
    GH_BRANCHES="main" run "$PROTEGER" --dry-run
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; r=json.loads(sys.argv[1]); assert len(r)==2; b,t=r; \
        assert b["name"]=="repogarde" and b["conditions"]["ref_name"]["include"]==["refs/heads/main"]; \
        assert b["rules"][2]["parameters"]["allowed_merge_methods"]==["squash"]; \
        assert b["rules"][3]["parameters"]["required_status_checks"][0]["context"]=="repogarde"; \
        assert t["target"]=="tag" and t["conditions"]["ref_name"]["include"]==["refs/tags/v*"]' "$(rulesets_json "$output")"
    [[ "$output" == *"suppression auto des branches : true"* ]]
    [[ "$output" != *"branche par défaut"* ]]
}

@test "proteger : flux develop -> main en merge commit, develop squash ou merge, defaut develop" {
    require python3
    fake_gh_repo
    git config repogarde.integrationBranch develop
    git config repogarde.protectedBranches "main develop"
    GH_BRANCHES="main develop" run "$PROTEGER" --dry-run --checks "repogarde ci"
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; r=json.loads(sys.argv[1]); assert len(r)==3; m,d,t=r; \
        assert m["conditions"]["ref_name"]["include"]==["refs/heads/main"]; \
        assert m["rules"][2]["parameters"]["allowed_merge_methods"]==["merge"]; \
        assert d["name"]=="repogarde (develop)" and d["conditions"]["ref_name"]["include"]==["refs/heads/develop"]; \
        assert d["rules"][2]["parameters"]["allowed_merge_methods"]==["squash","merge"]; \
        assert [c["context"] for c in d["rules"][3]["parameters"]["required_status_checks"]]==["repogarde","ci"]; \
        assert t["name"]=="repogarde (tags)"' "$(rulesets_json "$output")"
    [[ "$output" == *"suppression auto des branches : false"* ]]
    [[ "$output" == *"branche par défaut : develop"* ]]
}

@test "proteger : aucune branche protegee existante -> erreur" {
    fake_gh_repo
    GH_BRANCHES="" run "$PROTEGER" --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"Aucune des branches"* ]]
}
