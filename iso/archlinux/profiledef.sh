#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Perfil archiso de G-Mini OS, derivado de "releng" (archiso v91).
# scripts/build-iso-arch.sh lo copia a un directorio de trabajo, le añade los
# archivos comunes de iso/common/rootfs y el paquete local de G-Mini Agent, y
# ejecuta mkarchiso sobre esa copia.
#
# GMINI_OS_VERSION fija la versión del nombre del archivo; sin ella se usa la
# fecha, como en releng.

iso_name="g-mini-os-arch"
iso_label="GMINI_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="G-Mini Agent <https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent>"
iso_application="G-Mini OS (Arch Linux) live"
iso_version="${GMINI_OS_VERSION:-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)}"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/etc/sudoers.d/10-gmini-live"]="0:0:440"
    ["/home/gmini/.local/share/keyrings/"]="1000:1000:700"
    ["/usr/local/bin/gmini-autostart"]="0:0:755"
    ["/usr/local/bin/gmini-install"]="0:0:755"
    ["/usr/local/bin/gmini-install-ollama"]="0:0:755"
    ["/usr/local/bin/gmini-lang"]="0:0:755"
    ["/usr/local/bin/gmini-polkit-agent"]="0:0:755"
    ["/usr/local/bin/gmini-session-setup"]="0:0:755"
    ["/usr/local/bin/gmini-welcome"]="0:0:755"
    ["/usr/local/lib/gmini/post-install.sh"]="0:0:755"
)
