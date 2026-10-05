#!/usr/bin/env bash
# Projets sans langage reconnu : cible "test" d'un Makefile, justfile ou Taskfile
register tasks "Makefile makefile GNUmakefile justfile Justfile .justfile Taskfile.yml Taskfile.yaml" '^$' fallback

tasks_test() {
    if compgen -G "[Mm]akefile" >/dev/null || [ -f GNUmakefile ]; then
        if has make && make -n test >/dev/null 2>&1; then step "make test"; make test; return; fi
    fi
    if compgen -G "*ustfile" >/dev/null || [ -f .justfile ]; then
        if has just && just --show test >/dev/null 2>&1; then step "just test"; just test; return; fi
    fi
    if compgen -G "Taskfile.y*ml" >/dev/null; then
        if has task && task --list-all 2>/dev/null | grep -q '^\* test:'; then step "task test"; task test; return; fi
    fi
    echo "ℹ Pas de cible \"test\" (make/just/task)."
}
