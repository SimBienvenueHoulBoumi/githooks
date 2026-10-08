#!/usr/bin/env bash
# Installe ou retire les hooks repogarde.
#   ./install.sh                       active les hooks pour le dépôt courant
#   ./install.sh --global              active les hooks pour tous les dépôts
#                                      (et l'assistant de commit : git cc)
#   ./install.sh --global --lang en    langue des messages (fr, en) ; demandée une fois sinon
#   ./install.sh --uninstall [--global]
#                                      retire les hooks (seulement s'ils sont ceux de repogarde)
#   ./install.sh --uninstall --global --purge [--scan DOSSIER]
#                                      retire aussi les caches et liste les dépôts
#                                      de DOSSIER encore branchés sur repogarde
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
HOOKS="$ROOT/hooks"
# shellcheck source=hooks/lib/ui.sh
source "$HOOKS/lib/ui.sh"
# shellcheck source=hooks/lib/i18n.sh
source "$HOOKS/lib/i18n.sh"
SCOPE="--local"
ACTION="install"
PURGE=""
SCAN=""
LANG_CHOICE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --global) SCOPE="--global" ;;
        --uninstall) ACTION="uninstall" ;;
        --purge) PURGE=1 ;;
        --lang)
            shift
            LANG_CHOICE="${1:-}"
            ;;
        --scan)
            shift
            SCAN="${1:?--scan attend un dossier}"
            ;;
        -h | --help)
            sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            t install.unknown_arg "$1"
            echo "$REPLY" >&2
            exit 1
            ;;
    esac
    shift
done

# Langue des messages : --lang, sinon question (une fois, dans un terminal)
# si aucune n'est encore choisie ; enregistrée dans la config git
choose_lang() {
    local current
    current="$(git config "$SCOPE" --get repogarde.lang 2>/dev/null || true)"
    if [ -z "$LANG_CHOICE" ] && [ -z "$current" ] && [ -t 0 ]; then
        printf '%s\n' "Langue des messages / Message language :" "  1) Français" "  2) English" >&2
        read -r -p "[$([ "$REPOGARDE_LANG" = fr ] && echo 1 || echo 2)] : " LANG_CHOICE || true
        case "${LANG_CHOICE:-}" in
            1 | fr*) LANG_CHOICE=fr ;;
            2 | en*) LANG_CHOICE=en ;;
            *) LANG_CHOICE="$REPOGARDE_LANG" ;;
        esac
    fi
    [ -n "$LANG_CHOICE" ] || return 0
    case "$LANG_CHOICE" in
        fr | en) ;;
        *) t install.lang_invalid; err "$REPLY"; exit 1 ;;
    esac
    git config "$SCOPE" repogarde.lang "$LANG_CHOICE"
    REPOGARDE_LANG="$LANG_CHOICE"
    t install.lang_set "$ROOT/install.sh"
    ok "$REPLY"
}

if [ "$SCOPE" = --local ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    t install.not_repo
    err "$REPLY"
    exit 1
fi

# Vrai si le chemin $1 désigne des hooks repogarde : ce dossier, ou un ancien
# emplacement disparu (dossier déplacé).
is_repogarde_hooks() {
    local path="$1"
    [ -n "$path" ] || return 1
    if [ -d "$path" ]; then
        [ "$(cd "$path" && pwd -P)" = "$HOOKS" ] && return 0
        [ -f "$path/lib/common.sh" ] && grep -qs repogarde "$path/lib/common.sh"
        return
    fi
    case "$path" in */repogarde/hooks) return 0 ;; esac
    return 1
}

# Alias « git cc » → assistant de commit, sans écraser un alias existant
ALIAS_VALUE="!bash \"$ROOT/bin/commit\""
install_alias() {
    local current
    current="$(git config "$1" --get alias.cc || true)"
    if [ -n "$current" ] && [[ "$current" != *"/bin/commit"* ]]; then
        t install.alias_taken "$current"
        attention "$REPLY"
        return 0
    fi
    git config "$1" alias.cc "$ALIAS_VALUE"
    t install.alias_ok
    ok "$REPLY"
}

