#!/usr/bin/env bash
# Fonctions communes à tous les hooks : désactivation par projet et chaînage
# des hooks propres au projet. Compatible bash 3.2 (macOS).

HOOK_NAME="$(basename "$0")"
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# Vrai si l'élément est désactivé pour ce dépôt via `git config hooks.skip`.
# Valeurs : true|all, ou liste séparée par espaces/virgules parmi
# pre-commit commit-msg pre-push protect-branch secrets format tests
skipped() {
    local v
    v="$(git config --get hooks.skip || true)"
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

# Exécute les hooks propres au projet (.githooks/<hook> ou .git/hooks/<hook>),
# ignorés par git dès que core.hooksPath pointe ici.
run_local_hook() {
    local candidate real
    for candidate in ".githooks/$HOOK_NAME" "$(git rev-parse --git-common-dir)/hooks/$HOOK_NAME"; do
        [ -x "$candidate" ] || continue
        real="$(cd "$(dirname "$candidate")" && pwd -P)"
        [ "$real" = "$HOOKS_DIR" ] && continue
        echo "ℹ Hook local du projet : $candidate"
        "$candidate" "$@" || return $?
    done
}
