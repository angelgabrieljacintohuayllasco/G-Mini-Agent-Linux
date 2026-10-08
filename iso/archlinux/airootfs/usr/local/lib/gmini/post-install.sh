#!/bin/sh
# Ajustes de G-Mini OS en un sistema recién instalado con gmini-install.
# archinstall lo ejecuta dentro del sistema nuevo (custom_commands), cuando
# los usuarios ya existen: copia a sus carpetas la configuración de XFCE y los
# autostart de G-Mini, que llegaron a /etc/skel después de crearlos.
set -eu

for home in /home/*; do
    [ -d "${home}" ] || continue
    user="$(basename "${home}")"
    uid="$(id -u "${user}" 2>/dev/null)" || continue
    [ "${uid}" -ge 1000 ] || continue
    group="$(id -gn "${user}")"

    for dir in .config/xfce4 .config/autostart; do
        if [ -d "/etc/skel/${dir}" ] && [ ! -e "${home}/${dir}" ]; then
            mkdir -p "${home}/.config"
            cp -a "/etc/skel/${dir}" "${home}/${dir}"
        fi
    done
    chown -R "${user}:${group}" "${home}/.config"
done

echo "G-Mini OS: ajustes de escritorio aplicados"
