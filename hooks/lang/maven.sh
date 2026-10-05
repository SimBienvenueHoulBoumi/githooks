#!/usr/bin/env bash
# Java / Maven (Spring Boot, Quarkus…) : Spotless si configuré, mvn verify
register maven "pom.xml" '\.java$' outermost

maven_cmd() { if [ -x ./mvnw ]; then echo ./mvnw; else echo mvn; fi; }

maven_format() {
    grep -q spotless pom.xml || { tool_missing "Maven : Spotless non configuré dans pom.xml, formatage ignoré."; return 0; }
    step "Maven : spotless:apply"
    "$(maven_cmd)" -q spotless:apply -DspotlessFiles="$(printf '%s\n' "$@" | spotless_files_regex)"
}

maven_test() { step "Maven : $(maven_cmd) verify"; "$(maven_cmd)" -q verify; }

# Chemins relatifs (stdin) → liste de regex pour -DspotlessFiles.
# Spotless compare au chemin absolu : ".*[\\/]src[\\/]A\.java" (/ ou \ pour Windows).
# shellcheck disable=SC2016 # regex littérales
spotless_files_regex() {
    sed -e 's/[][\.*^$()+?{}|]/\\&/g' -e 's#/#[\\\\/]#g' -e 's#^#.*[\\\\/]#' | paste -sd, -
}
