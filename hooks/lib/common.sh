#!/usr/bin/env bash
# Fonctions communes à tous les hooks : désactivation par projet et chaînage
# des hooks propres au projet. Compatible bash 3.2 (macOS).
# shellcheck disable=SC2034 # variables utilisées par les hooks qui sourcent ce fichier

HOOK_NAME="$(basename "$0")"
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# Avertissement ; si GITHOOKS_WARN_FILE est défini (CI), il est aussi journalisé
# pour le mode strict (outil manquant = échec)
warn() {
    echo "⚠ $*" >&2
    if [ -n "${GITHOOKS_WARN_FILE:-}" ]; then echo "$*" >>"$GITHOOKS_WARN_FILE"; fi
}
step() { echo "▶ $*"; }
has() { command -v "$1" >/dev/null 2>&1; }

# Lit un réglage hooks.<clé> : git config (local puis global) en priorité,
# puis .githooks.conf versionné à la racine du projet, sinon la valeur par défaut.
#   cfg allowedBranches "main master"
cfg() {
    local root
    git config --get "hooks.$1" 2>/dev/null && return 0
    root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$root" ] && [ -f "$root/.githooks.conf" ] &&
        git config -f "$root/.githooks.conf" --get "hooks.$1" 2>/dev/null && return 0
    [ $# -ge 2 ] && printf '%s\n' "$2"
    return 0
}

# Conventional Commits (partagé par commit-msg et prepare-commit-msg)
CC_TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
CC_PATTERN="^($CC_TYPES)(\([a-z0-9._-]+\))?!?: .+"

# Nommage des branches : <type>/<sujet>
BRANCH_ALIASES="feature|bugfix|hotfix"
BRANCH_PATTERN="^($CC_TYPES|$BRANCH_ALIASES)/[a-z0-9._-]+(/[a-z0-9._-]+)*$"
DEFAULT_ALLOWED_BRANCHES="main master develop release/*"

# Liste des types avec leur rôle (affichée dans les messages d'aide)
types_help() {
    cat >&2 <<'EOF'
  feat      nouvelle fonctionnalité          (branche : feature/ accepté)
  fix       correction de bug                (branche : bugfix/, hotfix/ acceptés)
  docs      documentation uniquement
  style     formatage, sans changement de logique
  refactor  restructuration sans changement de comportement
  perf      amélioration de performance
  test      ajout ou modification de tests
  build     build, dépendances (pom.xml, package.json…)
  ci        intégration continue
  chore     maintenance diverse
  revert    annulation d'un commit
EOF
}

# Vrai si la branche respecte la convention ou fait partie des exceptions
branch_name_valid() {
    local branch="$1" allowed pat
    [ -z "$branch" ] && return 0 # HEAD détachée
    allowed="$(cfg allowedBranches "$DEFAULT_ALLOWED_BRANCHES")"
    set -f # pas d'expansion de "release/*" sur le disque
    for pat in $allowed; do
        # shellcheck disable=SC2254
        case "$branch" in $pat) set +f; return 0 ;; esac
    done
    set +f
    [[ "$branch" =~ $BRANCH_PATTERN ]]
}

# Propose un nom valide à partir d'un nom invalide (Feat/Mon Truc → feat/mon-truc)
suggest_branch_name() {
    local b type rest
    b="$(echo "$1" | tr '[:upper:] _' '[:lower:]--' | tr -cd 'a-z0-9._/-' |
        sed -e 's#//*#/#g' -e 's#^[/.-]*##' -e 's#[/.-]*$##')"
    if [[ "$b" != */* ]]; then
        echo "feat/${b:-ma-feature}"
        return
    fi
    type="${b%%/*}"
    rest="${b#*/}"
    case "$type" in
        bug | bugs) type=fix ;;
        doc) type=docs ;;
        features) type=feat ;;
        tests) type="test" ;;
        refacto) type=refactor ;;
    esac
    [[ "$type" =~ ^($CC_TYPES|$BRANCH_ALIASES)$ ]] || type=feat
    echo "$type/$rest"
}

