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
