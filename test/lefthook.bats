#!/usr/bin/env bats
# Intégration lefthook : config partagée (remote figé) et délégation depuis
# l'installation globale. Teste le dernier commit du dépôt repogarde.

load helpers

setup() {
    require lefthook
    # Dépôt repogarde "distant" : HEAD committé, publié sur une branche de test
    GH_REMOTE="$BATS_TEST_TMPDIR/repogarde.git"
    git init -q --bare "$GH_REMOTE"
    git -C "$BATS_TEST_DIRNAME/.." push -q --no-verify "$GH_REMOTE" HEAD:refs/heads/test/v1
    setup_repo
    # lefthook est un binaire Windows natif : chemin D:/... et non /d/...
    local url="$GH_REMOTE"
    if command -v cygpath >/dev/null 2>&1; then url="$(cygpath -m "$GH_REMOTE")"; fi
    cat >lefthook.yml <<EOF
remotes:
  - git_url: $url
    ref: test/v1
    configs:
      - lefthook-remote.yml
pre-commit:
  commands:
    projet:
      run: echo JOB-DU-PROJET
EOF
}

# Simule une installation globale de repogarde (core.hooksPath dans la config globale)
global_install() {
    git config --unset core.hooksPath
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global.gitconfig"
    git config --global core.hooksPath "$HOOKS"
    git config --global user.name test
    git config --global user.email test@example.com
}

@test "lefthook install : regles repogarde appliquees via le remote" {
    # poste "propre" : pas d'installation repogarde globale
    git config --unset core.hooksPath
    export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/empty.gitconfig"
    touch "$GIT_CONFIG_GLOBAL"
    run lefthook install
    [ "$status" -eq 0 ]
    initial_commit
    git switch -q -c Mauvais 2>/dev/null
    run git commit -q --allow-empty -m "feat: x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nom de branche non conforme"* ]]
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "ajoute"
    [ "$(subject)" = "feat(bean): ajoute" ]
}

@test "delegation : hooks repogarde globaux -> lefthook du projet" {
    global_install
    git add lefthook.yml # un fichier stagé : lefthook ignore les jobs sur un commit vide
    run git commit -q -m "chore: init"
    [ "$status" -eq 0 ]
    [[ "$output" == *"JOB-DU-PROJET"* ]]
    [[ "$output" != *"Custom hooks paths are not supported"* ]]
    git switch -q -c Mauvais 2>/dev/null
    run git commit -q --allow-empty -m "feat: x"
    [ "$status" -ne 0 ]
}

@test "delegation : pas de boucle avec les hooks lefthook de .git/hooks" {
    global_install
    run git commit -q --allow-empty -m "chore: init"
    [ "$status" -eq 0 ]
    # lefthook a installé ses hooks dans .git/hooks : repogarde ne doit pas les rappeler
    [ -f .git/hooks/pre-commit ]
    git switch -q -c feat/x
    run git commit -q --allow-empty -m "ajoute"
    [ "$status" -eq 0 ]
    [ "$(subject)" = "feat(x): ajoute" ]
}
