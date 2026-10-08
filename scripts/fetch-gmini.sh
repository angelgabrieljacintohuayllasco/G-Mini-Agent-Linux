#!/usr/bin/env bash
# Descarga los paquetes de G-Mini Agent publicados en una release del repo
# principal y verifica cada uno contra el sha256 que GitHub calcula al subirlo.
#
# Uso:
#   scripts/fetch-gmini.sh [opciones]
#
# Opciones:
#   --version VER   versión (0.3.1, v0.3.1) o "latest" (por defecto: latest)
#   --assets LISTA  qué bajar, separado por comas: appimage, deb, rpm.
#                   Un "?" al final lo vuelve opcional: "appimage,deb?"
#                   (por defecto: appimage)
#   --out DIR       destino (por defecto: out/gmini)
#   --repo O/N      repo de la app (por defecto: $GMINI_UPSTREAM_REPO)
#   -h, --help      muestra esta ayuda
#
# Deja en DIR el archivo gmini-release.env con GMINI_VERSION, GMINI_TAG y,
# por cada paquete, su ruta y su sha256 (GMINI_APPIMAGE, GMINI_APPIMAGE_SHA256,
# GMINI_DEB, ...). En GitHub Actions publica lo mismo en GITHUB_OUTPUT.
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

VERSION="latest"
ASSETS="appimage"
OUT="${GMINI_LINUX_ROOT}/out/gmini"
REPO="${GMINI_UPSTREAM_REPO}"

while (($#)); do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --assets) ASSETS="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
done

require_cmd curl jq sha256sum
OUT="$(abspath "${OUT}")"
mkdir -p "${OUT}"

if [[ -z "${VERSION}" || "${VERSION}" == "latest" ]]; then
    TAG="$(github_api "repos/${REPO}/releases/latest" | jq -r '.tag_name')"
    [[ -n "${TAG}" && "${TAG}" != "null" ]] || die "no se pudo leer la última release de ${REPO}"
    log "Última release de ${REPO}: ${TAG}"
else
    TAG="v${VERSION#v}"
fi
VERSION="${TAG#v}"
is_semver "${VERSION}" || die "versión no válida: ${VERSION}"

RELEASE_JSON="${OUT}/release-${TAG}.json"
github_api "repos/${REPO}/releases/tags/${TAG}" >"${RELEASE_JSON}" ||
    die "no existe la release ${TAG} en ${REPO}"

# Nombres que publica electron-builder en el repo principal.
asset_name() {
    case "$1" in
        appimage) printf 'G-Mini-Agent-%s.AppImage\n' "${VERSION}" ;;
        deb) printf 'g-mini-agent_%s_amd64.deb\n' "${VERSION}" ;;
        rpm) printf 'g-mini-agent-%s.x86_64.rpm\n' "${VERSION}" ;;
        *) die "tipo de paquete desconocido: $1" ;;
    esac
}

ENV_FILE="${OUT}/gmini-release.env"
{
    printf 'GMINI_VERSION=%q\n' "${VERSION}"
    printf 'GMINI_TAG=%q\n' "${TAG}"
} >"${ENV_FILE}"
emit_output version "${VERSION}" >/dev/null
emit_output tag "${TAG}" >/dev/null

IFS=',' read -r -a requested <<<"${ASSETS}"
for item in "${requested[@]}"; do
    kind="${item%\?}"
    optional=0
    [[ "${item}" == *\? ]] && optional=1
    name="$(asset_name "${kind}")"
    key="GMINI_${kind^^}"

    url="$(jq -r --arg n "${name}" '.assets[] | select(.name == $n) | .browser_download_url' "${RELEASE_JSON}")"
    digest="$(jq -r --arg n "${name}" '.assets[] | select(.name == $n) | .digest // empty' "${RELEASE_JSON}")"
    if [[ -z "${url}" ]]; then
        if ((optional)); then
            warn "${TAG} no publica ${name}; se omite"
            continue
        fi
        die "${TAG} no publica ${name} (assets: $(jq -r '[.assets[].name] | join(", ")' "${RELEASE_JSON}"))"
    fi

    file="${OUT}/${name}"
    expected="${digest#sha256:}"
    if [[ -f "${file}" && -n "${expected}" ]] && echo "${expected}  ${file}" | sha256sum --quiet -c - 2>/dev/null; then
        log "${name} ya descargado"
    else
        log "Descargando ${name}"
        curl -fsSL --retry 3 --retry-delay 3 -o "${file}.part" "${url}"
        mv -f -- "${file}.part" "${file}"
    fi

    actual="$(sha256sum -- "${file}" | cut -d' ' -f1)"
    if [[ -n "${expected}" ]]; then
        [[ "${actual}" == "${expected}" ]] ||
            die "${name}: sha256 ${actual} no coincide con el de GitHub (${expected})"
        info "${name}: sha256 verificado contra GitHub (${actual})"
    else
        warn "GitHub no informa el digest de ${name}; sha256 calculado: ${actual}"
    fi

    {
        printf '%s=%q\n' "${key}" "${file}"
        printf '%s_SHA256=%q\n' "${key}" "${actual}"
    } >>"${ENV_FILE}"
    emit_output "${kind}" "${file}" >/dev/null
    emit_output "${kind}_sha256" "${actual}" >/dev/null
done

log "G-Mini Agent ${VERSION} listo en ${OUT}"
cat -- "${ENV_FILE}"
