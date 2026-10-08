# G-Mini OS and G-Mini Agent for Linux

[Español](README.md)

This repository builds **G-Mini OS**: two live and installable Linux ISO
images with [G-Mini Agent](https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent)
preinstalled and opening at login. It also maintains the `g-mini-agent-bin`
PKGBUILD for Arch Linux.

| Edition | Base | Installer | How G-Mini Agent is installed |
|---|---|---|---|
| **G-Mini OS (Arch Linux)** | Arch Linux (archiso, `releng` profile) | archinstall, preconfigured | `g-mini-agent-bin` package built from the release AppImage |
| **G-Mini OS (Debian)** | Debian 13 "trixie" (live-build) | Calamares (copies the live system) | The official release `.deb` |

Both editions share the desktop and settings: XFCE on X11, Spanish (Peru) by
default with English available, Latin American and US keyboard layouts,
PipeWire, NetworkManager, Bluetooth, Noto fonts, Chromium, Tesseract OCR and
the C compiler that G-Mini Agent needs on first run.

> G-Mini Agent does not bundle Python. On first run it downloads its own
> Python 3.13 and components (about 1.5 GB) to `~/.local/share/g-mini-agent`.
> **Internet access is required** the first time.

## Downloads

Each [release](../../releases) publishes the two ISOs
(`g-mini-os-arch-<version>-x86_64.iso`, `g-mini-os-debian-<version>-amd64.iso`),
the Arch package (`g-mini-agent-bin-<version>-x86_64.pkg.tar.zst`), the final
`PKGBUILD`, an AUR bundle (`PKGBUILD`, `.SRCINFO`, install scriptlet) and
`SHA256SUMS`. Every ISO is checked to stay under GitHub's 2 GiB per-file limit;
the current package lists point to about 1.5 to 1.6 GiB (Arch) and 1.3 to
1.4 GiB (Debian).

Requirements: 64-bit x86 PC (BIOS or UEFI), 4 GB of RAM (8 GB recommended,
because the first-run download lives in RAM in the live session), a 4 GB USB
drive, and Secure Boot disabled.

Verify downloads with `sha256sum -c SHA256SUMS --ignore-missing`.

## Try it in a virtual machine

**VirtualBox**: new VM of type Linux (Arch Linux or Debian, 64-bit), 4096 MB
of RAM or more (6144 MB to use G-Mini Agent), 2 CPUs, VMSVGA graphics with
128 MB, attach the ISO to the optical drive, optionally enable EFI, and boot
**G-Mini OS**.

**QEMU** with KVM:

```sh
qemu-system-x86_64 -enable-kvm -cpu host -m 6G -smp 4 \
  -vga virtio -display gtk -cdrom g-mini-os-arch-0.1.0-x86_64.iso -boot d
```

Add `-bios /usr/share/ovmf/OVMF.fd` for UEFI and a qcow2 disk
(`-drive file=disk.qcow2,if=virtio`) to test installation.

`scripts/smoke-boot.sh --iso <file>` runs the same headless check as CI: BIOS
menu, UEFI menu, and kernel to systemd to serial-console login.

## Write the ISO to a USB drive

Use **Ventoy** (copy the ISO onto a Ventoy drive), **balenaEtcher**, Rufus in
DD mode, or `dd`:

```sh
sudo dd if=g-mini-os-arch-0.1.0-x86_64.iso of=/dev/sdX bs=4M conv=fsync oflag=direct status=progress
```

## Live session

User `gmini`, password `gmini` (also for `sudo`). Pick **G-Mini OS (English)**
in the boot menu for an English session with a US keyboard; Alt+Shift switches
keyboard layouts. Passwordless `sudo` and the passwordless keyring exist only
in the live session, which lives in RAM and is wiped on shutdown. Ollama is not
preinstalled; the **Install Ollama** launcher adds it on demand.

## Install G-Mini OS to disk

Open **Install G-Mini OS** on the desktop (internet required; back up first).
The Arch edition opens archinstall preconfigured for G-Mini OS: you choose
disk, user and passwords, and G-Mini Agent plus the desktop settings are added
to the new system. The Debian edition opens Calamares, which copies the live
system, G-Mini Agent included.

## Install G-Mini Agent on your distribution

Official packages are published in the main repository
[releases](https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent/releases).
First run compiles `evdev` (used by `pynput` on Linux), so install a C
compiler too:

| Distribution | Command |
|---|---|
| Ubuntu, Debian, Mint, Pop!_OS | `sudo apt install ./g-mini-agent_0.3.1_amd64.deb gcc libc6-dev` |
| Fedora | `sudo dnf install ./g-mini-agent-0.3.1.x86_64.rpm gcc kernel-headers` |
| openSUSE | `sudo zypper install ./g-mini-agent-0.3.1.x86_64.rpm gcc linux-glibc-devel` |
| Arch Linux and derivatives | `cd aur && makepkg -si` (or `pacman -U` the release package) |
| Any | AppImage (needs FUSE 2; on Ubuntu 24.04 run it with `--no-sandbox`) |

The PKGBUILD repackages the official AppImage into `/opt/G-Mini Agent`, the
same path as the `.deb` and `.rpm`, without executing it: it reads the squashfs
offset from the ELF header and extracts the image with `unsquashfs`. The
AppImage sha256 is pinned.

## How it is built

`.github/workflows/release.yml` (on `v*` tags or manually) resolves the G-Mini
Agent version (input, `GMINI_VERSION` repository variable, or the latest
upstream release), verifies every download against GitHub's asset digest,
builds the Arch package with makepkg, the Arch ISO with mkarchiso in a
privileged `archlinux` container, the Debian ISO with Debian's own live-build
on the Ubuntu runner, boots each ISO with QEMU, checks sizes, writes
`SHA256SUMS` and publishes the release. `ci.yml` lints everything and resolves
the package lists against the Arch and Debian archives. Local builds, including
from Windows through WSL2 and Docker, are covered in
[docs/building.md](docs/building.md) (Spanish).

## License

[MIT](LICENSE). The ISOs contain Arch Linux and Debian software under their
own licenses, including non-free firmware needed for common hardware.
