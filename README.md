# G-Mini OS y G-Mini Agent para Linux

[English](README.en.md)

Este repositorio construye **G-Mini OS**: dos imágenes ISO de Linux, live e
instalables, con [G-Mini Agent](https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent)
ya instalado y abriéndose al iniciar sesión. También mantiene el PKGBUILD
`g-mini-agent-bin` para instalar G-Mini Agent en Arch Linux.

| Edición | Base | Instalador | Cómo llega G-Mini Agent |
|---|---|---|---|
| **G-Mini OS (Arch Linux)** | Arch Linux (archiso, perfil `releng`) | archinstall, preconfigurado | Paquete `g-mini-agent-bin` construido desde el AppImage de la release |
| **G-Mini OS (Debian)** | Debian 13 "trixie" (live-build) | Calamares (copia el sistema live) | El `.deb` oficial de la release |

Las dos ediciones comparten escritorio, idioma y ajustes: XFCE sobre X11,
español (Perú) con teclado latinoamericano, PipeWire, NetworkManager,
Bluetooth, fuentes Noto, Chromium, Tesseract (OCR) y el compilador que
necesita el primer arranque de G-Mini Agent.

> G-Mini Agent no trae Python dentro. La primera vez que se abre descarga su
> propio Python 3.13 y sus componentes (unos 1,5 GB) en
> `~/.local/share/g-mini-agent`. **Hace falta internet** la primera vez.

## Descargas

Cada [release](../../releases) de este repositorio publica:

| Archivo | Qué es |
|---|---|
| `g-mini-os-arch-<versión>-x86_64.iso` | ISO live e instalable basada en Arch Linux |
| `g-mini-os-debian-<versión>-amd64.iso` | ISO live e instalable basada en Debian 13 |
| `g-mini-agent-bin-<versión>-x86_64.pkg.tar.zst` | Paquete de Arch listo para `pacman -U` |
| `PKGBUILD`, `g-mini-agent-bin-aur.tar.gz` | PKGBUILD final (con su sha256) y el conjunto para AUR (`PKGBUILD`, `.SRCINFO`, scriptlet) |
| `SHA256SUMS` | Sumas de verificación de todo lo anterior |

Cada ISO pesa menos de 2 GiB (límite de GitHub por archivo; el workflow lo
comprueba). Por las listas de paquetes actuales se esperan unos 1,5 a 1,6 GiB
para Arch y 1,3 a 1,4 GiB para Debian; el tamaño exacto figura en las notas de
cada release.

Requisitos: PC de 64 bits (x86_64) con arranque BIOS o UEFI, 4 GB de RAM como
mínimo (8 GB recomendados: en la sesión live la descarga del primer arranque
vive en RAM) y un USB de 4 GB o más. Desactiva el arranque seguro (Secure
Boot): la edición Arch no lo admite y en la Debian no está probado.

### Verificar la descarga

```sh
sha256sum -c SHA256SUMS --ignore-missing
```

En Windows (PowerShell): `Get-FileHash .\g-mini-os-arch-0.1.0-x86_64.iso -Algorithm SHA256`
y compara el resultado con la línea de `SHA256SUMS`.

## Probar la ISO en una máquina virtual

### VirtualBox

1. **Nueva** máquina: tipo *Linux*, versión *Arch Linux (64-bit)* o *Debian (64-bit)*.
2. Memoria: **4096 MB** o más (6144 MB si vas a usar G-Mini Agent); 2 CPU o más.
3. Disco: 25 GB (solo hace falta si vas a probar la instalación).
4. En **Configuración > Pantalla**: controlador *VMSVGA* y 128 MB de vídeo.
5. En **Configuración > Almacenamiento**, en el controlador óptico, elige la ISO.
6. Opcional: **Configuración > Sistema > Habilitar EFI** para probar el arranque UEFI.
7. Inicia la máquina y elige **G-Mini OS** en el menú.

El portapapeles compartido y el ajuste automático de resolución funcionan en
la edición Arch (lleva `virtualbox-guest-utils`).

### QEMU

Con aceleración KVM (Linux):

```sh
qemu-system-x86_64 -enable-kvm -cpu host -m 6G -smp 4 \
  -vga virtio -display gtk -cdrom g-mini-os-arch-0.1.0-x86_64.iso -boot d
```

Arranque UEFI (paquete `ovmf` en Debian/Ubuntu, `edk2-ovmf` en Arch):

```sh
qemu-system-x86_64 -enable-kvm -cpu host -m 6G -smp 4 -vga virtio \
  -bios /usr/share/ovmf/OVMF.fd -cdrom g-mini-os-debian-0.1.0-amd64.iso
```

