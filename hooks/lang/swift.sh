#!/usr/bin/env bash
# Swift (SwiftPM) : swift-format / SwiftFormat si une config existe, swift test
# Pas de style canonique en Swift : formatage seulement avec .swift-format ou .swiftformat
register swift "Package.swift" '\.swift$' standalone

swift_format() {
    if find_up .swift-format >/dev/null && swift format --version >/dev/null 2>&1; then
        step "Swift : swift format"; swift format --in-place "$@"
    elif find_up .swiftformat >/dev/null && has swiftformat; then
        step "Swift : swiftformat"; swiftformat --quiet "$@"
    else
        tool_missing "Swift : pas de .swift-format/.swiftformat (ou outil absent), formatage ignoré."
    fi
}

swift_test() {
    [ -d Tests ] || { echo "ℹ Swift : pas de dossier Tests/."; return 0; }
    has swift || { warn "Swift : swift absent, tests ignorés."; return 0; }
    step "Swift : swift test"; swift test
}
