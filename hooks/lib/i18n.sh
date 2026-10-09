#!/usr/bin/env bash
# Langue des messages (fr, en) et traduction. Compatible bash 3.2, sans
# sous-processus.
#   Poste : REPOWARDEN_LANG, sinon repowarden.lang (git config : choisie à
#           l'installation, prioritaire), sinon lang de .repowarden.conf,
#           sinon la langue du système.
#   CI    : REPOWARDEN_LANG, sinon lang de .repowarden.conf, sinon anglais
#           (les logs sont lus par toute l'équipe).
# Une clé absente du catalogue de la langue retombe sur le français.
# shellcheck disable=SC2034 # REPOWARDEN_LANG utilisée par les scripts qui sourcent ce fichier

I18N_DIR="$(dirname "${BASH_SOURCE[0]}")/i18n"
# shellcheck source=i18n/fr.sh
source "$I18N_DIR/fr.sh"
# shellcheck source=i18n/en.sh
source "$I18N_DIR/en.sh"

# Valeur imposée par l'environnement, mémorisée avant toute résolution
[ -n "${REPOWARDEN_LANG_ENV+x}" ] || REPOWARDEN_LANG_ENV="${REPOWARDEN_LANG:-}"

i18n_init() {
    local lang="$REPOWARDEN_LANG_ENV"
    if [ -z "$lang" ]; then
        if declare -F cfg_r >/dev/null; then
            cfg_r lang ""
            lang="$REPLY"
        else
            # Scripts sans la configuration complète (ci/install-tool.sh…) :
            # git config, puis le .repowarden.conf du dépôt courant
            # (anciens noms repogarde.lang, .repogarde.conf : lus aussi en v4)
            lang="$(git config --get repowarden.lang 2>/dev/null ||
                git config --get repogarde.lang 2>/dev/null ||
                git config -f "$(git rev-parse --show-toplevel 2>/dev/null)/.repowarden.conf" --get repowarden.lang 2>/dev/null ||
                git config -f "$(git rev-parse --show-toplevel 2>/dev/null)/.repogarde.conf" --get repogarde.lang 2>/dev/null || true)"
        fi
    fi
    if [ -z "$lang" ]; then
        if [ -n "${CI:-}" ]; then
            lang=en
        else
            case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in fr* | FR*) lang=fr ;; *) lang=en ;; esac
        fi
    fi
    case "$lang" in fr* | FR*) REPOWARDEN_LANG=fr ;; *) REPOWARDEN_LANG=en ;; esac
}

# Traduction dans _T, sans toucher à REPLY (utilisé par les hooks pour
# transmettre des résultats entre fonctions)
_tr() {
    local key="$1"
    shift
    _M=""
    [ "${REPOWARDEN_LANG:-}" = en ] && _msg_en "$key"
    [ -n "$_M" ] || _msg_fr "$key"
    [ -n "$_M" ] || _M="$key"
    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059 # le format vient du catalogue
        printf -v _T "$_M" "$@"
    else
        _T="$_M"
    fi
}

# t <clé> [args] → REPLY (scripts interactifs : assistant, installation)
t() {
    _tr "$@"
    REPLY="$_T"
}

# Traduire et afficher en une fois, REPLY préservé : ok_t, info_t, step_t,
# err_t, attention_t, warn_t, dim_t, echo_t <clé> [args]
ok_t() { _tr "$@"; ok "$_T"; }
info_t() { _tr "$@"; info "$_T"; }
step_t() { _tr "$@"; step "$_T"; }
err_t() { _tr "$@"; err "$_T"; }
attention_t() { _tr "$@"; attention "$_T"; }
warn_t() { _tr "$@"; warn "$_T"; }
dim_t() { _tr "$@"; dim "$_T"; }
echo_t() { _tr "$@"; echo "$_T"; }

i18n_init
