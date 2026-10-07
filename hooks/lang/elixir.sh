#!/usr/bin/env bash
# Elixir (Phoenix…) : mix format, mix test
register elixir "mix.exs" '\.(ex|exs|heex)$'

elixir_format() {
    has mix || { tool_missing "Elixir : mix absent, formatage ignoré."; return 0; }
    step_t lang.elixir.1; mix format "$@"
}

elixir_test() {
    has mix || { warn "Elixir : mix absent, tests ignorés."; return 0; }
    step_t lang.elixir.2; mix test
}
