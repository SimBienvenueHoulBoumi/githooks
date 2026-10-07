#!/usr/bin/env bash
# Installe un outil de vérification pour la CI : version figée, somme SHA-256 vérifiée.
#   ci/install-tool.sh gitleaks [version]     défaut : $GITLEAKS_VERSION ou 8.30.1
#   ci/install-tool.sh actionlint [version]   défaut : $ACTIONLINT_VERSION ou 1.7.12
#   ci/install-tool.sh pmd                    7.28.0 (Java, détection de code mort)
# Destination : $REPOGARDE_BIN (défaut ~/.local/bin), ajouté au PATH par ci/check.sh.
set -euo pipefail
# shellcheck source=../hooks/lib/ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib/ui.sh"
# shellcheck source=../hooks/lib/i18n.sh
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib/i18n.sh"

TOOL="${1:?usage : install-tool.sh gitleaks|actionlint|pmd [version]}"
BIN="${REPOGARDE_BIN:-$HOME/.local/bin}"

if command -v "$TOOL" >/dev/null 2>&1; then
    info_t ci.install_tool.1 "$TOOL" "$(command -v "$TOOL")"
    exit 0
fi

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# PMD : archive Java unique pour toutes les plateformes ; pas de fichier de
# sommes publié (signature GPG seulement) : empreinte figée ici, relevée sur
# l'archive officielle de la release.
if [ "$TOOL" = pmd ]; then
    version=7.28.0
    expected=f974ba571f7bc01c73fffe11bade25fbc1f438698f9e9c00e416e8d65e9fbac2
    asset="pmd-dist-${version}-bin.zip"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    step_t ci.install_tool.2 "$asset"
    curl -fsSL -o "$tmp/$asset" "https://github.com/pmd/pmd/releases/download/pmd_releases%2F${version}/${asset}"
    if [ "$(sha256 "$tmp/$asset")" != "$expected" ]; then
        err_t ci.install_tool.3 "$asset"
        exit 1
    fi
    mkdir -p "$BIN"
    unzip -q -o "$tmp/$asset" -d "$BIN"
    ln -sf "$BIN/pmd-bin-${version}/bin/pmd" "$BIN/pmd"
    ok_t ci.install_tool.4 pmd "$version" "$BIN"
    exit 0
fi

case "$(uname -s)" in
    Linux) os=linux ext=tar.gz ;;
    Darwin) os=darwin ext=tar.gz ;;
    MINGW* | MSYS* | CYGWIN*) os=windows ext=zip ;;
    *) err_t ci.install_tool.os "$(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) err_t ci.install_tool.arch "$(uname -m)"; exit 1 ;;
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
    *) err_t ci.install_tool.unknown "$TOOL"; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

step_t ci.install_tool.2 "$asset"
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/checksums.txt" "$base/$checksums"

expected="$(grep " ${asset}\$" "$tmp/checksums.txt" | cut -d' ' -f1)"
actual="$(sha256 "$tmp/$asset")"
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    err_t ci.install_tool.3 "$asset" >&2
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
ok_t ci.install_tool.4 "$TOOL" "$version" "$BIN"
