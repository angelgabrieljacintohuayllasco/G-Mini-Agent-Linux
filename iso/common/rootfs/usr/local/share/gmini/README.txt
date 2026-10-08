G-Mini OS: quick guide
======================

G-Mini OS is a Linux system with the XFCE desktop and G-Mini Agent already
installed: an AI agent that sees your screen, uses the mouse, keyboard and
browser, remembers what you tell it and talks.


Live session
------------
User: gmini
Password: gmini (also for sudo)

Everything lives in RAM and is lost on shutdown. To keep your data, install
G-Mini OS to disk (the "Install G-Mini OS" shortcut).


G-Mini Agent first run
----------------------
G-Mini Agent opens at login. On first run it downloads its own Python 3.13
and components (about 1.5 GB) to ~/.local/share/g-mini-agent, so it needs
internet:

  1. Connect to a network with the network icon in the panel.
  2. In the "Preparando G-Mini" window, press Retry if it failed.

In the live session that download uses RAM: use a computer with 8 GB or more.

AI provider API keys are stored in the system keyring (gnome-keyring). In the
live session the keyring has no password because everything is wiped on
shutdown.

If something fails, details are in:
    ~/.local/share/g-mini-agent/logs/setup.log


Install to disk
---------------
Open "Install G-Mini OS" on the desktop. You need internet.

  - Arch Linux edition: archinstall opens with G-Mini OS preconfigured
    (XFCE, language, keyboard, audio, network). You choose the disk, user and
    passwords. G-Mini Agent is added to the new system at the end.
  - Debian edition: the Calamares graphical installer copies this same
    system (with G-Mini Agent) to disk.

Back up your data first: installing can erase the selected disk.


Local models (optional)
-----------------------
"Install Ollama" (applications menu) installs Ollama to run models offline.
Then, in a terminal:
    ollama pull llama3.2:3b
and in G-Mini Agent: Settings > Provider > Ollama.


Language and keyboard
---------------------
Default: Spanish (Peru) with Latin American and US keyboard layouts.
Alt+Shift switches the layout. To switch everything to English: "G-Mini OS
Welcome" > "Switch to English", or pick "G-Mini OS (English)" in the boot menu.


More information
----------------
G-Mini Agent: https://github.com/angelgabrieljacintohuayllasco/G-Mini-Agent
