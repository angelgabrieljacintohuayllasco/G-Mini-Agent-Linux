#!/usr/bin/env bash
# Construye la ISO de G-Mini OS basada en Arch Linux (archiso).
#
# Uso (como root, dentro de Arch Linux o de un contenedor archlinux
# privilegiado):
#   scripts/build-iso-arch.sh --package FILE [opciones]
#
# Opciones:
#   --package FILE   g-mini-agent-bin-*.pkg.tar.zst (scripts/build-aur-package.sh)
#   --pkgbuild DIR   carpeta con el PKGBUILD final de ese paquete (para que el
#                    instalador lo reconstruya); por defecto, la del paquete
#   --version VER    versión de G-Mini OS para el nombre del archivo
#                    (por defecto: fecha, como releng)
#   --out DIR        salida de la ISO (por defecto: out/iso)
#   --work DIR       directorio de trabajo (por defecto: /tmp/gmini-archiso)
#   -h, --help       muestra esta ayuda
#
# Monta una copia del perfil iso/archlinux con los archivos comunes de
# iso/common/rootfs, añade un repositorio local [gmini] con el paquete y
# ejecuta: mkarchiso -v -w WORK/work -o OUT WORK/profile
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

PACKAGE=""
PKGBUILD_DIR=""
VERSION=""
OUT="${GMINI_LINUX_ROOT}/out/iso"
WORK="/tmp/gmini-archiso"

while (($#)); do
    case "$1" in
        --package) PACKAGE="$2"; shift 2 ;;
        --pkgbuild) PKGBUILD_DIR="$2"; shift 2 ;;
        --version) VERSION="${2#v}"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --work) WORK="$2"; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
done

[[ -n "${PACKAGE}" ]] || die "falta --package"
[[ -f "${PACKAGE}" ]] || die "no existe ${PACKAGE}"
require_root
require_cmd mkarchiso repo-add pacman-conf rsync

PACKAGE="$(abspath "${PACKAGE}")"
PKGBUILD_DIR="$(abspath "${PKGBUILD_DIR:-$(dirname -- "${PACKAGE}")}")"
OUT="$(abspath "${OUT}")"
WORK="$(abspath "${WORK}")"
[[ -f "${PKGBUILD_DIR}/PKGBUILD" ]] || die "no hay PKGBUILD en ${PKGBUILD_DIR}"

PROFILE="${WORK}/profile"
REPO="${WORK}/repo"
log "Preparando el perfil en ${PROFILE}"
rm -rf -- "${WORK}"
mkdir -p "${PROFILE}" "${REPO}" "${OUT}"

# Perfil propio primero; los archivos comunes no pisan los específicos de Arch.
rsync -a "${GMINI_LINUX_ROOT}/iso/archlinux/" "${PROFILE}/"
rsync -a --ignore-existing "${GMINI_LINUX_ROOT}/iso/common/rootfs/" "${PROFILE}/airootfs/"

# El instalador (gmini-install) reconstruye el paquete con este PKGBUILD.
install -Dm644 "${PKGBUILD_DIR}/PKGBUILD" "${PROFILE}/airootfs/usr/local/share/gmini/aur/PKGBUILD"
install -Dm644 "${PKGBUILD_DIR}/g-mini-agent-bin.install" "${PROFILE}/airootfs/usr/local/share/gmini/aur/g-mini-agent-bin.install"

log "Repositorio local [gmini]"
cp -- "${PACKAGE}" "${REPO}/"
repo-add --quiet "${REPO}/gmini.db.tar.gz" "${REPO}/$(basename -- "${PACKAGE}")"
cat >>"${PROFILE}/pacman.conf" <<EOF

# Añadido por build-iso-arch.sh: G-Mini Agent construido desde el AppImage
# de la release (scripts/build-aur-package.sh).
[gmini]
SigLevel = Optional TrustAll
Server = file://${REPO}
EOF
printf '%s\n' g-mini-agent-bin >>"${PROFILE}/packages.x86_64"

if [[ -n "${VERSION}" ]]; then
    export GMINI_OS_VERSION="${VERSION}"
fi

log "mkarchiso"
touch "${WORK}/.started"
mkarchiso -v -w "${WORK}/work" -o "${OUT}" "${PROFILE}"

mapfile -t isos < <(find "${OUT}" -maxdepth 1 -name 'g-mini-os-arch-*.iso' -newer "${WORK}/.started")
((${#isos[@]} == 1)) || die "mkarchiso no dejó la ISO esperada en ${OUT}"
ISO="${isos[0]}"
check_asset_size "${ISO}"
emit_output iso "${ISO}" >/dev/null
log "ISO lista: ${ISO}"
