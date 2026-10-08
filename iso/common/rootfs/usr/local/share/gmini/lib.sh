# shellcheck shell=sh
# Funciones comunes de los scripts gmini-* de G-Mini OS. Se cargan con ".".
# POSIX sh: también las usan los ganchos de live-config de Debian.

# shellcheck disable=SC2034  # la usan los scripts que cargan este archivo
GMINI_SHARE=/usr/local/share/gmini

# ¿Arrancó desde el medio live (archiso o live-boot)? Con copytoram, archiso
# desmonta /run/archiso/bootmnt, pero /run/archiso sigue existiendo.
gmini_is_live() {
    [ -d /run/archiso ] || [ -d /run/live/medium ] || grep -qwE 'boot=live|archisobasedir=[^ ]+' /proc/cmdline 2>/dev/null
}

# ID de /etc/os-release (arch, debian...).
gmini_distro() {
    (
        # shellcheck disable=SC1091
        . /etc/os-release 2>/dev/null
        printf '%s\n' "${ID:-linux}"
    )
}

# Idioma de la interfaz: "es" o "en".
gmini_ui_lang() {
    case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
        es*) echo es ;;
        *) echo en ;;
    esac
}

# Ejecutable de G-Mini Agent. El .deb, el .rpm y el paquete de Arch lo dejan
# en /opt/G-Mini Agent con un enlace en /usr/bin.
gmini_app_bin() {
    for candidate in gmini-agent-ui g-mini-agent; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            command -v "${candidate}"
            return 0
        fi
    done
    for candidate in "/opt/G-Mini Agent/gmini-agent-ui" "/opt/G-Mini Agent/g-mini-agent"; do
        if [ -x "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

# Lanzador .desktop instalado por el paquete de G-Mini Agent.
gmini_app_desktop() {
    for candidate in gmini-agent-ui g-mini-agent; do
        if [ -f "/usr/share/applications/${candidate}.desktop" ]; then
            printf '%s\n' "/usr/share/applications/${candidate}.desktop"
            return 0
        fi
    done
    return 1
}

# La app deja esta marca cuando terminó de preparar su Python
# (electron/runtime-setup.js del repo principal).
gmini_runtime_ready() {
    [ -f "${XDG_DATA_HOME:-${HOME}/.local/share}/g-mini-agent/python/.gmini-runtime" ]
}

# Espera hasta N segundos a que haya conexión a internet.
gmini_wait_online() {
    timeout="${1:-30}"
    if command -v nm-online >/dev/null 2>&1; then
        nm-online -q -t "${timeout}" && return 0
    fi
    end=$(($(date +%s) + timeout))
    while [ "$(date +%s)" -lt "${end}" ]; do
        if curl -fsS -o /dev/null --max-time 5 https://github.com 2>/dev/null; then
            return 0
        fi
        sleep 3
    done
    return 1
}

gmini_notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name="G-Mini OS" --icon=gmini-os "$1" "${2:-}" 2>/dev/null || true
    fi
}

# Vuelve a lanzar el script dentro de una terminal si no se abrió desde una.
gmini_in_terminal() {
    title="$1"
    shift
    if [ ! -t 0 ] && [ -n "${DISPLAY:-}" ] && command -v xfce4-terminal >/dev/null 2>&1; then
        exec xfce4-terminal --title="${title}" --hide-menubar --geometry=100x32 -x "$@"
    fi
}

gmini_pause() {
    printf '\n%s' "$1"
    read -r _ || true
}
