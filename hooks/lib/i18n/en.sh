#!/usr/bin/env bash
# English catalogue. A missing key falls back to French (fr.sh).
# printf formats: %s for arguments, %% for a literal "%".
_msg_en() {
    case "$1" in
        # Commit assistant (git cc)
        cc.title) REPLY="conventional commit" ;;
        cc.help) REPLY="Enter = suggested value in [brackets] · Ctrl+C to cancel" ;;
        cc.nothing_staged) REPLY="Nothing is staged: add your changes first (git add …)." ;;
        cc.step1) REPLY="Type of change" ;;
        cc.type.feat) REPLY="new feature" ;;
        cc.type.fix) REPLY="bug fix" ;;
        cc.type.docs) REPLY="documentation only" ;;
        cc.type.style) REPLY="formatting, no logic change" ;;
        cc.type.refactor) REPLY="restructuring without behaviour change" ;;
        cc.type.perf) REPLY="performance improvement" ;;
        cc.type.test) REPLY="adding or updating tests" ;;
        cc.type.build) REPLY="build, dependencies" ;;
        cc.type.ci) REPLY="continuous integration" ;;
        cc.type.chore) REPLY="other maintenance" ;;
        cc.type.revert) REPLY="reverting a commit" ;;
        cc.type_prompt) REPLY="Number or name [%s]: " ;;
        cc.type_invalid) REPLY="\"%s\": pick a number (1 to %s) or a name from the list." ;;
        cc.step2) REPLY="Scope (optional)" ;;
        cc.scope_hint) REPLY="Part of the project affected, e.g. api, auth, chart; Enter for none." ;;
        cc.scope_prompt_default) REPLY="Scope (\"-\" for none) [%s]: " ;;
        cc.scope_prompt) REPLY="Scope: " ;;
        cc.scope_invalid) REPLY="Scope: lowercase letters, digits, . _ - only." ;;
        cc.step3) REPLY="Breaking change?" ;;
        cc.first_commit) REPLY="First commit of the repository: nothing existing to break, question skipped." ;;
        cc.breaking_hint1) REPLY="Yes only if existing usage stops working for its users" ;;
        cc.breaking_hint2) REPLY="(API, configuration, format, command removed or changed). Major version." ;;
        cc.breaking_prompt) REPLY="Breaking? [y/N]: " ;;
        cc.breaking_note_hint) REPLY="What breaks and how to migrate (shown in the release notes)." ;;
        cc.breaking_note_prompt) REPLY="What changes: " ;;
        cc.breaking_note_invalid) REPLY="Describe the change (at least 10 characters); otherwise answer no to the previous question." ;;
        cc.step4) REPLY="Description" ;;
        cc.desc_hint) REPLY="Imperative mood, no initial capital or final period; %s characters max." ;;
        cc.desc_required) REPLY="The description is required." ;;
        cc.header_too_long) REPLY="Header too long: %s characters (72 max). Shorten the description." ;;
        cc.step5) REPLY="Details (optional)" ;;
        cc.body_hint) REPLY="Body: explain why, on several lines; empty line to finish." ;;
        cc.refs_prompt) REPLY="References (e.g. %s; Enter for none): " ;;
        cc.preview) REPLY="Message" ;;
        cc.confirm) REPLY="Commit? [Y/n]: " ;;
        cc.aborted) REPLY="Cancelled: nothing was committed." ;;
        cc.created) REPLY="Commit created." ;;
        cc.next_branch) REPLY="Next changes: on a branch, e.g. %s, then a %s." ;;
        cc.topic) REPLY="topic" ;;
        cc.next_push) REPLY="Push: %s" ;;
        # Installation
        install.unknown_arg) REPLY="Unknown argument: %s" ;;
        install.not_repo) REPLY="Not in a git repository (use --global for all repositories)." ;;
        install.alias_taken) REPLY="git cc alias already used ('%s'): commit assistant not installed." ;;
        install.alias_ok) REPLY="Commit assistant: git cc" ;;
        install.alias_removed) REPLY="git cc alias removed (%s)." ;;
        install.nothing) REPLY="No core.hooksPath (%s): nothing to remove." ;;
        install.removed) REPLY="repogarde hooks removed (%s)." ;;
        install.foreign) REPLY="core.hooksPath (%s) = '%s' is not repogarde: left untouched." ;;
        install.cache_removed) REPLY="Cache removed: %s" ;;
        install.scan) REPLY="Repositories under %s still using repogarde:" ;;
        install.none) REPLY="none" ;;
        install.last_step) REPLY="Last step, to run yourself if you no longer use repogarde:" ;;
        install.purge_needs_uninstall) REPLY="--purge and --scan go with --uninstall." ;;
        install.replaced) REPLY="core.hooksPath (%s) was '%s', replaced." ;;
        install.enabled) REPLY="Hooks enabled (%s) → %s" ;;
        install.local_wins) REPLY="A local core.hooksPath (e.g. husky) still takes precedence in that repository." ;;
        install.lang_set) REPLY="Message language: English (change: ./install.sh --global --lang fr)" ;;
        install.lang_invalid) REPLY="--lang: fr or en." ;;
        *) REPLY="" ;;
    esac
}
