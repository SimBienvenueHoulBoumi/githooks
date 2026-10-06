#!/usr/bin/env bats
# bats sous Windows ignore les tests dont le nom contient des caractères non ASCII

@test "noms de tests en ASCII (compatibilite bats Windows)" {
    run bash -c "grep -h '^@test' '$BATS_TEST_DIRNAME'/*.bats | LC_ALL=C grep -n '[^ -~]'"
    [ -z "$output" ] || { echo "Noms non ASCII :"; echo "$output"; return 1; }
}

@test "CI Windows : les filtres de languages.bats couvrent tous les tests" {
    command -v python3 >/dev/null || skip "python3 absent"
    run python3 - "$BATS_TEST_DIRNAME" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1]).parent
ci = (root / ".github/workflows/ci.yml").read_text()
filters = [re.compile(f) for f in re.findall(r"files: test/languages\.bats, filter: '([^']+)'", ci)]
names = re.findall(r'^@test "([^"]+)"', (root / "test/languages.bats").read_text(), re.M)
missing = [n for n in names if not any(f.search(n) for f in filters)]
print("\n".join(missing))
sys.exit(1 if missing or not filters else 0)
PY
    [ "$status" -eq 0 ] || { echo "Tests jamais lancés sous Windows :"; echo "$output"; return 1; }
}
