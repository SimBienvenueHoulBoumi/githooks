#!/usr/bin/env bash
# Installe un outil de vérification pour la CI : version figée, somme SHA-256 vérifiée.
#   ci/install-tool.sh gitleaks [version]     défaut : $GITLEAKS_VERSION ou 8.30.1
#   ci/install-tool.sh actionlint [version]   défaut : $ACTIONLINT_VERSION ou 1.7.12
# Destination : $REPOGARDE_BIN (défaut ~/.local/bin), ajouté au PATH par ci/check.sh.
set -euo pipefail
# shellcheck source=../hooks/lib/ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib/ui.sh"

TOOL="${1:?usage : install-tool.sh gitleaks|actionlint [version]}"
BIN="${REPOGARDE_BIN:-${GITHOOKS_BIN:-$HOME/.local/bin}}" # GITHOOKS_BIN : ancien nom

if command -v "$TOOL" >/dev/null 2>&1; then
    info "$TOOL déjà présent : $(command -v "$TOOL")"
    exit 0
fi

case "$(uname -s)" in
    Linux) os=linux ext=tar.gz ;;
    Darwin) os=darwin ext=tar.gz ;;
    MINGW* | MSYS* | CYGWIN*) os=windows ext=zip ;;
    *) err "Système non supporté : $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) err "Architecture non supportée : $(uname -m)" >&2; exit 1 ;;
esac

case "$TOOL" in
    gitleaks)
        version="${2:-${GITLEAKS_VERSION:-8.30.1}}"
        version="${version#v}"
        [ "$arch" = amd64 ] && arch=x64 # nommage des releases gitleaks
        asset="gitleaks_${version}_${os}_${arch}.${ext}"
        base="https://github.com/gitleaks/gitleaks/releases/download/v${version}"
        checksums="gitleaks_${version}_checksums.txt"
        ;;
    actionlint)
        version="${2:-${ACTIONLINT_VERSION:-1.7.12}}"
        version="${version#v}"
        asset="actionlint_${version}_${os}_${arch}.${ext}"
        base="https://github.com/rhysd/actionlint/releases/download/v${version}"
        checksums="actionlint_${version}_checksums.txt"
        ;;
    *) err "Outil inconnu : $TOOL" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

step "Téléchargement de $asset"
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/checksums.txt" "$base/$checksums"

expected="$(grep " ${asset}\$" "$tmp/checksums.txt" | cut -d' ' -f1)"
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
else
    actual="$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)"
fi
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    err "Somme SHA-256 invalide pour $asset" >&2
    exit 1
fi

mkdir -p "$BIN" "$tmp/out"
if [ "$ext" = zip ]; then
    unzip -q -o "$tmp/$asset" -d "$tmp/out"
else
    tar -xzf "$tmp/$asset" -C "$tmp/out"
fi
cp "$tmp/out/$TOOL"* "$BIN/"
chmod +x "$BIN/$TOOL"*
ok "$TOOL $version installé dans $BIN"
