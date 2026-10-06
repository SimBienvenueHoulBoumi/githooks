#!/usr/bin/env bash
# C / C++ / Objective-C (CMake, Meson) : clang-format si .clang-format existe, ctest / meson test
register cpp "CMakeLists.txt meson.build" '\.(c|h|cc|cpp|cxx|hh|hpp|hxx|m|mm)$' standalone outermost

cpp_format() {
    has clang-format || { tool_missing "C/C++ : clang-format absent, formatage ignoré."; return 0; }
    find_up .clang-format >/dev/null || find_up _clang-format >/dev/null ||
        { tool_missing "C/C++ : pas de .clang-format, formatage ignoré."; return 0; }
    step "C/C++ : clang-format"; clang-format -i --style=file "$@"
}

cpp_test() {
    # Recompile avant de tester : sinon les tests tournent sur l'ancien binaire
    if [ -f build/CTestTestfile.cmake ] && has ctest; then
        step "C/C++ : cmake --build + ctest"
        cmake --build build && ctest --test-dir build --output-on-failure
    elif [ -f builddir/build.ninja ] && has meson; then
        step "C/C++ : meson test"; meson test -C builddir
    else
        echo "ℹ C/C++ : pas de dossier de build configuré (build/ ou builddir/), tests ignorés."
    fi
}