# Message d'aide complet pour une branche invalide
branch_help() {
    local branch="$1"
    cat >&2 <<EOF

Nom de branche invalide : "$branch"

Format attendu : <type>/<sujet>
  sujet : minuscules, chiffres, . _ - (et / pour sous-découper)
  ex.   : feat/inscription, fix/user/login, hotfix/timeout-db

Types :
EOF
    types_help
    cat >&2 <<EOF

👉 Renommer la branche courante :
     git branch -m $(suggest_branch_name "$branch")

   Si elle est déjà poussée, renomme aussi le distant :
     git push origin -u $(suggest_branch_name "$branch") && git push origin --delete $branch

Exceptions autorisées : $(cfg allowedBranches "$DEFAULT_ALLOWED_BRANCHES")
  (modifier : git config hooks.allowedBranches "main develop release/*")
Désactiver pour ce dépôt : git config hooks.skip branch-name
EOF
}

# Vrai si l'élément est désactivé (hooks.skip, git config ou .githooks.conf).
# Valeurs : true|all, ou liste séparée par espaces/virgules parmi
# pre-commit prepare-commit-msg commit-msg pre-push post-checkout
# branch-name protect-branch secrets format tests, ou un langage (node, python…)
skipped() {
    local v
    v="$(cfg skip)"
    [ "$v" = true ] || [ "$v" = all ] && return 0
    case " ${v//,/ } " in *" $1 "*) return 0 ;; esac
    return 1
}

# Le hook entier est-il désactivé ? (à appeler en tête de hook)
exit_if_skipped() {
    if skipped "$HOOK_NAME"; then
        echo "ℹ $HOOK_NAME désactivé (git config hooks.skip)."
        exit 0
    fi
}

# lefthook refuse de fonctionner (gros avertissement) quand core.hooksPath est
# défini globalement. Pour lui seul, on présente une copie de la config globale
# de l'utilisateur SANS core.hooksPath : il récupère ses remotes et installe ses
# hooks dans .git/hooks, sans jamais toucher au dossier githooks global.
lefthook_without_global_hookspath() {
    local global cfg key value
    git config --global --get core.hooksPath >/dev/null 2>&1 || return 0
    global="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"
    cfg="$(git rev-parse --absolute-git-dir)/githooks-lefthook.gitconfig"
    # Copie régénérée seulement si la config globale a changé
    if [ ! -f "$cfg" ] || [ "$global" -nt "$cfg" ]; then
        : >"$cfg.tmp"
        git config --global --list --includes -z | while IFS= read -r -d '' entry; do
            key="${entry%%$'\n'*}"
            value="${entry#*$'\n'}"
            [ "$key" = "$entry" ] && value=""
            [ "$(echo "$key" | tr '[:upper:]' '[:lower:]')" = core.hookspath ] && continue
            git config -f "$cfg.tmp" --add "$key" "$value"
        done
        mv "$cfg.tmp" "$cfg"
    fi
    export GIT_CONFIG_GLOBAL="$cfg"
}

# Projet géré par lefthook (lefthook.yml) : lui déléguer le hook, pour appliquer
# sa config (remote githooks à la version figée + jobs du projet) même quand
# githooks est installé globalement (core.hooksPath, que lefthook refuse).
delegate_to_lefthook() {
    local root f
    [ -n "${GITHOOKS_RUNNER:-}" ] && return 0
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
    for f in lefthook.yml lefthook.yaml .lefthook.yml .lefthook.yaml; do
        [ -f "$root/$f" ] || continue
        if has lefthook; then
            export GITHOOKS_RUNNER=lefthook
            lefthook_without_global_hookspath
            exec lefthook run "$HOOK_NAME" "$@"
        fi
        warn "Projet lefthook ($f) mais lefthook absent : règles githooks par défaut. Installe lefthook."
        return 0
    done
}

# Exécute les hooks propres au projet (.githooks/<hook> ou .git/hooks/<hook>),
# ignorés par git dès que core.hooksPath pointe ici.
# Désactivé sous lefthook : .git/hooks contient ses propres hooks (boucle infinie)
# et les hooks du projet sont alors déclarés dans lefthook.yml.
run_local_hook() {
    local candidate real
    [ "${GITHOOKS_RUNNER:-}" = lefthook ] && return 0
    for candidate in ".githooks/$HOOK_NAME" "$(git rev-parse --git-common-dir)/hooks/$HOOK_NAME"; do
        [ -x "$candidate" ] || continue
        real="$(cd "$(dirname "$candidate")" && pwd -P)"
        [ "$real" = "$HOOKS_DIR" ] && continue
        echo "ℹ Hook local du projet : $candidate"
        "$candidate" "$@" || return $?
    done
}
