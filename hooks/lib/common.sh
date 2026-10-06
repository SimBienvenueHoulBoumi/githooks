#!/usr/bin/env bash
# Fonctions communes à tous les hooks : désactivation par projet et chaînage
# des hooks propres au projet. Compatible bash 3.2 (macOS).
# shellcheck disable=SC2034 # variables utilisées par les hooks qui sourcent ce fichier

HOOK_NAME="$(basename "$0")"
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# Avertissement ; si REPOGARDE_WARN_FILE est défini (CI), il est aussi journalisé
# pour le mode strict (outil manquant = échec)
warn() {
    echo "⚠ $*" >&2
    if [ -n "${REPOGARDE_WARN_FILE:-}" ]; then echo "$*" >>"$REPOGARDE_WARN_FILE"; fi
}
step() { echo "▶ $*"; }
has() { command -v "$1" >/dev/null 2>&1; }

# Anciens noms (githooks ≤ v1) : toujours acceptés, avec un avertissement unique
# par processus. Volontairement hors de `warn` : le mode strict de la CI ne doit
# pas faire échouer un projet qui n'a pas encore migré.
DEPRECATED_SEEN=""
deprecated() {
    case "$DEPRECATED_SEEN" in *"|$1|"*) return 0 ;; esac
    DEPRECATED_SEEN="$DEPRECATED_SEEN|$1|"
    echo "ℹ $1 : ancien nom (githooks), à remplacer par $2." >&2
}

# Variables d'environnement GITHOOKS_* → REPOGARDE_*
for _v in BIN BASE BRANCH CHECKS STRICT PR_TITLE CACHE; do
    if eval "[ -z \"\${REPOGARDE_$_v:-}\" ] && [ -n \"\${GITHOOKS_$_v:-}\" ]"; then
        eval "export REPOGARDE_$_v=\"\$GITHOOKS_$_v\""
        deprecated "GITHOOKS_$_v" "REPOGARDE_$_v"
    fi
done
unset _v

# Config repogarde.* chargée UNE fois par processus : chaque appel git coûte cher
# (20 à 50 ms sous Windows), et un hook lit la config des dizaines de fois.
# Priorité : git config (local puis global), puis .repogarde.conf versionné.
CFG_GIT=""
CFG_FILE=""
CFG_LOADED=""
# Racine du dépôt, calculée une fois et réutilisée par les hooks
GIT_TOPLEVEL=""

# Normalise la sortie de --get-regexp : clés hooks.* (anciennes) renommées en
# repogarde.* et placées AVANT les nouvelles, qui l'emportent donc (dernière valeur)
cfg_normalize() {
    local line old="" new=""
    while IFS= read -r line; do
        case "$line" in
            hooks.*) old="$old${line/#hooks./repogarde.}"$'\n' ;;
            ?*) new="$new$line"$'\n' ;;
        esac
    done <<<"$1"
    [ -z "$old" ] || deprecated "$2 hooks.*" "repogarde.*"
    REPLY="$old$new"
}

cfg_load() {
    local file=""
    GIT_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    cfg_normalize "$(git config --get-regexp '^(hooks|repogarde)\.' 2>/dev/null || true)" "git config"
    CFG_GIT="$REPLY"
    CFG_FILE=""
    if [ -n "$GIT_TOPLEVEL" ]; then
        if [ -f "$GIT_TOPLEVEL/.repogarde.conf" ]; then
            file="$GIT_TOPLEVEL/.repogarde.conf"
        elif [ -f "$GIT_TOPLEVEL/.githooks.conf" ]; then
            file="$GIT_TOPLEVEL/.githooks.conf"
            deprecated ".githooks.conf" ".repogarde.conf (section [repogarde])"
        fi
    fi
    if [ -n "$file" ]; then
        cfg_normalize "$(git config -f "$file" --get-regexp '^(hooks|repogarde)\.' 2>/dev/null || true)" "${file##*/} :"
        CFG_FILE="$REPLY"
    fi
    CFG_LOADED=1
}

# À appeler si la config change dans le même processus (tests)
cfg_reset() { cfg_load; }

# REPLY = dernière valeur de repogarde.<$1> dans $2 (sortie de --get-regexp, où git
# met les noms en minuscules : comparaison insensible à la casse). Échec si absente.
cfg_lookup() {
    local line found="" nocase=""
    REPLY=""
    shopt -q nocasematch && nocase=1
    shopt -s nocasematch
    while IFS= read -r line; do
        if [[ "$line" == "repogarde.$1 "* ]]; then
            REPLY="${line#* }"
            found=1
        elif [[ "$line" == "repogarde.$1" ]]; then
            REPLY=true # clé sans valeur
            found=1
        fi
    done <<<"$2"
    [ -n "$nocase" ] || shopt -u nocasematch
    [ -n "$found" ]
}

# REPLY = réglage repogarde.<$1>, ou $2 par défaut (sans sous-processus)
cfg_r() {
    [ -n "$CFG_LOADED" ] || cfg_load
    cfg_lookup "$1" "$CFG_GIT" || cfg_lookup "$1" "$CFG_FILE" || REPLY="${2-}"
    return 0
}

# Lit un réglage : cfg allowedBranches "main master" (2e argument = défaut)
cfg() {
    cfg_r "$@"
    [ -z "$REPLY" ] || printf '%s\n' "$REPLY"
}

# Conventional Commits (partagé par commit-msg et prepare-commit-msg)
CC_TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
CC_PATTERN="^($CC_TYPES)(\([a-z0-9._-]+\))?!?: .+"

