# Javelin OS - Installer Script

This script transforms a minimal, fresh Devuan installation into a lightweight, fast, and user-friendly desktop environment based on IceWM.

## Philosophy

The goal is to create a system that is:
- **Fast:** Based on Devuan, runit, the Liquorix kernel, and IceWM.
- **Lightweight:** Expects to use ~200-300MB of RAM at idle.
- **User-Friendly:** Includes graphical tools for managing sound, power, networking, and Bluetooth, making it accessible even for users not familiar with Linux.

## Prerequisites

- A fresh, minimal installation of **Devuan 5 "Daedalus" (64-bit)**.
- A standard non-root user account must already be created.
- A working internet connection.

## How to Use

1.  Log in to your fresh Devuan installation.
2.  Install `git`:
    ```bash
    sudo apt update && sudo apt install git
    ```
3.  Clone this repository:
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
    For example, if your username is `mum`, you would run `sudo ./install.sh mum`.

6.  The script will install all necessary packages and configure the system. It will take some time.
7.  When it is finished, **reboot your computer**.
8.  At the login screen, your new desktop should be ready to use!

## What It Installs

- **Core:** IceWM (Window Manager), PCManFM (for desktop icons), LightDM (Login Manager)
- **System:** Liquorix Kernel, runit services
- **Utilities:** `lxappearance`, `arandr`, `pavucontrol`, `flameshot`, `xfce4-power-manager`, `blueman`
- **Theme:** Materia GTK Theme, Papirus Icons
