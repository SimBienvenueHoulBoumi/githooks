#!/usr/bin/env bash
# Corrige une PR GitHub avant les vérifications (entrée fix-pr de l'action) :
#   - mauvaise cible (flux integrationBranch) : PR reciblée, ou fermée si une PR
#     de la même branche vise déjà la bonne cible (doublon) ;
#   - titre non conforme (il devient le message du commit en squash) : remplacé
#     par le message du commit s'il est seul et conforme, sinon déduit de la branche.
# Les modifications faites avec GITHUB_TOKEN ne relancent pas la CI : les valeurs
# corrigées sont transmises aux vérifications du même run (GITHUB_ENV).
#
# Variables : GH_TOKEN, PR, HEAD (branche), BASE (cible), TITLE, HEAD_SHA
set -euo pipefail

REPOGARDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../hooks/lib/common.sh
source "$REPOGARDE_DIR/hooks/lib/common.sh"
cd "$(git rev-parse --show-toplevel)"

out() { echo "$1=${2//$'\n'/ }" >>"${GITHUB_ENV:-/dev/null}"; } # une ligne : pas d'injection
notice() { echo "::notice title=repogarde::$*"; }

# 1. Cible
target="$BASE"
pr_targets_r "$HEAD"
allowed="$REPLY"
if [ -n "$allowed" ] && [[ " $allowed " != *" $BASE "* ]]; then
    target="${allowed%% *}"
    dup="$(gh pr list --head "$HEAD" --base "$target" --state open --json number -q '.[0].number // empty')"
    if [ -n "$dup" ]; then
        gh pr close "$PR" --comment "Doublon de #$dup : ouverte vers \`$BASE\` au lieu de \`$target\`, fermée automatiquement (repogarde)."
        out REPOGARDE_PR_CLOSED true
        notice "PR #$PR fermée : doublon de #$dup (cible $target)"
        exit 0
    fi
    gh pr edit "$PR" --base "$target" >/dev/null
    git fetch -q origin "$target"
    out REPOGARDE_FIXED_TARGET "$target"
    out REPOGARDE_FIXED_BASE "$(git merge-base "$HEAD_SHA" "origin/$target")"
    notice "PR #$PR reciblée : $BASE → $target (flux $(cfg integrationBranch))"
fi

# 2. Titre
if header_valid "$TITLE"; then
    echo "✔ Titre conforme : $TITLE"
    exit 0
fi
git fetch -q origin "$target" 2>/dev/null || true
base_sha="$(git merge-base "$HEAD_SHA" "origin/$target" 2>/dev/null || true)"
new=""
if [ -n "$base_sha" ]; then
    subjects="$(git log --no-merges --format=%s "$base_sha..$HEAD_SHA")"
    if [ "$(grep -c . <<<"$subjects")" = 1 ] && header_valid "$subjects"; then
        new="$subjects"
    fi
fi
if [ -z "$new" ]; then
    suggest_pr_title_r "$HEAD"
    new="$REPLY"
fi
gh pr edit "$PR" --title "$new" >/dev/null
out REPOGARDE_FIXED_TITLE "$new"
notice "Titre « $TITLE » remplacé par « $new »"
