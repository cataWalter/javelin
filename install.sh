#!/bin/bash
# ==============================================================================
# Javelin OS Installer Script (v6 - Refactored for Modularity)
#
# This script transforms a minimal, fresh Devuan installation into a
# lightweight, fast, and user-friendly desktop environment based on IceWM.
# ==============================================================================

# --- Configuration ---
LOG_FILE="/tmp/javelin-installer-$(date +%F-%H%M%S).log"
TARGET_USER=""
USER_HOME=""

# --- Colors for output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Package Lists (for easy customization) ---
PKGS_CORE_DESKTOP=(
    lightdm slick-greeter
    icewm pcmanfm picom
)
PKGS_AUDIO=(
    pipewire-pulse pavucontrol pa-applet
)
PKGS_POWER=(
    xfce4-power-manager tlp
)
PKGS_NETWORKING=(
    network-manager-gnome nm-applet
    bluez blueman
)
PKGS_FIRMWARE=(
    firmware-linux-nonfree firmware-realtek broadcom-sta-dkms
    intel-microcode amd64-microcode
)
PKGS_PRINTING=(
    cups system-config-printer sane-utils
)
PKGS_APPLICATIONS=(
    firefox-esr celluloid pinta abiword gnumeric atril mousepad ristretto qbittorrent
)
PKGS_MEDIA_SUPPORT=(
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
    gstreamer1.0-libav libavcodec-extra libdvd-pkg
)
PKGS_FILE_SUPPORT=(
    file-roller unzip unrar p7zip-full
    gvfs-backends mtp-tools
    ntfs-3g exfat-fuse exfatprogs btrfs-progs f2fs-tools
    default-jre
)
PKGS_SYSTEM_UTILITIES=(
    lxappearance arandr xfce4-screenshooter htop neofetch gparted baobab
    ttf-mscorefonts-installer
    zram-tools xfce4-terminal
    thermald irqbalance preload
    flatpak
)
PKGS_FONTS=(
    fonts-noto-cjk fonts-indic fonts-arabeyes
)
PKGS_THEMING=(
    materia-gtk-theme papirus-icon-theme
    grub-theme-poly-light
)
PKGS_UI_HELPERS=(
    rofi dunst icewm-menu-fdo xbacklight numlockx
    light-locker
)
PKGS_SYSTEM_SAFETY=(
    yad
    qt5-style-plugins qt5ct
    update-notifier
    timeshift
    gufw
    tmux
)
PKGS_DEVELOPMENT=(
    build-essential git
    linux-image-liquorix-amd64 linux-headers-liquorix-amd64
)

# --- Helper Functions ---
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# --- Phase 1: Initial Checks ---
check_prerequisites() {
    log "Phase 1: Checking prerequisites..."
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Please use sudo."
    fi

    if [ -z "$1" ]; then
        error "You must provide a username as the first argument.\nUsage: sudo ./install.sh <username>"
    fi

    TARGET_USER="$1"
    USER_HOME="/home/$TARGET_USER"

    if [ "$TARGET_USER" = "root" ]; then
        error "This script is not intended to be run for the root user. Please provide a standard username."
    fi

    if [ ! -d "$USER_HOME" ]; then
        error "User home directory $USER_HOME not found. Is the username correct?"
    fi

    if ! grep -q 'VERSION_CODENAME=daedalus' /etc/os-release; then
        error "This script is designed for Devuan 5 'Daedalus' only."
    fi
    log "Prerequisites met."
}

# --- Phase 2: System Preparation ---
setup_repositories() {
    log "Phase 2: Setting up repositories..."
    log "Enabling contrib, non-free, and non-free-firmware repositories..."
    sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list

    log "Updating package lists..."
    apt update &>> "$LOG_FILE"

    log "Installing prerequisites for adding new repositories..."
    apt install -y curl gpg &>> "$LOG_FILE"

    log "Adding the Liquorix Kernel repository..."
    curl -s 'https://liquorix.net/add-liquorix-repo.sh' | bash &>> "$LOG_FILE"

    log "Updating package lists again..."
    apt update &>> "$LOG_FILE"
    log "Repository setup complete."
}

# --- Phase 3: Package Installation ---
preseed_packages() {
    log "Phase 3a: Pre-seeding package configurations..."
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections
    echo "libdvd-pkg libdvd-pkg/accepted-pending-removal select true" | debconf-set-selections
    log "Pre-seeding complete."
}

