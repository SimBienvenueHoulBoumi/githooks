#!/usr/bin/env bash
# Moteur multi-langages : détection par fichier, formatage, tests.
# Les langages sont des plugins dans hooks/lang/<nom>.sh. Compatible bash 3.2.
#
# Un plugin appelle :
#   register <nom> "<marqueurs>" "<regex extensions>" [standalone] [fallback]
#     marqueurs  : fichiers (globs acceptés) qui marquent la racine d'un projet
#     standalone : sait formater un fichier hors de tout projet (script seul)
#     fallback   : utilisé pour les tests seulement si aucun autre langage
#     outermost  : multi-module, remonte au projet le plus englobant (Maven, Gradle…)
# et définit (optionnel) :
#   <nom>_format fichier...   lancé dans le dossier du projet, chemins relatifs
#   <nom>_test                lancé dans le dossier du projet
# Un outil absent → warn + return 0 : jamais bloquant.

PLUGINS=""

register() {
    PLUGINS="$PLUGINS $1"
    eval "PLUGIN_MARKERS_$1=\$2 PLUGIN_EXT_$1=\$3 PLUGIN_FLAGS_$1=\"\${*:4}\""
}

# Les fonctions de détection sont appelées pour chaque fichier : elles évitent
# tout sous-processus ($(…), dirname, git) et renvoient leur résultat dans REPLY.

# REPLY = attribut $2 (MARKERS, EXT, FLAGS) du plugin $1
plugin_get() { eval "REPLY=\${PLUGIN_$2_$1:-}"; }

plugin_has_flag() {
    plugin_get "$1" FLAGS
    [[ " $REPLY " == *" $2 "* ]]
}

# Plugins actifs (non désactivés via repogarde.skip <nom>), calculés une seule fois
ACTIVE_PLUGINS=""
ACTIVE_PLUGINS_DONE=""
active_plugins_init() {
    local p
    [ -n "$ACTIVE_PLUGINS_DONE" ] && return 0
    for p in $PLUGINS; do skipped "$p" || ACTIVE_PLUGINS="$ACTIVE_PLUGINS $p"; done
    ACTIVE_PLUGINS_DONE=1
}
active_plugins() { active_plugins_init; echo "$ACTIVE_PLUGINS"; }

for _plugin in "$(dirname "${BASH_SOURCE[0]}")/../lang/"*.sh; do
    # shellcheck source=/dev/null
    source "$_plugin"
done
unset _plugin

# --- Détection ---------------------------------------------------------------

