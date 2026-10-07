#!/usr/bin/env bash
# Docker : hadolint (Dockerfile), validation des fichiers Compose.
register docker "Dockerfile Containerfile *.Dockerfile compose.yaml compose.yml docker-compose.yaml docker-compose.yml" '(^|/)(Dockerfile|Containerfile)[^/]*$|\.Dockerfile$'

docker_test() {
    local f
    for f in Dockerfile* Containerfile *.Dockerfile; do
        [ -f "$f" ] || continue
        if has hadolint; then
            step_t lang.docker.1 "$f"
            hadolint "$f" || return 1
        else
            warn_t lang.docker.2 "$f"
        fi
    done
    for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
        [ -f "$f" ] || continue
        if docker compose version >/dev/null 2>&1; then
            step_t lang.docker.3 "$f"
            # --no-interpolate : pas d'échec sur les variables d'environnement absentes
            docker compose -f "$f" config -q --no-interpolate || return 1
        else
            warn_t lang.docker.4 "$f"
        fi
    done
}
