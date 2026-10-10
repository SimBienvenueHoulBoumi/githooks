#!/usr/bin/env bats
# GitHub App des workflows (bin/app) : gh simulé, navigateur simulé (le clic
# « Create » de GitHub renvoie vers la page locale avec un code)

load helpers

APP="$BATS_TEST_DIRNAME/../bin/app"

setup() {
    require node
    require curl
    setup_repo
    initial_commit
    F="$BATS_TEST_TMPDIR/gh"
    mkdir -p "$F/bin"
    cat >"$F/bin/gh" <<'GH'
#!/usr/bin/env bash
# gh simulé : variables et secrets du dépôt dans $FAKE, journal dans $FAKE/log
echo "$*" >>"$FAKE/log"
case "$1 $2" in
    "repo view") echo moi/projet ;;
    "api users/moi") echo User ;;
    "variable get") cat "$FAKE/var.$3" 2>/dev/null || exit 1 ;;
    "variable set") n="$3"; while [ $# -gt 0 ]; do [ "$1" = --body ] && printf '%s' "$2" >"$FAKE/var.$n"; shift; done ;;
    "secret list") for f in "$FAKE"/secret.*; do [ -e "$f" ] && echo "${f##*/secret.}	2026-10-10"; done ;;
    "secret set") cat >"$FAKE/secret.$3" ;;
    "api -X")
        [ "$4" = "app-manifests/c0de/conversions" ] || exit 1
        printf '{"id":7,"slug":"repowarden-moi","client_id":"Iv1.abc","pem":"-----BEGIN RSA PRIVATE KEY-----\\nSECRET\\n-----END RSA PRIVATE KEY-----"}' ;;
    "api user/installations")
        [ -e "$FAKE/installee" ] && printf '42\n' ;;
    "api user/installations/42/repositories") echo moi/projet ;;
esac
exit 0
GH
    chmod +x "$F/bin/gh"
    # Navigateur : page locale → état lu dans le formulaire → retour de GitHub
    # avec le code ; page d'installation → App installée
    cat >"$F/bin/navigateur" <<'NAV'
#!/usr/bin/env bash
case "$1" in
    http://127.0.0.1:*)
        page="$(curl -s "$1")"
        echo "$page" >"$FAKE/page"
        etat="$(sed -n 's/.*state=\([0-9a-f]*\).*/\1/p' <<<"$page")"
        curl -s "${1%/}/fin?code=c0de&state=$etat" >/dev/null ;;
    */installations/new) touch "$FAKE/installee" ;;
esac
NAV
    chmod +x "$F/bin/navigateur"
    export PATH="$F/bin:$PATH" FAKE="$F" REPOWARDEN_OPEN="$F/bin/navigateur"
}

@test "app init : App creee (manifest, permissions minimales), identifiants ranges sans etre affiches, installee" {
    run "$APP" init
    [ "$status" -eq 0 ]
    # formulaire envoye a GitHub : compte personnel, manifest sans webhook ni administration
    grep -q 'action="https://github.com/settings/apps/new?state=' "$F/page"
    grep -q '&quot;hook_attributes&quot;:{&quot;url&quot;:&quot;https://github.com/moi/projet&quot;,&quot;active&quot;:false}' "$F/page"
    grep -q '&quot;pull_requests&quot;:&quot;write&quot;' "$F/page"
    ! grep -q 'administration' "$F/page"
    [ "$(cat "$F/var.REPOWARDEN_APP_CLIENT_ID")" = Iv1.abc ]
    [ "$(cat "$F/var.REPOWARDEN_APP_SLUG")" = repowarden-moi ]
    grep -q "BEGIN RSA PRIVATE KEY" "$F/secret.REPOWARDEN_APP_KEY"
    [[ "$output" != *SECRET* ]]
    [[ "$output" == *"repowarden-moi installée sur moi/projet"* ]]
}

@test "app init : relance -> rien de recree ; --administration -> permission demandee" {
    run "$APP" init
    [ "$status" -eq 0 ]
    : >"$F/log"
    run "$APP" init
    [ "$status" -eq 0 ]
    [[ "$output" == *"déjà configurée"* ]]
    ! grep -q "app-manifests" "$F/log"
    rm -f "$F"/var.* "$F"/secret.*
    run "$APP" init --administration
    grep -q '&quot;administration&quot;:&quot;write&quot;' "$F/page"
}

@test "app init : retour de GitHub avec un mauvais etat -> refuse, rien de range" {
    cat >"$F/bin/navigateur" <<'NAV'
#!/usr/bin/env bash
case "$1" in
    */installations/new) touch "$FAKE/installee"; exit 0 ;;
esac
curl -s "${1%/}/fin?code=c0de&state=faux" >/dev/null
curl -s "${1%/}/fin?code=c0de&state=$(sed -n 's/.*state=\([0-9a-f]*\).*/\1/p' <<<"$(curl -s "$1")")" >/dev/null
NAV
    run "$APP" init
    # le faux etat est ignore ; seul le bon retour est accepte
    [ "$(grep -c "app-manifests" "$F/log")" -eq 1 ]
}
