#!/usr/bin/env bash
# Versions d'après les Conventional Commits, sans fichier de version (mode tag) :
#   ci/version.sh next  [ref]   prochaine version X.Y.Z, ou rien s'il n'y a rien à publier
#   ci/version.sh notes [ref]   notes de version (Markdown)
# Depuis le tag vX.Y.Z le plus élevé (pas le plus proche : une branche
# d'intégration ne contient pas les merges tagués sur main).
#   type! ou BREAKING CHANGE → majeure ; feat → mineure ; fix, perf → correctif.
# Un commit « chore(release): vX.Y.Z » (PR de livraison mergée en squash) fixe la version.
# Première version : $INITIAL_VERSION (défaut 0.1.0).
set -euo pipefail

# Langue des notes : celle du projet (lang de .repogarde.conf), anglais par défaut en CI
# shellcheck source=../hooks/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib/common.sh"

cmd="${1:-next}"
ref="${2:-HEAD}"
scope='(\([a-z0-9._-]+\))?'
last="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | sed -n 1p)"
range="${last:+$last..}$ref"

next() {
    local subjects bump major minor patch announced
    subjects="$(git log --no-merges --format=%s "$range")"
    announced="$(grep -oE '^chore\(release\): v[0-9]+\.[0-9]+\.[0-9]+$' <<<"$subjects" |
        sed 's/.*: v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1 || true)"
    if [ -n "$announced" ]; then
        echo_t ci.version.1 >&2
        echo "$announced"
        return
    fi
    if grep -qE "^[a-z]+$scope!: " <<<"$subjects" ||
        grep -qE '^BREAKING[ -]CHANGE: ' <<<"$(git log --no-merges --format=%b "$range")"; then
        bump="major"
    elif grep -qE "^feat$scope: " <<<"$subjects"; then
        bump="minor"
    elif grep -qE "^(fix|perf)$scope: " <<<"$subjects"; then
        bump="patch"
    else
        echo_t ci.version.2 "${last:-le début}" >&2
        return 0
    fi
    if [ -z "$last" ]; then
        echo_t ci.version.3 >&2
        echo "${INITIAL_VERSION:-0.1.0}"
        return
    fi
    IFS=. read -r major minor patch <<<"${last#v}"
    major="${major:-0}" minor="${minor:-0}" patch="${patch:-0}"
    case "$bump" in
        major) major=$((major + 1)) minor=0 patch=0 ;;
        minor) minor=$((minor + 1)) patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac
    echo_t ci.version.4 "$bump" "${last:-aucun tag}" >&2
    echo "$major.$minor.$patch"
}

notes() {
    local tab=$'\t' commits breaking_body breaking s h
    commits="$(git log --no-merges --reverse --format="%s$tab%h" "$range")"
    breaking_body="$(git log --no-merges --format=%h -E --grep='^BREAKING[ -]CHANGE: ' "$range")"
    breaking=""
    while IFS="$tab" read -r s h; do
        [ -n "$s" ] || continue
        if grep -qE "^[a-z]+$scope!: " <<<"$s" || grep -qx "$h" <<<"$breaking_body"; then
            breaking="$breaking- $s ($h)"$'\n'
        fi
    done <<<"$commits"
    t ci.version.breaking
    [ -z "$breaking" ] || printf '### ⚠ %s\n\n%s\n' "$REPLY" "$breaking"
    t ci.version.features
    section "$REPLY" "^feat$scope!?: "
    t ci.version.fixes
    section "$REPLY" "^(fix|perf)$scope!?: "
    t ci.version.maintenance
    section "$REPLY" "^(build|ci|chore|docs|refactor|style|test|revert)$scope!?: "
    echo_t ci.version.5 "${last:-le début du projet}"
}

section() { # titre, motif sur le sujet
    local lines
    lines="$(grep -E "$2" <<<"$commits" | grep -vE '^chore\(release\): ' |
        sed -E "s/^(.*)$tab(.*)$/- \1 (\2)/" || true)"
    [ -z "$lines" ] || printf '### %s\n\n%s\n\n' "$1" "$lines"
}

case "$cmd" in
    next) next ;;
    notes) notes ;;
    *) echo_t ci.version.usage >&2; exit 2 ;;
esac
