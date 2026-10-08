#!/usr/bin/env bash
# Comprobaciones en seco de los perfiles de las ISO y del PKGBUILD. No
# necesita root ni red: corre en Windows (Git Bash), WSL o CI.
#
# Uso: scripts/check-profiles.sh
#
# - Sintaxis de todos los scripts (bash -n / sh -n) y de los .py.
# - profiledef.sh: variables obligatorias y que cada ruta de file_permissions
#   exista en el perfil o en iso/common/rootfs.
# - Listas de paquetes: nombres válidos y sin duplicados.
# - Bit de ejecución en git para todo lo que se ejecuta dentro de las ISO
#   (desde Windows git no lo deduce del sistema de archivos).
# - Sin enlaces simbólicos ni finales de línea CRLF en los perfiles.
# - Menús de arranque: las imágenes que citan existen.
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

cd -- "${GMINI_LINUX_ROOT}"
ERRORS=0
fail() {
    printf '  FALLO: %s\n' "$*" >&2
    ERRORS=$((ERRORS + 1))
}

ARCH=iso/archlinux
DEBIAN=iso/debian
COMMON=iso/common/rootfs

# Todo lo que se ejecuta: scripts del repo y de las ISO.
mapfile -t EXECUTABLES < <(
    {
        find scripts -type f -name '*.sh'
        find "${COMMON}/usr/local/bin" "${ARCH}/airootfs/usr/local/bin" \
            "${DEBIAN}/config/includes.chroot_after_packages/usr/local/bin" -type f
        find "${ARCH}/airootfs/usr/local/lib/gmini" -type f
        find "${DEBIAN}/auto" "${DEBIAN}/config/hooks" -type f
        echo "${DEBIAN}/config/includes.chroot_after_packages/usr/lib/live/config/1175-gmini"
        echo "${ARCH}/profiledef.sh"
    } | sort
)

log "Sintaxis de ${#EXECUTABLES[@]} scripts"
for file in "${EXECUTABLES[@]}"; do
    case "$(head -n 1 "${file}")" in
        *python*)
            python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "${file}" ||
                fail "sintaxis Python: ${file}"
            ;;
        *bash*)
            bash -n "${file}" || fail "sintaxis bash: ${file}"
            ;;
        *)
            if command -v dash >/dev/null 2>&1; then
                dash -n "${file}" || fail "sintaxis sh: ${file}"
            else
                bash -n --posix "${file}" || fail "sintaxis sh: ${file}"
            fi
            ;;
    esac
done
bash -n aur/PKGBUILD || fail "sintaxis: aur/PKGBUILD"
bash -n aur/g-mini-agent-bin.install || fail "sintaxis: aur/g-mini-agent-bin.install"

log "Bit de ejecución en git"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for file in "${EXECUTABLES[@]}"; do
        mode="$(git ls-files -s -- "${file}" | cut -d' ' -f1)"
        if [[ -z "${mode}" ]]; then
            fail "no está en git: ${file}"
        elif [[ "${mode}" != 100755 && "${file}" != scripts/lib/* && "${file}" != */profiledef.sh ]]; then
            fail "sin bit de ejecución en git (git update-index --chmod=+x): ${file}"
        fi
    done
else
    warn "no es un repositorio git: se omite"
fi

