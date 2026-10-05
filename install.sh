#!/usr/bin/env bash
# Installe (ou retire) les hooks.
#   ./install.sh                    → active les hooks pour le dépôt courant
#   ./install.sh --global           → active les hooks pour tous les dépôts
#   ./install.sh --uninstall [--global]
set -euo pipefail

HOOKS="$(cd "$(dirname "$0")" && pwd -P)/hooks"
SCOPE="--local"
ACTION="install"

for arg in "$@"; do
    case "$arg" in
        --global) SCOPE="--global" ;;
        --uninstall) ACTION="uninstall" ;;
        -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
        *) echo "Argument inconnu : $arg" >&2; exit 1 ;;
    esac
done

if [ "$SCOPE" = --local ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "✖ Pas dans un dépôt git (utilise --global pour tous les dépôts)." >&2
    exit 1
fi

if [ "$ACTION" = uninstall ]; then
    git config "$SCOPE" --unset core.hooksPath || true
    echo "✔ Hooks désactivés ($SCOPE)."
    exit 0
fi

chmod +x "$HOOKS"/pre-commit "$HOOKS"/prepare-commit-msg "$HOOKS"/commit-msg "$HOOKS"/pre-push

CURRENT="$(git config "$SCOPE" --get core.hooksPath || true)"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "$HOOKS" ]; then
    echo "⚠ core.hooksPath ($SCOPE) valait '$CURRENT', remplacé."
fi

git config "$SCOPE" core.hooksPath "$HOOKS"
echo "✔ Hooks activés ($SCOPE) → $HOOKS"

if [ "$SCOPE" = --global ]; then
    echo "ℹ Un core.hooksPath local (ex. husky) reste prioritaire dans le dépôt concerné."
fi
