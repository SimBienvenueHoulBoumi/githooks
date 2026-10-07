#!/usr/bin/env bash
# Isolation du travail en cours pendant les hooks. Compatible bash 3.2 (macOS).
#   pre-commit : masque les modifications non stagées pendant le formatage,
#                pour ne formater/committer que ce qui est stagé.
#   pre-push   : teste le commit poussé, pas le dossier de travail.
# Principe : aucune perte possible, en cas de souci tout reste sauvegardé.

# --- pre-commit : masquer les modifications non stagées --------------------

UNSTAGED_PATCH=""
UNSTAGED_BACKUP=""

# Sauvegarde les modifications non stagées (fichiers suivis) : un patch pour les
# réappliquer sur la version formatée, et une copie brute des fichiers en secours.
# Puis remet le dossier de travail à l'état de l'index.
hide_unstaged() {
    git diff --quiet && return 0
    local gitdir f
    gitdir="$(git rev-parse --absolute-git-dir)"
    UNSTAGED_PATCH="$gitdir/repogarde-unstaged.patch"
    UNSTAGED_BACKUP="$gitdir/repogarde-backup"
    rm -rf "$UNSTAGED_BACKUP"
    mkdir -p "$UNSTAGED_BACKUP"
    git diff --binary >"$UNSTAGED_PATCH"
    git diff --name-only >"$UNSTAGED_BACKUP/.files"
    while IFS= read -r f; do
        [ -e "$f" ] || continue # suppression non stagée : rien à copier
        mkdir -p "$UNSTAGED_BACKUP/$(dirname "$f")"
        cp -p "$f" "$UNSTAGED_BACKUP/$f"
    done <"$UNSTAGED_BACKUP/.files"
    trap restore_unstaged EXIT INT TERM
    git checkout -q -- .
    info "Modifications non stagées mises de côté le temps du formatage."
}

# Réapplique les modifications non stagées sur la version formatée. Si le
# formatage touche les mêmes lignes, remet les fichiers exactement comme avant
# le hook : le commit est formaté, le dossier de travail ne perd rien.
restore_unstaged() {
    trap - EXIT INT TERM
    if [ -z "$UNSTAGED_PATCH" ] || [ ! -f "$UNSTAGED_PATCH" ]; then return 0; fi
    local f
    if ! git apply --whitespace=nowarn "$UNSTAGED_PATCH" 2>/dev/null; then
        while IFS= read -r f; do
            if [ -e "$UNSTAGED_BACKUP/$f" ]; then
                cp -p "$UNSTAGED_BACKUP/$f" "$f"
            else
                rm -f "$f"
            fi
        done <"$UNSTAGED_BACKUP/.files"
        warn "Formatage et modifications non stagées se chevauchent :"
        warn "le commit est formaté, ton dossier de travail est resté tel quel (non formaté)."
    fi
    rm -rf "$UNSTAGED_PATCH" "$UNSTAGED_BACKUP"
    UNSTAGED_PATCH=""
    UNSTAGED_BACKUP=""
}

# --- pre-push : tester exactement le commit poussé --------------------------

STASHED=""
WORKTREE=""

# Lance la commande "$@" sur le commit $1, sans tenir compte du dossier de travail.
#  - commit = HEAD : modifications en cours (y compris non suivies) mises en stash
#  - autre commit : worktree temporaire (node_modules lié pour éviter une réinstallation)
run_on_commit() {
    local sha="$1" rc=0
    shift
    if [ "$sha" = "$(git rev-parse HEAD)" ]; then
        if [ -n "$(git status --porcelain)" ]; then
            local before; before="$(git rev-parse -q --verify refs/stash || true)"
            git stash push -q --include-untracked -m "repogarde pre-push"
            [ "$(git rev-parse -q --verify refs/stash || true)" != "$before" ] && STASHED=1
            trap restore_stash EXIT INT TERM
            info "Modifications locales mises de côté : tests sur le commit poussé."
        fi
        "$@" || rc=$?
        restore_stash
    else
        WORKTREE="$(mktemp -d)"
        trap remove_worktree EXIT INT TERM
        git worktree add -q --detach "$WORKTREE" "$sha"
        [ -d node_modules ] && ln -s "$PWD/node_modules" "$WORKTREE/node_modules"
        info "Tests de ${sha:0:7} dans un worktree temporaire."
        (cd "$WORKTREE" && "$@") || rc=$?
        remove_worktree
    fi
    return "$rc"
}

restore_stash() {
    trap - EXIT INT TERM
    [ -n "$STASHED" ] || return 0
    STASHED=""
    if ! git stash pop -q --index; then
        warn "Impossible de restaurer automatiquement tes modifications."
        warn "Elles sont dans le stash : git stash list / git stash pop --index"
    fi
}

remove_worktree() {
    trap - EXIT INT TERM
    [ -n "$WORKTREE" ] || return 0
    git worktree remove --force "$WORKTREE" 2>/dev/null || rm -rf "$WORKTREE"
    git worktree prune
    WORKTREE=""
}
