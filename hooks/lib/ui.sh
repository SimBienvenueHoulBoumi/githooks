#!/usr/bin/env bash
# Charte visuelle de repogarde : mêmes symboles et couleurs partout (hooks,
# CI, assistant, installation). Couleurs dans un terminal ou si FORCE_COLOR
# est défini (logs de CI) ; jamais avec NO_COLOR, TERM=dumb ou une sortie
# redirigée (fichiers, tubes, tests). Compatible bash 3.2.
# shellcheck disable=SC2034 # couleurs utilisées par les scripts qui sourcent ce fichier

if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ] &&
    { [ -n "${FORCE_COLOR:-}" ] || [ -t 2 ]; }; then
    UI_B=$'\033[1m' UI_D=$'\033[2m' UI_N=$'\033[0m'
    UI_G=$'\033[32m' UI_R=$'\033[31m' UI_Y=$'\033[33m' UI_BL=$'\033[34m' UI_C=$'\033[36m'
else
    UI_B="" UI_D="" UI_N="" UI_G="" UI_R="" UI_Y="" UI_BL="" UI_C=""
fi

ok() { echo "${UI_G}✔${UI_N} $*"; }
info() { echo "${UI_BL}ℹ${UI_N} $*"; }
step() { echo "${UI_C}▶${UI_N} ${UI_B}$*${UI_N}"; }
err() { echo "${UI_R}✖${UI_N} ${UI_B}$*${UI_N}" >&2; }
# Avertissement affiché seulement (warn, dans common.sh, compte aussi pour le mode strict)
attention() { echo "${UI_Y}⚠${UI_N} $*" >&2; }
# Texte secondaire (aides, détails)
dim() { echo "${UI_D}$*${UI_N}"; }
# En-tête de marque
brand() { echo "${UI_C}${UI_B}◆ repogarde${UI_N}${UI_D}${1:+ · $1}${UI_N}"; }
