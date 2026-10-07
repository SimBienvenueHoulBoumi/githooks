#!/usr/bin/env bash
# Langue des messages (fr, en) et traduction. Compatible bash 3.2, sans
# sous-processus : t <clé> [arguments printf] → REPLY.
#   Poste : REPOGARDE_LANG, sinon repogarde.lang (git config : choisie à
#           l'installation, prioritaire), sinon lang de .repogarde.conf,
#           sinon la langue du système.
#   CI    : REPOGARDE_LANG, sinon lang de .repogarde.conf, sinon anglais
#           (les logs sont lus par toute l'équipe).
# Une clé absente du catalogue de la langue retombe sur le français.
# shellcheck disable=SC2034 # REPOGARDE_LANG utilisée par les scripts qui sourcent ce fichier

I18N_DIR="$(dirname "${BASH_SOURCE[0]}")/i18n"
# shellcheck source=i18n/fr.sh
source "$I18N_DIR/fr.sh"
# shellcheck source=i18n/en.sh
source "$I18N_DIR/en.sh"

i18n_init() {
    local lang="${REPOGARDE_LANG:-}"
    if [ -z "$lang" ]; then
        if declare -F cfg_r >/dev/null; then
            cfg_r lang ""
            lang="$REPLY"
        else
            lang="$(git config --get repogarde.lang 2>/dev/null || true)"
        fi
    fi
    if [ -z "$lang" ]; then
        if [ -n "${CI:-}" ]; then
            lang=en
        else
            case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in fr* | FR*) lang=fr ;; *) lang=en ;; esac
        fi
    fi
    case "$lang" in fr* | FR*) REPOGARDE_LANG=fr ;; *) REPOGARDE_LANG=en ;; esac
}

t() {
    local key="$1"
    shift
    REPLY=""
    [ "$REPOGARDE_LANG" = en ] && _msg_en "$key"
    [ -n "$REPLY" ] || _msg_fr "$key"
    [ -n "$REPLY" ] || REPLY="$key"
    # shellcheck disable=SC2059 # le format vient du catalogue
    [ $# -eq 0 ] || printf -v REPLY "$REPLY" "$@"
}

i18n_init
