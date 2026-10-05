#!/usr/bin/env bats
# bats sous Windows ignore les tests dont le nom contient des caractères non ASCII

@test "noms de tests en ASCII (compatibilite bats Windows)" {
    run bash -c "grep -h '^@test' '$BATS_TEST_DIRNAME'/*.bats | LC_ALL=C grep -n '[^ -~]'"
    [ -z "$output" ] || { echo "Noms non ASCII :"; echo "$output"; return 1; }
}
