#!/usr/bin/env bash
# Docker : hadolint (Dockerfile), validation des fichiers Compose.
register docker "Dockerfile Containerfile *.Dockerfile compose.yaml compose.yml docker-compose.yaml docker-compose.yml" '(^|/)(Dockerfile|Containerfile)[^/]*$|\.Dockerfile$'

docker_test() {
    local f
    for f in Dockerfile* Containerfile *.Dockerfile; do
        [ -f "$f" ] || continue
        if has hadolint; then
            step "Docker : hadolint $f"
            hadolint "$f" || return 1
        else
            warn "Docker : hadolint absent, $f non vérifié."
        fi
    done
    for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
        [ -f "$f" ] || continue
        if docker compose version >/dev/null 2>&1; then
            step "Docker : compose config ($f)"
            # --no-interpolate : pas d'échec sur les variables d'environnement absentes
            docker compose -f "$f" config -q --no-interpolate || return 1
        else
            warn "Docker : docker compose absent, $f non vérifié."
        fi
    done
}
