#!/usr/bin/env bash
# Java / Maven (Spring Boot, Quarkus…) : Spotless si configuré, mvn verify
register maven "pom.xml" '\.java$' outermost

maven_cmd() { if [ -x ./mvnw ]; then echo ./mvnw; else echo mvn; fi; }

maven_format() {
    grep -q spotless pom.xml || { tool_missing "Maven : Spotless non configuré dans pom.xml, formatage ignoré."; return 0; }
    step_t lang.maven.1
    # Nom complet du plugin : pas de résolution du préfixe « spotless: » sur un
    # index distant (un incident Maven Central faisait échouer le commit) ; la
    # version utilisée reste celle déclarée dans le pom.xml.
    "$(maven_cmd)" -q com.diffplug.spotless:spotless-maven-plugin:apply \
        -DspotlessFiles="$(printf '%s\n' "$@" | spotless_files_regex)"
}

maven_test() { step "Maven : $(maven_cmd) verify"; "$(maven_cmd)" -q verify; }

# Chemins relatifs (stdin) → liste de regex pour -DspotlessFiles.
# Spotless compare au chemin absolu : ".*[\\/]src[\\/]A\.java" (/ ou \ pour Windows).
# shellcheck disable=SC2016 # regex littérales
spotless_files_regex() {
    sed -e 's/[][\.*^$()+?{}|]/\\&/g' -e 's#/#[\\\\/]#g' -e 's#^#.*[\\\\/]#' | paste -sd, -
}

# Code mort prouvé (PMD) : voir hooks/lib/deadcode.sh
maven_deadcode() { java_deadcode; }
