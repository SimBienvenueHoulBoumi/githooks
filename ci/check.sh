#!/usr/bin/env bash
# Vérifications CI : mêmes règles que les hooks, mais non contournables.
# Fonctionne sur GitHub Actions, GitLab CI ou tout autre CI (variables REPOGARDE_*).
#
#   ci/check.sh [commits] [branch] [secrets] [format] [tests]   (défaut : tout)
#
# Variables (toutes optionnelles, détectées automatiquement sur GitHub/GitLab) :
#   REPOGARDE_CHECKS   liste des vérifications (si aucun argument)
#   REPOGARDE_BASE     commit de base (sinon : MR/PR, push précédent, branche par défaut)
#   REPOGARDE_BRANCH   nom de branche à vérifier
#   REPOGARDE_TARGET   branche cible de la PR / MR (flux integrationBranch)
#   REPOGARDE_STRICT   "true" : un outil de formatage/test manquant fait échouer
#   REPOGARDE_PR_TITLE titre de la PR / MR (devient le message du commit en squash)
#   REPOGARDE_BIN      dossier des outils installés (gitleaks), ajouté au PATH
set -euo pipefail

REPOGARDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../hooks/lib/common.sh
source "$REPOGARDE_DIR/hooks/lib/common.sh"
# shellcheck source=../hooks/lib/lang.sh
source "$REPOGARDE_DIR/hooks/lib/lang.sh"

export PATH="${REPOGARDE_BIN:-$HOME/.local/bin}:$PATH"
cd "$(git rev-parse --show-toplevel)"

# --- Affichage -----------------------------------------------------------------

section() { echo; echo "━━ $* ━━"; }

# Erreur annotée (visible dans l'onglet "Files changed" sur GitHub)
ci_error() {
    if [ "${GITHUB_ACTIONS:-}" = true ]; then
        echo "::error title=repogarde::$*"
    else
        err "$*" >&2
    fi
}

# --- Contexte : base, branche, fichiers ------------------------------------------

is_zero() { [[ "$1" =~ ^0+$ ]]; }
is_commit() { git cat-file -e "$1^{commit}" 2>/dev/null; }

# Commit de base des changements à vérifier (vide = tout l'historique)
detect_base() {
    local v def
    if [ -n "${REPOGARDE_BASE:-}" ]; then echo "$REPOGARDE_BASE"; return; fi
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
    echo "${REPOGARDE_BRANCH:-${GITHUB_HEAD_REF:-${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-${CI_COMMIT_BRANCH:-${GITHUB_REF_NAME:-}}}}}"
}

