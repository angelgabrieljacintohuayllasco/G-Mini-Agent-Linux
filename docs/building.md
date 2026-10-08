# Construir G-Mini OS en local

El camino normal es el workflow `release.yml` de GitHub Actions. Esta guía
sirve para depurar un perfil, probar un cambio antes de subirlo o construir
sin GitHub. Todos los scripts tienen `--help`.

## Requisitos

| Paso | Dónde | Herramientas |
|---|---|---|
| Descargar G-Mini Agent | cualquier Linux, WSL o Git Bash | `curl`, `jq`, `sha256sum` |
| Paquete de Arch | Arch Linux o contenedor `archlinux` | `base-devel`, `squashfs-tools` |
| ISO Arch | Arch Linux o contenedor `archlinux` **privilegiado**, como root | `archiso`, `grub`, `rsync` |
| ISO Debian | Debian 13 o contenedor `debian:trixie` privilegiado, como root | `live-build` de Debian, `rsync` |
| Prueba de arranque | Linux con QEMU | `qemu-system-x86`, `ovmf`, `bsdtar` |
| Lint | Linux, WSL o CI | `shellcheck`, opcionales: `yamllint`, `actionlint`, `desktop-file-validate`, `xmllint` |

Espacio libre: unos 15 GB para la ISO Arch y 12 GB para la Debian.

## 1. Descargar G-Mini Agent

```sh
scripts/fetch-gmini.sh --version 0.3.1 --assets appimage,deb --out out/gmini
```

`--version latest` toma la última release del repo principal. Cada archivo se
compara con el sha256 que GitHub publica para el asset; el resultado queda en
`out/gmini/gmini-release.env`. Con `GITHUB_TOKEN` definido se evita el límite
de la API anónima.

## 2. Paquete de Arch (g-mini-agent-bin)

En Arch Linux:

```sh
scripts/build-aur-package.sh --version 0.3.1 \
  --appimage out/gmini/G-Mini-Agent-0.3.1.AppImage --out out/aur --build
```

Desde otra distribución, con Docker:

```sh
docker run --rm -v "$PWD:/src" -w /src archlinux:latest bash -c '
  pacman -Syu --noconfirm --needed base-devel jq squashfs-tools &&
  scripts/build-aur-package.sh --version 0.3.1 \
    --appimage out/gmini/G-Mini-Agent-0.3.1.AppImage --out out/aur --build'
```

Deja en `out/aur` el PKGBUILD con la versión y el sha256 fijados, el
`.SRCINFO` y el `.pkg.tar.zst`. makepkg no corre como root: dentro del
contenedor el script usa el usuario `builder`.

## 3. ISO Arch Linux

```sh
docker run --rm --privileged -v "$PWD:/src" -w /src archlinux:latest bash -c '
  pacman -Syu --noconfirm --needed archiso grub rsync &&
  scripts/build-iso-arch.sh --package out/aur/g-mini-agent-bin-0.3.1-1-x86_64.pkg.tar.zst \
    --pkgbuild out/aur --version 0.1.0 --out out/iso --work /tmp/gmini-archiso'
```

En Arch sin Docker, lo mismo con `sudo` tras instalar `archiso grub rsync`.

El script copia `iso/archlinux` a un directorio de trabajo, le suma
`iso/common/rootfs` (sin pisar lo propio de Arch), añade el repositorio local
`[gmini]` con el paquete y ejecuta
`mkarchiso -v -w WORK/work -o out/iso WORK/profile`. El perfil del repositorio
no se modifica.

### Desde Windows con WSL2 y Docker Desktop

1. Instala Docker Desktop con el motor WSL2 y activa la integración con tu
   distribución (Settings > Resources > WSL integration).
2. Clona el repositorio **dentro** del sistema de archivos de WSL (por ejemplo
   `~/G-Mini-Agent-Linux`), no en `/mnt/c`: es mucho más rápido y conserva
   permisos y finales de línea.
