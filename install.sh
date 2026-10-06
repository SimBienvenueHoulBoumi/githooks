#!/usr/bin/env bash
# Installe ou retire les hooks repogarde.
#   ./install.sh                       active les hooks pour le dépôt courant
#   ./install.sh --global              active les hooks pour tous les dépôts
#   ./install.sh --uninstall [--global]
#                                      retire les hooks (seulement s'ils sont ceux de repogarde)
#   ./install.sh --uninstall --global --purge [--scan DOSSIER]
#                                      retire aussi les caches et liste les dépôts
#                                      de DOSSIER encore branchés sur repogarde
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
HOOKS="$ROOT/hooks"
SCOPE="--local"
ACTION="install"
PURGE=""
SCAN=""

while [ $# -gt 0 ]; do
    case "$1" in
        --global) SCOPE="--global" ;;
        --uninstall) ACTION="uninstall" ;;
        --purge) PURGE=1 ;;
        --scan)
            shift
            SCAN="${1:?--scan attend un dossier}"
            ;;
        -h | --help)
            sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Argument inconnu : $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$SCOPE" = --local ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "✖ Pas dans un dépôt git (utilise --global pour tous les dépôts)." >&2
    exit 1
fi

# Vrai si le chemin $1 désigne des hooks repogarde : ce dossier, ou un ancien
# emplacement disparu (dossier déplacé, ancien nom githooks).
is_repogarde_hooks() {
    local path="$1"
    [ -n "$path" ] || return 1
    if [ -d "$path" ]; then
        [ "$(cd "$path" && pwd -P)" = "$HOOKS" ] && return 0
        [ -f "$path/lib/common.sh" ] && grep -Eqs 'repogarde|githooks' "$path/lib/common.sh"
        return
    fi
    case "$path" in */repogarde/hooks | */githooks/hooks) return 0 ;; esac
    return 1
}

uninstall_scope() {
    local current
    current="$(git config "$1" --get core.hooksPath || true)"
    if [ -z "$current" ]; then
        echo "ℹ Aucun core.hooksPath ($1) : rien à retirer."
    elif is_repogarde_hooks "$current"; then
        git config "$1" --unset core.hooksPath
        echo "✔ Hooks repogarde retirés ($1)."
    else
        # Un autre outil (husky…) : ne jamais le désactiver
        echo "⚠ core.hooksPath ($1) = '$current' n'est pas repogarde : laissé intact." >&2
    fi
}

purge() {
    local cache dir repo path
    for cache in "${XDG_CACHE_HOME:-$HOME/.cache}/repogarde" "${XDG_CACHE_HOME:-$HOME/.cache}/githooks"; do
        if [ -d "$cache" ]; then
            rm -rf -- "$cache"
            echo "✔ Cache supprimé : $cache"
        fi
    done
    if [ -n "$SCAN" ]; then
        echo "▶ Dépôts de $SCAN encore branchés sur repogarde :"
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
            if grep -Eqs 'repogarde|githooks' "$repo/lefthook.yml" "$repo/lefthook.yaml" "$repo/.lefthook.yml"; then
                echo "  $repo (lefthook)  →  cd \"$repo\" && lefthook uninstall"
                found=1
            fi
        done < <(find "$SCAN" -maxdepth 5 -name .git -type d -prune 2>/dev/null)
        [ "$found" = 1 ] || echo "  aucun"
    fi
}

if [ "$ACTION" = uninstall ]; then
    uninstall_scope "$SCOPE"
    if [ -n "$PURGE" ]; then
        purge
        echo
        echo "Dernière étape, à lancer toi-même si tu n'utilises plus repogarde :"
        echo "  rm -rf \"$ROOT\""
    fi
    exit 0
fi

if [ -n "$PURGE$SCAN" ]; then
    echo "✖ --purge et --scan s'utilisent avec --uninstall." >&2
    exit 1
fi

chmod +x "$HOOKS"/pre-commit "$HOOKS"/prepare-commit-msg "$HOOKS"/commit-msg "$HOOKS"/pre-push "$HOOKS"/post-checkout "$HOOKS"/post-merge

CURRENT="$(git config "$SCOPE" --get core.hooksPath || true)"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "$HOOKS" ]; then
    echo "⚠ core.hooksPath ($SCOPE) valait '$CURRENT', remplacé."
fi

git config "$SCOPE" core.hooksPath "$HOOKS"
echo "✔ Hooks activés ($SCOPE) → $HOOKS"

if [ "$SCOPE" = --global ]; then
    echo "ℹ Un core.hooksPath local (ex. husky) reste prioritaire dans le dépôt concerné."
fi
