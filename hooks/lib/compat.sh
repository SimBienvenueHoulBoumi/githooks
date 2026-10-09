#!/usr/bin/env bash
# Anciens noms de repogarde (avant repowarden 4), encore lus pendant la v4 et
# retirés en v5. Chargé en premier (par ui.sh), sans sous-processus.
#   variables REPOGARDE_* → REPOWARDEN_* (la nouvelle l'emporte si les deux
#   sont définies) ; les clés repogarde.* et .repogarde.conf sont lues par
#   cfg_load (common.sh) ; .repogarde/<hook> par run_local_hook.
# Les noms rencontrés sont notés dans REPOWARDEN_OLD_NAMES, pour un seul
# avertissement par processus (compat_warn, une fois la langue connue).
# shellcheck disable=SC2034 # REPOWARDEN_OLD_NAMES lu par common.sh

REPOWARDEN_OLD_NAMES="${REPOWARDEN_OLD_NAMES:-}"

compat_note() {
    case " $REPOWARDEN_OLD_NAMES " in *" $1 "*) ;; *) REPOWARDEN_OLD_NAMES="${REPOWARDEN_OLD_NAMES:+$REPOWARDEN_OLD_NAMES }$1" ;; esac
}

for _ancienne in ${!REPOGARDE_*}; do
    _nouvelle="REPOWARDEN_${_ancienne#REPOGARDE_}"
    if [ -z "${!_nouvelle+x}" ]; then
        export "$_nouvelle=${!_ancienne}"
    fi
    compat_note "$_ancienne"
done
unset _ancienne _nouvelle
