#!/usr/bin/env bash
# Rasteriza la identidad visual (assets/branding/*.svg) en los PNG que usan
# las ISO. Los PNG se versionan para que un build de ISO no dependa de tener
# rsvg-convert y las fuentes exactas; tras editar un SVG, ejecuta este script
# y commitea el resultado.
#
# Uso: scripts/render-branding.sh
#
# Necesita rsvg-convert (librsvg2-bin / librsvg) y Noto Sans
# (fonts-noto-core / noto-fonts) para que el texto salga igual.
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd rsvg-convert fc-match
if [[ "$(fc-match -f '%{family[0]}' 'Noto Sans')" != "Noto Sans" ]]; then
    warn "Noto Sans no está instalada: el texto usará otra fuente"
fi

SRC="${GMINI_LINUX_ROOT}/assets/branding"
COMMON="${GMINI_LINUX_ROOT}/iso/common/rootfs"
ARCH="${GMINI_LINUX_ROOT}/iso/archlinux"
DEBIAN="${GMINI_LINUX_ROOT}/iso/debian/config/bootloaders"

render() {
    local svg="$1" width="$2" height="$3" out="$4"
    mkdir -p -- "$(dirname -- "${out}")"
    rsvg-convert --width "${width}" --height "${height}" --format png --output "${out}" "${SRC}/${svg}"
    info "${out#"${GMINI_LINUX_ROOT}/"} (${width}x${height}, $(human_size "${out}"))"
}

log "Fondos de escritorio"
render wallpaper.svg 1920 1080 "${COMMON}/usr/share/backgrounds/g-mini/g-mini-os-1920x1080.png"
render wallpaper.svg 2560 1440 "${COMMON}/usr/share/backgrounds/g-mini/g-mini-os-2560x1440.png"

log "Logo"
install -Dm644 "${SRC}/logo.svg" "${COMMON}/usr/local/share/icons/hicolor/scalable/apps/gmini-os.svg"
for size in 48 128 256; do
    render logo.svg "${size}" "${size}" "${COMMON}/usr/local/share/icons/hicolor/${size}x${size}/apps/gmini-os.png"
done

log "Menús de arranque"
render splash-bios.svg 640 480 "${ARCH}/syslinux/splash.png"
render boot-background.svg 1920 1080 "${ARCH}/grub/themes/gmini/background.png"
render splash-bios.svg 640 480 "${DEBIAN}/isolinux/splash.png"
render boot-background.svg 1920 1080 "${DEBIAN}/grub-pc/splash.png"

log "Listo"