Para probar la instalación, agrega un disco: `qemu-img create -f qcow2 disco.qcow2 25G`
y la opción `-drive file=disco.qcow2,if=virtio`.

En Windows sin KVM, QEMU funciona con `-accel whpx` (Hyper-V) o, más lento,
sin aceleración. VirtualBox suele ser la opción más cómoda.

### Prueba automática por consola serie

`scripts/smoke-boot.sh` es la misma prueba que corre el CI: arranca la ISO con
QEMU sin interfaz y comprueba por la consola serie el menú de SYSLINUX (BIOS),
el de GRUB (UEFI) y que el kernel llegue a systemd y al login.

```sh
sudo apt install qemu-system-x86 ovmf libarchive-tools   # o el equivalente
scripts/smoke-boot.sh --iso g-mini-os-arch-0.1.0-x86_64.iso
```

Usa KVM si `/dev/kvm` es accesible; sin KVM (emulación) tarda varios minutos.

## Grabar la ISO en un USB

Cualquier método copia la imagen completa; **el USB se borra**.

- **Ventoy** (Windows y Linux): instala Ventoy en el USB una vez y copia la ISO
  como un archivo más. Permite tener varias ISO en el mismo USB.
- **balenaEtcher** (Windows, macOS, Linux): *Flash from file*, elige el USB y *Flash*.
- **dd** (Linux): identifica el USB con `lsblk` y escribe sobre el dispositivo
  completo (por ejemplo `/dev/sdX`, no `/dev/sdX1`):

  ```sh
  sudo dd if=g-mini-os-arch-0.1.0-x86_64.iso of=/dev/sdX bs=4M conv=fsync oflag=direct status=progress
  ```

En Windows también sirve Rufus en modo *DD*.

## Sesión live

| | |
|---|---|
| Usuario | `gmini` |
| Contraseña | `gmini` (también para `sudo`) |
| Idioma | español (Perú), `es_PE.UTF-8`; entrada **G-Mini OS (English)** en el menú de arranque |
| Teclado | latinoamericano y estadounidense, **Alt+Mayús** alterna |
| Zona horaria | America/Lima |

Al entrar se abren la **Bienvenida** (red, instalación, Ollama, idioma) y
G-Mini Agent. Si todavía no hay red, G-Mini avisa y su ventana de preparación
ofrece **Reintentar** cuando te conectes.

En la sesión live, `sudo` no pide contraseña y el llavero (donde G-Mini guarda
las API keys) no tiene contraseña: todo vive en RAM y se borra al apagar. Nada
de eso pasa al sistema instalado.

Ollama (modelos locales) no viene en la ISO para mantenerla pequeña: el acceso
**Instalar Ollama** lo instala cuando lo necesites.

## Instalar G-Mini OS en el disco

Abre **Instalar G-Mini OS** en el escritorio. Necesitas internet y conviene
respaldar antes tus datos: el disco elegido puede borrarse.