log "profiledef.sh"
(
    # mkarchiso declara estos arrays antes de leer el perfil.
    declare -A file_permissions=()
    declare -a bootmodes=()
    # shellcheck disable=SC1091
    source "${ARCH}/profiledef.sh"
    for var in iso_name iso_label iso_publisher iso_application iso_version install_dir pacman_conf airootfs_image_type; do
        [[ -n "${!var:-}" ]] || { echo "  FALLO: profiledef.sh no define ${var}" >&2; exit 1; }
    done
    # shellcheck disable=SC2154  # iso_label la define profiledef.sh
    ((${#iso_label} <= 32)) || { echo "  FALLO: iso_label supera 32 caracteres" >&2; exit 1; }
    for mode in "${bootmodes[@]}"; do
        case "${mode}" in
            bios.syslinux | uefi.grub | uefi.systemd-boot) ;;
            *) echo "  FALLO: bootmode desconocido: ${mode}" >&2; exit 1 ;;
        esac
    done
    for path in "${!file_permissions[@]}"; do
        if [[ ! -e "${ARCH}/airootfs${path%/}" && ! -e "${COMMON}${path%/}" ]]; then
            echo "  FALLO: file_permissions apunta a ${path}, que no existe en el perfil" >&2
            exit 1
        fi
    done
) || ERRORS=$((ERRORS + 1))

check_package_list() {
    local file="$1"
    local -a names
    mapfile -t names < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "${file}" | grep -v '^$')
    ((${#names[@]} > 0)) || fail "${file} está vacía"
    local dup
    dup="$(printf '%s\n' "${names[@]}" | sort | uniq -d)"
    [[ -z "${dup}" ]] || fail "${file}: duplicados: ${dup//$'\n'/, }"
    local name
    for name in "${names[@]}"; do
        [[ "${name}" =~ ^[a-z0-9@._+-]+$ ]] || fail "${file}: nombre no válido: '${name}'"
    done
    info "${file}: ${#names[@]} paquetes"
}

log "Listas de paquetes"
check_package_list "${ARCH}/packages.x86_64"
check_package_list "${ARCH}/airootfs/usr/local/share/gmini/arch/install-packages.txt"
for list in "${DEBIAN}"/config/package-lists/*.list.chroot; do
    check_package_list "${list}"
done

log "Menús de arranque"
[[ -f "${ARCH}/syslinux/splash.png" ]] || fail "falta ${ARCH}/syslinux/splash.png"
[[ -f "${ARCH}/grub/themes/gmini/background.png" ]] || fail "falta el fondo del tema de GRUB"
[[ -f "${DEBIAN}/config/bootloaders/isolinux/splash.png" ]] || fail "falta el splash de isolinux"
[[ -f "${DEBIAN}/config/bootloaders/grub-pc/splash.png" ]] || fail "falta el splash de GRUB (Debian)"
grep -Eq '^[[:space:]]*set theme="/boot/grub/themes/gmini/theme.txt"' "${ARCH}/grub/grub.cfg" || fail "grub.cfg no carga el tema"
if grep -rq 'LINUX_LIVE' "${DEBIAN}/config/bootloaders/grub-pc/"; then
    fail "grub-pc/*.cfg no debe contener LINUX_LIVE (live-build borra esas líneas)"
fi
if grep -nP '[^\x00-\x7F]' "${ARCH}"/syslinux/*.cfg "${DEBIAN}"/config/bootloaders/syslinux_common/*.cfg* \
    "${DEBIAN}/config/bootloaders/isolinux/isolinux.cfg" | grep -v ':[[:space:]]*#'; then
    fail "SYSLINUX no muestra caracteres fuera de ASCII (usa la fuente CP437 de la BIOS)"
fi

log "Enlaces simbólicos y finales de línea"
links="$(find iso aur scripts -type l)"
[[ -z "${links}" ]] || fail "enlaces simbólicos (usa hooks o drop-ins): ${links}"
crlf="$(grep -rlI $'\r' iso aur scripts .github 2>/dev/null || true)"
[[ -z "${crlf}" ]] || fail "finales de línea CRLF: ${crlf}"

log "PKGBUILD"
grep -Eq '^pkgver=[0-9][0-9A-Za-z._]*$' aur/PKGBUILD || fail "pkgver no válido"
grep -Eq '^pkgrel=[1-9][0-9]*$' aur/PKGBUILD || fail "pkgrel no válido"
grep -Eq "^sha256sums_x86_64=\('[0-9a-f]{64}'\)$" aur/PKGBUILD || fail "sha256sums_x86_64 debe ser un sha256 concreto"

if ((ERRORS)); then
    die "${ERRORS} comprobaciones fallaron"
fi
log "Perfiles correctos"
