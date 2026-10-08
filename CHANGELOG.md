# Cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
versiones con [SemVer](https://semver.org/lang/es/).

## [0.1.0] - 2026-10-08

Primera versión. G-Mini Agent por defecto: 0.3.1.

### Añadido

- ISO **G-Mini OS (Arch Linux)**: perfil archiso derivado de `releng` (v91),
  live e instalable, con XFCE sobre X11, LightDM con entrada automática,
  PipeWire, NetworkManager, Bluetooth, fuentes Noto, Chromium, Tesseract y
  zram. Arranque BIOS (SYSLINUX) y UEFI (GRUB con tema propio), entradas en
  español, inglés y modo seguro.
- ISO **G-Mini OS (Debian)**: live-build de Debian 13 con el `.deb` oficial de
  G-Mini Agent y Calamares para instalar en el disco.
- Instalador de la edición Arch (`gmini-install`): archinstall preconfigurado
  que añade G-Mini Agent y los ajustes de escritorio al sistema instalado sin
  volver a descargar el paquete.
- Sesión común a las dos ediciones: autoarranque de G-Mini Agent que espera
  la red, pantalla de bienvenida, cambio de idioma (`gmini-lang`), instalación
  opcional de Ollama, fondo y menús de arranque de G-Mini OS.
- PKGBUILD `g-mini-agent-bin` desde el AppImage oficial, extraído sin
  ejecutarlo, en `/opt/G-Mini Agent`.
- Descarga de los paquetes de la release verificada contra el sha256 que
  publica GitHub (`scripts/fetch-gmini.sh`).
- Prueba de arranque con QEMU por consola serie (`scripts/smoke-boot.sh`).
- CI con shellcheck, yamllint, actionlint, desktop-file-validate, xmllint,
  comprobaciones de perfiles y resolución de las listas de paquetes contra
  los repositorios de Arch y Debian; release con ambas ISO, el paquete de Arch,
  el conjunto para AUR y `SHA256SUMS`.
