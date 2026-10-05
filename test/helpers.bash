# Helpers communs aux tests bats : chaque test tourne dans un dépôt jetable
# avec les hooks du dépôt githooks courant.

HOOKS="$(cd "$BATS_TEST_DIRNAME/../hooks" && pwd -P)"

setup_repo() {
    REPO="$BATS_TEST_TMPDIR/repo"
    REMOTE="$BATS_TEST_TMPDIR/remote.git"
    git init -q --bare "$REMOTE"
    git init -q -b main "$REPO"
    cd "$REPO" || return 1
    git config user.name test
    git config user.email test@example.com
    git config commit.gpgsign false
    git config core.hooksPath "$HOOKS"
    git config hooks.skip secrets # gitleaks pas forcément installé
    git remote add origin "$REMOTE"
}

# Premier commit sur main (autorisé : pas encore de HEAD)
initial_commit() {
    echo init >README.md
    git add README.md
    git commit -q -m "chore: init"
}

# Module Go minimal avec un test qui passe (TEST_OK=1) ou échoue
go_project() {
    printf 'module x\n\ngo 1.21\n' >go.mod
    write_go_test "$1"
}

write_go_test() {
    local expected=1
    [ "$1" = fail ] && expected=2
    printf 'package main\n\nimport "testing"\n\nfunc TestX(t *testing.T) {\n\tif 1 != %s {\n\t\tt.Fatal("ko")\n\t}\n}\n' "$expected" >x_test.go
}

subject() { git log -1 --format=%s "${1:-HEAD}"; }

require() {
    command -v "$1" >/dev/null 2>&1 || skip "$1 absent"
}
