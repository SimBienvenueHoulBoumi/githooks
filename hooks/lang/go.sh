#!/usr/bin/env bash
# Go : gofmt, go test
register go "go.mod" '\.go$' standalone

go_format() {
    has gofmt || { tool_missing "Go : gofmt absent, formatage ignoré."; return 0; }
    step_t lang.go.1
    gofmt -w "$@"
}

go_test() {
    has go || { warn "Go : go absent, tests ignorés."; return 0; }
    step_t lang.go.2
    go test ./...
}

# Code mort prouvé : identifiants non exportés jamais utilisés (staticcheck U1000)
go_deadcode() {
    has staticcheck || { deadcode_tool_missing Go staticcheck; return 0; }
    staticcheck -checks U1000 ./... 2>/dev/null |
        sed -nE 's/^(.+):([0-9]+):[0-9]+: (.*) \(U1000\)$/prouve\t\1\t\2\t\3/p'
}