# REPLY = longueur de la première ligne écrite par l'auteur : le suffixe
# « (#123) » ajouté par GitHub lors d'un merge squash n'est pas compté.
authored_length() {
    local subject="$1" continuation
    if [[ "$subject" =~ ^(.*)\ \(\#[0-9]+\)$ ]]; then subject="${BASH_REMATCH[1]}"; fi
    # Caractères et non octets, quelle que soit la locale (Git Bash sous Windows
    # est en locale C : « é » compterait double). En UTF-8, on retire du nombre
    # d'octets les octets de continuation (0x80 à 0xBF).
    local LC_ALL=C
    continuation="${subject//[^$'\x80'-$'\xbf']/}"
    REPLY=$((${#subject} - ${#continuation}))
}

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
    cfg_r allowedBranches "$DEFAULT_ALLOWED_BRANCHES"
    allowed="$REPLY"
    set -f # pas d'expansion de "release/*" sur le disque
    for pat in $allowed; do
        # shellcheck disable=SC2254
        case "$branch" in $pat) set +f; return 0 ;; esac
    done
    set +f
    [[ "$branch" =~ $BRANCH_PATTERN ]]
}

# Flux avec branche d'intégration (réglage integrationBranch, ex. develop) :
# REPLY = branches cibles autorisées pour une PR depuis la branche $1, vide si
# aucun flux n'est configuré (PR libres, en pratique vers main).
#   travail (feat/…, fix/…, bots) → intégration
#   intégration, PR de release-please → principale (mainBranch, défaut main)
#   release/…, hotfix/…           → principale ou intégration
pr_targets_r() {
    local integration
    cfg_r integrationBranch ""
    integration="$REPLY"
    [ -n "$integration" ] || return 0
    cfg_r mainBranch main
    case "$1" in
        "$integration" | release-please--*) ;;
        release/* | hotfix/*) REPLY="$REPLY $integration" ;;
        *) REPLY="$integration" ;;
    esac
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
  (modifier : git config repogarde.allowedBranches "main develop release/*")
Désactiver pour ce dépôt : git config repogarde.skip branch-name
EOF
}

# Vrai si l'élément est désactivé (repogarde.skip, git config ou .repogarde.conf).
# Valeurs : true|all, ou liste séparée par espaces/virgules parmi
# pre-commit prepare-commit-msg commit-msg pre-push post-checkout
# branch-name protect-branch secrets format tests, ou un langage (node, python…)
skipped() {
    local v
    cfg_r skip
    v="$REPLY"
    [ "$v" = true ] || [ "$v" = all ] && return 0
    case " ${v//,/ } " in *" $1 "*) return 0 ;; esac
    return 1
}

# Le hook entier est-il désactivé ? (à appeler en tête de hook)
exit_if_skipped() {
    if skipped "$HOOK_NAME"; then
        echo "ℹ $HOOK_NAME désactivé (git config repogarde.skip)."
        exit 0
    fi
}

# lefthook refuse de fonctionner (gros avertissement) quand core.hooksPath est
# défini globalement. Pour lui seul, on présente une copie de la config globale
# de l'utilisateur SANS core.hooksPath : il récupère ses remotes et installe ses
# hooks dans .git/hooks, sans jamais toucher au dossier repogarde global.
lefthook_without_global_hookspath() {
    local global cfg key value
    git config --global --get core.hooksPath >/dev/null 2>&1 || return 0
    global="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"
    cfg="$(git rev-parse --absolute-git-dir)/repogarde-lefthook.gitconfig"
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
# sa config (remote repogarde à la version figée + jobs du projet) même quand
# repogarde est installé globalement (core.hooksPath, que lefthook refuse).
delegate_to_lefthook() {
    local f
    [ -n "${REPOGARDE_RUNNER:-}" ] && return 0
    [ -n "$GIT_TOPLEVEL" ] || return 0
    for f in lefthook.yml lefthook.yaml .lefthook.yml .lefthook.yaml; do
        [ -f "$GIT_TOPLEVEL/$f" ] || continue
        if has lefthook; then
            export REPOGARDE_RUNNER=lefthook
            lefthook_without_global_hookspath
            exec lefthook run "$HOOK_NAME" "$@"
        fi
        warn "Projet lefthook ($f) mais lefthook absent : règles repogarde par défaut. Installe lefthook."
        return 0
    done
}

# Exécute les hooks propres au projet (.repogarde/<hook> ou .git/hooks/<hook>),
# ignorés par git dès que core.hooksPath pointe ici.
# Désactivé sous lefthook : .git/hooks contient ses propres hooks (boucle infinie)
# et les hooks du projet sont alors déclarés dans lefthook.yml.
run_local_hook() {
    local candidate real
    [ "${REPOGARDE_RUNNER:-}" = lefthook ] && return 0
    for candidate in ".repogarde/$HOOK_NAME" ".githooks/$HOOK_NAME" "$(git rev-parse --git-common-dir)/hooks/$HOOK_NAME"; do
        [ -x "$candidate" ] || continue
        [ "$candidate" = ".githooks/$HOOK_NAME" ] && deprecated ".githooks/" ".repogarde/"
        real="$(cd "$(dirname "$candidate")" && pwd -P)"
        [ "$real" = "$HOOKS_DIR" ] && continue
        echo "ℹ Hook local du projet : $candidate"
        "$candidate" "$@" || return $?
    done
}

# Chargement immédiat dans le processus qui source ce fichier : un appel $(cfg …)
# s'exécute dans un sous-shell et ne pourrait pas remplir le cache du parent.
cfg_load
