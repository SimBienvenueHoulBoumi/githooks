#!/usr/bin/env bash
# Scripts shell : shfmt (respecte .editorconfig, sinon indentation 4 espaces)
register shell "" '\.(sh|bash)$' standalone

shell_format() {
    has shfmt || { tool_missing "Shell : shfmt absent, formatage ignoré."; return 0; }
    step "Shell : shfmt"
    if find_up .editorconfig >/dev/null; then shfmt -w "$@"; else shfmt -w -i 4 -ci "$@"; fi
}
