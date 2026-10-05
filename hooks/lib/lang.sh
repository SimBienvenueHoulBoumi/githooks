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

plugin_get() { eval "printf '%s' \"\${PLUGIN_$2_$1:-}\""; }

plugin_has_flag() { [[ " $(plugin_get "$1" FLAGS) " == *" $2 "* ]]; }

# Plugins actifs (non désactivés via hooks.skip <nom>)
active_plugins() {
    local p out=""
    for p in $PLUGINS; do skipped "$p" || out="$out $p"; done
    echo "$out"
}

for _plugin in "$(dirname "${BASH_SOURCE[0]}")/../lang/"*.sh; do
    # shellcheck source=/dev/null
    source "$_plugin"
done
unset _plugin

# --- Détection ---------------------------------------------------------------

# Le dossier $1 contient-il un marqueur du plugin $2 ?
has_marker() {
    local m
    set -f
    for m in $(plugin_get "$2" MARKERS); do
        set +f
        compgen -G "$1/$m" >/dev/null && return 0
        set -f
    done
    set +f
    return 1
}

# Remonte depuis le dossier de $1 jusqu'à la racine ; affiche "<plugin> <dossier>"
# pour le premier dossier contenant un marqueur d'un des plugins $2.
nearest_project() {
    local dir p
    dir="$(dirname "$1")"
    while :; do
        for p in $2; do
            if has_marker "$dir" "$p"; then
                # multi-module : on build depuis le projet parent le plus haut
                if plugin_has_flag "$p" outermost; then
                    while [ "$dir" != . ] && has_marker "$(dirname "$dir")" "$p"; do
                        dir="$(dirname "$dir")"
                    done
                fi
                echo "$p $dir"
                return 0
            fi
        done
        [ "$dir" = . ] && return 1
        dir="$(dirname "$dir")"
    done
}

# Plugins dont l'extension correspond au fichier $1
plugins_for_file() {
    local p out=""
    for p in $(active_plugins); do
        [[ "$1" =~ $(plugin_get "$p" EXT) ]] && out="$out $p"
    done
    echo "$out"
}

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

# Outil absent : avertissement dans un projet, silence pour un fichier isolé
# (évite le bruit, ex. un README.md dans un projet Java sans prettier)
tool_missing() {
    [ -n "${STANDALONE:-}" ] || warn "$*"
    return 0
}

# --- Formatage (pre-commit) --------------------------------------------------

# Commande personnalisée : hooks.format reçoit les fichiers stagés en arguments
format_custom() {
    local cmd="$1"
    shift
    step "Formatage personnalisé : $cmd"
    sh -c "$cmd \"\$@\"" githooks-format "$@"
}

# Formate les fichiers stagés, chacun avec le langage de son projet le plus
# proche (monorepo), ou par extension s'il n'appartient à aucun projet (script).
format_staged() {
    local list f p d plugins found plugin dir groups key cmd standalone
    list="$(mktemp)"
    groups="$(mktemp)"
    git diff --cached --name-only --diff-filter=ACMR >"$list"
    [ -s "$list" ] || { rm -f "$list" "$groups"; return 0; }

    cmd="$(cfg format)"
    if [ -n "$cmd" ]; then
        local files=()
        while IFS= read -r f; do files+=("$f"); done <"$list"
        format_custom "$cmd" "${files[@]}" </dev/null || { rm -f "$list" "$groups"; return 1; }
        printf '%s\n' "${files[@]}" | restage
        rm -f "$list" "$groups"
        return 0
    fi

    # Regroupe : plugin <TAB> dossier <TAB> fichier
    while IFS= read -r f; do
        plugins="$(plugins_for_file "$f")"
        [ -z "${plugins// /}" ] && continue
        if found="$(nearest_project "$f" "$plugins")"; then
            plugin="${found%% *}"
            dir="${found#* }"
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
        (cd "$dir" && STANDALONE="$standalone" "${plugin}_format" "${rel[@]}") </dev/null
        printf '%s\n' "${abs[@]}" | restage
    done < <(cut -f1,2 "$groups" | sort -u)

    rm -f "$list" "$groups"
}

# Re-stage des fichiers reformatés (lus sur stdin, relatifs à la racine)
restage() {
    while IFS= read -r f; do [ -n "$f" ] && [ -e "$f" ] && git add -- "$f"; done
}

# --- Tests (pre-push) --------------------------------------------------------

# Projets touchés par les fichiers modifiés (stdin, relatifs à la racine) :
# affiche les dossiers uniques contenant au moins un marqueur.
projects_for_files() {
    local all="" p dir found
    for p in $(active_plugins); do
        [ -n "$(plugin_get "$p" MARKERS)" ] && all="$all $p"
    done
    awk '{ if (index($0, "/")) sub(/\/[^\/]*$/, ""); else $0 = "."; print }' | sort -u |
        while IFS= read -r dir; do
        found="$(nearest_project "$dir/x" "$all")" && echo "${found#* }"
    done | sort -u
}

# Lance les tests de chaque projet touché. Lecture des fichiers modifiés sur stdin.
test_projects() {
    local cmd dir p plugins key ran=0 rc=0
    cmd="$(cfg test)"
    if [ -n "$cmd" ]; then
        step "Tests personnalisés : $cmd"
        sh -c "$cmd" </dev/null
        return $?
    fi

    while IFS= read -r dir; do
        plugins=""
        for p in $(active_plugins); do
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
    return "$rc"
}
