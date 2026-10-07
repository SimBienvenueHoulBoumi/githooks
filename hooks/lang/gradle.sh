#!/usr/bin/env bash
# Java / Kotlin / Gradle (Spring Boot, Android…) : Spotless si configuré
# (fichiers stagés uniquement), gradle check
register gradle "settings.gradle settings.gradle.kts build.gradle build.gradle.kts" '\.(java|kt|kts|groovy)$' outermost

gradle_cmd() { if [ -x ./gradlew ]; then echo ./gradlew; else echo gradle; fi; }

gradle_format() {
    # Spotless peut être déclaré à la racine, dans un sous-projet ou dans buildSrc
    find . -maxdepth 3 \( -name '*.gradle' -o -name '*.gradle.kts' \) -not -path '*/build/*' -print0 2>/dev/null |
        xargs -0 grep -qs spotless ||
        { tool_missing "Gradle : Spotless non configuré, formatage ignoré."; return 0; }
    # Fichiers ciblés uniquement (chemins absolus, au format Windows si besoin :
    # Gradle tourne sur Java) — plus rapide qu'un spotlessApply complet
    local f files=""
    for f in "$@"; do
        f="$PWD/$f"
        if has cygpath; then f="$(cygpath -m "$f")"; fi
        files="${files:+$files,}$f"
    done
    step_t lang.gradle.1
    "$(gradle_cmd)" -q spotlessApply -PspotlessIdeHook="$files"
}

gradle_test() { step "Gradle : $(gradle_cmd) check"; "$(gradle_cmd)" -q check; }
