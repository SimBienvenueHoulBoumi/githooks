#!/usr/bin/env bash
# Rust : rustfmt (fichiers stagés uniquement), cargo test
register rust "Cargo.toml" '\.rs$' standalone outermost

rust_format() {
    has rustfmt || { tool_missing "Rust : rustfmt absent, formatage ignoré."; return 0; }
    local edition
    edition="$(grep -hsE '^[[:space:]]*edition[[:space:]]*=' Cargo.toml ./*/Cargo.toml | grep -oE '20[0-9]{2}' | head -n1)"
    step "Rust : rustfmt"
    rustfmt --edition "${edition:-2021}" "$@"
}

rust_test() {
    has cargo || { warn "Rust : cargo absent, tests ignorés."; return 0; }
    step "Rust : cargo test"
    cargo test --quiet
}
