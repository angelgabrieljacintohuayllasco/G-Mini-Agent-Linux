# shellcheck shell=bash
# Funciones compartidas por los scripts de build. Se carga con `source`.

# Raíz de este repositorio (G-Mini-Agent-Linux).
GMINI_LINUX_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export GMINI_LINUX_ROOT

# Repositorio de la app (owner/nombre en GitHub). Sus releases publican el
# AppImage, el .deb y el .rpm que estas ISO y el PKGBUILD reempaquetan.
: "${GMINI_UPSTREAM_REPO:=angelgabrieljacintohuayllasco/G-Mini-Agent}"
export GMINI_UPSTREAM_REPO

# Límite de GitHub por archivo de release.
GMINI_RELEASE_ASSET_LIMIT=$((2 * 1024 * 1024 * 1024))
export GMINI_RELEASE_ASSET_LIMIT

if [[ -t 2 || -n "${GITHUB_ACTIONS:-}" ]]; then
    _c_blue=$'\033[1;34m' _c_yellow=$'\033[1;33m' _c_red=$'\033[1;31m' _c_off=$'\033[0m'
else
    _c_blue='' _c_yellow='' _c_red='' _c_off=''
fi

log() { printf '%s==>%s %s\n' "${_c_blue}" "${_c_off}" "$*" >&2; }
info() { printf '    %s\n' "$*" >&2; }
warn() { printf '%sAVISO:%s %s\n' "${_c_yellow}" "${_c_off}" "$*" >&2; }
die() {
    printf '%sERROR:%s %s\n' "${_c_red}" "${_c_off}" "$*" >&2
    exit 1
}

# Comprueba que existan todas las órdenes indicadas.
require_cmd() {
    local cmd missing=()
    for cmd in "$@"; do
        command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
    done
    ((${#missing[@]} == 0)) || die "faltan herramientas: ${missing[*]}"
}

require_root() {
    ((EUID == 0)) || die "este paso necesita root (contenedor o sudo)"
}

# Convierte una ruta en absoluta sin exigir que exista.
abspath() {
    local path="$1"
    if [[ "${path}" == /* ]]; then
        printf '%s\n' "${path}"
    else
        printf '%s/%s\n' "$(pwd -P)" "${path#./}"
    fi
}

# Tamaño legible de un fichero o directorio.
human_size() {
    du -sh -- "$1" 2>/dev/null | cut -f1
}

# Falla si el archivo no cabe como asset de una release de GitHub.
check_asset_size() {
    local file="$1" bytes
    bytes="$(stat -c %s -- "${file}")"
    if ((bytes >= GMINI_RELEASE_ASSET_LIMIT)); then
        die "$(basename -- "${file}") pesa ${bytes} bytes: supera el límite de 2 GiB de GitHub"
    fi
    info "$(basename -- "${file}"): $(numfmt --to=iec-i --suffix=B "${bytes}") (${bytes} bytes)"
}

# Valida una versión semántica simple (X.Y.Z con sufijo opcional).
is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+.][0-9A-Za-z.]+)?$ ]]
}

# Llamada a la API de GitHub. Usa GITHUB_TOKEN si existe (evita el límite
# de 60 peticiones por hora de las llamadas anónimas).
github_api() {
    local path="$1"
    local -a headers=(-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    curl -fsSL --retry 3 --retry-delay 2 "${headers[@]}" "https://api.github.com/${path#/}"
}

# Imprime KEY=VALUE en stdout y, dentro de GitHub Actions, también en
# GITHUB_OUTPUT para que otros pasos lo lean.
emit_output() {
    local key="$1" value="$2"
    printf '%s=%s\n' "${key}" "${value}"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf '%s=%s\n' "${key}" "${value}" >>"${GITHUB_OUTPUT}"
    fi
}
