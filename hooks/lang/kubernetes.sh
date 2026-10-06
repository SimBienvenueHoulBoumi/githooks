#!/usr/bin/env bash
# Kubernetes (kustomize) : prettier sur les manifestes, rendu kustomize +
# validation des schémas (kubeconform, lu sur stdin : il ignore les fichiers
# sans extension .yaml) au push / en CI.
register kubernetes "kustomization.yaml kustomization.yml Kustomization" '\.ya?ml$'

kubernetes_format() { node_format "$@"; }

kubernetes_test() {
    local rendered rc=0
    rendered="$(mktemp)"
    if has kubectl; then
        step "Kubernetes : kubectl kustomize"
        kubectl kustomize . >"$rendered" || rc=1
    elif has kustomize; then
        step "Kubernetes : kustomize build"
        kustomize build . >"$rendered" || rc=1
    else
        warn "Kubernetes : ni kubectl ni kustomize, vérification ignorée."
        rm -f "$rendered"
        return 0
    fi
    if [ "$rc" = 0 ] && has kubeconform; then
        step "Kubernetes : kubeconform (schémas)"
        kubeconform -strict -summary -ignore-missing-schemas -cache "$(kubeconform_cache)" <"$rendered" || rc=1
    fi
    rm -f "$rendered"
    return "$rc"
}
