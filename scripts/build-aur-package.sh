#!/usr/bin/env bash
# Prepara el PKGBUILD de g-mini-agent-bin para una release concreta y, si se
# pide, lo construye con makepkg.
#
# Uso:
#   scripts/build-aur-package.sh --version VER --appimage FILE [opciones]
#
# Opciones:
#   --version VER    versión de G-Mini Agent (obligatoria)
#   --appimage FILE  AppImage ya descargado y verificado (obligatorio)
#   --sha256 HASH    sha256 esperado; por defecto se calcula del AppImage
#   --pkgrel N       pkgrel (por defecto: 1)
#   --out DIR        salida (por defecto: out/aur)
#   --build          ejecuta makepkg y deja el .pkg.tar.zst en DIR
#   --repo DIR       además crea un repositorio local de pacman en DIR
#                    (lo usa build-iso-arch.sh)
#   -h, --help       muestra esta ayuda
#
# Siempre deja en DIR el PKGBUILD final y, si hay makepkg, el .SRCINFO.
# makepkg no se ejecuta como root: dentro de un contenedor se usa el usuario
# sin privilegios "builder" (se crea si no existe).
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

VERSION=""
APPIMAGE=""
SHA256=""
PKGREL=1
OUT="${GMINI_LINUX_ROOT}/out/aur"
BUILD=0
REPO=""

while (($#)); do
    case "$1" in
        --version) VERSION="${2#v}"; shift 2 ;;
        --appimage) APPIMAGE="$2"; shift 2 ;;
        --sha256) SHA256="$2"; shift 2 ;;
        --pkgrel) PKGREL="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --build) BUILD=1; shift ;;
        --repo) REPO="$2"; BUILD=1; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
done

[[ -n "${VERSION}" ]] || die "falta --version"
[[ -n "${APPIMAGE}" ]] || die "falta --appimage"
is_semver "${VERSION}" || die "versión no válida: ${VERSION}"
[[ "${PKGREL}" =~ ^[1-9][0-9]*$ ]] || die "pkgrel no válido: ${PKGREL}"
[[ -f "${APPIMAGE}" ]] || die "no existe ${APPIMAGE}"
require_cmd sha256sum sed

# pacman no admite guiones en pkgver: 0.4.0-beta.1 pasa a 0.4.0_beta.1.
PKGVER="${VERSION//-/_}"
SOURCE_NAME="G-Mini-Agent-${VERSION}.AppImage"
OUT="$(abspath "${OUT}")"
APPIMAGE="$(abspath "${APPIMAGE}")"

actual="$(sha256sum -- "${APPIMAGE}" | cut -d' ' -f1)"
if [[ -n "${SHA256}" && "${SHA256}" != "${actual}" ]]; then
    die "el AppImage no coincide con el sha256 esperado (${actual} != ${SHA256})"
fi
SHA256="${actual}"

log "PKGBUILD de g-mini-agent-bin ${PKGVER}-${PKGREL}"
rm -rf -- "${OUT}"
mkdir -p "${OUT}"
cp -- "${GMINI_LINUX_ROOT}/aur/PKGBUILD" "${GMINI_LINUX_ROOT}/aur/g-mini-agent-bin.install" "${OUT}/"

# El PKGBUILD arma el nombre del AppImage con pkgver; si la versión trae
# guiones, se fija el nombre real de la release.
sed -i \
    -e "s|^pkgver=.*|pkgver=${PKGVER}|" \
    -e "s|^pkgrel=.*|pkgrel=${PKGREL}|" \
    -e "s|^sha256sums_x86_64=.*|sha256sums_x86_64=('${SHA256}')|" \
    "${OUT}/PKGBUILD"
if [[ "${PKGVER}" != "${VERSION}" ]]; then
    sed -i \
        -e "s|^_appimage=.*|_appimage=\"${SOURCE_NAME}\"|" \
        -e "s|/releases/download/v\${pkgver}/|/releases/download/v${VERSION}/|" \
        "${OUT}/PKGBUILD"
fi

grep -q "^pkgver=${PKGVER}\$" "${OUT}/PKGBUILD" || die "no se pudo fijar pkgver"
grep -q "^sha256sums_x86_64=('${SHA256}')\$" "${OUT}/PKGBUILD" || die "no se pudo fijar el sha256"
info "sha256: ${SHA256}"

# makepkg usa el archivo local si ya está junto al PKGBUILD con el nombre de
# la fuente, así no vuelve a descargarlo.
cp -- "${APPIMAGE}" "${OUT}/${SOURCE_NAME}"

as_builder() {
    if ((EUID == 0)); then
        if ! id builder >/dev/null 2>&1; then
            useradd --system --create-home --shell /bin/bash builder
        fi
        chown -R builder: "${OUT}"
        runuser -u builder -- "$@"
    else
        "$@"
    fi
}

if command -v makepkg >/dev/null 2>&1; then
    (cd -- "${OUT}" && as_builder makepkg --printsrcinfo >.SRCINFO.tmp) && mv -f -- "${OUT}/.SRCINFO.tmp" "${OUT}/.SRCINFO"
    info ".SRCINFO generado"
elif ((BUILD)); then
    die "makepkg no está disponible: construye dentro de Arch Linux (contenedor archlinux)"
else
    warn "makepkg no está disponible: no se genera .SRCINFO"
fi

if ((BUILD)); then
    # --nodeps: las dependencias de ejecución (gtk3, mesa...) no hacen falta
    # para empaquetar; la única de build se comprueba aquí.
    require_cmd unsquashfs
    log "Construyendo con makepkg"
    (cd -- "${OUT}" && as_builder env PKGDEST="${OUT}" SRCDEST="${OUT}" makepkg --nodeps --cleanbuild --clean --force --noconfirm)
    mapfile -t packages < <(find "${OUT}" -maxdepth 1 -name "g-mini-agent-bin-${PKGVER}-${PKGREL}-x86_64.pkg.tar.*" ! -name '*.sig')
    ((${#packages[@]} == 1)) || die "makepkg no generó el paquete esperado"
    PACKAGE="${packages[0]}"
    info "paquete: $(basename -- "${PACKAGE}") ($(human_size "${PACKAGE}"))"

    if command -v namcap >/dev/null 2>&1; then
        log "namcap"
        namcap "${OUT}/PKGBUILD" || true
        namcap "${PACKAGE}" || true
    fi

    if [[ -n "${REPO}" ]]; then
        require_cmd repo-add
        REPO="$(abspath "${REPO}")"
        mkdir -p "${REPO}"
        cp -- "${PACKAGE}" "${REPO}/"
        repo-add --quiet "${REPO}/gmini.db.tar.gz" "${REPO}/$(basename -- "${PACKAGE}")"
        info "repositorio local: ${REPO} (gmini)"
    fi
    emit_output package "${PACKAGE}" >/dev/null
fi

rm -f -- "${OUT}/${SOURCE_NAME}"
emit_output pkgbuild "${OUT}/PKGBUILD" >/dev/null
log "Listo: ${OUT}"