3. Desde la terminal de WSL ejecuta los pasos 1 a 3 tal cual.
4. La ISO queda en `out/iso`; desde Windows se ve en
   `\\wsl$\<distribución>\home\<usuario>\G-Mini-Agent-Linux\out\iso`.

Si WSL2 no arranca con `WSL_E_CUSTOM_KERNEL_NOT_FOUND`, `.wslconfig` apunta a
un kernel personalizado que ya no está en esa ruta: corrige `kernel=` o quita
la línea. WSL1 no sirve para construir ISO (no tiene montajes ni namespaces),
aunque sí para los pasos 1 y 2 sin makepkg y para el lint.

## 4. ISO Debian

En Debian 13, o en un contenedor `debian:trixie`:

```sh
docker run --rm --privileged -v "$PWD:/src" -w /src debian:trixie bash -c '
  apt-get update && apt-get install -y live-build rsync &&
  scripts/build-iso-debian.sh --deb out/gmini/g-mini-agent_0.3.1_amd64.deb \
    --version 0.1.0 --out out/iso --work /tmp/gmini-live-build'
```

En Ubuntu no sirve el paquete `live-build` de Ubuntu (es la variante 3.0~a57
que usa Ubuntu para sus propias imágenes; el script la rechaza). Instala el de
Debian y pásale el llavero de Debian 13 a debootstrap, como hace el workflow:

```sh
curl -fLO https://deb.debian.org/debian/pool/main/l/live-build/live-build_20250505+deb13u1_all.deb
curl -fLO https://deb.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2025.1_all.deb
sha256sum live-build_*.deb debian-archive-keyring_*.deb   # comparar con release.yml
sudo apt install ./live-build_20250505+deb13u1_all.deb debootstrap rsync
dpkg-deb -x debian-archive-keyring_2025.1_all.deb /tmp/debian-keyring
sudo scripts/build-iso-debian.sh --deb out/gmini/g-mini-agent_0.3.1_amd64.deb \
  --keyring /tmp/debian-keyring/usr/share/keyrings/debian-archive-keyring.pgp --version 0.1.0
```

El llavero se extrae en vez de instalarse: el paquete de Debian reemplazaría
al de Ubuntu, que debootstrap busca como `.gpg`, y el de Debian solo trae
`.pgp`.

El script copia `iso/debian`, suma `iso/common/rootfs` en
`config/includes.chroot_after_packages`, pone el `.deb` en
`config/packages.chroot` y ejecuta `lb config` y `lb build`. El registro
completo queda en `WORK/build.log`.

## 5. Probar el arranque

```sh
scripts/smoke-boot.sh --iso out/iso/g-mini-os-arch-0.1.0-x86_64.iso
scripts/smoke-boot.sh --iso out/iso/g-mini-os-debian-0.1.0-amd64.iso --mode kernel
```

Modos: `bios` (menú de SYSLINUX por la consola serie), `uefi` (menú de GRUB
con OVMF) y `kernel` (kernel e initramfs de la ISO con `console=ttyS0`, hasta
el login de la consola serie). Los registros quedan en `out/smoke`.

## 6. Lint y comprobaciones

```sh
scripts/lint.sh            # todo lo que corre ci.yml
scripts/check-profiles.sh  # solo los perfiles (sin root ni red)
```

`check-profiles.sh` también comprueba que todo lo que se ejecuta dentro de la
ISO tenga el bit de ejecución en git: desde Windows git no lo deduce del
sistema de archivos. Si falla, `git update-index --chmod=+x <archivo>`.

## 7. Identidad visual

Los SVG de `assets/branding` son la fuente; los PNG se versionan para que los
builds no dependan de las fuentes instaladas. Tras editar un SVG:

```sh
scripts/render-branding.sh   # rsvg-convert + Noto Sans
```

## 8. Publicar una release

