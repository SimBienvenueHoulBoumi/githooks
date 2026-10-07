#!/usr/bin/env bash
# Ansible (playbooks, rôles, collections) : reformatage YAML par ansible-lint,
# règles ansible-lint vérifiées au push / en CI.
register ansible "ansible.cfg galaxy.yml requirements.yml .ansible-lint .ansible-lint.yml" '\.ya?ml$'

ansible_format() {
    has ansible-lint || { tool_missing "Ansible : ansible-lint absent, formatage ignoré."; return 0; }
    step_t lang.ansible.1
    # --fix=none : reformatage YAML seul ; les violations de règles sont
    # signalées par ansible_test (push / CI), pas au commit.
    ansible-lint -q --nocolor --fix=none "$@" >/dev/null 2>&1 || true
}

ansible_test() {
    has ansible-lint || { warn "Ansible : ansible-lint absent, vérification ignorée."; return 0; }
    step_t lang.ansible.2
    ansible-lint -q --nocolor
}
