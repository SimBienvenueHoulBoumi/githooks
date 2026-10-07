#!/usr/bin/env bash
# Dart / Flutter : dart format, flutter test / dart test
register dart "pubspec.yaml" '\.dart$' standalone

dart_format() {
    has dart || { tool_missing "Dart : dart absent, formatage ignoré."; return 0; }
    step "Dart : dart format"
    dart format -o write "$@" >/dev/null
}

dart_test() {
    [ -d test ] || { info "Dart : pas de dossier test/."; return 0; }
    if grep -qs 'sdk: flutter' pubspec.yaml; then
        has flutter || { warn "Flutter : flutter absent, tests ignorés."; return 0; }
        step "Flutter : flutter test"; flutter test
    else
        has dart || { warn "Dart : dart absent, tests ignorés."; return 0; }
        step "Dart : dart test"; dart test
    fi
}
