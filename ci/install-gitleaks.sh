#!/usr/bin/env bash
# Installe gitleaks (version figée, somme SHA-256 vérifiée) pour la CI.
#   ci/install-gitleaks.sh [version]     défaut : $GITLEAKS_VERSION ou 8.30.1
# Destination : $GITHOOKS_BIN (défaut ~/.local/bin), ajouté au PATH par ci/check.sh.
set -euo pipefail

VERSION="${1:-${GITLEAKS_VERSION:-8.30.1}}"
VERSION="${VERSION#v}"
BIN="${GITHOOKS_BIN:-$HOME/.local/bin}"

if command -v gitleaks >/dev/null 2>&1; then
    echo "ℹ gitleaks déjà présent : $(gitleaks version)"
    exit 0
fi

case "$(uname -s)" in
    Linux) os=linux ext=tar.gz ;;
    Darwin) os=darwin ext=tar.gz ;;
    MINGW* | MSYS* | CYGWIN*) os=windows ext=zip ;;
    *) echo "✖ Système non supporté : $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) echo "✖ Architecture non supportée : $(uname -m)" >&2; exit 1 ;;
esac

asset="gitleaks_${VERSION}_${os}_${arch}.${ext}"
base="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "▶ Téléchargement de $asset"
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/checksums.txt" "$base/gitleaks_${VERSION}_checksums.txt"

expected="$(grep " ${asset}\$" "$tmp/checksums.txt" | cut -d' ' -f1)"
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
else
    actual="$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)"
fi
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    echo "✖ Somme SHA-256 invalide pour $asset" >&2
    exit 1
fi

mkdir -p "$BIN"
if [ "$ext" = zip ]; then
    unzip -q -o "$tmp/$asset" -d "$tmp/out"
else
    mkdir -p "$tmp/out" && tar -xzf "$tmp/$asset" -C "$tmp/out"
fi
cp "$tmp/out/gitleaks"* "$BIN/"
chmod +x "$BIN/gitleaks"*
echo "✔ gitleaks $VERSION installé dans $BIN"
