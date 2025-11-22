#!/bin/bash

# JAVELIN OS (Excalibur Edition) BUILDER
# --------------------------------------
# Target: Devuan Excalibur (Debian 13 Trixie)
# Kernel: Liquorix (Trixie/Testing)
# Init: Runit

set -e # Exit on error

# 1. CHECK ROOT
if [ "$(id -u)" -ne 0 ]; then
   echo "Please run as root (use 'su -')"
   exit 1
fi

echo ">>> [1/7] Installing Build Dependencies..."
# We ensure we are up to date first
apt-get update
apt-get install -y live-build live-boot live-config devuan-keyring git curl debootstrap xorriso gnupg

# 2. CREATE WORKSPACE
WORK_DIR="javelin-excalibur"
if [ -d "$WORK_DIR" ]; then
    echo "Directory $WORK_DIR already exists. Backing up..."
    mv "$WORK_DIR" "${WORK_DIR}_backup_$(date +%s)"
fi
mkdir "$WORK_DIR"
cd "$WORK_DIR"

echo ">>> [2/7] Configuring Core System (Excalibur/Trixie)..."
# Note: We use 'excalibur' for the distro
lb config \
   --distribution excalibur \
   --archive-areas "main contrib non-free non-free-firmware" \
   --init-system runit \
   --architectures amd64 \
   --binary-images iso-hybrid \
   --bootappend-live "boot=live components hostname=javelin username=user quiet splash" \
   --linux-packages "none"

# 3. SETUP LIQUORIX KERNEL REPO
echo ">>> [3/7] Adding Liquorix Repository (Targeting Trixie)..."
mkdir -p config/archives
# Important: Liquorix uses Debian codenames. Excalibur = Trixie.
echo "deb [arch=amd64] https://liquorix.net/debian trixie main" > config/archives/liquorix.list.chroot
curl 'https://liquorix.net/liquorix-keyring.gpg' | gpg --dearmor > config/archives/liquorix.key.chroot

# 4. CREATE PACKAGE LIST
echo ">>> [4/7] Creating Javelin Package List..."
cat <<EOF > config/package-lists/javelin.list.chroot
# --- KERNEL (LIQUORIX) ---
linux-image-liquorix-amd64
linux-headers-liquorix-amd64
firmware-linux-nonfree
intel-microcode
amd64-microcode
zram-tools
haveged

# --- CORE & INIT ---
runit
runit-init
elogind
libpam-elogind
devuan-keyring
debian-keyring

# --- DESKTOP ---
xorg
xserver-xorg-video-all
icewm
icewm-themes
slim
lxappearance
nitrogen
dunst
numlockx
fonts-noto
fonts-roboto
fonts-font-awesome

# --- FILE MANAGER (Thunar Stack) ---
thunar
thunar-volman
thunar-archive-plugin
gvfs-backends
gvfs-fuse
tumbler

# --- APPS ---
kitty
chromium
chromium-l10n
qbittorrent
mpv
viewnior
geany
gparted
synaptic

# --- UTILS & OPTIMIZATION ---
cpufrequtils
msr-tools
lm-sensors
pciutils
dmidecode
htop
neofetch
curl
wget
git

# --- INSTALLER ---
calamares
calamares-settings-debian
EOF

# 5. CREATE OPTIMIZATION SCRIPTS & CONFIGS
echo ">>> [5/7] Injecting Custom Scripts & Configs..."

mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/etc/icewm
mkdir -p config/includes.chroot/etc/xdg/kitty

# B. Javelin CPU Optimization Script
cat <<EOF > config/includes.chroot/usr/local/bin/javelin-opt.sh
#!/bin/sh
# JAVELIN OS - CPU OPTIMIZER
# 1. Force Performance
if [ -d /sys/devices/system/cpu ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "\$cpu" ] && echo "performance" > "\$cpu"
    done
fi
# 2. Intel Tweaks
VENDOR=\$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print \$3}')
if [ "\$VENDOR" = "GenuineIntel" ]; then
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo "0" > /sys/devices/system/cpu/intel_pstate/no_turbo
    fi
fi
# 3. Network Tweaks (BBR)
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
EOF

# C. IceWM Startup Script
cat <<EOF > config/includes.chroot/etc/icewm/startup
#!/bin/sh
nm-applet &
pavucontrol &
thunar --daemon &
nitrogen --restore &
numlockx on &
EOF

# D. Kitty Config
cat <<EOF > config/includes.chroot/etc/xdg/kitty/kitty.conf
font_family monospace
font_size 11.0
background #101010
foreground #00ff00
selection_background #00aa00
selection_foreground #000000
repaint_delay 8
sync_to_monitor yes
EOF

# 6. CREATE BUILD HOOKS
echo ">>> [6/7] Setting up Build Hooks..."
mkdir -p config/hooks/normal
cat <<EOF > config/hooks/normal/01-javelin-setup.hook.chroot
#!/bin/sh
chmod +x /usr/local/bin/javelin-opt.sh
chmod +x /etc/icewm/startup

# Add to rc.local
if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/sh -e' > /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
fi
if ! grep -q "javelin-opt.sh" /etc/rc.local; then
    sed -i '/exit 0/i /usr/local/bin/javelin-opt.sh' /etc/rc.local
fi

# Defaults
update-alternatives --set x-terminal-emulator /usr/bin/kitty
update-alternatives --set x-www-browser /usr/bin/chromium
update-alternatives --set gnome-www-browser /usr/bin/chromium

apt-get clean
EOF

# 7. FINISH
echo "--------------------------------------------------------"
echo ">>> JAVELIN (EXCALIBUR) CONFIGURATION COMPLETE"
echo "--------------------------------------------------------"
echo "Run: sudo lb build"
echo "--------------------------------------------------------"