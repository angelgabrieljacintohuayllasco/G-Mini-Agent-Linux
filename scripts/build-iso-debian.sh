#!/usr/bin/env bash
# Construye la ISO de G-Mini OS basada en Debian 13 (live-build).
#
# Uso (como root, en Debian o Ubuntu con el live-build de Debian):
#   scripts/build-iso-debian.sh --deb FILE [opciones]
#
# Opciones:
#   --deb FILE      g-mini-agent_<versión>_amd64.deb de la release
#   --keyring FILE  llavero de Debian para verificar el archivo al hacer el
#                   bootstrap (debian-archive-keyring.pgp de Debian 13); por
#                   defecto, el que traiga debootstrap en el sistema
#   --version VER   versión de G-Mini OS para el nombre del archivo
#                   (por defecto: dev-AAAAMMDD)
#   --out DIR       salida de la ISO (por defecto: out/iso)
#   --work DIR      directorio de trabajo (por defecto: /tmp/gmini-live-build)
#   -h, --help      muestra esta ayuda
#
# Ubuntu trae su propia variante antigua de live-build (3.0~a57), que no
# sirve para Debian 13: hay que instalar el paquete de Debian (lo hace el
# workflow; ver docs/building.md).
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

DEB=""
KEYRING=""
VERSION=""
OUT="${GMINI_LINUX_ROOT}/out/iso"
WORK="/tmp/gmini-live-build"

while (($#)); do
    case "$1" in
        --deb) DEB="$2"; shift 2 ;;
        --keyring) KEYRING="$2"; shift 2 ;;
        --version) VERSION="${2#v}"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --work) WORK="$2"; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
done

[[ -n "${DEB}" ]] || die "falta --deb"
[[ -f "${DEB}" ]] || die "no existe ${DEB}"
require_root
require_cmd lb debootstrap rsync dpkg-deb

lb_version="$(lb --version 2>/dev/null | head -n 1)"
case "${lb_version}" in
    3.0~a*) die "live-build ${lb_version} es la variante de Ubuntu; instala el paquete de Debian (docs/building.md)" ;;
esac

DEB="$(abspath "${DEB}")"
OUT="$(abspath "${OUT}")"
WORK="$(abspath "${WORK}")"
VERSION="${VERSION:-dev-$(date -u +%Y%m%d)}"
deb_name="$(dpkg-deb --field "${DEB}" Package)"

log "Preparando la configuración en ${WORK} (live-build ${lb_version})"
if [[ -d "${WORK}" ]]; then
    (cd -- "${WORK}" && lb clean --purge >/dev/null 2>&1) || true
    rm -rf -- "${WORK}"
fi
mkdir -p "${WORK}" "${OUT}"

rsync -a "${GMINI_LINUX_ROOT}/iso/debian/" "${WORK}/"
INCLUDES="${WORK}/config/includes.chroot_after_packages"
mkdir -p "${INCLUDES}"
rsync -a --ignore-existing "${GMINI_LINUX_ROOT}/iso/common/rootfs/" "${INCLUDES}/"

mkdir -p "${WORK}/config/packages.chroot"
cp -- "${DEB}" "${WORK}/config/packages.chroot/"
printf '# Añadido por build-iso-debian.sh\n%s\n' "${deb_name}" >"${WORK}/config/package-lists/g-mini-agent.list.chroot"

LB_CONFIG_ARGS=()
if [[ -n "${KEYRING}" ]]; then
    [[ -f "${KEYRING}" ]] || die "no existe el llavero ${KEYRING}"
    LB_CONFIG_ARGS+=(--debootstrap-options "--keyring=$(abspath "${KEYRING}")")
fi

cd -- "${WORK}"
export GMINI_OS_VERSION="${VERSION}"
log "lb config"
lb config "${LB_CONFIG_ARGS[@]}"
log "lb build (el registro completo queda en ${WORK}/build.log)"
lb build

mapfile -t isos < <(find "${WORK}" -maxdepth 1 -name '*.iso')
((${#isos[@]} == 1)) || die "live-build no dejó una ISO en ${WORK}"
ISO="${OUT}/g-mini-os-debian-${VERSION}-amd64.iso"
mv -f -- "${isos[0]}" "${ISO}"
check_asset_size "${ISO}"
emit_output iso "${ISO}" >/dev/null
log "ISO lista: ${ISO}"
