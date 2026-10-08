#!/usr/bin/env bash
# Prueba de arranque de una ISO de G-Mini OS con QEMU, por consola serie.
#
# Uso:
#   scripts/smoke-boot.sh --iso FILE [opciones]
#
# Opciones:
#   --iso FILE        ISO a probar (Arch o Debian; se detecta sola)
#   --mode LISTA      bios, uefi, kernel o all (por defecto: all)
#   --timeout SEG     límite de la prueba "kernel" (por defecto: 1200)
#   --memory MB       RAM de la máquina virtual (por defecto: 4096)
#   --log-dir DIR     registros de la consola serie (por defecto: out/smoke)
#   -h, --help        muestra esta ayuda
#
# Pruebas:
#   bios    arranca la ISO con SeaBIOS y espera el menú de SYSLINUX
#   uefi    arranca la ISO con OVMF y espera el menú de GRUB
#   kernel  arranca el kernel y el initramfs de la ISO (con la ISO como CD)
#           con console=ttyS0 y espera, en orden: el kernel, el banner de
#           systemd y el login de la consola serie (multi-user.target).
#
# Usa KVM si /dev/kvm es accesible; si no, emulación (TCG), mucho más lenta.
# GMINI_SMOKE_MENU_PATTERN cambia el texto que se espera en los menús (sirve
# para probar el script con otra ISO basada en archiso o live-build).
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

ISO=""
MODES="all"
TIMEOUT=1200
MEMORY=4096
LOG_DIR="${GMINI_LINUX_ROOT}/out/smoke"
MENU_PATTERN="${GMINI_SMOKE_MENU_PATTERN:-G-Mini OS}"

while (($#)); do
    case "$1" in
        --iso) ISO="$2"; shift 2 ;;
        --mode) MODES="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --memory) MEMORY="$2"; shift 2 ;;
        --log-dir) LOG_DIR="$2"; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
done

[[ -n "${ISO}" && -f "${ISO}" ]] || die "falta --iso o no existe"
require_cmd qemu-system-x86_64 bsdtar
ISO="$(abspath "${ISO}")"
LOG_DIR="$(abspath "${LOG_DIR}")"
mkdir -p "${LOG_DIR}"
[[ "${MODES}" == "all" ]] && MODES="bios,uefi,kernel"

TMP="$(mktemp -d -t gmini-smoke.XXXXXX)"
QEMU_PID=""
# shellcheck disable=SC2317,SC2329  # se invoca desde trap
cleanup() {
    if [[ -n "${QEMU_PID}" ]]; then
        kill "${QEMU_PID}" 2>/dev/null || true
        wait "${QEMU_PID}" 2>/dev/null || true
    fi
    rm -rf -- "${TMP}"
}
trap cleanup EXIT

ACCEL=(-accel "tcg,thread=multi" -cpu max)
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL=(-accel kvm -cpu host)
    log "Aceleración: KVM"
else
    warn "sin acceso a /dev/kvm: se usa emulación (TCG), puede tardar varios minutos"
fi

# Etiqueta de volumen ISO 9660 (descriptor primario, 32 bytes en 32808).
LABEL="$(dd if="${ISO}" bs=1 skip=32808 count=32 status=none | tr -d '\0' | sed 's/[[:space:]]*$//')"
if bsdtar -tf "${ISO}" arch/boot/x86_64/vmlinuz-linux >/dev/null 2>&1; then
    FLAVOR=arch
    KERNEL_PATH=arch/boot/x86_64/vmlinuz-linux
    INITRD_PATH=arch/boot/x86_64/initramfs-linux.img
    CMDLINE="archisobasedir=arch archisolabel=${LABEL} cow_spacesize=1G copytoram=n"
elif bsdtar -tf "${ISO}" live/vmlinuz >/dev/null 2>&1; then
    FLAVOR=debian
    KERNEL_PATH=live/vmlinuz
    INITRD_PATH=live/initrd.img
    CMDLINE="boot=live components username=gmini hostname=g-mini-os"
else
    die "no se reconoce la ISO (ni archiso ni live-build)"
fi
log "ISO $(basename -- "${ISO}"): ${FLAVOR}, etiqueta ${LABEL}"

# Quita secuencias ANSI y retornos de carro para buscar texto en el registro.
clean_log() {
    sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/\r//g' "$1" 2>/dev/null || true
}

# Espera a que aparezca un patrón en el registro mientras QEMU sigue vivo.
wait_for() {
    local log_file="$1" pattern="$2" limit="$3" start="${SECONDS}"
    while ((SECONDS - start < limit)); do
        if clean_log "${log_file}" | grep -Eq -- "${pattern}"; then
            return 0
        fi
        if ! kill -0 "${QEMU_PID}" 2>/dev/null; then
            return 1
        fi
        sleep 2
    done
    return 1
}

