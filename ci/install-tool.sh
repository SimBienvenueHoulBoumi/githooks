#!/usr/bin/env bash
# Installe un outil de vérification pour la CI : version figée, somme SHA-256 vérifiée.
#   ci/install-tool.sh gitleaks [version]     défaut : $GITLEAKS_VERSION ou 8.30.1
#   ci/install-tool.sh actionlint [version]   défaut : $ACTIONLINT_VERSION ou 1.7.12
#   ci/install-tool.sh pmd                    7.28.0 (Java, détection de code mort)
# Destination : $REPOWARDEN_BIN (défaut ~/.local/bin), ajouté au PATH par ci/check.sh.
# Outil déjà présent (image de runner pré-équipée) : rien n'est téléchargé.
# Empreintes SHA-256 figées ici pour les versions par défaut : un binaire
# modifié est refusé, même si sa source (ou son fichier de sommes) l'est aussi.
# Autre version : empreinte attendue en variable (GITLEAKS_SHA256, ACTIONLINT_SHA256).
# Miroir interne (Artifactory, Nexus… en proxy des releases GitHub) :
# REPOWARDEN_DOWNLOAD_MIRROR remplace https://github.com ; l'empreinte ne vient
# alors jamais du miroir (figée ici, ou fournie en variable, sinon refus).
set -euo pipefail
# shellcheck source=../hooks/lib/ui.sh
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib/ui.sh"
# shellcheck source=../hooks/lib/i18n.sh
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/lib/i18n.sh"

TOOL="${1:?usage : install-tool.sh gitleaks|actionlint|pmd [version]}"
BIN="${REPOWARDEN_BIN:-$HOME/.local/bin}"
MIRROR="${REPOWARDEN_DOWNLOAD_MIRROR:-}"
MIRROR="${MIRROR%/}"
SOURCE="${MIRROR:-https://github.com}"

if command -v "$TOOL" >/dev/null 2>&1; then
    info_t ci.install_tool.1 "$TOOL" "$(command -v "$TOOL")"
    exit 0
fi

# Empreintes des versions par défaut (fichiers de sommes officiels, recoupés
# avec les empreintes calculées par GitHub pour chaque fichier de release)
known_sha256() {
    case "$1" in
        gitleaks_8.30.1_darwin_arm64.tar.gz) echo b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
        gitleaks_8.30.1_darwin_x64.tar.gz) echo dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709 ;;
        gitleaks_8.30.1_linux_arm64.tar.gz) echo e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080 ;;
        gitleaks_8.30.1_linux_x64.tar.gz) echo 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
        gitleaks_8.30.1_windows_arm64.zip) echo b95f5e4f5c425cedca7ee203d9afd29597e692c4924a12ed42f970537c72cc0f ;;
        gitleaks_8.30.1_windows_x64.zip) echo d29144deff3a68aa93ced33dddf84b7fdc26070add4aa0f4513094c8332afc4e ;;
        actionlint_1.7.12_darwin_amd64.tar.gz) echo 5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644 ;;
        actionlint_1.7.12_darwin_arm64.tar.gz) echo aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f ;;
        actionlint_1.7.12_linux_amd64.tar.gz) echo 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 ;;
        actionlint_1.7.12_linux_arm64.tar.gz) echo 325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6 ;;
        actionlint_1.7.12_windows_amd64.zip) echo 6e7241b51e6817ea6a047693d8e6fed13b31819c9a0dd6c5a726e1592d22f6e9 ;;
        actionlint_1.7.12_windows_arm64.zip) echo cadcf7ea4efe3a68728893813643cebe1185e5b1d4be5b96245f65c9a4d5ea41 ;;
    esac
}

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
    curl -fsSL -o "$tmp/$asset" "$SOURCE/pmd/pmd/releases/download/pmd_releases%2F${version}/${asset}"
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
        base="$SOURCE/gitleaks/gitleaks/releases/download/v${version}"
        checksums="gitleaks_${version}_checksums.txt"
        ;;
    actionlint)
        version="${2:-${ACTIONLINT_VERSION:-1.7.12}}"
        version="${version#v}"
        asset="actionlint_${version}_${os}_${arch}.${ext}"
        base="$SOURCE/rhysd/actionlint/releases/download/v${version}"
        checksums="actionlint_${version}_checksums.txt"
        ;;
    *) err_t ci.install_tool.unknown "$TOOL"; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

step_t ci.install_tool.2 "$asset"
curl -fsSL -o "$tmp/$asset" "$base/$asset"

case "$TOOL" in
    gitleaks) expected="${GITLEAKS_SHA256:-}" ;;
    actionlint) expected="${ACTIONLINT_SHA256:-}" ;;
esac
[ -n "$expected" ] || expected="$(known_sha256 "$asset")"
if [ -z "$expected" ] && [ -n "$MIRROR" ]; then
    err_t ci.install_tool.sha_required "$asset" "$(echo "$TOOL" | tr '[:lower:]' '[:upper:]')_SHA256" >&2
    exit 1
fi
if [ -z "$expected" ]; then
    # Version non figée ici : fichier de sommes de la release officielle
    # (protège d'un fichier abîmé, pas d'une source compromise)
    curl -fsSL -o "$tmp/checksums.txt" "$base/$checksums"
    expected="$(grep " ${asset}\$" "$tmp/checksums.txt" | cut -d' ' -f1)"
fi
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
