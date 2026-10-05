#!/usr/bin/env bash
# Vérifications CI : mêmes règles que les hooks, mais non contournables.
# Fonctionne sur GitHub Actions, GitLab CI ou tout autre CI (variables GITHOOKS_*).
#
#   ci/check.sh [commits] [branch] [secrets] [format] [tests]   (défaut : tout)
#
# Variables (toutes optionnelles, détectées automatiquement sur GitHub/GitLab) :
#   GITHOOKS_CHECKS   liste des vérifications (si aucun argument)
#   GITHOOKS_BASE     commit de base (sinon : MR/PR, push précédent, branche par défaut)
#   GITHOOKS_BRANCH   nom de branche à vérifier
#   GITHOOKS_STRICT   "true" : un outil de formatage/test manquant fait échouer
#   GITHOOKS_BIN      dossier des outils installés (gitleaks), ajouté au PATH
set -euo pipefail

GITHOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../hooks/lib/common.sh
source "$GITHOOKS_DIR/hooks/lib/common.sh"
# shellcheck source=../hooks/lib/lang.sh
source "$GITHOOKS_DIR/hooks/lib/lang.sh"

export PATH="${GITHOOKS_BIN:-$HOME/.local/bin}:$PATH"
cd "$(git rev-parse --show-toplevel)"

# --- Affichage -----------------------------------------------------------------

section() { echo; echo "━━ $* ━━"; }

# Erreur annotée (visible dans l'onglet "Files changed" sur GitHub)
ci_error() {
    if [ "${GITHUB_ACTIONS:-}" = true ]; then
        echo "::error title=githooks::$*"
    else
        echo "✖ $*" >&2
    fi
}

# --- Contexte : base, branche, fichiers ------------------------------------------

is_zero() { [[ "$1" =~ ^0+$ ]]; }
is_commit() { git cat-file -e "$1^{commit}" 2>/dev/null; }

# Commit de base des changements à vérifier (vide = tout l'historique)
detect_base() {
    local v def
    if [ -n "${GITHOOKS_BASE:-}" ]; then echo "$GITHOOKS_BASE"; return; fi
    # GitLab merge request
    if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ]; then echo "$CI_MERGE_REQUEST_DIFF_BASE_SHA"; return; fi
    # GitHub pull request
    if [ -n "${GITHUB_BASE_REF:-}" ]; then
        git fetch -q origin "$GITHUB_BASE_REF" 2>/dev/null || true
        git merge-base HEAD "origin/$GITHUB_BASE_REF" 2>/dev/null && return
    fi
    # Push : état précédent de la branche
    for v in "${CI_COMMIT_BEFORE_SHA:-}" "${GITHUB_EVENT_BEFORE:-}"; do
        if [ -n "$v" ] && ! is_zero "$v" && is_commit "$v"; then echo "$v"; return; fi
    done
    # Nouvelle branche : point de départ depuis la branche par défaut
    def="${CI_DEFAULT_BRANCH:-${GITHUB_DEFAULT_BRANCH:-main}}"
    git fetch -q origin "$def" 2>/dev/null || true
    git merge-base HEAD "origin/$def" 2>/dev/null || true
}

detect_branch() {
    # Tag : pas de nom de branche à vérifier
    if [ -n "${CI_COMMIT_TAG:-}" ] || [ "${GITHUB_REF_TYPE:-}" = tag ]; then return; fi
    echo "${GITHOOKS_BRANCH:-${GITHUB_HEAD_REF:-${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-${CI_COMMIT_BRANCH:-${GITHUB_REF_NAME:-}}}}}"
}

# Fichiers ajoutés/modifiés depuis la base (tous les fichiers suivis sans base)
changed_files() {
    if [ -n "$BASE" ]; then
        git diff --name-only --diff-filter=ACMR "$BASE" HEAD
    else
        git ls-files
    fi
}

# --- Vérifications ---------------------------------------------------------------

