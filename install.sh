#!/bin/bash
# ==============================================================================
# Javelin OS Installer Script (v4 - Final Polish)
# ==============================================================================

# ... (Safety checks and log functions remain the same as v3) ...
# --- Safety Checks and Setup ---
set -e # Exit immediately if a command exits with a non-zero status.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root. Please use sudo."
fi

# Check for username argument
if [ -z "$1" ]; then
    error "You must provide a username as the first argument.\nUsage: sudo ./install.sh <username>"
fi

TARGET_USER="$1"
USER_HOME="/home/$TARGET_USER"

if [ ! -d "$USER_HOME" ]; then
    error "User home directory $USER_HOME not found. Is the username correct?"
fi

log "Starting Javelin OS transformation for user: $TARGET_USER"

# --- Phase 1: System Preparation & Repositories ---
log "Enabling contrib and non-free repositories for firmware..."
sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list

log "Updating package lists..."
apt update

log "Installing prerequisites for adding repositories..."
apt install -y curl gpg

log "Adding the Liquorix Kernel repository..."
curl -s 'https://liquorix.net/add-liquorix-repo.sh' | bash

log "Updating package lists again with new repository..."
apt update

# --- Phase 2: Pre-seeding Debconf for EULAs ---
log "Pre-accepting EULAs for Microsoft Fonts and DVD Playback..."
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections
echo "libdvd-pkg libdvd-pkg/accepted-pending-removal select true" | debconf-set-selections
echo "libdvd-pkg libdvd-pkg/build select true" | debconf-set-selections

# --- Phase 3: Core Package Installation ---
log "Installing the Javelin OS components..."
export DEBIAN_FRONTEND=noninteractive
apt install -y --no-install-recommends \
    \
    # --- CORE DESKTOP & LOGIN ---
    lightdm slick-greeter \
    icewm pcmanfm picom \
    \
    # ... (All packages from v3 are here) ...
    pipewire-pulse pavucontrol volumeicon-alsa \
    xfce4-power-manager tlp \
    network-manager-gnome nm-applet \
    bluez blueman \
    firmware-linux-nonfree firmware-realtek broadcom-sta-dkms \
    intel-microcode amd64-microcode \
    cups system-config-printer sane-utils \
    firefox-esr celluloid pinta abiword gnumeric atril \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav libavcodec-extra libdvd-pkg \
    file-roller unzip unrar p7zip-full \
    gvfs-backends mtp-tools \
    ntfs-3g exfat-fuse exfatprogs btrfs-progs f2fs-tools \
    default-jre \
    lxappearance arandr flameshot htop neofetch gparted baobab \
    ttf-mscorefonts-installer \
    fonts-noto-cjk fonts-indic fonts-arabeyes \
    materia-gtk-theme papirus-icon-theme \
    
    # --- NEW: UI & ERGONOMICS HELPERS ---
    rofi 
    dunst 
    icewm-menu-fdo 
    xbacklight 
    numlockx 
    betterlockscreen \
    \
    # --- NEW: POLISH & SYSTEM SAFETY ---
    grub-theme-poly-light \
    yad \
    qt5-style-plugins qt5ct \
    update-notifier \
    timeshift \
    gufw \
    tmux \
    \
    # --- POWER USER & KERNEL ---
    build-essential git \
    linux-image-liquorix-amd64 linux-headers-liquorix-amd64

log "Package installation complete."

# --- Phase 4: System-wide Configuration ---
log "Configuring system settings..."

# Set Slick Greeter as the default
echo "[Seat:*]\ngreeter-session=slick-greeter" > /etc/lightdm/lightdm.conf.d/60-slick-greeter.conf

# Configure the Slick Greeter
cat <<EOF > /etc/lightdm/slick-greeter.conf
[Greeter]
theme-name=Materia-dark-compact
icon-theme-name=Papirus-Dark
background=/usr/share/backgrounds/devuan/devuan-mesh-dark.png
draw-user-backgrounds=false
draw-grid=false
EOF

# Set the GRUB theme
sed -i 's/#GRUB_THEME=/GRUB_THEME="\/usr\/share\/grub\/themes\/poly-light\/theme.txt"/g' /etc/default/grub
update-grub

# Set hardware clock to local time for better dual-booting with Windows
timedatectl set-local-rtc 1 --adjust-system-clock

# Finalizing DVD playback configuration
log "Finalizing DVD playback configuration..."
dpkg-reconfigure libdvd-pkg

# --- Phase 5: System Services (runit) ---
log "Enabling core system services for runit..."
# ... (Same services as v3) ...
ln -sf /etc/sv/dbus /etc/service/
ln -sf /etc/sv/acpid /etc/service/
ln -sf /etc/sv/NetworkManager /etc/service/
ln -sf /etc/sv/bluetoothd /etc/service/
ln -sf /etc/sv/cupsd /etc/service/
ln -sf /etc/sv/lightdm /etc/service/
ln -sf /etc/sv/tlp /etc/service/
log "System services enabled."

# --- Phase 6: User Desktop Configuration ---
# Create a simple Welcome script
mkdir -p "$USER_HOME/.config/autostart"
cat <<'EOF' > "$USER_HOME/.local/share/welcome.sh"
#!/bin/bash
yad --title="Welcome to Javelin OS!" \
    --text="Welcome to your new, fast desktop.\n\n<b>Key Applications:</b>\n • <b>Menu:</b> Click the button in the bottom-left corner\n • <b>Web Browser:</b> Icon on the toolbar\n • <b>File Manager:</b> Icon on the toolbar\n\nEnjoy your system!" \
    --button="Get Started!":0 \
    --width=350 --height=150
# Create a flag file so this only runs once
touch ~/.config/javelin-welcomed
EOF

# Create the autostart entry for the welcome script
cat <<EOF > "$USER_HOME/.config/autostart/welcome.desktop"
[Desktop Entry]
Type=Application
Name=Javelin Welcome
Exec=bash -c "if [ ! -f ~/.config/javelin-welcomed ]; then bash ~/.local/share/welcome.sh; fi"
OnlyShowIn=ICEWM;
EOF

# Copy the rest of the configuration files
log "Copying default desktop configuration files to $USER_HOME..."
cp -rT files/ "$USER_HOME/"

log "Setting correct permissions..."
chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME"
chmod +x "$USER_HOME/.icewm/startup"
chmod +x "$USER_HOME/.local/share/welcome.sh"

log "User desktop configuration complete."

# --- Phase 7: Final Cleanup ---
log "Cleaning up apt cache..."
apt-get autoremove -y
apt-get clean

# --- Completion ---
log "--------------------------------------------------------"
log "Javelin OS Installation is COMPLETE!"
log "Please REBOOT your system now to apply all changes."
log "--------------------------------------------------------"

exit 0