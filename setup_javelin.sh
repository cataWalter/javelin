#!/bin/bash

# JAVELIN OS (Excalibur Edition) - FIXED BUILDER
# ----------------------------------------------
# Fix: Removed deprecated --init-system flag
# Target: Devuan Excalibur
# Kernel: Liquorix

set -e

# 1. CHECK ROOT
if [ "$(id -u)" -ne 0 ]; then
   echo "Please run as root (use 'su -')"
   exit 1
fi

# 2. CLEANUP PREVIOUS FAILED ATTEMPT
# We remove the config cache to prevent conflicts
if [ -d "javelin-excalibur" ]; then
    echo "Cleaning up previous config..."
    cd javelin-excalibur
    lb clean
    rm -rf config
    cd ..
else
    mkdir -p javelin-excalibur
fi

cd javelin-excalibur

echo ">>> [1/6] Configuring Core System..."
# REMOVED: --init-system runit (Deprecated)
lb config \
   --distribution excalibur \
   --archive-areas "main contrib non-free non-free-firmware" \
   --architectures amd64 \
   --binary-images iso-hybrid \
   --bootappend-live "boot=live components hostname=javelin username=user quiet splash" \
   --linux-packages "none"

# 3. SETUP LIQUORIX KERNEL REPO
echo ">>> [2/6] Adding Liquorix Repository..."
mkdir -p config/archives
echo "deb [arch=amd64] https://liquorix.net/debian trixie main" > config/archives/liquorix.list.chroot
curl 'https://liquorix.net/liquorix-keyring.gpg' | gpg --dearmor > config/archives/liquorix.key.chroot

# 4. CREATE PACKAGE LIST
echo ">>> [3/6] Creating Javelin Package List..."
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

# --- FILE MANAGER ---
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

# --- UTILS ---
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
calamares
calamares-settings-debian
EOF

# 5. SCRIPTS & CONFIGS
echo ">>> [4/6] Injecting Scripts..."
mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/etc/icewm
mkdir -p config/includes.chroot/etc/xdg/kitty

# Optimization Script
cat <<EOF > config/includes.chroot/usr/local/bin/javelin-opt.sh
#!/bin/sh
# Javelin CPU Optimizer
if [ -d /sys/devices/system/cpu ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "\$cpu" ] && echo "performance" > "\$cpu"
    done
fi
VENDOR=\$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print \$3}')
if [ "\$VENDOR" = "GenuineIntel" ]; then
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo "0" > /sys/devices/system/cpu/intel_pstate/no_turbo
    fi
fi
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
EOF

# IceWM Startup
cat <<EOF > config/includes.chroot/etc/icewm/startup
#!/bin/sh
nm-applet &
pavucontrol &
thunar --daemon &
nitrogen --restore &
numlockx on &
EOF

# Kitty Config
cat <<EOF > config/includes.chroot/etc/xdg/kitty/kitty.conf
font_family monospace
background #101010
foreground #00ff00
repaint_delay 8
sync_to_monitor yes
EOF

# 6. HOOKS
echo ">>> [5/6] Setting Hooks..."
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

update-alternatives --set x-terminal-emulator /usr/bin/kitty
update-alternatives --set x-www-browser /usr/bin/chromium
update-alternatives --set gnome-www-browser /usr/bin/chromium

apt-get clean
EOF

