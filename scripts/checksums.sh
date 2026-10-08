#!/usr/bin/env bash
# Genera SHA256SUMS con los archivos de una carpeta de release.
#
# Uso: scripts/checksums.sh DIR
#
# Verificación: cd DIR && sha256sum -c SHA256SUMS
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

DIR="${1:?uso: checksums.sh DIR}"
[[ -d "${DIR}" ]] || die "no existe ${DIR}"
require_cmd sha256sum

cd -- "${DIR}"
mapfile -t files < <(find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\n' | LC_ALL=C sort)
((${#files[@]} > 0)) || die "${DIR} está vacío"
sha256sum -- "${files[@]}" >SHA256SUMS
log "SHA256SUMS (${#files[@]} archivos)"
cat SHA256SUMS
