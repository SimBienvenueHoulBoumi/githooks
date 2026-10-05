#!/usr/bin/env bash
# Terraform / OpenTofu : fmt (validate demande un init, non lancé)
register terraform "" '\.(tf|tfvars|tftest\.hcl)$' standalone

terraform_format() {
    local bin
    bin="$(command -v terraform || command -v tofu || true)"
    [ -n "$bin" ] || { tool_missing "Terraform : terraform/tofu absent, formatage ignoré."; return 0; }
    step "Terraform : fmt"
    "$bin" fmt "$@" >/dev/null
}
