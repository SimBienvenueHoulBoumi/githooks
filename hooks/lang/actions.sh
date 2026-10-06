#!/usr/bin/env bash
# Workflows GitHub Actions : actionlint au push / en CI
register actions ".github/workflows" '^$'

actions_test() {
    has actionlint || { warn "GitHub Actions : actionlint absent, workflows non vérifiés."; return 0; }
    step "GitHub Actions : actionlint"
    actionlint
}
