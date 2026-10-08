#!/usr/bin/env bash
# Lint de todo el repositorio. Lo usa el workflow ci.yml y sirve en local.
#
# Uso: scripts/lint.sh
#
# Herramientas: shellcheck (obligatoria); yamllint, actionlint,
# desktop-file-validate y xmllint se usan si están instaladas (en CI lo están).
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

cd -- "${GMINI_LINUX_ROOT}"
require_cmd shellcheck
ERRORS=0
step() {
    local name="$1"
    shift
    if "$@"; then
        info "${name}: OK"
    else
        printf '  FALLO: %s\n' "${name}" >&2
        ERRORS=$((ERRORS + 1))
    fi
}

shell_files() {
    {
        find scripts -type f -name '*.sh'
        find iso/common/rootfs/usr/local/bin iso/archlinux/airootfs/usr/local/bin \
            iso/debian/config/includes.chroot_after_packages/usr/local/bin -type f
        find iso/archlinux/airootfs/usr/local/lib iso/debian/auto iso/debian/config/hooks -type f
        echo iso/common/rootfs/usr/local/share/gmini/lib.sh
        echo iso/debian/config/includes.chroot_after_packages/usr/lib/live/config/1175-gmini
        echo iso/archlinux/profiledef.sh
    } | while read -r file; do
        head -n 1 "${file}" | grep -q python || printf '%s\n' "${file}"
    done | sort
}

log "shellcheck ($(shellcheck --version | sed -n 's/^version: //p'))"
mapfile -t files < <(shell_files)
step "scripts (${#files[@]})" shellcheck -x --source-path=SCRIPTDIR --source-path="${GMINI_LINUX_ROOT}" "${files[@]}"
# makepkg define srcdir, pkgdir y las funciones error/msg.
step "PKGBUILD" shellcheck --shell=bash -e SC2034,SC2154,SC2164 aur/PKGBUILD
step "scriptlet de pacman" shellcheck --shell=sh aur/g-mini-agent-bin.install

if command -v yamllint >/dev/null 2>&1; then
    log "yamllint"
    step "workflows" yamllint --strict .github/workflows
else
    warn "yamllint no está instalado: se omite"
fi

if command -v actionlint >/dev/null 2>&1; then
    log "actionlint"
    step "workflows" actionlint
else
    warn "actionlint no está instalado: se omite"
fi

if command -v desktop-file-validate >/dev/null 2>&1; then
    log "desktop-file-validate"
    mapfile -t desktops < <(find iso -name '*.desktop' -type f | sort)
    step "lanzadores (${#desktops[@]})" desktop-file-validate "${desktops[@]}"
else
    warn "desktop-file-validate no está instalado: se omite"
fi

if command -v xmllint >/dev/null 2>&1; then
    log "xmllint"
    mapfile -t xmls < <(find iso -name '*.xml' -type f | sort)
    step "xfconf (${#xmls[@]})" xmllint --noout "${xmls[@]}"
else
    warn "xmllint no está instalado: se omite"
fi

log "Python"
step "gmini-welcome" python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' \
    iso/common/rootfs/usr/local/bin/gmini-welcome

log "Comprobaciones de perfiles"
step "check-profiles" "${GMINI_LINUX_ROOT}/scripts/check-profiles.sh"

if ((ERRORS)); then
    die "${ERRORS} pasos de lint fallaron"
fi
log "Lint correcto"