install_packages() {
    log "Phase 3b: Installing all Javelin OS components..."
    export DEBIAN_FRONTEND=noninteractive
    apt install -y --no-install-recommends \
        "${PKGS_CORE_DESKTOP[@]}" \
        "${PKGS_AUDIO[@]}" \
        "${PKGS_POWER[@]}" \
        "${PKGS_NETWORKING[@]}" \
        "${PKGS_FIRMWARE[@]}" \
        "${PKGS_PRINTING[@]}" \
        "${PKGS_APPLICATIONS[@]}" \
        "${PKGS_MEDIA_SUPPORT[@]}" \
        "${PKGS_FILE_SUPPORT[@]}" \
        "${PKGS_SYSTEM_UTILITIES[@]}" \
        "${PKGS_FONTS[@]}" \
        "${PKGS_THEMING[@]}" \
        "${PKGS_UI_HELPERS[@]}" \
        "${PKGS_SYSTEM_SAFETY[@]}" \
        "${PKGS_DEVELOPMENT[@]}" &>> "$LOG_FILE"
    log "Package installation complete."
}

# --- Phase 4: System-wide Configuration ---
configure_system() {
    log "Phase 4: Applying system-wide configurations..."
    # LightDM
    log "Configuring LightDM and Slick Greeter..."
    echo "[Seat:*]\ngreeter-session=slick-greeter" > /etc/lightdm/lightdm.conf.d/60-slick-greeter.conf
    cat <<EOF > /etc/lightdm/slick-greeter.conf
[Greeter]
theme-name=Materia-dark-compact
icon-theme-name=Papirus-Dark
background=/usr/share/backgrounds/devuan/devuan-mesh-dark.png
draw-user-backgrounds=false
draw-grid=false
EOF

    # GRUB
    log "Configuring GRUB theme..."
    sed -i 's/#GRUB_THEME=/GRUB_THEME="\/usr\/share\/grub\/themes\/poly-light\/theme.txt"/g' /etc/default/grub
    update-grub &>> "$LOG_FILE"

    # Hardware Clock
    log "Setting hardware clock to local time..."
    timedatectl set-local-rtc 1 --adjust-system-clock

    # DVD Playback
    log "Finalizing DVD playback configuration..."
    dpkg-reconfigure libdvd-pkg &>> "$LOG_FILE"
    log "System configuration complete."
}

# --- Phase 5: System Services (runit) ---
enable_services() {
    log "Phase 5: Enabling core system services for runit..."
    local services=(
        dbus acpid NetworkManager bluetoothd cupsd lightdm tlp zram
        thermald irqbalance preload
    )
    for service in "${services[@]}"; do
        log "Enabling service: $service"
        ln -sf "/etc/sv/$service" "/etc/service/"
    done
    log "System services enabled."
}

# --- Phase 6: User Desktop Configuration ---
configure_user_desktop() {
    log "Phase 6: Copying default desktop configuration for user $TARGET_USER..."
    
    # Safer copy with backup
    local config_dir="files"
    if [ ! -d "$config_dir" ]; then
        log "No 'files' directory found, skipping user configuration."
        return
    fi

    find "$config_dir" -mindepth 1 -print0 | while IFS= read -r -d '' src_path; do
        local dest_path="$USER_HOME/${src_path#$config_dir/}"
        
        # Create parent directory if it doesn't exist
        mkdir -p "$(dirname "$dest_path")"

        # If destination exists, back it up
        if [ -e "$dest_path" ]; then
            log "Backing up existing config: $dest_path"
            mv "$dest_path" "$dest_path.bak"
        fi
        
        log "Copying config to: $dest_path"
        cp -r "$src_path" "$dest_path"
    done

    log "Setting correct permissions for user home directory..."
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME"
    find "$USER_HOME" -type f -name "*.sh" -exec chmod +x {} +
    chmod +x "$USER_HOME/.icewm/startup"
    log "User desktop configuration complete."
}

# --- Phase 7: Final Cleanup ---
cleanup() {
    log "Phase 7: Cleaning up..."
    apt-get autoremove -y &>> "$LOG_FILE"
    apt-get clean &>> "$LOG_FILE"
    log "Cleanup complete."
}

# --- Main Execution ---
main() {
    check_prerequisites "$1"
    setup_repositories
    preseed_packages
    install_packages
    configure_system
    enable_services
    configure_user_desktop
    cleanup

    log "--------------------------------------------------------"
    log "Javelin OS Installation is COMPLETE!"
    log "Please REBOOT your system now to apply all changes."
    log "A detailed log is available at $LOG_FILE"
    log "--------------------------------------------------------"
}

# Run the main function, passing all script arguments to it
main "$@"

exit 0