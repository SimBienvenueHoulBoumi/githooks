#!/usr/bin/env bash
# Helm : helm lint + rendu (helm template) + schémas (kubeconform) + helm unittest.
# Les fichiers d'un chart sont des templates Go : JAMAIS de formatage YAML
# (prettier les casserait) — d'où l'absence de helm_format.
register helm "Chart.yaml" '\.(ya?ml|tpl|txt)$'

helm_test() {
    has helm || { warn "Helm : helm absent, vérification ignorée."; return 0; }
    local rendered rc=0
    if grep -qs '^dependencies:' Chart.yaml; then
        step_t lang.helm.1
        helm dependency build >/dev/null || return 1
    fi
    step_t lang.helm.2
    helm lint --quiet . || return 1
    rendered="$(mktemp)"
    helm template repowarden . >"$rendered" || { rm -f "$rendered"; return 1; }
    if has kubeconform; then
        step_t lang.helm.3
        kubeconform -strict -summary -ignore-missing-schemas -cache "$(kubeconform_cache)" <"$rendered" || rc=1
    fi
    rm -f "$rendered"
    [ "$rc" = 0 ] || return 1
    if [ -d tests ] && grep -q '^unittest' <<<"$(helm plugin list 2>/dev/null)"; then
        step_t lang.helm.4
        helm unittest .
    fi
}
