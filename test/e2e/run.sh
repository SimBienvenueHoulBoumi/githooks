#!/usr/bin/env bash
# Tests de bout en bout : un vrai petit projet par langage, avec son vrai outillage.
#
#   test/e2e/run.sh <langage>...        (défaut : tous)
#   E2E_STRICT=1 test/e2e/run.sh java   un outil manquant = échec (CI)
#
# Chaque fixture test/e2e/<langage>/ contient :
#   project/   le projet de départ, correctement formaté, tests au vert
#   bad/       fichiers mal formatés copiés par-dessus le projet (optionnel)
#   keep/      fichiers qui ne doivent PAS être modifiés (ex. templates Helm)
#   break/     fichiers qui font échouer les tests (optionnel)
#   e2e.env    REQUIRES="outils…"  SETUP="commande d'installation"
#              PRECHECK="commande" (environnement complet ? sinon ignoré)
#
# Scénario : commit via les hooks (formatage) → ci/check.sh format → ci/check.sh
# tests (succès) → tests cassés → ci/check.sh tests (échec attendu).
set -uo pipefail

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$E2E_DIR/../.." && pwd -P)"
HOOKS="$ROOT/hooks"
CHECK="$ROOT/ci/check.sh"

pass=0 fail=0 skipped=0
failures=""

log() { echo "  $*"; }
ko() { log "✖ $*"; return 1; }

run_fixture() {
    local lang="$1" fixture="$E2E_DIR/$1" work repo base f REQUIRES="" SETUP="" PRECHECK=""
    # shellcheck source=/dev/null
    [ -f "$fixture/e2e.env" ] && source "$fixture/e2e.env"

    for f in $REQUIRES; do
        if ! command -v "$f" >/dev/null 2>&1; then
            if [ -n "${E2E_STRICT:-}" ]; then ko "outil requis absent : $f"; return 1; fi
            log "↷ ignoré : $f absent"
            return 2
        fi
    done

    if [ -n "$PRECHECK" ] && ! sh -c "$PRECHECK" >/dev/null 2>&1; then
        if [ -n "${E2E_STRICT:-}" ]; then ko "environnement incomplet : $PRECHECK"; return 1; fi
        log "↷ ignoré : environnement incomplet ($PRECHECK)"
        return 2
    fi

    work="$(mktemp -d)"
    repo="$work/repo"
    cp -R "$fixture/project" "$repo"
    cd "$repo" || return 1
    git init -q -b main
    git config user.name e2e
    git config user.email e2e@example.com
    git config commit.gpgsign false
    git config core.hooksPath "$HOOKS"
    git config repogarde.skip secrets

    if [ -n "$SETUP" ]; then
        log "▶ installation : $SETUP"
        sh -c "$SETUP" >"$work/setup.log" 2>&1 || { tail -30 "$work/setup.log"; ko "installation échouée"; return 1; }
    fi
    git add -A
    git commit -q --no-verify -m "chore: projet de départ"
    base="$(git rev-parse HEAD)"
    git switch -q -c feat/e2e
    export REPOGARDE_BASE="$base" REPOGARDE_BRANCH=feat/e2e
    [ -n "${E2E_STRICT:-}" ] && export REPOGARDE_STRICT=true

    # 1. Formatage au commit
    if [ -d "$fixture/bad" ]; then
        cp -R "$fixture/bad/." .
        git add -A
        if ! git commit -q -m "ajoute du code mal formaté" >"$work/commit.log" 2>&1; then
            cat "$work/commit.log"
            ko "commit refusé"
            return 1
        fi
        while IFS= read -r f; do
            f="${f#./}"
            if git show "HEAD:$f" | cmp -s - "$fixture/bad/$f"; then
                cat "$work/commit.log"
                ko "$f n'a pas été formaté au commit"
                return 1
            fi
        done < <(cd "$fixture/bad" && find . -type f)
        log "✔ formatage au commit"

        # 2. La CI voit un code conforme
        if ! "$CHECK" format >"$work/format.log" 2>&1; then
            cat "$work/format.log"
            ko "ci/check.sh format échoue après formatage"
            return 1
        fi
        log "✔ ci/check.sh format"
    fi

    # 1 bis. Fichiers à ne jamais reformater
    if [ -d "$fixture/keep" ]; then
        cp -R "$fixture/keep/." .
        git add -A
        if ! git commit -q -m "ajoute des fichiers à préserver" >"$work/keep.log" 2>&1; then
            cat "$work/keep.log"
            ko "commit refusé (keep)"
            return 1
        fi
        while IFS= read -r f; do
            f="${f#./}"
            if ! git show "HEAD:$f" | cmp -s - "$fixture/keep/$f"; then
                git show "HEAD:$f" | diff "$fixture/keep/$f" - | head -20
                ko "$f a été modifié alors qu'il doit être préservé"
                return 1
            fi
        done < <(cd "$fixture/keep" && find . -type f)
        log "✔ fichiers préservés"
    fi

    # 3. Tests au vert, puis cassés
    if [ -d "$fixture/break" ]; then
        if ! "$CHECK" tests >"$work/tests.log" 2>&1; then
            cat "$work/tests.log"
            ko "tests en échec sur le projet sain"
            return 1
        fi
        log "✔ tests au vert"
        cp -R "$fixture/break/." .
        git add -A
        git commit -q --no-verify -m "test: casse volontairement"
        if "$CHECK" tests >"$work/broken.log" 2>&1; then
            cat "$work/broken.log"
            ko "tests cassés non détectés"
            return 1
        fi
        log "✔ tests cassés détectés"
    fi
    rm -rf "$work"
}

langs="${*:-$(cd "$E2E_DIR" && for d in */; do [ -d "$d/project" ] && echo "${d%/}"; done)}"
for lang in $langs; do
    echo "━━ $lang"
    (run_fixture "$lang")
    case $? in
        0) pass=$((pass + 1)) ;;
        2) skipped=$((skipped + 1)) ;;
        *) fail=$((fail + 1)); failures="$failures $lang" ;;
    esac
done

echo
echo "e2e : $pass réussi(s), $fail échec(s), $skipped ignoré(s)"
[ "$fail" -eq 0 ] || { echo "Échecs :$failures"; exit 1; }