# Branche cible de la PR / MR (vide hors PR)
detect_target() {
    echo "${REPOGARDE_TARGET:-${GITHUB_BASE_REF:-${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}}}"
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

# Bots de mise à jour des dépendances : leurs titres (« bump <paquet> from X
# to Y ») dépassent souvent 72 caractères ; seul leur format est exigé.
BOTS='^[0-9]*\+?(dependabot|renovate)\[bot\]@'
is_bot_branch() { [[ "$1" == dependabot/* || "$1" == renovate/* ]]; }

check_commits() {
    section "Messages de commit (Conventional Commits)"
    local sha subject bad=0 count=0 bot=""
    is_bot_branch "$(detect_branch)" && bot=1
    if [ -z "$BASE" ]; then info "Pas de base : vérification ignorée."; return 0; fi
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
        elif [[ "$(git log -1 --format=%ae "$sha")" =~ $BOTS ]]; then
            continue
        elif authored_length "$subject" && [ "$REPLY" -gt 72 ]; then
            ci_error "${sha:0:7} « $subject » : première ligne > 72 caractères (hors suffixe « (#NN) » de GitHub)."
            bad=1
        fi
    done < <(git rev-list --no-merges "$BASE..HEAD")
    # Titre de la PR : message du commit final en cas de merge squash
    local title="${REPOGARDE_PR_TITLE:-${CI_MERGE_REQUEST_TITLE:-}}"
    if [ -n "$title" ]; then
        if ! [[ "$title" =~ $CC_PATTERN ]]; then
            ci_error "Titre de la PR « $title » : format attendu <type>(<scope>): <description> (il devient le message du commit en squash)."
            bad=1
        elif [ -z "$bot" ] && authored_length "$title" && [ "$REPLY" -gt 72 ]; then
            ci_error "Titre de la PR « $title » : plus de 72 caractères."
            bad=1
        else
            ok "Titre de la PR conforme."
        fi
    fi
    if [ "$bad" = 1 ]; then
        echo "Types :"
        types_help 2>&1
        echo "Corriger : en merge squash, seul le titre de la PR devient le message final : le corriger suffit."
        echo "Sinon (historique conservé) : git rebase -i $BASE (reword), puis git push --force-with-lease"
        return 1
    fi
    ok "$count commit(s) conforme(s)."
}

check_branch() {
    section "Nom de branche"
    local branch
    branch="$(detect_branch)"
    if [ -z "$branch" ]; then info "Pas de branche (tag ou HEAD détachée) : ignoré."; return 0; fi
    if ! branch_name_valid "$branch"; then
        ci_error "Branche « $branch » non conforme : <type>/<sujet>, ex. $(suggest_branch_name "$branch")."
        branch_help "$branch" 2>&1
        return 1
    fi
    ok "« $branch » conforme."
    # Flux avec branche d'intégration : la PR vise-t-elle la bonne branche ?
    local target allowed
    target="$(detect_target)"
    pr_targets_r "$branch"
    allowed="$REPLY"
    [ -n "$target" ] && [ -n "$allowed" ] || return 0
    if [[ " $allowed " == *" $target "* ]]; then
        ok "Cible « $target » conforme au flux."
        return 0
    fi
    ci_error "PR de « $branch » vers « $target » : cible attendue ${allowed// / ou } (réglage integrationBranch)."
    echo "  Corriger : modifier la branche de base de la PR (Edit, à côté du titre), ou gh pr edit --base ${allowed%% *}"
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
    if ! changed_files | without_excluded | format_files; then
        ci_error "Un formateur a échoué (erreur de syntaxe ?) : voir le log ci-dessus."
        git checkout -q -- .
        return 1
    fi
    local diff
    diff="$(git diff --name-only)"
    if [ -n "$diff" ]; then
        while IFS= read -r f; do ci_error "$f : non formaté."; done <<<"$diff"
        git --no-pager diff --stat
        echo "Corriger : installer les hooks (lefthook install) ou lancer le formateur, puis commiter."
        git checkout -q -- .
        return 1
    fi
    ok "Fichiers modifiés correctement formatés."
}

check_tests() {
    section "Tests des projets touchés"
    changed_files | without_excluded | test_projects
}

# --- Exécution ---------------------------------------------------------------------

CHECKS="${*:-${REPOGARDE_CHECKS:-commits branch secrets format tests}}"
REPOGARDE_WARN_FILE="$(mktemp)"
export REPOGARDE_WARN_FILE
trap 'rm -f "$REPOGARDE_WARN_FILE"' EXIT

# Historique complet nécessaire pour comparer à la base
if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch -q --unshallow 2>/dev/null || warn "Clone superficiel : utiliser fetch-depth: 0 (GitHub) ou GIT_DEPTH: 0 (GitLab)."
fi

BASE="$(detect_base)"
echo "repogarde CI — base : ${BASE:-aucune (historique complet)} — vérifications : $CHECKS"

failed=""
for check in $CHECKS; do
    # Étapes désactivables par le projet (.repogarde.conf versionné)
    case "$check" in
        commits) key="commit-msg" ;;
        branch) key="branch-name" ;;
        *) key="$check" ;;
    esac
    if skipped "$key"; then
        section "$check"
        info "Désactivé par .repogarde.conf (skip $key)."
        continue
    fi
    declare -F "check_$check" >/dev/null || { ci_error "Vérification inconnue : $check"; failed="$failed $check"; continue; }
    "check_$check" || failed="$failed $check"
done

if [ "${REPOGARDE_STRICT:-false}" = true ] && [ -s "$REPOGARDE_WARN_FILE" ]; then
    section "Mode strict"
    while IFS= read -r w; do ci_error "$w"; done <"$REPOGARDE_WARN_FILE"
    failed="$failed strict"
fi

echo
if [ -n "$failed" ]; then
    err "Échec :$failed"
    exit 1
fi
ok "Toutes les vérifications repogarde sont passées."
