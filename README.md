# Javelin OS - Installer Script

This script transforms a minimal, fresh Devuan installation into a lightweight, fast, and user-friendly desktop environment based on IceWM.

## Philosophy

The goal is to create a system that is:
- **Fast:** Based on Devuan, runit, the Liquorix kernel, and IceWM.
- **Lightweight:** Expects to use ~200-300MB of RAM at idle.
- **User-Friendly:** Includes a full suite of graphical tools for managing sound, power, networking, and Bluetooth.
- **Modern:** Provides a clean, modern aesthetic with essential features like desktop notifications, compositing, and a searchable application launcher.

## What It Installs

- **Core:** IceWM, PCManFM (for desktop icons), LightDM (Login Manager), Rofi (App Launcher), Dunst (Notifications).
- **System:** Liquorix Kernel, runit services, PipeWire for audio.
- **Utilities:** `lxappearance`, `arandr`, `pavucontrol`, `xfce4-screenshooter`, `xfce4-power-manager`, `blueman`, `gufw` (Firewall), `timeshift` (Backups).
- **Applications:** Firefox-ESR, Mousepad (Text Editor), Celluloid (Video Player), Pinta (Image Editor), Atril (Document Viewer).
- **Theme:** Materia GTK Theme, Papirus Icons, Poly-Light GRUB Theme.

## Prerequisites

- A fresh, minimal installation of **Devuan 5 "Daedalus" (64-bit)**.
- A standard non-root user account must already be created.
- A working internet connection.

## How to Use

1.  Log in to your fresh Devuan installation.
2.  Install `git` and `sudo`:
    ```bash
    su -
    apt update && apt install git sudo
    # Add your user to the sudo group
    usermod -aG sudo your_username
    # Log out and log back in for the change to take effect
    exit
    ```
3.  Log back in as your user. Clone this repository:
    ```bash
    git clone https://github.com/your-username/javelin-os-installer.git
    ```
4.  Navigate into the directory:
    ```bash
    cd javelin-os-installer
    ```
5.  Run the installation script. **You must provide your username as an argument.**
    ```bash
    sudo ./install.sh your_username
    ```
    For example, if your username is `mum`, run `sudo ./install.sh mum`.

6.  The script will install all necessary packages and configure the system. A detailed log will be saved in the `/tmp` directory.
7.  When it is finished, **reboot your computer**.
8.  At the login screen, your new desktop should be ready to use!