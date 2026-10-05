#!/usr/bin/env bash
# Deno : deno fmt, deno test
register deno "deno.json deno.jsonc" '\.(ts|tsx|js|jsx|json|jsonc|md)$'

deno_format() {
    has deno || { tool_missing "Deno : deno absent, formatage ignoré."; return 0; }
    step "Deno : deno fmt"
    deno fmt --quiet "$@"
}

deno_test() {
    has deno || { warn "Deno : deno absent, tests ignorés."; return 0; }
    step "Deno : deno test"
    deno test --quiet
}
