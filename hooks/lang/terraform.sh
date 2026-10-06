#!/usr/bin/env bash
# Terraform / OpenTofu : fmt ; init (sans backend) + validate + tflint au push / en CI
register terraform "*.tf" '\.(tf|tfvars|tftest\.hcl)$' standalone

terraform_bin() { command -v terraform || command -v tofu || true; }

terraform_format() {
    local bin
    bin="$(terraform_bin)"
    [ -n "$bin" ] || { tool_missing "Terraform : terraform/tofu absent, formatage ignoré."; return 0; }
    step "Terraform : fmt"
    "$bin" fmt "$@" >/dev/null
}

terraform_test() {
    local bin
    bin="$(terraform_bin)"
    [ -n "$bin" ] || { warn "Terraform : terraform/tofu absent, validation ignorée."; return 0; }
    step "Terraform : init -backend=false + validate"
    "$bin" init -backend=false -input=false -no-color >/dev/null || return 1
    "$bin" validate -no-color || return 1
    if has tflint; then
        step "Terraform : tflint"
        tflint --init >/dev/null 2>&1
        tflint --no-color || return 1
    fi
}
