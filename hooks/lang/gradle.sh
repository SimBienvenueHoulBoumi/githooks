#!/usr/bin/env bash
# Java / Kotlin / Gradle (Spring Boot, Android…) : Spotless si configuré, gradle check
register gradle "settings.gradle settings.gradle.kts build.gradle build.gradle.kts" '\.(java|kt|kts|groovy)$' outermost

gradle_cmd() { if [ -x ./gradlew ]; then echo ./gradlew; else echo gradle; fi; }

gradle_format() {
    # Spotless peut être déclaré à la racine, dans un sous-projet ou dans buildSrc
    find . -maxdepth 3 \( -name '*.gradle' -o -name '*.gradle.kts' \) -not -path '*/build/*' -print0 2>/dev/null |
        xargs -0 grep -qs spotless ||
        { tool_missing "Gradle : Spotless non configuré, formatage ignoré."; return 0; }
    step "Gradle : spotlessApply"
    "$(gradle_cmd)" -q spotlessApply
}

gradle_test() { step "Gradle : $(gradle_cmd) check"; "$(gradle_cmd)" -q check; }