# Dossier parent sans sous-processus ("a/b" → "a", "a" → ".")
parent_dir() {
    case "$1" in
        */*) REPLY="${1%/*}" ;;
        *) REPLY=. ;;
    esac
}

# Le dossier $1 contient-il un marqueur du plugin $2 ?
has_marker() {
    local m markers
    plugin_get "$2" MARKERS
    markers="$REPLY"
    set -f
    for m in $markers; do
        set +f
        compgen -G "$1/$m" >/dev/null && return 0
        set -f
    done
    set +f
    return 1
}

# Mémo des résultats de nearest_project, par (dossier, plugins) : un gros commit
# touche beaucoup de fichiers dans peu de dossiers.
NEAREST_MEMO=$'\n'

# REPLY = "<plugin> <dossier>" du premier dossier, en remontant depuis le dossier
# de $1, qui contient un marqueur d'un des plugins $2 ; échec si aucun.
nearest_project_r() {
    local start dir p key hit up
    parent_dir "$1"
    start="$REPLY"
    key="$start|$2"
    case "$NEAREST_MEMO" in
        *$'\n'"$key="*)
            hit="${NEAREST_MEMO#*$'\n'"$key="}"
            REPLY="${hit%%$'\n'*}"
            [ -n "$REPLY" ]
            return
            ;;
    esac
    dir="$start"
    while :; do
        for p in $2; do
            if has_marker "$dir" "$p"; then
                # multi-module : on build depuis le projet parent le plus haut
                if plugin_has_flag "$p" outermost; then
                    while [ "$dir" != . ]; do
                        parent_dir "$dir"
                        up="$REPLY" # has_marker écrase REPLY
                        has_marker "$up" "$p" || break
                        dir="$up"
                    done
                fi
                NEAREST_MEMO="$NEAREST_MEMO$key=$p $dir"$'\n'
                REPLY="$p $dir"
                return 0
            fi
        done
        if [ "$dir" = . ]; then
            NEAREST_MEMO="$NEAREST_MEMO$key="$'\n'
            REPLY=""
            return 1
        fi
        parent_dir "$dir"
        dir="$REPLY"
    done
}

# Version affichée (tests, usage interactif)
nearest_project() { nearest_project_r "$@" && echo "$REPLY"; }

# REPLY = plugins actifs dont l'extension correspond au fichier $1
plugins_for_file_r() {
    local p out=""
    active_plugins_init
    for p in $ACTIVE_PLUGINS; do
        plugin_get "$p" EXT
        [[ "$1" =~ $REPLY ]] && out="$out $p"
    done
    REPLY="$out"
}

plugins_for_file() { plugins_for_file_r "$1"; echo "$REPLY"; }

# Cherche $1 depuis le dossier courant en remontant jusqu'à la racine du dépôt
# (lockfile ou node_modules hissés à la racine d'un monorepo, config de style…)
find_up() {
    local dir top
    dir="$(pwd -P)"
    # même format de chemin que $dir (Git Bash : /d/... et non D:/...)
    top="$(cd "$(git rev-parse --show-toplevel 2>/dev/null || echo /)" && pwd -P)"
    while :; do
        [ -e "${dir%/}/$1" ] && { echo "${dir%/}/$1"; return 0; }
        if [ "$dir" = "$top" ] || [ "$dir" = / ]; then return 1; fi
        dir="$(dirname "$dir")"
    done
}

# Cache des téléchargements entre deux lancements (schémas, providers)
REPOGARDE_CACHE="${REPOGARDE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/repogarde}"
cache_dir() { mkdir -p "$REPOGARDE_CACHE/$1" && echo "$REPOGARDE_CACHE/$1"; }
kubeconform_cache() { cache_dir kubeconform; }

# Outil absent : avertissement dans un projet, silence pour un fichier isolé
# (évite le bruit, ex. un README.md dans un projet Java sans prettier)
tool_missing() {
    [ -n "${STANDALONE:-}" ] || warn "$*"
    return 0
}

# Chemins exclus (repogarde.exclude) : globs séparés par des espaces, ex.
# "vendor/* generated/*" — code vendorisé, fichiers générés, fixtures de test.
EXCLUDE_PATTERNS=""
EXCLUDE_DONE=""
is_excluded() {
    local pat
    if [ -z "$EXCLUDE_DONE" ]; then
        cfg_r exclude
        EXCLUDE_PATTERNS="$REPLY"
        EXCLUDE_DONE=1
    fi
    [ -n "$EXCLUDE_PATTERNS" ] || return 1
    set -f
    for pat in $EXCLUDE_PATTERNS; do
        # shellcheck disable=SC2254
        case "$1" in $pat) set +f; return 0 ;; esac
    done
    set +f
    return 1
}

# Filtre stdin : retire les chemins exclus
without_excluded() {
    local f
    while IFS= read -r f; do is_excluded "$f" || printf '%s\n' "$f"; done
}

# --- Formatage (pre-commit) --------------------------------------------------

# Commande personnalisée : repogarde.format reçoit les fichiers stagés en arguments
format_custom() {
    local cmd="$1"
    shift
    step "Formatage personnalisé : $cmd"
    sh -c "$cmd \"\$@\"" repogarde-format "$@"
}

# Formate les fichiers stagés puis les re-stage (pre-commit)
format_staged() {
    git diff --cached --name-only --diff-filter=ACMR | format_files restage
}

# Formate les fichiers lus sur stdin (relatifs à la racine), chacun avec le
# langage de son projet le plus proche (monorepo), ou par extension s'il
# n'appartient à aucun projet (script). $1 = "restage" pour les re-stager.
format_files() {
    local mode="${1:-}" list f p d plugins plugin dir groups key cmd standalone failed=0
    list="$(mktemp)"
    groups="$(mktemp)"
    while IFS= read -r f; do [ -f "$f" ] && ! is_excluded "$f" && echo "$f"; done >"$list"
    [ -s "$list" ] || { rm -f "$list" "$groups"; return 0; }

    cmd="$(cfg format)"
    if [ -n "$cmd" ]; then
        local files=()
        while IFS= read -r f; do files+=("$f"); done <"$list"
        format_custom "$cmd" "${files[@]}" </dev/null || { rm -f "$list" "$groups"; return 1; }
        [ "$mode" = restage ] && printf '%s\n' "${files[@]}" | restage
        rm -f "$list" "$groups"
        return 0
    fi

    # Regroupe : plugin <TAB> dossier <TAB> fichier
    while IFS= read -r f; do
        plugins_for_file_r "$f"
        plugins="$REPLY"
        [ -z "${plugins// /}" ] && continue
        if nearest_project_r "$f" "$plugins"; then
            plugin="${REPLY%% *}"
            dir="${REPLY#* }"
        else
            plugin=""
            for p in $plugins; do
                plugin_has_flag "$p" standalone && { plugin="$p"; break; }
            done
            [ -z "$plugin" ] && continue
            dir=.
        fi
        printf '%s\t%s\t%s\n' "$plugin" "$dir" "$f" >>"$groups"
    done <"$list"

    while IFS="$(printf '\t')" read -r plugin dir; do
        local rel=() abs=()
        while IFS="$(printf '\t')" read -r p d f; do
            if [ "$p" != "$plugin" ] || [ "$d" != "$dir" ]; then continue; fi
            abs+=("$f")
            if [ "$dir" = . ]; then rel+=("$f"); else rel+=("${f#"$dir"/}"); fi
        done <"$groups"
        declare -F "${plugin}_format" >/dev/null || continue
        if [ "$dir" = . ]; then key="$plugin"; else key="$plugin ($dir)"; fi
        standalone=""
        has_marker "$dir" "$plugin" || standalone=1
        echo "ℹ $key : ${#rel[@]} fichier(s)"
        # Échec d'un formateur (ex. erreur de syntaxe) : signalé, jamais ignoré
        if ! (cd "$dir" && STANDALONE="$standalone" "${plugin}_format" "${rel[@]}") </dev/null; then
            echo "✖ Échec du formatage $key (erreur de syntaxe ?)." >&2
            failed=1
            continue
        fi
        if [ "$mode" = restage ]; then printf '%s\n' "${abs[@]}" | restage; fi
    done < <(cut -f1,2 "$groups" | sort -u)

    rm -f "$list" "$groups"
    return "$failed"
}

# Re-stage des fichiers reformatés (lus sur stdin, relatifs à la racine)
restage() {
    local f
    while IFS= read -r f; do [ -n "$f" ] && [ -e "$f" ] && printf '%s\0' "$f"; done |
        xargs -0 git add --
}

# --- Tests (pre-push) --------------------------------------------------------

# Projets touchés par les fichiers modifiés (stdin, relatifs à la racine) :
# affiche les dossiers uniques contenant au moins un marqueur.
projects_for_files() {
    local all="" p dir
    active_plugins_init
    for p in $ACTIVE_PLUGINS; do
        plugin_get "$p" MARKERS
        [ -n "$REPLY" ] && all="$all $p"
    done
    without_excluded |
        awk '{ if (index($0, "/")) sub(/\/[^\/]*$/, ""); else $0 = "."; print }' | sort -u |
        while IFS= read -r dir; do
            nearest_project_r "$dir/x" "$all" && echo "${REPLY#* }"
        done | sort -u
}

# Lance les tests de chaque projet touché. Lecture des fichiers modifiés sur stdin.
test_projects() {
    local cmd dir p plugins key ran=0
    cmd="$(cfg test)"
    if [ -n "$cmd" ]; then
        # Fichiers modifiés transmis sur l'entrée standard : la commande peut
        # choisir quoi tester (ex. ./scripts/check.sh --if-changed)
        step "Tests personnalisés : $cmd"
        sh -c "$cmd"
        return $?
    fi

    while IFS= read -r dir; do
        plugins=""
        active_plugins_init
        for p in $ACTIVE_PLUGINS; do
            has_marker "$dir" "$p" && plugins="$plugins $p"
        done
        # un plugin "fallback" (ex. make) seulement si rien d'autre
        local main=""
        for p in $plugins; do plugin_has_flag "$p" fallback || main="$main $p"; done
        [ -n "$main" ] && plugins="$main"
        for p in $plugins; do
            declare -F "${p}_test" >/dev/null || continue
            ran=1
            if [ "$dir" = . ]; then key="$p"; else key="$p ($dir)"; fi
            echo "ℹ Tests $key"
            if ! (cd "$dir" && "${p}_test") </dev/null; then
                echo "✖ Échec des tests $key : push refusé." >&2
                return 1
            fi
        done
    done < <(projects_for_files)

    [ "$ran" = 1 ] || echo "ℹ Aucun projet testable touché par ce push."
    return 0
}
