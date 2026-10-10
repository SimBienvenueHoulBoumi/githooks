#!/usr/bin/env bats
# commit-msg + prepare-commit-msg

load helpers

setup() { setup_repo; initial_commit; }

@test "commit-msg : message conforme accepte" {
    git switch -q -c feat/x
    run git commit -q --allow-empty -m "fix: corrige un truc"
    [ "$status" -eq 0 ]
    [ "$(subject)" = "fix: corrige un truc" ]
}

@test "commit-msg : message invalide refuse avec l'aide" {
    git switch -q -c wip-x 2>/dev/null
    git config repowarden.skip "secrets branch-name"
    run git commit -q --allow-empty -m "n'importe quoi"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Message de commit invalide"* ]]
    [[ "$output" == *"nouvelle fonctionnalité"* ]]
}

@test "commit-msg : premiere ligne > 72 caracteres refusee" {
    git switch -q -c feat/x
    run git commit -q --allow-empty -m "fix: $(printf 'a%.0s' {1..80})"
    [ "$status" -ne 0 ]
    [[ "$output" == *"trop longue"* ]]
}

@test "prepare-commit-msg : prefixe deduit de la branche" {
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "ajoute le bean"
    [ "$(subject)" = "feat(bean): ajoute le bean" ]
}

@test "prepare-commit-msg : alias de branche (bugfix -> fix)" {
    git switch -q -c bugfix/timeout
    git commit -q --allow-empty -m "corrige"
    [ "$(subject)" = "fix(timeout): corrige" ]
}

@test "prepare-commit-msg : scope trop long omis" {
    git switch -q -c fix/un-sujet-vraiment-tres-long
    git commit -q --allow-empty -m "corrige"
    [ "$(subject)" = "fix: corrige" ]
}

@test "prepare-commit-msg : message deja conforme inchange" {
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "docs: readme"
    [ "$(subject)" = "docs: readme" ]
}

@test "prepare-commit-msg : amend sans double prefixe" {
    git switch -q -c feat/bean
    git commit -q --allow-empty -m "ajoute"
    GIT_EDITOR=true git commit -q --amend --allow-empty
    [ "$(subject)" = "feat(bean): ajoute" ]
}

@test "repowarden.skip true desactive tout" {
    git config repowarden.skip true
    run git commit -q --allow-empty -m "n'importe quoi"
    [ "$status" -eq 0 ]
}

@test "commit-msg : signatures d'agent IA retirees du message, identite d'agent refusee" {
    git switch -q -c feat/x
    run git commit -q --allow-empty -m "feat: ajoute un truc" -m "Pourquoi." \
        -m "Co-Authored-By: Claude Opus <noreply@anthropic.com>
🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-authored-by: Alice <alice@example.com>"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Signature d'agent IA retirée"* ]]
    msg="$(git log -1 --format=%B)"
    echo "message : $msg"
    [[ "$msg" != *anthropic* && "$msg" != *"Generated with"* ]]
    [[ "$msg" == *"Co-authored-by: Alice <alice@example.com>"* ]]
    # auteur agent : refuse
    GIT_AUTHOR_NAME=Claude GIT_AUTHOR_EMAIL=noreply@anthropic.com \
        run git commit -q --allow-empty -m "fix: autre"
    [ "$status" -ne 0 ]
    [[ "$output" == *"agent IA"* ]]
    # reglage : agents autorises
    git config repowarden.allowAgentSignatures true
    GIT_AUTHOR_NAME=Claude GIT_AUTHOR_EMAIL=noreply@anthropic.com \
        run git commit -q --allow-empty -m "fix: autorise" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
    [ "$status" -eq 0 ]
    [[ "$(git log -1 --format=%B)" == *anthropic* ]]
}