# El CD lleva bootindex 1: con -kernel, QEMU reserva el 0 para su ROM
# linuxboot y rechaza otro dispositivo con el mismo índice.
start_qemu() {
    local log_file="$1"
    shift
    : >"${log_file}"
    qemu-system-x86_64 -machine q35 -m "${MEMORY}" -smp 2 "${ACCEL[@]}" \
        -display none -monitor none -no-reboot \
        -serial "file:${log_file}" \
        -drive "file=${ISO},media=cdrom,readonly=on,if=none,id=cd0" \
        -device ide-cd,drive=cd0,bootindex=1 \
        "$@" &
    QEMU_PID=$!
}

stop_qemu() {
    kill "${QEMU_PID}" 2>/dev/null || true
    wait "${QEMU_PID}" 2>/dev/null || true
    QEMU_PID=""
}

RESULTS=()
FAILED=0

record() {
    RESULTS+=("$1")
    [[ "$1" == OK* ]] || FAILED=1
}

test_bios() {
    local log_file="${LOG_DIR}/${FLAVOR}-bios.log" start="${SECONDS}"
    log "BIOS: esperando el menú de SYSLINUX"
    start_qemu "${log_file}"
    if wait_for "${log_file}" "${MENU_PATTERN}" 240; then
        record "OK    bios    menú de SYSLINUX en $((SECONDS - start)) s"
    else
        record "FALLO bios    no apareció el menú (ver ${log_file})"
    fi
    stop_qemu
}

find_ovmf() {
    local candidate
    for candidate in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF.fd /usr/share/edk2/x64/OVMF.4m.fd /usr/share/edk2-ovmf/x64/OVMF.fd; do
        if [[ -f "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

test_uefi() {
    local log_file="${LOG_DIR}/${FLAVOR}-uefi.log" ovmf start="${SECONDS}"
    if ! ovmf="$(find_ovmf)"; then
        record "FALLO uefi    falta el firmware OVMF (paquete ovmf / edk2-ovmf)"
        return
    fi
    log "UEFI: esperando el menú de GRUB (${ovmf})"
    start_qemu "${log_file}" -bios "${ovmf}"
    if wait_for "${log_file}" "${MENU_PATTERN}" 300; then
        record "OK    uefi    menú de GRUB en $((SECONDS - start)) s"
    else
        record "FALLO uefi    no apareció el menú (ver ${log_file})"
    fi
    stop_qemu
}

test_kernel() {
    local log_file="${LOG_DIR}/${FLAVOR}-kernel.log" start step
    bsdtar -xf "${ISO}" -C "${TMP}" "${KERNEL_PATH}" "${INITRD_PATH}"
    # loglevel=6: con su nivel de consola por defecto, el kernel de Arch no
    # imprime el banner "Linux version" (KERN_NOTICE) que la prueba espera primero.
    local append="${CMDLINE} console=ttyS0,115200 loglevel=6 systemd.unit=multi-user.target"
    log "Kernel: ${append}"
    start="${SECONDS}"
    start_qemu "${log_file}" \
        -kernel "${TMP}/${KERNEL_PATH}" -initrd "${TMP}/${INITRD_PATH}" \
        -append "${append}"

    # live-config de Debian puede entrar solo en la consola serie: vale el
    # login o el prompt del usuario.
    for step in 'Linux version|kernel' 'Welcome to|systemd' 'login:|@g-mini-os|consola serie'; do
        if wait_for "${log_file}" "${step%|*}" "$((TIMEOUT - (SECONDS - start)))"; then
            info "${step##*|}: $((SECONDS - start)) s"
        else
            record "FALLO kernel  sin \"${step%|*}\" tras $((SECONDS - start)) s (ver ${log_file})"
            stop_qemu
            return
        fi
    done
    record "OK    kernel  kernel + systemd + login en $((SECONDS - start)) s"
    stop_qemu
}

IFS=',' read -r -a selected <<<"${MODES}"
for mode in "${selected[@]}"; do
    case "${mode}" in
        bios) test_bios ;;
        uefi) test_uefi ;;
        kernel) test_kernel ;;
        *) die "modo desconocido: ${mode}" ;;
    esac
done

log "Resultado ($(basename -- "${ISO}"))"
printf '    %s\n' "${RESULTS[@]}"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        printf '### Arranque de %s\n\n```\n' "$(basename -- "${ISO}")"
        printf '%s\n' "${RESULTS[@]}"
        printf '```\n'
    } >>"${GITHUB_STEP_SUMMARY}"
fi
exit "${FAILED}"
