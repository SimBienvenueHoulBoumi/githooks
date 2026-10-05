#!/usr/bin/env bash
# Détection du/des langage(s) du dépôt + commandes de formatage et de test associées.
# Sourcé par pre-commit et pre-push. Compatible bash 3.2 (macOS).
# Chaque outil absent est ignoré avec un avertissement, jamais bloquant.

warn() { echo "⚠ $*" >&2; }
step() { echo "▶ $*"; }
has() { command -v "$1" >/dev/null 2>&1; }

# Langages détectés à la racine (maven gradle node python go rust)
detect_languages() {
    local langs=""
    [ -f pom.xml ] && langs="$langs maven"
    { [ -f build.gradle ] || [ -f build.gradle.kts ]; } && langs="$langs gradle"
    [ -f package.json ] && langs="$langs node"
    { [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; } && langs="$langs python"
    [ -f go.mod ] && langs="$langs go"
    [ -f Cargo.toml ] && langs="$langs rust"
    echo "$langs"
}

mvn_cmd() { if [ -x ./mvnw ]; then echo ./mvnw; else echo mvn; fi; }
gradle_cmd() { if [ -x ./gradlew ]; then echo ./gradlew; else echo gradle; fi; }

# Fichiers stagés filtrés par regex d'extension (un par ligne)
staged_files() {
    git diff --cached --name-only --diff-filter=ACMR | grep -E "$1" || true
}

# Re-stage des fichiers reformatés (lus sur stdin)
restage() {
    while IFS= read -r f; do [ -n "$f" ] && git add -- "$f"; done
}

# --- Formatage (pre-commit) -------------------------------------------------

format_maven() {
    local files; files="$(staged_files '\.java$')"
    [ -z "$files" ] && return 0
    if ! grep -q spotless pom.xml; then warn "Maven : Spotless non configuré, formatage ignoré."; return 0; fi
    step "Maven : formatage (spotless:apply)"
    "$(mvn_cmd)" -q spotless:apply
    echo "$files" | restage
}

format_gradle() {
    local files; files="$(staged_files '\.(java|kt|kts)$')"
    [ -z "$files" ] && return 0
    if ! grep -qs spotless build.gradle build.gradle.kts; then warn "Gradle : Spotless non configuré, formatage ignoré."; return 0; fi
    step "Gradle : formatage (spotlessApply)"
    "$(gradle_cmd)" -q spotlessApply
    echo "$files" | restage
}

format_node() {
    local files; files="$(staged_files '\.(js|jsx|ts|tsx|mjs|cjs|json|css|scss|html|md|ya?ml)$')"
    [ -z "$files" ] && return 0
    if [ ! -x node_modules/.bin/prettier ]; then warn "Node : prettier absent de node_modules, formatage ignoré."; return 0; fi
    step "Node : formatage (prettier)"
    echo "$files" | tr '\n' '\0' | xargs -0 node_modules/.bin/prettier --write --ignore-unknown --log-level warn
    echo "$files" | restage
}

format_python() {
    local files; files="$(staged_files '\.py$')"
    [ -z "$files" ] && return 0
    if has ruff; then
        step "Python : formatage (ruff format)"
        echo "$files" | tr '\n' '\0' | xargs -0 ruff format -q
    elif has black; then
        step "Python : formatage (black)"
        echo "$files" | tr '\n' '\0' | xargs -0 black -q
    else
        warn "Python : ni ruff ni black installé, formatage ignoré."; return 0
    fi
    echo "$files" | restage
}

format_go() {
    local files; files="$(staged_files '\.go$')"
    [ -z "$files" ] && return 0
    if ! has gofmt; then warn "Go : gofmt absent, formatage ignoré."; return 0; fi
    step "Go : formatage (gofmt)"
    echo "$files" | tr '\n' '\0' | xargs -0 gofmt -w
    echo "$files" | restage
}

format_rust() {
    local files; files="$(staged_files '\.rs$')"
    [ -z "$files" ] && return 0
    if ! has cargo; then warn "Rust : cargo absent, formatage ignoré."; return 0; fi
    step "Rust : formatage (cargo fmt)"
    cargo fmt
    echo "$files" | restage
}

# --- Tests / build complet (pre-push) ---------------------------------------

test_maven() { step "Maven : $(mvn_cmd) verify"; "$(mvn_cmd)" -q verify; }

test_gradle() { step "Gradle : $(gradle_cmd) check"; "$(gradle_cmd)" -q check; }

test_node() {
    # Ignore le script "test" par défaut généré par npm init
    if ! node -e 'const t=(require("./package.json").scripts||{}).test; process.exit(t && !/no test specified/.test(t) ? 0 : 1)' 2>/dev/null; then
        warn "Node : pas de script \"test\", ignoré."; return 0
    fi
    step "Node : npm test"; npm test --silent
}

test_python() {
    if ! has pytest; then warn "Python : pytest absent, tests ignorés."; return 0; fi
    step "Python : pytest"
    local rc=0; pytest -q || rc=$?
    # 5 = aucun test collecté : pas une erreur
    [ "$rc" -eq 5 ] && { warn "Python : aucun test trouvé."; return 0; }
    return "$rc"
}

test_go() { step "Go : go test ./..."; go test ./...; }

test_rust() { step "Rust : cargo test"; cargo test --quiet; }