- **Edición Arch Linux**: se abre [archinstall](https://wiki.archlinux.org/title/Archinstall)
  ya configurado (XFCE con LightDM, `es_PE.UTF-8`, teclado `la-latin1`,
  PipeWire, NetworkManager, Bluetooth, zram, America/Lima). Tú eliges el disco
  (*Disk configuration*), el usuario y las contraseñas (*Authentication*) y
  pulsas *Install*. Al final se añaden G-Mini Agent (el mismo paquete de la
  sesión live, reconstruido sin volver a descargarlo) y los ajustes de
  escritorio de G-Mini OS. El registro queda en `/var/log/gmini-install.log`
  del sistema instalado.
- **Edición Debian**: se abre Calamares, que copia este mismo sistema al disco
  (G-Mini Agent incluido) y quita los paquetes propios de la sesión live.

## Instalar G-Mini Agent en tu distribución

El repositorio principal publica los paquetes oficiales en sus
[releases](https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent/releases).
En todos los casos, la primera vez que se abre compila un módulo (`evdev`,
que usa `pynput` en Linux), así que instala también un compilador de C.

| Distribución | Paquete | Instalación |
|---|---|---|
| Ubuntu, Debian, Linux Mint, Pop!_OS | `.deb` | `sudo apt install ./g-mini-agent_0.3.1_amd64.deb gcc libc6-dev` |
| Fedora | `.rpm` | `sudo dnf install ./g-mini-agent-0.3.1.x86_64.rpm gcc kernel-headers` |
| openSUSE | `.rpm` | `sudo zypper install ./g-mini-agent-0.3.1.x86_64.rpm gcc linux-glibc-devel` |
| Arch Linux, Manjaro, EndeavourOS | PKGBUILD | ver abajo |
| Cualquiera | AppImage | `chmod +x G-Mini-Agent-0.3.1.AppImage && ./G-Mini-Agent-0.3.1.AppImage` |

Notas:

- El AppImage usa el runtime clásico, que necesita FUSE 2 (`libfuse2`; en
  Ubuntu 24.04, `libfuse2t64`). Sin FUSE: `./G-Mini-Agent-0.3.1.AppImage --appimage-extract-and-run`.
- En Ubuntu 24.04 o posterior, AppArmor bloquea el sandbox de Chromium de los
  AppImage: ábrelo con `--no-sandbox` o usa el `.deb`, que deja el sandbox
  de Chromium con SUID y no tiene ese problema.
- Las API keys se guardan en el llavero del sistema (Secret Service):
  `gnome-keyring` en GNOME, XFCE, Cinnamon o MATE; KWallet en KDE Plasma.
- Audio y micrófono: PipeWire (con `pipewire-pulse`) o PulseAudio. OCR
  opcional: `tesseract` con los datos de español e inglés.

### Arch Linux con el PKGBUILD

El PKGBUILD reempaqueta el AppImage oficial en `/opt/G-Mini Agent` (la misma
ruta que el `.deb` y el `.rpm`) sin ejecutarlo: lee el desplazamiento de la
imagen squashfs en la cabecera ELF y la extrae con `unsquashfs`. La suma
sha256 del AppImage está fijada en el PKGBUILD.

```sh
git clone https://github.com/<owner>/G-Mini-Agent-Linux.git
cd G-Mini-Agent-Linux/aur
makepkg -si
```

O con el conjunto de la release: descarga `g-mini-agent-bin-aur.tar.gz`,
descomprímelo y ejecuta `makepkg -si` dentro. También puedes instalar
directamente el paquete ya construido:

```sh
sudo pacman -U g-mini-agent-bin-0.3.1-1-x86_64.pkg.tar.zst
```

Para publicarlo en AUR, el conjunto de la release ya trae el `.SRCINFO`
que produce `makepkg --printsrcinfo`.

## Cómo se construye

El workflow [`release.yml`](.github/workflows/release.yml) hace todo en GitHub
Actions al empujar una etiqueta `v*` (o a mano, con *Run workflow*):

1. **Versiones**: G-Mini Agent sale de la entrada `gmini_version`, si no de la
   variable del repositorio `GMINI_VERSION`, y si no de la última release del
   repo principal. Cada paquete descargado se verifica contra el sha256 que
   GitHub publica para el asset.
2. **Paquete de Arch**: `makepkg` en un contenedor `archlinux`, más `namcap`.
3. **ISO Arch**: `mkarchiso` en un contenedor `archlinux` con `--privileged`,
   con el paquete anterior en un repositorio local.
4. **ISO Debian**: el live-build de Debian 13 (versión fijada y verificada) en
   el runner de Ubuntu.
5. **Prueba de arranque** de cada ISO con QEMU (KVM si el runner lo ofrece):
   menú BIOS, menú UEFI y kernel hasta el login por consola serie.
6. **Release**: comprueba que cada archivo pese menos de 2 GiB, genera
   `SHA256SUMS` y publica todo con `softprops/action-gh-release`.

[`ci.yml`](.github/workflows/ci.yml) corre en cada push: shellcheck, yamllint,
actionlint, desktop-file-validate, xmllint y comprobaciones en seco de los
perfiles; además resuelve las listas de paquetes contra los repositorios de
Arch (`pacman -Sp`) y de Debian (`apt-get --simulate`) y valida el PKGBUILD
con `namcap`.

Builds locales, también desde Windows con WSL2 y Docker: [docs/building.md](docs/building.md).

## Estructura

```
aur/                   PKGBUILD de g-mini-agent-bin y su scriptlet de pacman
assets/branding/       logo, fondo y menús de arranque en SVG
iso/archlinux/         perfil archiso (derivado de releng)
iso/debian/            configuración de live-build (auto/ y config/)
iso/common/rootfs/     archivos compartidos por las dos ISO: XFCE, bienvenida,
                       autoarranque, scripts gmini-*, fondos
scripts/               build de las ISO y del paquete, descarga verificada de
                       G-Mini Agent, prueba de arranque, lint
docs/                  guía de build y decisiones de diseño
```

## Licencia

[MIT](LICENSE). G-Mini Agent tiene su propia licencia (MIT) en su repositorio.
Las ISO incluyen software de Arch Linux y de Debian con sus respectivas
licencias, incluido firmware no libre necesario para hardware común.
