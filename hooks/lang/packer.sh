#!/usr/bin/env bash
# Packer : packer fmt ; validation syntaxique au push / en CI
register packer "*.pkr.hcl" '\.(pkr|pkrvars)\.hcl$' standalone

packer_format() {
    has packer || { tool_missing "Packer : packer absent, formatage ignoré."; return 0; }
    step "Packer : fmt"
    local f
    for f in "$@"; do packer fmt "$f" >/dev/null || return 1; done
}

packer_test() {
    has packer || { warn "Packer : packer absent, validation ignorée."; return 0; }
    step "Packer : validate -syntax-only"
    packer validate -syntax-only .
}