1. Ajusta `CHANGELOG.md`.
2. Crea y empuja la etiqueta: `git tag -a v0.1.0 -m "G-Mini OS 0.1.0" && git push origin v0.1.0`.
3. `release.yml` usa la última release de G-Mini Agent, salvo que la variable
   del repositorio `GMINI_VERSION` fije otra (Settings > Secrets and variables
   > Actions > Variables).

*Run workflow* en la pestaña Actions construye y prueba sin publicar; acepta
una versión de G-Mini Agent y permite saltarse la prueba con QEMU.

## Decisiones de diseño

**XFCE sobre X11, no Wayland.** G-Mini Agent captura la pantalla (`mss`),
mueve el mouse y escribe (`pyautogui` y `pynput` sobre Xlib/XTEST), registra
atajos globales (Electron `globalShortcut`) y dibuja un avatar en una ventana
transparente, siempre encima y posicionada por la app. En X11 todo eso
funciona sin permisos extra; en Wayland cada punto queda bloqueado o depende
de portales que cada compositor implementa a su manera. XFCE es ligero (unos
500 MB de RAM en reposo), está en la misma versión (4.20) en Arch y en Debian
13, trae compositor para la transparencia y un panel con bandeja para el icono
de G-Mini.

**El PKGBUILD parte del AppImage.** El AppImage existe desde 0.2.0 y el `.deb`
desde 0.3.1; con el AppImage el paquete sirve para cualquier release. Se
extrae leyendo la cabecera ELF, sin ejecutar el binario descargado, y queda
igual que el `.deb` en `/opt/G-Mini Agent`.

**Perfiles sin enlaces simbólicos.** El repositorio se edita también desde
Windows, donde git no crea enlaces simbólicos. Por eso, en Arch, un hook de
pacman ejecuta `systemctl enable` durante el build (crea los enlaces como en
un sistema instalado, `display-manager.service` incluido) y otro fija la zona
horaria; `check-profiles.sh` falla si aparece un enlace.

**Instalación en disco de la edición Arch.** archinstall es el instalador
oficial; `gmini-install` le pasa una configuración de G-Mini OS y dos
`custom_commands`. Como `bacman` ya no existe en Arch, el paquete de G-Mini se
reconstruye con makepkg a partir de `pacman -Ql` en la sesión live (no ocupa
espacio extra en la ISO ni descarga nada) y se sirve en `127.0.0.1`:
`arch-chroot` comparte la red de la sesión live.

**Primer arranque en la sesión live.** La preparación de G-Mini Agent escribe
unos 1,5 GB que, en live, viven en RAM: la edición Arch arranca con
`cow_spacesize=70%` (archiso usa 256 MB por defecto) y `copytoram=n` (no gasta
RAM en copiar la imagen), y ambas ediciones activan zram.

**Tamaños.** Estimados a partir de las bases de datos de los repositorios
(octubre de 2026): la lista de Arch arrastra 549 paquetes (1,26 GiB de
descarga, 3,4 GiB instalados) y la de Debian 943 (0,8 GiB de descarga, 3,0 GiB
instalados) más el `.deb` de 85 MB. Con squashfs xz eso da unos 1,5 a 1,6 GiB y
1,3 a 1,4 GiB por ISO. El workflow falla si alguna llega a 2 GiB; si hace
falta recortar, lo que más pesa es Chromium, el firmware completo, gcc y los
iconos Papirus.

## Limitaciones conocidas

- La edición Arch no admite Secure Boot; en la Debian no está probado.
- Las ISO no están firmadas: la integridad se comprueba con `SHA256SUMS`.
- G-Mini Agent necesita internet en su primer arranque.
- Depende del repositorio principal: el escritorio publica
  `StartupWMClass=G-Mini Agent`, pero la app no declara `productName` y su
  ventana se identifica como `gmini-agent-ui`; en XFCE no se nota, en GNOME el
  icono del dock puede no agruparse con el lanzador.
