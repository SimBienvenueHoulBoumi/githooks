#!/usr/bin/env bash
# Deno : deno fmt, deno test
register deno "deno.json deno.jsonc" '\.(ts|tsx|js|jsx|json|jsonc|md)$'

deno_format() {
    has deno || { tool_missing "Deno : deno absent, formatage ignoré."; return 0; }
    step_t lang.deno.1
    deno fmt --quiet "$@"
}

deno_test() {
    has deno || { warn "Deno : deno absent, tests ignorés."; return 0; }
    step_t lang.deno.2
    deno test --quiet
}