check_commits() {
    section "Messages de commit (Conventional Commits)"
    local sha subject bad=0 count=0
    if [ -z "$BASE" ]; then echo "ℹ Pas de base : vérification ignorée."; return 0; fi
    while IFS= read -r sha; do
        subject="$(git log -1 --format=%s "$sha")"
        count=$((count + 1))
        if [[ "$subject" =~ ^(fixup|squash|amend)! ]]; then
            ci_error "${sha:0:7} « $subject » : commit à squasher avant le merge (git rebase -i --autosquash)."
            bad=1
        elif [[ "$subject" =~ ^(Merge|Revert) ]]; then
            continue
        elif ! [[ "$subject" =~ $CC_PATTERN ]]; then
            ci_error "${sha:0:7} « $subject » : format attendu <type>(<scope>): <description>."
            bad=1
        elif [ "${#subject}" -gt 72 ]; then
            ci_error "${sha:0:7} « $subject » : première ligne > 72 caractères."
            bad=1
        fi
    done < <(git rev-list --no-merges "$BASE..HEAD")
    if [ "$bad" = 1 ]; then
        echo "Types :"
        types_help 2>&1
        echo "Corriger : git rebase -i $BASE (reword), puis git push --force-with-lease"
        return 1
    fi
    echo "✔ $count commit(s) conforme(s)."
}

check_branch() {
    section "Nom de branche"
    local branch
    branch="$(detect_branch)"
    if [ -z "$branch" ]; then echo "ℹ Pas de branche (tag ou HEAD détachée) : ignoré."; return 0; fi
    if branch_name_valid "$branch"; then
        echo "✔ « $branch » conforme."
        return 0
    fi
    ci_error "Branche « $branch » non conforme : <type>/<sujet>, ex. $(suggest_branch_name "$branch")."
    branch_help "$branch" 2>&1
    return 1
}

check_secrets() {
    section "Secrets (gitleaks)"
    if ! has gitleaks; then
        ci_error "gitleaks absent : lancer ci/install-gitleaks.sh avant ce script."
        return 1
    fi
    if [ -n "$BASE" ]; then
        gitleaks git --redact --no-banner --log-opts="$BASE..HEAD" .
    else
        gitleaks git --redact --no-banner .
    fi || { ci_error "Secret détecté : le retirer de l'historique et révoquer le secret."; return 1; }
}

check_format() {
    section "Formatage"
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        ci_error "Dossier de travail modifié avant la vérification : impossible de contrôler le formatage."
        return 1
    fi
    changed_files | format_files
    local diff
    diff="$(git diff --name-only)"
    if [ -n "$diff" ]; then
        while IFS= read -r f; do ci_error "$f : non formaté."; done <<<"$diff"
        git --no-pager diff --stat
        echo "Corriger : installer les hooks (lefthook install) ou lancer le formateur, puis commiter."
        git checkout -q -- .
        return 1
    fi
    echo "✔ Fichiers modifiés correctement formatés."
}

check_tests() {
    section "Tests des projets touchés"
    changed_files | test_projects
}

# --- Exécution ---------------------------------------------------------------------

CHECKS="${*:-${GITHOOKS_CHECKS:-commits branch secrets format tests}}"
GITHOOKS_WARN_FILE="$(mktemp)"
export GITHOOKS_WARN_FILE
trap 'rm -f "$GITHOOKS_WARN_FILE"' EXIT

# Historique complet nécessaire pour comparer à la base
if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch -q --unshallow 2>/dev/null || warn "Clone superficiel : utiliser fetch-depth: 0 (GitHub) ou GIT_DEPTH: 0 (GitLab)."
fi

BASE="$(detect_base)"
echo "githooks CI — base : ${BASE:-aucune (historique complet)} — vérifications : $CHECKS"

failed=""
for check in $CHECKS; do
    # Étapes désactivables par le projet (.githooks.conf versionné)
    case "$check" in
        commits) key="commit-msg" ;;
        branch) key="branch-name" ;;
        *) key="$check" ;;
    esac
    if skipped "$key"; then
        section "$check"
        echo "ℹ Désactivé par .githooks.conf (skip $key)."
        continue
    fi
    declare -F "check_$check" >/dev/null || { ci_error "Vérification inconnue : $check"; failed="$failed $check"; continue; }
    "check_$check" || failed="$failed $check"
done

if [ "${GITHOOKS_STRICT:-false}" = true ] && [ -s "$GITHOOKS_WARN_FILE" ]; then
    section "Mode strict"
    while IFS= read -r w; do ci_error "$w"; done <"$GITHOOKS_WARN_FILE"
    failed="$failed strict"
fi

echo
if [ -n "$failed" ]; then
    echo "✖ Échec :$failed"
    exit 1
fi
echo "✔ Toutes les vérifications githooks sont passées."