uninstall_alias() {
    local current
    current="$(git config "$1" --get alias.cc || true)"
    if [[ "$current" == *"/bin/commit"* ]]; then
        git config "$1" --unset alias.cc
        t install.alias_removed "$1"
        ok "$REPLY"
    fi
}

uninstall_scope() {
    local current
    current="$(git config "$1" --get core.hooksPath || true)"
    if [ -z "$current" ]; then
        t install.nothing "$1"
        info "$REPLY"
    elif is_repogarde_hooks "$current"; then
        git config "$1" --unset core.hooksPath
        t install.removed "$1"
        ok "$REPLY"
    else
        # Un autre outil (husky…) : ne jamais le désactiver
        t install.foreign "$1" "$current"
        attention "$REPLY"
    fi
}

purge() {
    local cache dir repo path
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/repogarde"
    if [ -d "$cache" ]; then
        rm -rf -- "$cache"
        t install.cache_removed "$cache"
        ok "$REPLY"
    fi
    if [ -n "$SCAN" ]; then
        t install.scan "$SCAN"
        step "$REPLY"
        local found=0
        while IFS= read -r dir; do
            repo="$(dirname "$dir")"
            path="$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true)"
            if [ -n "$path" ]; then
                case "$path" in /*) ;; *) path="$repo/$path" ;; esac
                if is_repogarde_hooks "$path"; then
                    echo "  $repo  →  git -C \"$repo\" config --unset core.hooksPath"
                    found=1
                fi
            fi
            if grep -qs repogarde "$repo/lefthook.yml" "$repo/lefthook.yaml" "$repo/.lefthook.yml"; then
                echo "  $repo (lefthook)  →  cd \"$repo\" && lefthook uninstall"
                found=1
            fi
        done < <(find "$SCAN" -maxdepth 5 -name .git -type d -prune 2>/dev/null)
        t install.none
        [ "$found" = 1 ] || echo "  $REPLY"
    fi
}

if [ "$ACTION" = uninstall ]; then
    uninstall_scope "$SCOPE"
    uninstall_alias "$SCOPE"
    if [ -n "$PURGE" ]; then
        purge
        echo
        t install.last_step
        echo "$REPLY"
        # Paquet npm : le désinstaller ; clone : supprimer son dossier
        case "$ROOT" in
            */node_modules/*) echo "  npm uninstall -g $(sed -n 's/^  "name": *"\([^"]*\)".*/\1/p' "$ROOT/package.json")" ;;
            *) echo "  rm -rf \"$ROOT\"" ;;
        esac
    elif [ "$SCOPE" = --global ] && [[ "$ROOT" == */node_modules/* ]]; then
        # Paquet npm : hooks retirés, le paquet reste installé
        t install.npm_remove "npm uninstall -g $(sed -n 's/^  "name": *"\([^"]*\)".*/\1/p' "$ROOT/package.json")"
        dim "$REPLY"
    fi
    exit 0
fi

if [ -n "$PURGE$SCAN" ]; then
    t install.purge_needs_uninstall
    err "$REPLY"
    exit 1
fi

choose_lang

chmod +x "$ROOT/bin/commit" "$HOOKS"/pre-commit "$HOOKS"/prepare-commit-msg "$HOOKS"/commit-msg "$HOOKS"/pre-push "$HOOKS"/post-checkout "$HOOKS"/post-merge

CURRENT="$(git config "$SCOPE" --get core.hooksPath || true)"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "$HOOKS" ]; then
    t install.replaced "$SCOPE" "$CURRENT"
    attention "$REPLY"
fi

git config "$SCOPE" core.hooksPath "$HOOKS"
t install.enabled "$SCOPE" "$HOOKS"
ok "$REPLY"
install_alias "$SCOPE"

if [ "$SCOPE" = --global ]; then
    t install.local_wins
    info "$REPLY"
fi
